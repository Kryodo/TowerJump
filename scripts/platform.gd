extends StaticBody2D
## Wiederverwendbare Plattform (StaticBody2D mit One-Way-Collision) in vier
## Varianten (siehe PlatformType). Wird vom PlatformSpawner gepoolt: Instanzen
## werden nie gelöscht, sondern per spawn_as() an eine neue Stelle "teleportiert"
## und dabei komplett neu konfiguriert (Typ, Position, Zustand).

enum PlatformType {
	NORMAL,
	MOVING,
	BREAKABLE,
	SPRING,
}

@export var width: float = 220.0
@export var height: float = 20.0

var width_scale: float = 1.0

@export_group("Beweglich")
@export var move_radius: float = 90.0
@export var move_speed: float = 1.6

@export_group("Brüchig")
@export var breakable_warning_duration: float = 0.3
@export var breakable_flicker_color: Color = Color(1.0, 0.35, 0.25, 1.0)
@export var breakable_wobble_amplitude: float = 5.0

@export_group("Spring")
@export var spring_multiplier: float = 1.75

const NEON_COLOR := Color(0.0, 0.65, 0.90, 1.0)
const PLATFORM_BODY_COLOR := Color("#0B111B")


const BEVEL := 4.0
const EDGE_HEIGHT := 8.0
const EDGE_INSET := 1.0

var platform_type: PlatformType = PlatformType.NORMAL

var _base_position: Vector2 = Vector2.ZERO
var _move_phase: float = 0.0
var _is_breaking: bool = false
var _broken: bool = false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Polygon2D = $Visual
@onready var _neon_edge: Polygon2D = $NeonEdge

func _ready() -> void:
	add_to_group("platforms")
	_collision_shape.one_way_collision = true



	_apply_geometry()

func _apply_geometry() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width * width_scale, height)
	_collision_shape.shape = shape

	var hw: float = half_width()
	var hh: float = height * 0.5

	# --------------------------------------------------
	# PLATFORM BODY
	# --------------------------------------------------

	_visual.polygon = PackedVector2Array([
		Vector2(-hw + BEVEL, -hh),
		Vector2(hw - BEVEL, -hh),

		Vector2(hw, -hh + BEVEL),
		Vector2(hw, hh - BEVEL),

		Vector2(hw - BEVEL, hh),
		Vector2(-hw + BEVEL, hh),

		Vector2(-hw, hh - BEVEL),
		Vector2(-hw, -hh + BEVEL)
	])

	_visual.set_instance_shader_parameter(
		"platform_width",
		width * width_scale
	)

	_visual.color = PLATFORM_BODY_COLOR

	# --------------------------------------------------
	# NEON EDGE
	# --------------------------------------------------

	_neon_edge.polygon = PackedVector2Array([
		Vector2(-hw + BEVEL + EDGE_INSET, -hh),
		Vector2(hw - BEVEL - EDGE_INSET, -hh),

		Vector2(hw - EDGE_INSET, -hh + BEVEL),
		Vector2(hw - EDGE_INSET, -hh + EDGE_HEIGHT),

		Vector2(-hw + EDGE_INSET, -hh + EDGE_HEIGHT),
		Vector2(-hw + EDGE_INSET, -hh + BEVEL)
	])

	_neon_edge.color = NEON_COLOR
	_neon_edge.set_instance_shader_parameter(
		"platform_width",
		width * width_scale
	)
	_neon_edge.set_instance_shader_parameter("platform_width", width * width_scale)


func _physics_process(delta: float) -> void:
	_update_landing_target()

	if platform_type == PlatformType.MOVING and not _is_breaking and not _broken:
		_move_phase += move_speed * delta
		position.x = _base_position.x + sin(_move_phase) * move_radius

func half_width() -> float:
	return width * width_scale * 0.5

func spawn_as(
	type: PlatformType,
	new_position: Vector2,
	new_width_scale: float = 1.0
) -> void:
	platform_type = type
	width_scale = new_width_scale

	global_position = new_position
	_base_position = new_position
	_move_phase = randf_range(0.0, TAU)

	_is_breaking = false
	_broken = false

	_neon_edge.set_instance_shader_parameter("activated", 0.0)
	_neon_edge.set_instance_shader_parameter("landing_confirm", 0.0)

	modulate = Color.WHITE

	_collision_shape.disabled = false
	visible = true



	_apply_geometry()

func on_ball_landed(landing_world_x: float) -> float:
	_play_landing_pulse(landing_world_x)
	_neon_edge.set_instance_shader_parameter("activated", 1.0)
	_neon_edge.set_instance_shader_parameter("landing_confirm", 1.0)

	if platform_type == PlatformType.BREAKABLE:
		_start_breaking()
		return 1.0

	if platform_type == PlatformType.SPRING:
		return spring_multiplier

	return 1.0

func _play_landing_pulse(_landing_world_x: float) -> void:
	_neon_edge.set_instance_shader_parameter("landing_confirm", 1.0)

	_visual.set_instance_shader_parameter(
		"landing_pulse",
		0.0
	)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_method(
		func(value: float) -> void:
			_visual.set_instance_shader_parameter(
				"landing_pulse",
				value
			),
		0.0,
		1.0,
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_method(
		func(value: float) -> void:
			_neon_edge.set_instance_shader_parameter(
				"landing_confirm",
				value
			),
		1.0,
		0.0,
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.set_parallel(false)

	tween.tween_method(
		func(value: float) -> void:
			_visual.set_instance_shader_parameter(
				"landing_pulse",
				value
			),
		1.0,
		0.0,
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_callback(
		func() -> void:
			_visual.set_instance_shader_parameter(
				"landing_pulse",
				0.0
			)
			_neon_edge.set_instance_shader_parameter("landing_confirm", 0.0)
	)

func _update_landing_target() -> void:
	var ball := get_tree().get_first_node_in_group("player_ball") as CharacterBody2D
	if ball == null:
		return

	var prediction := _get_best_landing_prediction(ball)
	var charge := 0.0
	var target_ratio := 0.5

	if prediction.is_empty():
		_neon_edge.set_instance_shader_parameter("approach_charge", 0.0)
		_neon_edge.set_instance_shader_parameter("approach_target_x", target_ratio)
		return

	var target: Node2D = prediction["platform"] as Node2D
	if target != self:
		_neon_edge.set_instance_shader_parameter("approach_charge", 0.0)
		_neon_edge.set_instance_shader_parameter("approach_target_x", target_ratio)
		return

	var time_to_land: float = prediction["time_to_land"]
	var predicted_x: float = prediction["predicted_x"]
	var screen_width: float = float(get_viewport_rect().size.x)
	var local_x: float = predicted_x - global_position.x

	if screen_width > 0.0:
		if local_x > screen_width * 0.5:
			local_x -= screen_width
		elif local_x < -screen_width * 0.5:
			local_x += screen_width

	# Keep the real predicted landing point, but constrain only the visual
	# target so the charge can converge cleanly without snapping to center.
	var target_min := _visual_target_margin()
	var target_max := 1.0 - target_min
	target_ratio = clampf(
		(local_x + half_width()) / (width * width_scale),
		target_min,
		target_max
	)

	# Smaller platforms get a longer perceived charge window. The window is
	# still driven entirely by the predicted time-to-land, not by distance.
	var effective_width: float = width * width_scale
	var width_factor: float = clampf(
		inverse_lerp(100.0, 320.0, effective_width),
		0.0,
		1.0
	)
	var charge_window: float = lerpf(1.35, 0.80, width_factor)
	var raw_charge: float = 1.0 - clampf(time_to_land / charge_window, 0.0, 1.0)

	# Continuous milestone-shaped progression:
	# 0 -> 20 -> 50 -> 70 -> 80 -> 95 -> 100.
	# The milestones are only shaping points; there are no discrete stages.
	charge = _shape_approach_charge(raw_charge)

	# Never visually claim a completed connection before the actual landing.
	charge = minf(charge, 0.995)

	_neon_edge.set_instance_shader_parameter("approach_charge", charge)
	_neon_edge.set_instance_shader_parameter("approach_target_x", target_ratio)


func _shape_approach_charge(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)

	if x < 0.20:
		return 0.20 * smoothstep(0.0, 1.0, x / 0.20)
	if x < 0.50:
		return 0.20 + 0.30 * smoothstep(0.0, 1.0, (x - 0.20) / 0.30)
	if x < 0.70:
		return 0.50 + 0.20 * smoothstep(0.0, 1.0, (x - 0.50) / 0.20)
	if x < 0.80:
		return 0.70 + 0.10 * smoothstep(0.0, 1.0, (x - 0.70) / 0.10)
	if x < 0.95:
		return 0.80 + 0.15 * smoothstep(0.0, 1.0, (x - 0.80) / 0.15)
	return 0.95 + 0.05 * smoothstep(0.0, 1.0, (x - 0.95) / 0.05)


func _visual_target_margin() -> float:
	var effective_width: float = width * width_scale
	var width_factor: float = clampf(
		inverse_lerp(100.0, 320.0, effective_width),
		0.0,
		1.0
	)
	# Small platforms preserve almost the full predicted landing range.
	# Wider platforms get a slightly safer interior target.
	return lerpf(0.08, 0.18, width_factor)


func _get_best_landing_prediction(ball: CharacterBody2D) -> Dictionary:
	if ball.velocity.y <= 0.0:
		return {}

	var candidates: Array[Node] = get_tree().get_nodes_in_group("platforms")
	var best: Node2D = null
	var best_dy: float = INF
	var best_time: float = 0.0
	var best_x: float = 0.0
	var g: float = float(ball.gravity)
	var vy: float = float(ball.velocity.y)
	var screen_width: float = float(get_viewport_rect().size.x)

	if g <= 0.0:
		return {}

	for candidate in candidates:
		if not candidate is Node2D:
			continue

		var platform := candidate as Node2D
		if not platform.visible or not platform.has_method("half_width"):
			continue

		var platform_dy: float = platform.global_position.y - ball.global_position.y
		if platform_dy <= 0.0 or platform_dy > 360.0:
			continue

		var discriminant: float = vy * vy + 2.0 * g * platform_dy
		if discriminant < 0.0:
			continue

		var time_to_land: float = (-vy + sqrt(discriminant)) / g
		if time_to_land <= 0.0:
			continue

		var predicted_x: float = ball.global_position.x + ball.velocity.x * time_to_land
		if screen_width > 0.0:
			predicted_x = fmod(predicted_x, screen_width)
			if predicted_x < 0.0:
				predicted_x += screen_width

		var candidate_half_width: float = float(platform.call("half_width"))
		var local_x: float = predicted_x - platform.global_position.x

		if screen_width > 0.0:
			if local_x > screen_width * 0.5:
				local_x -= screen_width
			elif local_x < -screen_width * 0.5:
				local_x += screen_width

		var landing_margin: float = 24.0
		if absf(local_x) <= candidate_half_width + landing_margin:
			if platform_dy < best_dy:
				best_dy = platform_dy
				best = platform
				best_time = time_to_land
				best_x = predicted_x

	if best == null:
		return {}

	return {
		"platform": best,
		"time_to_land": best_time,
		"predicted_x": best_x,
	}


func _find_best_landing_target(ball: CharacterBody2D) -> Node2D:
	var prediction := _get_best_landing_prediction(ball)
	if prediction.is_empty():
		return null
	return prediction["platform"] as Node2D


func _start_breaking() -> void:
	if _is_breaking or _broken:
		return

	_is_breaking = true

	var tween := create_tween()

	tween.tween_property(
		self,
		"modulate",
		breakable_flicker_color,
		breakable_warning_duration
	)

	tween.parallel().tween_method(
		_apply_wobble,
		0.0,
		1.0,
		breakable_warning_duration
	)

	tween.tween_callback(_break)

func _apply_wobble(t: float) -> void:
	position.x = _base_position.x + sin(t * TAU * 6.0) * breakable_wobble_amplitude * (1.0 - t)

func _break() -> void:
	_is_breaking = false
	_broken = true
	position.x = _base_position.x
	_collision_shape.disabled = true
	visible = false
