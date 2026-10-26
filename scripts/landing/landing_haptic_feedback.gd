extends Node
## Sends impact-scaled landing haptics. Normal contacts use a short tap;
## COMBO activation strengthens that tap, while STREAK gets a compact double tap.

@export var landing_feedback_controller_path: NodePath = NodePath("../LandingFeedbackController")
@export var landing_score_controller_path: NodePath = NodePath("../LandingScoreController")

@export_category("Haptic Output")
@export var enable_gamepad_haptics: bool = true
@export var enable_handheld_haptics: bool = true
@export_range(0.02, 0.12, 0.005) var gamepad_pulse_duration: float = 0.055
@export_range(10, 80, 5) var handheld_pulse_duration_ms: int = 35

@export_category("Impact Scaling")
@export_range(200.0, 1600.0, 50.0) var full_impact_speed: float = 1200.0
@export_range(0.0, 0.25, 0.01) var minimum_impact_strength: float = 0.18
@export_range(0.0, 0.25, 0.01) var gamepad_weak_motor_max: float = 0.12
@export_range(0.0, 0.8, 0.05) var gamepad_strong_motor_max: float = 0.50
@export_range(0.0, 1.0, 0.05) var handheld_amplitude_max: float = 0.55

@export_category("Milestone Haptic Accents")
@export_range(1.0, 1.4, 0.02) var combo_activation_strength_multiplier: float = 1.12
@export_range(1.0, 1.5, 0.02) var streak_primary_strength_multiplier: float = 1.18
@export_range(0.06, 0.20, 0.01) var streak_second_pulse_delay: float = 0.105
@export_range(0.35, 0.90, 0.05) var streak_second_pulse_strength: float = 0.68

var _feedback_controller: Node = null


func _ready() -> void:
	# Use the scored result when available so milestone haptics remain aligned
	# with the camera's one-shot COMBO/STREAK accents on this same landing.
	var score_controller := get_node_or_null(landing_score_controller_path)
	if score_controller != null and score_controller.has_signal("landing_scored"):
		var score_callback := Callable(self, "_on_landing_scored")
		if not score_controller.is_connected("landing_scored", score_callback):
			score_controller.connect("landing_scored", score_callback)
		return

	# Fallback retains ordinary physical-contact haptics if scoring is unavailable.
	_feedback_controller = get_node_or_null(landing_feedback_controller_path)
	if (
		_feedback_controller != null
		and _feedback_controller.has_signal("landing_confirmed")
	):
		var callback := Callable(self, "_on_landing_confirmed")
		if not _feedback_controller.is_connected("landing_confirmed", callback):
			_feedback_controller.connect("landing_confirmed", callback)
	else:
		push_warning(
			"LandingHapticFeedback: Neither LandingScoreController nor LandingFeedbackController was found; haptics are disabled."
		)


func _on_landing_scored(result: Dictionary) -> void:
	var impact_speed: float = maxf(
		float(result.get("vertical_velocity", 0.0)),
		0.0
	)
	var combo_activated: bool = bool(result.get("combo_activated", false))
	var streak_activated: bool = bool(result.get("streak_activated", false))
	_play_landing_feedback(impact_speed, combo_activated, streak_activated)


func _on_landing_confirmed(event: Variant) -> void:
	if not event is LandingEvent:
		return
	_play_landing_feedback(maxf(event.vertical_velocity, 0.0), false, false)


func _play_landing_feedback(
	impact_speed: float,
	combo_activated: bool,
	streak_activated: bool
) -> void:
	var speed_reference: float = maxf(full_impact_speed, 1.0)
	var impact_ratio: float = clampf(impact_speed / speed_reference, 0.0, 1.0)
	var strength: float = lerpf(
		clampf(minimum_impact_strength, 0.0, 1.0),
		1.0,
		impact_ratio
	)

	if combo_activated:
		strength *= maxf(combo_activation_strength_multiplier, 1.0)
	if streak_activated:
		strength *= maxf(streak_primary_strength_multiplier, 1.0)
	strength = clampf(strength, 0.0, 1.0)

	# The primary pulse is synchronous with the scored landing event.
	_play_pulse(strength)

	# STREAK's second short pulse is a recognizable accent, not a long rumble.
	if streak_activated:
		var second_strength: float = clampf(
			strength * streak_second_pulse_strength,
			0.0,
			1.0
		)
		get_tree().create_timer(
			maxf(streak_second_pulse_delay, 0.06)
		).timeout.connect(
			_on_streak_second_tap.bind(second_strength)
		)


func _on_streak_second_tap(strength: float) -> void:
	_play_pulse(strength)


func _play_pulse(strength: float) -> void:
	var safe_strength: float = clampf(strength, 0.0, 1.0)
	_play_gamepad_pulse(safe_strength)

	if enable_handheld_haptics and OS.has_feature("mobile"):
		var amplitude: float = clampf(
			handheld_amplitude_max * safe_strength,
			0.0,
			1.0
		)
		Input.vibrate_handheld(
			maxi(handheld_pulse_duration_ms, 1),
			amplitude
		)


func _play_gamepad_pulse(strength: float) -> void:
	if not enable_gamepad_haptics:
		return

	# Gamepad vibration is optional; controllers without rumble support simply
	# won't vibrate. Keep the pulse crisp to avoid a muddy long rumble.
	var connected_joypads: Array[int] = Input.get_connected_joypads()
	if connected_joypads.is_empty():
		return

	var device_id: int = connected_joypads[0]
	var weak_motor: float = clampf(
		gamepad_weak_motor_max * strength,
		0.0,
		1.0
	)
	var strong_motor: float = clampf(
		gamepad_strong_motor_max * strength,
		0.0,
		1.0
	)
	Input.start_joy_vibration(
		device_id,
		weak_motor,
		strong_motor,
		maxf(gamepad_pulse_duration, 0.02)
	)
