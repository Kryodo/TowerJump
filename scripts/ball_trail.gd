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
const SHED_GEOMETRY_PIECE_CAPACITY: int = 12
const MAX_ACTIVE_SHED_BREAKS: int = 3
const SHED_MIN_FRAGMENT_PROGRESS: float = 0.40
const SHED_MAX_FRAGMENT_PROGRESS: float = 0.88
const SHED_RECENT_PROGRESS_SEPARATION: float = 0.13

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
var _landing_shear_pending: bool = false
var _shed_sequence: int = 0
var _recent_shed_progresses: Array[float] = []
var _detached_shed_fragments: Array[Dictionary] = []
var _shed_geometry_pieces: Array[Polygon2D] = []
var _shed_piece_ranges: Array[Dictionary] = []
var _shed_break_events: Array[Dictionary] = []
var _shed_piece_material: ShaderMaterial
var _detached_piece_material: ShaderMaterial

const SPLIT_LINE_PROFILE_STEPS: int = 16
var _energy_line_slots: Array[Line2D] = []
var _aura_line_slots: Array[Line2D] = []
var _energy_base_gradient: Gradient
var _aura_base_gradient: Gradient
var _energy_base_width_curve: Curve
var _aura_base_width_curve: Curve
var _energy_profile_gradients: Array[Gradient] = []
var _aura_profile_gradients: Array[Gradient] = []
var _energy_profile_curves: Array[Curve] = []
var _aura_profile_curves: Array[Curve] = []


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
	_initialize_split_line_pools()
	_initialize_shed_geometry_pieces()
	call_deferred("_connect_landing_feedback")
	_update_trail_lines()
	_update_rim_breath()


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
		_landing_shear_pending = false
	else:
		for event in _shed_break_events:
			event["hold_remaining"] = maxf(
				float(event.get("hold_remaining", 0.0)) - delta,
				0.0
			)
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
		_clear_shed_line_spans()
		if _unified_shape != null:
			_unified_shape.polygon = PackedVector2Array()
			_unified_shape.uv = PackedVector2Array()
		_clear_shed_geometry_pieces()
		if _unified_contour != null:
			_unified_contour.clear_points()
		return

	_rebuild_shed_line_spans()
	_update_unified_comet_shape()


func _initialize_split_line_pools() -> void:
	_energy_base_gradient = _energy_line.gradient
	_aura_base_gradient = _trail_aura.gradient
	_energy_base_width_curve = _energy_line.width_curve
	_aura_base_width_curve = _trail_aura.width_curve

	_energy_line_slots.append(_energy_line)
	_aura_line_slots.append(_trail_aura)
	_energy_profile_gradients.append(_make_profile_gradient(_energy_base_gradient))
	_aura_profile_gradients.append(_make_profile_gradient(_aura_base_gradient))
	_energy_profile_curves.append(_make_profile_curve(_energy_base_width_curve))
	_aura_profile_curves.append(_make_profile_curve(_aura_base_width_curve))

	for slot_index in range(1, MAX_ACTIVE_SHED_BREAKS + 1):
		var energy_span := _energy_line.duplicate() as Line2D
		energy_span.name = "EnergyLineSplit_%02d" % slot_index
		energy_span.clear_points()
		var source_energy_material := _energy_line.material as ShaderMaterial
		if source_energy_material != null:
			energy_span.material = source_energy_material.duplicate() as ShaderMaterial
		var energy_profile_gradient: Gradient = _make_profile_gradient(_energy_base_gradient)
		var energy_profile_curve: Curve = _make_profile_curve(_energy_base_width_curve)
		if energy_profile_gradient != null:
			energy_span.gradient = energy_profile_gradient
		if energy_profile_curve != null:
			energy_span.width_curve = energy_profile_curve
		add_child(energy_span)
		_energy_line_slots.append(energy_span)
		_energy_profile_gradients.append(energy_profile_gradient)
		_energy_profile_curves.append(energy_profile_curve)

		var aura_span := _trail_aura.duplicate() as Line2D
		aura_span.name = "TrailAuraSplit_%02d" % slot_index
		aura_span.clear_points()
		var source_aura_material := _trail_aura.material as ShaderMaterial
		if source_aura_material != null:
			aura_span.material = source_aura_material.duplicate() as ShaderMaterial
		var aura_profile_gradient: Gradient = _make_profile_gradient(_aura_base_gradient)
		var aura_profile_curve: Curve = _make_profile_curve(_aura_base_width_curve)
		if aura_profile_gradient != null:
			aura_span.gradient = aura_profile_gradient
		if aura_profile_curve != null:
			aura_span.width_curve = aura_profile_curve
		add_child(aura_span)
		_aura_line_slots.append(aura_span)
		_aura_profile_gradients.append(aura_profile_gradient)
		_aura_profile_curves.append(aura_profile_curve)


func _make_profile_gradient(source_gradient: Gradient) -> Gradient:
	if source_gradient == null:
		return null

	var profile := Gradient.new()
	profile.set_color(0, source_gradient.sample(0.0))
	profile.set_color(1, source_gradient.sample(1.0))
	for point_index in range(1, SPLIT_LINE_PROFILE_STEPS):
		var t: float = float(point_index) / float(SPLIT_LINE_PROFILE_STEPS)
		profile.add_point(t, source_gradient.sample(t))
	return profile


func _make_profile_curve(source_curve: Curve) -> Curve:
	if source_curve == null:
		return null

	var profile := Curve.new()
	profile.clear_points()
	profile.min_value = source_curve.min_value
	profile.max_value = source_curve.max_value
	profile.bake_resolution = source_curve.bake_resolution
	for point_index in range(SPLIT_LINE_PROFILE_STEPS + 1):
		var t: float = float(point_index) / float(SPLIT_LINE_PROFILE_STEPS)
		profile.add_point(Vector2(t, source_curve.sample_baked(t)))
	return profile


func _rebuild_shed_line_spans() -> void:
	var energy_points: Array[Vector2] = []
	var aura_points: Array[Vector2] = []
	var energy_distances: Array[float] = [0.0]
	var aura_distances: Array[float] = [0.0]
	for point_index in range(_points.size()):
		energy_points.append(_get_animated_trail_point(point_index, true))
		aura_points.append(_get_animated_trail_point(point_index, false))
		if point_index > 0:
			energy_distances.append(
				energy_distances[point_index - 1]
				+ energy_points[point_index - 1].distance_to(energy_points[point_index])
			)
			aura_distances.append(
				aura_distances[point_index - 1]
				+ aura_points[point_index - 1].distance_to(aura_points[point_index])
			)

	var energy_total: float = energy_distances[energy_distances.size() - 1]
	var aura_total: float = aura_distances[aura_distances.size() - 1]
	var spans: Array[Vector2i] = _get_live_shed_line_spans(aura_distances, aura_total)
	var has_gaps: bool = true
	if spans.size() == 1:
		var only_span: Vector2i = spans[0]
		has_gaps = only_span.x != 0 or only_span.y != _points.size() - 1

	for slot_index in range(_energy_line_slots.size()):
		var energy_line: Line2D = _energy_line_slots[slot_index]
		var aura_line: Line2D = _aura_line_slots[slot_index]
		energy_line.clear_points()
		aura_line.clear_points()
		if slot_index >= spans.size():
			continue

		var span: Vector2i = spans[slot_index]
		if span.y - span.x < 1:
			continue
		for point_index in range(span.x, span.y + 1):
			energy_line.add_point(energy_line.to_local(energy_points[point_index]))
			aura_line.add_point(aura_line.to_local(aura_points[point_index]))

		var energy_start_progress: float = 0.0
		var energy_end_progress: float = 1.0
		if energy_total > 0.001:
			energy_start_progress = energy_distances[span.x] / energy_total
			energy_end_progress = energy_distances[span.y] / energy_total
		var aura_start_progress: float = 0.0
		var aura_end_progress: float = 1.0
		if aura_total > 0.001:
			aura_start_progress = aura_distances[span.x] / aura_total
			aura_end_progress = aura_distances[span.y] / aura_total

		_apply_line_profile(
			energy_line, _energy_base_gradient, _energy_base_width_curve,
			_energy_profile_gradients[slot_index], _energy_profile_curves[slot_index],
			energy_start_progress, energy_end_progress, has_gaps
		)
		_apply_line_profile(
			aura_line, _aura_base_gradient, _aura_base_width_curve,
			_aura_profile_gradients[slot_index], _aura_profile_curves[slot_index],
			aura_start_progress, aura_end_progress, has_gaps
		)
		var energy_material := energy_line.material as ShaderMaterial
		if energy_material != null:
			energy_material.set_shader_parameter("trail_progress_start", energy_start_progress)
			energy_material.set_shader_parameter(
				"trail_progress_scale",
				maxf(energy_end_progress - energy_start_progress, 0.0001)
			)


func _apply_line_profile(
	line: Line2D,
	source_gradient: Gradient,
	source_curve: Curve,
	profile_gradient: Gradient,
	profile_curve: Curve,
	start_progress: float,
	end_progress: float,
	profile_is_split: bool
) -> void:
	if not profile_is_split:
		line.gradient = source_gradient
		line.width_curve = source_curve
		return

	if source_gradient != null and profile_gradient != null:
		for point_index in range(profile_gradient.get_point_count()):
			var local_progress: float = profile_gradient.get_offset(point_index)
			profile_gradient.set_color(
				point_index,
				source_gradient.sample(lerpf(start_progress, end_progress, local_progress))
			)
		line.gradient = profile_gradient
	elif source_gradient == null:
		line.gradient = null

	if source_curve != null and profile_curve != null:
		for point_index in range(profile_curve.get_point_count()):
			var local_progress: float = profile_curve.get_point_position(point_index).x
			profile_curve.set_point_value(
				point_index,
				source_curve.sample_baked(lerpf(start_progress, end_progress, local_progress))
			)
		line.width_curve = profile_curve
	elif source_curve == null:
		line.width_curve = null


func _get_live_shed_line_spans(reference_distances: Array[float], reference_total: float) -> Array[Vector2i]:
	var cut_ranges: Array[Vector2i] = []
	if shedding_enabled:
		for event in _shed_break_events:
			var start_index: int = _point_ids.find(int(event["start_id"]))
			var end_index: int = _point_ids.find(int(event["end_id"]))
			if start_index < 0 or end_index < 0:
				if float(event.get("hold_remaining", 0.0)) > 0.0:
					var fallback_start: float = clampf(float(event.get("start_progress", 0.0)), 0.0, 1.0)
					var fallback_end: float = clampf(float(event.get("end_progress", 1.0)), 0.0, 1.0)
					var fallback_start_distance: float = minf(fallback_start, fallback_end) * reference_total
					var fallback_end_distance: float = maxf(fallback_start, fallback_end) * reference_total
					var fallback_cut_start: int = _nearest_trail_sample_index(fallback_start_distance, reference_distances)
					var fallback_cut_end: int = _nearest_trail_sample_index(fallback_end_distance, reference_distances)
					cut_ranges.append(Vector2i(fallback_cut_start, fallback_cut_end))
					continue
				if start_index < 0 and end_index < 0:
					continue

			var cut_start: int
			var cut_end: int
			if start_index >= 0 and end_index >= 0:
				cut_start = mini(start_index, end_index)
				cut_end = maxi(start_index, end_index)
			elif start_index >= 0:
				cut_start = start_index
				cut_end = _points.size() - 1
			else:
				cut_start = 0
				cut_end = end_index
			cut_ranges.append(Vector2i(cut_start, cut_end))

	cut_ranges.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var merged_ranges: Array[Vector2i] = []
	for cut_range in cut_ranges:
		if merged_ranges.is_empty():
			merged_ranges.append(cut_range)
			continue
		var previous: Vector2i = merged_ranges[merged_ranges.size() - 1]
		if cut_range.x <= previous.y + 1:
			merged_ranges[merged_ranges.size() - 1] = Vector2i(
				previous.x, maxi(previous.y, cut_range.y)
			)
		else:
			merged_ranges.append(cut_range)

	var spans: Array[Vector2i] = []
	var next_start: int = 0
	for cut_range in merged_ranges:
		if cut_range.x - next_start >= 2:
			spans.append(Vector2i(next_start, cut_range.x - 1))
		next_start = maxi(next_start, cut_range.y + 1)
	if _points.size() - next_start >= 2:
		spans.append(Vector2i(next_start, _points.size() - 1))
	return spans


func _clear_shed_line_spans() -> void:
	for line in _energy_line_slots:
		line.clear_points()
	for line in _aura_line_slots:
		line.clear_points()


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

	# Detach only after this frame's geometry has been rebuilt, so the selected
	# source range and persistent hole describe the same surviving trail.
	_process_pending_landing_shear(
		path, cumulative_distances, total_distance, tangents, normals, half_widths
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

	# Let the previous shear finish before allowing another one. This keeps the
	# landing effect rare and readable instead of stacking several moving pieces.
	for fragment in _detached_shed_fragments:
		var existing_piece := fragment.get("node") as Polygon2D
		if is_instance_valid(existing_piece):
			return

	_landing_shear_pending = true


func _process_pending_landing_shear(
	path: Array[Vector2],
	cumulative_distances: Array[float],
	total_distance: float,
	tangents: Array[Vector2],
	normals: Array[Vector2],
	half_widths: Array[float]
) -> void:
	if not shedding_enabled or not _landing_shear_pending:
		return

	# A failed source selection is intentionally dropped rather than retried on
	# a later frame, when the trail would have moved away from the landing.
	_landing_shear_pending = false
	var previous_break_count: int = _shed_break_events.size()
	_spawn_shed_fragment(
		path, cumulative_distances, total_distance, tangents, normals, half_widths
	)
	if _shed_break_events.size() == previous_break_count:
		return


func _spawn_shed_fragment(
	path: Array[Vector2],
	cumulative_distances: Array[float],
	total_distance: float,
	tangents: Array[Vector2],
	normals: Array[Vector2],
	half_widths: Array[float]
) -> void:
	if (
		not shedding_enabled
		or path.size() < 16
		or total_distance < 105.0
		or _detached_shed_fragments.size() >= 14
		or _shed_break_events.size() >= MAX_ACTIVE_SHED_BREAKS
		or _shed_piece_ranges.size() < 2
		or _shed_geometry_container == null
	):
		return

	# Form candidate pairs from adjacent, currently visible trail islands. The
	# resulting shard is one continuous, wider piece rather than three tiny
	# particle-like chips. Its source is rebuilt from the same ribbon geometry.
	var candidate_pairs: Array[Dictionary] = []
	for range_index in range(_shed_piece_ranges.size() - 1):
		var first: Dictionary = _shed_piece_ranges[range_index]
		var second: Dictionary = _shed_piece_ranges[range_index + 1]
		var first_piece := first["node"] as Polygon2D
		var second_piece := second["node"] as Polygon2D
		if (
			not is_instance_valid(first_piece)
			or not is_instance_valid(second_piece)
			or not first_piece.visible
			or not second_piece.visible
		):
			continue

		var start_distance: float = float(first["start_distance"])
		var end_distance: float = float(second["end_distance"])
		var gap_between: float = float(second["start_distance"]) - float(first["end_distance"])
		var progress: float = (start_distance + end_distance) * 0.5 / total_distance
		if (
			gap_between < -0.1
			or gap_between > 4.0
			or progress < SHED_MIN_FRAGMENT_PROGRESS
			or progress > SHED_MAX_FRAGMENT_PROGRESS
			or end_distance - start_distance < 22.0
		):
			continue

		candidate_pairs.append({
			"first_index": range_index,
			"second_index": range_index + 1,
			"start_distance": start_distance,
			"end_distance": end_distance,
			"progress": progress
		})

	if candidate_pairs.is_empty():
		return

	# Prefer a source position well away from the last few shears. If the live
	# gaps leave very few options, fall back to available pairs rather than
	# forcing an awkward location or repeatedly choosing the same tail section.
	var preferred_pairs: Array[Dictionary] = []
	for candidate in candidate_pairs:
		var progress: float = float(candidate["progress"])
		var separated_from_recent: bool = true
		for recent_progress in _recent_shed_progresses:
			if absf(progress - recent_progress) < SHED_RECENT_PROGRESS_SEPARATION:
				separated_from_recent = false
				break
		if separated_from_recent:
			preferred_pairs.append(candidate)

	var selection_pool: Array[Dictionary] = (
		preferred_pairs if not preferred_pairs.is_empty() else candidate_pairs
	)
	var selected: Dictionary = selection_pool[randi_range(0, selection_pool.size() - 1)]
	var first_range_index: int = int(selected["first_index"])
	var second_range_index: int = int(selected["second_index"])
	var start_distance: float = float(selected["start_distance"])
	var end_distance: float = float(selected["end_distance"])

	var world_root: Node2D = get_tree().current_scene as Node2D
	if world_root == null:
		world_root = get_parent() as Node2D
	if world_root == null:
		return

	# Build one mesh across both neighboring source intervals, then detach that
	# actual ribbon section with the same body shader and full-trail UV values.
	var fragment_source := Polygon2D.new()
	fragment_source.name = "CometShearSource"
	fragment_source.visible = false
	_shed_geometry_container.add_child(fragment_source)
	_build_shed_piece_polygon(
		fragment_source, start_distance, end_distance, path,
		cumulative_distances, total_distance, tangents, normals, half_widths
	)
	fragment_source.visible = false
	fragment_source.material = (
		_detached_piece_material if _detached_piece_material != null else _shed_piece_material
	)
	if fragment_source.polygon.size() < 4:
		fragment_source.queue_free()
		return

	var world_vertices: Array[Vector2] = []
	var centroid_global := Vector2.ZERO
	for local_vertex in fragment_source.polygon:
		var global_vertex: Vector2 = fragment_source.to_global(local_vertex)
		world_vertices.append(global_vertex)
		centroid_global += global_vertex
	centroid_global /= float(world_vertices.size())

	var detached_polygon := PackedVector2Array()
	for global_vertex in world_vertices:
		detached_polygon.append(global_vertex - centroid_global)

	var shard := Polygon2D.new()
	shard.name = "DetachedCometShear"
	shard.z_as_relative = false
	shard.z_index = -2
	shard.polygon = detached_polygon
	shard.uv = fragment_source.uv.duplicate()
	shard.material = _detached_piece_material if _detached_piece_material != null else fragment_source.material
	world_root.add_child(shard)
	shard.global_position = centroid_global
	shard.global_rotation = 0.0
	fragment_source.queue_free()

	var start_anchor_index: int = _nearest_trail_sample_index(start_distance, cumulative_distances)
	var end_anchor_index: int = _nearest_trail_sample_index(end_distance, cumulative_distances)
	if end_anchor_index <= start_anchor_index:
		shard.queue_free()
		return

	var start_id: int = _point_ids[start_anchor_index]
	var end_id: int = _point_ids[end_anchor_index]
	var start_offset: float = start_distance - cumulative_distances[start_anchor_index]
	var end_offset: float = end_distance - cumulative_distances[end_anchor_index]
	var sequence_value: float = float(_shed_sequence)
	var horizontal_side_value: float = sin(sequence_value * 17.17 + _trail_time * 0.73)
	var side: float = -1.0 if horizontal_side_value < 0.0 else 1.0
	var horizontal_speed: float = lerpf(90.0, 132.0, absf(sin(sequence_value * 11.31 + 0.4)))
	var vertical_speed: float = sin(sequence_value * 7.73 + 2.1) * 30.0
	var lifetime: float = lerpf(1.10, 1.38, absf(sin(sequence_value * 3.91 + 0.8)))
	var angular_velocity: float = sin(sequence_value * 8.31 + 0.9) * 2.1

	# The original samples may leave the capped history before this fragment
	# finishes fading. Keep a progress-space fallback gap for the fragment's
	# visible lifetime, then let it disappear naturally with the shear.
	_shed_break_events.append({
		"start_id": start_id,
		"end_id": end_id,
		"start_offset": start_offset,
		"end_offset": end_offset,
		"start_progress": start_distance / total_distance,
		"end_progress": end_distance / total_distance,
		"hold_remaining": lifetime + 0.10
	})

	# Remove the two source islands immediately; rebuilding will keep every
	# intersecting source interval absent as the history advances.
	for range_index in [first_range_index, second_range_index]:
		var source_range: Dictionary = _shed_piece_ranges[range_index]
		var source_piece := source_range["node"] as Polygon2D
		if is_instance_valid(source_piece):
			source_piece.visible = false

	_recent_shed_progresses.append(float(selected["progress"]))
	while _recent_shed_progresses.size() > 3:
		_recent_shed_progresses.pop_front()

	# Use world-space horizontal ejection with only a small vertical component.
	var velocity := Vector2(side * horizontal_speed, vertical_speed)
	_detached_shed_fragments.append({
		"node": shard,
		"velocity": velocity,
		"age": 0.0,
		"lifetime": lifetime,
		"angular_velocity": angular_velocity,
		"base_alpha": 1.0
	})
	_shed_sequence += 1
	_sync_shed_gap_materials(cumulative_distances, total_distance)
	_rebuild_shed_line_spans()


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
		velocity.y += 7.0 * delta
		velocity *= maxf(0.0, 1.0 - delta * 0.45)
		shard.global_position += velocity * delta
		shard.rotation += float(fragment["angular_velocity"]) * delta
		var fade: float = 1.0 - smoothstep(lifetime * 0.56, lifetime, age)
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
		_detached_piece_material.set_shader_parameter("shed_gap_0", Vector2(-1.0, -1.0))
		_detached_piece_material.set_shader_parameter("shed_gap_1", Vector2(-1.0, -1.0))
		_detached_piece_material.set_shader_parameter("shed_gap_2", Vector2(-1.0, -1.0))

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
	var start_skew: float = minf(length * 0.12, 1.2)
	var end_skew: float = minf(length * 0.10, 1.0)

	# Keep the chipped ends inside their own source interval. This prevents a
	# neighboring piece from protruding back into a persistent detachment gap.
	var start_right_distance: float = start_distance + start_skew
	var start_left_distance: float = start_distance + start_skew * 0.25
	var end_right_distance: float = end_distance - end_skew
	var end_left_distance: float = end_distance - end_skew * 0.25

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
	# Only an event-locked source interval creates a pronounced missing chunk.
	var cursor: float = maxf(total_distance * SHED_CONNECTED_END_PROGRESS - 3.5, 0.0)
	var tail_limit: float = total_distance * 0.985
	var slot_index: int = 0
	while cursor < tail_limit and slot_index < _shed_geometry_pieces.size():
		var seed_a: float = absf(sin(float(slot_index) * 15.731 + 2.17))
		var seed_b: float = absf(sin(float(slot_index) * 9.173 + 5.61))
		var piece_length: float = clampf(total_distance * lerpf(0.055, 0.095, seed_a), 8.0, 24.0)
		var piece_end: float = minf(cursor + piece_length, tail_limit)
		if piece_end - cursor < 5.0:
			break

		var start_sample_index: int = _nearest_trail_sample_index(cursor, cumulative_distances)
		var end_sample_index: int = _nearest_trail_sample_index(piece_end, cumulative_distances)
		if end_sample_index <= start_sample_index:
			if start_sample_index < _point_ids.size() - 1:
				end_sample_index = start_sample_index + 1
			else:
				start_sample_index = maxi(start_sample_index - 1, 0)

		var interval_has_detached_piece: bool = _shed_event_overlaps_interval(
			cursor, piece_end, cumulative_distances, total_distance
		)
		if not interval_has_detached_piece:
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

		# Always advance, including when this interval overlaps a live break.
		# The previous implementation advanced only after drawing a piece,
		# so one existing break could stall the whole geometry reconstruction.
		cursor = piece_end + clampf(lerpf(0.6, 1.3, seed_b), 0.6, 1.5)
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
		# Keep a break while either boundary sample survives. When the older
		# boundary leaves the capped trail, the hole contracts naturally from
		# the tail instead of the original source geometry suddenly respawning.
		if start_index < 0 and end_index < 0 and float(event.get("hold_remaining", 0.0)) <= 0.0:
			_shed_break_events.remove_at(event_index)


func _shed_event_overlaps_interval(
	interval_start: float,
	interval_end: float,
	cumulative_distances: Array[float],
	total_distance: float
) -> bool:
	for event in _shed_break_events:
		var start_index: int = _point_ids.find(int(event["start_id"]))
		var end_index: int = _point_ids.find(int(event["end_id"]))
		if start_index < 0 or end_index < 0:
			if float(event.get("hold_remaining", 0.0)) > 0.0:
				var fallback_start: float = clampf(float(event.get("start_progress", 0.0)), 0.0, 1.0)
				var fallback_end: float = clampf(float(event.get("end_progress", 1.0)), 0.0, 1.0)
				var fallback_distance_start: float = minf(fallback_start, fallback_end) * total_distance
				var fallback_distance_end: float = maxf(fallback_start, fallback_end) * total_distance
				if fallback_distance_start < interval_end - 0.8 and fallback_distance_end > interval_start + 0.8:
					return true
				continue
			if start_index < 0 and end_index < 0:
				continue

		var event_start: float = 0.0
		var event_end: float = total_distance
		if start_index >= 0 and end_index >= 0:
			var anchored_start: float = cumulative_distances[start_index] + float(event.get("start_offset", 0.0))
			var anchored_end: float = cumulative_distances[end_index] + float(event.get("end_offset", 0.0))
			event_start = minf(anchored_start, anchored_end)
			event_end = maxf(anchored_start, anchored_end)
		elif start_index >= 0:
			event_start = cumulative_distances[start_index] + float(event.get("start_offset", 0.0))
		elif end_index >= 0:
			event_end = cumulative_distances[end_index] + float(event.get("end_offset", 0.0))

		event_start = clampf(event_start, 0.0, total_distance)
		event_end = clampf(event_end, 0.0, total_distance)
		# If one boundary ages out, extend only that side to the trail end.
		# The surviving anchor and local offset keep the missing interval stable.
		if event_start < interval_end - 0.8 and event_end > interval_start + 0.8:
			return true
	return false


func _sync_shed_gap_materials(
	cumulative_distances: Array[float],
	total_distance: float
) -> void:
	var intervals: Array[Vector2] = [
		Vector2(-1.0, -1.0),
		Vector2(-1.0, -1.0),
		Vector2(-1.0, -1.0)
	]
	if shedding_enabled and total_distance > 0.01:
		for event_index in range(mini(_shed_break_events.size(), MAX_ACTIVE_SHED_BREAKS)):
			var event: Dictionary = _shed_break_events[event_index]
			var start_index: int = _point_ids.find(int(event["start_id"]))
			var end_index: int = _point_ids.find(int(event["end_id"]))
			if start_index < 0 or end_index < 0:
				if float(event.get("hold_remaining", 0.0)) > 0.0:
					var fallback_start: float = clampf(float(event.get("start_progress", 0.0)), 0.0, 1.0)
					var fallback_end: float = clampf(float(event.get("end_progress", 1.0)), 0.0, 1.0)
					var fallback_start_distance: float = minf(fallback_start, fallback_end) * total_distance
					var fallback_end_distance: float = maxf(fallback_start, fallback_end) * total_distance
					if fallback_end_distance - fallback_start_distance > 0.01:
						intervals[event_index] = Vector2(
							fallback_start_distance / total_distance,
						fallback_end_distance / total_distance
						)
					continue
				if start_index < 0 and end_index < 0:
					continue

			var start_distance: float = 0.0
			var end_distance: float = total_distance
			if start_index >= 0 and end_index >= 0:
				var anchored_start: float = cumulative_distances[start_index] + float(event.get("start_offset", 0.0))
				var anchored_end: float = cumulative_distances[end_index] + float(event.get("end_offset", 0.0))
				start_distance = minf(anchored_start, anchored_end)
				end_distance = maxf(anchored_start, anchored_end)
			elif start_index >= 0:
				start_distance = cumulative_distances[start_index] + float(event.get("start_offset", 0.0))
			elif end_index >= 0:
				end_distance = cumulative_distances[end_index] + float(event.get("end_offset", 0.0))

			start_distance = clampf(start_distance, 0.0, total_distance)
			end_distance = clampf(end_distance, 0.0, total_distance)
			if end_distance - start_distance > 0.01:
				intervals[event_index] = Vector2(
					start_distance / total_distance,
					end_distance / total_distance
				)

	var unified_material: ShaderMaterial = null
	if _unified_shape != null:
		unified_material = _unified_shape.material as ShaderMaterial
	for material in [unified_material, _shed_piece_material]:
		if material != null:
			material.set_shader_parameter("shed_gap_0", intervals[0])
			material.set_shader_parameter("shed_gap_1", intervals[1])
			material.set_shader_parameter("shed_gap_2", intervals[2])


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
			unified_material.set_shader_parameter("shedding_amount", 1.0 if shedding_enabled else 0.0)
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
