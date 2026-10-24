extends Control

## Fine, short-lived electrical filaments for Epic and Perfect landing grades.
## This is a sibling layer, not a child of the animated grade label: its strokes
## stay hairline-thin while the text itself compresses, overshoots and rotates.

const EPIC_ANGLES: Array[float] = [-2.55, -1.28, 0.08, 1.42, 2.70]
const PERFECT_ANGLES: Array[float] = [-2.70, -1.92, -0.82, 0.08, 0.78, 1.78, 2.74]

var _label: Label
var _quality: String = "EPIC"
var _quality_color: Color = Color(0.92, 0.12, 1.0, 1.0)
var _elapsed: float = 0.0
var _duration: float = 0.44
var _seed_offset: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed_offset = float(get_instance_id() % 991) * 0.013
	var root := get_parent()
	if root != null:
		_label = root.get_node_or_null("LandingGrade") as Label
	visible = false
	set_process(false)


func configure(quality: String, quality_color: Color) -> void:
	_quality = quality
	_quality_color = quality_color
	_duration = 0.54 if quality == "PERFECT" else 0.44
	_elapsed = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _label == null or not is_instance_valid(_label):
		queue_free()
		return

	# Track only the label's center position. Never copy its scale or rotation.
	position = _label.position + Vector2(-4.0, -3.0)
	if _elapsed >= _duration:
		visible = false
		set_process(false)
		return
	queue_redraw()


func _draw() -> void:
	if _label == null or not is_instance_valid(_label) or _elapsed >= _duration:
		return

	var font: Font = _label.get_theme_font("font")
	if font == null:
		return
	var font_size: int = _label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(
		_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
	).x
	text_width = minf(text_width, _label.size.x)
	if text_width <= 1.0:
		return

	# The effect sits 4 px outside the word horizontally and 3 px vertically.
	# Coordinates are in this sibling layer, whose origin is offset from the label.
	var text_left: float = (_label.size.x - text_width) * 0.5 + 4.0
	var text_top: float = (size.y - float(font_size)) * 0.5
	var word_center := Vector2(text_left + text_width * 0.5, size.y * 0.5)
	var filament_bounds := Rect2(
		Vector2(text_left - 4.0, text_top - 3.0),
		Vector2(text_width + 8.0, float(font_size) + 6.0)
	)
	var is_perfect: bool = _quality == "PERFECT"
	var angles: Array[float] = PERFECT_ANGLES if is_perfect else EPIC_ANGLES
	var strand_length: float = 17.0 if is_perfect else 13.5
	var branch_count: int = 2 if is_perfect else 1

	for strand_index in range(angles.size()):
		var strand_delay: float = float(strand_index % 3) * 0.024
		var local_age: float = _elapsed - strand_delay
		if local_age < 0.0:
			continue

		var strand_life: float = maxf(_duration - strand_delay, 0.01)
		var progress: float = clampf(local_age / strand_life, 0.0, 1.0)
		var reveal: float = clampf(progress / 0.22, 0.0, 1.0)
		var fade: float = pow(1.0 - progress, 0.82)
		var flicker: float = 0.72 + 0.28 * absf(
			sin(_elapsed * 25.0 + _seed_offset + float(strand_index) * 5.7)
		)
		var energy: float = reveal * fade * flicker
		if energy <= 0.012:
			continue

		var seed: float = _seed_offset + float(strand_index) * 19.37
		var angle: float = angles[strand_index]
		angle += sin(_elapsed * 14.0 + seed) * 0.045
		var direction := Vector2(cos(angle), sin(angle)).normalized()
		var anchor := word_center + Vector2(
			cos(angle) * text_width * 0.39,
			sin(angle) * float(font_size) * 0.24
		)
		var length_variation: float = 0.78 + _random01(seed + 2.1) * 0.42
		var live_length: float = strand_length * length_variation * reveal
		var main_points := _build_filament(
			anchor, direction, live_length, seed, 2.25
		)
		main_points = _clamp_filament_points(main_points, filament_bounds)
		_draw_tapered_filament(main_points, energy, seed, 1.0, is_perfect)

		# Tiny offshoots fork at uneven points and angles, like live current—not
		# rigid V-shaped shards. Perfect gets a couple more delicate hairline forks.
		for branch_index in range(branch_count):
			var attach_index: int = 2 if branch_index == 0 else 3
			if attach_index >= main_points.size() - 1:
				continue
			var fork_point: Vector2 = main_points[attach_index]
			var side: float = -1.0 if _random01(seed + 8.2 + float(branch_index)) < 0.5 else 1.0
			var fork_angle: float = side * (0.72 + _random01(seed + 9.6 + float(branch_index)) * 0.58)
			var fork_direction: Vector2 = direction.rotated(fork_angle).normalized()
			var fork_length: float = live_length * (
				(0.43 if is_perfect else 0.37) + _random01(seed + 11.4) * 0.12
			)
			var fork_points := _build_filament(
				fork_point, fork_direction, fork_length,
				seed + 13.0 + float(branch_index) * 3.7, 1.25
			)
			fork_points = _clamp_filament_points(fork_points, filament_bounds)
			_draw_tapered_filament(
				fork_points, energy * (0.70 if is_perfect else 0.58),
				seed + float(branch_index) * 2.3, 0.72, is_perfect
			)


func _build_filament(
	start: Vector2,
	direction: Vector2,
	length: float,
	seed: float,
	jaggedness: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	if length <= 0.5:
		return points

	var perpendicular := Vector2(-direction.y, direction.x)
	var point_count: int = 5
	for point_index in range(point_count):
		var t: float = float(point_index) / float(point_count - 1)
		var distance: float = length * t
		var displacement: float = 0.0
		if point_index > 0 and point_index < point_count - 1:
			var random_offset: float = _random01(
				seed + float(point_index) * 4.73
			) - 0.5
			var live_wobble: float = sin(
				_elapsed * 31.0 + seed + float(point_index) * 3.9
			) * 0.45
			displacement = random_offset * jaggedness * 2.0 + live_wobble
		var point := start + direction * distance + perpendicular * displacement
		points.append(point)
	return points


func _clamp_filament_points(
	points: PackedVector2Array,
	bounds: Rect2
) -> PackedVector2Array:
	var clamped_points := PackedVector2Array()
	for point in points:
		clamped_points.append(Vector2(
			clampf(point.x, bounds.position.x, bounds.end.x),
			clampf(point.y, bounds.position.y, bounds.end.y)
		))
	return clamped_points


func _draw_tapered_filament(
	points: PackedVector2Array,
	energy: float,
	seed: float,
	width_scale: float,
	is_perfect: bool
) -> void:
	if points.size() < 2 or energy <= 0.012:
		return

	var glow_color := Color(
		_quality_color.r, _quality_color.g, _quality_color.b,
		(0.19 if is_perfect else 0.16) * energy
	)
	var core_color := _quality_color.lerp(Color.WHITE, 0.76 if is_perfect else 0.67)
	core_color.a = (0.88 if is_perfect else 0.78) * energy

	for segment_index in range(1, points.size()):
		var t: float = float(segment_index) / float(points.size() - 1)
		var taper: float = 1.0 - t * 0.62
		var shimmer: float = 0.78 + 0.22 * absf(
			sin(_elapsed * 29.0 + seed + float(segment_index) * 4.1)
		)
		var glow := glow_color
		glow.a *= shimmer
		var core := core_color
		core.a *= shimmer
		draw_line(
			points[segment_index - 1], points[segment_index],
			glow, (1.30 * taper) * width_scale, true
		)
		draw_line(
			points[segment_index - 1], points[segment_index],
			core, (0.66 * taper) * width_scale, true
		)


func _random01(value: float) -> float:
	var raw: float = sin(value * 127.1 + 19.19) * 43758.5453
	return raw - floor(raw)
