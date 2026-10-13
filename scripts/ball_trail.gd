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

const UNIFIED_HEAD_RADIUS: float = 31.0
const UNIFIED_ROOT_BLEND_DISTANCE: float = 38.0
const UNIFIED_HEAD_ARC_SEGMENTS: int = 20
const WISP_CURVE_SAMPLES: int = 23
const WISP_FORK_START_INDEX: int = 15
const WISP_FORK_SAMPLES: int = 11

@export_category("Visual Palette")
@export_enum("Electric Blue", "Rich Violet") var visual_palette: int = 0
@export_range(0.0, 2.0, 0.05) var wisp_strength: float = 1.0

@onready var _energy_line: Line2D = $EnergyLine
@onready var _trail_aura: Line2D = $TrailAura
@onready var _unified_shape: Polygon2D = get_node_or_null("UnifiedCometShape") as Polygon2D
@onready var _unified_contour: Line2D = get_node_or_null("UnifiedCometContour") as Line2D
@onready var _wisp_head: Line2D = $WispHead
@onready var _wisp_streamer: Line2D = $WispStreamer
@onready var _wisp_fork: Line2D = $WispFork
@onready var _ball_visual: Sprite2D = get_parent().get_node("Visual") as Sprite2D
@onready var _rim_aura: Sprite2D = get_parent().get_node_or_null("RimAura") as Sprite2D

var _points: Array[Vector2] = []
var _particle_emitters: Array[GPUParticles2D] = []
var _previous_ball_position: Vector2 = Vector2.ZERO
var _trail_time: float = 0.0
var _last_emission_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	z_index = -1
	_previous_ball_position = global_position

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
	_update_trail_lines()


func _process(delta: float) -> void:
	var ball := get_parent() as CharacterBody2D
	if ball == null:
		return

	_trail_time += delta
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

	_update_trail_lines()
	_update_particle_emitters(current_world_position, movement, distance_from_trail)
	_previous_ball_position = current_world_position


func _update_trail_lines() -> void:
	if _points.size() < 2:
		_energy_line.clear_points()
		_trail_aura.clear_points()
		_wisp_head.clear_points()
		_wisp_streamer.clear_points()
		_wisp_fork.clear_points()
		if _unified_shape != null:
			_unified_shape.polygon = PackedVector2Array()
			_unified_shape.uv = PackedVector2Array()
		if _unified_contour != null:
			_unified_contour.clear_points()
		return

	_energy_line.clear_points()
	_trail_aura.clear_points()

	# Rebuild the stream every frame with a tiny animated lateral drift.
	# This keeps the energy alive at the jump apex even when the ball itself
	# has almost no velocity and no new trail samples are being collected.
	for i in range(_points.size()):
		var point: Vector2 = _get_animated_trail_point(i)
		_energy_line.add_point(_energy_line.to_local(point))
		_trail_aura.add_point(_trail_aura.to_local(point))

	_update_wisp_lines()
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
		var root_blend: float = 1.0 - smoothstep(
			0.0,
			UNIFIED_ROOT_BLEND_DISTANCE,
			cumulative_distances[i]
		)
		half_widths.append(lerp(line_half_width, UNIFIED_HEAD_RADIUS, root_blend))

	var polygon_points := PackedVector2Array()
	var polygon_uvs := PackedVector2Array()
	var root_direction: Vector2 = tangents[0]
	var root_normal: Vector2 = normals[0]

	# Close the fill across the FRONT half of the ball. The real orb is drawn
	# above this skin, so its core remains untouched and the closure stays hidden.
	for arc_index in range(UNIFIED_HEAD_ARC_SEGMENTS + 1):
		var arc_t: float = float(arc_index) / float(UNIFIED_HEAD_ARC_SEGMENTS)
		var angle: float = PI * 0.5 + PI * arc_t
		var world_point: Vector2 = (
			path[0]
			+ root_direction * UNIFIED_HEAD_RADIUS * cos(angle)
			+ root_normal * UNIFIED_HEAD_RADIUS * sin(angle)
		)
		polygon_points.append(_unified_shape.to_local(world_point))
		polygon_uvs.append(Vector2(0.0, arc_t))

	# Right edge follows the same historical trajectory as the trail lines.
	for i in range(1, path.size() - 1):
		var right_point: Vector2 = path[i] - normals[i] * half_widths[i]
		polygon_points.append(_unified_shape.to_local(right_point))
		polygon_uvs.append(Vector2(cumulative_distances[i] / total_distance, 1.0))

	# Single tip vertex avoids coincident left/right end vertices at zero width.
	polygon_points.append(_unified_shape.to_local(path[path.size() - 1]))
	polygon_uvs.append(Vector2(1.0, 0.5))

	# Return along the left edge and close against the orb's rear contour.
	for i in range(path.size() - 2, 0, -1):
		var left_point: Vector2 = path[i] + normals[i] * half_widths[i]
		polygon_points.append(_unified_shape.to_local(left_point))
		polygon_uvs.append(Vector2(cumulative_distances[i] / total_distance, 0.0))

	_unified_shape.polygon = polygon_points
	_unified_shape.uv = polygon_uvs

	# Draw only the exposed silhouette: begin at one shoulder, follow that
	# side of the shared body to the tip, then return along the opposite side.
	# The front head arc is deliberately omitted; the orb supplies that contour.
	if _unified_contour != null:
		var contour_points := PackedVector2Array()
		contour_points.append(
			_unified_shape.to_local(path[0] + root_normal * UNIFIED_HEAD_RADIUS)
		)
		for i in range(1, path.size() - 1):
			contour_points.append(
				_unified_shape.to_local(path[i] + normals[i] * half_widths[i])
			)
		contour_points.append(_unified_shape.to_local(path[path.size() - 1]))
		for i in range(path.size() - 2, 0, -1):
			contour_points.append(
				_unified_shape.to_local(path[i] - normals[i] * half_widths[i])
			)
		contour_points.append(
			_unified_shape.to_local(path[0] - root_normal * UNIFIED_HEAD_RADIUS)
		)
		_unified_contour.points = contour_points

	# The same direction drives both rim shaders, tying their contour treatment
	# to the actual shared silhouette instead of fading an independent effect.
	var ball := get_parent() as CharacterBody2D
	if ball != null:
		var local_tail_direction: Vector2 = (
			ball.to_local(ball.global_position + root_direction)
			- ball.to_local(ball.global_position)
		).normalized()
		var orb_material := _ball_visual.material as ShaderMaterial
		if orb_material != null:
			orb_material.set_shader_parameter("trail_direction", local_tail_direction)
		if _rim_aura != null:
			var rim_material := _rim_aura.material as ShaderMaterial
			if rim_material != null:
				rim_material.set_shader_parameter("trail_direction", local_tail_direction)


func _update_wisp_lines() -> void:
	_wisp_head.clear_points()
	_wisp_streamer.clear_points()
	_wisp_fork.clear_points()
	if _points.size() < 2:
		return

	# Build the animated centreline once. The wisps sample this shared path by
	# distance, so their different start/end locations don't depend on point count.
	var path: Array[Vector2] = []
	for i in range(_points.size()):
		path.append(_get_animated_trail_point(i))

	var cumulative_distances: Array[float] = [0.0]
	var total_distance: float = 0.0
	for i in range(1, path.size()):
		total_distance += path[i - 1].distance_to(path[i])
		cumulative_distances.append(total_distance)

	if total_distance < 0.001:
		return

	# Short head-born filament: partially hidden by the orb, then it peels out
	# and fades around the upper-middle of the comet instead of running its length.
	_build_wisp_curve(
		_wisp_head, path, cumulative_distances, total_distance,
		0.0, 0.47, 1.0, 0.12, 1.04, 0.35, 1.15, 1.25
	)

	# A separate streamer grows out of the existing flow part-way down the body.
	# It continues toward the tail but stays finer and less prominent than the core.
	_build_wisp_curve(
		_wisp_streamer, path, cumulative_distances, total_distance,
		0.29, 0.985, -1.0, 0.24, 1.12, 1.9, 2.75, 0.95
	)

	# Fork the longer streamer near its end. The first branch point is copied
	# from the actual streamer point to guarantee a joined Y rather than a gap.
	_build_wisp_fork(path, cumulative_distances, total_distance)


func _build_wisp_curve(
	line: Line2D,
	path: Array[Vector2],
	cumulative_distances: Array[float],
	total_distance: float,
	start_progress: float,
	end_progress: float,
	side: float,
	start_spread: float,
	end_spread: float,
	phase: float,
	clearance: float,
	bend_strength: float
) -> void:
	line.clear_points()
	if path.size() < 2 or total_distance < 0.001:
		return

	for sample_index in range(WISP_CURVE_SAMPLES):
		var local_progress: float = (
			float(sample_index) / float(WISP_CURVE_SAMPLES - 1)
		)
		var trail_progress: float = lerp(
			start_progress,
			end_progress,
			local_progress
		)
		var center: Vector2 = _sample_trail_path(
			path, cumulative_distances, total_distance, trail_progress
		)
		var before: Vector2 = _sample_trail_path(
			path, cumulative_distances, total_distance,
			max(0.0, trail_progress - 0.006)
		)
		var after: Vector2 = _sample_trail_path(
			path, cumulative_distances, total_distance,
			min(1.0, trail_progress + 0.006)
		)
		var tangent: Vector2 = after - before
		if tangent.length_squared() < 0.001:
			tangent = Vector2.DOWN
		else:
			tangent = tangent.normalized()
		var normal := Vector2(-tangent.y, tangent.x)

		var silhouette_half_width: float = _get_silhouette_half_width(
			trail_progress, total_distance
		)
		var spread_blend: float = smoothstep(0.0, 0.68, local_progress)
		var spread_ratio: float = lerp(
			start_spread, end_spread, spread_blend
		)

		# Keep the root subtly inside the flow. The clearance grows as the wisp
		# peels away, while a small bend gives it life without making long arms.
		var clearance_blend: float = smoothstep(0.0, 0.62, local_progress)
		var edge_clearance: float = clearance * min(wisp_strength, 1.5) * clearance_blend
		var organic_bend: float = (
			sin(_trail_time * 0.72 + trail_progress * 9.0 + phase)
			* bend_strength
			* sin(PI * local_progress)
			* min(wisp_strength, 1.2)
		)
		var lateral_offset: float = max(
			1.0,
			silhouette_half_width * spread_ratio + edge_clearance + organic_bend
		)
		var world_point: Vector2 = center + normal * side * lateral_offset
		line.add_point(line.to_local(world_point))


func _build_wisp_fork(
	path: Array[Vector2],
	cumulative_distances: Array[float],
	total_distance: float
) -> void:
	_wisp_fork.clear_points()
	if (
		_wisp_streamer.points.size() != WISP_CURVE_SAMPLES
		or _wisp_streamer.points.size() <= WISP_FORK_START_INDEX
	):
		return

	var fork_start_index: int = WISP_FORK_START_INDEX
	var local_progress: float = (
		float(fork_start_index) / float(WISP_CURVE_SAMPLES - 1)
	)
	var fork_start_progress: float = lerp(0.29, 0.985, local_progress)
	var first_local_point: Vector2 = _wisp_streamer.points[fork_start_index]
	var first_world_point: Vector2 = _wisp_streamer.to_global(first_local_point)
	_wisp_fork.add_point(_wisp_fork.to_local(first_world_point))

	var trail_center: Vector2 = _sample_trail_path(
		path, cumulative_distances, total_distance, fork_start_progress
	)
	var before: Vector2 = _sample_trail_path(
		path, cumulative_distances, total_distance,
		max(0.0, fork_start_progress - 0.006)
	)
	var after: Vector2 = _sample_trail_path(
		path, cumulative_distances, total_distance,
		min(1.0, fork_start_progress + 0.006)
	)
	var tangent: Vector2 = after - before
	if tangent.length_squared() < 0.001:
		tangent = Vector2.DOWN
	else:
		tangent = tangent.normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	var side: float = -1.0
	var starting_offset: float = (
		(first_world_point - trail_center).dot(normal * side)
	)

	# The branch begins exactly on the streamer, then separates by only a few
	# pixels as it approaches the tail tip. It is a fine split, not a second arm.
	for sample_index in range(1, WISP_FORK_SAMPLES):
		var branch_progress: float = (
			float(sample_index) / float(WISP_FORK_SAMPLES - 1)
		)
		var trail_progress: float = lerp(
			fork_start_progress, 0.985, branch_progress
		)
		var center: Vector2 = _sample_trail_path(
			path, cumulative_distances, total_distance, trail_progress
		)
		var local_before: Vector2 = _sample_trail_path(
			path, cumulative_distances, total_distance,
			max(0.0, trail_progress - 0.006)
		)
		var local_after: Vector2 = _sample_trail_path(
			path, cumulative_distances, total_distance,
			min(1.0, trail_progress + 0.006)
		)
		var branch_tangent: Vector2 = local_after - local_before
		if branch_tangent.length_squared() < 0.001:
			branch_tangent = Vector2.DOWN
		else:
			branch_tangent = branch_tangent.normalized()
		var branch_normal := Vector2(-branch_tangent.y, branch_tangent.x)
		var silhouette_half_width: float = _get_silhouette_half_width(
			trail_progress, total_distance
		)

		var separation_blend: float = smoothstep(0.0, 0.72, branch_progress)
		var target_base_offset: float = silhouette_half_width * lerp(
			1.12, 1.30, separation_blend
		) + 2.75 * min(wisp_strength, 1.5)
		var continuity_blend: float = smoothstep(0.0, 0.24, branch_progress)
		var base_offset: float = lerp(
			starting_offset, target_base_offset, continuity_blend
		)
		var fork_separation: float = 4.2 * smoothstep(
			0.0, 0.74, branch_progress
		)
		var fine_drift: float = sin(
			_trail_time * 0.80 + branch_progress * 4.4 + 0.9
		) * 0.45 * sin(PI * branch_progress)
		var world_point: Vector2 = (
			center + branch_normal * side * (base_offset + fork_separation + fine_drift)
		)
		_wisp_fork.add_point(_wisp_fork.to_local(world_point))


func _sample_trail_path(
	path: Array[Vector2],
	cumulative_distances: Array[float],
	total_distance: float,
	progress: float
) -> Vector2:
	var target_distance: float = clampf(progress, 0.0, 1.0) * total_distance
	for i in range(cumulative_distances.size() - 1):
		var segment_end: float = cumulative_distances[i + 1]
		if target_distance <= segment_end:
			var segment_start: float = cumulative_distances[i]
			var segment_length: float = segment_end - segment_start
			if segment_length < 0.001:
				return path[i]
			var segment_progress: float = (
				(target_distance - segment_start) / segment_length
			)
			return path[i].lerp(path[i + 1], segment_progress)
	return path[path.size() - 1]


func _get_silhouette_half_width(
	progress: float,
	total_distance: float
) -> float:
	var width_factor: float = 1.0
	if _trail_aura.width_curve != null:
		width_factor = _trail_aura.width_curve.sample_baked(progress)
	var trail_half_width: float = _trail_aura.width * width_factor * 0.5
	var root_blend: float = 1.0 - smoothstep(
		0.0,
		UNIFIED_ROOT_BLEND_DISTANCE,
		progress * total_distance
	)
	return lerp(trail_half_width, UNIFIED_HEAD_RADIUS, root_blend)




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
	var left_wisp_head: Color
	var left_wisp_tail: Color
	var right_wisp_head: Color
	var right_wisp_tail: Color
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
		left_wisp_head = Color(1.0, 0.60, 1.0, 1.0)
		left_wisp_tail = Color(0.42, 0.06, 0.88, 1.0)
		right_wisp_head = Color(0.74, 0.38, 1.0, 1.0)
		right_wisp_tail = Color(0.20, 0.035, 0.62, 1.0)
		soft_particle_tint = Color(0.58, 0.32, 0.90, 0.76)
		diamond_tint = Color(0.98, 0.52, 1.20, 1.0)
		square_tint = Color(0.58, 0.20, 1.12, 0.96)
		shard_tint = Color(1.0, 0.70, 1.25, 1.0)
		contour_color = Color(1.25, 0.42, 2.2, 1.0)
	else:
		energy_head = Color(0.72, 0.94, 1.0, 1.0)
		energy_tail = Color(0.035, 0.16, 0.82, 1.0)
		aura_head = Color(0.12, 0.58, 1.0, 1.0)
		aura_tail = Color(0.008, 0.035, 0.25, 1.0)
		left_wisp_head = Color(0.70, 0.96, 1.0, 1.0)
		left_wisp_tail = Color(0.035, 0.20, 0.95, 1.0)
		right_wisp_head = Color(0.25, 0.62, 1.0, 1.0)
		right_wisp_tail = Color(0.015, 0.08, 0.55, 1.0)
		soft_particle_tint = Color(0.18, 0.48, 0.82, 0.72)
		diamond_tint = Color(0.40, 0.78, 1.25, 1.0)
		square_tint = Color(0.12, 0.42, 1.18, 0.96)
		shard_tint = Color(0.62, 0.90, 1.30, 1.0)
		contour_color = Color(0.16, 0.90, 1.8, 1.0)

	# Duplicate materials locally so palette changes don't mutate shared resources.
	var orb_material := _ball_visual.material as ShaderMaterial
	if orb_material != null:
		orb_material = orb_material.duplicate() as ShaderMaterial
		orb_material.set_shader_parameter("palette_mode", visual_palette)
		_ball_visual.material = orb_material

	if _rim_aura != null:
		var rim_aura_material := _rim_aura.material as ShaderMaterial
		if rim_aura_material != null:
			rim_aura_material.set_shader_parameter("palette_mode", visual_palette)

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
	_set_line_gradient(_wisp_head, left_wisp_head, left_wisp_tail)
	_set_line_gradient(_wisp_streamer, right_wisp_head, right_wisp_tail)
	_set_line_gradient(_wisp_fork, right_wisp_head, right_wisp_tail)
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
