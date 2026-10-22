extends Node2D
## Flowing, skin-independent quality energy ring.
## Progress segments share the orb's motion language without sharing its palette.

const SEGMENT_COUNT := 3
const SEGMENT_STEP: float = TAU / 3.0
const SEGMENT_GAP: float = 0.16
const RING_RADIUS: float = 20.5
const RING_WIDTH: float = 2.75
const CONTOUR_WIDTH: float = 3.25
const ARC_STEPS_PER_RADIAN: float = 34.0
const STREAK_EXPANSION_DISTANCE: float = 3.6

const GOOD_COLOR := Color(0.05, 0.80, 1.0, 1.0)
const EPIC_COLOR := Color(0.60, 0.22, 1.0, 1.0)
const PERFECT_COLOR := Color(0.82, 0.98, 1.0, 1.0)
const CONTOUR_COLOR := Color(0.075, 0.055, 0.17, 0.40)
const STREAK_AMBER := Color(1.0, 0.52, 0.12, 1.0)
const STREAK_HIGHLIGHT := Color(1.0, 0.90, 0.55, 1.0)
const RIBBON_GLOW_WIDTH: float = 6.2
const RIBBON_GLOW_ALPHA: float = 0.25

var _active_segments: int = 0
var _quality: String = "GOOD"
var _motion_time: float = 0.0
var _streak_sweep_progress: float = 0.0
var _streak_sweep_strength: float = 0.0
var _streak_expansion: float = 0.0
var _streak_sweep_tween: Tween = null
var _streak_strength_tween: Tween = null
var _streak_expansion_tween: Tween = null


func _process(delta: float) -> void:
	_motion_time += delta
	if _active_segments > 0 or _streak_sweep_strength > 0.001:
		queue_redraw()


func set_quality_state(chain_count: int, quality: String) -> void:
	_active_segments = clampi(chain_count, 0, SEGMENT_COUNT)
	_quality = quality.to_upper()
	queue_redraw()


func play_streak_activation() -> void:
	_kill_tween(_streak_sweep_tween)
	_kill_tween(_streak_strength_tween)
	_kill_tween(_streak_expansion_tween)

	_streak_sweep_progress = 0.0
	_streak_sweep_strength = 0.0
	_streak_expansion = 0.0

	_streak_sweep_tween = create_tween()
	_streak_sweep_tween.tween_method(
		Callable(self, "_set_streak_sweep_progress"),
		0.0,
		1.0,
		0.62
	).set_trans(Tween.TRANS_LINEAR)

	_streak_strength_tween = create_tween()
	_streak_strength_tween.tween_method(
		Callable(self, "_set_streak_sweep_strength"),
		0.0,
		1.0,
		0.045
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_streak_strength_tween.tween_method(
		Callable(self, "_set_streak_sweep_strength"),
		1.0,
		0.0,
		0.62
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_streak_expansion_tween = create_tween()
	_streak_expansion_tween.tween_method(
		Callable(self, "_set_streak_expansion"),
		0.0,
		1.0,
		0.10
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_streak_expansion_tween.tween_method(
		Callable(self, "_set_streak_expansion"),
		1.0,
		0.0,
		0.30
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _set_streak_sweep_progress(value: float) -> void:
	_streak_sweep_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _set_streak_sweep_strength(value: float) -> void:
	_streak_sweep_strength = clampf(value, 0.0, 1.0)
	queue_redraw()


func _set_streak_expansion(value: float) -> void:
	_streak_expansion = clampf(value, 0.0, 1.0)
	queue_redraw()


func _get_quality_color() -> Color:
	match _quality:
		"EPIC":
			return EPIC_COLOR
		"PERFECT":
			return PERFECT_COLOR
		_:
			return GOOD_COLOR


func _draw_ribbon(
	start_angle: float,
	end_angle: float,
	radius: float,
	width: float,
	ribbon_color: Color,
	phase: float = 0.0,
	taper_ends: bool = true
) -> void:
	if end_angle <= start_angle or width <= 0.0 or ribbon_color.a <= 0.001:
		return

	var steps: int = maxi(8, ceili((end_angle - start_angle) * ARC_STEPS_PER_RADIAN))
	var outer_points := PackedVector2Array()
	var inner_points := PackedVector2Array()
	var outer_colors := PackedColorArray()
	var inner_colors := PackedColorArray()

	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var angle: float = lerpf(start_angle, end_angle, t)
		var taper: float = 1.0
		if taper_ends:
			taper = 0.015 + 0.985 * pow(maxf(sin(PI * t), 0.0), 0.62)

		var radial_wave: float = (
			sin(angle * 2.0 + _motion_time * 1.35 + phase) * 0.40
			+ sin(angle * 5.0 - _motion_time * 1.85 + phase * 1.7) * 0.16
			+ sin(angle * 3.0 + _motion_time * 0.72 + phase) * 0.13
		)
		var center_radius: float = radius + radial_wave
		var half_width: float = width * 0.5 * taper
		var direction := Vector2(cos(angle), sin(angle))
		outer_points.append(direction * (center_radius + half_width))
		inner_points.append(direction * (center_radius - half_width))

		var edge_alpha: float = ribbon_color.a * taper
		outer_colors.append(Color(
			ribbon_color.r * 0.88,
			ribbon_color.g * 0.90,
			ribbon_color.b * 0.97,
			edge_alpha * 0.84
		))
		inner_colors.append(Color(
			ribbon_color.r,
			ribbon_color.g,
			ribbon_color.b,
			edge_alpha
		))

	var polygon := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(outer_points.size()):
		polygon.append(outer_points[i])
		colors.append(outer_colors[i])
	for i in range(inner_points.size() - 1, -1, -1):
		polygon.append(inner_points[i])
		colors.append(inner_colors[i])

	draw_polygon(polygon, colors)


func _draw_segment_flow(
	start_angle: float,
	end_angle: float,
	segment_index: int,
	radius: float,
	segment_color: Color
) -> void:
	var span: float = end_angle - start_angle
	var streak_length: float = 0.42
	var flow_t: float = fposmod(_motion_time * 0.46 + float(segment_index) * 0.31, 1.0)
	var flow_center: float = start_angle + streak_length * 0.5 + flow_t * maxf(span - streak_length, 0.01)
	var flow_start: float = flow_center - streak_length * 0.5
	var flow_end: float = flow_center + streak_length * 0.5
	var flow_brightness: float = 0.68 + 0.32 * sin(_motion_time * 2.6 + float(segment_index) * 1.7)

	# A fine, offset wisp moves with the ring's energy rather than rotating a
	# rigid symbol. Both ends taper to points so no rectangular cap is visible.
	var wisp := Color(
		segment_color.r,
		segment_color.g,
		segment_color.b,
		0.48 * flow_brightness
	)
	_draw_ribbon(
		flow_start - 0.10,
		flow_end + 0.08,
		radius,
		1.12,
		wisp,
		float(segment_index) * 1.4 + 0.8
	)

	var glint_color: Color = segment_color.lerp(Color.WHITE, 0.20)
	glint_color.a = 0.94 * flow_brightness
	_draw_ribbon(
		flow_start,
		flow_end,
		radius - 0.10,
		1.12,
		glint_color,
		float(segment_index) * 1.2
	)


func _draw() -> void:
	if _active_segments <= 0 and _streak_sweep_strength <= 0.001:
		return

	var radius: float = RING_RADIUS + _streak_expansion * STREAK_EXPANSION_DISTANCE
	var segment_color: Color = _get_quality_color()

	for segment_index in range(_active_segments):
		var start_angle: float = -PI * 0.5 + float(segment_index) * SEGMENT_STEP + SEGMENT_GAP * 0.5
		var end_angle: float = start_angle + SEGMENT_STEP - SEGMENT_GAP
		var glow_color: Color = segment_color
		glow_color.a = RIBBON_GLOW_ALPHA
		_draw_ribbon(
			start_angle,
			end_angle,
			radius,
			RIBBON_GLOW_WIDTH,
			glow_color,
			float(segment_index) * 0.6 + 0.15
		)
		_draw_ribbon(
			start_angle,
			end_angle,
			radius,
			CONTOUR_WIDTH,
			CONTOUR_COLOR,
			float(segment_index) * 0.6
		)
		_draw_ribbon(
			start_angle,
			end_angle,
			radius,
			RING_WIDTH,
			segment_color,
			float(segment_index) * 0.6 + 0.3
		)
		_draw_segment_flow(start_angle, end_angle, segment_index, radius, segment_color)

	if _streak_sweep_strength <= 0.001:
		return

	var sweep_length: float = 0.88
	var sweep_center: float = -PI * 0.5 + TAU * _streak_sweep_progress
	var sweep_start: float = sweep_center - sweep_length * 0.5
	var sweep_end: float = sweep_center + sweep_length * 0.5
	var streak_radius: float = radius + 0.45

	var streak_glow := Color(
		STREAK_AMBER.r,
		STREAK_AMBER.g,
		STREAK_AMBER.b,
		0.34 * _streak_sweep_strength
	)
	_draw_ribbon(sweep_start, sweep_end, streak_radius, 5.0, streak_glow, 0.4)

	var streak_core := Color(
		STREAK_AMBER.r,
		STREAK_AMBER.g,
		STREAK_AMBER.b,
		0.98 * _streak_sweep_strength
	)
	_draw_ribbon(sweep_start, sweep_end, streak_radius, 2.8, streak_core, 0.7)

	var streak_highlight := Color(
		STREAK_HIGHLIGHT.r,
		STREAK_HIGHLIGHT.g,
		STREAK_HIGHLIGHT.b,
		0.82 * _streak_sweep_strength
	)
	_draw_ribbon(sweep_start + 0.03, sweep_end - 0.03, streak_radius - 0.10, 1.0, streak_highlight, 1.2)
