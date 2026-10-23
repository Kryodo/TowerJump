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

const NEON_COLOR := Color(0.0, 0.65, 0.90, 1.0)
const PLATFORM_BODY_COLOR := Color("#0B111B")

const BEVEL := 4.0
const EDGE_HEIGHT := 8.0
const EDGE_INSET := 1.0

const IDLE_SHEEN_CHANCE := 0.40
const IDLE_SHEEN_MIN_SPAWN_GAP := 2
const IDLE_SHEEN_DELAY_MIN := 0.25
const IDLE_SHEEN_DELAY_MAX := 0.85
const IDLE_SHEEN_DURATION := 0.16

static var _sheen_spawn_sequence: int = 0
static var _last_sheen_spawn_sequence: int = -1000

const LandingApproachStateScript := preload(
	"res://scripts/landing/landing_approach_state.gd"
)

# Physical landing is surfaced as an event so the centralized landing system
# can fan the same event out to future ball/effect/score/combo/camera/audio layers.
signal landing_occurred(landing_world_x: float)

var platform_type: PlatformType = PlatformType.NORMAL
## Increments every time this pooled node is assigned a new platform spawn.
var spawn_generation: int = 0

var _base_position: Vector2 = Vector2.ZERO
var _move_phase: float = 0.0
var _is_breaking: bool = false
var _broken: bool = false

# Platform-local visual state is kept in a dedicated helper. The controller
# owns targeting/prediction; the platform only exposes a visual adapter.
var _landing_approach: LandingApproachState = LandingApproachState.new()
var _landing_confirmation_tween: Tween = null
var _idle_sheen_delay: float = -1.0
var _idle_sheen_tween: Tween = null

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Polygon2D = $Visual
@onready var _neon_edge: Polygon2D = $NeonEdge

func _ready() -> void:
	add_to_group("platforms")
	_collision_shape.one_way_collision = true

	_apply_geometry()
	_schedule_idle_sheen()

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
	_neon_edge.set_instance_shader_parameter(
		"platform_width",
		width * width_scale
	)
	_neon_edge.set_instance_shader_parameter("idle_sheen_progress", -1.0)

func _process(delta: float) -> void:
	if _idle_sheen_delay < 0.0:
		return
	# Pooled platform nodes can exist off-screen before they enter the viewport.
	# Pause the one-shot timer until the platform is actually visible.
	if not _is_platform_on_screen():
		return
	_idle_sheen_delay -= delta
	if _idle_sheen_delay > 0.0:
		return

	if _is_idle_sheen_allowed():
		_idle_sheen_delay = -1.0
		_play_idle_sheen()
	elif _can_wait_for_idle_sheen():
		# Keep the selected flash pending through the approach window. Once the
		# platform becomes activated/landed, it is cancelled instead of lost or
		# allowed to fire over gameplay feedback.
		_idle_sheen_delay = 0.18
	else:
		_idle_sheen_delay = -1.0


func _can_wait_for_idle_sheen() -> bool:
	if not visible or _broken or _is_breaking:
		return false
	var active: float = float(_neon_edge.get_instance_shader_parameter("activated"))
	var confirm: float = float(_neon_edge.get_instance_shader_parameter("landing_confirm"))
	return active <= 0.001 and confirm <= 0.001


func _is_platform_on_screen() -> bool:
	if not is_inside_tree() or not visible:
		return false
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	var screen_center: Vector2 = canvas_transform * global_position
	var screen_scale_x: float = canvas_transform.x.length()
	var screen_scale_y: float = canvas_transform.y.length()
	var half_screen_width: float = half_width() * screen_scale_x
	var half_screen_height: float = height * screen_scale_y * 0.5
	var screen_rect := Rect2(
		Vector2(screen_center.x - half_screen_width, screen_center.y - half_screen_height),
		Vector2(half_screen_width * 2.0, half_screen_height * 2.0)
	)
	return screen_rect.intersects(get_viewport().get_visible_rect())


func _schedule_idle_sheen() -> void:
	if _idle_sheen_tween != null and _idle_sheen_tween.is_valid():
		_idle_sheen_tween.kill()
	_idle_sheen_tween = null
	_idle_sheen_delay = -1.0
	_neon_edge.set_instance_shader_parameter("idle_sheen_progress", -1.0)

	_sheen_spawn_sequence += 1
	if _sheen_spawn_sequence - _last_sheen_spawn_sequence < IDLE_SHEEN_MIN_SPAWN_GAP:
		return
	if randf() > IDLE_SHEEN_CHANCE:
		return

	_last_sheen_spawn_sequence = _sheen_spawn_sequence
	_idle_sheen_delay = randf_range(IDLE_SHEEN_DELAY_MIN, IDLE_SHEEN_DELAY_MAX)


func _is_idle_sheen_allowed() -> bool:
	if not visible or _broken or _is_breaking:
		return false
	if _landing_approach.progress > 0.0001:
		return false
	var charge: float = float(_neon_edge.get_instance_shader_parameter("approach_charge"))
	var active: float = float(_neon_edge.get_instance_shader_parameter("activated"))
	var confirm: float = float(_neon_edge.get_instance_shader_parameter("landing_confirm"))
	return charge <= 0.001 and active <= 0.001 and confirm <= 0.001


func _set_idle_sheen_progress(value: float) -> void:
	if is_instance_valid(_neon_edge):
		_neon_edge.set_instance_shader_parameter("idle_sheen_progress", value)


func _play_idle_sheen() -> void:
	_neon_edge.set_instance_shader_parameter("idle_sheen_progress", 0.0)
	_idle_sheen_tween = create_tween()
	_idle_sheen_tween.tween_method(
		_set_idle_sheen_progress,
		0.0,
		1.0,
		IDLE_SHEEN_DURATION
	).set_trans(Tween.TRANS_LINEAR)
	_idle_sheen_tween.tween_callback(
		func() -> void:
			if is_instance_valid(_neon_edge):
				_neon_edge.set_instance_shader_parameter("idle_sheen_progress", -1.0)
			_idle_sheen_tween = null
	)


func _physics_process(delta: float) -> void:
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
	spawn_generation += 1
	platform_type = type
	width_scale = new_width_scale

	global_position = new_position
	_base_position = new_position
	_move_phase = randf_range(0.0, TAU)

	_is_breaking = false
	_broken = false
	_landing_approach.reset()
	reset_landing_feedback_visual()

	modulate = Color.WHITE

	_collision_shape.disabled = false
	visible = true

	_apply_geometry()
	_schedule_idle_sheen()

func on_ball_landed(landing_world_x: float) -> float:
	# Surface the physical landing. LandingFeedbackController turns this into
	# one LandingEvent that all future reaction layers can consume.
	landing_occurred.emit(landing_world_x)

	_landing_approach.complete()
	_neon_edge.set_instance_shader_parameter("approach_charge", 1.0)
	_neon_edge.set_instance_shader_parameter("activated", 1.0)

	if platform_type == PlatformType.BREAKABLE:
		_start_breaking()
		return 1.0

	if platform_type == PlatformType.SPRING:
		return spring_multiplier

	return 1.0

func play_landing_confirmation(strength: float = 1.0) -> void:
	if _landing_confirmation_tween != null and _landing_confirmation_tween.is_valid():
		_landing_confirmation_tween.kill()

	_neon_edge.set_instance_shader_parameter("activated", 1.0)
	_neon_edge.set_instance_shader_parameter("landing_confirm", 0.0)
	_visual.set_instance_shader_parameter(
		"landing_pulse",
		0.0
	)

	_landing_confirmation_tween = create_tween()
	_landing_confirmation_tween.set_parallel(true)

	# Platform body: keep the existing subtle physical pulse.
	_landing_confirmation_tween.tween_method(
		func(value: float) -> void:
			_visual.set_instance_shader_parameter(
				"landing_pulse",
				value
			),
		0.0,
		strength,
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# NeonEdge: rapid white completion flash.
	_landing_confirmation_tween.tween_method(
		func(value: float) -> void:
			_neon_edge.set_instance_shader_parameter(
				"landing_confirm",
				value
			),
		0.0,
		strength,
		0.045
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	_landing_confirmation_tween.set_parallel(false)

	# Smoothly settle back into the activated HDR cyan rather than snapping.
	_landing_confirmation_tween.tween_method(
		func(value: float) -> void:
			_neon_edge.set_instance_shader_parameter(
				"landing_confirm",
				value
			),
		strength,
		0.0,
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_landing_confirmation_tween.tween_method(
		func(value: float) -> void:
			_visual.set_instance_shader_parameter(
				"landing_pulse",
				value
			),
		strength,
		0.0,
		0.30
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_landing_confirmation_tween.tween_callback(
		func() -> void:
			_neon_edge.set_instance_shader_parameter(
				"landing_confirm",
				0.0
			)
			_visual.set_instance_shader_parameter(
				"landing_pulse",
				0.0
			)
			_landing_confirmation_tween = null
	)

func set_landing_approach_feedback(
	time_to_land: float,
	predicted_x: float,
	edge_factor: float,
	delta: float
) -> void:
	_landing_approach.update_forward(
		delta,
		time_to_land,
		width * width_scale,
		predicted_x,
		edge_factor,
		global_position.x,
		float(get_viewport_rect().size.x)
	)
	_neon_edge.set_instance_shader_parameter(
		"approach_charge",
		_landing_approach.charge()
	)
	_neon_edge.set_instance_shader_parameter(
		"approach_target_x",
		_landing_approach.target_x
	)

func retract_landing_approach_feedback(delta: float) -> void:
	_landing_approach.update_retract(
		delta,
		width * width_scale
	)
	_neon_edge.set_instance_shader_parameter(
		"approach_charge",
		_landing_approach.charge()
	)
	_neon_edge.set_instance_shader_parameter(
		"approach_target_x",
		_landing_approach.target_x
	)

func complete_landing_approach_feedback() -> void:
	_landing_approach.complete()
	_neon_edge.set_instance_shader_parameter(
		"approach_charge",
		1.0
	)
	_neon_edge.set_instance_shader_parameter(
		"approach_target_x",
		_landing_approach.target_x
	)
	_neon_edge.set_instance_shader_parameter(
		"activated",
		1.0
	)

func is_landing_approach_feedback_empty() -> bool:
	return _landing_approach.progress <= 0.0001

func get_landing_approach_progress() -> float:
	return _landing_approach.progress

func get_landing_approach_target_x() -> float:
	return _landing_approach.target_x

func reset_landing_feedback_visual() -> void:
	_landing_approach.reset()
	_neon_edge.set_instance_shader_parameter("idle_sheen_progress", -1.0)
	_neon_edge.set_instance_shader_parameter("approach_charge", 0.0)
	_neon_edge.set_instance_shader_parameter("approach_target_x", 0.5)
	_neon_edge.set_instance_shader_parameter("activated", 0.0)
	_neon_edge.set_instance_shader_parameter("landing_confirm", 0.0)

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
