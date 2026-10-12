extends Node2D

const PARTICLE_EMISSION_OFFSET: float = 28.0

## Visual energy trail for the player ball.
## The trail is layered: a soft outer aura, a turbulent inner stream, two
## independently drifting wisps, and a restrained geometric fragment field.
## This script only controls visuals; ball movement and collision remain in ball.gd.

@export_category("Trail History")
@export var max_points: int = 27
@export var min_distance: float = 2.0
@export var max_segment_distance: float = 120.0
@export_range(0.0, 40.0, 1.0) var trail_head_offset: float = 20.0

@export_category("Visual Palette")
@export_enum("Electric Blue", "Rich Violet") var visual_palette: int = 0
@export_range(0.0, 2.0, 0.05) var wisp_strength: float = 1.0

@onready var _energy_line: Line2D = $EnergyLine
@onready var _trail_aura: Line2D = $TrailAura
@onready var _wisp_left: Line2D = $WispLeft
@onready var _wisp_right: Line2D = $WispRight
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
	_update_rim_direction(ball)
	_previous_ball_position = current_world_position


func _update_trail_lines() -> void:
	if _points.size() < 2:
		_energy_line.clear_points()
		_trail_aura.clear_points()
		_wisp_left.clear_points()
		_wisp_right.clear_points()
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

	_update_wisp_line(_wisp_left, 1.0, 11.0, 0.3)
	_update_wisp_line(_wisp_right, -1.0, 14.0, 2.0)


func _get_animated_trail_point(index: int) -> Vector2:
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
	var head_offset: float = trail_head_offset if index == 0 else 0.0
	return point - tangent * head_offset + perpendicular * drift


func _update_wisp_line(
	line: Line2D,
	side: float,
	amplitude: float,
	phase: float
) -> void:
	line.clear_points()
	if _points.size() < 2:
		return

	var denominator: float = float(_points.size() - 1)
	for i in range(_points.size()):
		var raw_point: Vector2 = _points[i]
		var point: Vector2 = _get_animated_trail_point(i)
		var tangent: Vector2

		if i < _points.size() - 1:
			tangent = raw_point - _points[i + 1]
		else:
			tangent = _points[i - 1] - raw_point

		if tangent.length_squared() < 0.001:
			line.add_point(line.to_local(point))
			continue

		tangent = tangent.normalized()
		var perpendicular := Vector2(-tangent.y, tangent.x)
		var t: float = float(i) / denominator
		var envelope: float = smoothstep(0.0, 0.24, t)
		var sway: float = sin(_trail_time * 0.75 + t * 5.8 + phase)
		# Keep each wisp on its own side while varying its offset, rather than
		# allowing rapid oscillation to make the wisps swap sides.
		var drift: float = (4.0 + amplitude * 0.35 * (1.0 + sway)) * envelope * t
		var offset: Vector2 = perpendicular * side * drift * wisp_strength

		line.add_point(line.to_local(point + offset))


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
		current_world_position + _last_emission_direction * PARTICLE_EMISSION_OFFSET
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


func _update_rim_direction(ball: CharacterBody2D) -> void:
	# Convert the trail's rearward direction into the ball's local space so
	# the rim opening follows the trail as the ball changes direction.
	var local_trail_direction: Vector2 = (
		ball.to_local(ball.global_position + _last_emission_direction)
		- ball.to_local(ball.global_position)
	)
	if local_trail_direction.length_squared() < 0.001:
		local_trail_direction = Vector2.DOWN
	else:
		local_trail_direction = local_trail_direction.normalized()

	var orb_material := _ball_visual.material as ShaderMaterial
	if orb_material != null:
		orb_material.set_shader_parameter("trail_direction", local_trail_direction)

	if _rim_aura != null:
		var rim_material := _rim_aura.material as ShaderMaterial
		if rim_material != null:
			rim_material.set_shader_parameter("trail_direction", local_trail_direction)


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

	var energy_material := _energy_line.material as ShaderMaterial
	if energy_material != null:
		energy_material = energy_material.duplicate() as ShaderMaterial
		energy_material.set_shader_parameter("palette_mode", visual_palette)
		_energy_line.material = energy_material

	_set_line_gradient(_energy_line, energy_head, energy_tail)
	_set_line_gradient(_trail_aura, aura_head, aura_tail)
	_set_line_gradient(_wisp_left, left_wisp_head, left_wisp_tail)
	_set_line_gradient(_wisp_right, right_wisp_head, right_wisp_tail)

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
