extends Node2D
## Authored landmark visuals kept independent from repeating architecture modules.

enum LandmarkStyle {
	RESONANCE_GATE,
	ARCHIVE_FRAGMENT,
}

@export var landmark_style: LandmarkStyle = LandmarkStyle.RESONANCE_GATE

var _theme: EnvironmentThemeProfile
var _lighting: EnvironmentLightingProfile
var _seed: int = 0


func configure(
	theme_profile: EnvironmentThemeProfile,
	lighting_profile: EnvironmentLightingProfile,
	seed_value: int
) -> void:
	_theme = theme_profile
	_lighting = lighting_profile
	_seed = seed_value
	queue_redraw()


func _draw() -> void:
	if landmark_style == LandmarkStyle.ARCHIVE_FRAGMENT:
		_draw_archive_fragment()
	else:
		_draw_resonance_gate()


func _draw_resonance_gate() -> void:
	var cyan := _accent_primary()
	var violet := _accent_secondary()
	var outer := PackedVector2Array([
		Vector2(-245.0, 385.0),
		Vector2(-245.0, -130.0),
		Vector2(-205.0, -285.0),
		Vector2(-128.0, -390.0),
		Vector2(128.0, -390.0),
		Vector2(205.0, -285.0),
		Vector2(245.0, -130.0),
		Vector2(245.0, 385.0),
		Vector2(178.0, 435.0),
		Vector2(-178.0, 435.0),
	])
	draw_colored_polygon(outer, Color(0.008, 0.019, 0.037, 0.99))

	var aperture := PackedVector2Array([
		Vector2(-153.0, 320.0),
		Vector2(-153.0, -118.0),
		Vector2(-124.0, -240.0),
		Vector2(-75.0, -304.0),
		Vector2(75.0, -304.0),
		Vector2(124.0, -240.0),
		Vector2(153.0, -118.0),
		Vector2(153.0, 320.0),
		Vector2(0.0, 372.0),
	])
	draw_colored_polygon(aperture, Color(0.003, 0.007, 0.017, 1.0))

	cyan.a *= 0.74
	violet.a *= 0.66
	draw_line(Vector2(-245.0, 165.0), Vector2(-245.0, -118.0), cyan, 2.5, true)
	draw_line(Vector2(245.0, -118.0), Vector2(245.0, 165.0), cyan, 2.5, true)
	draw_line(Vector2(-128.0, -390.0), Vector2(-76.0, -320.0), violet, 2.0, true)
	draw_line(Vector2(128.0, -390.0), Vector2(76.0, -320.0), violet, 2.0, true)
	draw_line(Vector2(-155.0, -118.0), Vector2(-155.0, 280.0), cyan, 2.0, true)
	draw_line(Vector2(155.0, -118.0), Vector2(155.0, 280.0), cyan, 2.0, true)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-116.0, -428.0),
		"RESONANCE GATE",
		HORIZONTAL_ALIGNMENT_LEFT,
		232.0,
		13,
		Color(0.19, 0.42, 0.53, 0.58)
	)


func _draw_archive_fragment() -> void:
	var frame := Color(0.018, 0.050, 0.071, 0.72)
	var accent := _accent_primary()
	accent.a *= 0.48
	var housing := Rect2(Vector2(-52.0, -82.0), Vector2(104.0, 164.0))
	draw_rect(housing, Color(0.006, 0.015, 0.030, 0.98), true)
	draw_rect(housing, frame, false, 2.0)
	draw_rect(Rect2(Vector2(-34.0, -61.0), Vector2(68.0, 122.0)), Color(0.003, 0.008, 0.018, 1.0), true)
	draw_line(Vector2(-23.0, -43.0), Vector2(0.0, -55.0), accent, 2.0, true)
	draw_line(Vector2(0.0, -55.0), Vector2(23.0, -43.0), accent, 2.0, true)
	draw_line(Vector2(-19.0, 34.0), Vector2(19.0, 34.0), accent, 1.4, true)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-42.0, 108.0),
		"ARCHIVE",
		HORIZONTAL_ALIGNMENT_LEFT,
		84.0,
		10,
		Color(0.16, 0.35, 0.45, 0.55)
	)


func _accent_primary() -> Color:
	return _theme.accent_primary if _theme != null else Color(0.012, 0.82, 1.15, 0.84)


func _accent_secondary() -> Color:
	return _theme.accent_secondary if _theme != null else Color(0.42, 0.16, 0.88, 0.78)
