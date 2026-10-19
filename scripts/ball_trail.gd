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
const SURFACE_BURST_PIECE_COUNT: int = 4
const CHEVRON_BURST_PIECE_COUNT: int = 5
const SURFACE_BURST_SPACING: float = 0.055
const CHEVRON_BURST_SPACING: float = 0.035

@export_category("Visual Palette")
@export_enum("Electric Blue", "Rich Violet") var visual_palette: int = 0

@export_category("Comet Shedding")
@export var shedding_enabled: bool = true

@export_category("Energy Release")
@export_range(1, 20, 1) var full_release_every_landings: int = 5
@export_range(0.0, 1.0, 0.01) var full_release_filament_chance: float = 0.72

@onready var _energy_line: Line2D = $EnergyLine
@onready var _trail_aura: Line2D = $TrailAura
@onready var _unified_shape: MeshInstance2D = get_node_or_null("UnifiedCometShape") as MeshInstance2D
@onready var _unified_contour: Line2D = get_node_or_null("UnifiedCometContour") as Line2D
@onready var _ball_visual: Sprite2D = get_parent().get_node("Visual") as Sprite2D
@onready var _rim_aura: Sprite2D = get_parent().get_node_or_null("RimAura") as Sprite2D

var _points: Array[Vector2] = []
var _particle_emitters: Array[GPUParticles2D] = []
var _previous_ball_position: Vector2 = Vector2.ZERO
var _trail_time: float = 0.0
var _last_emission_direction: Vector2 = Vector2.DOWN
var _ball_surface_radius: float = 29.9
var _surface_burst_remaining: int = 0
var _surface_burst_clock: float = 0.0
var _chevron_burst_remaining: int = 0
var _chevron_burst_clock: float = 0.0
var _shed_sequence: int = 0
var _detached_shed_fragments: Array[Dictionary] = []
var _aura_fragment_material: CanvasItemMaterial
var _surface_fragment_material: ShaderMaterial
var _visual_rng := RandomNumberGenerator.new()
var _energy_filaments: Array[Dictionary] = []
var _pulse_active: bool = false
var _pulse_progress: float = -1.0
var _pulse_filament_progress: float = 0.48
var _pulse_filament_enabled: bool = false
var _pulse_filament_spawned: bool = false
var _confirmed_landing_count: int = 0
var _landing_release_pending: bool = false
var _landing_release_after_reverse: bool = false

var _landing_approach_platform: Node2D = null
var _landing_anticipation_target: float = 0.0
var _landing_anticipation: float = 0.0
var _landing_confirmation_elapsed: float = -1.0
var _landing_confirmation_strength: float = 0.0
var _landing_trail_kick_elapsed: float = -1.0
var _landing_trail_kick_strength: float = 0.0
var _landing_trail_kick_progress: float = 0.0
var _landing_rim_elapsed: float = -1.0
var _landing_rim_strength: float = 0.0

# Full-ribbon releases are landing-driven; the inward discharge remains the regular landing response.
const ENERGY_PULSE_SPEED: float = 0.62
const ENERGY_PULSE_END: float = 0.94
const ENERGY_FILAMENT_MAX_ACTIVE: int = 8
const LANDING_TRAIL_KICK_DURATION: float = 0.32
const LANDING_CONFIRMATION_DURATION: float = 0.26
const LANDING_RIM_CONFIRMATION_DURATION: float = 0.38
const LANDING_ANTICIPATION_RESPONSE: float = 10.0

var _latest_trail_path: Array[Vector2] = []
var _latest_trail_distances: Array[float] = []
var _latest_trail_tangents: Array[Vector2] = []
var _latest_trail_normals: Array[Vector2] = []
var _latest_trail_half_widths: Array[float] = []
var _latest_trail_total_distance: float = 0.0
var _landing_burst_path: Array[Vector2] = []
var _landing_burst_distances: Array[float] = []
var _landing_burst_tangents: Array[Vector2] = []
var _landing_burst_normals: Array[Vector2] = []
var _landing_burst_half_widths: Array[float] = []
var _landing_burst_total_distance: float = 0.0
var _landing_burst_snapshot_valid: bool = false

func _ready() -> void:
	z_index = -1
	_previous_ball_position = global_position
	_visual_rng.randomize()
	_ball_surface_radius = _measure_ball_surface_radius()
	if _unified_shape != null:
		_unified_shape.mesh = ArrayMesh.new()

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
	# Small chevron flecks use additive blending; broad surface fragments use
	# the same comet shader as the body, with alpha boosted on the copied mesh.
	var accent_material := CanvasItemMaterial.new()
	accent_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_aura_fragment_material = accent_material

	var body_material := _unified_shape.material as ShaderMaterial
	if body_material != null:
		_surface_fragment_material = body_material.duplicate() as ShaderMaterial
		_surface_fragment_material.set_shader_parameter("fragment_alpha_boost", 2.25)




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


func _sample_image_alpha_bilinear(texture_image: Image, image_position: Vector2) -> float:
	var max_x: float = float(texture_image.get_width() - 1)
	var max_y: float = float(texture_image.get_height() - 1)
	var x: float = clampf(image_position.x, 0.0, max_x)
	var y: float = clampf(image_position.y, 0.0, max_y)
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
		_surface_burst_remaining = 0
		_surface_burst_clock = 0.0
		_chevron_burst_remaining = 0
		_chevron_burst_clock = 0.0
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
	_update_energy_pulse(delta)
	_update_landing_response(delta)
	_update_detached_shed_fragments(delta)
	_update_energy_filaments(delta)
	_update_rim_breath()
	_update_particle_emitters(current_world_position, movement, distance_from_trail)
	_previous_ball_position = current_world_position


func _update_rim_breath() -> void:
	# Keep the orb rim, its outer halo, and the trail response visually linked.
	var breathing: float = 0.5 + 0.5 * sin(_trail_time * 1.35)
	var rim_breath: float = lerp(0.72, 1.0, breathing)
	rim_breath += _landing_anticipation * 0.12
	rim_breath += _landing_confirmation_strength * 0.10
	rim_breath += _landing_rim_strength * 0.20
	if _pulse_active:
		var pulse_origin_flash: float = 1.0 - smoothstep(0.0, 0.18, _pulse_progress)
		rim_breath += pulse_origin_flash * 0.18
	rim_breath = clampf(rim_breath, 0.0, 1.35)
	var orb_material := _ball_visual.material as ShaderMaterial
	if orb_material != null:
		orb_material.set_shader_parameter("rim_breath", rim_breath)
	if _rim_aura != null:
		var rim_aura_material := _rim_aura.material as ShaderMaterial
		if rim_aura_material != null:
			rim_aura_material.set_shader_parameter("rim_breath", rim_breath)
	if _unified_contour != null:
		_unified_contour.modulate = Color(rim_breath, rim_breath, rim_breath, 1.0)


func _update_trail_lines(delta: float = 0.0) -> void:
	if _points.size() < 2:
		_latest_trail_path.clear()
		_latest_trail_distances.clear()
		_latest_trail_tangents.clear()
		_latest_trail_normals.clear()
		_latest_trail_half_widths.clear()
		_latest_trail_total_distance = 0.0
		_energy_line.clear_points()
		_trail_aura.clear_points()
		_clear_unified_comet_mesh()
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

	# Keep the live ribbon geometry, but build it as explicit triangles rather
	# than asking Polygon2D to re-triangulate a moving, potentially self-crossing
	# concave polygon every frame.
	var path: Array[Vector2] = []
	for i in range(_points.size()):
		path.append(_get_animated_trail_point(i, false))

	var cumulative_distances: Array[float] = [0.0]
	var total_distance: float = 0.0
	for i in range(1, path.size()):
		total_distance += path[i - 1].distance_to(path[i])
		cumulative_distances.append(total_distance)

	if total_distance < 0.01:
		_clear_unified_comet_mesh()
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
		var line_half_width: float = _trail_aura.width * width_factor * 0.5
		half_widths.append(line_half_width)

	var upper_edge_points: Array[Vector2] = []
	var lower_edge_points: Array[Vector2] = []
	for i in range(path.size()):
		# Keep the original clean, consistent ribbon width. Organic movement is
		# already supplied by the trail path, plasma flow and travelling pulses.
		var base_half_width: float = half_widths[i]
		upper_edge_points.append(path[i] + normals[i] * base_half_width)
		lower_edge_points.append(path[i] - normals[i] * base_half_width)

	_latest_trail_path = path.duplicate()
	_latest_trail_distances = cumulative_distances.duplicate()
	_latest_trail_tangents = tangents.duplicate()
	_latest_trail_normals = normals.duplicate()
	_latest_trail_half_widths = half_widths.duplicate()
	_latest_trail_total_distance = total_distance

	var mesh_vertices: Array[Vector2] = []
	var mesh_uvs: Array[Vector2] = []
	var root_direction: Vector2 = tangents[0]
	var root_normal: Vector2 = normals[0]
	var head_arc_points: Array[Vector2] = []
	var head_arc_uvs: Array[Vector2] = []

	# Triangulate the half-disc explicitly. Its curved boundary stays tucked
	# beneath the orb, and its open diameter feeds into the trail strip below.
	for arc_index in range(UNIFIED_HEAD_ARC_SEGMENTS + 1):
		var arc_t: float = float(arc_index) / float(UNIFIED_HEAD_ARC_SEGMENTS)
		var angle: float = PI * 0.5 + PI * arc_t
		var world_point: Vector2 = (
			path[0]
			+ root_direction * _ball_surface_radius * cos(angle)
			+ root_normal * _ball_surface_radius * sin(angle)
		)
		head_arc_points.append(world_point)
		head_arc_uvs.append(Vector2(0.0, arc_t))

	var center_uv := Vector2(0.0, 0.5)
	for arc_index in range(UNIFIED_HEAD_ARC_SEGMENTS):
		_append_comet_mesh_triangle(
			mesh_vertices, mesh_uvs,
			path[0], head_arc_points[arc_index], head_arc_points[arc_index + 1],
			center_uv, head_arc_uvs[arc_index], head_arc_uvs[arc_index + 1]
		)

	# Build each ribbon section from two triangles. Unlike one concave polygon,
	# every primitive has a fixed topology, so moving vertices cannot alter
	# Polygon2D's triangulation across frames.
	var previous_left: Vector2 = head_arc_points[0]
	var previous_right: Vector2 = head_arc_points[head_arc_points.size() - 1]
	var previous_progress: float = 0.0
	for i in range(1, path.size()):
		var progress: float = cumulative_distances[i] / total_distance
		var current_left: Vector2 = path[i] + normals[i] * half_widths[i]
		var current_right: Vector2 = path[i] - normals[i] * half_widths[i]
		var previous_left_uv := Vector2(previous_progress, 0.0)
		var previous_right_uv := Vector2(previous_progress, 1.0)
		var current_left_uv := Vector2(progress, 0.0)
		var current_right_uv := Vector2(progress, 1.0)

		_append_comet_mesh_triangle(
			mesh_vertices, mesh_uvs,
			previous_left, previous_right, current_right,
			previous_left_uv, previous_right_uv, current_right_uv
		)
		_append_comet_mesh_triangle(
			mesh_vertices, mesh_uvs,
			previous_left, current_right, current_left,
			previous_left_uv, current_right_uv, current_left_uv
		)

		previous_left = current_left
		previous_right = current_right
		previous_progress = progress

	var surface_arrays: Array = []
	surface_arrays.resize(Mesh.ARRAY_MAX)
	surface_arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array(mesh_vertices)
	surface_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(mesh_uvs)

	var unified_mesh := _unified_shape.mesh as ArrayMesh
	if unified_mesh == null:
		unified_mesh = ArrayMesh.new()
		_unified_shape.mesh = unified_mesh
	unified_mesh.clear_surfaces()
	if mesh_vertices.size() >= 3:
		unified_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)

	# Keep the existing trail contour and its precise orb intersections intact.
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
			for point_index in range(exposed_lower.size() - 2, -1, -1):
				contour_points.append(
					_unified_shape.to_local(exposed_lower[point_index])
				)
		_unified_contour.points = contour_points

	# Landing fragment effects still use the freshly rebuilt trail cross-sections.
	_process_shed_burst(delta)


func _append_comet_mesh_triangle(
	vertices: Array[Vector2],
	uvs: Array[Vector2],
	point_a: Vector2,
	point_b: Vector2,
	point_c: Vector2,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2
) -> void:
	vertices.append(_unified_shape.to_local(point_a))
	vertices.append(_unified_shape.to_local(point_b))
	vertices.append(_unified_shape.to_local(point_c))
	uvs.append(uv_a)
	uvs.append(uv_b)
	uvs.append(uv_c)


func _clear_unified_comet_mesh() -> void:
	if _unified_shape == null:
		return
	var unified_mesh := _unified_shape.mesh as ArrayMesh
	if unified_mesh != null:
		unified_mesh.clear_surfaces()


func _connect_landing_feedback() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	# The main game scene owns this coordinator. Test rooms without it continue
	# to render the trail without raising any landing-triggered feedback.
	var controller := scene_root.get_node_or_null("LandingFeedbackController")
	if controller == null:
		return

	var approach_callback := Callable(self, "_on_landing_approach_updated")
	if (
		controller.has_signal("landing_approach_updated")
		and not controller.is_connected("landing_approach_updated", approach_callback)
	):
		controller.connect("landing_approach_updated", approach_callback)

	var target_callback := Callable(self, "_on_landing_target_changed")
	if (
		controller.has_signal("landing_target_changed")
		and not controller.is_connected("landing_target_changed", target_callback)
	):
		controller.connect("landing_target_changed", target_callback)

	var landing_callback := Callable(self, "_on_landing_confirmed")
	if (
		controller.has_signal("landing_confirmed")
		and not controller.is_connected("landing_confirmed", landing_callback)
	):
		controller.connect("landing_confirmed", landing_callback)


func _on_landing_target_changed(_previous_target: Node2D, new_target: Node2D) -> void:
	_landing_approach_platform = new_target
	_landing_anticipation_target = 0.0


func _on_landing_approach_updated(
	platform: Node2D,
	progress: float,
	_target_x: float,
	_time_to_land: float,
	_edge_factor: float
) -> void:
	if platform == null or not is_instance_valid(platform):
		return
	if _landing_approach_platform != null and platform != _landing_approach_platform:
		return
	_landing_approach_platform = platform
	_landing_anticipation_target = clampf(progress, 0.0, 1.0)


func _start_landing_response() -> void:
	# Core and rim confirmation remain available on every physical landing.
	# The inward trail flash is sequenced independently from the full-ribbon release.
	_landing_approach_platform = null
	_landing_anticipation_target = 0.0
	_landing_confirmation_elapsed = 0.0
	_landing_confirmation_strength = 0.0
	_landing_rim_elapsed = 0.0
	_landing_rim_strength = 0.0


func _start_landing_reverse_flash(release_after_reverse: bool) -> void:
	_landing_trail_kick_elapsed = 0.0
	_landing_trail_kick_strength = 0.0
	_landing_trail_kick_progress = 1.0
	_landing_release_after_reverse = release_after_reverse

func _update_landing_response(delta: float) -> void:
	var response: float = 1.0 - exp(-LANDING_ANTICIPATION_RESPONSE * delta)
	_landing_anticipation = lerpf(
		_landing_anticipation,
		_landing_anticipation_target,
		response
	)

	# The orb's core flash remains crisp; the outer rim has a shorter, colored afterglow.
	if _landing_confirmation_elapsed >= 0.0:
		_landing_confirmation_elapsed += delta
		var attack: float = smoothstep(0.0, 0.035, _landing_confirmation_elapsed)
		var release: float = 1.0 - smoothstep(0.045, 0.22, _landing_confirmation_elapsed)
		_landing_confirmation_strength = attack * release
		if _landing_confirmation_elapsed >= LANDING_CONFIRMATION_DURATION:
			_landing_confirmation_elapsed = -1.0
			_landing_confirmation_strength = 0.0
	else:
		_landing_confirmation_strength = 0.0

	if _landing_rim_elapsed >= 0.0:
		_landing_rim_elapsed += delta
		var rim_attack: float = smoothstep(0.0, 0.045, _landing_rim_elapsed)
		var rim_release: float = 1.0 - smoothstep(0.07, LANDING_RIM_CONFIRMATION_DURATION, _landing_rim_elapsed)
		_landing_rim_strength = rim_attack * rim_release
		if _landing_rim_elapsed >= LANDING_RIM_CONFIRMATION_DURATION:
			_landing_rim_elapsed = -1.0
			_landing_rim_strength = 0.0
	else:
		_landing_rim_strength = 0.0

	# The front starts at the tail and runs back to the orb; the ambient pulse
	# stays on its own scheduler and still travels outward across the whole comet.
	if _landing_trail_kick_elapsed >= 0.0:
		_landing_trail_kick_elapsed += delta
		var kick_attack: float = smoothstep(0.0, 0.018, _landing_trail_kick_elapsed)
		var kick_release: float = 1.0 - smoothstep(0.18, LANDING_TRAIL_KICK_DURATION, _landing_trail_kick_elapsed)
		_landing_trail_kick_strength = kick_attack * kick_release
		_landing_trail_kick_progress = 1.0 - clampf(
			_landing_trail_kick_elapsed / LANDING_TRAIL_KICK_DURATION,
			0.0,
			1.0
		)
		if _landing_trail_kick_elapsed >= LANDING_TRAIL_KICK_DURATION:
			var launch_release_after_reverse: bool = _landing_release_after_reverse
			_landing_release_after_reverse = false
			_landing_trail_kick_elapsed = -1.0
			_landing_trail_kick_strength = 0.0
			_landing_trail_kick_progress = 0.0
			if launch_release_after_reverse and not _start_energy_pulse():
				# Keep the release queued if the trail isn't long enough this frame.
				_landing_release_pending = true
	else:
		_landing_trail_kick_strength = 0.0
		_landing_trail_kick_progress = 0.0

	var orb_material := _ball_visual.material as ShaderMaterial
	if orb_material != null:
		orb_material.set_shader_parameter("landing_anticipation", _landing_anticipation)
		orb_material.set_shader_parameter("landing_confirmation", _landing_confirmation_strength)

	if _rim_aura != null:
		var rim_aura_material := _rim_aura.material as ShaderMaterial
		if rim_aura_material != null:
			rim_aura_material.set_shader_parameter("landing_anticipation", _landing_anticipation)
			rim_aura_material.set_shader_parameter("landing_confirmation", _landing_rim_strength)

	# The landing-specific front only affects the inner energy channel.
	var energy_material := _energy_line.material as ShaderMaterial
	if energy_material != null:
		energy_material.set_shader_parameter("landing_kick_strength", _landing_trail_kick_strength)
		energy_material.set_shader_parameter("landing_kick_progress", _landing_trail_kick_progress)

func _on_landing_confirmed(event: LandingEvent) -> void:
	if event == null:
		return

	var ball := get_parent() as CharacterBody2D
	if ball == null or event.ball != ball:
		return

	_start_landing_response()

	# The cadence counts confirmed landings only. A pending release is a single
	# queued event, never a backlog of overlapping full-ribbon pulses.
	_confirmed_landing_count += 1
	var release_interval: int = maxi(full_release_every_landings, 1)
	if _confirmed_landing_count % release_interval == 0:
		_landing_release_pending = true

	if _pulse_active:
		# While the full-ribbon release is travelling outward, suppress the
		# inward flash. Any queued release waits for a later eligible landing.
		_landing_trail_kick_elapsed = -1.0
		_landing_trail_kick_strength = 0.0
		_landing_trail_kick_progress = 0.0
		_landing_release_after_reverse = false
	elif _landing_trail_kick_elapsed >= 0.0:
		# Do not restart a reverse flash already in motion; attach a due release
		# to its completion instead.
		if _landing_release_pending:
			_landing_release_after_reverse = true
			_landing_release_pending = false
	else:
		var release_after_reverse: bool = _landing_release_pending
		_start_landing_reverse_flash(release_after_reverse)
		if release_after_reverse:
			_landing_release_pending = false

	if not shedding_enabled:
		return

	# Freeze the just-rendered trail shape before the ball's bounce changes it.
	if _latest_trail_path.size() < 6 or _latest_trail_total_distance < 55.0:
		_surface_burst_remaining = 0
		_chevron_burst_remaining = 0
		_landing_burst_snapshot_valid = false
		return
	_landing_burst_path = _latest_trail_path.duplicate()
	_landing_burst_distances = _latest_trail_distances.duplicate()
	_landing_burst_tangents = _latest_trail_tangents.duplicate()
	_landing_burst_normals = _latest_trail_normals.duplicate()
	_landing_burst_half_widths = _latest_trail_half_widths.duplicate()
	_landing_burst_total_distance = _latest_trail_total_distance
	_landing_burst_snapshot_valid = true

	# Both fragment groups now use that frozen geometry, not the changing live trail.
	_surface_burst_remaining = SURFACE_BURST_PIECE_COUNT
	_surface_burst_clock = 0.0
	_chevron_burst_remaining = CHEVRON_BURST_PIECE_COUNT
	_chevron_burst_clock = 0.0


func _process_shed_burst(delta: float) -> void:
	if not shedding_enabled or not _landing_burst_snapshot_valid:
		return

	if _surface_burst_remaining > 0:
		_surface_burst_clock = maxf(_surface_burst_clock - delta, 0.0)
		if _surface_burst_clock <= 0.0:
			var surface_index: int = SURFACE_BURST_PIECE_COUNT - _surface_burst_remaining
			var previous_surface_count: int = _detached_shed_fragments.size()
			_spawn_surface_fragment(
				_landing_burst_path, _landing_burst_distances, _landing_burst_total_distance,
				_landing_burst_tangents, _landing_burst_normals, _landing_burst_half_widths,
				surface_index
			)
			if _detached_shed_fragments.size() == previous_surface_count:
				_surface_burst_remaining = 0
			else:
				_surface_burst_remaining -= 1
				_surface_burst_clock = SURFACE_BURST_SPACING if _surface_burst_remaining > 0 else 0.0

	if _chevron_burst_remaining > 0:
		_chevron_burst_clock = maxf(_chevron_burst_clock - delta, 0.0)
		if _chevron_burst_clock <= 0.0:
			var chevron_index: int = CHEVRON_BURST_PIECE_COUNT - _chevron_burst_remaining
			var previous_chevron_count: int = _detached_shed_fragments.size()
			_spawn_shed_fragment(
				_landing_burst_path, _landing_burst_distances, _landing_burst_total_distance,
				_landing_burst_tangents, _landing_burst_normals, _landing_burst_half_widths,
				chevron_index
			)
			if _detached_shed_fragments.size() == previous_chevron_count:
				_chevron_burst_remaining = 0
			else:
				_chevron_burst_remaining -= 1
				_chevron_burst_clock = CHEVRON_BURST_SPACING if _chevron_burst_remaining > 0 else 0.0


func _spawn_surface_fragment(
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
		or total_distance < 70.0
		or _detached_shed_fragments.size() >= 36
		or _surface_fragment_material == null
	):
		return

	var sequence_value: float = float(_shed_sequence)
	var anchor_progress: float
	match burst_index:
		0:
			anchor_progress = 0.34
		1:
			anchor_progress = 0.45
		2:
			anchor_progress = 0.57
		_:
			anchor_progress = 0.68
	var progress: float = clampf(
		anchor_progress + sin(sequence_value * 8.13 + 1.7) * 0.024,
		0.30,
		0.73
	)
	var center_distance: float = total_distance * progress
	var fragment_length: float = lerpf(
		22.0, 32.0, absf(sin(sequence_value * 5.31 + 1.2))
	)
	var start_distance: float = maxf(center_distance - fragment_length * 0.5, 0.5)
	var end_distance: float = minf(center_distance + fragment_length * 0.5, total_distance * 0.91)
	if end_distance - start_distance < 12.0:
		return

	var fragment_distances: Array[float] = [start_distance]
	for point_index in range(1, path.size() - 1):
		var sample_distance: float = cumulative_distances[point_index]
		if sample_distance > start_distance + 0.1 and sample_distance < end_distance - 0.1:
			fragment_distances.append(sample_distance)
	fragment_distances.append(end_distance)

	var width_scale: float = lerpf(0.62, 0.78, absf(sin(sequence_value * 4.73 + 0.6)))
	var side: float = -1.0 if burst_index % 2 == 0 else 1.0
	var outer_edge := PackedVector2Array()
	var inner_edge := PackedVector2Array()
	var outer_uvs := PackedVector2Array()
	var inner_uvs := PackedVector2Array()
	for sample_index in range(fragment_distances.size()):
		var sample_distance: float = fragment_distances[sample_index]
		var section: Dictionary = _sample_trail_cross_section(
			sample_distance, path, cumulative_distances, tangents, normals, half_widths
		)
		var center: Vector2 = section["position"]
		var tangent: Vector2 = section["tangent"]
		var normal: Vector2 = section["normal"]
		var half_width: float = float(section["half_width"]) * width_scale
		var start_skew: float = 3.8 if sample_index == 0 else 0.0
		var end_skew: float = -2.8 if sample_index == fragment_distances.size() - 1 else 0.0
		var distance_skew: float = start_skew + end_skew
		outer_edge.append(center + normal * side * half_width * 0.94 + tangent * distance_skew)
		inner_edge.append(center + normal * side * half_width * 0.16 - tangent * distance_skew * 0.65)
		var outer_across: float = 0.0 if side > 0.0 else 1.0
		var inner_across: float = 0.43 if side > 0.0 else 0.57
		outer_uvs.append(Vector2(sample_distance / total_distance, outer_across))
		inner_uvs.append(Vector2(sample_distance / total_distance, inner_across))

	var global_vertices: Array[Vector2] = []
	var fragment_uvs := PackedVector2Array()
	var centroid_global := Vector2.ZERO
	for vertex_index in range(outer_edge.size()):
		global_vertices.append(outer_edge[vertex_index])
		fragment_uvs.append(outer_uvs[vertex_index])
		centroid_global += outer_edge[vertex_index]
	for vertex_index in range(inner_edge.size() - 1, -1, -1):
		global_vertices.append(inner_edge[vertex_index])
		fragment_uvs.append(inner_uvs[vertex_index])
		centroid_global += inner_edge[vertex_index]
	if global_vertices.size() < 6:
		return
	centroid_global /= float(global_vertices.size())

	var fragment_polygon := PackedVector2Array()
	for vertex in global_vertices:
		fragment_polygon.append(vertex - centroid_global)

	var shard := Polygon2D.new()
	shard.name = "DetachedCometSurfaceFragment"
	shard.z_as_relative = false
	shard.z_index = -2
	shard.polygon = fragment_polygon
	shard.uv = fragment_uvs
	shard.material = _surface_fragment_material
	shard.modulate = Color(1.08, 1.12, 1.24, 1.0)

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
		48.0, 78.0, absf(sin(sequence_value * 17.13 + 2.7))
	)
	var tangential_drift: float = sin(sequence_value * 7.73 + 2.1) * 8.0
	var lifetime: float = lerpf(
		0.78, 1.08, absf(sin(sequence_value * 3.91 + 0.8))
	)
	var angular_velocity: float = sin(sequence_value * 8.31 + 0.9) * 1.7
	var velocity: Vector2 = normals[source_index] * side * outward_speed + tangents[source_index] * tangential_drift
	_detached_shed_fragments.append({
		"node": shard,
		"velocity": velocity,
		"age": 0.0,
		"lifetime": lifetime,
		"angular_velocity": angular_velocity,
		"base_alpha": 1.0,
		"fade_start_fraction": 0.56
	})
	_shed_sequence += 1


func _spawn_shed_fragment(
	path: Array[Vector2],
	cumulative_distances: Array[float],
	total_distance: float,
	tangents: Array[Vector2],
	normals: Array[Vector2],
	half_widths: Array[float],
	burst_index: int
) -> void:
	# Small secondary chevrons cluster near the tail. They accent the larger
	# surface pieces without pretending to carve holes in the real trail.
	if (
		not shedding_enabled
		or path.size() < 6
		or total_distance < 55.0
		or _detached_shed_fragments.size() >= 36
		or _aura_fragment_material == null
	):
		return

	var sequence_value: float = float(_shed_sequence)
	var burst_progress: float = float(burst_index) / float(maxi(CHEVRON_BURST_PIECE_COUNT - 1, 1))
	var progress: float = clampf(
		lerpf(0.73, 0.90, burst_progress)
		+ sin(sequence_value * 11.7 + 2.4) * 0.018,
		0.68,
		0.93
	)
	var center_distance: float = total_distance * progress
	var fragment_length: float = lerpf(
		15.0, 23.0, absf(sin(sequence_value * 5.31 + 1.2))
	)
	var start_distance: float = maxf(center_distance - fragment_length * 0.5, 0.5)
	var end_distance: float = minf(center_distance + fragment_length * 0.5, total_distance * 0.98)
	if end_distance - start_distance < 7.0:
		return

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
		var t: float = (sample_distance - start_distance) / (end_distance - start_distance)
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
	shard.name = "DetachedAuraChevron"
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
		38.0, 62.0, absf(sin(sequence_value * 17.13 + 2.7))
	)
	var drift_speed: float = lerpf(
		8.0, 18.0, absf(sin(sequence_value * 6.73 + 1.4))
	)
	var lifetime: float = lerpf(
		0.34, 0.48, absf(sin(sequence_value * 3.91 + 0.8))
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
		"base_alpha": 1.0,
		"fade_start_fraction": 0.18
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
		velocity *= maxf(0.0, 1.0 - delta * 0.8)
		shard.global_position += velocity * delta
		shard.rotation += float(fragment["angular_velocity"]) * delta
		var fade_start: float = lifetime * float(fragment.get("fade_start_fraction", 0.18))
		var fade: float = 1.0 - smoothstep(fade_start, lifetime, age)
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
		var particle_material := emitter.process_material as ParticleProcessMaterial
		if particle_material != null:
			particle_material.direction = Vector3(
				_last_emission_direction.x,
				_last_emission_direction.y,
				0.0
			)



func _update_energy_pulse(delta: float) -> void:
	# A scheduled full-ribbon pulse travels from the orb toward the tail.
	# This function only advances a pulse after a landing sequence has launched it.
	if _pulse_active:
		if (
			_latest_trail_path.size() < 6
			or _latest_trail_total_distance < 70.0
		):
			# If the trail briefly becomes invalid mid-pulse, retry only after a
			# future eligible landing rather than launching into an empty ribbon.
			_pulse_active = false
			_pulse_progress = -1.0
			_landing_release_pending = true
		else:
			var previous_progress: float = _pulse_progress
			_pulse_progress = minf(_pulse_progress + delta * ENERGY_PULSE_SPEED, 1.0)

			if (
				_pulse_filament_enabled
				and not _pulse_filament_spawned
				and previous_progress < _pulse_filament_progress
				and _pulse_progress >= _pulse_filament_progress
			):
				_spawn_pulse_filament(_pulse_filament_progress)
				_pulse_filament_spawned = true

			if _pulse_progress >= ENERGY_PULSE_END:
				_pulse_active = false
				_pulse_progress = -1.0

	var progress_for_shader: float = _pulse_progress if _pulse_active else -1.0
	var strength_for_shader: float = 1.0 if _pulse_active else 0.0
	var materials: Array[ShaderMaterial] = [
		_unified_shape.material as ShaderMaterial,
		_energy_line.material as ShaderMaterial,
		_trail_aura.material as ShaderMaterial
	]
	for shader_material in materials:
		if shader_material != null:
			shader_material.set_shader_parameter("pulse_progress", progress_for_shader)
			shader_material.set_shader_parameter("pulse_strength", strength_for_shader)


func _start_energy_pulse() -> bool:
	if (
		_pulse_active
		or _latest_trail_path.size() < 6
		or _latest_trail_total_distance < 70.0
	):
		return false

	_pulse_active = true
	_pulse_progress = 0.0
	_pulse_filament_progress = _visual_rng.randf_range(0.34, 0.67)
	# The release has a configurable chance to spawn its outward filament.
	_pulse_filament_enabled = _visual_rng.randf() < clampf(full_release_filament_chance, 0.0, 1.0)
	_pulse_filament_spawned = false
	return true


func _spawn_pulse_filament(progress: float) -> void:
	if (
		_latest_trail_path.size() < 6
		or _latest_trail_total_distance < 90.0
		or _energy_filaments.size() >= ENERGY_FILAMENT_MAX_ACTIVE
	):
		return

	var section: Dictionary = _sample_trail_cross_section(
		_latest_trail_total_distance * progress,
		_latest_trail_path,
		_latest_trail_distances,
		_latest_trail_tangents,
		_latest_trail_normals,
		_latest_trail_half_widths
	)
	var center: Vector2 = section["position"]
	var tangent: Vector2 = section["tangent"]
	var normal: Vector2 = section["normal"]
	var half_width: float = float(section["half_width"])
	var side: float = -1.0 if _visual_rng.randf() < 0.5 else 1.0
	var outward: Vector2 = normal * side
	var anchor: Vector2 = center + outward * half_width * 0.86
	var length: float = _visual_rng.randf_range(24.0, 40.0)

	var offsets := PackedVector2Array()
	offsets.append(Vector2.ZERO)
	offsets.append(outward * length * 0.22 + tangent * _visual_rng.randf_range(-3.0, 3.0))
	offsets.append(outward * length * 0.46 + tangent * _visual_rng.randf_range(-7.0, 7.0))
	offsets.append(outward * length * 0.73 + tangent * _visual_rng.randf_range(-5.0, 8.0))
	offsets.append(outward * length + tangent * _visual_rng.randf_range(-7.0, 7.0))

	var lifetime: float = _visual_rng.randf_range(0.20, 0.31)
	_spawn_energy_filament_line(
		anchor,
		offsets,
		_visual_rng.randf_range(2.0, 2.8),
		lifetime
	)

	# A minority of events split near the outer half into a shorter secondary arc.
	if _visual_rng.randf() < 0.32 and _energy_filaments.size() < ENERGY_FILAMENT_MAX_ACTIVE:
		var branch_origin: Vector2 = anchor + offsets[2]
		var branch_direction: Vector2 = (outward + tangent * _visual_rng.randf_range(-0.48, 0.48)).normalized()
		var branch_length: float = length * _visual_rng.randf_range(0.42, 0.62)
		var branch_offsets := PackedVector2Array()
		branch_offsets.append(Vector2.ZERO)
		branch_offsets.append(branch_direction * branch_length * 0.36 + tangent * _visual_rng.randf_range(-3.0, 3.0))
		branch_offsets.append(branch_direction * branch_length * 0.72 + tangent * _visual_rng.randf_range(-4.0, 4.0))
		branch_offsets.append(branch_direction * branch_length)
		_spawn_energy_filament_line(
			branch_origin,
			branch_offsets,
			_visual_rng.randf_range(1.1, 1.6),
			lifetime * 0.88
		)


func _spawn_energy_filament_line(
	origin: Vector2,
	point_offsets: PackedVector2Array,
	line_width: float,
	lifetime: float
) -> void:
	var world_root: Node2D = get_tree().current_scene as Node2D
	if world_root == null:
		world_root = get_parent() as Node2D
	if world_root == null or point_offsets.size() < 2:
		return

	var filament := Line2D.new()
	filament.name = "CometPulseFilament"
	filament.z_as_relative = false
	filament.z_index = -1
	filament.width = line_width
	filament.joint_mode = Line2D.LINE_JOINT_ROUND
	filament.begin_cap_mode = Line2D.LINE_CAP_ROUND
	filament.end_cap_mode = Line2D.LINE_CAP_ROUND
	filament.antialiased = true

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	filament.material = additive
	filament.gradient = _make_filament_gradient()
	world_root.add_child(filament)
	filament.global_position = origin
	for point_offset in point_offsets:
		filament.add_point(point_offset)

	_energy_filaments.append({
		"line": filament,
		"age": 0.0,
		"lifetime": lifetime,
		"base_width": line_width
	})


func _make_filament_gradient() -> Gradient:
	var gradient := Gradient.new()
	if visual_palette == 1:
		gradient.set_color(0, Color(1.20, 0.82, 1.65, 0.92))
		gradient.set_color(1, Color(0.58, 0.14, 1.25, 0.0))
	else:
		gradient.set_color(0, Color(0.62, 1.20, 1.70, 0.92))
		gradient.set_color(1, Color(0.10, 0.42, 1.25, 0.0))
	return gradient


func _update_energy_filaments(delta: float) -> void:
	for index in range(_energy_filaments.size() - 1, -1, -1):
		var filament_data: Dictionary = _energy_filaments[index]
		var line := filament_data.get("line") as Line2D
		if not is_instance_valid(line):
			_energy_filaments.remove_at(index)
			continue

		var age: float = float(filament_data["age"]) + delta
		var lifetime: float = float(filament_data["lifetime"])
		var t: float = clampf(age / maxf(lifetime, 0.001), 0.0, 1.0)
		var attack: float = smoothstep(0.0, 0.10, t)
		var fade: float = 1.0 - smoothstep(0.22, 1.0, t)
		var modulate_color: Color = line.modulate
		modulate_color.a = attack * fade
		line.modulate = modulate_color
		line.width = float(filament_data["base_width"]) * lerpf(1.0, 0.42, t)

		filament_data["age"] = age
		if age >= lifetime:
			line.queue_free()
			_energy_filaments.remove_at(index)
		else:
			_energy_filaments[index] = filament_data



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

	if _rim_aura != null:
		var rim_aura_material := _rim_aura.material as ShaderMaterial
		if rim_aura_material != null:
			rim_aura_material = rim_aura_material.duplicate() as ShaderMaterial
			rim_aura_material.set_shader_parameter("palette_mode", visual_palette)
			_rim_aura.material = rim_aura_material

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

	var aura_material := _trail_aura.material as ShaderMaterial
	if aura_material != null:
		aura_material = aura_material.duplicate() as ShaderMaterial
		aura_material.set_shader_parameter("palette_mode", visual_palette)
		_trail_aura.material = aura_material

	_set_line_gradient(_energy_line, energy_head, energy_tail)
	_set_line_gradient(_trail_aura, aura_head, aura_tail)

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
