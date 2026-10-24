extends Control

## Brief, grade-tinted electrical fragments around Epic and Perfect landing labels.
## The strands flare from the word, fork slightly, then dissolve; there are no
## dot particles or screen-wide effects.

const FRAGMENT_ANGLES: Array[float] = [-2.65, -1.72, -0.78, 0.20, 2.72, 1.95]

var _label: Label
var _quality: String = "EPIC"
var _quality_color: Color = Color(0.92, 0.12, 1.0, 1.0)
var _elapsed: float = 0.0
var _duration: float = 0.30
var _fragment_count: int = 3
var _seed_offset: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = get_parent() as Label
	_seed_offset = float(get_instance_id() % 991) * 0.017
	visible = false
	set_process(false)


func configure(quality: String, quality_color: Color) -> void:
	_quality = quality
	_quality_color = quality_color
	if quality == "PERFECT":
		_fragment_count = 5
		_duration = 0.38
	else:
		_fragment_count = 3
		_duration = 0.30
	_elapsed = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		visible = false
		set_process(false)
		return
	queue_redraw()


func _draw() -> void:
	if _label == null or not is_instance_valid(_label):
		return
	if _elapsed >= _duration:
		return

	var font: Font = _label.get_theme_font("font")
	if font == null:
		return
	var font_size: int = _label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(
		_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
	).x
	text_width = minf(text_width, _label.size.x)
	var text_left: float = (_label.size.x - text_width) * 0.5
	var word_center := Vector2(
		text_left + text_width * 0.5,
		size.y * 0.5
	)
	var is_perfect: bool = _quality == "PERFECT"
	var base_length: float = 14.0 if is_perfect else 10.0

	for fragment_index in range(_fragment_count):
		var start_delay: float = float(fragment_index % 3) * 0.018
		var local_time: float = _elapsed - start_delay
		if local_time < 0.0:
			continue
		var life: float = _duration - start_delay
		var progress: float = clampf(local_time / life, 0.0, 1.0)
		var ramp: float = clampf(progress / 0.12, 0.0, 1.0)
		var visibility: float = ramp * pow(1.0 - progress, 1.25)
		if visibility <= 0.015:
			continue

		var seed: float = _seed_offset + float(fragment_index) * 17.23
		var angle: float = FRAGMENT_ANGLES[fragment_index]
		angle += sin(_elapsed * 13.0 + seed) * 0.035
		var direction := Vector2(cos(angle), sin(angle))
		var perpendicular := Vector2(-direction.y, direction.x)
		var anchor := word_center + Vector2(
			cos(angle) * text_width * 0.18,
			sin(angle) * float(font_size) * 0.20
		)
		var distance: float = base_length * (0.78 + _random01(seed + 2.4) * 0.40)
		var travel: float = distance * (1.0 - pow(1.0 - progress, 2.0))
		var middle := anchor + direction * travel * 0.52
		middle += perpendicular * sin(_elapsed * 17.0 + seed) * travel * 0.13
		var tip := anchor + direction * travel
		tip += perpendicular * sin(_elapsed * 19.0 + seed * 1.4) * travel * 0.08
		var points := PackedVector2Array([anchor, middle, tip])
		_draw_filament(points, visibility, is_perfect, seed)

		# Perfect gets a few short forks that make the burst feel more electric,
		# without adding round particles or a large radial explosion.
		if is_perfect and fragment_index % 2 == 0:
			var fork_anchor: Vector2 = middle
			var fork_tip: Vector2 = middle + perpendicular * distance * 0.34 * (1.0 - progress * 0.25)
			fork_tip += direction * distance * 0.10
			var fork_points := PackedVector2Array([
				fork_anchor,
				fork_anchor.lerp(fork_tip, 0.55) + direction * 1.5,
				fork_tip
			])
			_draw_filament(fork_points, visibility * 0.56, true, seed + 7.0)


func _draw_filament(
	points: PackedVector2Array,
	visibility: float,
	is_perfect: bool,
	seed: float
) -> void:
	if points.size() < 2:
		return
	var glow_color := Color(
		_quality_color.r, _quality_color.g, _quality_color.b,
		(0.24 if is_perfect else 0.18) * visibility
	)
	var core_color := _quality_color.lerp(Color.WHITE, 0.74 if is_perfect else 0.58)
	core_color.a = (0.88 if is_perfect else 0.76) * visibility
	for segment in range(1, points.size()):
		var segment_progress: float = float(segment) / float(points.size() - 1)
		var shimmer: float = 0.78 + 0.22 * absf(
			sin(_elapsed * 27.0 + seed + float(segment) * 2.7)
		)
		var segment_alpha: float = visibility * shimmer
		var glow := glow_color
		glow.a *= shimmer
		var core := core_color
		core.a *= shimmer
		draw_line(
			points[segment - 1], points[segment], glow,
			1.8 if is_perfect else 1.45, true
		)
		draw_line(
			points[segment - 1], points[segment], core,
			lerpf(0.85, 0.48, segment_progress), true
		)


func _random01(value: float) -> float:
	var raw: float = sin(value * 127.1 + 19.19) * 43758.5453
	return raw - floor(raw)
