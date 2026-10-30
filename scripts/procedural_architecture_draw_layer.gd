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

enum LifeTreatment {
	BASELINE,
	SUBTLE_CONTOURS, # Preserve the first life experiment's mapping.
	CONTOURS_AND_WINDOWS, # Preserve the first life experiment's mapping.
	STRUCTURED_CONTOURS,
	WINDOW_STATES,
	STRUCTURED_COMBINED,
	PANEL_CLUSTERS,
	COMPACT_PANEL_STATES,
	COMPACT_PANEL_FLICKER,
}

enum MidDetailTreatment {
	BASELINE,
	STEPPED_INSETS,
	INSETS_AND_MECHANICAL_RECESSES,
}

@export var layer_type: LayerType = LayerType.FAR_SILHOUETTES
@export var palette_variant: PaletteVariant = PaletteVariant.CURRENT_NAVY
@export var life_treatment: LifeTreatment = LifeTreatment.BASELINE
@export var mid_detail_treatment: MidDetailTreatment = MidDetailTreatment.BASELINE
@export var environment_seed: int = 7319
@export var world_width: float = 720.0
@export var section_top_y: float = -10400.0
@export var section_bottom_y: float = 1600.0

var _rng := RandomNumberGenerator.new()
var _flicker_clock: float = 0.0

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

# Static far-layer life treatments. These remain below HDR/emissive intensity:
# they add construction cues without turning the distant layer into a neon outline.
const FAR_DETAIL_A1 := {
	"contour": Color(0.052, 0.040, 0.082, 0.38),
	"window": Color(0.052, 0.038, 0.088, 0.46),
	"window_edge": Color(0.095, 0.073, 0.145, 0.36),
}
const FAR_DETAIL_A2 := {
	"contour": Color(0.030, 0.071, 0.105, 0.36),
	"window": Color(0.025, 0.070, 0.110, 0.42),
	"window_edge": Color(0.050, 0.105, 0.150, 0.32),
}

# Second-pass details have architectural structure rather than free-floating strokes.
# The A1 treatment lifts the details enough to remain legible on dark far masses;
# A2 uses cool blue details that sit clearly below the middle layer's HDR accents.
const FAR_STRUCTURED_A1 := {
	"panel_fill": Color(0.003, 0.004, 0.012, 0.82),
	"panel_edge": Color(0.070, 0.052, 0.112, 0.54),
	"panel_rail": Color(0.105, 0.078, 0.166, 0.42),
	"window_frame": Color(0.092, 0.066, 0.138, 0.78),
	"window_dark": Color(0.003, 0.004, 0.011, 0.98),
	"window_lit": Color(0.085, 0.048, 0.142, 0.84),
	"window_neon": Color(0.36, 0.18, 0.54, 0.76),
	"window_halo": Color(0.26, 0.12, 0.40, 0.11),
}
const FAR_STRUCTURED_A2 := {
	# Recesses stay close to the far fill instead of becoming near-black cutouts.
	# The slight lift keeps the blue-purple mass visually continuous with the dark-blue middle.
	"panel_fill": Color(0.009, 0.026, 0.052, 0.68),
	"panel_edge": Color(0.055, 0.095, 0.145, 0.40),
	"panel_rail": Color(0.070, 0.120, 0.180, 0.32),
	"window_frame": Color(0.045, 0.092, 0.132, 0.70),
	"window_dark": Color(0.005, 0.014, 0.028, 0.90),
	"window_lit": Color(0.024, 0.090, 0.142, 0.82),
	"window_neon": Color(0.13, 0.37, 0.55, 0.74),
	"window_halo": Color(0.08, 0.24, 0.38, 0.10),
}


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


func _process(delta: float) -> void:
	# Only the compact panel-flicker treatment animates. All other treatments stay static.
	if layer_type == LayerType.FAR_SILHOUETTES and life_treatment == LifeTreatment.COMPACT_PANEL_FLICKER:
		_flicker_clock += delta
		queue_redraw()


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
			return Color(0.004, 0.016, 0.065, 0.96)
		PaletteVariant.CURRENT_NAVY_E_BRIGHTER:
			# New follow-up C: brighter blue middle fill, still darker overall than the void.
			# Its blue channel rises farther above the backdrop while red/green remain lower.
			return Color(0.004, 0.018, 0.075, 0.96)
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

	match life_treatment:
		LifeTreatment.SUBTLE_CONTOURS, LifeTreatment.CONTOURS_AND_WINDOWS:
			_draw_far_life_details(side, top_y, height, width, index)
		LifeTreatment.STRUCTURED_CONTOURS:
			_draw_structured_far_contours(side, top_y, height, width, index)
		LifeTreatment.WINDOW_STATES:
			_draw_far_window_states(side, top_y, height, width, index)
		LifeTreatment.STRUCTURED_COMBINED:
			_draw_structured_far_contours(side, top_y, height, width, index)
			_draw_far_window_states(side, top_y, height, width, index)
		LifeTreatment.PANEL_CLUSTERS:
			_draw_far_panel_clusters(side, top_y, height, width, index)
		LifeTreatment.COMPACT_PANEL_STATES:
			_draw_far_compact_panel_clusters(side, top_y, height, width, index, false)
		LifeTreatment.COMPACT_PANEL_FLICKER:
			_draw_far_compact_panel_clusters(side, top_y, height, width, index, true)


func _far_life_palette() -> Dictionary:
	match palette_variant:
		PaletteVariant.CURRENT_NAVY_MID_CONTRAST, PaletteVariant.CURRENT_NAVY_A1_DARK_TINT_FAR, PaletteVariant.CURRENT_NAVY_A1_BRIGHT_TINT_FAR:
			return FAR_DETAIL_A1
		_:
			return FAR_DETAIL_A2


func _draw_far_life_details(side: float, top_y: float, height: float, width: float, index: int) -> void:
	var edge_x: float = 0.0 if side > 0.0 else world_width
	var detail_palette := _far_life_palette()
	var contour_color: Color = detail_palette["contour"]

	# A few interrupted inset contours and joints suggest constructed panels.
	# They are deliberately sparse, low contrast, and non-emissive.
	var vertical_x: float = edge_x + side * (width - 42.0)
	if index % 2 == 0:
		draw_line(
			Vector2(vertical_x, top_y + height * 0.18),
			Vector2(vertical_x, top_y + height * 0.29),
			contour_color,
			1.8,
			true
		)
	if index % 3 != 1:
		var joint_y: float = top_y + height * (0.43 if index % 2 == 0 else 0.63)
		draw_line(
			Vector2(edge_x + side * (width - 76.0), joint_y),
			Vector2(edge_x + side * (width - 18.0), joint_y),
			contour_color,
			1.5,
			true
		)

	if life_treatment != LifeTreatment.CONTOURS_AND_WINDOWS:
		return

	# Windows appear only on selected far modules. They are small, dim, and
	# theme-tinted; they do not use HDR values or contribute to glow/bloom.
	if index % 3 != 1:
		var window_x: float = edge_x + side * (width - 70.0) - (18.0 if side < 0.0 else 0.0)
		var window_rect := Rect2(
			Vector2(window_x, top_y + height * 0.47),
			Vector2(18.0, 46.0)
		)
		draw_rect(window_rect, detail_palette["window"], true)
		draw_rect(window_rect, detail_palette["window_edge"], false, 1.0)

	# A smaller secondary opening is rarer, keeping the facade from becoming a grid.
	if index % 5 == 0:
		var second_window_x: float = edge_x + side * (width - 112.0) - (12.0 if side < 0.0 else 0.0)
		var second_window := Rect2(
			Vector2(second_window_x, top_y + height * 0.66),
			Vector2(12.0, 32.0)
		)
		draw_rect(second_window, detail_palette["window"], true)
		draw_rect(second_window, detail_palette["window_edge"], false, 1.0)


func _structured_far_palette() -> Dictionary:
	match palette_variant:
		PaletteVariant.CURRENT_NAVY_MID_CONTRAST, PaletteVariant.CURRENT_NAVY_A1_DARK_TINT_FAR, PaletteVariant.CURRENT_NAVY_A1_BRIGHT_TINT_FAR:
			return FAR_STRUCTURED_A1
		_:
			return FAR_STRUCTURED_A2


func _far_panel_left_x(side: float, edge_x: float, width: float, panel_width: float = 46.0) -> float:
	var panel_anchor: float = edge_x + side * (width - 78.0)
	return panel_anchor if side > 0.0 else panel_anchor - panel_width


func _draw_structured_far_contours(side: float, top_y: float, height: float, width: float, index: int) -> void:
	# Repeated recessed bays define a construction system. Their vertical rails,
	# caps, and inset surfaces share a consistent layout instead of random strokes.
	if index % 3 == 1:
		return

	var edge_x: float = 0.0 if side > 0.0 else world_width
	var detail: Dictionary = _structured_far_palette()
	var panel_width: float = 46.0
	var panel_x: float = _far_panel_left_x(side, edge_x, width, panel_width)
	var panel_y: float = top_y + height * (0.20 if index % 2 == 0 else 0.23)
	var panel_height: float = height * (0.49 if index % 2 == 0 else 0.45)
	var panel := Rect2(Vector2(panel_x, panel_y), Vector2(panel_width, panel_height))

	draw_rect(panel, detail["panel_fill"], true)
	draw_rect(panel, detail["panel_edge"], false, 1.4)

	# A second inner rail reads as a recessed structural lip, not an outline.
	var rail_x: float = panel_x + (5.0 if side > 0.0 else panel_width - 5.0)
	draw_line(
		Vector2(rail_x, panel_y + 12.0),
		Vector2(rail_x, panel_y + panel_height - 12.0),
		detail["panel_rail"],
		1.6,
		true
	)

	# Panel joints only occur within the framed bay and follow its construction.
	if index % 2 == 0:
		var joint_y: float = panel_y + panel_height * 0.66
		draw_line(
			Vector2(panel_x + 4.0, joint_y),
			Vector2(panel_x + panel_width - 4.0, joint_y),
			detail["panel_edge"],
			1.2,
			true
		)


func _draw_far_window_states(side: float, top_y: float, height: float, width: float, index: int) -> void:
	# Sparse paired apertures sit in a stable facade bay. Most remain dark;
	# occasional subdued interiors and rarer low-strength neon imply distant activity.
	if index % 3 == 1:
		return

	var edge_x: float = 0.0 if side > 0.0 else world_width
	var detail: Dictionary = _structured_far_palette()
	var panel_x: float = _far_panel_left_x(side, edge_x, width)
	var window_width: float = 16.0
	var window_height: float = 58.0
	var window_gap: float = 7.0
	var group_width: float = window_width * 2.0 + window_gap
	var group_x: float = panel_x + (46.0 - group_width) * 0.5

	# Two aligned openings form a small architectural group. A third, lower
	# opening is used on fewer modules to avoid an uninterrupted repeated grid.
	var window_rows: Array[float] = [0.36, 0.49]
	if index % 5 == 0:
		window_rows.append(0.64)

	for row_index in range(window_rows.size()):
		var y: float = top_y + height * window_rows[row_index]
		for column_index in range(2):
			var x: float = group_x + float(column_index) * (window_width + window_gap)
			var window_rect := Rect2(Vector2(x, y), Vector2(window_width, window_height))
			var state: int = posmod(index * 2 + row_index * 3 + column_index, 7)
			_draw_far_window(window_rect, state, detail)


func _draw_far_window(window_rect: Rect2, state: int, detail: Dictionary) -> void:
	# State mapping: 4/7 dormant, 2/7 softly lit, 1/7 low-strength neon.
	# Draw the low-alpha halo first so it remains visible outside the aperture.
	if state == 0:
		var halo := Rect2(window_rect.position - Vector2(2.0, 2.0), window_rect.size + Vector2(4.0, 4.0))
		draw_rect(halo, detail["window_halo"], true)

	draw_rect(window_rect, detail["window_dark"], true)
	draw_rect(window_rect, detail["window_frame"], false, 1.0)
	var inner := Rect2(
		window_rect.position + Vector2(3.0, 4.0),
		window_rect.size - Vector2(6.0, 8.0)
	)
	if state == 0:
		# Neon remains well below the strength of the middle layer's main accents.
		draw_rect(inner, detail["window_neon"], true)
		draw_rect(
			Rect2(inner.position + Vector2(3.0, 2.0), Vector2(2.0, inner.size.y - 4.0)),
			detail["window_neon"],
			true
		)
	elif state == 2 or state == 5:
		draw_rect(inner, detail["window_lit"], true)
		# A single interior division suggests a lit recess, not a glowing sign.
		draw_line(
			inner.position + Vector2(2.0, inner.size.y * 0.58),
			Vector2(inner.end.x - 2.0, inner.position.y + inner.size.y * 0.58),
			detail["window_frame"],
			1.0,
			true
		)



# Organized panel clusters use a small, deliberate composition library.
# Rectangles remain the dominant language; variation comes from grouping,
# scale, spacing, and placement rather than arbitrary decorative geometry.
func _draw_far_panel_clusters(
	side: float,
	top_y: float,
	height: float,
	width: float,
	index: int
) -> void:
	# Not every far module receives a detail cluster. Empty modules preserve scale
	# and make the detailed modules feel like intentional structural states.
	if index % 3 == 1:
		return

	var edge_x: float = 0.0 if side > 0.0 else world_width
	var detail: Dictionary = _structured_far_palette()
	var side_index: int = 1 if side < 0.0 else 0
	var pattern: int = posmod(index * 3 + side_index, 5)
	var cluster_width: float = 88.0
	# The far layer is vertically scaled to 0.18, so local panel heights are
	# deliberately taller to preserve readable square / rectangle proportions on screen.
	var cluster_height: float = 370.0
	var cluster_x: float = _far_panel_left_x(side, edge_x, width, cluster_width)
	var cluster_y: float = top_y + height * (0.28 + float(posmod(index + side_index, 3)) * 0.035)

	# Two-thirds of clusters sit in a shallow recess. The remaining third are
	# integrated directly into the silhouette with no large backing panel.
	var has_recess: bool = posmod(index + side_index, 3) != 1
	if has_recess:
		var recess_width: float = 100.0 if pattern % 2 == 0 else 96.0
		var recess_height: float = cluster_height + 30.0
		var recess_x: float = cluster_x - (recess_width - cluster_width) * 0.5
		var recess_y: float = cluster_y - 15.0
		var recess := Rect2(Vector2(recess_x, recess_y), Vector2(recess_width, recess_height))
		draw_rect(recess, detail["panel_fill"], true)
		draw_rect(recess, detail["panel_edge"], false, 1.35)

		# A partial inner rail creates depth without boxing every cluster in a bright frame.
		var rail_x: float = recess_x + (5.0 if side > 0.0 else recess_width - 5.0)
		draw_line(
			Vector2(rail_x, recess_y + 13.0),
			Vector2(rail_x, recess_y + recess_height - 13.0),
			detail["panel_rail"],
			1.45,
			true
		)
		if pattern % 2 == 0:
			draw_line(
				Vector2(recess_x + 7.0, recess_y + recess_height * 0.73),
				Vector2(recess_x + recess_width - 7.0, recess_y + recess_height * 0.73),
				detail["panel_edge"],
				1.0,
				true
			)

	var elements: Array[Vector4] = []
	match pattern:
		0:
			# Mixed three-part cluster: screen-square panel, broad horizontal panel, tall element below.
			elements.append(Vector4(4.0, 0.10, 31.0, 150.0))
			elements.append(Vector4(42.0, 0.15, 39.0, 65.0))
			elements.append(Vector4(23.0, 0.55, 19.0, 150.0))
		1:
			# Two substantial, separated elements with contrasting proportions.
			elements.append(Vector4(3.0, 0.17, 61.0, 70.0))
			elements.append(Vector4(28.0, 0.56, 26.0, 160.0))
		2:
			# Four-piece cluster: upper pair and an offset lower pair.
			elements.append(Vector4(5.0, 0.07, 22.0, 112.0))
			elements.append(Vector4(37.0, 0.08, 43.0, 60.0))
			elements.append(Vector4(5.0, 0.56, 35.0, 70.0))
			elements.append(Vector4(49.0, 0.53, 30.0, 140.0))
		3:
			# Substantial charged slits arranged around a wider central panel.
			elements.append(Vector4(7.0, 0.08, 15.0, 190.0))
			elements.append(Vector4(35.0, 0.22, 35.0, 60.0))
			elements.append(Vector4(58.0, 0.45, 16.0, 170.0))
		_:
			# Sparse asymmetric trio: one broad upper panel and two separated square-like panels.
			elements.append(Vector4(27.0, 0.08, 51.0, 68.0))
			elements.append(Vector4(3.0, 0.47, 31.0, 142.0))
			elements.append(Vector4(47.0, 0.55, 31.0, 142.0))

	for element_index in range(elements.size()):
		var spec: Vector4 = elements[element_index]
		var aperture_rect := Rect2(
			Vector2(cluster_x + spec.x, cluster_y + cluster_height * spec.y),
			Vector2(spec.z, spec.w)
		)
		var state_roll: int = posmod(index * 3 + element_index * 5 + pattern * 2 + side_index, 10)
		var state: int = 0
		if state_roll >= 8:
			state = 2 # energized
		elif state_roll >= 5:
			state = 1 # active
		_draw_panel_aperture(aperture_rect, state, detail)


func _draw_panel_aperture(
	aperture_rect: Rect2,
	state: int,
	detail: Dictionary
) -> void:
	# State 0 = dormant, 1 = active, 2 = energized.
	# The glow reuses the visible treatment from the successful static window test.
	var halo_color: Color = detail["window_halo"]
	if state == 2:
		var halo := Rect2(
			aperture_rect.position - Vector2(3.5, 3.5),
			aperture_rect.size + Vector2(7.0, 7.0)
		)
		draw_rect(halo, halo_color, true)

	draw_rect(aperture_rect, detail["window_dark"], true)
	draw_rect(aperture_rect, detail["window_frame"], false, 1.0)

	var inner := Rect2(
		aperture_rect.position + Vector2(2.5, 2.5),
		aperture_rect.size - Vector2(5.0, 5.0)
	)
	if inner.size.x <= 2.0 or inner.size.y <= 2.0:
		return

	if state == 0:
		return

	var fill_color: Color = detail["window_lit"] if state == 1 else detail["window_neon"]
	draw_rect(inner, fill_color, true)

	if state == 2:
		# A brighter inset rail keeps energized apertures readable at small display size.
		var rail_color: Color = detail["window_neon"]

		if inner.size.x >= inner.size.y:
			draw_rect(
				Rect2(inner.position + Vector2(2.0, 2.0), Vector2(2.5, inner.size.y - 4.0)),
				rail_color,
				true
			)
		else:
			draw_rect(
				Rect2(inner.position + Vector2(2.0, 2.0), Vector2(inner.size.x - 4.0, 2.5)),
				rail_color,
				true
			)




# Compact panel pass: retain the taller recessed bays, but make their contents
# smaller and more selective. All geometry is positioned inside the actual far mass.
# Recess and panel proportions vary by module while retaining the rectangular grammar.
func _draw_far_compact_panel_clusters(
	side: float,
	top_y: float,
	height: float,
	width: float,
	index: int,
	flicker_enabled: bool
) -> void:
	if index % 3 == 1:
		return

	var edge_x: float = 0.0 if side > 0.0 else world_width
	var detail: Dictionary = _structured_far_palette()
	var side_index: int = 1 if side < 0.0 else 0
	var pattern: int = posmod(index * 3 + side_index, 5)

	# Different modules receive visibly different bay dimensions. The dimensions
	# are local to the far layer and retain readable proportions after parallax.
	var width_variant: int = posmod(index * 5 + side_index * 3, 4)
	var height_variant: int = posmod(index * 7 + side_index * 2, 4)
	var cluster_width: float = 94.0 + float(width_variant) * 7.0
	var cluster_height: float = 420.0 + float(height_variant) * 76.0
	var cluster_y: float = top_y + height * (
		0.23 + float(posmod(index + side_index, 3)) * 0.027
	)

	var has_recess: bool = posmod(index + side_index, 3) != 1
	var recess_width: float = cluster_width + 12.0 + float(posmod(index * 3 + side_index, 3)) * 5.0
	var recess_top_pad: float = 22.0 + float(posmod(index + 1, 4)) * 7.0
	var recess_bottom_pad: float = 30.0 + float(posmod(index * 2 + 1, 4)) * 9.0
	var group_width: float = recess_width if has_recess else cluster_width + 4.0
	var edge_margin: float = 13.0

	# The solid far mass occupies the strip between the screen edge and its
	# inward silhouette boundary. Anchor the entire group from that boundary:
	# left-side details stop before the right edge of the mass, and right-side
	# details stop after its left edge. This also protects isolated apertures.
	var group_left: float
	if side > 0.0:
		group_left = edge_x + width - group_width - edge_margin
	else:
		group_left = edge_x - width + edge_margin
	var cluster_x: float = group_left + (group_width - cluster_width) * 0.5

	if has_recess:
		var recess_y: float = cluster_y - recess_top_pad
		var recess_height: float = cluster_height + recess_top_pad + recess_bottom_pad
		var recess := Rect2(Vector2(group_left, recess_y), Vector2(recess_width, recess_height))
		draw_rect(recess, detail["panel_fill"], true)
		draw_rect(recess, detail["panel_edge"], false, 1.25)

		# A single inset rail and an occasional lower joint give the recess depth
		# without creating another bright frame around every aperture.
		var rail_x: float = group_left + (5.0 if side > 0.0 else recess_width - 5.0)
		draw_line(
			Vector2(rail_x, recess_y + 15.0),
			Vector2(rail_x, recess_y + recess_height - 15.0),
			detail["panel_rail"],
			1.35,
			true
		)
		if posmod(index + pattern, 2) == 0:
			var joint_y: float = recess_y + recess_height * (
				0.68 + float(posmod(index, 3)) * 0.055
			)
			draw_line(
				Vector2(group_left + 8.0, joint_y),
				Vector2(group_left + recess_width - 8.0, joint_y),
				detail["panel_edge"],
				1.0,
				true
			)

	# Five deliberate compositions keep the forms organized. The individual
	# dimensions below are varied again per module so repeated patterns do not
	# read as identical stamped layouts.
	var elements: Array[Vector4] = []
	match pattern:
		0:
			elements.append(Vector4(4.0, 0.08, 27.0, 132.0))
			elements.append(Vector4(49.0, 0.12, 36.0, 78.0))
			elements.append(Vector4(25.0, 0.58, 15.0, 150.0))
		1:
			elements.append(Vector4(4.0, 0.12, 45.0, 78.0))
			elements.append(Vector4(65.0, 0.56, 27.0, 132.0))
		2:
			elements.append(Vector4(3.0, 0.05, 14.0, 145.0))
			elements.append(Vector4(27.0, 0.07, 27.0, 132.0))
			elements.append(Vector4(64.0, 0.10, 32.0, 70.0))
			elements.append(Vector4(17.0, 0.60, 40.0, 70.0))
		3:
			elements.append(Vector4(5.0, 0.07, 12.0, 175.0))
			elements.append(Vector4(34.0, 0.25, 13.0, 142.0))
			elements.append(Vector4(65.0, 0.50, 12.0, 158.0))
			elements.append(Vector4(73.0, 0.13, 24.0, 72.0))
		_:
			elements.append(Vector4(29.0, 0.08, 43.0, 76.0))
			elements.append(Vector4(3.0, 0.56, 27.0, 132.0))
			elements.append(Vector4(74.0, 0.62, 27.0, 132.0))

	var x_scale: float = cluster_width / 104.0
	var y_scale: float = cluster_height / 540.0
	for element_index in range(elements.size()):
		var spec: Vector4 = elements[element_index]
		var size_x_factor: float = 0.88 + float(posmod(index * 3 + element_index * 5, 4)) * 0.08
		var size_y_factor: float = 0.88 + float(posmod(index * 5 + element_index * 3, 4)) * 0.08
		var aperture_width: float = spec.z * x_scale * size_x_factor
		var aperture_height: float = spec.w * y_scale * size_y_factor
		var x_jitter: float = (float(posmod(index * 11 + element_index * 7, 5)) - 2.0) * 1.8
		var aperture_x: float = clampf(
			spec.x * x_scale + x_jitter,
			3.0,
			cluster_width - aperture_width - 3.0
		)
		var y_jitter: float = (float(posmod(index * 7 + element_index * 3, 3)) - 1.0) * 0.018
		var aperture_y_fraction: float = clampf(spec.y + y_jitter, 0.025, 0.68)
		var aperture_y: float = cluster_y + cluster_height * aperture_y_fraction
		aperture_height = minf(aperture_height, cluster_y + cluster_height - aperture_y - 9.0)
		var aperture_rect := Rect2(
			Vector2(cluster_x + aperture_x, aperture_y),
			Vector2(aperture_width, aperture_height)
		)

		# Most compact elements can be illuminated; broader panels are less likely.
		# The distribution deliberately preserves dormant, mid, and strong-neon states.
		var state_roll: int = posmod(index * 3 + element_index * 5 + pattern * 2 + side_index, 12)
		var state: int = 0
		var is_broad_panel: bool = spec.z >= 40.0 and spec.w <= 90.0
		if is_broad_panel:
			if state_roll >= 10:
				state = 2
			elif state_roll >= 7:
				state = 1
		else:
			if state_roll >= 9:
				state = 2
			elif state_roll >= 5:
				state = 1
		_draw_compact_panel_light(aperture_rect, state, flicker_enabled, index, element_index, detail)


func _draw_compact_panel_light(
	aperture_rect: Rect2,
	state: int,
	flicker_enabled: bool,
	module_index: int,
	element_index: int,
	detail: Dictionary
) -> void:
	# The aperture frame is always present; only the inset light changes state.
	draw_rect(aperture_rect, detail["window_dark"], true)
	draw_rect(aperture_rect, detail["window_frame"], false, 1.0)

	if state == 0:
		return

	var inner := Rect2(
		aperture_rect.position + Vector2(2.5, 12.0),
		aperture_rect.size - Vector2(5.0, 24.0)
	)
	if inner.size.x <= 2.0 or inner.size.y <= 3.0:
		return

	var intensity: float = 1.0
	if flicker_enabled:
		var switch_source: bool = posmod(module_index * 11 + element_index * 7, 4) == 0
		if switch_source:
			# A subset of sources behave like small powered apertures switching
			# between on and nearly-off states. Individual periods and phases differ.
			var cycle_duration: float = 2.45 + float(posmod(module_index + element_index, 4)) * 0.58
			var switch_phase: float = float(posmod(module_index * 19 + element_index * 23, 17)) / 17.0
			var cycle_position: float = fposmod(_flicker_clock / cycle_duration + switch_phase, 1.0)
			var off_start: float = 0.70 + float(posmod(module_index * 3 + element_index, 3)) * 0.055
			var fade_end: float = minf(0.99, off_start + 0.045)
			var switch_level: float = 1.0
			if cycle_position >= off_start:
				switch_level = 1.0 - smoothstep(off_start, fade_end, cycle_position)
			elif cycle_position <= 0.045:
				switch_level = smoothstep(0.0, 0.045, cycle_position)
			intensity = 0.045 + switch_level * 0.955
		else:
			# The rest retain a gentler, irregular shimmer rather than blinking together.
			var shimmer_phase: float = float(module_index) * 0.93 + float(element_index) * 1.71
			var flicker_signal: float = (
				sin(_flicker_clock * 4.4 + shimmer_phase) * 0.52
				+ sin(_flicker_clock * 7.9 + shimmer_phase * 1.83) * 0.31
				+ sin(_flicker_clock * 12.7 + shimmer_phase * 2.41) * 0.17
			)
			intensity = 0.86 + flicker_signal * 0.22

	var fill_color: Color = detail["window_lit"] if state == 1 else detail["window_neon"]
	if state == 2:
		# Keep the rare energized state close to the successful window treatment.
		fill_color.a = minf(1.0, fill_color.a * 1.18)
	fill_color.a = fill_color.a * intensity

	if state == 2:
		var halo_color: Color = detail["window_halo"]
		var outer_halo_color: Color = halo_color
		outer_halo_color.a = outer_halo_color.a * 0.82 * intensity
		halo_color.a = minf(0.24, halo_color.a * 1.55 * intensity)
		# Y padding compensates for the far layer's compressed vertical scale.
		var outer_halo_rect := Rect2(
			inner.position - Vector2(7.0, 28.0),
			inner.size + Vector2(14.0, 56.0)
		)
		var halo_rect := Rect2(
			inner.position - Vector2(3.5, 14.0),
			inner.size + Vector2(7.0, 28.0)
		)
		draw_rect(outer_halo_rect, outer_halo_color, true)
		draw_rect(halo_rect, halo_color, true)

	draw_rect(inner, fill_color, true)

	if state == 2:
		var highlight_color: Color = detail["window_neon"]
		highlight_color.a = minf(1.0, highlight_color.a * 1.18 * intensity)
		if inner.size.x >= inner.size.y:
			draw_rect(
				Rect2(inner.position + Vector2(2.0, 2.0), Vector2(2.0, inner.size.y - 4.0)),
				highlight_color,
				true
			)
		else:
			draw_rect(
				Rect2(inner.position + Vector2(2.0, 2.0), Vector2(inner.size.x - 4.0, 2.0)),
				highlight_color,
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

	# The optional middle-detail study adds structural depth without duplicating
	# the far layer's illuminated aperture language.
	if mid_detail_treatment != MidDetailTreatment.BASELINE:
		_draw_mid_stepped_inset(side, top_y, height, width, index)
	if mid_detail_treatment == MidDetailTreatment.INSETS_AND_MECHANICAL_RECESSES:
		_draw_mid_mechanical_recesses(side, top_y, height, width, index)

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


# Middle-layer study B: recessed stepped plates. These are dark, non-emissive
# structural inserts embedded in the broad support mass, not illuminated windows.
func _draw_mid_stepped_inset(
	side: float,
	top_y: float,
	height: float,
	width: float,
	index: int
) -> void:
	# Anchor to the inward-facing edge so the plate remains inside either side mass.
	var plate_width: float = 38.0 + float(posmod(index, 3)) * 5.0
	var plate_height: float = height * (0.31 if index % 2 == 0 else 0.27)
	var plate_y: float = top_y + height * (0.22 if index % 2 == 0 else 0.27)
	var inner_edge_x: float = 0.0 if side > 0.0 else world_width
	var plate_x: float
	if side > 0.0:
		plate_x = inner_edge_x + width - 26.0 - plate_width
	else:
		plate_x = inner_edge_x - width + 26.0
	var plate := Rect2(Vector2(plate_x, plate_y), Vector2(plate_width, plate_height))

	# A shallow shadow pocket, stepped inner surface, and partial shoulder reveal
	# create parallax-readable depth without tracing the full rectangle brightly.
	draw_rect(plate, Color(0.0035, 0.009, 0.019, 0.74), true)
	draw_rect(plate, Color(0.038, 0.076, 0.112, 0.38), false, 1.4)

	var inner_plate := Rect2(
		plate.position + Vector2(4.0, 7.0),
		plate.size - Vector2(8.0, 14.0)
	)
	draw_rect(inner_plate, Color(0.012, 0.027, 0.047, 0.58), true)

	var shoulder_x: float = plate.position.x + (
		plate.size.x - 5.0 if side > 0.0 else 5.0
	)
	draw_line(
		Vector2(shoulder_x, plate.position.y + 12.0),
		Vector2(shoulder_x, plate.end.y - 12.0),
		Color(0.070, 0.125, 0.164, 0.32),
		1.3,
		true
	)

	# Two interrupted horizontal divisions imply a segmented load-bearing plate.
	for division in range(2):
		var division_y: float = plate.position.y + plate.size.y * (0.38 + float(division) * 0.29)
		var division_start_x: float = plate.position.x + 6.0
		var division_end_x: float = plate.end.x - 6.0
		if side > 0.0:
			division_end_x -= 7.0
		else:
			division_start_x += 7.0
		draw_line(
			Vector2(division_start_x, division_y),
			Vector2(division_end_x, division_y),
			Color(0.043, 0.078, 0.108, 0.30),
			1.0,
			true
		)

	# A short offset foot makes the housing feel stepped into the support itself.
	var foot_width: float = 16.0 + float(posmod(index, 2)) * 5.0
	var foot_x: float = plate.end.x - foot_width if side > 0.0 else plate.position.x - 2.0
	draw_rect(
		Rect2(
			Vector2(foot_x, plate.end.y - 28.0),
			Vector2(foot_width, 28.0)
		),
		Color(0.018, 0.039, 0.060, 0.52),
		true
	)


# Middle-layer study C adds a small number of recessed mechanical slots to B.
# The slots stay dark and subdued: no neon, moving light, or residential window rhythm.
func _draw_mid_mechanical_recesses(
	side: float,
	top_y: float,
	height: float,
	width: float,
	index: int
) -> void:
	if index % 3 == 1:
		return

	var slot_width: float = 24.0 + float(index % 2) * 4.0
	var slot_height: float = 54.0 + float(index % 3) * 8.0
	var edge_x: float = 0.0 if side > 0.0 else world_width
	var slot_anchor_x: float = edge_x + side * (width * 0.43)
	var slot_x: float = slot_anchor_x if side > 0.0 else slot_anchor_x - slot_width
	var slot_rows: Array[float] = [0.36, 0.66]
	if index % 2 == 0:
		slot_rows.reverse()

	for row_index in range(slot_rows.size()):
		var slot_y: float = top_y + height * slot_rows[row_index]
		var slot := Rect2(
			Vector2(slot_x, slot_y),
			Vector2(slot_width, slot_height)
		)
		draw_rect(slot, Color(0.0025, 0.007, 0.015, 0.82), true)
		draw_rect(slot, Color(0.032, 0.068, 0.096, 0.32), false, 1.1)

		# A short inner shelf gives the recess a physical lip, not a lit indicator.
		var shelf_y: float = slot.position.y + slot.size.y * 0.68
		draw_line(
			Vector2(slot.position.x + 4.0, shelf_y),
			Vector2(slot.end.x - 4.0, shelf_y),
			Color(0.052, 0.092, 0.124, 0.28),
			1.0,
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
