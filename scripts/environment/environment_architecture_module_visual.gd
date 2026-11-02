extends Node2D
## Small reusable architectural scene vocabulary for the Art Library preview fixtures.

enum ModuleStyle {
	FAR_APERTURE_MASS,
	MIDDLE_SUPPORT,
	NEAR_EDGE_RAIL,
}

@export var module_style: ModuleStyle = ModuleStyle.FAR_APERTURE_MASS
@export var module_width: float = 190.0
@export var module_height: float = 1200.0

var _theme: EnvironmentThemeProfile
var _lighting: EnvironmentLightingProfile
var _seed: int = 0
var _light_state: int = EnvironmentLightingProfile.LightState.DORMANT
var _clock: float = 0.0
var _flicker_alpha: float = 1.0


func configure(
	theme_profile: EnvironmentThemeProfile,
	lighting_profile: EnvironmentLightingProfile,
	seed_value: int,
	light_state: int = -1
) -> void:
	_theme = theme_profile
	_lighting = lighting_profile
	_seed = seed_value
	_light_state = (
		light_state
		if light_state >= 0
		else (_lighting.state_for_seed(seed_value) if _lighting != null else EnvironmentLightingProfile.LightState.DORMANT)
	)
	queue_redraw()


func _process(delta: float) -> void:
	if _lighting == null or not _lighting.flicker_enabled:
		return
	_clock += delta
	var rate := maxf(_lighting.flicker_rate_hz, 0.1)
	var phase := float(posmod(_seed, 997)) * 0.017
	var wave := 0.5 + 0.5 * sin(_clock * TAU * rate + phase)
	_flicker_alpha = lerpf(_lighting.flicker_minimum_alpha, 1.0, wave)
	queue_redraw()


func _draw() -> void:
	match module_style:
		ModuleStyle.MIDDLE_SUPPORT:
			_draw_middle_support()
		ModuleStyle.NEAR_EDGE_RAIL:
			_draw_near_frame()
		_:
			_draw_far_mass()


func _draw_far_mass() -> void:
	var fill_a := _theme.far_fill_a if _theme != null else Color(0.004, 0.012, 0.026, 0.98)
	var fill_b := _theme.far_fill_b if _theme != null else Color(0.006, 0.016, 0.032, 0.98)
	var width := module_width
	var height := module_height
	var inset := 12.0 + float(posmod(_seed, 4)) * 7.0
	var silhouette := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(width, 0.0),
		Vector2(width, height * 0.19),
		Vector2(width - inset, height * 0.23),
		Vector2(width - inset, height * 0.41),
		Vector2(width - 6.0, height * 0.46),
		Vector2(width - 6.0, height * 0.73),
		Vector2(width - inset * 1.25, height * 0.78),
		Vector2(width - inset * 1.25, height),
		Vector2(0.0, height),
	])
	draw_colored_polygon(silhouette, fill_a if posmod(_seed, 3) == 0 else fill_b)

	# A compact aperture/panel group gives the mass a readable construction rhythm.
	var group_y := 150.0 + float(posmod(_seed, 4)) * 180.0
	var panel := Rect2(Vector2(26.0, group_y), Vector2(74.0, 138.0))
	draw_rect(panel, Color(0.003, 0.006, 0.016, 0.86), true)
	draw_rect(panel, _muted_accent(0.34), false, 1.2)
	draw_rect(Rect2(panel.position + Vector2(10.0, 12.0), Vector2(54.0, 30.0)), _state_color(), true)
	draw_rect(Rect2(panel.position + Vector2(10.0, 58.0), Vector2(54.0, 6.0)), _muted_accent(0.30), true)
	draw_rect(Rect2(panel.position + Vector2(10.0, 76.0), Vector2(35.0, 6.0)), _muted_accent(0.22), true)

	var second_y := minf(group_y + 410.0, height - 230.0)
	draw_rect(Rect2(Vector2(34.0, second_y), Vector2(54.0, 92.0)), Color(0.003, 0.006, 0.016, 0.78), true)
	draw_rect(Rect2(Vector2(34.0, second_y), Vector2(54.0, 92.0)), _muted_accent(0.24), false, 1.0)
	draw_line(Vector2(width - 22.0, 40.0), Vector2(width - 22.0, height * 0.34), _muted_accent(0.18), 1.4, true)


func _draw_middle_support() -> void:
	var fill := _theme.middle_fill if _theme != null else Color(0.011, 0.024, 0.044, 0.96)
	var width := module_width
	var height := module_height
	var support := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(width - 8.0, 0.0),
		Vector2(width - 8.0, height * 0.16),
		Vector2(width - 20.0, height * 0.20),
		Vector2(width - 20.0, height * 0.82),
		Vector2(width - 5.0, height * 0.87),
		Vector2(width - 5.0, height),
		Vector2(0.0, height),
	])
	draw_colored_polygon(support, fill)

	var plate_y := 150.0 + float(posmod(_seed, 3)) * 70.0
	var plate := Rect2(Vector2(28.0, plate_y), Vector2(126.0, 270.0))
	draw_rect(plate, Color(0.004, 0.009, 0.022, 0.96), true)
	draw_rect(plate, _muted_accent(0.46), false, 1.4)
	var variant := posmod(_seed, 4)
	var step_width := 72.0 + float(variant) * 9.0
	draw_rect(
		Rect2(plate.position + Vector2(12.0, 18.0), Vector2(step_width, 18.0)),
		_muted_accent(0.28),
		true
	)
	draw_rect(
		Rect2(plate.position + Vector2(12.0, 50.0), Vector2(step_width - 15.0, 7.0)),
		_muted_accent(0.23),
		true
	)
	draw_line(
		plate.position + Vector2(12.0, 224.0),
		plate.position + Vector2(plate.size.x - 12.0, 224.0),
		_muted_accent(0.24),
		1.2,
		true
	)

	# A mechanical recess sits at least 15 px beyond the stepped plate.
	var slot_x := plate.end.x + 15.0
	var slot_width := maxf(width - slot_x - 18.0, 18.0)
	var slot_y := plate_y + 32.0 + float(variant) * 23.0
	draw_rect(Rect2(Vector2(slot_x, slot_y), Vector2(slot_width, 82.0)), Color(0.002, 0.006, 0.016, 0.98), true)
	draw_rect(Rect2(Vector2(slot_x, slot_y), Vector2(slot_width, 82.0)), _muted_accent(0.22), false, 1.0)
	draw_line(
		Vector2(slot_x + 4.0, slot_y + 56.0),
		Vector2(slot_x + slot_width - 4.0, slot_y + 56.0),
		_muted_accent(0.30),
		1.0,
		true
	)

	var reveal_color := _state_color()
	draw_line(Vector2(7.0, 34.0), Vector2(7.0, 270.0), reveal_color, 1.8, true)
	draw_line(Vector2(width - 9.0, height - 270.0), Vector2(width - 9.0, height - 34.0), _muted_accent(0.44), 1.4, true)


func _draw_near_frame() -> void:
	var width := module_width
	var height := module_height
	var color := _theme.near_detail if _theme != null else Color(0.018, 0.13, 0.18, 0.20)
	# Sparse broken rails only; no filled blocks or dense particle-like marks.
	var offset := float(posmod(_seed, 5)) * 62.0
	draw_line(Vector2(5.0, 48.0 + offset), Vector2(5.0, 270.0 + offset), color, 1.5, true)
	draw_line(Vector2(5.0, 650.0 + offset), Vector2(5.0, 830.0 + offset), color, 1.2, true)
	draw_line(Vector2(width - 5.0, 210.0 + offset), Vector2(width - 5.0, 390.0 + offset), color, 1.4, true)


func _state_color() -> Color:
	if _lighting != null:
		var result := _lighting.color_for_state(_theme, _light_state)
		result.a *= _flicker_alpha
		return result
	if _theme != null:
		var fallback := _theme.light_subtle
		fallback.a *= _flicker_alpha
		return fallback
	return Color(0.08, 0.3, 0.4, 0.35 * _flicker_alpha)


func _muted_accent(alpha_scale: float) -> Color:
	var result := _theme.accent_primary if _theme != null else Color(0.012, 0.82, 1.15, 0.84)
	result.a *= alpha_scale
	return result
