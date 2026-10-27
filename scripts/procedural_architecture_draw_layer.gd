extends Node2D
## One depth layer for the procedural architecture experiment.
## Geometry is authored in tower-space. The parent manager scales and offsets this
## node against the camera to create genuine vertical parallax without textures.

enum LayerType {
	FAR_SILHOUETTES,
	MID_ARCHITECTURE,
	NEAR_FRAMES,
}

@export var layer_type: LayerType = LayerType.FAR_SILHOUETTES
@export var environment_seed: int = 7319
@export var world_width: float = 720.0
@export var section_top_y: float = -10400.0
@export var section_bottom_y: float = 1600.0

var _rng := RandomNumberGenerator.new()

const DARK_FILL := Color(0.008, 0.022, 0.050, 0.88)
const FAR_OUTLINE := Color(0.045, 0.20, 0.31, 0.40)
const MID_CYAN := Color(0.025, 0.42, 0.58, 0.52)
const MID_VIOLET := Color(0.25, 0.10, 0.42, 0.44)
const NEAR_CYAN := Color(0.025, 0.62, 0.78, 0.40)
const NEAR_VIOLET := Color(0.37, 0.15, 0.62, 0.40)


func _draw() -> void:
	_rng.seed = int(environment_seed) + int(layer_type) * 7919

	match layer_type:
		LayerType.FAR_SILHOUETTES:
			_draw_far_silhouettes()
			_draw_far_landmark_echo()
		LayerType.MID_ARCHITECTURE:
			_draw_mid_architecture()
			_draw_gate_landmark()
			_draw_discovery_glyph()
		LayerType.NEAR_FRAMES:
			_draw_near_frames()
			_draw_gate_accents()


func _draw_far_silhouettes() -> void:
	# Sparse distant lights. Their small scale and low contrast suggest a huge
	# environment rather than decorative particles around the player.
	for i in range(190):
		var point := Vector2(
			_rng.randf_range(-40.0, world_width + 40.0),
			_rng.randf_range(section_top_y, section_bottom_y)
		)
		var radius: float = _rng.randf_range(0.7, 2.1)
		var color := Color(0.20, 0.49, 0.67, _rng.randf_range(0.10, 0.42))
		if _rng.randf() < 0.18:
			color = Color(0.45, 0.23, 0.71, _rng.randf_range(0.12, 0.32))
		draw_circle(point, radius, color)

	var band_y: float = section_top_y + 90.0
	while band_y < section_bottom_y:
		for i in range(3):
			var x: float = _rng.randf_range(-100.0, world_width + 100.0)
			# Keep most silhouettes toward the edges so the playable route stays
			# legible even when foreground platforms and hazards are present.
			if x > 215.0 and x < 505.0 and _rng.randf() < 0.76:
				x = -20.0 if _rng.randf() < 0.5 else world_width + 20.0

			var width: float = _rng.randf_range(45.0, 150.0)
			var height: float = _rng.randf_range(220.0, 660.0)
			var y: float = band_y + _rng.randf_range(-160.0, 160.0)
			var slant: float = _rng.randf_range(-34.0, 34.0)
			var points := PackedVector2Array([
				Vector2(x - width * 0.34, y),
				Vector2(x + width * 0.23, y),
				Vector2(x + width * 0.50, y + height * 0.17),
				Vector2(x + width * 0.32 + slant, y + height),
				Vector2(x - width * 0.42 + slant, y + height * 0.90),
				Vector2(x - width * 0.50, y + height * 0.16),
			])
			var fill := Color(0.012, 0.032, 0.071, _rng.randf_range(0.48, 0.82))
			if _rng.randf() < 0.22:
				fill = Color(0.027, 0.027, 0.085, _rng.randf_range(0.38, 0.66))
			draw_colored_polygon(points, fill)
			_draw_closed_outline(points, Color(0.035, 0.15, 0.25, 0.28), 1.2)

			# A few internal ribs give distant towers a constructed silhouette.
			if _rng.randf() < 0.55:
				draw_line(
					Vector2(x, y + height * 0.18),
					Vector2(x + slant * 0.55, y + height * 0.84),
					Color(0.035, 0.19, 0.29, 0.30),
					1.0,
					true
				)
		band_y += _rng.randf_range(250.0, 390.0)

	# Long faint strata imply that the architecture continues beyond the view.
	for y in range(int(section_top_y), int(section_bottom_y), 610):
		draw_line(
			Vector2(-70.0, float(y)),
			Vector2(world_width + 70.0, float(y) + _rng.randf_range(-14.0, 14.0)),
			Color(0.025, 0.10, 0.18, 0.22),
			1.0,
			true
		)


func _draw_mid_architecture() -> void:
	var band_y: float = section_top_y + 300.0
	var index: int = 0
	while band_y < section_bottom_y:
		var scale_factor: float = _rng.randf_range(0.70, 1.28)
		var highlight: Color = MID_CYAN if index % 3 != 1 else MID_VIOLET
		_draw_side_cluster(36.0, band_y, 1.0, scale_factor, highlight)

		# Avoid making both sides mirror each other in every band. That creates a
		# designed rhythm while preserving an irregular, explored-world feeling.
		if index % 2 == 0 or _rng.randf() < 0.38:
			_draw_side_cluster(
				world_width - 36.0,
				band_y + _rng.randf_range(-180.0, 180.0),
				-1.0,
				_rng.randf_range(0.66, 1.18),
				MID_VIOLET if index % 3 == 1 else MID_CYAN
			)

		# Occasional structural cross-beams connect distant towers, but leave a
		# large central opening and never create gameplay collision.
		if index % 3 == 0:
			var beam_y: float = band_y + _rng.randf_range(-90.0, 90.0)
			draw_line(
				Vector2(18.0, beam_y),
				Vector2(world_width * 0.29, beam_y - 60.0),
				Color(0.035, 0.22, 0.34, 0.30),
				3.0,
				true
			)
			draw_line(
				Vector2(world_width * 0.71, beam_y - 60.0),
				Vector2(world_width - 18.0, beam_y),
				Color(0.20, 0.10, 0.39, 0.26),
				3.0,
				true
			)

		index += 1
		band_y += _rng.randf_range(650.0, 920.0)


func _draw_side_cluster(
	anchor_x: float,
	center_y: float,
	side: float,
	scale_factor: float,
	highlight: Color
) -> void:
	var w: float = 106.0 * scale_factor
	var h: float = 320.0 * scale_factor
	var points := PackedVector2Array([
		Vector2(anchor_x - side * 24.0 * scale_factor, center_y - h),
		Vector2(anchor_x + side * w * 0.40, center_y - h * 0.82),
		Vector2(anchor_x + side * w, center_y - h * 0.30),
		Vector2(anchor_x + side * w * 0.82, center_y + h * 0.68),
		Vector2(anchor_x + side * w * 0.20, center_y + h),
		Vector2(anchor_x - side * 18.0 * scale_factor, center_y + h * 0.70),
	])
	draw_colored_polygon(points, Color(0.009, 0.029, 0.065, 0.76))
	_draw_closed_outline(points, Color(highlight.r, highlight.g, highlight.b, 0.36), 2.0)

	var inner_top := Vector2(anchor_x + side * 24.0 * scale_factor, center_y - h * 0.65)
	var inner_bottom := Vector2(anchor_x + side * 55.0 * scale_factor, center_y + h * 0.62)
	draw_line(inner_top, inner_bottom, Color(highlight.r, highlight.g, highlight.b, 0.48), 1.7, true)
	draw_line(
		Vector2(anchor_x - side * 7.0, center_y - h * 0.25),
		Vector2(anchor_x + side * w * 0.72, center_y - h * 0.05),
		Color(0.18, 0.23, 0.53, 0.30),
		1.5,
		true
	)

	# Broken arcs are a recurring visual motif: architectural, but not a wall of
	# glowing strokes. Rotation/position varies through each vertical segment.
	if _rng.randf() < 0.62:
		draw_arc(
			Vector2(anchor_x + side * 70.0 * scale_factor, center_y),
			54.0 * scale_factor,
			deg_to_rad(205.0),
			deg_to_rad(505.0),
			34,
			Color(highlight.r, highlight.g, highlight.b, 0.38),
			2.0,
			true
		)


func _draw_near_frames() -> void:
	# The closest layer frames the viewport edges rather than filling the play
	# area. It is intentionally sparse and low contrast.
	draw_line(
		Vector2(12.0, section_top_y),
		Vector2(12.0, section_bottom_y),
		Color(0.02, 0.31, 0.40, 0.19),
		2.0,
		true
	)
	draw_line(
		Vector2(world_width - 12.0, section_top_y),
		Vector2(world_width - 12.0, section_bottom_y),
		Color(0.18, 0.07, 0.34, 0.19),
		2.0,
		true
	)

	var band_y: float = section_top_y + 220.0
	var index: int = 0
	while band_y < section_bottom_y:
		var side: float = 1.0 if index % 2 == 0 else -1.0
		var anchor_x: float = 4.0 if side > 0.0 else world_width - 4.0
		var length: float = _rng.randf_range(110.0, 280.0)
		var height: float = _rng.randf_range(160.0, 350.0)
		var tone: Color = NEAR_CYAN if index % 3 != 1 else NEAR_VIOLET

		var frame := PackedVector2Array([
			Vector2(anchor_x, band_y - height),
			Vector2(anchor_x + side * length * 0.48, band_y - height * 0.72),
			Vector2(anchor_x + side * length, band_y - height * 0.12),
			Vector2(anchor_x + side * length * 0.83, band_y + height * 0.72),
			Vector2(anchor_x + side * length * 0.22, band_y + height),
		])
		draw_colored_polygon(frame, Color(0.01, 0.035, 0.075, 0.36))
		_draw_closed_outline(frame, Color(tone.r, tone.g, tone.b, 0.34), 2.0)
		draw_line(
			Vector2(anchor_x + side * 22.0, band_y - height * 0.80),
			Vector2(anchor_x + side * length * 0.73, band_y + height * 0.60),
			Color(tone.r, tone.g, tone.b, 0.28),
			1.4,
			true
		)

		index += 1
		band_y += _rng.randf_range(850.0, 1250.0)


func _draw_far_landmark_echo() -> void:
	var landmark_y: float = lerpf(section_top_y, section_bottom_y, 0.49)
	draw_arc(
		Vector2(world_width * 0.5, landmark_y),
		340.0,
		0.0,
		TAU,
		72,
		Color(0.09, 0.23, 0.43, 0.30),
		5.0,
		true
	)
	draw_arc(
		Vector2(world_width * 0.5, landmark_y),
		455.0,
		deg_to_rad(24.0),
		deg_to_rad(335.0),
		72,
		Color(0.23, 0.09, 0.39, 0.23),
		4.0,
		true
	)
	draw_line(
		Vector2(world_width * 0.5, landmark_y - 700.0),
		Vector2(world_width * 0.5, landmark_y + 700.0),
		Color(0.045, 0.18, 0.30, 0.20),
		2.0,
		true
	)


func _draw_gate_landmark() -> void:
	var center := Vector2(world_width * 0.5, lerpf(section_top_y, section_bottom_y, 0.49))
	var cx: float = center.x
	var cy: float = center.y

	var outer := PackedVector2Array([
		Vector2(cx - 218.0, cy + 365.0),
		Vector2(cx - 252.0, cy + 218.0),
		Vector2(cx - 226.0, cy - 215.0),
		Vector2(cx - 142.0, cy - 382.0),
		Vector2(cx + 142.0, cy - 382.0),
		Vector2(cx + 226.0, cy - 215.0),
		Vector2(cx + 252.0, cy + 218.0),
		Vector2(cx + 218.0, cy + 365.0),
		Vector2(cx, cy + 470.0),
	])
	draw_colored_polygon(outer, Color(0.009, 0.035, 0.073, 0.78))
	_draw_closed_outline(outer, Color(0.025, 0.46, 0.62, 0.67), 4.0)

	# Dark aperture makes the monumental ring read as a gate instead of a solid
	# block. It remains background geometry: the player's platforms stay separate.
	var aperture := PackedVector2Array([
		Vector2(cx - 135.0, cy + 258.0),
		Vector2(cx - 166.0, cy + 156.0),
		Vector2(cx - 144.0, cy - 188.0),
		Vector2(cx - 86.0, cy - 273.0),
		Vector2(cx + 86.0, cy - 273.0),
		Vector2(cx + 144.0, cy - 188.0),
		Vector2(cx + 166.0, cy + 156.0),
		Vector2(cx + 135.0, cy + 258.0),
		Vector2(cx, cy + 329.0),
	])
	draw_colored_polygon(aperture, Color(0.004, 0.014, 0.032, 0.94))
	_draw_closed_outline(aperture, Color(0.29, 0.12, 0.50, 0.74), 3.0)

	# Repeated inner ribs and restrained energy seams communicate constructed
	# geometry rather than an ornamental neon circle.
	draw_line(Vector2(cx - 208.0, cy - 128.0), Vector2(cx - 154.0, cy + 246.0), Color(0.02, 0.52, 0.67, 0.50), 2.0, true)
	draw_line(Vector2(cx + 208.0, cy - 128.0), Vector2(cx + 154.0, cy + 246.0), Color(0.02, 0.52, 0.67, 0.50), 2.0, true)
	draw_line(Vector2(cx - 139.0, cy - 323.0), Vector2(cx - 74.0, cy - 370.0), Color(0.33, 0.18, 0.64, 0.65), 3.0, true)
	draw_line(Vector2(cx + 139.0, cy - 323.0), Vector2(cx + 74.0, cy - 370.0), Color(0.33, 0.18, 0.64, 0.65), 3.0, true)

	draw_arc(center, 286.0, deg_to_rad(205.0), deg_to_rad(335.0), 46, Color(0.04, 0.72, 0.92, 0.62), 3.0, true)
	draw_arc(center, 310.0, deg_to_rad(24.0), deg_to_rad(152.0), 46, Color(0.43, 0.20, 0.78, 0.55), 3.0, true)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(cx - 125.0, cy - 422.0),
		"THE RESONANCE GATE",
		HORIZONTAL_ALIGNMENT_LEFT,
		250.0,
		14,
		Color(0.50, 0.82, 0.96, 0.76)
	)


func _draw_gate_accents() -> void:
	var center := Vector2(world_width * 0.5, lerpf(section_top_y, section_bottom_y, 0.49))
	# Foreground fragments of the gate are offset toward the viewport edges.
	# Parallax causes these pieces to drift at a different rate than the gate.
	draw_arc(
		center + Vector2(-44.0, 12.0),
		276.0,
		deg_to_rad(210.0),
		deg_to_rad(258.0),
		24,
		Color(0.02, 0.74, 0.98, 0.74),
		5.0,
		true
	)
	draw_arc(
		center + Vector2(48.0, -18.0),
		276.0,
		deg_to_rad(286.0),
		deg_to_rad(326.0),
		24,
		Color(0.40, 0.20, 0.78, 0.69),
		5.0,
		true
	)

	for i in range(7):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = world_width * 0.5 + side * _rng.randf_range(220.0, 370.0)
		var y: float = center.y + _rng.randf_range(-350.0, 350.0)
		var length: float = _rng.randf_range(38.0, 105.0)
		var tone: Color = NEAR_CYAN if i % 3 != 1 else NEAR_VIOLET
		draw_line(
			Vector2(x, y),
			Vector2(x - side * length * 0.42, y - length),
			Color(tone.r, tone.g, tone.b, 0.52),
			2.5,
			true
		)


func _draw_discovery_glyph() -> void:
	# An optional visual discovery signature. It is purposefully a single
	# recognizable object rather than a scatter of collectable-looking dots.
	var center := Vector2(world_width * 0.76, lerpf(section_top_y, section_bottom_y, 0.34))
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -34.0),
		center + Vector2(23.0, 0.0),
		center + Vector2(0.0, 34.0),
		center + Vector2(-23.0, 0.0),
	])
	draw_colored_polygon(diamond, Color(0.035, 0.12, 0.20, 0.70))
	_draw_closed_outline(diamond, Color(0.11, 0.72, 0.89, 0.86), 2.0)
	draw_arc(center, 52.0, deg_to_rad(18.0), deg_to_rad(320.0), 48, Color(0.25, 0.16, 0.57, 0.76), 2.0, true)
	draw_arc(center, 67.0, deg_to_rad(194.0), deg_to_rad(510.0), 48, Color(0.025, 0.50, 0.66, 0.66), 1.5, true)
	draw_line(center + Vector2(-54.0, 0.0), center + Vector2(-31.0, 0.0), Color(0.12, 0.52, 0.66, 0.50), 1.5, true)
	draw_line(center + Vector2(31.0, 0.0), center + Vector2(54.0, 0.0), Color(0.12, 0.52, 0.66, 0.50), 1.5, true)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-58.0, 92.0),
		"ARCHIVE FRAGMENT",
		HORIZONTAL_ALIGNMENT_LEFT,
		140.0,
		12,
		Color(0.40, 0.72, 0.88, 0.62)
	)


func _draw_closed_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 3:
		return
	var closed := PackedVector2Array()
	for point in points:
		closed.append(point)
	closed.append(points[0])
	draw_polyline(closed, color, width, true)
