extends Area2D
## Reusable pooled collectible. When attached to a platform placement, it waits
## for the platform's construction progress before materializing and enabling contact.

@export var radius: float = 14.0
@export var coin_color: Color = Color(1.0, 0.84, 0.15, 1.0)
@export var coin_outline_color: Color = Color(0.75, 0.55, 0.05, 1.0)
@export var coin_shine_color: Color = Color(1.0, 0.95, 0.6, 1.0)

@export_group("Einsammel-Effekt")
@export var collect_pop_scale: float = 1.4
@export var collect_duration: float = 0.25

var _is_active: bool = false
var _is_collected: bool = false
var _assembly_platform: Node2D = null
var _awaiting_platform_assembly: bool = false
var _reveal_tween: Tween = null

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision_shape.shape = shape
	body_entered.connect(_on_body_entered)
	deactivate()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, coin_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, coin_outline_color, 2.0, true)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.28, coin_shine_color)


func _process(_delta: float) -> void:
	if not _is_active or not _awaiting_platform_assembly:
		return
	if _assembly_platform == null or not is_instance_valid(_assembly_platform):
		_begin_materialization()
		return
	if not _assembly_platform.has_method("get_assembly_progress"):
		_begin_materialization()
		return

	# Join the shared world reveal after the linked platform's construction front
	# has started. The coin is neither visible nor collectible while waiting.
	if float(_assembly_platform.call("get_assembly_progress")) >= 0.10:
		_begin_materialization()


func is_active() -> bool:
	return _is_active


## The platform reference is optional for compatibility with detached collectibles.
func spawn_as(new_position: Vector2, assembly_platform: Node2D = null) -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null

	global_position = new_position
	_is_active = true
	_is_collected = false
	_assembly_platform = assembly_platform
	scale = Vector2.ONE
	modulate = Color.WHITE

	_awaiting_platform_assembly = (
		_assembly_platform != null
		and is_instance_valid(_assembly_platform)
		and _assembly_platform.has_method("get_assembly_progress")
		and float(_assembly_platform.call("get_assembly_progress")) < 0.999
	)
	if _awaiting_platform_assembly:
		visible = false
		modulate.a = 0.0
		scale = Vector2.ONE * 0.72
		monitoring = false
		_collision_shape.disabled = true
	else:
		visible = true
		monitoring = true
		_collision_shape.disabled = false
	queue_redraw()


func _begin_materialization() -> void:
	if not _is_active or not _awaiting_platform_assembly:
		return

	_awaiting_platform_assembly = false
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	scale = Vector2.ONE * 0.72
	monitoring = false
	_collision_shape.disabled = true

	_reveal_tween = create_tween()
	_reveal_tween.set_parallel(true)
	_reveal_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		0.20
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.24
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.set_parallel(false)
	_reveal_tween.tween_callback(_finish_materialization)


func _finish_materialization() -> void:
	_reveal_tween = null
	if not _is_active or _is_collected:
		return
	monitoring = true
	_collision_shape.disabled = false


func deactivate() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null
	_is_active = false
	_is_collected = false
	_assembly_platform = null
	_awaiting_platform_assembly = false
	modulate = Color.WHITE
	scale = Vector2.ONE
	visible = false
	monitoring = false
	_collision_shape.disabled = true


func _on_body_entered(body: Node) -> void:
	if not _is_active or _is_collected or _awaiting_platform_assembly or not body.is_in_group("player_ball"):
		return
	_collect()


## Deferred physics changes are retained for calls made from body_entered.
func _collect() -> void:
	_is_collected = true
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null
	_assembly_platform = null
	set_deferred("monitoring", false)
	_collision_shape.set_deferred("disabled", true)
	GameManager.add_coins(1)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * collect_pop_scale, collect_duration * 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ZERO, collect_duration * 0.65)
	tween.parallel().tween_property(self, "modulate:a", 0.0, collect_duration * 0.65)
	tween.tween_callback(func() -> void: visible = false)
