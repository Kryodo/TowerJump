extends Control

## Open geometric rails that merge into the landing-grade typography.
## The center backing is intentionally subtle; the animated rails extend through
## the word's width so the grade reads as one continuous neon composition.

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
			_duration = 0.40
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

	var text_width: float = 58.0
	if grade_label != null and is_instance_valid(grade_label):
		var font: Font = grade_label.get_theme_font("font")
		if font != null:
			text_width = font.get_string_size(
				grade_label.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				grade_label.get_theme_font_size("font_size")
			).x

	# Every word gets geometry based on its real rendered width. The central
	# backing is narrow, while the rails reach through and slightly beyond the
	# letters. This keeps the emblem from reading as a separate badge.
	var is_epic: bool = _quality == "EPIC"
	var is_perfect: bool = _quality == "PERFECT"
	var half_text: float = minf(text_width * 0.5, size.x * 0.40)
	var outer_half: float = minf(half_text + 7.0, size.x * 0.47)
	var core_half: float = maxf(half_text * 0.34, 12.0)
	var half_height: float = 4.5 if not is_epic and not is_perfect else (5.0 if is_epic else 5.6)
	var center := Vector2(size.x * 0.5, size.y * 0.5)

	# A low-opacity center facet provides depth without creating an opaque plate.
	var backing := PackedVector2Array([
		Vector2(center.x - core_half, center.y - half_height),
		Vector2(center.x + core_half, center.y - half_height),
		Vector2(center.x + core_half + 2.5, center.y),
		Vector2(center.x + core_half, center.y + half_height),
		Vector2(center.x - core_half, center.y + half_height),
		Vector2(center.x - core_half - 2.5, center.y),
	])
	var backing_color := Color(0.006, 0.014, 0.032, 0.28 if not is_perfect else 0.36)
	draw_colored_polygon(backing, backing_color)

	# Upper and lower rails are continuous angular paths. They start outside
	# the text bounds, sweep inward around the central facet, then reconnect
	# across the middle where the letter shapes break up the line naturally.
	var left_outer: float = center.x - outer_half
	var right_outer: float = center.x + outer_half
	var left_text: float = center.x - half_text
	var right_text: float = center.x + half_text
	var left_core: float = center.x - core_half
	var right_core: float = center.x + core_half
	var center_rail_y: float = 1.2 if not is_perfect else 1.0

	var top_rail := PackedVector2Array([
		Vector2(left_outer, center.y + 1.8),
		Vector2(left_text + 2.0, center.y - half_height),
		Vector2(left_core, center.y - half_height),
		Vector2(left_core + 3.0, center.y - center_rail_y),
		Vector2(right_core - 3.0, center.y - center_rail_y),
		Vector2(right_core, center.y - half_height),
		Vector2(right_text - 2.0, center.y - half_height),
		Vector2(right_outer, center.y + 1.8),
	])
	var bottom_rail := PackedVector2Array()
	for point in top_rail:
		bottom_rail.append(Vector2(point.x, center.y * 2.0 - point.y))

	var glow_alpha: float = 0.18 if not is_epic and not is_perfect else (0.24 if is_epic else 0.31)
	var core_alpha: float = 0.72 if not is_epic and not is_perfect else (0.84 if is_epic else 0.96)
	var rail_core_color: Color = _quality_color.lerp(
		Color.WHITE,
		0.12 if not is_epic and not is_perfect else (0.38 if is_epic else 0.80)
	)
	_draw_rail(top_rail, rail_core_color, glow_alpha, core_alpha)
	_draw_rail(bottom_rail, rail_core_color, glow_alpha, core_alpha)

	# Open-ended cuts anchor the rails at the word's edges without enclosing it.
	var cut_color: Color = rail_core_color
	cut_color.a = core_alpha
	draw_line(
		Vector2(left_outer + 0.8, center.y - 2.6),
		Vector2(left_outer + 3.0, center.y + 2.8),
		cut_color,
		0.85,
		true
	)
	draw_line(
		Vector2(right_outer - 0.8, center.y - 2.6),
		Vector2(right_outer - 3.0, center.y + 2.8),
		cut_color,
		0.85,
		true
	)

	# The sweep passes through the open rails and remains behind the glyphs.
	if _elapsed < _duration and _elapsed >= 0.025:
		var sweep_progress: float = clampf(
			(_elapsed - 0.025) / maxf(_duration - 0.025, 0.01),
			0.0,
			1.0
		)
		var sweep_gate: float = sin(sweep_progress * PI)
		var sweep_x: float = lerpf(
			left_outer + 2.0,
			right_outer - 2.0,
			sweep_progress
		)
		var sweep_strength: float = 0.40 if not is_epic and not is_perfect else (0.64 if is_epic else 0.88)
		var sweep_color: Color = _quality_color.lerp(Color.WHITE, 0.82)
		sweep_color.a = sweep_strength * sweep_gate
		var glow_color := sweep_color
		glow_color.a *= 0.24
		draw_line(
			Vector2(sweep_x - 2.6, center.y - half_height - 1.0),
			Vector2(sweep_x + 2.6, center.y + half_height + 1.0),
			glow_color,
			3.2,
			true
		)
		draw_line(
			Vector2(sweep_x - 1.0, center.y - half_height - 0.6),
			Vector2(sweep_x + 1.0, center.y + half_height + 0.6),
			sweep_color,
			1.0,
			true
		)

	# Epic adds shoulder cuts; Perfect gets a fine inner trace and terminal
	# diamonds. The outer silhouette remains part of the same continuous rails.
	if is_epic:
		var detail_color: Color = _quality_color.lerp(Color.WHITE, 0.62)
		detail_color.a = 0.82
		var shoulder_x: float = half_text * 0.68
		draw_line(
			Vector2(center.x - shoulder_x - 1.5, center.y - half_height + 0.2),
			Vector2(center.x - shoulder_x + 1.8, center.y - 1.6),
			detail_color,
			0.85,
			true
		)
		draw_line(
			Vector2(center.x + shoulder_x + 1.5, center.y - half_height + 0.2),
			Vector2(center.x + shoulder_x - 1.8, center.y - 1.6),
			detail_color,
			0.85,
			true
		)
	elif is_perfect:
		var inset_color: Color = _quality_color.lerp(Color.WHITE, 0.86)
		inset_color.a = 0.76
		draw_line(
			Vector2(left_core + 3.6, center.y - half_height + 1.7),
			Vector2(right_core - 3.6, center.y - half_height + 1.7),
			inset_color,
			0.65,
			true
		)
		_draw_diamond(Vector2(left_outer + 3.5, center.y + 1.8), 1.3, inset_color)
		_draw_diamond(Vector2(right_outer - 3.5, center.y + 1.8), 1.3, inset_color)


func _draw_rail(
	points: PackedVector2Array,
	core_color: Color,
	glow_alpha: float,
	core_alpha: float
) -> void:
	var glow_color: Color = core_color
	glow_color.a = glow_alpha
	draw_polyline(points, glow_color, 2.8, true)
	var line_color: Color = core_color
	line_color.a = core_alpha
	draw_polyline(points, line_color, 0.95, true)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(points, color)
