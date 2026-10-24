extends Control

## A single filled geometric flash behind the landing grade.
## There are no outlines or rails to compete with the lettering: the silhouette
## expands quickly, gives one soft quality-colored flash, then settles to a
## very faint tint so the word remains the clear focal point.

var _quality: String = "GOOD"
var _quality_color: Color = Color(0.40, 0.86, 1.0, 1.0)
var _elapsed: float = 0.0
var _flash_duration: float = 0.17
var _processing_duration: float = 0.30


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func configure(quality: String, quality_color: Color) -> void:
	_quality = quality
	_quality_color = quality_color
	match _quality:
		"EPIC":
			_flash_duration = 0.20
			_processing_duration = 0.24
		"PERFECT":
			_flash_duration = 0.23
			_processing_duration = 0.28
		_:
			_flash_duration = 0.17
			_processing_duration = 0.21
	_elapsed = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _processing_duration:
		_elapsed = _processing_duration
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

	var is_epic: bool = _quality == "EPIC"
	var is_perfect: bool = _quality == "PERFECT"
	var center := Vector2(size.x * 0.5, size.y * 0.5)

	# Adapt the flash to the rendered word, but keep it slightly narrower so
	# the text overhangs the silhouette instead of appearing inside a badge.
	var half_text_width: float = minf(text_width * 0.5, size.x * 0.42)
	var half_width: float = minf(half_text_width * 0.93, size.x * 0.46)
	var half_height: float = 5.3 if not is_epic and not is_perfect else (6.0 if is_epic else 6.8)

	# A fast horizontal expansion creates the impact. Once expanded, the
	# silhouette stays still while the light peaks and quickly recedes.
	var expansion_progress: float = clampf(_elapsed / 0.095, 0.0, 1.0)
	var expansion_eased: float = 1.0 - pow(1.0 - expansion_progress, 3.0)
	var expansion: float = lerpf(0.68, 1.0, expansion_eased)
	half_width *= expansion
	half_height *= lerpf(0.72, 1.0, expansion_eased)

	var shape_points := _build_flash_shape(
		center, half_width, half_height, is_epic, is_perfect
	)

	var flash_progress: float = clampf(_elapsed / maxf(_flash_duration, 0.01), 0.0, 1.0)
	var flash_envelope: float = sin(flash_progress * PI)
	var idle_alpha: float = 0.030 if not is_epic and not is_perfect else (0.038 if is_epic else 0.044)
	var peak_alpha: float = 0.15 if not is_epic and not is_perfect else (0.18 if is_epic else 0.21)
	var fill_color: Color = _quality_color.lerp(
		Color.WHITE,
		0.0 if not is_epic and not is_perfect else (0.12 if is_epic else 0.48)
	)
	fill_color.a = idle_alpha + peak_alpha * flash_envelope
	draw_colored_polygon(shape_points, fill_color)


func _build_flash_shape(
	center: Vector2,
	half_width: float,
	half_height: float,
	is_epic: bool,
	is_perfect: bool
) -> PackedVector2Array:
	var points := PackedVector2Array()

	if is_perfect:
		# The top tier gets a broader, faceted energy flare—but still one solid fill.
		points.append(Vector2(center.x - half_width, center.y))
		points.append(Vector2(center.x - half_width * 0.82, center.y - half_height * 0.44))
		points.append(Vector2(center.x - half_width * 0.68, center.y - half_height))
		points.append(Vector2(center.x - half_width * 0.28, center.y - half_height * 0.78))
		points.append(Vector2(center.x + half_width * 0.28, center.y - half_height * 0.78))
		points.append(Vector2(center.x + half_width * 0.68, center.y - half_height))
		points.append(Vector2(center.x + half_width * 0.82, center.y - half_height * 0.44))
		points.append(Vector2(center.x + half_width, center.y))
		points.append(Vector2(center.x + half_width * 0.82, center.y + half_height * 0.44))
		points.append(Vector2(center.x + half_width * 0.68, center.y + half_height))
		points.append(Vector2(center.x + half_width * 0.28, center.y + half_height * 0.78))
		points.append(Vector2(center.x - half_width * 0.28, center.y + half_height * 0.78))
		points.append(Vector2(center.x - half_width * 0.68, center.y + half_height))
		points.append(Vector2(center.x - half_width * 0.82, center.y + half_height * 0.44))
	elif is_epic:
		# Epic has a sharper shoulder cut than Good, without adding linework.
		points.append(Vector2(center.x - half_width, center.y))
		points.append(Vector2(center.x - half_width * 0.78, center.y - half_height * 0.54))
		points.append(Vector2(center.x - half_width * 0.42, center.y - half_height))
		points.append(Vector2(center.x + half_width * 0.68, center.y - half_height))
		points.append(Vector2(center.x + half_width * 0.84, center.y - half_height * 0.42))
		points.append(Vector2(center.x + half_width, center.y))
		points.append(Vector2(center.x + half_width * 0.84, center.y + half_height * 0.42))
		points.append(Vector2(center.x + half_width * 0.68, center.y + half_height))
		points.append(Vector2(center.x - half_width * 0.42, center.y + half_height))
		points.append(Vector2(center.x - half_width * 0.78, center.y + half_height * 0.54))
	else:
		# Good stays a simple, low-profile elongated hex flash.
		points.append(Vector2(center.x - half_width, center.y))
		points.append(Vector2(center.x - half_width * 0.78, center.y - half_height))
		points.append(Vector2(center.x + half_width * 0.78, center.y - half_height))
		points.append(Vector2(center.x + half_width, center.y))
		points.append(Vector2(center.x + half_width * 0.78, center.y + half_height))
		points.append(Vector2(center.x - half_width * 0.78, center.y + half_height))

	return points
