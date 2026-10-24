extends Node2D
## First layer in TowerJump's reusable platform-visual library.
##
## Normal platforms use a restrained resonance field outside the body:
## slow breathing, a travelling idle wave, a little motion around the tips,
## and a stronger expanding wave on landing. The field is drawn behind the
## platform's own body and edge. Other platform types are intentionally hidden
## until they receive their own visual behavior.

const PLATFORM_TYPE_NORMAL: int = 0
const IDLE_WAVE_PERIOD: float = 5.6
const IDLE_WAVE_DURATION: float = 1.55
const LANDING_WAVE_DURATION: float = 0.46
const CURVE_SEGMENTS: int = 42

var _platform_type: int = PLATFORM_TYPE_NORMAL
var _platform_width: float = 220.0
var _platform_height: float = 20.0
var _time: float = 0.0
var _phase_offset: float = 0.0
var _approach_charge: float = 0.0
var _approach_charge_target: float = 0.0
var _approach_target_x: float = 0.5
var _landing_wave_age: float = -1.0
var _landing_wave_strength: float = 0.0
var _landing_local_x: float = 0.0


func _ready() -> void:
	_phase_offset = randf_range(0.0, IDLE_WAVE_PERIOD)
	var additive_material := CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive_material
	set_process(true)


func configure(platform_type: int, platform_width: float, platform_height: float) -> void:
	_platform_type = platform_type
	_platform_width = maxf(platform_width, 1.0)
	_platform_height = maxf(platform_height, 1.0)

	# Only Normal gets this first-pass treatment. This keeps the upcoming
	# Moving/Spring/Decay identities from inheriting the wrong energy language.
	visible = _platform_type == PLATFORM_TYPE_NORMAL
	if not visible:
		_approach_charge = 0.0
		_approach_charge_target = 0.0
		_landing_wave_age = -1.0
	queue_redraw()


func set_approach_feedback(charge: float, target_x: float) -> void:
	_approach_charge_target = clampf(charge, 0.0, 1.0)
	_approach_target_x = clampf(target_x, 0.0, 1.0)


func play_landing_wave(landing_world_x: float, strength: float = 1.0) -> void:
	if _platform_type != PLATFORM_TYPE_NORMAL:
		return
	_landing_local_x = clampf(
		landing_world_x - global_position.x,
		-_platform_width * 0.5,
		_platform_width * 0.5
	)
	_landing_wave_age = 0.0
	_landing_wave_strength = clampf(strength, 0.65, 1.45)
	_approach_charge_target = 0.0
	queue_redraw()


func reset_feedback() -> void:
	_approach_charge = 0.0
	_approach_charge_target = 0.0
	_approach_target_x = 0.5
	_landing_wave_age = -1.0
	_landing_wave_strength = 0.0
	_landing_local_x = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or not is_visible_in_tree():
		return
	var platform := get_parent()
	if platform == null:
		return
	# Respect the parent platform's existing visibility test so pooled,
	# off-screen platforms do not redraw or advance their field animation.
	if platform.has_method("_is_platform_on_screen") and not bool(platform.call("_is_platform_on_screen")):
		return

	_time += delta
	var response: float = 1.0 - exp(-7.0 * delta)
	_approach_charge = lerpf(_approach_charge, _approach_charge_target, response)
	if _landing_wave_age >= 0.0:
		_landing_wave_age += delta
		if _landing_wave_age >= LANDING_WAVE_DURATION:
			_landing_wave_age = -1.0
			_landing_wave_strength = 0.0
	queue_redraw()


func _draw() -> void:
	if not visible or _platform_type != PLATFORM_TYPE_NORMAL:
		return

	var half_width: float = _platform_width * 0.5
	var half_height: float = _platform_height * 0.5
	var breathe: float = 0.5 + 0.5 * sin(_time * 1.35 + _phase_offset)
	var field_base_y: float = half_height + 4.2
	var phase: float = _time * 0.72 + _phase_offset

	# An asymmetric, slowly moving curve hangs just beneath the platform's
	# underside. It reads as a field in the surrounding space, not a second edge.
	var field_curve := PackedVector2Array()
	for i in range(CURVE_SEGMENTS + 1):
		var t: float = float(i) / float(CURVE_SEGMENTS)
		var x: float = lerpf(-half_width - 11.0, half_width + 11.0, t)
		var sway: float = sin(t * TAU * 1.15 + phase) * 0.72
		var secondary_sway: float = sin(t * TAU * 2.45 - _time * 0.52 + _phase_offset) * 0.34
		var gather: float = 0.0
		if _approach_charge > 0.001:
			var target_x: float = lerpf(-half_width, half_width, _approach_target_x)
			var focus_radius: float = lerpf(half_width * 0.30, half_width * 0.14, _approach_charge)
			gather = exp(-pow((x - target_x) / maxf(focus_radius, 1.0), 2.0)) * _approach_charge
		field_curve.append(Vector2(
			x,
			field_base_y + sway + secondary_sway - gather * 1.5
		))

	# A very soft, broad halo sits below the main filament; the brighter inner
	# trace breathes gently and keeps the platform from feeling inert.
	draw_polyline(
		field_curve,
		Color(0.22, 0.16, 1.45, 0.055 + breathe * 0.025),
		5.5,
		true
	)
	draw_polyline(
		field_curve,
		Color(0.08, 0.75, 2.0, 0.11 + breathe * 0.065),
		1.35,
		true
	)

	_draw_tip_filament(-1.0, half_width, half_height, phase, breathe)
	_draw_tip_filament(1.0, half_width, half_height, phase + 0.83, breathe)

	# Occasionally, a pair of resonance fronts travels from the center toward
	# both ends. Their timing is offset per platform, so adjacent platforms
	# don't pulse in lockstep.
	var idle_wave_clock: float = fposmod(_time + _phase_offset * 0.37, IDLE_WAVE_PERIOD)
	if idle_wave_clock < IDLE_WAVE_DURATION:
		var wave_progress: float = smoothstep(0.0, IDLE_WAVE_DURATION, idle_wave_clock)
		var wave_x: float = (half_width + 10.0) * wave_progress
		var wave_fade: float = (1.0 - wave_progress * 0.48) * (0.12 + 0.10 * breathe)
		_draw_wave_crest(wave_x, half_height, wave_fade, false)
		_draw_wave_crest(-wave_x, half_height, wave_fade, false)

	# As the player approaches, the resonance tightens toward the predicted
	# landing point, making the outside field participate in the same feedback.
	if _approach_charge > 0.025:
		var approach_x: float = lerpf(-half_width, half_width, _approach_target_x)
		var approach_strength: float = _approach_charge * (0.20 + breathe * 0.12)
		_draw_approach_crescent(approach_x, half_height, approach_strength)

	# A contact wave expands away from the real landing location, then dissolves.
	if _landing_wave_age >= 0.0:
		var landing_progress: float = smoothstep(0.0, LANDING_WAVE_DURATION, _landing_wave_age)
		var landing_fade: float = _landing_wave_strength * (1.0 - landing_progress) * 0.50
		var travel_extent: float = half_width + 13.0
		var left_front: float = lerpf(_landing_local_x, -travel_extent, landing_progress)
		var right_front: float = lerpf(_landing_local_x, travel_extent, landing_progress)
		_draw_wave_crest(left_front, half_height, landing_fade, true)
		_draw_wave_crest(right_front, half_height, landing_fade, true)

		if _landing_wave_age < 0.11:
			var impact_strength: float = _landing_wave_strength * (1.0 - _landing_wave_age / 0.11)
			var impact_color := Color(0.32, 1.55, 3.25, clampf(impact_strength * 0.28, 0.0, 0.42))
			var impact_y: float = half_height + 5.0
			draw_line(
				Vector2(_landing_local_x - 6.0, impact_y + 2.0),
				Vector2(_landing_local_x - 2.0, impact_y - 1.0),
				impact_color, 1.5, true
			)
			draw_line(
				Vector2(_landing_local_x + 2.0, impact_y - 1.0),
				Vector2(_landing_local_x + 6.0, impact_y + 2.0),
				impact_color, 1.5, true
			)


func _draw_tip_filament(
	side: float,
	half_width: float,
	half_height: float,
	phase: float,
	breathe: float
) -> void:
	var bob: float = sin(phase * 0.92 + side * 0.4) * 1.25
	var drift: float = sin(phase * 0.63 + side) * 1.6
	var points := PackedVector2Array([
		Vector2(side * (half_width + 1.5), half_height - 3.0),
		Vector2(side * (half_width + 4.5), half_height + bob * 0.35),
		Vector2(side * (half_width + 8.0 + drift), half_height + 3.0 + bob),
		Vector2(side * (half_width + 11.5), half_height + 7.0 - bob * 0.25)
	])
	var alpha: float = 0.075 + breathe * 0.075
	draw_polyline(points, Color(0.10, 0.78, 2.15, alpha), 1.15, true)


func _draw_wave_crest(
	center_x: float,
	half_height: float,
	strength: float,
	landing_wave: bool
) -> void:
	var y: float = half_height + 4.2
	var points := PackedVector2Array([
		Vector2(center_x - 7.0, y + 2.0),
		Vector2(center_x - 3.5, y + 0.4),
		Vector2(center_x, y - 0.8),
		Vector2(center_x + 3.5, y + 0.4),
		Vector2(center_x + 7.0, y + 2.0)
	])
	var alpha: float = clampf(strength * (1.0 if landing_wave else 0.72), 0.0, 0.45)
	var tint := Color(0.16, 1.0, 2.65, alpha)
	if landing_wave:
		tint = Color(0.34, 1.65, 3.4, alpha)
	draw_polyline(points, tint, 1.8 if landing_wave else 1.25, true)


func _draw_approach_crescent(center_x: float, half_height: float, strength: float) -> void:
	var y: float = half_height + 4.0
	var points := PackedVector2Array([
		Vector2(center_x - 11.0, y + 2.0),
		Vector2(center_x - 6.0, y + 0.8),
		Vector2(center_x, y - 0.2),
		Vector2(center_x + 6.0, y + 0.8),
		Vector2(center_x + 11.0, y + 2.0)
	])
	draw_polyline(
		points,
		Color(0.10, 1.05, 2.5, clampf(strength, 0.0, 0.36)),
		1.4,
		true
	)
