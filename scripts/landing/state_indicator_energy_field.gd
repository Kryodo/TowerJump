extends Control

## A shared energy field for the complete Combo/Streak indicator. Thin, tapered
## current-like filaments glide through the full label group and branch into
## finer threads; there are deliberately no particles or bright dot heads.

const FILAMENT_SAMPLES := 17

var _energy_strength: float = 0.0
var _energy_tint: Color = Color(0.40, 0.86, 1.0, 1.0)
var _flow_speed: float = 34.0
var _seed_offset: float = 0.0
var _clock: float = 0.0
var _strength_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed_offset = float(get_instance_id() % 997) * 0.013
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
	var target: float = clampf(strength, 0.0, 1.0)
	if is_equal_approx(target, _energy_strength):
		queue_redraw()
		return
	if _strength_tween != null and _strength_tween.is_valid():
		_strength_tween.kill()
	if is_equal_approx(target, 0.0):
		_strength_tween = create_tween()
		_strength_tween.tween_method(
			Callable(self, "set_strength"), _energy_strength, target, 0.20
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		var duration: float = 0.30 if activation else 0.22
		_strength_tween = create_tween()
		_strength_tween.tween_method(
			Callable(self, "set_strength"), _energy_strength, target, duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	queue_redraw()


func set_strength(value: float) -> void:
	_energy_strength = clampf(value, 0.0, 1.0)
	visible = _energy_strength > 0.012
	set_process(visible)
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	if _energy_strength <= 0.012:
		return
	var is_streak: bool = _flow_speed >= 40.0
	var strand_count: int = 4 if is_streak else 3
	var tail_length: float = 57.0 if is_streak else 43.0
	var speed_pixels: float = _flow_speed * 3.9
	var track_length: float = size.x + tail_length * 2.0
	var amplitude: float = 5.0 if is_streak else 4.0
	var lane_spread: float = size.y * (0.28 if is_streak else 0.20)

	# Multiple offset filaments cross the indicator at different heights. Their
	# tails taper continuously to a hairline; no point sprites or dot heads exist.
	for strand in range(strand_count):
		var index: float = float(strand)
		var phase: float = _seed_offset + index * 2.13
		var offset: float = index / float(strand_count)
		var travel: float = fposmod(
			_clock * speed_pixels / track_length + offset,
			1.0
		)
		var head_x: float = travel * track_length - tail_length
		var lane_y: float = size.y * 0.5
		lane_y += sin(phase * 1.7 + _clock * 0.82) * lane_spread
		var points := PackedVector2Array()
		for sample in range(FILAMENT_SAMPLES):
			var progress: float = float(sample) / float(FILAMENT_SAMPLES - 1)
			var point_x: float = head_x - tail_length + progress * tail_length
			var point_y: float = _filament_y(
				point_x, lane_y, amplitude, phase, progress
			)
			points.append(Vector2(point_x, point_y))
		_draw_tapered_path(points, _energy_strength, 1.0, phase)

		# A finer offshoot forks from the main current. It follows the moving
		# strand but curls outward, creating a branching filament rather than dots.
		var branch_points := PackedVector2Array()
		var branch_start: int = 5
		var branch_end: int = 13
		var branch_side: float = 1.0 if strand % 2 == 0 else -1.0
		for sample in range(branch_start, branch_end + 1):
			var branch_progress: float = float(sample - branch_start) / float(branch_end - branch_start)
			var p: Vector2 = points[sample]
			p.x += branch_progress * 2.8
			p.y += branch_side * (
				branch_progress * amplitude * 1.6
				+ sin(branch_progress * PI) * amplitude * 0.75
			)
			branch_points.append(p)
		_draw_tapered_path(
			branch_points, _energy_strength * 0.60, 0.52, phase + 1.7
		)


func _filament_y(
	x: float,
	lane_y: float,
	amplitude: float,
	phase: float,
	progress: float
) -> float:
	var slow_wave: float = sin(
		x * 0.025 - _clock * (1.8 + _flow_speed * 0.025) + phase
	)
	var quick_wave: float = sin(
		x * 0.061 - _clock * 2.8 + phase * 1.9
	)
	var bend: float = sin(progress * PI) * amplitude * 0.68
	return lane_y + slow_wave * amplitude + quick_wave * amplitude * 0.34 + bend


func _draw_tapered_path(
	points: PackedVector2Array,
	strength: float,
	width_scale: float,
	phase: float
) -> void:
	if points.size() < 2:
		return
	for index in range(1, points.size()):
		var progress: float = float(index) / float(points.size() - 1)
		var taper: float = pow(progress, 1.35)
		var shimmer: float = 0.72 + 0.28 * (
			0.5 + 0.5 * sin(_clock * 7.4 + progress * 13.0 + phase)
		)
		var energy: float = strength * taper * shimmer
		var glow := Color(
			_energy_tint.r, _energy_tint.g, _energy_tint.b,
			0.10 * energy
		)
		var core := _energy_tint.lerp(Color.WHITE, 0.48 + 0.28 * progress)
		core.a = 0.76 * energy
		draw_line(
			points[index - 1], points[index], glow,
			lerpf(1.3, 2.6, progress) * width_scale, true
		)
		draw_line(
			points[index - 1], points[index], core,
			lerpf(0.32, 0.92, progress) * width_scale, true
		)
