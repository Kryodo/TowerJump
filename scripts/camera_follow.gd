extends Camera2D
## Folgt dem Ziel (Ball) ausschließlich nach oben. Fällt der Ball wieder
## nach unten, bleibt die Kamera stehen (typisch für Doodle-Jump-artige Spiele).

@export var target_path: NodePath
@export var follow_lerp_weight: float = 6.0 ## Höher = die Kamera "klebt" enger am Ball

@onready var _target: Node2D = get_node(target_path)

@export_category("Landing Camera Response")
@export var landing_feedback_controller_path: NodePath = NodePath("../LandingFeedbackController")
@export_range(0.0, 14.0, 0.5) var landing_response_snap_distance: float = 8.0
@export_range(14.0, 44.0, 1.0) var landing_response_frequency: float = 32.0
@export_range(0.25, 0.85, 0.01) var landing_response_damping_ratio: float = 0.44
@export_range(0.0, 12.0, 0.5) var landing_response_max_offset: float = 9.0

var _base_offset: Vector2 = Vector2.ZERO
var _landing_response_offset_y: float = 0.0
var _landing_response_velocity_y: float = 0.0


func _ready() -> void:
	_base_offset = offset
	var landing_controller := get_node_or_null(landing_feedback_controller_path)
	if landing_controller != null and landing_controller.has_signal("landing_confirmed"):
		landing_controller.connect(
			"landing_confirmed",
			Callable(self, "_on_landing_confirmed")
		)
	else:
		push_warning(
			"CameraFollow: LandingFeedbackController was not found; landing camera response is disabled."
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


func _on_landing_confirmed(_event: Variant) -> void:
	# Contact produces an immediate downward camera snap (positive Camera2D Y).
	# The response then releases through an underdamped spring, moving slightly
	# upward past rest before settling. Resetting the same spring prevents stacked
	# tweens; repeated landings retrigger one bounded, coherent response.
	var max_offset: float = maxf(landing_response_max_offset, 0.0)
	_landing_response_offset_y = clampf(
		maxf(_landing_response_offset_y, 0.0)
		+ maxf(landing_response_snap_distance, 0.0),
		0.0,
		max_offset
	)
	_landing_response_velocity_y = 0.0
	offset = _base_offset + Vector2(0.0, _landing_response_offset_y)


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
		_landing_response_offset_y = clampf(
			_landing_response_offset_y,
			-landing_response_max_offset,
			landing_response_max_offset
		)
		remaining -= step

	if (
		absf(_landing_response_offset_y) < 0.001
		and absf(_landing_response_velocity_y) < 0.01
	):
		_landing_response_offset_y = 0.0
		_landing_response_velocity_y = 0.0

	offset = _base_offset + Vector2(0.0, _landing_response_offset_y)
