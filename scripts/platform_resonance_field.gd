extends Node2D
## Platform resonance field: a diffuse, living atmosphere connected to the
## platform's neon perimeter, rather than a second geometric platform.
##
## The cloud is shader-driven so its energy has no fixed outline. Sparse
## filaments and fragments briefly emerge from the edge and dissolve into it.
## Normal is the first authored platform type; other types remain unlit by this
## field until their own visual behaviors are designed.

const PLATFORM_TYPE_NORMAL: int = 0
const CLOUD_SHADER := preload("res://scenes/platform_resonance_cloud.gdshader")

const CLOUD_MARGIN_X: float = 86.0
const CLOUD_MARGIN_Y: float = 90.0
const LANDING_WAVE_DURATION: float = 0.58
const FRAGMENT_COUNT: int = 8
const FILAMENT_COUNT: int = 5

var _platform_type: int = PLATFORM_TYPE_NORMAL
var _platform_width: float = 220.0
var _platform_height: float = 20.0
var _time: float = 0.0
var _phase_offset: float = 0.0
var _approach_charge: float = 0.0
var _approach_charge_target: float = 0.0
var _approach_target_x: float = 0.5
var _landing_wave_age: float = -1.0
var _landing_wave_strength: float = 0.0
var _landing_local_x: float = 0.0

var _cloud: Polygon2D
var _cloud_material: ShaderMaterial


func _ready() -> void:
	_phase_offset = randf_range(0.0, 997.0)
	material = _make_additive_material()
	_create_cloud_layer()
	set_process(true)


func _make_additive_material() -> CanvasItemMaterial:
	var additive_material := CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return additive_material


func _create_cloud_layer() -> void:
	_cloud = Polygon2D.new()
	_cloud.name = "DiffuseResonanceCloud"
	_cloud.z_index = 0
	_cloud.material = ShaderMaterial.new()
	_cloud_material = _cloud.material as ShaderMaterial
	_cloud_material.shader = CLOUD_SHADER
	_cloud_material.set_shader_parameter("phase_offset", _phase_offset)
	add_child(_cloud)


func configure(platform_type: int, platform_width: float, platform_height: float) -> void:
	_platform_type = platform_type
	_platform_width = maxf(platform_width, 1.0)
	_platform_height = maxf(platform_height, 1.0)

	# This is the Normal signature only; other platform identities get bespoke
	# motion languages later instead of inheriting this effect with a new tint.
	visible = _platform_type == PLATFORM_TYPE_NORMAL
	if not visible:
		reset_feedback()
	_update_cloud_geometry()
	_sync_cloud_parameters()
	queue_redraw()


func _update_cloud_geometry() -> void:
	if _cloud == null or not is_instance_valid(_cloud):
		return

	var half_width: float = _platform_width * 0.5 + CLOUD_MARGIN_X
	var half_height: float = _platform_height * 0.5 + CLOUD_MARGIN_Y
	# The enlarged canvas gives the environmental haze room to feather outward.
	# Shader falloff reaches zero before these actual edges, avoiding a cut-off
	# rectangle and keeping neighboring platform fields from merging.
	_cloud.polygon = PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(half_width, half_height),
		Vector2(-half_width, half_height)
	])
	_cloud.uv = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0)
	])
	_cloud_material.set_shader_parameter(
		"field_size",
		Vector2(half_width * 2.0, half_height * 2.0)
	)
	_cloud_material.set_shader_parameter("platform_half_width", _platform_width * 0.5)
	_cloud_material.set_shader_parameter("platform_half_height", _platform_height * 0.5)


func set_approach_feedback(charge: float, target_x: float) -> void:
	_approach_charge_target = clampf(charge, 0.0, 1.0)
	_approach_target_x = clampf(target_x, 0.0, 1.0)


func play_landing_wave(landing_world_x: float, strength: float = 1.0) -> void:
	if _platform_type != PLATFORM_TYPE_NORMAL:
		return
	_landing_local_x = clampf(
		landing_world_x - global_position.x,
		-_platform_width * 0.5,
		_platform_width * 0.5
	)
	_landing_wave_age = 0.0
	_landing_wave_strength = clampf(strength, 0.65, 1.45)
	_approach_charge_target = 0.0
	_sync_cloud_parameters()
	queue_redraw()


func reset_feedback() -> void:
	_approach_charge = 0.0
	_approach_charge_target = 0.0
	_approach_target_x = 0.5
	_landing_wave_age = -1.0
	_landing_wave_strength = 0.0
	_landing_local_x = 0.0
	_sync_cloud_parameters()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or not is_visible_in_tree():
		return
	var platform := get_parent()
	if platform == null:
		return
	if platform.has_method("_is_platform_on_screen") and not bool(platform.call("_is_platform_on_screen")):
		return

	_time += delta
	_approach_charge = lerpf(
		_approach_charge,
		_approach_charge_target,
		1.0 - exp(-7.5 * delta)
	)
	if _landing_wave_age >= 0.0:
		_landing_wave_age += delta
		if _landing_wave_age >= LANDING_WAVE_DURATION:
			_landing_wave_age = -1.0
			_landing_wave_strength = 0.0

	_sync_cloud_parameters()
	queue_redraw()


func _sync_cloud_parameters() -> void:
	if _cloud_material == null:
		return
	_cloud_material.set_shader_parameter("approach_charge", _approach_charge)
	_cloud_material.set_shader_parameter("approach_target_x", _approach_target_x)
	_cloud_material.set_shader_parameter("landing_age", _landing_wave_age)
	_cloud_material.set_shader_parameter("landing_strength", _landing_wave_strength)
	_cloud_material.set_shader_parameter("landing_x", _landing_local_x)
	_cloud_material.set_shader_parameter("phase_offset", _phase_offset)


func _draw() -> void:
	if not visible or _platform_type != PLATFORM_TYPE_NORMAL:
		return

	var half_width: float = _platform_width * 0.5
	var half_height: float = _platform_height * 0.5
	_draw_edge_filaments(half_width, half_height)
	_draw_edge_fragments(half_width, half_height)


func _draw_edge_filaments(half_width: float, half_height: float) -> void:
	# Short-lived filaments emerge from scattered perimeter points. They never
	# join into a full outline, and their low-contrast tails disappear into cloud.
	for strand in range(FILAMENT_COUNT):
		var seed: float = _phase_offset * 0.19 + float(strand) * 13.71
		var life_clock: float = _time * (0.19 + float(strand) * 0.023) + seed
		var life_phase: float = fposmod(life_clock, 1.0)
		var active_window: float = 0.33 + float(strand % 2) * 0.07
		if life_phase >= active_window:
			continue
		var cycle_id: float = floor(life_clock)
		var random_seed: float = seed + cycle_id * 17.17
		var envelope: float = sin(PI * life_phase / active_window)
		envelope = pow(maxf(envelope, 0.0), 0.8)
		_draw_emergent_filament(
			half_width,
			half_height,
			random_seed,
			envelope * (0.42 + _approach_charge * 0.26)
		)


func _draw_emergent_filament(
	half_width: float,
	half_height: float,
	seed: float,
	energy: float
) -> void:
	var side_id: int = int(floor(_random01(seed + 1.1) * 4.0))
	var along: float = _random01(seed + 2.3) * 2.0 - 1.0
	var origin := Vector2.ZERO
	var normal := Vector2.ZERO
	var tangent := Vector2.ZERO

	match side_id:
		0:
			origin = Vector2(along * half_width, -half_height)
			normal = Vector2(0.0, -1.0)
			tangent = Vector2(1.0, 0.0)
		1:
			origin = Vector2(along * half_width, half_height)
			normal = Vector2(0.0, 1.0)
			tangent = Vector2(1.0, 0.0)
		2:
			origin = Vector2(-half_width, along * half_height)
			normal = Vector2(-1.0, 0.0)
			tangent = Vector2(0.0, 1.0)
		_:
			origin = Vector2(half_width, along * half_height)
			normal = Vector2(1.0, 0.0)
			tangent = Vector2(0.0, 1.0)

	var direction: float = -1.0 if _random01(seed + 3.7) < 0.5 else 1.0
	var bend: float = (_random01(seed + 4.9) - 0.5) * 13.0
	var length: float = lerpf(12.0, 26.0, _random01(seed + 5.3))
	# Most filaments still grow out of the platform edge. A few begin several
	# pixels into the cloud, so the energy occasionally appears already detached.
	var detached_gap: float = 0.0
	if _random01(seed + 6.7) < 0.38:
		detached_gap = lerpf(3.5, 7.0, _random01(seed + 7.1))
	var points := PackedVector2Array()
	points.append(origin + normal * detached_gap + tangent * direction * 1.5)
	points.append(origin + normal * (detached_gap + 3.8) + tangent * (direction * length * 0.23 + bend * 0.25))
	points.append(origin + normal * (detached_gap + length * 0.50) + tangent * (direction * length * 0.62 + bend))
	points.append(origin + normal * (detached_gap + length * 0.83) + tangent * (direction * length * 0.45 - bend * 0.45))
	points.append(origin + normal * (detached_gap + length) + tangent * (direction * length * 0.22))

	_draw_tapered_filament(points, energy, seed)


func _draw_tapered_filament(points: PackedVector2Array, energy: float, seed: float) -> void:
	if points.size() < 2 or energy <= 0.01:
		return
	for index in range(1, points.size()):
		var t: float = float(index) / float(points.size() - 1)
		var taper: float = sin((t * 0.90 + 0.06) * PI) * 0.58 + 0.12
		var shimmer: float = 0.72 + 0.28 * absf(sin(_time * 17.0 + seed + float(index) * 3.7))
		var strength: float = energy * taper * shimmer
		draw_line(
			points[index - 1], points[index],
			Color(0.025, 0.28, 1.25, 0.24 * strength),
			5.0 if index < 3 else 3.2, true
		)
		draw_line(
			points[index - 1], points[index],
			Color(0.045, 0.72, 2.05, 0.42 * strength),
			1.65 if index < 3 else 1.0, true
		)
		if index == 2 and energy > 0.25:
			draw_line(
				points[index - 1], points[index],
				Color(0.62, 1.25, 2.7, 0.42 * strength),
				0.70, true
			)


func _draw_edge_fragments(half_width: float, half_height: float) -> void:
	# Fragments originate from four perimeter zones and drift into surrounding
	# space along curved, seeded paths before dissolving. Sparse by design.
	for index in range(FRAGMENT_COUNT):
		var seed: float = _phase_offset * 5.7 + float(index) * 19.31
		var speed: float = 0.12 + _random01(seed + 0.6) * 0.085
		var life_clock: float = _time * speed + seed
		var phase: float = fposmod(life_clock, 1.0)
		var cycle_id: float = floor(life_clock)
		var local_seed: float = seed + cycle_id * 23.9
		var alpha_envelope: float = sin(PI * phase)
		alpha_envelope = pow(maxf(alpha_envelope, 0.0), 1.25)
		if alpha_envelope <= 0.015:
			continue

		var side_id: int = int(floor(_random01(local_seed + 1.7) * 4.0))
		var along: float = _random01(local_seed + 2.9) * 2.0 - 1.0
		var origin := Vector2.ZERO
		var outward := Vector2.ZERO
		var tangent := Vector2.ZERO
		match side_id:
			0:
				origin = Vector2(along * half_width, -half_height)
				outward = Vector2(0.0, -1.0)
				tangent = Vector2(1.0, 0.0)
			1:
				origin = Vector2(along * half_width, half_height)
				outward = Vector2(0.0, 1.0)
				tangent = Vector2(1.0, 0.0)
			2:
				origin = Vector2(-half_width, along * half_height)
				outward = Vector2(-1.0, 0.0)
				tangent = Vector2(0.0, 1.0)
			_:
				origin = Vector2(half_width, along * half_height)
				outward = Vector2(1.0, 0.0)
				tangent = Vector2(0.0, 1.0)

		var travel: float = 7.0 + phase * lerpf(13.0, 24.0, _random01(local_seed + 3.3))
		var curl: float = sin(phase * PI) * (_random01(local_seed + 4.1) - 0.5) * 13.0
		var position_now: Vector2 = (
			origin + outward * travel
			+ tangent * (phase * (_random01(local_seed + 5.1) - 0.5) * 22.0 + curl)
		)
		var radius: float = 0.65 + _random01(local_seed + 6.2) * 0.60
		var alpha: float = alpha_envelope * (0.38 + _approach_charge * 0.20)
		# A barely visible curved trace gives a few drifting fragments direction
		# and a sense of motion without turning them into particle streaks.
		var trail_start: Vector2 = (
			position_now - outward * (3.5 + phase * 1.5)
			- tangent * curl * 0.16
		)
		draw_line(
			trail_start, position_now,
			Color(0.035, 0.36, 1.35, alpha * 0.16), 0.85, true
		)
		draw_circle(position_now, radius * 4.2, Color(0.025, 0.24, 1.2, alpha * 0.28))
		draw_circle(position_now, radius * 2.1, Color(0.045, 0.72, 2.0, alpha * 0.52))
		draw_circle(position_now, radius * 0.78, Color(0.64, 1.28, 2.65, alpha * 0.72))


func _random01(value: float) -> float:
	var raw: float = sin(value * 127.1 + 19.19) * 43758.5453
	return raw - floor(raw)
