extends Node2D
## A constrained architectural grammar for TowerJump's background.
## Every silhouette belongs to a connected side structure or a repeated support
## module. Randomness changes module variants, never the underlying language.

enum LayerType {
	FAR_SILHOUETTES,
	MID_ARCHITECTURE,
	NEAR_FRAMES,
}
enum PaletteVariant {
	CURRENT_NAVY,
	REVERSED_VOID,
	INTERMEDIATE_BLUE_BLACK,
	INTERMEDIATE_BLUE_BLACK_MID_CONTRAST,
	CURRENT_NAVY_MID_CONTRAST,
	CURRENT_NAVY_BRIGHTER_FAR,
	CURRENT_NAVY_HYBRID,
	CURRENT_NAVY_HUE_ONLY,
	CURRENT_NAVY_BRIGHTNESS_ONLY,
	CURRENT_NAVY_A1_DARK_TINT_FAR,
	CURRENT_NAVY_A1_BRIGHT_TINT_FAR,
	CURRENT_NAVY_A2_DARK_BLUE_MID,
	CURRENT_NAVY_A2_DARK_PURPLE_MID,
	CURRENT_NAVY_E_BALANCED,
	CURRENT_NAVY_E_BRIGHTER,
	CURRENT_NAVY_PURPLE_FAR_BLUE_MID,
	CURRENT_NAVY_BLUE_FAR_PURPLE_MID,
}

@export var layer_type: LayerType = LayerType.FAR_SILHOUETTES
@export var palette_variant: PaletteVariant = PaletteVariant.CURRENT_NAVY
@export var environment_seed: int = 7319
@export var world_width: float = 720.0
@export var section_top_y: float = -10400.0
@export var section_bottom_y: float = 1600.0

var _rng := RandomNumberGenerator.new()

const FAR_MASS_A := Color(0.004, 0.012, 0.026, 0.98)
const FAR_MASS_B := Color(0.006, 0.016, 0.032, 0.98)
const MID_MASS := Color(0.011, 0.024, 0.044, 0.96)
const MID_SHADOW := Color(0.003, 0.008, 0.019, 0.96)
const SEAM_CYAN := Color(0.025, 0.19, 0.26, 0.42)
const SEAM_VIOLET := Color(0.15, 0.07, 0.27, 0.34)
const NEAR_SEAM := Color(0.018, 0.13, 0.18, 0.20)
const ACCENT_CYAN := Color(0.012, 0.82, 1.15, 0.84)
const ACCENT_VIOLET := Color(0.42, 0.16, 0.88, 0.78)
const EDGE_REVEAL := Color(0.026, 0.105, 0.155, 0.64)


func _draw() -> void:
	_rng.seed = int(environment_seed) + int(layer_type) * 7919

	match layer_type:
		LayerType.FAR_SILHOUETTES:
			_draw_far_architecture()
		LayerType.MID_ARCHITECTURE:
			_draw_mid_architecture()
			_draw_resonance_gate()
			_draw_archive_recess()
		LayerType.NEAR_FRAMES:
			_draw_near_frames()


func _far_mass_color(index: int) -> Color:
	match palette_variant:
		PaletteVariant.CURRENT_NAVY_HUE_ONLY:
			# Hue-vs-brightness test B: use A2's actual RGB proportions,
			# scaled down to match each original control fill's weighted RGB luminance.
			# This preserves the subtle A2 hue/chromaticity shift without lifting brightness.
			return Color(0.004514, 0.012040, 0.024080, 0.98) if index % 3 == 0 else Color(0.006366, 0.015911, 0.031821, 0.98)
		PaletteVariant.CURRENT_NAVY_BRIGHTNESS_ONLY:
			# Hue-vs-brightness test C: retain the original RGB ratios while
			# lifting luminance close to the existing combined A2 fill values.
			return Color(0.01042, 0.03127, 0.06776, 0.98) if index % 3 == 0 else Color(0.01479, 0.03945, 0.07890, 0.98)
		PaletteVariant.CURRENT_NAVY_A1_DARK_TINT_FAR:
			# B in the bounded comparison: dark indigo/blue-purple far masses,
			# darker overall than the navy void and distinct from A1's middle fill.
			return Color(0.012, 0.010, 0.032, 0.98) if index % 3 == 0 else Color(0.016, 0.012, 0.038, 0.98)
		PaletteVariant.CURRENT_NAVY_A1_BRIGHT_TINT_FAR:
			# Earlier A1 candidate C, retained as a historical comparison.
			return Color(0.020, 0.026, 0.066, 0.98) if index % 3 == 0 else Color(0.025, 0.027, 0.072, 0.98)
		PaletteVariant.CURRENT_NAVY_E_BALANCED:
			# New follow-up B: a modestly darker, slightly purple-shifted A2 far tint.
			return Color(0.010, 0.026, 0.060, 0.98) if index % 3 == 0 else Color(0.014, 0.032, 0.070, 0.98)
		PaletteVariant.CURRENT_NAVY_E_BRIGHTER:
			# New follow-up C: a brighter blue-purple far tint than A2.
			return Color(0.016, 0.033, 0.075, 0.98) if index % 3 == 0 else Color(0.022, 0.041, 0.092, 0.98)
		PaletteVariant.CURRENT_NAVY_PURPLE_FAR_BLUE_MID:
			# New follow-up D: purple-leaning far fills matched approximately to A2's far-fill luminance.
			return Color(0.056, 0.014, 0.100, 0.98) if index % 3 == 0 else Color(0.071, 0.018, 0.126, 0.98)
		PaletteVariant.CURRENT_NAVY_BRIGHTER_FAR, PaletteVariant.CURRENT_NAVY_HYBRID, PaletteVariant.CURRENT_NAVY_A2_DARK_BLUE_MID, PaletteVariant.CURRENT_NAVY_A2_DARK_PURPLE_MID, PaletteVariant.CURRENT_NAVY_BLUE_FAR_PURPLE_MID:
			# F / A2, G / Hybrid, and new E use A2's original brighter blue far fills.
			return Color(0.011764706, 0.03137255, 0.0627451, 0.98) if index % 3 == 0 else Color(0.015686275, 0.039215688, 0.078431375, 0.98)
		PaletteVariant.REVERSED_VOID, PaletteVariant.INTERMEDIATE_BLUE_BLACK_MID_CONTRAST:
			# B reverses the existing roles; D deliberately retains C's far-mass
			# fills so D changes only the middle fill compared with C.
			return Color(0.007843138, 0.023529412, 0.050980393, 0.98) if index % 3 == 0 else Color(0.007843138, 0.019607844, 0.043137256, 0.98)
		PaletteVariant.INTERMEDIATE_BLUE_BLACK:
			# Keep the same dark navy silhouette but reduce the background-to-mass
			# difference through an intermediate background shade.
			return Color(0.007843138, 0.023529412, 0.050980393, 0.98) if index % 3 == 0 else Color(0.007843138, 0.019607844, 0.043137256, 0.98)
		_:
			return FAR_MASS_A if index % 3 == 0 else FAR_MASS_B


func _mid_mass_color() -> Color:
	match palette_variant:
		PaletteVariant.CURRENT_NAVY_MID_CONTRAST, PaletteVariant.INTERMEDIATE_BLUE_BLACK_MID_CONTRAST, PaletteVariant.CURRENT_NAVY_HYBRID, PaletteVariant.CURRENT_NAVY_A1_DARK_TINT_FAR, PaletteVariant.CURRENT_NAVY_A1_BRIGHT_TINT_FAR:
			# Existing A1/D family retains the brighter blue-purple middle fill.
			return Color(0.015686275, 0.03137255, 0.0627451, 0.96) # approx. #040810
		PaletteVariant.CURRENT_NAVY_A2_DARK_BLUE_MID, PaletteVariant.CURRENT_NAVY_PURPLE_FAR_BLUE_MID:
			# A2/E and new D use the same dark-blue middle fill for the purple-placement comparison.
			return Color(0.0055, 0.0165, 0.038, 0.96)
		PaletteVariant.CURRENT_NAVY_A2_DARK_PURPLE_MID:
			# Earlier A2/F option, retained unchanged.
			return Color(0.014, 0.010, 0.038, 0.96)
		PaletteVariant.CURRENT_NAVY_E_BALANCED:
			# New follow-up B: slightly brighter, distinct blue middle fill.
			# Red/green stay below the navy backdrop while blue sits above it,
			# so the fill cannot visually collapse into the same navy relationship.
			return Color(0.0055, 0.018, 0.060, 0.96)
		PaletteVariant.CURRENT_NAVY_E_BRIGHTER:
			# New follow-up C: brighter blue middle fill, still darker overall than the void.
			# Its blue channel rises farther above the backdrop while red/green remain lower.
			return Color(0.0055, 0.019, 0.070, 0.96)
		PaletteVariant.CURRENT_NAVY_BLUE_FAR_PURPLE_MID:
			# New follow-up E: purple middle hue with approximate luminance matched to the dark-blue E fill.
			return Color(0.030, 0.0075, 0.054, 0.96)
		PaletteVariant.REVERSED_VOID, PaletteVariant.INTERMEDIATE_BLUE_BLACK:
			# Existing low-contrast middle structure, retained for A/B/C.
			return Color(0.011764706, 0.02745098, 0.050980393, 0.96)
		_:
			return MID_MASS


# A few broad, overlapping side masses imply an enormous continuous structure.
# The inner edges step in a repeated cadence; there are no detached shards.
func _draw_far_architecture() -> void:
	var y: float = section_top_y - 900.0
	var index := 0
	while y < section_bottom_y:
		var height := 1920.0 + _rng.randf_range(-110.0, 120.0)
		var left_width := 165.0 + float(index % 3) * 24.0 + _rng.randf_range(-10.0, 10.0)
		var right_width := 162.0 + float((index + 1) % 3) * 26.0 + _rng.randf_range(-10.0, 10.0)
		var y_jitter := _rng.randf_range(-60.0, 60.0)
		_draw_far_mass(1.0, y + y_jitter, height, left_width, index)
		_draw_far_mass(-1.0, y + y_jitter + (120.0 if index % 2 == 0 else -80.0), height, right_width, index + 1)
		index += 1
		y += 1580.0


func _draw_far_mass(side: float, top_y: float, height: float, width: float, index: int) -> void:
	var edge_x: float = 0.0 if side > 0.0 else world_width
	var inner: float = width
	var step: float = 18.0 if index % 2 == 0 else -12.0
	var points := PackedVector2Array([
		Vector2(edge_x - side * 86.0, top_y),
		Vector2(edge_x + side * inner, top_y),
		Vector2(edge_x + side * (inner + 20.0), top_y + height * 0.09),
		Vector2(edge_x + side * (inner + 20.0), top_y + height * 0.30),
		Vector2(edge_x + side * (inner + step), top_y + height * 0.36),
		Vector2(edge_x + side * (inner + step), top_y + height * 0.68),
		Vector2(edge_x + side * (inner + 10.0), top_y + height * 0.76),
		Vector2(edge_x + side * (inner + 10.0), top_y + height),
		Vector2(edge_x - side * 86.0, top_y + height),
	])
	var fill: Color = _far_mass_color(index)
	draw_colored_polygon(points, fill)

	# One recessed vertical seam on selected modules. The silhouette, not an
	# outline, does most of the work.
	if index % 2 == 0:
		var seam_x: float = edge_x + side * (inner - 14.0)
		draw_line(
			Vector2(seam_x, top_y + height * 0.16),
			Vector2(seam_x, top_y + height * 0.80),
			Color(0.016, 0.044, 0.067, 0.34),
			2.0,
			true
		)


# Mid-distance structures use a repeated upright-and-buttress module. The same
# proportions recur on both sides, while module timing and size vary slightly.
func _draw_mid_architecture() -> void:
	var y: float = section_top_y + 120.0
	var index := 0
	while y < section_bottom_y + 1100.0:
		_draw_support_module(1.0, y, index)
		# Deliberately omit some opposing modules so the environment is composed,
		# not mirrored like a corridor. The fixed cadence still unifies the kit.
		if index % 4 != 1 or _rng.randf() < 0.12:
			_draw_support_module(-1.0, y + (180.0 if index % 2 == 0 else -110.0), index + 2)
		index += 1
		y += 1260.0


func _draw_support_module(side: float, top_y: float, index: int) -> void:
	var edge_x: float = 0.0 if side > 0.0 else world_width
	var height: float = 1030.0 + float(index % 3) * 60.0 + _rng.randf_range(-22.0, 22.0)
	var width: float = 136.0 + float(index % 3) * 15.0 + _rng.randf_range(-8.0, 8.0)
	var inset: float = 20.0 if index % 2 == 0 else -10.0
	var silhouette := PackedVector2Array([
		Vector2(edge_x - side * 28.0, top_y),
		Vector2(edge_x + side * (width - 25.0), top_y),
		Vector2(edge_x + side * width, top_y + 90.0),
		Vector2(edge_x + side * width, top_y + height * 0.34),
		Vector2(edge_x + side * (width + 48.0), top_y + height * 0.43),
		Vector2(edge_x + side * (width + 48.0), top_y + height * 0.51),
		Vector2(edge_x + side * (width - 6.0), top_y + height * 0.57),
		Vector2(edge_x + side * (width - 6.0), top_y + height),
		Vector2(edge_x - side * 28.0, top_y + height),
	])
	draw_colored_polygon(silhouette, _mid_mass_color())

	# A quiet edge reveal separates the mass from the game background, while
	# the broad fill still carries most of the structure's visual weight.
	var inner_edge_x: float = edge_x + side * (width - 2.0)
	draw_line(
		Vector2(inner_edge_x, top_y + height * 0.10),
		Vector2(inner_edge_x, top_y + height * 0.78),
		EDGE_REVEAL,
		2.0,
		true
	)

	# A single dark inset makes the upright feel thick and constructed.
	var inset_x: float = edge_x + side * (width - 27.0)
	draw_line(
		Vector2(inset_x, top_y + 100.0),
		Vector2(inset_x, top_y + height - 100.0),
		MID_SHADOW,
		7.0,
		true
	)

	# Recurring horizontal joints are sparse and low-contrast.
	if index % 3 != 1:
		var seam_y: float = top_y + height * (0.35 if index % 2 == 0 else 0.61)
		var seam_color: Color = SEAM_CYAN if index % 4 == 0 else SEAM_VIOLET
		draw_line(
			Vector2(edge_x + side * 18.0, seam_y),
			Vector2(edge_x + side * (width - 16.0 + inset), seam_y),
			seam_color,
			2.0,
			true
		)

	# Most modules stay unlit. Every fifth module gets a short HDR edge accent,
	# enough to react to the game's glow pass without tracing every edge.
	var accent_y: float = top_y + height * (0.13 if index % 5 == 0 else 0.64)
	if index % 5 == 0:
		draw_line(
			Vector2(inner_edge_x, accent_y),
			Vector2(inner_edge_x, accent_y + height * 0.105),
			ACCENT_CYAN,
			2.0,
			true
		)
	elif index % 7 == 0:
		draw_line(
			Vector2(inner_edge_x, accent_y),
			Vector2(inner_edge_x, accent_y + height * 0.07),
			ACCENT_VIOLET,
			2.0,
			true
		)


# The closest depth is intentionally quiet: only small interrupted edge rails,
# never filled geometric clusters or bright strokes through the play lane.
func _draw_near_frames() -> void:
	var y: float = section_top_y + 400.0
	var index := 0
	while y < section_bottom_y:
		var length: float = (430.0 if index % 2 == 0 else 280.0) + _rng.randf_range(-45.0, 45.0)
		var left_start := Vector2(14.0, y)
		var right_start := Vector2(world_width - 14.0, y + 360.0)
		if index % 2 == 0:
			draw_line(left_start, left_start + Vector2(0.0, length), NEAR_SEAM, 2.0, true)
		else:
			draw_line(right_start, right_start + Vector2(0.0, -length), NEAR_SEAM, 2.0, true)
		y += 2140.0
		index += 1


# Resonance Gate: one deliberately composed architectural object. The dark mass
# and its aperture define the shape; only a few short seams carry color.
func _draw_resonance_gate() -> void:
	var cy: float = lerpf(section_top_y, section_bottom_y, 0.51)
	var cx: float = world_width * 0.5
	var outer := PackedVector2Array([
		Vector2(cx - 245.0, cy + 385.0),
		Vector2(cx - 245.0, cy - 130.0),
		Vector2(cx - 205.0, cy - 285.0),
		Vector2(cx - 128.0, cy - 390.0),
		Vector2(cx + 128.0, cy - 390.0),
		Vector2(cx + 205.0, cy - 285.0),
		Vector2(cx + 245.0, cy - 130.0),
		Vector2(cx + 245.0, cy + 385.0),
		Vector2(cx + 178.0, cy + 435.0),
		Vector2(cx - 178.0, cy + 435.0),
	])
	draw_colored_polygon(outer, Color(0.008, 0.019, 0.037, 0.99))

	# The aperture is almost background-black, so the gate reads as thick
	# architecture surrounding an opening rather than an outlined emblem.
	var aperture := PackedVector2Array([
		Vector2(cx - 153.0, cy + 320.0),
		Vector2(cx - 153.0, cy - 118.0),
		Vector2(cx - 124.0, cy - 240.0),
		Vector2(cx - 75.0, cy - 304.0),
		Vector2(cx + 75.0, cy - 304.0),
		Vector2(cx + 124.0, cy - 240.0),
		Vector2(cx + 153.0, cy - 118.0),
		Vector2(cx + 153.0, cy + 320.0),
		Vector2(cx, cy + 372.0),
	])
	draw_colored_polygon(aperture, Color(0.003, 0.007, 0.017, 1.0))

	# Partial contour reveals clarify the monument's shape. Only a few short
	# HDR segments glow under the same WorldEnvironment as the normal game.
	draw_line(Vector2(cx - 245.0, cy + 165.0), Vector2(cx - 245.0, cy - 118.0), ACCENT_CYAN, 2.5, true)
	draw_line(Vector2(cx + 245.0, cy - 118.0), Vector2(cx + 245.0, cy + 165.0), ACCENT_CYAN, 2.5, true)
	draw_line(Vector2(cx - 128.0, cy - 390.0), Vector2(cx - 76.0, cy - 320.0), ACCENT_VIOLET, 2.0, true)
	draw_line(Vector2(cx + 128.0, cy - 390.0), Vector2(cx + 76.0, cy - 320.0), ACCENT_VIOLET, 2.0, true)

	# Inner reveals and only two small lit joints. No circular halo, floating
	# shards, or duplicated gate geometry on the parallax layers.
	draw_line(
		Vector2(cx - 155.0, cy - 118.0),
		Vector2(cx - 155.0, cy + 280.0),
		Color(0.020, 0.24, 0.31, 0.35),
		2.0,
		true
	)
	draw_line(
		Vector2(cx + 155.0, cy - 118.0),
		Vector2(cx + 155.0, cy + 280.0),
		Color(0.020, 0.24, 0.31, 0.35),
		2.0,
		true
	)
	draw_line(
		Vector2(cx - 122.0, cy - 239.0),
		Vector2(cx - 75.0, cy - 303.0),
		Color(0.025, 0.31, 0.39, 0.43),
		2.0,
		true
	)
	draw_line(
		Vector2(cx + 122.0, cy - 239.0),
		Vector2(cx + 75.0, cy - 303.0),
		Color(0.025, 0.31, 0.39, 0.43),
		2.0,
		true
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(cx - 116.0, cy - 428.0),
		"RESONANCE GATE",
		HORIZONTAL_ALIGNMENT_LEFT,
		232.0,
		13,
		Color(0.19, 0.42, 0.53, 0.58)
	)


# Archive Fragment is embedded in a side structure. Its frame and recessed
# housing make it a discoverable object without floating rings or a bright halo.
func _draw_archive_recess() -> void:
	var center := Vector2(world_width - 118.0, lerpf(section_top_y, section_bottom_y, 0.31))
	var housing := Rect2(center - Vector2(48.0, 76.0), Vector2(96.0, 152.0))
	draw_rect(housing, Color(0.006, 0.015, 0.030, 0.98), true)
	draw_rect(housing, Color(0.018, 0.050, 0.071, 0.72), false, 2.0)
	draw_rect(
		Rect2(center - Vector2(31.0, 57.0), Vector2(62.0, 114.0)),
		Color(0.003, 0.008, 0.018, 1.0),
		true
	)
	draw_line(
		center + Vector2(-21.0, -38.0),
		center + Vector2(0.0, -51.0),
		Color(0.025, 0.22, 0.28, 0.48),
		2.0,
		true
	)
	draw_line(
		center + Vector2(0.0, -51.0),
		center + Vector2(21.0, -38.0),
		Color(0.025, 0.22, 0.28, 0.48),
		2.0,
		true
	)
	draw_line(
		center + Vector2(-17.0, 33.0),
		center + Vector2(17.0, 33.0),
		Color(0.025, 0.22, 0.28, 0.35),
		1.5,
		true
	)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-51.0, 98.0),
		"ARCHIVE",
		HORIZONTAL_ALIGNMENT_LEFT,
		102.0,
		10,
		Color(0.16, 0.35, 0.45, 0.55)
	)
