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

# Visual target acquisition state. This is deliberately separate from
# physical landing prediction so the neon sequence can begin during ascent.
var _approach_target: Node2D = null
var _approach_elapsed: float = 0.0
var _approach_target_x: float = 0.5

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
	_update_landing_target(delta)

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
	_approach_target = null
	_approach_elapsed = 0.0
	_approach_target_x = 0.5

	_neon_edge.set_instance_shader_parameter("activated", 0.0)
	_neon_edge.set_instance_shader_parameter("landing_confirm", 0.0)

	modulate = Color.WHITE

	_collision_shape.disabled = false
	visible = true



	_apply_geometry()

func on_ball_landed(landing_world_x: float) -> float:
	_play_landing_pulse(landing_world_x)
	_neon_edge.set_instance_shader_parameter("approach_charge", 1.0)
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

func _update_landing_target(delta: float) -> void:
	var ball := get_tree().get_first_node_in_group("player_ball") as CharacterBody2D
	if ball == null:
		_reset_approach_state()
		return

	var prediction := _get_best_landing_prediction(ball)
	var predicted_target: Node2D = null
	if not prediction.is_empty():
		predicted_target = prediction["platform"] as Node2D

	_update_approach_target(predicted_target, prediction, delta)

	if _approach_target != self:
		_neon_edge.set_instance_shader_parameter("approach_charge", 0.0)
		_neon_edge.set_instance_shader_parameter("approach_target_x", 0.5)
		return

	var predicted_x: float = _approach_target_x_world(ball)
	var local_x: float = predicted_x - global_position.x
	var screen_width: float = float(get_viewport_rect().size.x)

	if screen_width > 0.0:
		if local_x > screen_width * 0.5:
			local_x -= screen_width
		elif local_x < -screen_width * 0.5:
			local_x += screen_width

	_approach_target_x = clampf(
		(local_x + half_width()) / (width * width_scale),
		_visual_target_margin(),
		1.0 - _visual_target_margin()
	)

	_neon_edge.set_instance_shader_parameter("approach_charge", _approach_charge())
	_neon_edge.set_instance_shader_parameter("approach_target_x", _approach_target_x)


func _update_approach_target(predicted_target: Node2D, prediction: Dictionary, delta: float) -> void:
	if predicted_target == null:
		_reset_approach_state()
		return

	if predicted_target != _approach_target:
		_approach_target = predicted_target
		_approach_elapsed = 0.0

	# The sequence starts from target acquisition, but its playback speed
	# adapts to landing urgency. Early targets get a calm readable build;
	# late/close landings accelerate the remaining anticipation so the visual
	# sequence can catch up without turning time-to-land into the progress bar.
	var time_to_land: float = INF
	if not prediction.is_empty():
		time_to_land = float(prediction.get("time_to_land", INF))
	_approach_elapsed += delta * _approach_speed_multiplier(time_to_land)


func _reset_approach_state() -> void:
	_approach_target = null
	_approach_elapsed = 0.0
	_approach_target_x = 0.5


func _approach_charge() -> float:
	var effective_width: float = width * width_scale
	var width_factor: float = clampf(
		inverse_lerp(100.0, 320.0, effective_width),
		0.0,
		1.0
	)

	# Smaller platforms receive a slightly longer, more readable anticipation.
	# This is the base playback length; landing urgency can accelerate it.
	var sequence_duration: float = lerpf(1.35, 0.90, width_factor)
	var raw_progress := clampf(_approach_elapsed / sequence_duration, 0.0, 1.0)

	# 95% is the airborne ceiling. The final 5% is reserved for the actual
	# landing so the platform never appears fully connected before contact.
	var visual_progress := minf(raw_progress, 0.95)

	# Continuous visual milestones. These are shaping points, not discrete
	# states: 0 -> 20 -> 50 -> 70 -> 80 -> 95 -> HOLD.
	if visual_progress < 0.20:
		return 0.20 * smoothstep(0.0, 1.0, visual_progress / 0.20)
	if visual_progress < 0.50:
		return 0.20 + 0.30 * smoothstep(0.0, 1.0, (visual_progress - 0.20) / 0.30)
	if visual_progress < 0.70:
		return 0.50 + 0.20 * smoothstep(0.0, 1.0, (visual_progress - 0.50) / 0.20)
	if visual_progress < 0.80:
		return 0.70 + 0.10 * smoothstep(0.0, 1.0, (visual_progress - 0.70) / 0.10)
	if visual_progress < 0.95:
		return 0.80 + 0.15 * smoothstep(0.0, 1.0, (visual_progress - 0.80) / 0.15)
	return 0.95


func _approach_speed_multiplier(time_to_land: float) -> float:
	if not is_finite(time_to_land) or time_to_land >= 0.90:
		return 1.0

	# Keep the early sequence calm, then progressively compress the remaining
	# anticipation as contact gets close. The multiplier is intentionally
	# strongest near landing so a late target can still reach the 95% hold.
	var urgency := 1.0 - smoothstep(0.15, 0.90, time_to_land)
	return lerpf(1.0, 6.0, urgency)


func _approach_target_x_world(ball: CharacterBody2D) -> float:
	var prediction := _get_platform_prediction(ball, self)
	if prediction.is_empty():
		return global_position.x

	return prediction["predicted_x"]


func _visual_target_margin() -> float:
	var effective_width: float = width * width_scale
	var width_factor: float = clampf(
		inverse_lerp(100.0, 320.0, effective_width),
		0.0,
		1.0
	)
	return lerpf(0.08, 0.18, width_factor)


func _get_platform_prediction(ball: CharacterBody2D, platform: Node2D) -> Dictionary:
	var g: float = float(ball.gravity)
	var vy: float = float(ball.velocity.y)
	var platform_dy: float = platform.global_position.y - ball.global_position.y
	var screen_width: float = float(get_viewport_rect().size.x)

	if g <= 0.0 or platform_dy <= 0.0:
		return {}

	# Solve the ballistic crossing time regardless of whether the ball is
	# currently rising or falling. During ascent this finds the FUTURE
	# descending crossing of the platform height.
	var discriminant: float = vy * vy + 2.0 * g * platform_dy
	if discriminant < 0.0:
		return {}

	var time_to_land: float = (-vy + sqrt(discriminant)) / g
	if time_to_land <= 0.0:
		return {}

	var predicted_x: float = ball.global_position.x + ball.velocity.x * time_to_land
	if screen_width > 0.0:
		predicted_x = fmod(predicted_x, screen_width)
		if predicted_x < 0.0:
			predicted_x += screen_width

	var local_x: float = predicted_x - platform.global_position.x
	if screen_width > 0.0:
		if local_x > screen_width * 0.5:
			local_x -= screen_width
		elif local_x < -screen_width * 0.5:
			local_x += screen_width

	var platform_half_width: float = float(platform.call("half_width"))
	var landing_margin: float = 24.0

	if absf(local_x) > platform_half_width + landing_margin:
		return {}

	return {
		"platform": platform,
		"time_to_land": time_to_land,
		"predicted_x": predicted_x,
		"local_x": local_x,
	}


func _get_best_landing_prediction(ball: CharacterBody2D) -> Dictionary:
	var candidates: Array[Node] = get_tree().get_nodes_in_group("platforms")
	var best: Node2D = null
	var best_dy: float = INF
	var best_time: float = INF
	var g: float = float(ball.gravity)

	if g <= 0.0:
		return {}

	for candidate in candidates:
		if not candidate is Node2D:
			continue

		var platform := candidate as Node2D
		if not platform.visible or not platform.has_method("half_width"):
			continue

		var prediction := _get_platform_prediction(ball, platform)
		if prediction.is_empty():
			continue

		var platform_dy: float = platform.global_position.y - ball.global_position.y
		var time_to_land: float = prediction["time_to_land"]

		# Prefer the nearest physically reachable platform above the ball.
		# Time is only a tie-breaker, keeping target selection stable.
		if platform_dy < best_dy - 0.5 or (
			absf(platform_dy - best_dy) <= 0.5 and time_to_land < best_time
		):
			best_dy = platform_dy
			best_time = time_to_land
			best = platform

	if best == null:
		return {}

	var best_prediction := _get_platform_prediction(ball, best)
	if best_prediction.is_empty():
		return {}

	return best_prediction


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
