extends Control

## Compact geometric banner behind the landing-grade typography.
## The silhouette stays restrained for GOOD, gains angular rails for EPIC,
## and gets a double outline plus wing accents for PERFECT. A light sweep
## travels through the banner during the grade's entrance, then leaves a clean
## static emblem to fade with the rest of the reward cluster.

var _quality: String = "GOOD"
var _quality_color: Color = Color(0.40, 0.86, 1.0, 1.0)
var _elapsed: float = 0.0
var _duration: float = 0.31


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func configure(quality: String, quality_color: Color) -> void:
	_quality = quality
	_quality_color = quality_color
	match _quality:
		"EPIC":
			_duration = 0.43
		"PERFECT":
			_duration = 0.54
		_:
			_duration = 0.31
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

	var is_epic: bool = _quality == "EPIC"
	var is_perfect: bool = _quality == "PERFECT"
	var half_width: float = 41.0 if not is_epic and not is_perfect else (46.0 if is_epic else 51.0)
	var half_height: float = 7.6 if not is_perfect else 8.8
	var tip_length: float = 7.5 if not is_epic and not is_perfect else (9.5 if is_epic else 12.0)
	var center := Vector2(size.x * 0.5, size.y * 0.5)

	# The shape opens horizontally with the grade instead of appearing as a
	# finished static UI plate. Its center remains aligned with the word.
	var entrance_progress: float = clampf(_elapsed / 0.14, 0.0, 1.0)
	var entrance_ease: float = 1.0 - pow(1.0 - entrance_progress, 3.0)
	var reveal: float = clampf(entrance_ease, 0.0, 1.0)
	half_width *= lerpf(0.86, 1.0, reveal)
	half_height *= lerpf(0.72, 1.0, reveal)

	var banner_points := _make_banner_points(center, half_width, half_height, tip_length)
	var fill_color := Color(0.006, 0.014, 0.032, 0.78 * reveal)
	draw_colored_polygon(banner_points, fill_color)

	# A narrow, slanted light pass cuts through the emblem rather than spraying
	# independent particles around the word. Higher grades get a brighter pass.
	var sweep_start_delay: float = 0.055
	if _elapsed >= sweep_start_delay and _elapsed < _duration:
		var sweep_progress: float = clampf(
			(_elapsed - sweep_start_delay) / maxf(_duration - sweep_start_delay, 0.01),
			0.0,
			1.0
		)
		var sweep_gate: float = sin(sweep_progress * PI)
		var sweep_x: float = lerpf(
			center.x - half_width + tip_length + 1.0,
			center.x + half_width - tip_length - 1.0,
			sweep_progress
		)
		var sweep_strength: float = 0.34 if not is_epic and not is_perfect else (0.54 if is_epic else 0.78)
		var sweep_color: Color = _quality_color.lerp(Color(0.86, 0.98, 1.0, 1.0), 0.72)
		sweep_color.a = sweep_strength * sweep_gate
		var beam_glow := _make_sweep_points(sweep_x, center.y, half_height - 1.6, 8.0)
		var glow_color := sweep_color
		glow_color.a *= 0.24
		draw_colored_polygon(beam_glow, glow_color)
		var beam_core := _make_sweep_points(sweep_x, center.y, half_height - 1.9, 2.2)
		draw_colored_polygon(beam_core, sweep_color)

	var outline_points := _close_points(banner_points)
	var outline_glow: Color = _quality_color
	outline_glow.a = 0.20 * reveal
	draw_polyline(outline_points, outline_glow, 3.0, true)
	var outline_core: Color = _quality_color
	outline_core.a = (0.78 if not is_perfect else 0.92) * reveal
	draw_polyline(outline_points, outline_core, 1.15, true)

	# EPIC and PERFECT share the same banner language as GOOD, but gain a fine
	# inset rail so their silhouettes feel more deliberate without getting busy.
	if is_epic or is_perfect:
		var inner_points := _make_banner_points(
			center,
			half_width - 3.4,
			half_height - 2.5,
			maxf(tip_length - 2.4, 4.0)
		)
		var inner_color: Color = _quality_color.lerp(Color.WHITE, 0.42 if is_epic else 0.72)
		inner_color.a = (0.48 if is_epic else 0.70) * reveal
		draw_polyline(_close_points(inner_points), inner_color, 0.75, true)

	if is_epic:
		# Small paired chevrons live at the banner shoulders, outside the word.
		var chevron_color: Color = _quality_color.lerp(Color.WHITE, 0.56)
		chevron_color.a = 0.78 * reveal
		var chevron_offset: float = half_width - tip_length - 3.4
		_draw_chevron(Vector2(center.x - chevron_offset, center.y), -1.0, chevron_color)
		_draw_chevron(Vector2(center.x + chevron_offset, center.y), 1.0, chevron_color)
	elif is_perfect:
		# Tiny wing diamonds make the top tier feel crafted, not simply brighter.
		var wing_color: Color = _quality_color.lerp(Color.WHITE, 0.82)
		wing_color.a = 0.90 * reveal
		var wing_offset: float = half_width - tip_length * 0.53
		_draw_diamond(Vector2(center.x - wing_offset, center.y), 1.8, wing_color)
		_draw_diamond(Vector2(center.x + wing_offset, center.y), 1.8, wing_color)


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


func _draw_chevron(center: Vector2, direction: float, color: Color) -> void:
	var first := center + Vector2(-direction * 2.0, -3.0)
	var point := center + Vector2(direction * 1.0, 0.0)
	var last := center + Vector2(-direction * 2.0, 3.0)
	draw_line(first, point, color, 0.9, true)
	draw_line(point, last, color, 0.9, true)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(points, color)
