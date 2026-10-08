class_name LandingFeedbackController
extends Node
## Central coordinator for TowerJump landing feedback.
##
## Responsibilities:
## - Observe the ball's current physics state.
## - Predict the next physically valid platform using the proven deterministic
##   landing model.
## - Maintain stable target selection/hysteresis.
## - Drive each platform's LandingApproachState without owning platform behavior.
## - Emit a LandingEvent when physical contact actually occurs.
##
## Future reactions (ball, geometric particles, score/combo, labels, camera,
## audio) should listen to these signals rather than being added to platform.gd.

signal landing_target_changed(previous_target: Node2D, new_target: Node2D)
signal landing_approach_updated(
	platform: Node2D,
	progress: float,
	target_x: float,
	time_to_land: float,
	edge_factor: float
)
signal landing_confirmed(event: LandingEvent)

const LANDING_FEEDBACK_TARGET_META := "_towerjump_landing_feedback_target"

const TARGET_SWITCH_DY_MARGIN := 36.0
const TARGET_LOSS_GRACE_TIME := 0.09

const LandingPredictionFilterScript := preload(
	"res://scripts/landing/landing_prediction_filter.gd"
)

# Visual timing behavior preserved from the current tested prototype.
const APPROACH_TIME_BUFFER_MAX := 0.14
const MAX_CATCHUP_MULTIPLIER := 2.25

@export var ball_path: NodePath
@export var platforms_group: StringName = &"platforms"

var _ball: CharacterBody2D = null
var _approach_target: Node2D = null
var _retracting_targets: Array[Node2D] = []

var _prediction_filter: LandingPredictionFilterScript = LandingPredictionFilterScript.new()
var _last_valid_prediction: Dictionary = {}
var _last_valid_prediction_at_msec: int = 0

func _ready() -> void:
	_ball = get_node_or_null(ball_path) as CharacterBody2D
	call_deferred("_connect_platforms")

func _connect_platforms() -> void:
	for node in get_tree().get_nodes_in_group(platforms_group):
		_connect_platform(node as Node)

func _connect_platform(node: Node) -> void:
	if node == null or not node.has_signal("landing_occurred"):
		return

	# Platforms are pooled and their signal connection persists for their
	# lifetime, so each platform is connected once after the pool is created.
	node.connect(
		"landing_occurred",
		Callable(self, "_on_platform_landed").bind(node)
	)

func _physics_process(delta: float) -> void:
	if _ball == null or not is_instance_valid(_ball):
		_ball = get_node_or_null(ball_path) as CharacterBody2D
		if _ball == null:
			_prediction_filter.reset()
			return

	_update_landing_target(delta)
	_update_retracting_targets(delta)

func _update_landing_target(delta: float) -> void:
	var prediction := _get_stable_landing_prediction()
	var predicted_target: Node2D = null

	if not prediction.is_empty():
		predicted_target = prediction["platform"] as Node2D

	var previous_target := _approach_target

	if predicted_target != previous_target:
		_approach_target = predicted_target
		_prediction_filter.reset()
		_last_valid_prediction = {}
		_last_valid_prediction_at_msec = 0

		if (
			previous_target != null
			and is_instance_valid(previous_target)
			and previous_target != predicted_target
		):
			if not _retracting_targets.has(previous_target):
				_retracting_targets.append(previous_target)

		landing_target_changed.emit(
			previous_target,
			_approach_target
		)

	if _approach_target == null or not is_instance_valid(_approach_target):
		return

	var time_to_land := float(prediction.get("time_to_land", INF))
	var predicted_x := float(prediction.get("predicted_x", _approach_target.global_position.x))
	var edge_factor := float(prediction.get("edge_factor", 0.0))

	var filtered_x := _prediction_filter.update(
		predicted_x,
		_approach_target.global_position.x,
		float(get_viewport().get_visible_rect().size.x),
		float(_approach_target.get("width")) * float(_approach_target.get("width_scale")),
		delta
	)

	prediction["raw_predicted_x"] = predicted_x
	prediction["predicted_x"] = filtered_x

	_approach_target.set_landing_approach_feedback(
		time_to_land,
		filtered_x,
		edge_factor,
		delta
	)

	landing_approach_updated.emit(
		_approach_target,
		_approach_target.get_landing_approach_progress(),
		_approach_target.get_landing_approach_target_x(),
		time_to_land,
		edge_factor
	)

func _update_retracting_targets(delta: float) -> void:
	for i in range(_retracting_targets.size() - 1, -1, -1):
		var platform := _retracting_targets[i]

		if (
			platform == null
			or not is_instance_valid(platform)
			or platform == _approach_target
		):
			_retracting_targets.remove_at(i)
			continue

		platform.retract_landing_approach_feedback(delta)

		if platform.is_landing_approach_feedback_empty():
			_retracting_targets.remove_at(i)

func _get_stable_landing_prediction() -> Dictionary:
	var best_prediction := _get_best_landing_prediction()
	var stable_target: Node2D = null

	if _ball.has_meta(LANDING_FEEDBACK_TARGET_META):
		stable_target = _ball.get_meta(
			LANDING_FEEDBACK_TARGET_META
		) as Node2D

	if stable_target != null and not is_instance_valid(stable_target):
		stable_target = null

	if stable_target != null and stable_target.visible:
		var current_prediction := _get_platform_prediction(
			_ball,
			stable_target
		)

		if not current_prediction.is_empty():
			_last_valid_prediction = current_prediction.duplicate()
			_last_valid_prediction_at_msec = Time.get_ticks_msec()

			if best_prediction.is_empty():
				return current_prediction

			var best_target := best_prediction["platform"] as Node2D
			if best_target == stable_target:
				return current_prediction

			var current_dy: float = (
				stable_target.global_position.y - _ball.global_position.y
			)
			var best_dy: float = (
				best_target.global_position.y - _ball.global_position.y
			)

			# Keep the existing target unless another platform is clearly better.
			# This is the existing target hysteresis from the stable prototype.
			if best_dy >= current_dy - TARGET_SWITCH_DY_MARGIN:
				return current_prediction

		# A real competing platform can still take over normally once it is
		# clearly better; no additional delay is imposed here.
		return best_prediction

	# The target's precise prediction can briefly disappear during rapid steering.
	# Trust the last valid target for only a few frames rather than immediately
	# tearing down the visual sequence. This protects the timeline without
	# freezing it or inventing a broader landing zone.
	if (
		stable_target != null
		and stable_target.visible
		and not _last_valid_prediction.is_empty()
		and _last_valid_prediction.get("platform") == stable_target
	):
		var elapsed: float = (
			Time.get_ticks_msec() - _last_valid_prediction_at_msec
		) / 1000.0

		if elapsed <= TARGET_LOSS_GRACE_TIME:
			var held_prediction: Dictionary = _last_valid_prediction.duplicate()
			var old_time_to_land := float(
				held_prediction.get("time_to_land", 0.0)
			)
			held_prediction["platform"] = stable_target
			held_prediction["time_to_land"] = maxf(
				old_time_to_land - elapsed,
				0.02
			)
			held_prediction["grace_hold"] = true
			return held_prediction

	_last_valid_prediction = {}
	_last_valid_prediction_at_msec = 0

	if not best_prediction.is_empty():
		_ball.set_meta(
			LANDING_FEEDBACK_TARGET_META,
			best_prediction["platform"]
		)
	else:
		_ball.set_meta(LANDING_FEEDBACK_TARGET_META, null)

	return best_prediction
func _get_platform_prediction(
	ball: CharacterBody2D,
	platform: Node2D
) -> Dictionary:
	var g: float = float(ball.gravity)
	var vy: float = float(ball.velocity.y)
	var platform_dy: float = (
		platform.global_position.y - ball.global_position.y
	)
	var screen_width: float = float(get_viewport().get_visible_rect().size.x)

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

	# Predict horizontal movement using the same control model as ball.gd:
	# acceleration while a direction is held, deceleration when released.
	# This fixes the main edge/long-steering blind spot of constant-velocity
	# extrapolation without creating a broad reachability envelope.
	var predicted_displacement := _predict_horizontal_displacement(
		ball,
		time_to_land
	)
	var predicted_x_unwrapped: float = (
		ball.global_position.x + predicted_displacement
	)
	var predicted_x: float = _wrap_x(
		predicted_x_unwrapped,
		screen_width
	)

	var platform_half_width: float = float(platform.call("half_width"))

	# Use the ball radius as the physically grounded contact allowance.
	var landing_margin: float = float(ball.radius)
	var accepted_half_width: float = (
		platform_half_width + landing_margin
	)

	var local_x: float = _shortest_local_x(
		predicted_x,
		platform.global_position.x,
		screen_width
	)

	if absf(local_x) > accepted_half_width:
		return {}

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
		"predicted_x": predicted_x,
		"local_x": local_x,
		"edge_factor": edge_factor,
	}

func _predict_horizontal_displacement(
	ball: CharacterBody2D,
	duration: float
) -> float:
	if duration <= 0.0:
		return 0.0

	var initial_velocity: float = float(ball.velocity.x)
	var steering_input: float = clampf(
		float(ball.input_direction),
		-1.0,
		1.0
	)
	var max_speed: float = float(ball.max_horizontal_speed)

	if max_speed <= 0.0:
		return initial_velocity * duration

	var target_speed: float
	var acceleration_rate: float

	if absf(steering_input) > 0.01:
		target_speed = steering_input * max_speed
		acceleration_rate = float(ball.horizontal_acceleration)
	else:
		target_speed = 0.0
		acceleration_rate = float(ball.horizontal_deceleration)

	if acceleration_rate <= 0.0:
		return target_speed * duration

	var delta_v := target_speed - initial_velocity
	if absf(delta_v) <= 0.0001:
		return target_speed * duration

	var time_to_target := absf(delta_v) / acceleration_rate

	if time_to_target >= duration:
		return (
			initial_velocity * duration
			+ 0.5 * signf(delta_v)
			* acceleration_rate
			* duration
			* duration
		)

	var first_phase := (
		initial_velocity * time_to_target
		+ 0.5 * signf(delta_v)
		* acceleration_rate
		* time_to_target
		* time_to_target
	)

	return first_phase + target_speed * (
		duration - time_to_target
	)

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

func _get_best_landing_prediction() -> Dictionary:
	var ball := _ball
	var candidates: Array[Node] = get_tree().get_nodes_in_group(
		platforms_group
	)

	var best: Node2D = null
	var best_dy: float = INF
	var best_time: float = INF

	if ball == null or not is_instance_valid(ball):
		return {}

	for candidate in candidates:
		if not candidate is Node2D:
			continue

		var platform := candidate as Node2D
		if (
			not platform.visible
			or not platform.has_method("half_width")
		):
			continue

		var prediction := _get_platform_prediction(
			ball,
			platform
		)
		if prediction.is_empty():
			continue

		var platform_dy: float = (
			platform.global_position.y - ball.global_position.y
		)
		var time_to_land: float = prediction["time_to_land"]

		# Prefer the nearest physically reachable platform above the ball.
		# Time is only a tie-breaker, keeping target selection stable.
		if (
			platform_dy < best_dy - 0.5
			or (
				absf(platform_dy - best_dy) <= 0.5
				and time_to_land < best_time
			)
		):
			best_dy = platform_dy
			best_time = time_to_land
			best = platform

	if best == null:
		return {}

	return _get_platform_prediction(
		ball,
		best
	)

func _on_platform_landed(
	landing_world_x: float,
	platform: Node2D
) -> void:
	if _ball == null or not is_instance_valid(platform):
		return

	var platform_half_width: float = float(
		platform.call("half_width")
	)

	var local_x: float = (
		landing_world_x - platform.global_position.x
	)
	var landing_ratio := 0.5

	if platform_half_width > 0.0:
		landing_ratio = clampf(
			(local_x + platform_half_width)
			/ (platform_half_width * 2.0),
			0.0,
			1.0
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

	var approach_progress: float = 0.0
	if platform.has_method("get_landing_approach_progress"):
		approach_progress = platform.get_landing_approach_progress()

	var event := LandingEvent.new(
		_ball,
		platform,
		landing_world_x,
		landing_ratio,
		edge_factor,
		float(_ball.velocity.x),
		float(_ball.velocity.y),
		approach_progress,
		int(platform.get("platform_type"))
	)

	# The actual landing is authoritative. Complete this platform's approach
	# state now, even if prediction was a fraction late or targeted elsewhere.
	if _approach_target != platform:
		if (
			_approach_target != null
			and is_instance_valid(_approach_target)
			and not _retracting_targets.has(_approach_target)
		):
			_retracting_targets.append(_approach_target)

		_approach_target = platform

		for i in range(_retracting_targets.size() - 1, -1, -1):
			if _retracting_targets[i] == platform:
				_retracting_targets.remove_at(i)

	_ball.set_meta(
		LANDING_FEEDBACK_TARGET_META,
		platform
	)

	platform.complete_landing_approach_feedback()

	landing_confirmed.emit(event)
