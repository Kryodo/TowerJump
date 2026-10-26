extends Node
## Sends a short haptic transient from the same confirmed-contact event as the camera.
## Gamepad vibration supports desktop testing; handheld vibration is used on mobile.

@export var landing_feedback_controller_path: NodePath = NodePath("../LandingFeedbackController")

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

var _feedback_controller: Node = null


func _ready() -> void:
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
			"LandingHapticFeedback: LandingFeedbackController was not found; haptics are disabled."
		)


func _on_landing_confirmed(event: Variant) -> void:
	if event == null or not event is LandingEvent:
		return

	# This is the velocity captured immediately before move_and_slide resolves
	# the collision, rather than the near-zero velocity after collision response.
	var impact_speed: float = maxf(event.vertical_velocity, 0.0)
	var speed_reference: float = maxf(full_impact_speed, 1.0)
	var impact_ratio: float = clampf(impact_speed / speed_reference, 0.0, 1.0)
	var strength: float = lerpf(
		clampf(minimum_impact_strength, 0.0, 1.0),
		1.0,
		impact_ratio
	)

	_play_gamepad_pulse(strength)

	if enable_handheld_haptics and OS.has_feature("mobile"):
		var amplitude: float = clampf(handheld_amplitude_max * strength, 0.0, 1.0)
		Input.vibrate_handheld(
			maxi(handheld_pulse_duration_ms, 1),
			amplitude
		)


func _play_gamepad_pulse(strength: float) -> void:
	if not enable_gamepad_haptics:
		return

	# Use the first connected controller that reports vibration support.
	# A very short pulse with a restrained strong motor feels like a tick,
	# rather than the longer, muddy rumble we want to avoid.
	for device_id in Input.get_connected_joypads():
		if not Input.has_joy_vibration(device_id):
			continue

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
		break
