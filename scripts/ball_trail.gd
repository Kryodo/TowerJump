extends Node2D

## Visual energy trail for the player ball.
## Stores recent world positions and draws a tapered ribbon.
## Internal energy will be handled separately.

@export_category("Trail")
@export var max_points: int = 18
@export var min_distance: float = 3.0
@export var max_segment_distance: float = 120.0

@export_category("Outer Ribbon")
@export var start_width: float = 58.0
@export var end_width: float = 2.0
@export var start_alpha: float = 0.75
@export var end_alpha: float = 0.0

const TRAIL_COLOR := Color(0.0, 1.0, 1.0, 1.0)

@export_category("Outer Aura")
@export var aura_width: float = 3.0
@export var aura_alpha: float = 0.28

const AURA_COLOR := Color(0.0, 0.75, 0.9, 1.0)

var _points: Array[Vector2] = []

@onready var _energy_line: Line2D = $EnergyLine
@onready var _trail_aura: Line2D = $TrailAura

var _previous_ball_position: Vector2

func _ready() -> void:
	z_index = -1
	_previous_ball_position = global_position
	queue_redraw()


func _process(_delta: float) -> void:
	var ball := get_parent()

	if ball == null:
		return

	var current_world_position: Vector2 = ball.global_position

	if _points.is_empty():
		_points.append(current_world_position)
		_update_energy_line()
		_update_particle_emitter()
		queue_redraw()
		return

	var last_world_position: Vector2 = _points[0]

	var distance_from_trail: float = current_world_position.distance_to(
		last_world_position
	)

	# If the ball jumped an unusually large distance, do not connect
	# the old trail to the new position.
	if distance_from_trail > max_segment_distance:
		_points.clear()
		_points.append(current_world_position)
		_update_energy_line()
		queue_redraw()
		return

	if distance_from_trail >= min_distance:
		_points.push_front(current_world_position)

		while _points.size() > max_points:
			_points.pop_back()

	_update_energy_line()
	queue_redraw()

func _update_energy_line() -> void:
	if _points.size() < 2:
		_energy_line.clear_points()
		_trail_aura.clear_points()
		return

	_energy_line.clear_points()
	_trail_aura.clear_points()

	for point in _points:
		_energy_line.add_point(
			_energy_line.to_local(point)
		)

		_trail_aura.add_point(
			_trail_aura.to_local(point)
		)

func _update_particle_emitter() -> void:
	var current_position := global_position
	var movement := current_position - _previous_ball_position

	if movement.length() > 0.01:
		$TrailParticles.global_position = _previous_ball_position

	_previous_ball_position = current_position

func _draw() -> void:
	if _points.size() < 2:
		return

	for i in range(_points.size() - 1):
		var current_world: Vector2 = _points[i]
		var next_world: Vector2 = _points[i + 1]

		var current: Vector2 = to_local(current_world)
		var next: Vector2 = to_local(next_world)

		var direction: Vector2 = current - next

		if direction.length_squared() < 0.001:
			continue

		direction = direction.normalized()

		var perpendicular := Vector2(
			-direction.y,
			direction.x
		)

		var t: float = float(i) / float(_points.size() - 1)

		var width_t: float = pow(t, 0.65)

		var width: float = lerp(
			start_width,
			end_width,
			width_t
		)

		var alpha: float = lerp(
			start_alpha,
			end_alpha,
			t
		)

		var half_width: float = width * 0.5

		var left := current + perpendicular * half_width
		var right := current - perpendicular * half_width

		var next_left := next + perpendicular * half_width
		var next_right := next - perpendicular * half_width

		var polygon := PackedVector2Array([
			left,
			next_left,
			next_right,
			right
		])

		draw_colored_polygon(
			polygon,
			Color(
				TRAIL_COLOR.r,
				TRAIL_COLOR.g,
				TRAIL_COLOR.b,
				alpha
			)
		)
		
	_draw_outer_aura()

func _draw_outer_aura() -> void:
	if _points.size() < 2:
		return

	var left_points := PackedVector2Array()
	var right_points := PackedVector2Array()

	for i in range(_points.size() - 1):
		var current_world: Vector2 = _points[i]
		var next_world: Vector2 = _points[i + 1]

		var current: Vector2 = to_local(current_world)
		var next: Vector2 = to_local(next_world)

		var direction: Vector2 = current - next

		if direction.length_squared() < 0.001:
			continue

		direction = direction.normalized()

		var perpendicular := Vector2(
			-direction.y,
			direction.x
		)

		var t: float = float(i) / float(_points.size() - 1)

		var width_t: float = pow(t, 0.65)

		var width: float = lerp(
			start_width,
			end_width,
			width_t
		)

		var half_width: float = width * 0.5

		var aura_offset: float = aura_width * (1.0 - t)

		left_points.append(
			current + perpendicular * (half_width + aura_offset)
		)

		right_points.append(
			current - perpendicular * (half_width + aura_offset)
		)

	if left_points.size() >= 2:
		draw_polyline(
			left_points,
			Color(
				AURA_COLOR.r,
				AURA_COLOR.g,
				AURA_COLOR.b,
				aura_alpha
			),
			aura_width,
			true
		)

	if right_points.size() >= 2:
		draw_polyline(
			right_points,
			Color(
				AURA_COLOR.r,
				AURA_COLOR.g,
				AURA_COLOR.b,
				aura_alpha
			),
			aura_width,
			true
		)	
