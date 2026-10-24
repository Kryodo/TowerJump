extends Control

## Static filled geometry behind the landing grade.
## The parent grade composition owns all motion, entrance scaling, rotation,
## and fading so the shape always behaves as part of the word, not a separate flash.

var _quality: String = "GOOD"
var _quality_color: Color = Color(0.40, 0.86, 1.0, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func configure(quality: String, quality_color: Color) -> void:
	_quality = quality
	_quality_color = quality_color
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

	# Let the word overhang the colored silhouette slightly, avoiding a badge-like frame.
	var half_text_width: float = minf(text_width * 0.5, size.x * 0.42)
	# Give the silhouette short horizontal wings beyond the word, while leaving
	# the outlined lettering free to overhang its top and bottom edges.
	var half_width: float = minf(half_text_width + 7.0, size.x * 0.46)
	# The parent places this control's center on the label center, so these
	# shallow heights keep the word visibly taller than its colored backdrop.
	var half_height: float = 4.8 if not is_epic and not is_perfect else (5.6 if is_epic else 6.8)

	var shape_points := _build_flash_shape(
		center, half_width, half_height, is_epic, is_perfect
	)

	var fill_color: Color = _quality_color.lerp(
		Color.WHITE,
		0.16 if not is_epic and not is_perfect else (0.30 if is_epic else 0.58)
	)
	# This remains visible beneath the outlined lettering for the entire reward life.
	# The composition's shared alpha fade controls its disappearance along with the text.
	fill_color.a = 0.24 if not is_epic and not is_perfect else (0.31 if is_epic else 0.40)
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
		# Perfect has a broad, faceted flare, still a single solid shape.
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
		# Epic is a balanced, faceted step between Good's simple hex and
		# Perfect's more intricate inward-cut facets.
		points.append(Vector2(center.x - half_width, center.y))
		points.append(Vector2(center.x - half_width * 0.76, center.y - half_height * 0.48))
		points.append(Vector2(center.x - half_width * 0.48, center.y - half_height))
		points.append(Vector2(center.x + half_width * 0.48, center.y - half_height))
		points.append(Vector2(center.x + half_width * 0.76, center.y - half_height * 0.48))
		points.append(Vector2(center.x + half_width, center.y))
		points.append(Vector2(center.x + half_width * 0.76, center.y + half_height * 0.48))
		points.append(Vector2(center.x + half_width * 0.48, center.y + half_height))
		points.append(Vector2(center.x - half_width * 0.48, center.y + half_height))
		points.append(Vector2(center.x - half_width * 0.76, center.y + half_height * 0.48))
	else:
		# Good stays a simple, low-profile elongated hex.
		points.append(Vector2(center.x - half_width, center.y))
		points.append(Vector2(center.x - half_width * 0.78, center.y - half_height))
		points.append(Vector2(center.x + half_width * 0.78, center.y - half_height))
		points.append(Vector2(center.x + half_width, center.y))
		points.append(Vector2(center.x + half_width * 0.78, center.y + half_height))
		points.append(Vector2(center.x - half_width * 0.78, center.y + half_height))

	return points
