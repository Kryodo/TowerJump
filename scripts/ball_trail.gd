extends Node2D

## Visual energy trail for the player ball.
## The trail is layered: a soft outer aura, a turbulent inner stream, staggered
## plasma filaments with a small terminal fork, and geometric energy fragments.
## This script only controls visuals; ball movement and collision remain in ball.gd.

@export_category("Trail History")
@export var max_points: int = 27
@export var min_distance: float = 2.0
@export var max_segment_distance: float = 120.0
@export_range(0.0, 40.0, 1.0) var trail_head_offset: float = 28.0

const UNIFIED_HEAD_ARC_SEGMENTS: int = 20
const ORB_RIM_CENTER_RADIUS_RATIO: float = 0.93
const SHED_CONNECTED_END_PROGRESS: float = 0.38
const SHED_GEOMETRY_PIECE_CAPACITY: int = 32
const SHED_GAP_MASK_PADDING: float = 2.5
const MAX_ACTIVE_SHED_BREAKS: int = 3
const LANDING_BURST_FRAGMENT_COUNT: int = 3
const LANDING_BURST_INTERVAL: float = 0.05

@export_category("Visual Palette")
@export_enum("Electric Blue", "Rich Violet") var visual_palette: int = 0

@export_category("Comet Shedding")
@export var shedding_enabled: bool = true

@onready var _energy_line: Line2D = $EnergyLine
@onready var _trail_aura: Line2D = $TrailAura
@onready var _unified_shape: Polygon2D = get_node_or_null("UnifiedCometShape") as Polygon2D
@onready var _shed_geometry_container: Node2D = get_node_or_null("ShedGeometry") as Node2D
@onready var _unified_contour: Line2D = get_node_or_null("UnifiedCometContour") as Line2D
@onready var _ball_visual: Sprite2D = get_parent().get_node("Visual") as Sprite2D

var _points: Array[Vector2] = []
var _point_ids: Array[int] = []
var _next_point_id: int = 1
var _particle_emitters: Array[GPUParticles2D] = []
var _previous_ball_position: Vector2 = Vector2.ZERO
var _trail_time: float = 0.0
var _last_emission_direction: Vector2 = Vector2.DOWN
var _ball_surface_radius: float = 29.9
var _shed_sequence: int = 0
var _pending_landing_shed: bool = false
var _landing_burst_remaining: int = 0
var _landing_burst_timer: float = 0.0
var _landing_burst_last_progress: float = -1.0
var _detached_shed_fragments: Array[Dictionary] = []
var _shed_geometry_pieces: Array[Polygon2D] = []
var _shed_piece_ranges: Array[Dictionary] = []
var _shed_break_events: Array[Dictionary] = []
var _shed_piece_material: ShaderMaterial
var _detached_piece_material: ShaderMaterial


func _ready() -> void:
	z_index = -1
	_previous_ball_position = global_position
	_ball_surface_radius = _measure_ball_surface_radius()

	for node_name in [
		"TrailParticles",
		"TrailDiamonds",
		"TrailSquares",
		"TrailShards"
	]:
		var emitter := get_node_or_null(node_name) as GPUParticles2D
		if emitter != null:
			_particle_emitters.append(emitter)

	_apply_visual_palette()
	_initialize_shed_geometry_pieces()
	_update_trail_lines()
	_update_rim_breath()
	call_deferred("_connect_landing_feedback")


func _connect_landing_feedback() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	# Reuse the existing confirmed-landing event; the trail owns only its
	# visual reaction and does not infer contact from ball velocity.
	var controller: Node = scene_root.get_node_or_null("LandingFeedbackController")
	if controller == null or not controller.has_signal("landing_confirmed"):
		return

	var callback := Callable(self, "_on_landing_confirmed")
	if not controller.is_connected("landing_confirmed", callback):
		controller.connect("landing_confirmed", callback)


func _on_landing_confirmed(event: LandingEvent) -> void:
	if not shedding_enabled or event == null:
		return

	var ball := get_parent() as CharacterBody2D
	if ball == null or event.ball != ball:
		return

	# Queue a short release burst until this frame's trail geometry is rebuilt.
	# The burst only uses genuine pieces cut from this trail's polygon.
	_pending_landing_shed = true


func _measure_ball_surface_radius() -> float:
	if _ball_visual == null or _ball_visual.texture == null:
		return 29.9

	var texture_image: Image = _ball_visual.texture.get_image()
	if texture_image == null or texture_image.is_empty():
		var texture_size: Vector2 = _ball_visual.texture.get_size()
		var scale_x: float = absf(_ball_visual.global_scale.x)
		var scale_y: float = absf(_ball_visual.global_scale.y)
		return minf(texture_size.x * scale_x, texture_size.y * scale_y) * 0.5

	var image_size: Vector2i = texture_image.get_size()
	var image_center := Vector2(
		(float(image_size.x) - 1.0) * 0.5,
		(float(image_size.y) - 1.0) * 0.5
	)
	var max_radius: float = minf(image_size.x, image_size.y) * 0.5
	var step_size: float = 0.25
	var sample_count: int = int(ceil(max_radius / step_size))
	var angle_count: int = 256
	var radius_sum: float = 0.0
	var measured_rays: int = 0

	# Measure the mask's 50% alpha boundary once. This sets the contour root
	# against the real sprite edge without wrapping a separate hood around it.
	for angle_index in range(angle_count):
		var angle: float = TAU * float(angle_index) / float(angle_count)
		var direction := Vector2(cos(angle), sin(angle))
		var previous_radius: float = 0.0
		var previous_alpha: float = _sample_image_alpha_bilinear(texture_image, image_center)
		var crossing_radius: float = max_radius
		var found_edge: bool = false

		for sample_index in range(1, sample_count + 1):
			var current_radius: float = minf(float(sample_index) * step_size, max_radius)
			var sample_position: Vector2 = image_center + direction * current_radius
			var current_alpha: float = _sample_image_alpha_bilinear(texture_image, sample_position)
			if current_alpha < 0.5:
				var alpha_span: float = previous_alpha - current_alpha
				var crossing_t: float = 0.0
				if alpha_span > 0.001:
					crossing_t = clampf((previous_alpha - 0.5) / alpha_span, 0.0, 1.0)
				crossing_radius = lerp(previous_radius, current_radius, crossing_t)
				found_edge = true
				break
			previous_radius = current_radius
			previous_alpha = current_alpha

		if found_edge:
			radius_sum += crossing_radius
			measured_rays += 1

	if measured_rays == 0:
		var fallback_size: Vector2 = _ball_visual.texture.get_size()
		var fallback_scale_x: float = absf(_ball_visual.global_scale.x)
		var fallback_scale_y: float = absf(_ball_visual.global_scale.y)
		return minf(fallback_size.x * fallback_scale_x, fallback_size.y * fallback_scale_y) * 0.5

	var texture_radius: float = radius_sum / float(measured_rays)
	var world_scale: float = (
		absf(_ball_visual.global_scale.x) + absf(_ball_visual.global_scale.y)
	) * 0.5
	return texture_radius * world_scale


func _sample_image_alpha_bilinear(texture_image: Image, position: Vector2) -> float:
	var max_x: float = float(texture_image.get_width() - 1)
	var max_y: float = float(texture_image.get_height() - 1)
	var x: float = clampf(position.x, 0.0, max_x)
	var y: float = clampf(position.y, 0.0, max_y)
	var x0: int = int(floor(x))
	var y0: int = int(floor(y))
	var x1: int = mini(x0 + 1, texture_image.get_width() - 1)
	var y1: int = mini(y0 + 1, texture_image.get_height() - 1)
	var tx: float = x - float(x0)
	var ty: float = y - float(y0)
	var top_alpha: float = lerp(
		texture_image.get_pixel(x0, y0).a,
		texture_image.get_pixel(x1, y0).a,
		tx
	)
	var bottom_alpha: float = lerp(
		texture_image.get_pixel(x0, y1).a,
		texture_image.get_pixel(x1, y1).a,
		tx
	)
	return lerp(top_alpha, bottom_alpha, ty)


func _get_exposed_flank_points(
	edge_points: Array[Vector2],
	ball_center: Vector2,
	contour_radius: float
) -> Array[Vector2]:
	var exposed_points: Array[Vector2] = []
	if edge_points.size() < 2:
		return exposed_points

	var radius_squared: float = contour_radius * contour_radius
	var first_offset: Vector2 = edge_points[0] - ball_center
	if first_offset.length_squared() >= radius_squared:
		# Defensive fallback if a future trail profile begins outside the orb.
		exposed_points.append(edge_points[0])
		for point_index in range(1, edge_points.size()):
			exposed_points.append(edge_points[point_index])
		return exposed_points

	# Hide the contour while its real trail edge lies inside the orb. Its first
	# visible point is the exact segment/circle intersection with the rim ridge.
	for point_index in range(1, edge_points.size()):
		var segment_start: Vector2 = edge_points[point_index - 1]
		var segment_end: Vector2 = edge_points[point_index]
		var start_offset: Vector2 = segment_start - ball_center
		var end_offset: Vector2 = segment_end - ball_center
		var start_inside: bool = start_offset.length_squared() < radius_squared
		var end_inside: bool = end_offset.length_squared() < radius_squared

		if start_inside and not end_inside:
			exposed_points.append(
				_segment_circle_exit_intersection(
					segment_start, segment_end, ball_center, contour_radius
				)
			)
			for remaining_index in range(point_index, edge_points.size()):
				exposed_points.append(edge_points[remaining_index])
			return exposed_points

	return exposed_points


func _segment_circle_exit_intersection(
	segment_start: Vector2,
	segment_end: Vector2,
	circle_center: Vector2,
	circle_radius: float
) -> Vector2:
	var segment: Vector2 = segment_end - segment_start
	var offset: Vector2 = segment_start - circle_center
	var a: float = segment.length_squared()
	if a < 0.0001:
		return segment_start

	var b: float = 2.0 * offset.dot(segment)
	var c_value: float = offset.length_squared() - circle_radius * circle_radius
	var discriminant: float = maxf(b * b - 4.0 * a * c_value, 0.0)
	var t: float = (-b + sqrt(discriminant)) / (2.0 * a)
	return segment_start + segment * clampf(t, 0.0, 1.0)


func _process(delta: float) -> void:
	var ball := get_parent() as CharacterBody2D
	if ball == null:
		return

	_trail_time += delta
	if not shedding_enabled:
		_shed_break_events.clear()
		_pending_landing_shed = false
		_landing_burst_remaining = 0
		_landing_burst_timer = 0.0
		_landing_burst_last_progress = -1.0
	if _landing_burst_remaining > 0 and not _pending_landing_shed:
		_landing_burst_timer = maxf(_landing_burst_timer - delta, 0.0)
	var current_world_position: Vector2 = ball.global_position
	var movement: Vector2 = current_world_position - _previous_ball_position
	var distance_from_trail: float = movement.length()

	if _points.is_empty() or distance_from_trail > max_segment_distance:
		# Do not draw a ribbon across teleports, screen-wrap jumps, or other
		# large discontinuities in the sampled trajectory.
		_points.clear()
		_point_ids.clear()
		_shed_break_events.clear()
		_points.append(current_world_position)
		_point_ids.append(_next_point_id)
		_next_point_id += 1
	elif _points[0].distance_to(current_world_position) >= min_distance:
		_points.push_front(current_world_position)
		_point_ids.push_front(_next_point_id)
		_next_point_id += 1
		while _points.size() > max_points:
			_points.pop_back()
			_point_ids.pop_back()

	_update_trail_lines()
	_update_detached_shed_fragments(delta)
	_update_rim_breath()
	_update_particle_emitters(current_world_position, movement, distance_from_trail)
	_previous_ball_position = current_world_position


func _update_rim_breath() -> void:
	# Keep the orb's rim shader and shared trail contour on the same pulse curve.
	var breathing: float = 0.5 + 0.5 * sin(_trail_time * 1.35)
	var rim_breath: float = lerp(0.72, 1.0, breathing)
	var orb_material := _ball_visual.material as ShaderMaterial
	if orb_material != null:
		orb_material.set_shader_parameter("rim_breath", rim_breath)
	if _unified_contour != null:
		_unified_contour.modulate = Color(rim_breath, rim_breath, rim_breath, 1.0)


func _update_trail_lines() -> void:
	if _points.size() < 2:
		_energy_line.clear_points()
		_trail_aura.clear_points()
		if _unified_shape != null:
			_unified_shape.polygon = PackedVector2Array()
			_unified_shape.uv = PackedVector2Array()
		_clear_shed_geometry_pieces()
		if _unified_contour != null:
			_unified_contour.clear_points()
		return

	_energy_line.clear_points()
	_trail_aura.clear_points()

	# Rebuild the stream every frame with a tiny animated lateral drift.
	# This keeps the energy alive at the jump apex even when the ball itself
	# has almost no velocity and no new trail samples are being collected.
	# Keep the inner energy line's recessed head, but give the translucent aura
	# the same centreline as the unified skin and contour so their outer edges
	# stay aligned through the narrow neck directly below the orb.
	for i in range(_points.size()):
		var point: Vector2 = _get_animated_trail_point(i)
		_energy_line.add_point(_energy_line.to_local(point))
		var aura_point: Vector2 = _get_animated_trail_point(i, false)
		_trail_aura.add_point(_trail_aura.to_local(aura_point))

	_update_unified_comet_shape()


func _get_animated_trail_point(index: int, apply_head_offset: bool = true) -> Vector2:
	var point: Vector2 = _points[index]
	if _points.size() < 2:
		return point

	var tangent: Vector2
	if index < _points.size() - 1:
		tangent = point - _points[index + 1]
	else:
		tangent = _points[index - 1] - point

	if tangent.length_squared() < 0.001:
		return point

	tangent = tangent.normalized()
	var perpendicular := Vector2(-tangent.y, tangent.x)
	var t: float = float(index) / float(_points.size() - 1)
	var envelope: float = smoothstep(0.02, 0.32, t)
	var wave: float = sin(_trail_time * 2.1 - t * 8.0)
	var secondary_wave: float = sin(_trail_time * 1.25 + t * 5.5 + 0.8)
	var drift: float = (wave * 0.7 + secondary_wave * 0.3) * (0.5 + 1.8 * t) * envelope

	# The newest sample is the ball centre. Move just this head point backward
	# along the travel direction so the visible V begins at the orb's trailing
	# surface instead of emerging from its luminous core.
	var head_offset: float = trail_head_offset if index == 0 and apply_head_offset else 0.0
	return point - tangent * head_offset + perpendicular * drift



func _update_unified_comet_shape() -> void:
	if _unified_shape == null or _points.size() < 2:
		return

	# Use the same animated trail history, but keep the true ball-centre sample
	# so the shared silhouette continues underneath the orb rather than starting
	# at a separately offset trail point.
	var path: Array[Vector2] = []
	for i in range(_points.size()):
		path.append(_get_animated_trail_point(i, false))

	var cumulative_distances: Array[float] = [0.0]
	var total_distance: float = 0.0
	for i in range(1, path.size()):
		total_distance += path[i - 1].distance_to(path[i])
		cumulative_distances.append(total_distance)

	if total_distance < 0.01:
		_unified_shape.polygon = PackedVector2Array()
		_unified_shape.uv = PackedVector2Array()
		_clear_shed_geometry_pieces()
		if _unified_contour != null:
			_unified_contour.clear_points()
		return

	var tangents: Array[Vector2] = []
	var normals: Array[Vector2] = []
	var half_widths: Array[float] = []
	for i in range(path.size()):
		var tangent: Vector2
		if i == 0:
			tangent = path[1] - path[0]
		elif i == path.size() - 1:
			tangent = path[i] - path[i - 1]
		else:
			tangent = path[i + 1] - path[i - 1]

		if tangent.length_squared() < 0.001:
			tangent = Vector2.DOWN
		else:
			tangent = tangent.normalized()

		var normal := Vector2(-tangent.y, tangent.x)
		tangents.append(tangent)
		normals.append(normal)

		var progress: float = cumulative_distances[i] / total_distance
		var width_factor: float = 1.0
		if _trail_aura.width_curve != null:
			width_factor = _trail_aura.width_curve.sample_baked(progress)
		# Keep the real trail width at the root. The contour will be clipped to
		# the ball's rim at the exact edge intersections below, not widened to
		# the ball radius at its left and right sides.
		var line_half_width: float = _trail_aura.width * width_factor * 0.5
		half_widths.append(line_half_width)

	var upper_edge_points: Array[Vector2] = []
	var lower_edge_points: Array[Vector2] = []
	for i in range(path.size()):
		upper_edge_points.append(path[i] + normals[i] * half_widths[i])
		lower_edge_points.append(path[i] - normals[i] * half_widths[i])

	var polygon_points := PackedVector2Array()
	var polygon_uvs := PackedVector2Array()
	var root_direction: Vector2 = tangents[0]
	var root_normal: Vector2 = normals[0]
	var use_geometric_shedding: bool = shedding_enabled and total_distance >= 70.0
	var connected_end_distance: float = total_distance
	if use_geometric_shedding:
		connected_end_distance = total_distance * SHED_CONNECTED_END_PROGRESS

	# Keep the orb and upper neck as one coherent piece. In shedding mode the
	# parent silhouette ends here; the lower half is rebuilt from separate
	# Polygon2D islands with real transparent gaps between their boundaries.
	for arc_index in range(UNIFIED_HEAD_ARC_SEGMENTS + 1):
		var arc_t: float = float(arc_index) / float(UNIFIED_HEAD_ARC_SEGMENTS)
		var angle: float = PI * 0.5 + PI * arc_t
		var world_point: Vector2 = (
			path[0]
			+ root_direction * _ball_surface_radius * cos(angle)
			+ root_normal * _ball_surface_radius * sin(angle)
		)
		polygon_points.append(_unified_shape.to_local(world_point))
		polygon_uvs.append(Vector2(0.0, arc_t))

	if use_geometric_shedding:
		# Add the surviving connected section's right edge up to its cut plane.
		for i in range(1, path.size() - 1):
			if cumulative_distances[i] >= connected_end_distance:
				break
			var right_point: Vector2 = path[i] - normals[i] * half_widths[i]
			polygon_points.append(_unified_shape.to_local(right_point))
			polygon_uvs.append(Vector2(cumulative_distances[i] / total_distance, 1.0))

		var connected_cut: Dictionary = _sample_trail_cross_section(
			connected_end_distance, path, cumulative_distances, tangents, normals, half_widths
		)
		var cut_position: Vector2 = connected_cut["position"]
		var cut_normal: Vector2 = connected_cut["normal"]
		var cut_width: float = connected_cut["half_width"]
		var cut_uv_x: float = connected_end_distance / total_distance
		polygon_points.append(_unified_shape.to_local(cut_position - cut_normal * cut_width))
		polygon_uvs.append(Vector2(cut_uv_x, 1.0))
		polygon_points.append(_unified_shape.to_local(cut_position + cut_normal * cut_width))
		polygon_uvs.append(Vector2(cut_uv_x, 0.0))

		for i in range(path.size() - 2, 0, -1):
			if cumulative_distances[i] >= connected_end_distance:
				continue
			var left_point: Vector2 = path[i] + normals[i] * half_widths[i]
			polygon_points.append(_unified_shape.to_local(left_point))
			polygon_uvs.append(Vector2(cumulative_distances[i] / total_distance, 0.0))

		_update_shed_geometry_pieces(
			path, cumulative_distances, total_distance, tangents, normals, half_widths
		)
	else:
		# Fallback preserves the original continuous silhouette when shedding
		# is disabled, making this experiment easy to compare and roll back.
		for i in range(1, path.size() - 1):
			var right_point: Vector2 = path[i] - normals[i] * half_widths[i]
			polygon_points.append(_unified_shape.to_local(right_point))
			polygon_uvs.append(Vector2(cumulative_distances[i] / total_distance, 1.0))

		polygon_points.append(_unified_shape.to_local(path[path.size() - 1]))
		polygon_uvs.append(Vector2(1.0, 0.5))

		for i in range(path.size() - 2, 0, -1):
			var left_point: Vector2 = path[i] + normals[i] * half_widths[i]
			polygon_points.append(_unified_shape.to_local(left_point))
			polygon_uvs.append(Vector2(cumulative_distances[i] / total_distance, 0.0))

		_clear_shed_geometry_pieces()
		_sync_shed_gap_materials(cumulative_distances, total_distance)

	_unified_shape.polygon = polygon_points
	_unified_shape.uv = polygon_uvs

	# Draw only the part of each flank that is outside the orb. Both ends begin
	# at true circle intersections on the bright rim ridge, not at the ball's
	# left/right equator and not under the ball sprite.
	if _unified_contour != null:
		var contour_radius: float = _ball_surface_radius * ORB_RIM_CENTER_RADIUS_RATIO
		var exposed_upper: Array[Vector2] = _get_exposed_flank_points(
			upper_edge_points, path[0], contour_radius
		)
		var exposed_lower: Array[Vector2] = _get_exposed_flank_points(
			lower_edge_points, path[0], contour_radius
		)
		var contour_points := PackedVector2Array()
		if exposed_upper.size() >= 2 and exposed_lower.size() >= 2:
			for point in exposed_upper:
				contour_points.append(_unified_shape.to_local(point))
			# The upper flank already contributes the tail tip; return along the
			# lower flank without duplicating that shared tip vertex.
			for point_index in range(exposed_lower.size() - 2, -1, -1):
				contour_points.append(
					_unified_shape.to_local(exposed_lower[point_index])
				)
		_unified_contour.points = contour_points

	# A confirmed landing starts three real pieces, with two short stagger gaps.
	# Each release happens only after this frame's source polygons are rebuilt.
	if _pending_landing_shed:
		_pending_landing_shed = false
		_landing_burst_remaining = LANDING_BURST_FRAGMENT_COUNT
		_landing_burst_timer = 0.0
		_landing_burst_last_progress = -1.0

	if _landing_burst_remaining > 0 and _landing_burst_timer <= 0.0:
		var spawned: bool = _spawn_shed_fragment(
			path, cumulative_distances, total_distance, tangents, normals, half_widths
		)
		if spawned:
			_landing_burst_remaining -= 1
			if _landing_burst_remaining > 0:
				_landing_burst_timer = LANDING_BURST_INTERVAL
		else:
			# Do not leave a burst waiting forever if usable source material is
			# unavailable or all three persistent gap slots are already occupied.
			_landing_burst_remaining = 0
			_landing_burst_last_progress = -1.0


func _spawn_shed_fragment(
	path: Array[Vector2],
	cumulative_distances: Array[float],
	total_distance: float,
	tangents: Array[Vector2],
	normals: Array[Vector2],
	half_widths: Array[float]
) -> bool:
	if (
		not shedding_enabled
		or path.size() < 16
		or total_distance < 105.0
		or _detached_shed_fragments.size() >= 14
		or _shed_break_events.size() >= MAX_ACTIVE_SHED_BREAKS
		or _shed_piece_ranges.is_empty()
	):
		return false

	# Candidates are the actual lower-tail polygons currently visible in the
	# scene. We clone one of those exact meshes instead of inventing a generic
	# shard, then lock its source range out of the living trail.
	var candidates: Array[Dictionary] = []
	for piece_range in _shed_piece_ranges:
		var progress: float = float(piece_range["progress"])
		var source_piece := piece_range["node"] as Polygon2D
		if progress >= 0.48 and progress <= 0.78 and is_instance_valid(source_piece) and source_piece.visible:
			candidates.append(piece_range)
	if candidates.is_empty():
		return false

	# Start near the middle of the lower tail, then take neighboring islands in
	# the same direction. This makes one landing read as a compact material burst.
	var selected: Dictionary = {}
	if _landing_burst_last_progress < 0.0:
		for candidate in candidates:
			var candidate_progress: float = float(candidate["progress"])
			if (
				selected.is_empty()
				or absf(candidate_progress - 0.62)
				< absf(float(selected["progress"]) - 0.62)
			):
				selected = candidate
	else:
		for candidate in candidates:
			var candidate_progress: float = float(candidate["progress"])
			if candidate_progress <= _landing_burst_last_progress + 0.002:
				continue
			if (
				selected.is_empty()
				or candidate_progress < float(selected["progress"])
			):
				selected = candidate

		# Near the tail limit there may be no candidate farther down the stream.
		# In that case, take the nearest unbroken island just above the previous one.
		if selected.is_empty():
			for candidate in candidates:
				var candidate_progress_before: float = float(candidate["progress"])
				if candidate_progress_before >= _landing_burst_last_progress - 0.002:
					continue
				if (
					selected.is_empty()
					or candidate_progress_before > float(selected["progress"])
				):
					selected = candidate

	if selected.is_empty():
		return false
	var source_piece := selected["node"] as Polygon2D
	if source_piece.polygon.size() < 4:
		return false

	var start_id: int = int(selected["start_id"])
	var end_id: int = int(selected["end_id"])
	var start_sample_index: int = _point_ids.find(start_id)
	var end_sample_index: int = _point_ids.find(end_id)
	if start_sample_index < 0 or end_sample_index < 0:
		return false
	var piece_length: float = (
		float(selected["end_distance"]) - float(selected["start_distance"])
	)
	var start_skew: float = minf(piece_length * 0.32, 5.0)
	var end_skew: float = minf(piece_length * 0.28, 4.5)
	var start_offset: float = (
		float(selected["start_distance"]) - cumulative_distances[start_sample_index]
	)
	var end_offset: float = (
		float(selected["end_distance"]) - cumulative_distances[end_sample_index]
	)

	var world_root: Node2D = get_tree().current_scene as Node2D
	if world_root == null:
		world_root = get_parent() as Node2D
	if world_root == null:
		return false

	var world_vertices: Array[Vector2] = []
	var centroid_global := Vector2.ZERO
	for local_vertex in source_piece.polygon:
		var global_vertex: Vector2 = source_piece.to_global(local_vertex)
		world_vertices.append(global_vertex)
		centroid_global += global_vertex
	centroid_global /= float(world_vertices.size())

	var detached_polygon := PackedVector2Array()
	for global_vertex in world_vertices:
		detached_polygon.append(global_vertex - centroid_global)

	var shard := Polygon2D.new()
	shard.name = "DetachedCometBodyPiece"
	shard.z_as_relative = false
	shard.z_index = -2
	shard.polygon = detached_polygon
	shard.uv = source_piece.uv.duplicate()
	shard.material = _detached_piece_material if _detached_piece_material != null else source_piece.material
	world_root.add_child(shard)
	shard.global_position = centroid_global
	shard.global_rotation = 0.0

	_shed_break_events.append({
		"start_id": start_id,
		"end_id": end_id,
		"start_offset": start_offset,
		"end_offset": end_offset,
		"start_skew": start_skew,
		"end_skew": end_skew
	})

	# Remove this very section immediately. Its anchor IDs keep the matching
	# gap in the trail history as new samples are added at the orb end.
	source_piece.visible = false

	var source_distance: float = (
		float(selected["start_distance"]) + float(selected["end_distance"])
	) * 0.5
	var source_index: int = _nearest_trail_sample_index(
		source_distance, cumulative_distances
	)
	var sequence_value: float = float(_shed_sequence)
	var side: float = -1.0 if _shed_sequence % 2 == 0 else 1.0
	var outward_speed: float = lerpf(24.0, 44.0, absf(sin(sequence_value * 17.13 + 2.7)))
	var drift_speed: float = lerpf(9.0, 22.0, absf(sin(sequence_value * 6.73 + 1.4)))
	var lifetime: float = lerpf(0.42, 0.70, absf(sin(sequence_value * 3.91 + 0.8)))
	var angular_velocity: float = sin(sequence_value * 8.31 + 0.9) * 3.0
	var velocity: Vector2 = (
		normals[source_index] * side * outward_speed
		+ tangents[source_index] * drift_speed
	)
	_detached_shed_fragments.append({
		"node": shard,
		"velocity": velocity,
		"age": 0.0,
		"lifetime": lifetime,
		"angular_velocity": angular_velocity,
		"base_alpha": 1.0
	})
	_shed_sequence += 1
	_landing_burst_last_progress = float(selected["progress"])
	_sync_shed_gap_materials(cumulative_distances, total_distance)
	return true


func _update_detached_shed_fragments(delta: float) -> void:
	for fragment_index in range(_detached_shed_fragments.size() - 1, -1, -1):
		var fragment: Dictionary = _detached_shed_fragments[fragment_index]
		var shard := fragment.get("node") as Polygon2D
		if not is_instance_valid(shard):
			_detached_shed_fragments.remove_at(fragment_index)
			continue

		var age: float = float(fragment["age"]) + delta
		var lifetime: float = float(fragment["lifetime"])
		var velocity: Vector2 = fragment["velocity"]
		velocity.y += 10.0 * delta
		velocity *= maxf(0.0, 1.0 - delta * 0.8)
		shard.global_position += velocity * delta
		shard.rotation += float(fragment["angular_velocity"]) * delta
		var fade: float = 1.0 - smoothstep(lifetime * 0.18, lifetime, age)
		var tint: Color = shard.modulate
		tint.a = float(fragment["base_alpha"]) * fade
		shard.modulate = tint

		fragment["age"] = age
		fragment["velocity"] = velocity
		if age >= lifetime:
			shard.queue_free()
			_detached_shed_fragments.remove_at(fragment_index)
		else:
			_detached_shed_fragments[fragment_index] = fragment


func _initialize_shed_geometry_pieces() -> void:
	if _shed_geometry_container == null:
		return
	var base_material := _unified_shape.material as ShaderMaterial
	if base_material != null:
		_shed_piece_material = base_material.duplicate() as ShaderMaterial
		_shed_piece_material.set_shader_parameter("solid_piece", 1.0)
		_shed_piece_material.set_shader_parameter("shedding_amount", 1.0)
		_detached_piece_material = _shed_piece_material.duplicate() as ShaderMaterial
		_detached_piece_material.set_shader_parameter("shed_gap_0", Vector4(-1.0, -1.0, 0.0, 0.0))
		_detached_piece_material.set_shader_parameter("shed_gap_1", Vector4(-1.0, -1.0, 0.0, 0.0))
		_detached_piece_material.set_shader_parameter("shed_gap_2", Vector4(-1.0, -1.0, 0.0, 0.0))

	for piece_index in range(SHED_GEOMETRY_PIECE_CAPACITY):
		var piece := Polygon2D.new()
		piece.name = "ShedTrailPiece_%02d" % piece_index
		piece.z_index = -1
		piece.visible = false
		piece.material = _shed_piece_material
		_shed_geometry_container.add_child(piece)
		_shed_geometry_pieces.append(piece)


func _clear_shed_geometry_pieces() -> void:
	_shed_piece_ranges.clear()
	for piece in _shed_geometry_pieces:
		piece.polygon = PackedVector2Array()
		piece.uv = PackedVector2Array()
		piece.visible = false


func _sample_trail_cross_section(
	target_distance: float,
	path: Array[Vector2],
	cumulative_distances: Array[float],
	tangents: Array[Vector2],
	normals: Array[Vector2],
	half_widths: Array[float]
) -> Dictionary:
	var right_index: int = 1
	while right_index < cumulative_distances.size() - 1 and cumulative_distances[right_index] < target_distance:
		right_index += 1
	var left_index: int = maxi(right_index - 1, 0)
	var span: float = maxf(
		cumulative_distances[right_index] - cumulative_distances[left_index],
		0.001
	)
	var blend: float = clampf(
		(target_distance - cumulative_distances[left_index]) / span,
		0.0,
		1.0
	)
	var center: Vector2 = path[left_index].lerp(path[right_index], blend)
	var tangent: Vector2 = tangents[left_index].lerp(tangents[right_index], blend).normalized()
	var normal: Vector2 = normals[left_index].lerp(normals[right_index], blend).normalized()
	var half_width: float = lerpf(half_widths[left_index], half_widths[right_index], blend)
	return {
		"position": center,
		"tangent": tangent,
		"normal": normal,
		"half_width": half_width
	}


func _append_shed_edge_sample(
	points: PackedVector2Array,
	uvs: PackedVector2Array,
	world_position: Vector2,
	progress: float,
	across: float
) -> void:
	points.append(_shed_geometry_container.to_local(world_position))
	uvs.append(Vector2(progress, across))


func _build_shed_piece_polygon(
	piece: Polygon2D,
	start_distance: float,
	end_distance: float,
	path: Array[Vector2],
	cumulative_distances: Array[float],
	total_distance: float,
	tangents: Array[Vector2],
	normals: Array[Vector2],
	half_widths: Array[float]
) -> void:
	var polygon_points := PackedVector2Array()
	var polygon_uvs := PackedVector2Array()
	var length: float = end_distance - start_distance
	var start_skew: float = minf(length * 0.32, 5.0)
	var end_skew: float = minf(length * 0.28, 4.5)

	# Asymmetric offsets make both ends read as stronger angled cuts. The same
	# skew values are stored in the gap event so every visual layer matches them.
	var start_right_distance: float = start_distance + start_skew
	var start_left_distance: float = start_distance + start_skew * 0.12
	var end_right_distance: float = end_distance - end_skew
	var end_left_distance: float = end_distance - end_skew * 0.12

	var start_right_section: Dictionary = _sample_trail_cross_section(
		start_right_distance, path, cumulative_distances, tangents, normals, half_widths
	)
	var start_left_section: Dictionary = _sample_trail_cross_section(
		start_left_distance, path, cumulative_distances, tangents, normals, half_widths
	)
	var end_right_section: Dictionary = _sample_trail_cross_section(
		end_right_distance, path, cumulative_distances, tangents, normals, half_widths
	)
	var end_left_section: Dictionary = _sample_trail_cross_section(
		end_left_distance, path, cumulative_distances, tangents, normals, half_widths
	)

	var start_right: Vector2 = start_right_section["position"] - start_right_section["normal"] * float(start_right_section["half_width"])
	var start_left: Vector2 = start_left_section["position"] + start_left_section["normal"] * float(start_left_section["half_width"])
	var end_right: Vector2 = end_right_section["position"] - end_right_section["normal"] * float(end_right_section["half_width"])
	var end_left: Vector2 = end_left_section["position"] + end_left_section["normal"] * float(end_left_section["half_width"])

	_append_shed_edge_sample(
		polygon_points, polygon_uvs, start_right,
		start_right_distance / total_distance, 1.0
	)
	for i in range(1, path.size() - 1):
		if cumulative_distances[i] > start_right_distance and cumulative_distances[i] < end_right_distance:
			var right_point: Vector2 = path[i] - normals[i] * half_widths[i]
			_append_shed_edge_sample(
				polygon_points, polygon_uvs, right_point,
				cumulative_distances[i] / total_distance, 1.0
			)
	_append_shed_edge_sample(
		polygon_points, polygon_uvs, end_right,
		end_right_distance / total_distance, 1.0
	)
	_append_shed_edge_sample(
		polygon_points, polygon_uvs, end_left,
		end_left_distance / total_distance, 0.0
	)
	for i in range(path.size() - 2, 0, -1):
		if cumulative_distances[i] < end_left_distance and cumulative_distances[i] > start_left_distance:
			var left_point: Vector2 = path[i] + normals[i] * half_widths[i]
			_append_shed_edge_sample(
				polygon_points, polygon_uvs, left_point,
				cumulative_distances[i] / total_distance, 0.0
			)
	_append_shed_edge_sample(
		polygon_points, polygon_uvs, start_left,
		start_left_distance / total_distance, 0.0
	)

	piece.polygon = polygon_points
	piece.uv = polygon_uvs
	piece.material = _shed_piece_material
	piece.visible = polygon_points.size() >= 4


func _update_shed_geometry_pieces(
	path: Array[Vector2],
	cumulative_distances: Array[float],
	total_distance: float,
	tangents: Array[Vector2],
	normals: Array[Vector2],
	half_widths: Array[float]
) -> void:
	_clear_shed_geometry_pieces()
	_prune_shed_break_events()
	if _shed_geometry_pieces.is_empty() or total_distance < 38.0 or _shed_geometry_container == null:
		_sync_shed_gap_materials(cumulative_distances, total_distance)
		return

	# The connected head transitions into a nearly continuous segmented tail.
	# Keep the tiny seam and overlap at the neck, but carve every live landing
	# break out of the geometry itself rather than hoping a whole generated
	# island happens to overlap it after the trail is rebuilt.
	var cursor: float = maxf(
		total_distance * SHED_CONNECTED_END_PROGRESS - 3.5,
		0.0
	)
	var tail_limit: float = total_distance * 0.985
	var slot_index: int = 0
	while cursor < tail_limit and slot_index < _shed_geometry_pieces.size():
		var seed_a: float = absf(sin(float(slot_index) * 15.731 + 2.17))
		var seed_b: float = absf(sin(float(slot_index) * 9.173 + 5.61))
		var piece_length: float = clampf(total_distance * lerpf(0.055, 0.095, seed_a), 8.0, 24.0)
		var piece_end: float = minf(cursor + piece_length, tail_limit)
		if piece_end - cursor < 5.0:
			break

		# If a live break intersects this island, end the island at the near
		# boundary or jump across the hole. No rebuilt polygon can span the gap.
		var overlapping_break: Vector2 = _find_overlapping_shed_break(
			cursor, piece_end, cumulative_distances
		)
		if overlapping_break.x >= 0.0:
			if overlapping_break.x > cursor + 5.0:
				piece_end = minf(piece_end, overlapping_break.x)
			else:
				cursor = minf(
					maxf(overlapping_break.y + 0.65, cursor + 1.0),
					tail_limit
				)
				slot_index += 1
				continue

		if piece_end - cursor < 5.0:
			if overlapping_break.x >= 0.0:
				cursor = minf(
					maxf(overlapping_break.y + 0.65, cursor + 1.0),
					tail_limit
				)
				slot_index += 1
				continue
			break

		var start_sample_index: int = _nearest_trail_sample_index(cursor, cumulative_distances)
		var end_sample_index: int = _nearest_trail_sample_index(piece_end, cumulative_distances)
		if end_sample_index <= start_sample_index:
			if start_sample_index < _point_ids.size() - 1:
				end_sample_index = start_sample_index + 1
			else:
				start_sample_index = maxi(start_sample_index - 1, 0)

		var piece: Polygon2D = _shed_geometry_pieces[slot_index]
		_build_shed_piece_polygon(
			piece,
			cursor,
			piece_end,
			path,
			cumulative_distances,
			total_distance,
			tangents,
			normals,
			half_widths
		)
		_shed_piece_ranges.append({
			"node": piece,
			"start_id": _point_ids[start_sample_index],
			"end_id": _point_ids[end_sample_index],
			"start_distance": cursor,
			"end_distance": piece_end,
			"progress": (cursor + piece_end) * 0.5 / total_distance,
			"slot": slot_index
		})

		cursor = piece_end + clampf(lerpf(0.25, 0.65, seed_b), 0.2, 0.8)
		slot_index += 1

	_sync_shed_gap_materials(cumulative_distances, total_distance)


func _nearest_trail_sample_index(
	target_distance: float,
	cumulative_distances: Array[float]
) -> int:
	var closest_index: int = 0
	var closest_error: float = INF
	for i in range(cumulative_distances.size()):
		var error: float = absf(cumulative_distances[i] - target_distance)
		if error < closest_error:
			closest_error = error
			closest_index = i
	return closest_index


func _prune_shed_break_events() -> void:
	for event_index in range(_shed_break_events.size() - 1, -1, -1):
		var event: Dictionary = _shed_break_events[event_index]
		var start_index: int = _point_ids.find(int(event["start_id"]))
		var end_index: int = _point_ids.find(int(event["end_id"]))
		# A gap belongs to the exact source interval. Once either boundary sample
		# leaves history, that interval has aged out and its mask is removed.
		if start_index < 0 or end_index < 0:
			_shed_break_events.remove_at(event_index)


func _shed_event_distance_bounds(
	event: Dictionary,
	cumulative_distances: Array[float]
) -> Vector2:
	var start_index: int = _point_ids.find(int(event["start_id"]))
	var end_index: int = _point_ids.find(int(event["end_id"]))
	if start_index < 0 or end_index < 0 or cumulative_distances.is_empty():
		return Vector2(-1.0, -1.0)

	var max_distance: float = cumulative_distances[cumulative_distances.size() - 1]
	var start_distance: float = clampf(
		cumulative_distances[start_index] + float(event.get("start_offset", 0.0)),
		0.0,
		max_distance
	)
	var end_distance: float = clampf(
		cumulative_distances[end_index] + float(event.get("end_offset", 0.0)),
		0.0,
		max_distance
	)
	if end_distance < start_distance:
		var swap_distance: float = start_distance
		start_distance = end_distance
		end_distance = swap_distance
	return Vector2(start_distance, end_distance)


func _find_overlapping_shed_break(
	interval_start: float,
	interval_end: float,
	cumulative_distances: Array[float]
) -> Vector2:
	var closest_break := Vector2(-1.0, -1.0)
	for event in _shed_break_events:
		var bounds: Vector2 = _shed_event_distance_bounds(event, cumulative_distances)
		if bounds.x < 0.0 or bounds.y <= bounds.x:
			continue
		if bounds.x >= interval_end or bounds.y <= interval_start:
			continue
		if closest_break.x < 0.0 or bounds.x < closest_break.x:
			closest_break = bounds
	return closest_break


func _empty_shed_gap_intervals() -> Array[Vector4]:
	return [
		Vector4(-1.0, -1.0, 0.0, 0.0),
		Vector4(-1.0, -1.0, 0.0, 0.0),
		Vector4(-1.0, -1.0, 0.0, 0.0)
	]


func _build_path_gap_intervals(
	cumulative_distances: Array[float],
	total_distance: float
) -> Array[Vector4]:
	var intervals: Array[Vector4] = _empty_shed_gap_intervals()
	if not shedding_enabled or total_distance <= 0.01:
		return intervals

	for event_index in range(mini(_shed_break_events.size(), MAX_ACTIVE_SHED_BREAKS)):
		var event: Dictionary = _shed_break_events[event_index]
		var bounds: Vector2 = _shed_event_distance_bounds(event, cumulative_distances)
		if bounds.x < 0.0 or bounds.y - bounds.x <= 0.01:
			continue

		var start_skew: float = float(event.get("start_skew", 0.0))
		var end_skew: float = float(event.get("end_skew", 0.0))
		var mask_start: float = maxf(bounds.x - SHED_GAP_MASK_PADDING, 0.0)
		var mask_end: float = minf(bounds.y + SHED_GAP_MASK_PADDING, total_distance)
		intervals[event_index] = Vector4(
			mask_start / total_distance,
			mask_end / total_distance,
			start_skew / total_distance,
			end_skew / total_distance
		)
	return intervals


func _map_path_distance_to_line_uv(
	target_distance: float,
	path_cumulative_distances: Array[float],
	line_cumulative_distances: Array[float],
	begin_cap_offset: float,
	line_total_distance: float
) -> float:
	if (
		path_cumulative_distances.size() < 2
		or line_cumulative_distances.size() != path_cumulative_distances.size()
		or line_total_distance <= 0.01
	):
		return 0.0

	var clamped_distance: float = clampf(
		target_distance,
		0.0,
		path_cumulative_distances[path_cumulative_distances.size() - 1]
	)
	var right_index: int = 1
	while (
		right_index < path_cumulative_distances.size() - 1
		and path_cumulative_distances[right_index] < clamped_distance
	):
		right_index += 1
	var left_index: int = right_index - 1
	var path_span: float = maxf(
		path_cumulative_distances[right_index] - path_cumulative_distances[left_index],
		0.001
	)
	var blend: float = clampf(
		(clamped_distance - path_cumulative_distances[left_index]) / path_span,
		0.0,
		1.0
	)
	var line_distance: float = lerpf(
		line_cumulative_distances[left_index],
		line_cumulative_distances[right_index],
		blend
	)
	return clampf((begin_cap_offset + line_distance) / line_total_distance, 0.0, 1.0)


func _build_line_gap_intervals(
	line: Line2D,
	path_cumulative_distances: Array[float],
	total_path_distance: float
) -> Array[Vector4]:
	var intervals: Array[Vector4] = _empty_shed_gap_intervals()
	if (
		not shedding_enabled
		or line == null
		or path_cumulative_distances.size() < 2
		or total_path_distance <= 0.01
	):
		return intervals

	var line_points: PackedVector2Array = line.points
	if line_points.size() != path_cumulative_distances.size():
		# Fail closed rather than applying body-space UVs to a different line mesh.
		return intervals

	var line_cumulative_distances: Array[float] = [0.0]
	var line_path_distance: float = 0.0
	for point_index in range(1, line_points.size()):
		line_path_distance += line_points[point_index - 1].distance_to(line_points[point_index])
		line_cumulative_distances.append(line_path_distance)

	var head_width_factor: float = 1.0
	var tail_width_factor: float = 1.0
	if line.width_curve != null:
		head_width_factor = line.width_curve.sample_baked(0.0)
		tail_width_factor = line.width_curve.sample_baked(1.0)
	var begin_cap_offset: float = 0.0
	var end_cap_offset: float = 0.0
	if line.begin_cap_mode != Line2D.LINE_CAP_NONE:
		begin_cap_offset = line.width * 0.5 * head_width_factor
	if line.end_cap_mode != Line2D.LINE_CAP_NONE:
		end_cap_offset = line.width * 0.5 * tail_width_factor
	var line_total_distance: float = (
		line_path_distance + begin_cap_offset + end_cap_offset
	)
	if line_total_distance <= 0.01:
		return intervals

	for event_index in range(mini(_shed_break_events.size(), MAX_ACTIVE_SHED_BREAKS)):
		var event: Dictionary = _shed_break_events[event_index]
		var bounds: Vector2 = _shed_event_distance_bounds(event, path_cumulative_distances)
		if bounds.x < 0.0 or bounds.y - bounds.x <= 0.01:
			continue

		# Convert the same physical break into this Line2D's own UV space. This
		# handles its point positions, width curve, and round/box cap distance.
		var raw_start: float = maxf(bounds.x - SHED_GAP_MASK_PADDING, 0.0)
		var raw_end: float = minf(
			bounds.y + SHED_GAP_MASK_PADDING,
			total_path_distance
		)
		var start_skew: float = float(event.get("start_skew", 0.0))
		var end_skew: float = float(event.get("end_skew", 0.0))
		var start_u: float = _map_path_distance_to_line_uv(
			raw_start,
			path_cumulative_distances,
			line_cumulative_distances,
			begin_cap_offset,
			line_total_distance
		)
		var end_u: float = _map_path_distance_to_line_uv(
			raw_end,
			path_cumulative_distances,
			line_cumulative_distances,
			begin_cap_offset,
			line_total_distance
		)
		var start_skew_u: float = (
			_map_path_distance_to_line_uv(
				minf(raw_start + start_skew, total_path_distance),
				path_cumulative_distances,
				line_cumulative_distances,
				begin_cap_offset,
				line_total_distance
			) - start_u
		)
		var end_skew_u: float = (
			end_u - _map_path_distance_to_line_uv(
				maxf(raw_end - end_skew, 0.0),
				path_cumulative_distances,
				line_cumulative_distances,
				begin_cap_offset,
				line_total_distance
			)
		)
		intervals[event_index] = Vector4(
			start_u,
			end_u,
			maxf(start_skew_u, 0.0),
			maxf(end_skew_u, 0.0)
		)
	return intervals


func _set_shed_gap_uniforms(
	material: ShaderMaterial,
	intervals: Array[Vector4]
) -> void:
	if material == null:
		return
	material.set_shader_parameter("shed_gap_0", intervals[0])
	material.set_shader_parameter("shed_gap_1", intervals[1])
	material.set_shader_parameter("shed_gap_2", intervals[2])


func _sync_shed_gap_materials(
	cumulative_distances: Array[float],
	total_distance: float
) -> void:
	var path_intervals: Array[Vector4] = _build_path_gap_intervals(
		cumulative_distances, total_distance
	)
	var energy_intervals: Array[Vector4] = _build_line_gap_intervals(
		_energy_line, cumulative_distances, total_distance
	)
	var aura_intervals: Array[Vector4] = _build_line_gap_intervals(
		_trail_aura, cumulative_distances, total_distance
	)

	var unified_material: ShaderMaterial = null
	if _unified_shape != null:
		unified_material = _unified_shape.material as ShaderMaterial
	var energy_material: ShaderMaterial = null
	if _energy_line != null:
		energy_material = _energy_line.material as ShaderMaterial
	var aura_material: ShaderMaterial = null
	if _trail_aura != null:
		aura_material = _trail_aura.material as ShaderMaterial

	# The polygon islands are already physically carved by the geometry builder.
	# Keep their shader unmasked so an unrelated UV edge can never redraw or
	# accidentally shrink the cut. The detached clone has its own unmasked mat.
	_set_shed_gap_uniforms(unified_material, path_intervals)
	_set_shed_gap_uniforms(energy_material, energy_intervals)
	_set_shed_gap_uniforms(aura_material, aura_intervals)
	_set_shed_gap_uniforms(_shed_piece_material, _empty_shed_gap_intervals())


func _apply_visual_palette() -> void:
	var energy_head: Color
	var energy_tail: Color
	var aura_head: Color
	var aura_tail: Color
	var soft_particle_tint: Color
	var diamond_tint: Color
	var square_tint: Color
	var shard_tint: Color
	var contour_color: Color

	if visual_palette == 1:
		energy_head = Color(0.98, 0.72, 1.0, 1.0)
		energy_tail = Color(0.34, 0.045, 0.82, 1.0)
		aura_head = Color(0.72, 0.22, 1.0, 1.0)
		aura_tail = Color(0.13, 0.02, 0.38, 1.0)
		soft_particle_tint = Color(0.58, 0.32, 0.90, 0.76)
		diamond_tint = Color(0.98, 0.52, 1.20, 1.0)
		square_tint = Color(0.58, 0.20, 1.12, 0.96)
		shard_tint = Color(1.0, 0.70, 1.25, 1.0)
		contour_color = Color(3.0, 0.61, 5.8, 1.0)
	else:
		energy_head = Color(0.72, 0.94, 1.0, 1.0)
		energy_tail = Color(0.035, 0.16, 0.82, 1.0)
		aura_head = Color(0.12, 0.58, 1.0, 1.0)
		aura_tail = Color(0.008, 0.035, 0.25, 1.0)
		soft_particle_tint = Color(0.18, 0.48, 0.82, 0.72)
		diamond_tint = Color(0.40, 0.78, 1.25, 1.0)
		square_tint = Color(0.12, 0.42, 1.18, 0.96)
		shard_tint = Color(0.62, 0.90, 1.30, 1.0)
		contour_color = Color(0.20, 2.4, 5.8, 1.0)

	# Duplicate materials locally so palette changes don't mutate shared resources.
	var orb_material := _ball_visual.material as ShaderMaterial
	if orb_material != null:
		orb_material = orb_material.duplicate() as ShaderMaterial
		orb_material.set_shader_parameter("palette_mode", visual_palette)
		_ball_visual.material = orb_material

	if _unified_shape != null:
		var unified_material := _unified_shape.material as ShaderMaterial
		if unified_material != null:
			unified_material = unified_material.duplicate() as ShaderMaterial
			unified_material.set_shader_parameter("palette_mode", visual_palette)
			unified_material.set_shader_parameter("shedding_amount", 1.0 if shedding_enabled else 0.0)
			_unified_shape.material = unified_material

	var energy_material := _energy_line.material as ShaderMaterial
	if energy_material != null:
		energy_material = energy_material.duplicate() as ShaderMaterial
		energy_material.set_shader_parameter("palette_mode", visual_palette)
		energy_material.set_shader_parameter("shedding_amount", 1.0 if shedding_enabled else 0.0)
		_energy_line.material = energy_material

	_set_line_gradient(_energy_line, energy_head, energy_tail)
	_set_line_gradient(_trail_aura, aura_head, aura_tail)

	var aura_material := _trail_aura.material as ShaderMaterial
	if aura_material != null:
		aura_material = aura_material.duplicate() as ShaderMaterial
		aura_material.set_shader_parameter("shedding_amount", 1.0 if shedding_enabled else 0.0)
		_trail_aura.material = aura_material

	# All filaments share the contour hue; each strand's own gradient retains
	# its lower opacity so the lines feel grown from the same outer energy.
	if _unified_contour != null:
		# Same hue on both flanks; the gradient's alpha profile fades toward
		# the tip symmetrically instead of making one side darker than the other.
		_set_line_gradient(_unified_contour, contour_color, contour_color)

	# Give each fragment type a distinct but coordinated tint. The atlas
	# itself is neutral white, so these colors remain clear in both palettes.
	var soft_emitter := get_node_or_null("TrailParticles") as GPUParticles2D
	var diamond_emitter := get_node_or_null("TrailDiamonds") as GPUParticles2D
	var square_emitter := get_node_or_null("TrailSquares") as GPUParticles2D
	var shard_emitter := get_node_or_null("TrailShards") as GPUParticles2D

	if soft_emitter != null:
		soft_emitter.modulate = soft_particle_tint
	if diamond_emitter != null:
		diamond_emitter.modulate = diamond_tint
	if square_emitter != null:
		square_emitter.modulate = square_tint
	if shard_emitter != null:
		shard_emitter.modulate = shard_tint


func _set_line_gradient(
	line: Line2D,
	head_color: Color,
	tail_color: Color
) -> void:
	if line.gradient == null:
		return

	var gradient := line.gradient.duplicate() as Gradient
	for index in range(gradient.get_point_count()):
		var original: Color = gradient.get_color(index)
		var t: float = gradient.get_offset(index)
		var color: Color = head_color.lerp(tail_color, t)
		color.a = original.a
		gradient.set_color(index, color)

	line.gradient = gradient
