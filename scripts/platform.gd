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

# Visual target state shared between pooled platform instances through the ball.
# This keeps tiny prediction changes from making different platforms fight over
# the same neon sequence.
const LANDING_FEEDBACK_TARGET_META := "_towerjump_landing_feedback_target"
const TARGET_SWITCH_DY_MARGIN := 36.0
const RETRACT_RATE_MULTIPLIER := 0.90

# Small, directional prediction assist for aggressive horizontal steering.
# This is deliberately capped and only activates while the ball is already
# moving toward the candidate platform, so idle jumps keep the old precise
# single-point behavior.
const STEERING_ASSIST_MIN_SPEED := 120.0
const STEERING_ASSIST_MAX_DISPLACEMENT := 140.0
const STEERING_ASSIST_BLEND_MAX := 0.65
const APPROACH_TARGET_SMOOTH_RATE := 16.0

# Give the timeline a small visual buffer near contact so the required rate
# does not explode during the last few frames and produce a visible snap.
const APPROACH_TIME_BUFFER_MAX := 0.14
const MAX_CATCHUP_MULTIPLIER := 2.25

var platform_type: PlatformType = PlatformType.NORMAL

var _base_position: Vector2 = Vector2.ZERO
var _move_phase: float = 0.0
var _is_breaking: bool = false
var _broken: bool = false

# Visual target acquisition state. This is deliberately separate from
# physical landing prediction so the neon sequence can begin during ascent.
var _approach_target: Node2D = null
var _approach_progress: float = 0.0
var _approach_speed_rate: float = 0.0
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
	_approach_progress = 0.0
	_approach_speed_rate = 0.0
	_approach_target_x = 0.5

	_neon_edge.set_instance_shader_parameter("approach_charge", 0.0)
	_neon_edge.set_instance_shader_parameter("approach_target_x", 0.5)
	_neon_edge.set_instance_shader_parameter("activated", 0.0)
	_neon_edge.set_instance_shader_parameter("landing_confirm", 0.0)

	modulate = Color.WHITE

	_collision_shape.disabled = false
	visible = true

	_apply_geometry()

func on_ball_landed(landing_world_x: float) -> float:
	_play_landing_pulse(landing_world_x)
	_approach_progress = 1.0
	_approach_speed_rate = 0.0
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

	var prediction := _get_stable_landing_prediction(ball)
	var predicted_target: Node2D = null
	if not prediction.is_empty():
		predicted_target = prediction["platform"] as Node2D

	_update_approach_target(predicted_target, prediction, delta)

	if _approach_target != self:
		# The old target is allowed to visually retract in _update_approach_target().
		# Only clear the shader once the reversible timeline has returned to zero.
		if _approach_progress <= 0.0001:
			_neon_edge.set_instance_shader_parameter("approach_charge", 0.0)
			_neon_edge.set_instance_shader_parameter("approach_target_x", 0.5)
		else:
			_neon_edge.set_instance_shader_parameter(
				"approach_charge",
				_approach_charge()
			)
			_neon_edge.set_instance_shader_parameter(
				"approach_target_x",
				_approach_target_x
			)
		return

	if predicted_target == self and not prediction.is_empty():
		_set_approach_target_x(
			float(prediction.get("predicted_x", 0.0)),
			float(prediction.get("edge_factor", 0.0)),
			delta
		)

	_neon_edge.set_instance_shader_parameter(
		"approach_charge",
		_approach_charge()
	)
	_neon_edge.set_instance_shader_parameter(
		"approach_target_x",
		_approach_target_x
	)

func _update_approach_target(
	predicted_target: Node2D,
	prediction: Dictionary,
	delta: float
) -> void:
	if predicted_target == self:
		# Re-acquiring the same platform never resets the timeline. This is the
		# key difference from the old restart-on-target-loss behavior.
		if _approach_target != self:
			_approach_target = self
			_approach_speed_rate = 0.0

		var time_to_land: float = INF
		if not prediction.is_empty():
			time_to_land = float(prediction.get("time_to_land", INF))

		_update_approach_progress(delta, time_to_land, true)
		return

	# If we were the previous target but the predicted landing has moved away,
	# smoothly run the same timeline backwards. Small timing shifts do not get
	# here unless the platform actually falls out of the stable target.
	if _approach_target == self:
		_update_approach_progress(delta, 0.0, false)

		if _approach_progress <= 0.0001:
			_approach_progress = 0.0
			_approach_speed_rate = 0.0
			_approach_target = null

func _reset_approach_state() -> void:
	_approach_target = null
	_approach_progress = 0.0
	_approach_speed_rate = 0.0
	_approach_target_x = 0.5

func _update_approach_progress(
	delta: float,
	time_to_land: float,
	target_confirmed: bool
) -> void:
	var effective_width: float = width * width_scale
	var width_factor: float = clampf(
		inverse_lerp(100.0, 320.0, effective_width),
		0.0,
		1.0
	)

	# Width controls the preferred visual tempo, but the actual landing
	# deadline still determines the forward playback rate.
	var preferred_duration: float = lerpf(1.35, 0.90, width_factor)
	var preferred_rate: float = 1.0 / preferred_duration

	if not target_confirmed:
		# Retraction is deliberately calmer than forward charging. It is a
		# visual "backing away", not a hard reset.
		var retract_rate: float = preferred_rate * RETRACT_RATE_MULTIPLIER
		var retract_response: float = preferred_rate * 8.0

		_approach_speed_rate = move_toward(
			_approach_speed_rate,
			-retract_rate,
			retract_response * delta
		)
		_approach_progress = maxf(
			_approach_progress + _approach_speed_rate * delta,
			0.0
		)
		return

	if not is_finite(time_to_land) or time_to_land <= 0.0:
		return

	var remaining_progress: float = maxf(1.0 - _approach_progress, 0.0)
	var time_buffer: float = lerpf(
		0.04,
		APPROACH_TIME_BUFFER_MAX,
		1.0 - width_factor
	)
	var remaining_time: float = maxf(time_to_land + time_buffer, 0.08)
	var required_rate: float = remaining_progress / remaining_time

	# Catch-up is deliberately capped. The extra timing buffer prevents the
	# last few frames from turning a smooth approach into a visible 60 -> 100
	# acceleration burst. Actual landing still sets the final 100%.
	var max_catchup_rate: float = preferred_rate * MAX_CATCHUP_MULTIPLIER
	var desired_rate: float = minf(required_rate, max_catchup_rate)

	# Timing changes only alter the positive playback speed. They never create
	# negative progress, so a small time-to-land shift cannot visually rewind
	# a still-valid target.
	var rate_response: float = preferred_rate * 8.0
	_approach_speed_rate = move_toward(
		_approach_speed_rate,
		desired_rate,
		rate_response * delta
	)

	_approach_progress = minf(
		_approach_progress + _approach_speed_rate * delta,
		0.999
	)

func _approach_charge() -> float:
	# Continuous visual milestones. These are shaping points, not discrete
	# states. The underlying progress remains a single smooth 0..1 timeline.
	var progress: float = clampf(_approach_progress, 0.0, 1.0)

	if progress < 0.20:
		return 0.20 * smoothstep(0.0, 1.0, progress / 0.20)
	if progress < 0.50:
		return 0.20 + 0.30 * smoothstep(0.0, 1.0, (progress - 0.20) / 0.30)
	if progress < 0.70:
		return 0.50 + 0.20 * smoothstep(0.0, 1.0, (progress - 0.50) / 0.20)
	if progress < 0.80:
		return 0.70 + 0.10 * smoothstep(0.0, 1.0, (progress - 0.70) / 0.10)
	return 0.80 + 0.20 * smoothstep(0.0, 1.0, (progress - 0.80) / 0.20)

func _set_approach_target_x(
	predicted_x: float,
	edge_factor: float,
	delta: float
) -> void:
	var local_x: float = predicted_x - global_position.x
	var screen_width: float = float(get_viewport_rect().size.x)

	if screen_width > 0.0:
		if local_x > screen_width * 0.5:
			local_x -= screen_width
		elif local_x < -screen_width * 0.5:
			local_x += screen_width

	var base_margin := _visual_target_margin()
	# Only predictions that are already valid landing candidates reach this
	# point. Near a real edge, reduce the visual clamp so an edge landing does
	# not get forced toward the platform interior.
	var visual_margin := lerpf(
		base_margin,
		0.04,
		clampf(edge_factor, 0.0, 1.0)
	)

	var desired_target_x := clampf(
		(local_x + half_width()) / (width * width_scale),
		visual_margin,
		1.0 - visual_margin
	)

	# Smooth target motion by a few physics frames. This removes the little
	# target-point hop that can happen when aggressive steering changes the
	# predicted landing position, without changing which platform is targeted.
	_approach_target_x = move_toward(
		_approach_target_x,
		desired_target_x,
		APPROACH_TARGET_SMOOTH_RATE * delta
	)

func _visual_target_margin() -> float:
	var effective_width: float = width * width_scale
	var width_factor: float = clampf(
		inverse_lerp(100.0, 320.0, effective_width),
		0.0,
		1.0
	)
	return lerpf(0.08, 0.18, width_factor)

func _get_stable_landing_prediction(ball: CharacterBody2D) -> Dictionary:
	var best_prediction := _get_best_landing_prediction(ball)
	var stable_target := ball.get_meta(
		LANDING_FEEDBACK_TARGET_META,
		null
	) as Node2D

	if stable_target != null and not is_instance_valid(stable_target):
		stable_target = null

	if stable_target != null and stable_target.visible:
		var current_prediction := _get_platform_prediction(
			ball,
			stable_target
		)

		if not current_prediction.is_empty():
			if best_prediction.is_empty():
				return current_prediction

			var best_target := best_prediction["platform"] as Node2D
			if best_target == stable_target:
				return current_prediction

			var current_dy: float = stable_target.global_position.y - ball.global_position.y
			var best_dy: float = best_target.global_position.y - ball.global_position.y

			# Keep the existing target unless another platform is clearly
			# better. This hysteresis stops tiny prediction changes from
			# swapping the neon target and restarting the visual story.
			if best_dy >= current_dy - TARGET_SWITCH_DY_MARGIN:
				return current_prediction

	if not best_prediction.is_empty():
		ball.set_meta(
			LANDING_FEEDBACK_TARGET_META,
			best_prediction["platform"]
		)
	else:
		ball.set_meta(LANDING_FEEDBACK_TARGET_META, null)

	return best_prediction

func _get_platform_prediction(
	ball: CharacterBody2D,
	platform: Node2D
) -> Dictionary:
	var g: float = float(ball.gravity)
	var vy: float = float(ball.velocity.y)
	var platform_dy: float = platform.global_position.y - ball.global_position.y
	var screen_width: float = float(get_viewport_rect().size.x)

	if g <= 0.0 or platform_dy <= 0.0:
		return {}

	# Keep the proven ballistic crossing-time calculation as the primary
	# prediction. It remains the gate for normal/idle jumps.
	var discriminant: float = vy * vy + 2.0 * g * platform_dy
	if discriminant < 0.0:
		return {}

	var time_to_land: float = (-vy + sqrt(discriminant)) / g
	if time_to_land <= 0.0:
		return {}

	var predicted_x_unwrapped: float = (
		ball.global_position.x
		+ ball.velocity.x * time_to_land
	)
	var predicted_x: float = _wrap_x(predicted_x_unwrapped, screen_width)

	var platform_half_width: float = float(platform.call("half_width"))
	var landing_margin: float = 24.0
	var accepted_half_width: float = platform_half_width + landing_margin

	var local_x: float = _shortest_local_x(
		predicted_x,
		platform.global_position.x,
		screen_width
	)

	var guidance_x_unwrapped := predicted_x_unwrapped

	# Primary gate: preserve the precise old behavior whenever the current
	# ballistic prediction already lands on the platform.
	if absf(local_x) > accepted_half_width:
		# Secondary assist: only when the ball is already moving toward this
		# platform with meaningful horizontal velocity. This compensates for
		# acceleration during long left->right steering without creating the
		# general "reachable platform" behavior that caused false activations.
		var current_to_platform := _shortest_local_x(
			ball.global_position.x,
			platform.global_position.x,
			screen_width
		)
		var target_direction := signf(current_to_platform)

		if (
			target_direction == 0.0
			or absf(ball.velocity.x) < STEERING_ASSIST_MIN_SPEED
			or signf(ball.velocity.x) != target_direction
		):
			return {}

		var assisted_displacement := _steering_assisted_displacement(
			float(ball.velocity.x),
			time_to_land,
			target_direction,
			float(ball.max_horizontal_speed),
			float(ball.horizontal_acceleration)
		)
		var assisted_x_unwrapped := ball.global_position.x + assisted_displacement

		# Cap how far the assist may move the proven ballistic prediction.
		guidance_x_unwrapped = move_toward(
			predicted_x_unwrapped,
			assisted_x_unwrapped,
			STEERING_ASSIST_MAX_DISPLACEMENT
		)

		var steering_factor := clampf(
			absf(ball.velocity.x) / maxf(
			float(ball.max_horizontal_speed),
			STEERING_ASSIST_MIN_SPEED
			),
			0.25,
			STEERING_ASSIST_BLEND_MAX
		)
		guidance_x_unwrapped = lerpf(
			predicted_x_unwrapped,
			guidance_x_unwrapped,
			steering_factor
		)

		var guidance_x := _wrap_x(guidance_x_unwrapped, screen_width)
		local_x = _shortest_local_x(
			guidance_x,
			platform.global_position.x,
			screen_width
		)

		if absf(local_x) > accepted_half_width:
			return {}
	else:
		guidance_x_unwrapped = predicted_x_unwrapped

	var guidance_x := _wrap_x(guidance_x_unwrapped, screen_width)
	local_x = _shortest_local_x(
		guidance_x,
		platform.global_position.x,
		screen_width
	)

	var edge_factor := 0.0
	if platform_half_width > 0.0:
		edge_factor = clampf(
			inverse_lerp(
				platform_half_width * 0.20,
				platform_half_width,
				absf(local_x)
			),
			0.0,
			1.0
		)

	return {
		"platform": platform,
		"time_to_land": time_to_land,
		"predicted_x": guidance_x,
		"local_x": local_x,
		"edge_factor": edge_factor,
	}

func _steering_assisted_displacement(
	initial_velocity: float,
	duration: float,
	direction: float,
	max_speed: float,
	acceleration: float
) -> float:
	if duration <= 0.0:
		return 0.0

	if acceleration <= 0.0 or max_speed <= 0.0:
		return initial_velocity * duration

	var target_speed := direction * max_speed
	var delta_v := target_speed - initial_velocity
	var reach_time := absf(delta_v) / acceleration

	if reach_time >= duration:
		return (
			initial_velocity * duration
			+ 0.5 * signf(delta_v) * acceleration * duration * duration
		)

	var accelerated_displacement := (
		initial_velocity * reach_time
		+ 0.5 * signf(delta_v) * acceleration * reach_time * reach_time
	)
	return accelerated_displacement + target_speed * (duration - reach_time)

func _wrap_x(x: float, screen_width: float) -> float:
	if screen_width <= 0.0:
		return x

	var wrapped := fmod(x, screen_width)
	if wrapped < 0.0:
		wrapped += screen_width
	return wrapped

func _shortest_local_x(
	world_x: float,
	platform_x: float,
	screen_width: float
) -> float:
	var local_x := world_x - platform_x
	if screen_width > 0.0:
		if local_x > screen_width * 0.5:
			local_x -= screen_width
		elif local_x < -screen_width * 0.5:
			local_x += screen_width
	return local_x

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
