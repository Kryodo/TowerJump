extends Camera2D
## Folgt dem Ziel (Ball) ausschließlich nach oben. Fällt der Ball wieder
## nach unten, bleibt die Kamera stehen (typisch für Doodle-Jump-artige Spiele).

@export var target_path: NodePath
@export var follow_lerp_weight: float = 6.0 ## Höher = die Kamera "klebt" enger am Ball

@onready var _target: Node2D = get_node(target_path)

@export_category("Landing Camera Response")
@export var landing_feedback_controller_path: NodePath = NodePath("../LandingFeedbackController")
@export var landing_score_controller_path: NodePath = NodePath("../LandingScoreController")
@export_range(0.0, 240.0, 5.0) var landing_response_impulse: float = 110.0
@export_range(14.0, 36.0, 1.0) var landing_response_frequency: float = 17.0
@export_range(0.35, 0.90, 0.01) var landing_response_damping_ratio: float = 0.56
@export_range(0.0, 8.0, 0.5) var landing_response_max_offset: float = 5.0
@export_range(0.0, 320.0, 10.0) var landing_response_max_velocity: float = 180.0

@export_category("Landing Quality Scaling")
@export_range(0.80, 1.30, 0.01) var good_landing_impulse_multiplier: float = 1.00
@export_range(0.80, 1.30, 0.01) var epic_landing_impulse_multiplier: float = 1.08
@export_range(0.80, 1.30, 0.01) var perfect_landing_impulse_multiplier: float = 1.16

@export_category("Milestone Camera Response")
@export_range(0.0, 0.30, 0.01) var combo_activation_impulse_bonus: float = 0.08
@export_range(0.0, 0.40, 0.01) var streak_activation_impulse_bonus: float = 0.18
@export_range(1.0, 1.50, 0.01) var milestone_impulse_scale_cap: float = 1.35

@export_category("Streak Zoom Accent")
@export_range(0.0, 1.5, 0.05) var streak_zoom_impulse_velocity: float = 0.72
@export_range(12.0, 36.0, 1.0) var streak_zoom_response_frequency: float = 24.0
@export_range(0.45, 0.98, 0.01) var streak_zoom_damping_ratio: float = 0.82
@export_range(0.0, 0.06, 0.005) var streak_zoom_max_out: float = 0.035
@export_range(0.0, 2.0, 0.1) var streak_zoom_max_velocity: float = 1.1

var _base_offset: Vector2 = Vector2.ZERO
var _base_zoom: Vector2 = Vector2.ONE
var _landing_response_offset_y: float = 0.0
var _landing_response_velocity_y: float = 0.0
var _streak_zoom_offset: float = 0.0
var _streak_zoom_velocity: float = 0.0


func _ready() -> void:
	_base_offset = offset
	_base_zoom = zoom

	# Prefer the scored result so the response can distinguish Good, Epic and
	# Perfect without delaying a frame. landing_scored is emitted synchronously
	# during the same physical landing callback that triggers the haptic pulse.
	var score_controller := get_node_or_null(landing_score_controller_path)
	if score_controller != null and score_controller.has_signal("landing_scored"):
		score_controller.connect(
			"landing_scored",
			Callable(self, "_on_landing_scored")
		)
		return

	# Keep a safe baseline fallback if the scoring controller is absent.
	var landing_controller := get_node_or_null(landing_feedback_controller_path)
	if landing_controller != null and landing_controller.has_signal("landing_confirmed"):
		landing_controller.connect(
			"landing_confirmed",
			Callable(self, "_on_landing_confirmed")
		)
	else:
		push_warning(
			"CameraFollow: Neither LandingScoreController nor LandingFeedbackController was found; landing camera response is disabled."
		)


func _process(delta: float) -> void:
	# Preserve the existing one-way upward follow; the reaction is an independent
	# screen-space offset so it cannot pull the camera's world position off target.
	if _target.global_position.y < global_position.y:
		global_position.y = lerp(
			global_position.y,
			_target.global_position.y,
			clampf(follow_lerp_weight * delta, 0.0, 1.0)
		)
	_update_landing_response(delta)


func _on_landing_scored(result: Dictionary) -> void:
	# All camera layers are resolved into one response for this physical landing.
	# Milestone accents only fire on activation, not on every active combo landing.
	var downward_speed: float = maxf(
		float(result.get("vertical_velocity", 0.0)),
		0.0
	)
	var quality: String = str(result.get("quality", "GOOD"))
	var combo_activated: bool = bool(result.get("combo_activated", false))
	var streak_activated: bool = bool(result.get("streak_activated", false))
	_apply_landing_response(
		downward_speed,
		quality,
		combo_activated,
		streak_activated
	)
	if streak_activated:
		_trigger_streak_zoom()


func _on_landing_confirmed(event: Variant) -> void:
	# Fallback path when scoring is unavailable: retain the proven baseline feel.
	var downward_speed: float = 0.0
	if event is LandingEvent:
		downward_speed = maxf(event.vertical_velocity, 0.0)
	elif _target != null and _target.has_method("get"):
		downward_speed = maxf(
			float(_target.get("landing_impact_velocity_y")),
			0.0
		)
	_apply_landing_response(downward_speed, "GOOD")


func _apply_landing_response(
	downward_speed: float,
	quality: String,
	combo_activated: bool = false,
	streak_activated: bool = false
) -> void:
	# Impact speed and quality define the base impulse. A milestone contributes
	# a small additive accent, combined into this same bounded spring response.
	var impact_scale: float = clampf(downward_speed / 900.0, 0.70, 1.15)
	var response_scale: float = _get_quality_impulse_multiplier(quality)
	if combo_activated:
		response_scale += maxf(combo_activation_impulse_bonus, 0.0)
	if streak_activated:
		response_scale += maxf(streak_activation_impulse_bonus, 0.0)
	response_scale = minf(
		response_scale,
		maxf(milestone_impulse_scale_cap, 1.0)
	)

	var max_velocity: float = maxf(landing_response_max_velocity, 0.0)
	_landing_response_velocity_y = clampf(
		_landing_response_velocity_y
		+ maxf(landing_response_impulse, 0.0) * impact_scale * response_scale,
		-max_velocity,
		max_velocity
	)


func _trigger_streak_zoom() -> void:
	# Zoom is a small spring-driven outward pulse, not a step change. Negative
	# zoom offset opens the view briefly; its damped rebound returns to baseline.
	var max_velocity: float = maxf(streak_zoom_max_velocity, 0.0)
	_streak_zoom_velocity = clampf(
		_streak_zoom_velocity - maxf(streak_zoom_impulse_velocity, 0.0),
		-max_velocity,
		max_velocity
	)


func _get_quality_impulse_multiplier(quality: String) -> float:
	match quality.to_upper():
		"PERFECT":
			return maxf(perfect_landing_impulse_multiplier, 0.0)
		"EPIC":
			return maxf(epic_landing_impulse_multiplier, 0.0)
		_:
			return maxf(good_landing_impulse_multiplier, 0.0)


func _update_landing_response(delta: float) -> void:
	# Substeps keep the underdamped spring stable and make recovery consistent
	# across ordinary frame rates and brief frame-time spikes.
	var remaining: float = clampf(delta, 0.0, 0.1)
	var angular_frequency: float = maxf(landing_response_frequency, 1.0)
	var spring_strength: float = angular_frequency * angular_frequency
	var damping: float = (
		2.0 * landing_response_damping_ratio * angular_frequency
	)
	while remaining > 0.0:
		var step: float = minf(remaining, 1.0 / 120.0)
		var acceleration: float = (
			-spring_strength * _landing_response_offset_y
			- damping * _landing_response_velocity_y
		)
		_landing_response_velocity_y += acceleration * step
		_landing_response_offset_y += _landing_response_velocity_y * step
		var max_offset: float = maxf(landing_response_max_offset, 0.0)
		_landing_response_offset_y = clampf(
			_landing_response_offset_y,
			-max_offset,
			max_offset
		)
			# The zoom spring runs on the same substeps to remain frame-rate stable.
		var zoom_frequency: float = maxf(streak_zoom_response_frequency, 1.0)
		var zoom_acceleration: float = (
			-(zoom_frequency * zoom_frequency) * _streak_zoom_offset
			- 2.0 * streak_zoom_damping_ratio * zoom_frequency * _streak_zoom_velocity
		)
		_streak_zoom_velocity += zoom_acceleration * step
		_streak_zoom_offset += _streak_zoom_velocity * step
		var zoom_out_limit: float = maxf(streak_zoom_max_out, 0.0)
		_streak_zoom_offset = clampf(
			_streak_zoom_offset,
			-zoom_out_limit,
			zoom_out_limit * 0.25
		)
		remaining -= step

	if (
		absf(_landing_response_offset_y) < 0.001
		and absf(_landing_response_velocity_y) < 0.01
	):
		_landing_response_offset_y = 0.0
		_landing_response_velocity_y = 0.0

	if (
		absf(_streak_zoom_offset) < 0.0001
		and absf(_streak_zoom_velocity) < 0.001
	):
		_streak_zoom_offset = 0.0
		_streak_zoom_velocity = 0.0

	offset = _base_offset + Vector2(0.0, _landing_response_offset_y)
	zoom = _base_zoom * maxf(1.0 + _streak_zoom_offset, 0.01)
