extends Control

## Lightweight additive-feeling energy drawn directly over a persistent status
## label. Short strands and bright motes move along curved paths through the
## lettering; the effect remains small enough to preserve text readability.

const FIELD_MARGIN_X := 5.0
const FIELD_MARGIN_Y := 4.0
const FILAMENT_SAMPLES := 7

var _label: Label
var _energy_strength: float = 0.0
var _energy_tint: Color = Color(0.40, 0.86, 1.0, 1.0)
var _flow_speed: float = 32.0
var _seed_offset: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = get_parent() as Label
	if _label != null:
		_seed_offset = float(_label.get_instance_id() % 997) * 0.013
	visible = false
	set_process(false)


func set_energy(strength: float, tint: Color, speed: float) -> void:
	_energy_tint = tint
	_flow_speed = maxf(speed, 1.0)
	set_strength(strength)


func set_strength(strength: float) -> void:
	_energy_strength = clampf(strength, 0.0, 1.0)
	visible = _energy_strength > 0.015
	set_process(visible)
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	if _energy_strength <= 0.015 or _label == null or not is_instance_valid(_label):
		return
	if _label.text.is_empty():
		return

	var label_font: Font = _label.get_theme_font("font")
	if label_font == null:
		return
	var font_size: int = _label.get_theme_font_size("font_size")
	var text_width: float = label_font.get_string_size(
		_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
	).x
	text_width = clampf(text_width, 10.0, maxf(10.0, _label.size.x - 2.0))

	var text_left: float = 0.0
	match _label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			text_left = (_label.size.x - text_width) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			text_left = _label.size.x - text_width

	var start_x: float = FIELD_MARGIN_X + text_left
	var center_y: float = FIELD_MARGIN_Y + _label.size.y * 0.5
	var amplitude: float = clampf(float(font_size) * 0.27, 2.6, 4.8)
	var strength: float = _energy_strength
	var is_streak: bool = _flow_speed >= 40.0
	var strand_count: int = 3 if is_streak else 2
	var particle_count: int = 6 if is_streak else 4
	var cycle_rate: float = (
		0.48 + _flow_speed * 0.009
	) / maxf(text_width / 48.0, 0.65)

	# Short curved filaments travel across the word in alternating directions.
	# Each is a moving tail, never a fixed line or a geometric screen decoration.
	for strand in range(strand_count):
		var phase: float = _seed_offset + float(strand) * 2.17
		var moving_progress: float = fposmod(
			_clock * cycle_rate + _seed_offset * 0.013
			+ float(strand) / float(strand_count),
			1.0
		)
		var moves_backwards: bool = strand % 2 == 1
		var head_progress: float = 1.0 - moving_progress if moves_backwards else moving_progress
		var tail_span: float = minf(0.38, 19.0 / maxf(text_width, 1.0))
		var points := PackedVector2Array()
		for sample in range(FILAMENT_SAMPLES):
			var tail_fraction: float = float(sample) / float(FILAMENT_SAMPLES - 1)
			var path_progress: float = (
				head_progress + tail_span * tail_fraction
				if moves_backwards
				else head_progress - tail_span * tail_fraction
			)
			if path_progress < 0.0 or path_progress > 1.0:
				continue
			var point_x: float = start_x + path_progress * text_width
			var point_y: float = _path_y(
				path_progress, center_y, amplitude, phase
			)
			points.append(Vector2(point_x, point_y))

		if points.size() >= 2:
			var glow_color := Color(
				_energy_tint.r, _energy_tint.g, _energy_tint.b, 0.22 * strength
			)
			var thread_color := _energy_tint.lerp(Color.WHITE, 0.58)
			thread_color.a = 0.82 * strength
			draw_polyline(
				points, glow_color, 3.3 if is_streak else 2.6, true
			)
			draw_polyline(
				points, thread_color, 1.35 if is_streak else 1.05, true
			)

		var head_position := Vector2(
			start_x + head_progress * text_width,
			_path_y(head_progress, center_y, amplitude, phase)
		)
		var head_radius: float = 2.65 if is_streak else 2.2
		draw_circle(
			head_position,
			head_radius,
			Color(_energy_tint.r, _energy_tint.g, _energy_tint.b, 0.30 * strength)
		)
		draw_circle(
			head_position,
			0.85 if is_streak else 0.72,
			Color(1.0, 1.0, 1.0, 0.92 * strength)
		)

	# Independent motes dart through and just outside the text silhouette.
	# Their bright cores and flickering halos give the active state a spark-like
	# texture, while STREAK adds more motes and a little extra size/intensity.
	for mote in range(particle_count):
		var mote_index: float = float(mote)
		var mote_progress: float = fposmod(
			_clock * cycle_rate * (1.16 + mote_index * 0.09)
			+ _seed_offset * 0.031 + mote_index * 0.287,
			1.0
		)
		var mote_x: float = start_x - 2.0 + mote_progress * (text_width + 4.0)
		var mote_phase: float = _seed_offset + mote_index * 1.91
		var mote_y: float = (
			center_y
			+ sin(_clock * (2.7 + mote_index * 0.17) + mote_phase) * amplitude * 0.96
			+ sin(mote_progress * TAU * 2.2 + mote_phase * 1.3) * amplitude * 0.34
		)
		var twinkle: float = 0.50 + 0.50 * absf(
			sin(_clock * (5.5 + mote_index * 0.73) + mote_phase)
		)
		var mote_position := Vector2(mote_x, mote_y)
		var halo_radius: float = 2.8 if is_streak else 2.35
		draw_circle(
			mote_position,
			halo_radius,
			Color(
				_energy_tint.r, _energy_tint.g, _energy_tint.b,
				(0.17 + twinkle * 0.13) * strength
			)
		)
		draw_circle(
			mote_position,
			0.86 if is_streak else 0.72,
			Color(1.0, 1.0, 1.0, (0.62 + twinkle * 0.32) * strength)
		)


func _path_y(
	progress: float,
	center_y: float,
	amplitude: float,
	phase: float
) -> float:
	return (
		center_y
		+ sin(progress * TAU * 1.45 - _clock * (1.6 + _flow_speed * 0.012) + phase) * amplitude
		+ sin(progress * TAU * 2.25 + _clock * 1.35 + phase * 1.7) * amplitude * 0.34
	)
