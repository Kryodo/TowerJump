extends Node2D

## Visual energy trail for the player ball.
## The trail is layered: a soft outer aura, a turbulent inner stream, staggered
## plasma filaments with a small terminal fork, and landing-triggered aura fragments.
## This script only controls visuals; ball movement and collision remain in ball.gd.

@export_category("Trail History")
@export var max_points: int = 27
@export var min_distance: float = 2.0
@export var max_segment_distance: float = 120.0
@export_range(0.0, 40.0, 1.0) var trail_head_offset: float = 28.0

const UNIFIED_HEAD_ARC_SEGMENTS: int = 20
const ORB_RIM_CENTER_RADIUS_RATIO: float = 0.93
const SHED_BURST_PIECE_COUNT: int = 5
const SHED_BURST_SPACING: float = 0.035

@export_category("Visual Palette")
@export_enum("Electric Blue", "Rich Violet") var visual_palette: int = 0

@export_category("Comet Shedding")
@export var shedding_enabled: bool = true

@onready var _energy_line: Line2D = $EnergyLine
@onready var _trail_aura: Line2D = $TrailAura
@onready var _unified_shape: Polygon2D = get_node_or_null("UnifiedCometShape") as Polygon2D
@onready var _unified_contour: Line2D = get_node_or_null("UnifiedCometContour") as Line2D
@onready var _ball_visual: Sprite2D = get_parent().get_node("Visual") as Sprite2D

var _points: Array[Vector2] = []
var _particle_emitters: Array[GPUParticles2D] = []
var _previous_ball_position: Vector2 = Vector2.ZERO
var _trail_time: float = 0.0
var _last_emission_direction: Vector2 = Vector2.DOWN
var _ball_surface_radius: float = 29.9
var _shed_burst_remaining: int = 0
var _shed_burst_clock: float = 0.0
var _shed_sequence: int = 0
var _detached_shed_fragments: Array[Dictionary] = []
var _aura_fragment_material: CanvasItemMaterial

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
	_initialize_aura_fragment_material()
	call_deferred("_connect_landing_feedback")
	_update_trail_lines()
	_update_rim_breath()


func _initialize_aura_fragment_material() -> void:
	# Use additive blending so the detached aura strips read as luminous energy,
	# without borrowing the main comet-body shader or changing its geometry.
	var fragment_material := CanvasItemMaterial.new()
	fragment_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_aura_fragment_material = fragment_material


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
		_shed_burst_remaining = 0
		_shed_burst_clock = 0.0
	var current_world_position: Vector2 = ball.global_position
	var movement: Vector2 = current_world_position - _previous_ball_position
	var distance_from_trail: float = movement.length()

	if _points.is_empty() or distance_from_trail > max_segment_distance:
		# Do not draw a ribbon across teleports, screen-wrap jumps, or other
		# large discontinuities in the sampled trajectory.
		_points.clear()
		_points.append(current_world_position)
	elif _points[0].distance_to(current_world_position) >= min_distance:
		_points.push_front(current_world_position)
		while _points.size() > max_points:
			_points.pop_back()

	_update_trail_lines(delta)
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


func _update_trail_lines(delta: float = 0.0) -> void:
	if _points.size() < 2:
		_energy_line.clear_points()
		_trail_aura.clear_points()
		if _unified_shape != null:
			_unified_shape.polygon = PackedVector2Array()
			_unified_shape.uv = PackedVector2Array()
		if _unified_contour != null:
			_unified_contour.clear_points()
		return

	_rebuild_trail_lines()
	_update_unified_comet_shape(delta)


func _rebuild_trail_lines() -> void:
	_energy_line.clear_points()
	_trail_aura.clear_points()
	if _points.size() < 2:
		return

	# Each ribbon stays whole and keeps its original gradient and width profile.
	for point_index in range(_points.size()):
		var energy_point: Vector2 = _get_animated_trail_point(point_index, true)
		var aura_point: Vector2 = _get_animated_trail_point(point_index, false)
		_energy_line.add_point(_energy_line.to_local(energy_point))
		_trail_aura.add_point(_trail_aura.to_local(aura_point))

	var energy_material := _energy_line.material as ShaderMaterial
	if energy_material != null:
		energy_material.set_shader_parameter("trail_progress_start", 0.0)
		energy_material.set_shader_parameter("trail_progress_scale", 1.0)


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



func _update_unified_comet_shape(delta: float = 0.0) -> void:
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

	# The living comet body always remains one uninterrupted ribbon. Landing
	# fragments are built separately from narrow strips of the outer aura only.
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

	# The trail geometry and candidate ranges have now been rebuilt for this
	# frame. Release at most one queued fragment from those fresh surviving ranges.
	_process_shed_burst(
		delta, path, cumulative_distances, total_distance, tangents, normals, half_widths
	)


func _connect_landing_feedback() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	# The main game scene owns this coordinator. Test rooms without it continue
	# to render the trail without raising any landing-triggered bursts.
	var controller := scene_root.get_node_or_null("LandingFeedbackController")
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

	# A confirmed physical landing queues one deliberate burst; no shedding is
	# driven by elapsed time while the ball is travelling between platforms.
	_shed_burst_remaining = SHED_BURST_PIECE_COUNT
	_shed_burst_clock = 0.0


func _process_shed_burst(
	delta: float,
	path: Array[Vector2],
	cumulative_distances: Array[float],
	total_distance: float,
	tangents: Array[Vector2],
	normals: Array[Vector2],
	half_widths: Array[float]
) -> void:
	if not shedding_enabled or _shed_burst_remaining <= 0:
		return

	if _shed_burst_clock > 0.0:
		_shed_burst_clock = maxf(_shed_burst_clock - delta, 0.0)
		if _shed_burst_clock > 0.0:
			return

	var previous_fragment_count: int = _detached_shed_fragments.size()
	var burst_index: int = SHED_BURST_PIECE_COUNT - _shed_burst_remaining
	_spawn_shed_fragment(
		path, cumulative_distances, total_distance, tangents, normals, half_widths,
		burst_index
	)

	# Drop a burst when there is not enough trail to make a meaningful aura strip.
	if _detached_shed_fragments.size() == previous_fragment_count:
		_shed_burst_remaining = 0
		_shed_burst_clock = 0.0
		return

	_shed_burst_remaining -= 1
	if _shed_burst_remaining > 0:
		_shed_burst_clock = SHED_BURST_SPACING


func _spawn_shed_fragment(
	path: Array[Vector2],
	cumulative_distances: Array[float],
	total_distance: float,
	tangents: Array[Vector2],
	normals: Array[Vector2],
	half_widths: Array[float],
	burst_index: int
) -> void:
	if (
		not shedding_enabled
		or path.size() < 6
		or total_distance < 55.0
		or _detached_shed_fragments.size() >= 30
		or _aura_fragment_material == null
	):
		return

	# Spread the groups along the visible trail, with a little deterministic
	# variation. They are slices of the outside edge of the aura, never the body.
	var burst_progress: float = (
		float(burst_index) / float(maxi(SHED_BURST_PIECE_COUNT - 1, 1))
	)
	var sequence_value: float = float(_shed_sequence)
	var progress: float = clampf(
		lerpf(0.22, 0.79, burst_progress)
		+ sin(sequence_value * 11.7 + 2.4) * 0.026,
		0.17,
		0.84
	)
	var center_distance: float = total_distance * progress
	var fragment_length: float = lerpf(
		18.0, 29.0, absf(sin(sequence_value * 5.31 + 1.2))
	)
	var start_distance: float = maxf(center_distance - fragment_length * 0.5, 0.5)
	var end_distance: float = minf(center_distance + fragment_length * 0.5, total_distance * 0.97)
	if end_distance - start_distance < 7.0:
		return

	# Include the path samples that lie within the fragment so its strip follows
	# bends rather than looking like a straight tile cut from the trail.
	var fragment_distances: Array[float] = [start_distance]
	for point_index in range(1, path.size() - 1):
		var sample_distance: float = cumulative_distances[point_index]
		if sample_distance > start_distance + 0.1 and sample_distance < end_distance - 0.1:
			fragment_distances.append(sample_distance)
	fragment_distances.append(end_distance)

	var side: float = -1.0 if burst_index % 2 == 0 else 1.0
	var outer_edge: Array[Vector2] = []
	var inner_edge: Array[Vector2] = []
	for distance_index in range(fragment_distances.size()):
		var sample_distance: float = fragment_distances[distance_index]
		var section: Dictionary = _sample_trail_cross_section(
			sample_distance, path, cumulative_distances, tangents, normals, half_widths
		)
		var t: float = (
			(sample_distance - start_distance) / (end_distance - start_distance)
		)
		var taper: float = lerpf(0.14, 1.0, sin(PI * t))
		var center: Vector2 = section["position"]
		var normal: Vector2 = section["normal"]
		var half_width: float = float(section["half_width"])
		outer_edge.append(center + normal * side * half_width * 0.98 * taper)
		inner_edge.append(center + normal * side * half_width * 0.54 * taper)

	var world_vertices: Array[Vector2] = []
	var centroid_global := Vector2.ZERO
	for vertex in outer_edge:
		world_vertices.append(vertex)
		centroid_global += vertex
	for reverse_index in range(inner_edge.size() - 1, -1, -1):
		var vertex: Vector2 = inner_edge[reverse_index]
		world_vertices.append(vertex)
		centroid_global += vertex

	if world_vertices.size() < 6:
		return
	centroid_global /= float(world_vertices.size())

	var fragment_polygon := PackedVector2Array()
	for vertex in world_vertices:
		fragment_polygon.append(vertex - centroid_global)

	var shard := Polygon2D.new()
	shard.name = "DetachedAuraFragment"
	shard.z_as_relative = false
	shard.z_index = -2
	shard.polygon = fragment_polygon
	shard.material = _aura_fragment_material
	shard.color = _aura_fragment_tint(progress)

	var world_root: Node2D = get_tree().current_scene as Node2D
	if world_root == null:
		world_root = get_parent() as Node2D
	if world_root == null:
		shard.queue_free()
		return
	world_root.add_child(shard)
	shard.global_position = centroid_global
	shard.global_rotation = 0.0

	var source_index: int = _nearest_trail_sample_index(center_distance, cumulative_distances)
	var outward_speed: float = lerpf(
		24.0, 44.0, absf(sin(sequence_value * 17.13 + 2.7))
	)
	var drift_speed: float = lerpf(
		9.0, 22.0, absf(sin(sequence_value * 6.73 + 1.4))
	)
	var lifetime: float = lerpf(
		0.46, 0.72, absf(sin(sequence_value * 3.91 + 0.8))
	)
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


func _aura_fragment_tint(progress: float) -> Color:
	var head_color: Color
	var tail_color: Color
	if visual_palette == 1:
		head_color = Color(0.92, 0.43, 1.35, 0.92)
		tail_color = Color(0.28, 0.045, 0.62, 0.72)
	else:
		head_color = Color(0.20, 0.72, 1.35, 0.92)
		tail_color = Color(0.025, 0.11, 0.54, 0.72)
	return head_color.lerp(tail_color, clampf(progress, 0.0, 1.0))




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


func _update_particle_emitters(
	current_world_position: Vector2,
	movement: Vector2,
	distance_from_trail: float
) -> void:
	if distance_from_trail > 0.01 and distance_from_trail <= max_segment_distance:
		_last_emission_direction = -movement.normalized()

	# Spawn geometric fragments from the back of the orb, not its centre, so
	# they appear to break away from the comet tail rather than through the ball.
	var emission_position: Vector2 = (
		current_world_position + _last_emission_direction * trail_head_offset
	)
	for emitter in _particle_emitters:
		emitter.global_position = emission_position
		var material := emitter.process_material as ParticleProcessMaterial
		if material != null:
			material.direction = Vector3(
				_last_emission_direction.x,
				_last_emission_direction.y,
				0.0
			)


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
			_unified_shape.material = unified_material

	var energy_material := _energy_line.material as ShaderMaterial
	if energy_material != null:
		energy_material = energy_material.duplicate() as ShaderMaterial
		energy_material.set_shader_parameter("palette_mode", visual_palette)
		_energy_line.material = energy_material

	_set_line_gradient(_energy_line, energy_head, energy_tail)
	_set_line_gradient(_trail_aura, aura_head, aura_tail)

	var aura_material := _trail_aura.material as ShaderMaterial
	if aura_material != null:
		aura_material = aura_material.duplicate() as ShaderMaterial
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
