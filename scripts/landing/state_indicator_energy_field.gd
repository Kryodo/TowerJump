extends Control

## Small, intermittent electrical crackles for the persistent Combo/Streak text.
## Each burst is short, jagged and locally placed over a word; there are no
## travelling dots or long filaments sweeping across empty indicator space.

const FILAMENT_POINTS := 5

var _energy_strength: float = 0.0
var _energy_target: float = 0.0
var _energy_tint: Color = Color(0.40, 0.86, 1.0, 1.0)
var _flow_speed: float = 34.0
var _seed_offset: float = 0.0
var _clock: float = 0.0
var _activation_flash_time: float = 0.0
var _strength_tween: Tween
var _label_nodes: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_seed_offset = float(get_instance_id() % 997) * 0.013
	var root := get_parent()
	if root != null:
		for label_name in [
			"ComboStatusLabel",
			"ComboMultiplierCounter",
			"StreakStatusLabel",
			"StreakCountCounter",
		]:
			var candidate := root.get_node_or_null(label_name)
			if candidate is Label:
				_label_nodes.append(candidate as Label)
	visible = false
	set_process(false)


func set_energy(
	strength: float,
	tint: Color,
	speed: float,
	activation: bool = false
) -> void:
	_energy_tint = tint
	_flow_speed = maxf(speed, 1.0)
	if activation:
		_activation_flash_time = 0.26

	var target: float = clampf(strength, 0.0, 1.0)
	if is_equal_approx(target, _energy_target):
		queue_redraw()
		return
	_energy_target = target
	if _strength_tween != null and _strength_tween.is_valid():
		_strength_tween.kill()

	if is_equal_approx(target, 0.0):
		_strength_tween = create_tween()
		_strength_tween.tween_method(
			Callable(self, "set_strength"), _energy_strength, target, 0.18
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		var duration: float = 0.24 if activation else 0.20
		_strength_tween = create_tween()
		_strength_tween.tween_method(
			Callable(self, "set_strength"), _energy_strength, target, duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	set_process(true)
	queue_redraw()


func set_strength(value: float) -> void:
	_energy_strength = clampf(value, 0.0, 1.0)
	visible = _energy_strength > 0.012 or _activation_flash_time > 0.01
	set_process(visible)
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	_activation_flash_time = maxf(0.0, _activation_flash_time - delta)
	if _energy_strength <= 0.012 and _energy_target <= 0.012 and _activation_flash_time <= 0.01:
		visible = false
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _energy_strength <= 0.012:
		return
	var is_streak: bool = _flow_speed >= 40.0
	var slot_count: int = 3 if is_streak else 2
	var cycle_rate: float = 1.12 if is_streak else 0.78
	var active_fraction: float = 0.26 if is_streak else 0.22
	var activation_boost: float = clampf(_activation_flash_time / 0.26, 0.0, 1.0)

	for label_index in range(_label_nodes.size()):
		var label: Label = _label_nodes[label_index] as Label
		if label == null or not is_instance_valid(label):
			continue
		if not label.visible or label.text.is_empty():
			continue
		var text_rect: Rect2 = _get_text_rect(label)
		if text_rect.size.x <= 3.0:
			continue

		# The regular state is a sparse set of little crackles, not a continuous
		# stream. Each flicker appears at a different spot on the actual word.
		for slot in range(slot_count):
			var slot_phase: float = (
				_clock * cycle_rate + _seed_offset * 0.07
				+ float(label_index) * 0.217 + float(slot) * 0.381
			)
			var phase: float = fposmod(slot_phase, 1.0)
			if phase >= active_fraction:
				continue
			var cycle_id: float = floor(slot_phase)
			var local_seed: float = (
				_seed_offset + float(label_index) * 17.13
				+ float(slot) * 4.73 + cycle_id * 9.17
			)
			var pulse: float = sin(
				clampf(phase / active_fraction, 0.0, 1.0) * PI
			)
			pulse = pow(maxf(0.0, pulse), 0.72) * _energy_strength
			_draw_crackle(
				text_rect, local_seed, pulse, is_streak,
				1.0, 1 if is_streak else 1
			)

		# Activation adds one brief extra charge pop around each visible word,
		# then returns to the quieter intermittent state.
		if activation_boost > 0.015:
			var activation_seed: float = (
				_seed_offset + float(label_index) * 29.7
				+ floor(_clock * 2.0) * 13.1
			)
			var activation_pulse: float = (
				activation_boost * _energy_strength
			)
			_draw_crackle(
				text_rect, activation_seed, activation_pulse,
				is_streak, 1.12, 2 if is_streak else 1
			)


func _get_text_rect(label: Label) -> Rect2:
	var font: Font = label.get_theme_font("font")
	if font == null:
		return Rect2()
	var font_size: int = label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
	).x
	text_width = minf(text_width, label.size.x)

	var text_left: float = 0.0
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			text_left = (label.size.x - text_width) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			text_left = label.size.x - text_width

	# Keep the electrical detail within the word's own footprint, with only a
	# tiny breathing margin—not the large empty area of the status container.
	var origin_x: float = label.position.x + text_left
	var origin_y: float = label.position.y + (label.size.y - float(font_size)) * 0.5
	return Rect2(
		Vector2(origin_x - 1.5, origin_y - 1.0),
		Vector2(text_width + 3.0, float(font_size) + 2.0)
	)


func _draw_crackle(
	text_rect: Rect2,
	seed: float,
	pulse: float,
	is_streak: bool,
	length_scale: float,
	branch_count: int
) -> void:
	if pulse <= 0.015:
		return
	var font_height: float = maxf(10.0, text_rect.size.y - 2.0)
	var max_length: float = minf(
		font_height * (1.06 if is_streak else 0.88),
		text_rect.size.x * 0.38
	)
	var length: float = maxf(
		5.0,
		lerpf(font_height * 0.48, max_length, _random01(seed + 1.7))
		* length_scale
	)
	length = minf(length, text_rect.size.x - 1.0)
	if length <= 1.0:
		return

	var inner_min_x: float = text_rect.position.x + length * 0.5
	var inner_max_x: float = text_rect.end.x - length * 0.5
	var center_x: float = lerpf(
		inner_min_x, inner_max_x, _random01(seed + 2.9)
	)
	var center_y: float = text_rect.position.y + (
		0.22 + 0.56 * _random01(seed + 3.8)
	) * text_rect.size.y
	# Tiny live movement stops each electrical fork looking like a static zigzag.
	center_x += sin(_clock * 15.0 + seed) * 0.75
	center_y += sin(_clock * 19.0 + seed * 1.3) * 0.85

	var points := PackedVector2Array()
	for point_index in range(FILAMENT_POINTS):
		var t: float = float(point_index) / float(FILAMENT_POINTS - 1)
		var x: float = center_x - length * 0.5 + t * length
		var y: float = center_y + (t - 0.5) * (
			_random01(seed + 4.9) - 0.5
		) * font_height * 0.34
		if point_index > 0 and point_index < FILAMENT_POINTS - 1:
			var jaggedness: float = (
				_random01(seed + float(point_index) * 5.37) - 0.5
			) * font_height * (0.50 if is_streak else 0.42)
			y += jaggedness
		y = clampf(y, text_rect.position.y + 0.5, text_rect.end.y - 0.5)
		x = clampf(x, text_rect.position.x + 0.5, text_rect.end.x - 0.5)
		points.append(Vector2(x, y))

	_draw_tapered_crackle(points, pulse, is_streak, seed)

	# Short branches split off the main filament; they fade to hairlines rather
	# than ending in glowing dots.
	var actual_branch_count: int = mini(branch_count, 2)
	for branch_index in range(actual_branch_count):
		var attach_index: int = 1 + int(
			floor(_random01(seed + float(branch_index) * 2.1 + 8.0) * 3.0)
		)
		var anchor: Vector2 = points[attach_index]
		var side: float = 1.0 if _random01(seed + branch_index * 3.1 + 11.0) > 0.5 else -1.0
		var branch_length: float = minf(
			font_height * (0.42 if is_streak else 0.32),
			length * 0.34
		)
		var branch_mid := Vector2(
			clampf(anchor.x + branch_length * 0.42, text_rect.position.x + 0.5, text_rect.end.x - 0.5),
			clampf(anchor.y + side * branch_length * 0.72, text_rect.position.y + 0.5, text_rect.end.y - 0.5)
		)
		var branch_tip := Vector2(
			clampf(anchor.x + branch_length, text_rect.position.x + 0.5, text_rect.end.x - 0.5),
			clampf(anchor.y + side * branch_length, text_rect.position.y + 0.5, text_rect.end.y - 0.5)
		)
		var branch_points := PackedVector2Array([anchor, branch_mid, branch_tip])
		_draw_tapered_crackle(
			branch_points, pulse * 0.48, is_streak, seed + 2.7 + float(branch_index)
		)


func _draw_tapered_crackle(
	points: PackedVector2Array,
	pulse: float,
	is_streak: bool,
	seed: float
) -> void:
	if points.size() < 2:
		return
	for index in range(1, points.size()):
		var t: float = float(index) / float(points.size() - 1)
		var end_fade: float = sin(t * PI) * 0.62 + 0.30
		var shimmer: float = 0.72 + 0.28 * absf(
			sin(_clock * 23.0 + seed + float(index) * 4.1)
		)
		var energy: float = pulse * end_fade * shimmer
		var glow := Color(
			_energy_tint.r, _energy_tint.g, _energy_tint.b,
			0.16 * energy
		)
		var core := _energy_tint.lerp(Color.WHITE, 0.62)
		core.a = (0.74 if is_streak else 0.64) * energy
		draw_line(
			points[index - 1], points[index],
			glow, 1.7 if is_streak else 1.35, true
		)
		draw_line(
			points[index - 1], points[index],
			core, 0.82 if is_streak else 0.65, true
		)


func _random01(value: float) -> float:
	var raw: float = sin(value * 127.1 + 19.19) * 43758.5453
	return raw - floor(raw)
