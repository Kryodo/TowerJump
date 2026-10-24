extends Node2D
## Reusable platform energy field, first authored for NORMAL platforms.
##
## This deliberately combines a soft volume, a translucent membrane, layered
## traveling currents, sparse spark filaments and motes. No asset texture is
## required; the geometry is animated in platform-local space and drawn behind
## the platform body/edge. Gameplay responses modulate the same field rather
## than spawning unrelated generic particles.

const PLATFORM_TYPE_NORMAL: int = 0
const IDLE_WAVE_PERIOD: float = 5.0
const IDLE_WAVE_DURATION: float = 1.65
const LANDING_WAVE_DURATION: float = 0.58
const CURVE_SEGMENTS: int = 56
const MEMBRANE_SEGMENTS: int = 42
const FILAMENT_POINTS: int = 6
const MOTE_COUNT: int = 9

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
	_phase_offset = randf_range(0.0, TAU)
	var additive_material := CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive_material
	set_process(true)


func configure(platform_type: int, platform_width: float, platform_height: float) -> void:
	_platform_type = platform_type
	_platform_width = maxf(platform_width, 1.0)
	_platform_height = maxf(platform_height, 1.0)

	# Only Normal receives this first visual identity. Special platforms will
	# get their own characteristic field behavior, not a color-swapped copy.
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
	# Skip animation work when a pooled platform is outside the camera.
	if platform.has_method("_is_platform_on_screen") and not bool(platform.call("_is_platform_on_screen")):
		return

	_time += delta
	var response: float = 1.0 - exp(-8.0 * delta)
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
	var breathe: float = 0.5 + 0.5 * sin(_time * 1.12 + _phase_offset)
	var slow_phase: float = _time * 0.46 + _phase_offset
	var fast_phase: float = _time * 1.12 - _phase_offset * 0.7

	# 1. VOLUME. Three overlapping, tapered membranes create a soft energy
	# pocket. Their different depth/width keeps it from reading as an outline.
	_draw_membrane_band(
		half_width + 18.0, half_height, 1.0, 23.0,
		1.55, slow_phase,
		Color(0.035, 0.20, 1.15, 0.075 + breathe * 0.018)
	)
	_draw_membrane_band(
		half_width + 11.0, half_height, 2.0, 17.0,
		1.15, fast_phase,
		Color(0.025, 0.48, 1.8, 0.085 + breathe * 0.032)
	)
	_draw_membrane_band(
		half_width + 4.0, half_height, 2.8, 10.5,
		0.72, slow_phase + 1.7,
		Color(0.06, 0.72, 2.15, 0.075 + breathe * 0.026)
	)

	# 2. LIVING CURRENTS. A blurred outer halo, luminous current and fine
	# inner thread share the same organic curve but have separate energy depth.
	var current_a := _build_current(
		half_width, half_height, 5.5, 1.85,
		slow_phase, -_approach_charge
	)
	var current_b := _build_current(
		half_width, half_height, 10.2, 2.35,
		-fast_phase + 1.9, _approach_charge * 0.65
	)
	var current_c := _build_current(
		half_width, half_height, 15.2, 1.55,
		fast_phase * 0.72 + 2.4, 0.0
	)
	_draw_current_layers(current_a, 0.78 + breathe * 0.28)
	_draw_current_layers(current_b, 0.52 + breathe * 0.30)
	_draw_current_layers(current_c, 0.36 + breathe * 0.22)

	# 3. EDGE FILAMENTS. Short branching strands peel away from the end field;
	# the tapered double strokes feel closer to the comet energy threads than
	# to decorative rails. They drift on slightly different rhythms.
	_draw_edge_filaments(-1.0, half_width, half_height, slow_phase, breathe)
	_draw_edge_filaments(1.0, half_width, half_height, fast_phase + 0.8, breathe)

	# Sparse motes drift inside the field; each has a soft halo and a compact
	# core, so they read as energized material rather than a particle shower.
	_draw_resonance_motes(half_width, half_height, slow_phase, breathe)

	# 4. QUIET TRAVELING SURGE. Once in a while a low, organic swell travels
	# outward from the center. It is a volume/lobe in the field, not a chevron
	# riding on a single baseline.
	var idle_wave_clock: float = fposmod(_time + _phase_offset * 0.41, IDLE_WAVE_PERIOD)
	if idle_wave_clock < IDLE_WAVE_DURATION:
		var wave_progress: float = smoothstep(0.0, 1.0, idle_wave_clock / IDLE_WAVE_DURATION)
		var wave_x: float = (half_width + 13.0) * wave_progress
		var wave_fade: float = (1.0 - wave_progress * 0.68) * (0.28 + breathe * 0.20)
		_draw_energy_lobe(wave_x, half_height + 8.5, wave_fade, false)
		_draw_energy_lobe(-wave_x, half_height + 8.5, wave_fade * 0.94, false)

	# 5. APPROACH. The energy compresses around the predicted contact point.
	# It borrows the field's material instead of drawing a separate UI marker.
	if _approach_charge > 0.018:
		var focus_x: float = lerpf(-half_width, half_width, _approach_target_x)
		_draw_approach_resonance(focus_x, half_height, breathe)

	# 6. LANDING. A short, layered pulse expands from the actual contact point,
	# briefly brightens the under-field and fades without replacing the base life.
	if _landing_wave_age >= 0.0:
		var landing_t: float = clampf(_landing_wave_age / LANDING_WAVE_DURATION, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - landing_t, 2.0)
		var extent: float = half_width + 17.0
		var left_x: float = lerpf(_landing_local_x, -extent, eased)
		var right_x: float = lerpf(_landing_local_x, extent, eased)
		var landing_fade: float = _landing_wave_strength * (1.0 - landing_t)
		_draw_energy_lobe(left_x, half_height + 8.0, landing_fade * 0.72, true)
		_draw_energy_lobe(right_x, half_height + 8.0, landing_fade * 0.72, true)
		_draw_contact_filaments(half_height, landing_t, landing_fade)


func _draw_membrane_band(
	half_width: float,
	half_height: float,
	top_offset: float,
	depth: float,
	amplitude: float,
	phase: float,
	tint: Color
) -> void:
	var points := PackedVector2Array()
	for i in range(MEMBRANE_SEGMENTS + 1):
		var t: float = float(i) / float(MEMBRANE_SEGMENTS)
		var x: float = lerpf(-half_width, half_width, t)
		var taper: float = pow(maxf(sin(t * PI), 0.0), 0.45)
		var wave: float = (
			sin(t * TAU * 1.25 + phase) * amplitude
			+ sin(t * TAU * 2.3 - phase * 0.66) * amplitude * 0.31
		) * taper
		var upper_y: float = half_height + top_offset + wave + (1.0 - taper) * 2.2
		points.append(Vector2(x, upper_y))

	for i in range(MEMBRANE_SEGMENTS, -1, -1):
		var t: float = float(i) / float(MEMBRANE_SEGMENTS)
		var x: float = lerpf(-half_width, half_width, t)
		var taper: float = pow(maxf(sin(t * PI), 0.0), 0.45)
		var wave: float = (
			sin(t * TAU * 1.25 + phase) * amplitude
			+ sin(t * TAU * 2.3 - phase * 0.66) * amplitude * 0.31
		) * taper
		var lower_y: float = (
			half_height + top_offset + wave + depth * taper
			+ (1.0 - taper) * 2.2
		)
		points.append(Vector2(x, lower_y))
	draw_colored_polygon(points, tint)


func _build_current(
	half_width: float,
	half_height: float,
	base_offset: float,
	amplitude: float,
	phase: float,
	focus_strength: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(CURVE_SEGMENTS + 1):
		var t: float = float(i) / float(CURVE_SEGMENTS)
		var x: float = lerpf(-half_width - 13.0, half_width + 13.0, t)
		var taper: float = pow(maxf(sin(t * PI), 0.0), 0.48)
		var waviness: float = (
			sin(t * TAU * 1.2 + phase) * amplitude
			+ sin(t * TAU * 2.6 - phase * 0.58) * amplitude * 0.32
		) * taper
		var focus: float = 0.0
		if _approach_charge > 0.001:
			var target_x: float = lerpf(-half_width, half_width, _approach_target_x)
			var radius: float = maxf(half_width * lerpf(0.26, 0.12, _approach_charge), 1.0)
			focus = exp(-pow((x - target_x) / radius, 2.0)) * _approach_charge * focus_strength * 3.2
		var y: float = half_height + base_offset + waviness - focus
		points.append(Vector2(x, y))
	return points


func _draw_current_layers(points: PackedVector2Array, energy: float) -> void:
	# Three passes give the filament a soft bloom, a colored membrane edge and
	# a thin highlight core. This is the same layered-stroke idea used by the
	# comet's live energy filaments.
	draw_polyline(
		points,
		Color(0.02, 0.28, 1.25, 0.11 * energy),
		8.5,
		true
	)
	draw_polyline(
		points,
		Color(0.035, 0.68, 2.0, 0.16 * energy),
		3.3,
		true
	)
	draw_polyline(
		points,
		Color(0.55, 1.15, 2.25, 0.24 * energy),
		0.82,
		true
	)


func _draw_edge_filaments(
	side: float,
	half_width: float,
	half_height: float,
	phase: float,
	breathe: float
) -> void:
	for strand in range(3):
		var strand_phase: float = phase + float(strand) * 1.71
		var spread: float = 5.5 + float(strand) * 3.8
		var bob: float = sin(strand_phase * 0.93) * (1.4 + float(strand) * 0.25)
		var drift: float = sin(strand_phase * 0.61 + float(strand) * 1.3) * 2.3
		var points := PackedVector2Array([
			Vector2(side * (half_width - 3.0), half_height + 1.8),
			Vector2(side * (half_width + 1.0), half_height + 2.0 + bob * 0.25),
			Vector2(side * (half_width + spread * 0.55), half_height + 4.0 + bob),
			Vector2(side * (half_width + spread + drift), half_height + 7.2 + bob * 0.50),
			Vector2(side * (half_width + spread + drift * 0.7), half_height + 10.2 - bob * 0.7),
			Vector2(side * (half_width + spread * 0.7), half_height + 12.0 + bob * 0.32)
		])
		_draw_tapered_filament(points, (0.46 + breathe * 0.40) * (1.0 - float(strand) * 0.17), strand == 0)


func _draw_tapered_filament(points: PackedVector2Array, energy: float, has_core: bool = true) -> void:
	if points.size() < 2 or energy <= 0.01:
		return
	for index in range(1, points.size()):
		var t: float = float(index) / float(points.size() - 1)
		var tip_fade: float = sin(t * PI) * 0.60 + 0.25
		var shimmer: float = 0.74 + 0.26 * absf(sin(_time * 17.0 + float(index) * 3.7 + _phase_offset))
		var strength: float = energy * tip_fade * shimmer
		draw_line(
			points[index - 1], points[index],
			Color(0.025, 0.35, 1.45, 0.13 * strength),
			3.6 if has_core else 2.4, true
		)
		draw_line(
			points[index - 1], points[index],
			Color(0.08, 0.92, 2.35, 0.34 * strength),
			1.25 if has_core else 0.82, true
		)
		if has_core and index % 2 == 0:
			draw_line(
				points[index - 1], points[index],
				Color(0.62, 1.35, 2.6, 0.48 * strength),
				0.60, true
			)


func _draw_resonance_motes(
	half_width: float,
	half_height: float,
	phase: float,
	breathe: float
) -> void:
	for index in range(MOTE_COUNT):
		var seed: float = _phase_offset * 13.7 + float(index) * 9.173
		var speed: float = 0.045 + fposmod(float(index) * 0.037, 0.055)
		var travel: float = fposmod(_time * speed + seed, 1.0)
		var x: float = lerpf(-half_width - 10.0, half_width + 10.0, travel)
		var y_wave: float = sin(_time * (0.72 + float(index) * 0.028) + seed) * 2.4
		var layer: float = fposmod(float(index) * 0.37 + 0.12, 1.0)
		var y: float = half_height + 4.8 + layer * 12.0 + y_wave
		var pulse: float = 0.54 + 0.46 * absf(sin(_time * (2.8 + float(index) * 0.1) + seed))
		var radius: float = 0.8 + pulse * (0.45 if index % 3 == 0 else 0.12)
		var alpha: float = (0.22 + breathe * 0.15) * pulse
		draw_circle(Vector2(x, y), radius * 3.6, Color(0.02, 0.34, 1.25, alpha * 0.30))
		draw_circle(Vector2(x, y), radius * 1.65, Color(0.08, 0.78, 2.1, alpha * 0.62))
		draw_circle(Vector2(x, y), radius * 0.68, Color(0.72, 1.35, 2.5, alpha))


func _draw_energy_lobe(
	center_x: float,
	center_y: float,
	strength: float,
	landing_wave: bool
) -> void:
	if strength <= 0.008:
		return
	var rx: float = 13.0 if not landing_wave else 16.0
	var ry: float = 5.2 if not landing_wave else 6.6
	var points := PackedVector2Array()
	for i in range(17):
		var angle: float = TAU * float(i) / 16.0
		var warp: float = 1.0 + 0.14 * sin(angle * 3.0 + _time * 2.1 + _phase_offset)
		points.append(Vector2(
			center_x + cos(angle) * rx * warp,
			center_y + sin(angle) * ry * warp
		))
	var tint := Color(0.08, 0.72, 2.2, clampf(strength * 0.13, 0.0, 0.42))
	if landing_wave:
		tint = Color(0.20, 1.30, 3.2, clampf(strength * 0.20, 0.0, 0.48))
	draw_colored_polygon(points, tint)
	var ring := PackedVector2Array()
	for i in range(25):
		var angle: float = TAU * float(i) / 24.0
		var warp: float = 1.0 + 0.12 * sin(angle * 3.0 + _time * 2.1 + _phase_offset)
		ring.append(Vector2(
			center_x + cos(angle) * rx * 1.28 * warp,
			center_y + sin(angle) * ry * 1.28 * warp
		))
	draw_polyline(
		ring,
		Color(0.08, 0.72, 2.2, clampf(strength * 0.15, 0.0, 0.40)),
		3.6,
		true
	)
	draw_polyline(
		ring,
		Color(0.34, 1.35, 2.8, clampf(strength * 0.34, 0.0, 0.60)),
		1.0,
		true
	)


func _draw_approach_resonance(
	center_x: float,
	half_height: float,
	breathe: float
) -> void:
	var charge: float = _approach_charge
	var compressed: float = lerpf(1.0, 0.62, charge)
	var rx: float = 24.0 * compressed
	var cy: float = half_height + 8.5
	var alpha: float = charge * (0.30 + breathe * 0.16)
	var points := PackedVector2Array()
	for i in range(19):
		var angle: float = TAU * float(i) / 18.0
		var distortion: float = 1.0 + 0.13 * sin(angle * 3.0 + _time * 1.6)
		points.append(Vector2(
			center_x + cos(angle) * rx * distortion,
			cy + sin(angle) * 6.4 * distortion
		))
	draw_colored_polygon(points, Color(0.04, 0.70, 2.0, alpha * 0.14))
	draw_polyline(points, Color(0.07, 0.75, 2.15, alpha * 0.30), 4.8, true)
	draw_polyline(points, Color(0.36, 1.22, 2.5, alpha * 0.62), 1.05, true)

	var focus_filament := PackedVector2Array([
		Vector2(center_x - rx * 1.15, cy + 4.0),
		Vector2(center_x - rx * 0.62, cy + 1.2),
		Vector2(center_x, cy - 0.8),
		Vector2(center_x + rx * 0.48, cy + 1.5),
		Vector2(center_x + rx * 1.10, cy + 4.2)
	])
	_draw_tapered_filament(focus_filament, charge * 0.85)


func _draw_contact_filaments(
	half_height: float,
	landing_t: float,
	strength: float
) -> void:
	if strength <= 0.01 or landing_t >= 0.86:
		return
	var impact_fade: float = 1.0 - landing_t / 0.86
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array([
			Vector2(_landing_local_x, half_height + 4.8),
			Vector2(_landing_local_x + side * 3.0, half_height + 1.6),
			Vector2(_landing_local_x + side * 8.0, half_height + 4.0),
			Vector2(_landing_local_x + side * 12.0, half_height + 8.0),
			Vector2(_landing_local_x + side * 18.0, half_height + 10.5)
		])
		_draw_tapered_filament(points, strength * impact_fade * 0.70, true)
