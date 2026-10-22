extends Node2D
## Draws protected quality progress segments above the cosmetic orb.
## Ring colors, stroke width and outline are independent of the orb/trail skin.

const SEGMENT_COUNT := 3
const SEGMENT_STEP: float = TAU / 3.0
const SEGMENT_GAP: float = 0.20
const RING_RADIUS: float = 14.5
const RING_WIDTH: float = 3.2
const OUTLINE_WIDTH: float = 6.0
const ARC_POINTS := 32
const STREAK_EXPANSION_DISTANCE: float = 4.5

const GOOD_COLOR := Color(0.05, 0.80, 1.0, 1.0)
const EPIC_COLOR := Color(0.60, 0.22, 1.0, 1.0)
const PERFECT_COLOR := Color(0.82, 0.98, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.025, 0.018, 0.065, 0.98)
const STREAK_AMBER := Color(1.0, 0.52, 0.12, 1.0)
const STREAK_HIGHLIGHT := Color(1.0, 0.90, 0.55, 1.0)

var _active_segments: int = 0
var _quality: String = "GOOD"
var _streak_sweep_progress: float = 0.0
var _streak_sweep_strength: float = 0.0
var _streak_expansion: float = 0.0
var _streak_sweep_tween: Tween = null
var _streak_strength_tween: Tween = null
var _streak_expansion_tween: Tween = null


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
		0.56
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


func _draw() -> void:
	if _active_segments <= 0:
		return

	var radius: float = RING_RADIUS + _streak_expansion * STREAK_EXPANSION_DISTANCE
	var segment_color: Color = _get_quality_color()
	for segment_index in range(_active_segments):
		var start_angle: float = -PI * 0.5 + float(segment_index) * SEGMENT_STEP + SEGMENT_GAP * 0.5
		var end_angle: float = start_angle + SEGMENT_STEP - SEGMENT_GAP
		# The dark stroke hugs each segment itself, protecting the colored edge
		# from any skin hue without creating a broad dark track under the ring.
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, ARC_POINTS, OUTLINE_COLOR, OUTLINE_WIDTH, true)
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, ARC_POINTS, segment_color, RING_WIDTH, true)

	if _streak_sweep_strength <= 0.001:
		return

	var sweep_length: float = 1.34
	var sweep_center: float = -PI * 0.5 + TAU * _streak_sweep_progress
	var sweep_start: float = sweep_center - sweep_length * 0.5
	var sweep_end: float = sweep_center + sweep_length * 0.5
	var streak_radius: float = radius + 0.15
	draw_arc(
		Vector2.ZERO,
		streak_radius,
		sweep_start,
		sweep_end,
		ARC_POINTS,
		Color(OUTLINE_COLOR.r, OUTLINE_COLOR.g, OUTLINE_COLOR.b, 0.98 * _streak_sweep_strength),
		7.4,
		true
	)
	draw_arc(
		Vector2.ZERO,
		streak_radius,
		sweep_start,
		sweep_end,
		ARC_POINTS,
		Color(STREAK_AMBER.r, STREAK_AMBER.g, STREAK_AMBER.b, 0.98 * _streak_sweep_strength),
		4.5,
		true
	)
	draw_arc(
		Vector2.ZERO,
		streak_radius,
		sweep_start,
		sweep_end,
		ARC_POINTS,
		Color(STREAK_HIGHLIGHT.r, STREAK_HIGHLIGHT.g, STREAK_HIGHLIGHT.b, 0.94 * _streak_sweep_strength),
		1.2,
		true
	)
