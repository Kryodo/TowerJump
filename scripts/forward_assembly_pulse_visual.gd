extends Node2D
## Lightweight additive-looking visual for the shared forward-construction pulse.
## This node only draws; scheduling and gameplay ownership remain in PlatformSpawner.

const TRAIL_LIFETIME: float = 0.14
const MAX_TRAIL_POINTS: int = 28

var _pulse_position: Vector2 = Vector2.ZERO
var _has_position: bool = false
var _intensity: float = 0.0
var _trail: Array[Dictionary] = []


func set_pulse_state(local_position: Vector2, intensity: float, moving: bool) -> void:
	if moving and _intensity > 0.001 and _has_position and _pulse_position.distance_to(local_position) >= 2.0:
		_trail.append({
			"position": _pulse_position,
			"age": 0.0,
		})
		while _trail.size() > MAX_TRAIL_POINTS:
			_trail.pop_front()

	_pulse_position = local_position
	_has_position = true
	_intensity = clampf(intensity, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	for index in range(_trail.size() - 1, -1, -1):
		_trail[index]["age"] = float(_trail[index]["age"]) + delta
		if float(_trail[index]["age"]) >= TRAIL_LIFETIME:
			_trail.remove_at(index)
	queue_redraw()


func _draw() -> void:
	if not _has_position:
		return

	# The trail is a soft cyan trace, not a solid beam. Its short lifetime keeps
	# the pulse readable without painting a permanent line through the tower.
	var previous_position: Vector2 = _trail[0]["position"] if not _trail.is_empty() else _pulse_position
	for index in range(1, _trail.size()):
		var point: Dictionary = _trail[index]
		var point_position: Vector2 = point["position"]
		var age_ratio: float = clampf(float(point["age"]) / TRAIL_LIFETIME, 0.0, 1.0)
		var alpha: float = (1.0 - age_ratio) * _intensity
		draw_line(
			previous_position,
			point_position,
			Color(0.02, 0.58, 1.25, alpha * 0.045),
			12.0,
			true
		)
		draw_line(
			previous_position,
			point_position,
			Color(0.0, 0.82, 1.45, alpha * 0.15),
			4.0,
			true
		)
		previous_position = point_position

	if not _trail.is_empty():
		var last_point: Dictionary = _trail[_trail.size() - 1]
		var last_age: float = clampf(float(last_point["age"]) / TRAIL_LIFETIME, 0.0, 1.0)
		var trail_alpha: float = (1.0 - last_age) * _intensity
		draw_line(
			last_point["position"],
			_pulse_position,
			Color(0.02, 0.58, 1.25, trail_alpha * 0.045),
			12.0,
			true
		)
		draw_line(
			last_point["position"],
			_pulse_position,
			Color(0.0, 0.82, 1.45, trail_alpha * 0.15),
			4.0,
			true
		)

	if _intensity <= 0.001:
		return

	# Multiple restrained halos provide the bloom source; the bright center
	# makes the construction front read as a small moving point of energy.
	draw_circle(_pulse_position, 20.0, Color(0.0, 0.40, 0.95, 0.035 * _intensity))
	draw_circle(_pulse_position, 12.0, Color(0.0, 0.70, 1.35, 0.09 * _intensity))
	draw_circle(_pulse_position, 6.5, Color(0.02, 0.95, 1.70, 0.38 * _intensity))
	draw_circle(_pulse_position, 3.2, Color(0.52, 1.18, 1.45, 0.92 * _intensity))
	draw_circle(_pulse_position, 1.4, Color(1.15, 1.30, 1.35, 0.95 * _intensity))
