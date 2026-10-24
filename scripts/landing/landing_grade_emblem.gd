extends Control

## A compact geometric backdrop behind the landing grade.
## Its silhouette remains fixed while the text moves and scales over it.
## A single light sweep and tier-specific edge details give the banner energy
## without turning it into a frame that encloses the whole word.

var _quality: String = "GOOD"
var _quality_color: Color = Color(0.40, 0.86, 1.0, 1.0)
var _elapsed: float = 0.0
var _duration: float = 0.30


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func configure(quality: String, quality_color: Color) -> void:
	_quality = quality
	_quality_color = quality_color
	match _quality:
		"EPIC":
			_duration = 0.39
		"PERFECT":
			_duration = 0.48
		_:
			_duration = 0.30
	_elapsed = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		_elapsed = _duration
		queue_redraw()
		set_process(false)
		return
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var grade_label: Label = null
	var parent := get_parent()
	if parent != null:
		grade_label = parent.get_node_or_null("LandingGrade") as Label

	var text_width: float = 64.0
	if grade_label != null and is_instance_valid(grade_label):
		var font: Font = grade_label.get_theme_font("font")
		if font != null:
			text_width = font.get_string_size(
				grade_label.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				grade_label.get_theme_font_size("font_size")
			).x

	var is_epic: bool = _quality == "EPIC"
	var is_perfect: bool = _quality == "PERFECT"
	# The body is intentionally narrower than the word: letters overhang it
	# horizontally and vertically, making this a backing accent rather than a box.
	var width_ratio: float = 0.76 if is_epic else (0.82 if is_perfect else 0.80)
	var half_width: float = maxf(text_width * width_ratio * 0.5, 15.0)
	var half_height: float = 5.0 if not is_epic and not is_perfect else (5.7 if is_epic else 6.2)
	var tip_length: float = minf(half_width * 0.30, 9.0 if is_perfect else 7.0)
	var center := Vector2(size.x * 0.5, size.y * 0.5)

	# Stable shape; only the light and a brief edge accent move.
	var banner_points := _make_banner_points(center, half_width, half_height, tip_length)
	var fill_color := Color(0.006, 0.014, 0.032, 0.82)
	draw_colored_polygon(banner_points, fill_color)

	var outline_points := _close_points(banner_points)
	var outline_glow: Color = _quality_color
	outline_glow.a = 0.24 if not is_perfect else 0.34
	draw_polyline(outline_points, outline_glow, 3.0, true)
	var outline_core: Color = _quality_color.lerp(Color.WHITE, 0.12 if not is_epic and not is_perfect else 0.32)
	outline_core.a = 0.82 if not is_perfect else 0.96
	draw_polyline(_close_points(banner_points), outline_core, 1.05, true)

	# One compact highlight races across the background strip. Its intensity
	# changes by grade, but the emblem itself never scales to match the text.
	if _elapsed < _duration:
		var sweep_start: float = 0.025
		var sweep_progress: float = clampf(
			(_elapsed - sweep_start) / maxf(_duration - sweep_start, 0.01),
			0.0,
			1.0
		)
		if _elapsed >= sweep_start:
			var sweep_gate: float = sin(sweep_progress * PI)
			var sweep_x: float = lerpf(
				center.x - half_width + tip_length + 1.0,
				center.x + half_width - tip_length - 1.0,
				sweep_progress
			)
			var sweep_strength: float = 0.38 if not is_epic and not is_perfect else (0.60 if is_epic else 0.82)
			var sweep_color: Color = _quality_color.lerp(Color.WHITE, 0.78)
			sweep_color.a = sweep_strength * sweep_gate
			var beam_glow := _make_sweep_points(sweep_x, center.y, half_height - 1.1, 6.0)
			var glow_color := sweep_color
			glow_color.a *= 0.28
			draw_colored_polygon(beam_glow, glow_color)
			var beam_core := _make_sweep_points(sweep_x, center.y, half_height - 1.3, 1.6)
			draw_colored_polygon(beam_core, sweep_color)

	# The higher tiers get finer geometry along the rail, not a larger enclosure.
	if is_epic:
		var inset_color: Color = _quality_color.lerp(Color.WHITE, 0.55)
		inset_color.a = 0.82
		var tick_x: float = half_width * 0.48
		var tick_y: float = half_height - 1.2
		draw_line(
			Vector2(center.x - tick_x, center.y - tick_y),
			Vector2(center.x - tick_x + 3.0, center.y),
			inset_color, 0.8, true
		)
		draw_line(
			Vector2(center.x + tick_x, center.y - tick_y),
			Vector2(center.x + tick_x - 3.0, center.y),
			inset_color, 0.8, true
		)
	elif is_perfect:
		var inset_points := _make_banner_points(
			center,
			half_width - 3.0,
			half_height - 2.0,
			maxf(tip_length - 2.0, 3.0)
		)
		var inset_color: Color = _quality_color.lerp(Color.WHITE, 0.76)
		inset_color.a = 0.84
		draw_polyline(_close_points(inset_points), inset_color, 0.65, true)
		var accent_color := _quality_color.lerp(Color.WHITE, 0.90)
		accent_color.a = 0.90
		_draw_diamond(Vector2(center.x - half_width + tip_length, center.y), 1.35, accent_color)
		_draw_diamond(Vector2(center.x + half_width - tip_length, center.y), 1.35, accent_color)


func _make_banner_points(
	center: Vector2,
	half_width: float,
	half_height: float,
	tip_length: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2(center.x - half_width + tip_length, center.y - half_height))
	points.append(Vector2(center.x + half_width - tip_length, center.y - half_height))
	points.append(Vector2(center.x + half_width, center.y))
	points.append(Vector2(center.x + half_width - tip_length, center.y + half_height))
	points.append(Vector2(center.x - half_width + tip_length, center.y + half_height))
	points.append(Vector2(center.x - half_width, center.y))
	return points


func _close_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed


func _make_sweep_points(
	x: float,
	center_y: float,
	half_height: float,
	width: float
) -> PackedVector2Array:
	var slant: float = width * 0.72
	var points := PackedVector2Array()
	points.append(Vector2(x - width * 0.5, center_y - half_height))
	points.append(Vector2(x + width * 0.5, center_y - half_height))
	points.append(Vector2(x + width * 0.5 + slant, center_y + half_height))
	points.append(Vector2(x - width * 0.5 + slant, center_y + half_height))
	return points


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(points, color)
