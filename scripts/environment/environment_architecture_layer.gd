class_name EnvironmentArchitectureLayer
extends Node2D
## Extracted, reusable renderer for TowerJump's established three-layer architecture.
## The geometry, proportions, repetition cadence, A2 detail palette and controlled
## seed variation are derived from experiment-middle-architecture-details.
## Experiment-only palette comparisons, debug overlays and test orchestration are omitted.

enum LayerType {
	FAR_SILHOUETTES,
	MID_ARCHITECTURE,
	NEAR_FRAMES,
}

enum FarDetailTreatment {
	NONE,
	COMPACT_PANEL_STATES,
	COMPACT_PANEL_FLICKER,
}

enum MidDetailTreatment {
	BASELINE,
	STEPPED_INSETS,
	INSETS_AND_MECHANICAL_RECESSES,
}

@export var layer_type: LayerType = LayerType.FAR_SILHOUETTES
@export var theme_profile: EnvironmentThemeProfile
@export var environment_seed: int = 7319
@export var architecture_recipe: EnvironmentArchitectureRecipe
@export var world_width: float = 720.0
@export var section_top_y: float = -10400.0
@export var section_bottom_y: float = 1600.0
## True for the isolated original-study fixture; normal subzones use bounded geometry.
@export var preserve_reference_overdraw: bool = false
@export var far_detail_treatment: FarDetailTreatment = FarDetailTreatment.COMPACT_PANEL_FLICKER
@export var mid_detail_treatment: MidDetailTreatment = MidDetailTreatment.INSETS_AND_MECHANICAL_RECESSES
@export var module_preview_mode: bool = false

var _rng := RandomNumberGenerator.new()
var _flicker_clock: float = 0.0

const FAR_MASS_A := Color(0.011764706, 0.03137255, 0.0627451, 0.98)
const FAR_MASS_B := Color(0.015686275, 0.039215688, 0.078431375, 0.98)
const MID_MASS := Color(0.0055, 0.0165, 0.038, 0.96)
const MID_SHADOW := Color(0.003, 0.008, 0.019, 0.96)
const SEAM_CYAN := Color(0.025, 0.19, 0.26, 0.42)
const SEAM_VIOLET := Color(0.15, 0.07, 0.27, 0.34)
const NEAR_SEAM := Color(0.018, 0.13, 0.18, 0.20)
const ACCENT_CYAN := Color(0.012, 0.82, 1.15, 0.84)
const ACCENT_VIOLET := Color(0.42, 0.16, 0.88, 0.78)
const EDGE_REVEAL := Color(0.026, 0.105, 0.155, 0.64)

const FAR_STRUCTURED_A2 := {
	"panel_fill": Color(0.009, 0.026, 0.052, 0.68),
	"panel_edge": Color(0.055, 0.095, 0.145, 0.40),
	"panel_rail": Color(0.070, 0.120, 0.180, 0.32),
	"window_frame": Color(0.045, 0.092, 0.132, 0.70),
	"window_dark": Color(0.005, 0.014, 0.028, 0.90),
	"window_lit": Color(0.024, 0.090, 0.142, 0.82),
	"window_neon": Color(0.13, 0.37, 0.55, 0.74),
	"window_halo": Color(0.08, 0.24, 0.38, 0.10),
}


func configure(
	profile: EnvironmentThemeProfile,
	_unused_lighting_profile: EnvironmentLightingProfile,
	seed_value: int,
	_unused_light_state: int = -1
) -> void:
	theme_profile = profile
	environment_seed = seed_value
	queue_redraw()


func _draw() -> void:
	_rng.seed = int(environment_seed) + int(layer_type) * 7919

	if module_preview_mode:
		match layer_type:
			LayerType.FAR_SILHOUETTES:
				_draw_far_mass(1.0, 120.0, 1920.0, 189.0, 0)
			LayerType.MID_ARCHITECTURE:
				_draw_support_module(1.0, 120.0, 0)
			LayerType.NEAR_FRAMES:
				_draw_near_frames()
		return

	if not preserve_reference_overdraw:
		match layer_type:
			LayerType.FAR_SILHOUETTES:
				_draw_far_architecture_bounded()
			LayerType.MID_ARCHITECTURE:
				_draw_mid_architecture_bounded()
			LayerType.NEAR_FRAMES:
				_draw_near_frames_bounded()
		return

	# The explicit reference path below preserves the original study's overdraw
	# and coordinates exactly. Do not change it without refreshing parity baselines.
	match layer_type:
		LayerType.FAR_SILHOUETTES:
			_draw_far_architecture()
		LayerType.MID_ARCHITECTURE:
			_draw_mid_architecture()
		LayerType.NEAR_FRAMES:
			_draw_near_frames()


func _process(delta: float) -> void:
	if (
		layer_type == LayerType.FAR_SILHOUETTES
		and far_detail_treatment == FarDetailTreatment.COMPACT_PANEL_FLICKER
	):
		_flicker_clock += delta
		queue_redraw()


func _far_mass_color(index: int) -> Color:
	if theme_profile == null:
		return FAR_MASS_A if index % 3 == 0 else FAR_MASS_B
	return theme_profile.far_fill_a if index % 3 == 0 else theme_profile.far_fill_b


func _mid_mass_color() -> Color:
	return theme_profile.middle_fill if theme_profile != null else MID_MASS


func _accent_primary() -> Color:
	return theme_profile.accent_primary if theme_profile != null else ACCENT_CYAN


func _accent_secondary() -> Color:
	return theme_profile.accent_secondary if theme_profile != null else ACCENT_VIOLET


func _near_seam_color() -> Color:
	return theme_profile.near_detail if theme_profile != null else NEAR_SEAM




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
		y += architecture_recipe.far_repeat_spacing_px if architecture_recipe != null else 1580.0

func _draw_far_architecture_bounded() -> void:
	# Same silhouettes, spacing, palette, and aperture grammar as the reference
	# renderer, but no mass is allowed to extend outside this subzone's height.
	var y: float = section_top_y
	var index := 0
	while y < section_bottom_y:
		var height: float = 1920.0 + _rng.randf_range(-110.0, 120.0)
		var left_width: float = 165.0 + float(index % 3) * 24.0 + _rng.randf_range(-10.0, 10.0)
		var right_width: float = 162.0 + float((index + 1) % 3) * 26.0 + _rng.randf_range(-10.0, 10.0)
		var y_jitter: float = _rng.randf_range(-60.0, 60.0)
		var right_offset: float = 120.0 if index % 2 == 0 else -80.0
		var left_top_y: float = maxf(section_top_y, y + y_jitter)
		var right_top_y: float = maxf(section_top_y, y + y_jitter + right_offset)
		if left_top_y + height <= section_bottom_y:
			_draw_far_mass(1.0, left_top_y, height, left_width, index)
		if right_top_y + height <= section_bottom_y:
			_draw_far_mass(-1.0, right_top_y, height, right_width, index + 1)
		index += 1
		y += architecture_recipe.far_repeat_spacing_px if architecture_recipe != null else 1580.0


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


	if far_detail_treatment != FarDetailTreatment.NONE:
		_draw_far_compact_panel_clusters(
			side,
			top_y,
			height,
			width,
			index,
			far_detail_treatment == FarDetailTreatment.COMPACT_PANEL_FLICKER
		)


static func resolve_far_detail_palette(profile: EnvironmentThemeProfile) -> Dictionary:
	# A2 remains the fallback for an unassigned profile. A1/A2 and future zone
	# themes provide the entire far recess/window material, not just light tint.
	var detail: Dictionary = FAR_STRUCTURED_A2.duplicate(true)
	if profile != null:
		detail["panel_fill"] = profile.far_panel_fill
		detail["panel_edge"] = profile.far_panel_edge
		detail["panel_rail"] = profile.far_panel_rail
		detail["window_frame"] = profile.far_window_frame
		detail["window_dark"] = profile.far_window_dark
		detail["window_lit"] = profile.far_window_lit
		detail["window_neon"] = profile.far_window_neon
		detail["window_halo"] = profile.far_window_halo
	return detail


func _structured_far_palette() -> Dictionary:
	return resolve_far_detail_palette(theme_profile)




func _far_panel_left_x(side: float, edge_x: float, width: float, panel_width: float = 46.0) -> float:
	var panel_anchor: float = edge_x + side * (width - 78.0)
	return panel_anchor if side > 0.0 else panel_anchor - panel_width

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
		y += architecture_recipe.middle_repeat_spacing_px if architecture_recipe != null else 1260.0

func _draw_mid_architecture_bounded() -> void:
	# The largest authored support variant is 1,172 px tall. Use that conservative
	# envelope so neither the primary nor offset opposing support crosses a boundary.
	const MAX_SUPPORT_HEIGHT: float = 1172.0
	var y: float = section_top_y + 120.0
	var index := 0
	var spacing: float = architecture_recipe.middle_repeat_spacing_px if architecture_recipe != null else 1260.0
	while y + MAX_SUPPORT_HEIGHT <= section_bottom_y:
		_draw_support_module(1.0, y, index)
		if index % 4 != 1 or _rng.randf() < 0.12:
			var opposite_y: float = y + (180.0 if index % 2 == 0 else -110.0)
			if (
				opposite_y >= section_top_y
				and opposite_y + MAX_SUPPORT_HEIGHT <= section_bottom_y
			):
				_draw_support_module(-1.0, opposite_y, index + 2)
		index += 1
		y += spacing


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
			_accent_primary(),
			2.0,
			true
		)
	elif index % 7 == 0:
		draw_line(
			Vector2(inner_edge_x, accent_y),
			Vector2(inner_edge_x, accent_y + height * 0.07),
			_accent_secondary(),
			2.0,
			true
		)


# One shared dark-indigo palette keeps recesses visually consistent across blue and
# purple middle fills. The fill behind them changes; their material identity does not.
# Diagnostic mode deliberately exaggerates contrast for inspection.

func _mid_detail_colors() -> Dictionary:
	# Shared dark-indigo recess material retained from the approved middle-detail study.
	# It remains unchanged across the A2 blue fill and future zone-specific fills.
	return {
		"cavity": Color(0.020, 0.014, 0.060, 0.92),
		"edge": Color(0.105, 0.080, 0.178, 0.66),
		"inner": Color(0.013, 0.010, 0.044, 0.94),
		"inner_edge": Color(0.090, 0.070, 0.155, 0.62),
		"division": Color(0.125, 0.096, 0.195, 0.66),
		"foot": Color(0.018, 0.013, 0.052, 0.88),
		"slot": Color(0.014, 0.010, 0.046, 0.96),
		"slot_edge": Color(0.105, 0.080, 0.176, 0.62),
		"shelf": Color(0.135, 0.105, 0.205, 0.60),
	}




func _mid_inset_plate_specs(height: float, index: int, side_index: int) -> Array[Rect2]:
	var pattern: int = posmod(index * 3 + side_index, 4)
	var base_width: float = 39.0 + float(posmod(index * 5, 4)) * 4.0
	var plates: Array[Rect2] = []

	match pattern:
		0:
			# Single long inset with a visible lower step.
			var pw: float = base_width + 6.0
			plates.append(Rect2(
				Vector2(0.0, height * 0.21),
				Vector2(pw, height * 0.34)
			))
		1:
			# Two separated, offset recesses of unequal height.
			plates.append(Rect2(
				Vector2(0.0, height * 0.18),
				Vector2(base_width - 4.0, height * 0.16)
			))
			plates.append(Rect2(
				Vector2(0.0, height * 0.53),
				Vector2(base_width - 12.0, height * 0.13)
			))
		2:
			# Broad horizontal housing with a compact lower inset.
			plates.append(Rect2(
				Vector2(0.0, height * 0.36),
				Vector2(base_width + 15.0, height * 0.17)
			))
			plates.append(Rect2(
				Vector2(0.0, height * 0.64),
				Vector2(base_width - 13.0, height * 0.11)
			))
		_:
			# Paired vertical plates with deliberately unequal proportions.
			plates.append(Rect2(
				Vector2(0.0, height * 0.25),
				Vector2(base_width - 9.0, height * 0.22)
			))
			plates.append(Rect2(
				Vector2(0.0, height * 0.57),
				Vector2(base_width + 1.0, height * 0.18)
			))

	return plates

func _draw_mid_stepped_inset(
	side: float,
	top_y: float,
	height: float,
	width: float,
	index: int
) -> void:
	var colors: Dictionary = _mid_detail_colors()
	var side_index: int = 1 if side < 0.0 else 0
	var pattern: int = posmod(index * 3 + side_index, 4)
	var inner_edge_x: float = 0.0 if side > 0.0 else world_width
	var plates: Array[Rect2] = _mid_inset_plate_specs(height, index, side_index)

	for plate_index in range(plates.size()):
		var spec: Rect2 = plates[plate_index]
		var plate_width: float = spec.size.x
		var plate_height: float = spec.size.y
		# Bias the plates inward to create a deliberate buffer for the outer
		# mechanical-service lane, while keeping them embedded in the support.
		var inward_offset: float = float(posmod(index + plate_index * 2, 3)) * 5.0 - 18.0
		var plate_x: float
		if side > 0.0:
			plate_x = inner_edge_x + width - 27.0 - plate_width - inward_offset
		else:
			plate_x = inner_edge_x - width + 27.0 + inward_offset
		var plate_y: float = top_y + spec.position.y + (
			float(posmod(index * 7 + plate_index * 3, 3)) - 1.0
		) * 7.0
		var plate := Rect2(Vector2(plate_x, plate_y), Vector2(plate_width, plate_height))
		_draw_mid_inset_plate(plate, side, pattern, plate_index, colors)

func _draw_mid_inset_plate(
	plate: Rect2,
	side: float,
	pattern: int,
	plate_index: int,
	colors: Dictionary
) -> void:
	draw_rect(plate, colors["cavity"], true)
	draw_rect(plate, colors["edge"], false, 1.4)

	var inner_plate := Rect2(
		plate.position + Vector2(4.0, 7.0),
		plate.size - Vector2(8.0, 14.0)
	)
	draw_rect(inner_plate, colors["inner"], true)
	draw_rect(
		inner_plate,
		colors["inner_edge"],
		false,
		1.1
	)

	# A broken shoulder reveal is offset to one side, rather than a complete bright frame.
	var shoulder_x: float = plate.position.x + (
		plate.size.x - 5.0 if side > 0.0 else 5.0
	)
	draw_line(
		Vector2(shoulder_x, plate.position.y + 12.0),
		Vector2(shoulder_x, plate.end.y - 12.0),
		colors["edge"],
		1.1,
		true
	)

	match pattern:
		0:
			for division in range(2):
				var division_y: float = plate.position.y + plate.size.y * (
					0.38 + float(division) * 0.29
				)
				draw_line(
					Vector2(plate.position.x + 6.0, division_y),
					Vector2(plate.end.x - 8.0, division_y),
					colors["division"],
					1.45,
					true
				)
			var foot_width: float = 15.0 + float(plate_index) * 3.0
			var foot_x: float = plate.end.x - foot_width if side > 0.0 else plate.position.x - 2.0
			draw_rect(
				Rect2(Vector2(foot_x, plate.end.y - 24.0), Vector2(foot_width, 24.0)),
				colors["foot"],
				true
			)
		1:
			var cross_y: float = plate.position.y + plate.size.y * 0.62
			draw_line(
				Vector2(plate.position.x + 5.0, cross_y),
				Vector2(plate.end.x - 5.0, cross_y),
				colors["division"],
				1.45,
				true
			)
		2:
			var shelf_y: float = plate.position.y + plate.size.y * 0.72
			draw_line(
				Vector2(plate.position.x + 6.0, shelf_y),
				Vector2(plate.end.x - 6.0, shelf_y),
				colors["division"],
				1.5,
				true
			)
			var vertical_x: float = plate.position.x + (
				plate.size.x * 0.68 if side > 0.0 else plate.size.x * 0.32
			)
			draw_line(
				Vector2(vertical_x, plate.position.y + 5.0),
				Vector2(vertical_x, plate.end.y - 5.0),
				colors["division"],
				1.0,
				true
			)
		_:
			# A staggered pair of short interior ribs gives the double-plate pattern
			# a different internal rhythm from the tall and broad variants.
			for rib in range(2):
				var rib_y: float = plate.position.y + plate.size.y * (0.34 + float(rib) * 0.38)
				var rib_start_x: float = plate.position.x + 5.0 + float(rib) * 4.0
				draw_line(
					Vector2(rib_start_x, rib_y),
					Vector2(plate.end.x - 7.0, rib_y),
					colors["division"],
					1.35,
					true
				)


# Middle-layer study C adds different mechanical cavity arrangements to B.
# The recesses remain non-emissive and use the shared dark-indigo material.

func _draw_mid_mechanical_recesses(
	side: float,
	top_y: float,
	height: float,
	width: float,
	index: int
) -> void:
	if index % 3 == 1:
		return

	var colors: Dictionary = _mid_detail_colors()
	var side_index: int = 1 if side < 0.0 else 0
	var pattern: int = posmod(index * 5 + side_index, 4)
	var edge_x: float = 0.0 if side > 0.0 else world_width
	var slot_width: float = 19.0 + float(posmod(index, 3)) * 4.0
	var slot_height: float = 48.0 + float(posmod(index * 2, 3)) * 12.0
	var slots: Array[Rect2] = []

	match pattern:
		0:
			# Two vertical cavities at different heights.
			slots.append(Rect2(Vector2(0.0, top_y + height * 0.34), Vector2(slot_width, slot_height)))
			slots.append(Rect2(Vector2(0.0, top_y + height * 0.62), Vector2(slot_width - 3.0, slot_height * 0.82)))
		1:
			# One broad horizontal recess with a smaller offset companion.
			slots.append(Rect2(Vector2(0.0, top_y + height * 0.43), Vector2(slot_width + 18.0, slot_height * 0.55)))
			slots.append(Rect2(Vector2(0.0, top_y + height * 0.61), Vector2(slot_width - 2.0, slot_height * 0.42)))
		2:
			# A staggered vertical / horizontal pair.
			slots.append(Rect2(Vector2(0.0, top_y + height * 0.29), Vector2(slot_width - 4.0, slot_height * 0.92)))
			slots.append(Rect2(Vector2(0.0, top_y + height * 0.68), Vector2(slot_width + 13.0, slot_height * 0.44)))
		_:
			# Three short, unevenly spaced service cuts.
			for cut in range(3):
				slots.append(Rect2(
					Vector2(0.0, top_y + height * (0.33 + float(cut) * 0.15)),
					Vector2(slot_width - float(cut % 2) * 3.0, slot_height * 0.38)
				))

	# Calculate the closest inset edge from the exact same layout specifications
	# used by B. C then reserves a fixed 15px separation instead of guessing a
	# second X-position independently.
	var inset_specs: Array[Rect2] = _mid_inset_plate_specs(height, index, side_index)
	var nearest_inset_edge: float = INF
	for plate_index in range(inset_specs.size()):
		var inward_offset: float = float(posmod(index + plate_index * 2, 3)) * 5.0 - 18.0
		var plate_outer_edge: float = width - 27.0 - inset_specs[plate_index].size.x - inward_offset
		nearest_inset_edge = minf(nearest_inset_edge, plate_outer_edge)

	for slot_index in range(slots.size()):
		var spec: Rect2 = slots[slot_index]
		var outer_offset: float = 6.0 + float(slot_index) * 3.0
		var maximum_slot_width: float = nearest_inset_edge - outer_offset - 15.0
		# Skip a cavity rather than violating the minimum gap if a future pattern
		# leaves insufficient room for a readable service recess.
		if maximum_slot_width < 14.0:
			continue
		var slot_width_actual: float = minf(spec.size.x, maximum_slot_width)
		var slot_height_actual: float = spec.size.y
		var slot_y: float = spec.position.y + float(posmod(index + slot_index, 2)) * 5.0
		var slot_anchor_x: float = edge_x + side * outer_offset
		var slot_x: float = slot_anchor_x if side > 0.0 else slot_anchor_x - slot_width_actual
		var slot := Rect2(Vector2(slot_x, slot_y), Vector2(slot_width_actual, slot_height_actual))
		draw_rect(slot, colors["slot"], true)
		draw_rect(slot, colors["slot_edge"], false, 1.2)

		# A short shelf is the only interior highlight, so these stay structural cavities.
		var shelf_y: float = slot.position.y + slot.size.y * 0.68
		draw_line(
			Vector2(slot.position.x + 4.0, shelf_y),
			Vector2(slot.end.x - 4.0, shelf_y),
			colors["shelf"],
			1.1,
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
			draw_line(left_start, left_start + Vector2(0.0, length), _near_seam_color(), 2.0, true)
		else:
			draw_line(right_start, right_start + Vector2(0.0, -length), _near_seam_color(), 2.0, true)
		y += architecture_recipe.near_repeat_spacing_px if architecture_recipe != null else 2140.0
		index += 1


func _draw_near_frames_bounded() -> void:
	var y: float = section_top_y + 400.0
	var index := 0
	var spacing: float = architecture_recipe.near_repeat_spacing_px if architecture_recipe != null else 2140.0
	while y < section_bottom_y:
		var length: float = (430.0 if index % 2 == 0 else 280.0) + _rng.randf_range(-45.0, 45.0)
		if index % 2 == 0:
			if y + length <= section_bottom_y:
				var left_start := Vector2(14.0, y)
				draw_line(left_start, left_start + Vector2(0.0, length), _near_seam_color(), 2.0, true)
		else:
			var right_start_y: float = y + 360.0
			var right_top_y: float = right_start_y - length
			if right_top_y >= section_top_y and right_start_y <= section_bottom_y:
				var right_start := Vector2(world_width - 14.0, right_start_y)
				draw_line(right_start, right_start + Vector2(0.0, -length), _near_seam_color(), 2.0, true)
		y += spacing
		index += 1


# Resonance Gate: one deliberately composed architectural object. The dark mass
# and its aperture define the shape; only a few short seams carry color.
