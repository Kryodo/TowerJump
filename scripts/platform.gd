extends StaticBody2D
## Wiederverwendbare Plattform (StaticBody2D mit One-Way-Collision) in vier
## Varianten (siehe PlatformType). Wird vom PlatformSpawner gepoolt: Instanzen
## werden nie gelöscht, sondern per spawn_as() an eine neue Stelle "teleportiert"
## und dabei komplett neu konfiguriert (Typ, Position, Zustand).

enum PlatformType {
	NORMAL,
	MOVING,
	BREAKABLE,
	SPRING,
}

@export var width: float = 220.0
@export var height: float = 20.0

var width_scale: float = 1.0

@export_group("Beweglich")
@export var move_radius: float = 90.0
@export var move_speed: float = 1.6

@export_group("Brüchig")
@export var breakable_warning_duration: float = 0.3
@export var breakable_flicker_color: Color = Color(1.0, 0.35, 0.25, 1.0)
@export var breakable_wobble_amplitude: float = 5.0

@export_group("Spring")
@export var spring_multiplier: float = 1.75

const NEON_COLOR := Color(0.0, 1.8, 2.4, 1.0)
const PLATFORM_BODY_COLOR := Color("#0B111B")


const BEVEL := 4.0
const EDGE_HEIGHT := 4.0
const EDGE_INSET := 1.0

var platform_type: PlatformType = PlatformType.NORMAL

var _base_position: Vector2 = Vector2.ZERO
var _move_phase: float = 0.0
var _is_breaking: bool = false
var _broken: bool = false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Polygon2D = $Visual
@onready var _neon_edge: Polygon2D = $NeonEdge
@onready var _landing_energy: Polygon2D = $LandingEnergy

func _ready() -> void:
	add_to_group("platforms")
	_collision_shape.one_way_collision = true

	_landing_energy.visible = false


	_apply_geometry()

func _apply_geometry() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width * width_scale, height)
	_collision_shape.shape = shape

	var hw: float = half_width()
	var hh: float = height * 0.5

	# --------------------------------------------------
	# PLATFORM BODY
	# --------------------------------------------------

	_visual.polygon = PackedVector2Array([
		Vector2(-hw + BEVEL, -hh),
		Vector2(hw - BEVEL, -hh),

		Vector2(hw, -hh + BEVEL),
		Vector2(hw, hh - BEVEL),

		Vector2(hw - BEVEL, hh),
		Vector2(-hw + BEVEL, hh),

		Vector2(-hw, hh - BEVEL),
		Vector2(-hw, -hh + BEVEL)
	])

	_visual.set_instance_shader_parameter(
		"platform_width",
		width * width_scale
	)

	_visual.color = PLATFORM_BODY_COLOR

	# --------------------------------------------------
	# NEON EDGE
	# --------------------------------------------------

	_neon_edge.polygon = PackedVector2Array([
		Vector2(-hw + BEVEL + EDGE_INSET, -hh),
		Vector2(hw - BEVEL - EDGE_INSET, -hh),

		Vector2(hw - EDGE_INSET, -hh + BEVEL),
		Vector2(hw - EDGE_INSET, -hh + EDGE_HEIGHT),

		Vector2(-hw + EDGE_INSET, -hh + EDGE_HEIGHT),
		Vector2(-hw + EDGE_INSET, -hh + BEVEL)
	])

	_neon_edge.color = NEON_COLOR

	# --------------------------------------------------
	# LANDING ENERGY SURFACE
	# --------------------------------------------------

	var energy_height := 34.0
	var energy_top := -hh - energy_height
	var energy_bottom := -hh + 5.0

	_landing_energy.polygon = PackedVector2Array([
		Vector2(-hw, energy_top),
		Vector2(hw, energy_top),
		Vector2(hw, energy_bottom),
		Vector2(-hw, energy_bottom)
	])

	_landing_energy.color = Color.WHITE

	_landing_energy.set_instance_shader_parameter(
		"platform_width",
		width * width_scale
	)

	_landing_energy.set_instance_shader_parameter(
		"surface_y",
		-hh
	)

func _physics_process(delta: float) -> void:
	_update_landing_target()

	if platform_type == PlatformType.MOVING and not _is_breaking and not _broken:
		_move_phase += move_speed * delta
		position.x = _base_position.x + sin(_move_phase) * move_radius

func half_width() -> float:
	return width * width_scale * 0.5

func spawn_as(
	type: PlatformType,
	new_position: Vector2,
	new_width_scale: float = 1.0
) -> void:
	platform_type = type
	width_scale = new_width_scale

	global_position = new_position
	_base_position = new_position
	_move_phase = randf_range(0.0, TAU)

	_is_breaking = false
	_broken = false

	modulate = Color.WHITE

	_collision_shape.disabled = false
	visible = true

	_landing_energy.visible = false


	_apply_geometry()

func on_ball_landed(landing_world_x: float) -> float:
	_play_landing_pulse(landing_world_x)
	_neon_edge.set_instance_shader_parameter("landing_confirm", 1.0)

	if platform_type == PlatformType.BREAKABLE:
		_start_breaking()
		return 1.0

	if platform_type == PlatformType.SPRING:
		return spring_multiplier

	return 1.0

func _play_landing_pulse(landing_world_x: float) -> void:
	_neon_edge.color = NEON_COLOR
	_neon_edge.set_instance_shader_parameter("landing_confirm", 0.0)

	_visual.set_instance_shader_parameter(
		"landing_pulse",
		0.0
	)

	# --------------------------------------------------
	# CALCULATE LANDING POSITION ON PLATFORM
	# --------------------------------------------------

	var local_landing_x := landing_world_x - global_position.x

	var landing_ratio := (
		local_landing_x + half_width()
	) / (width * width_scale)

	landing_ratio = clamp(
		landing_ratio,
		0.0,
		1.0
	)

	# --------------------------------------------------
	# START SURFACE ENERGY
	# --------------------------------------------------

	_landing_energy.visible = true

	_landing_energy.set_instance_shader_parameter(
		"landing_x",
		landing_ratio
	)

	_landing_energy.set_instance_shader_parameter(
		"landing_energy",
		0.0
	)

	var tween := create_tween()

	tween.set_parallel(true)

	# --------------------------------------------------
	# NEON EDGE
	# --------------------------------------------------

	# --------------------------------------------------
	# BODY
	# --------------------------------------------------

	tween.tween_method(
		func(value: float) -> void:
			_visual.set_instance_shader_parameter(
				"landing_pulse",
				value
			),
		0.0,
		1.0,
		1.15
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# --------------------------------------------------
	# SURFACE ENERGY
	# --------------------------------------------------

	tween.tween_method(
		func(value: float) -> void:
			_landing_energy.set_instance_shader_parameter(
				"landing_energy",
				value
			),
		0.0,
		1.0,
		1.05
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	tween.set_parallel(false)

	# --------------------------------------------------
	# NEON EDGE RECOVERY
	# --------------------------------------------------

	tween.tween_property(
		_neon_edge,
		"color",
		NEON_COLOR,
		1.92
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# --------------------------------------------------
	# BODY RECOVERY
	# --------------------------------------------------

	tween.tween_method(
		func(value: float) -> void:
			_visual.set_instance_shader_parameter(
				"landing_pulse",
				value
			),
		1.0,
		0.0,
		1.90
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# --------------------------------------------------
	# CLEANUP
	# --------------------------------------------------

	tween.tween_callback(
		func() -> void:
			_landing_energy.set_instance_shader_parameter(
				"landing_energy",
				0.0
			)

			_landing_energy.visible = false

			_visual.set_instance_shader_parameter(
				"landing_pulse",
				0.0
			)

			_neon_edge.set_instance_shader_parameter(
				"landing_confirm",
				0.0
			)
	)

func _update_landing_target() -> void:
	var ball := get_tree().get_first_node_in_group("player_ball") as CharacterBody2D
	if ball == null:
		return

	var is_target := _is_best_landing_target(ball)
	var charge := 0.0
	var target_ratio := 0.5

	if is_target and ball.velocity.y > 0.0:
		var dy := global_position.y - ball.global_position.y
		var approach_range := 300.0

		if dy > 0.0 and dy < approach_range:
			var g: float = float(ball.gravity)
			var vy: float = float(ball.velocity.y)
			var discriminant: float = vy * vy + 2.0 * g * dy

			if discriminant >= 0.0:
				var t: float = (-vy + sqrt(discriminant)) / g
				var predicted_x: float = ball.global_position.x + ball.velocity.x * t

				# Account for screen wrap when predicting the landing position.
				var screen_width: float = float(get_viewport_rect().size.x)
				if predicted_x < 0.0:
					predicted_x = fmod(predicted_x, screen_width) + screen_width
				elif predicted_x > screen_width:
					predicted_x = fmod(predicted_x, screen_width)

				var local_x: float = predicted_x - global_position.x
				var landing_margin := 18.0

				if local_x >= -half_width() - landing_margin and local_x <= half_width() + landing_margin:
					target_ratio = clampf(
						(local_x + half_width()) / (width * width_scale),
						0.0,
						1.0
					)
					charge = 1.0 - clampf(dy / approach_range, 0.0, 1.0)
					charge = smoothstep(0.0, 1.0, charge)

	if charge <= 0.001:
		_landing_energy.set_instance_shader_parameter("landing_energy", 0.0)

	_neon_edge.set_instance_shader_parameter("approach_charge", charge)
	_neon_edge.set_instance_shader_parameter("approach_target_x", target_ratio)


func _is_best_landing_target(ball: CharacterBody2D) -> bool:
	if ball.velocity.y <= 0.0:
		return false

	var candidates: Array[Node] = get_tree().get_nodes_in_group("platforms")
	var best: Node2D = null
	var best_dy := INF

	for candidate in candidates:
		if not candidate is Node2D:
			continue

		var platform := candidate as Node2D
		if not platform.visible:
			continue

		var platform_dy := platform.global_position.y - ball.global_position.y
		if platform_dy <= 0.0 or platform_dy > 300.0:
			continue

		var candidate_half_width := float(platform.call("half_width"))
		var local_x := ball.global_position.x - platform.global_position.x
		var margin := 24.0

		if local_x >= -candidate_half_width - margin and local_x <= candidate_half_width + margin:
			if platform_dy < best_dy:
				best_dy = platform_dy
				best = platform

	return best == self


func _start_breaking() -> void:
	if _is_breaking or _broken:
		return

	_is_breaking = true

	var tween := create_tween()

	tween.tween_property(
		self,
		"modulate",
		breakable_flicker_color,
		breakable_warning_duration
	)

	tween.parallel().tween_method(
		_apply_wobble,
		0.0,
		1.0,
		breakable_warning_duration
	)

	tween.tween_callback(_break)

func _apply_wobble(t: float) -> void:
	position.x = _base_position.x + sin(t * TAU * 6.0) * breakable_wobble_amplitude * (1.0 - t)

func _break() -> void:
	_is_breaking = false
	_broken = true
	position.x = _base_position.x
	_collision_shape.disabled = true
	visible = false
