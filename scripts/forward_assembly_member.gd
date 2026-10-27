extends Node2D
## Opt-in adapter for future traps, collectibles, and structural environment pieces.
## It listens to the shared construction pulse/frontier and keeps collision disabled
## until its own visual construction has finished.

@export var construction_coordinator_path: NodePath = NodePath("../PlatformSpawner")
@export var visual_root_path: NodePath = NodePath(".")
@export var collision_shape_paths: Array[NodePath] = []
@export_range(8.0, 180.0, 4.0) var pulse_trigger_radius: float = 52.0
@export_range(8.0, 180.0, 4.0) var frontier_height_tolerance: float = 44.0
@export_range(0.10, 0.90, 0.05) var materialization_duration: float = 0.34
@export_range(4.0, 60.0, 2.0) var materialization_slide_distance: float = 18.0

var _coordinator: Node = null
var _visual_root: Node2D = null
var _collision_shapes: Array[CollisionShape2D] = []
var _base_position: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE
var _base_modulate: Color = Color.WHITE
var _assembly_tween: Tween = null
var _assembled: bool = false
var _has_previous_pulse: bool = false
var _previous_pulse_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_visual_root = get_node_or_null(visual_root_path) as Node2D
	if _visual_root == null:
		push_error("ForwardAssemblyMember: visual_root_path must point to a Node2D.")
		return

	_base_position = _visual_root.position
	_base_scale = _visual_root.scale
	_base_modulate = _visual_root.modulate
	_visual_root.visible = false
	_set_collision_shapes_enabled(false)

	for path in collision_shape_paths:
		var shape := get_node_or_null(path) as CollisionShape2D
		if shape != null and not _collision_shapes.has(shape):
			_collision_shapes.append(shape)
	_set_collision_shapes_enabled(false)

	_coordinator = get_node_or_null(construction_coordinator_path)
	if _coordinator == null:
		push_warning("ForwardAssemblyMember: construction coordinator was not found.")
		return

	if _coordinator.has_signal("construction_pulse_advanced"):
		var pulse_callback := Callable(self, "_on_construction_pulse_advanced")
		if not _coordinator.is_connected("construction_pulse_advanced", pulse_callback):
			_coordinator.connect("construction_pulse_advanced", pulse_callback)

	if _coordinator.has_signal("assembly_frontier_reached"):
		var frontier_callback := Callable(self, "_on_assembly_frontier_reached")
		if not _coordinator.is_connected("assembly_frontier_reached", frontier_callback):
			_coordinator.connect("assembly_frontier_reached", frontier_callback)


func _on_construction_pulse_advanced(
	pulse_position: Vector2,
	_direction: Vector2,
	_speed: float,
	_frontier_platform: Node2D
) -> void:
	if _assembled or _visual_root == null or not is_instance_valid(_visual_root):
		return

	# Segment-to-point distance prevents a fast pulse from skipping a narrow prop
	# between frames. Only the path actually travelled by the pulse can trigger it.
	if _has_previous_pulse:
		var segment: Vector2 = pulse_position - _previous_pulse_position
		var closest_point: Vector2 = _previous_pulse_position
		if segment.length_squared() > 0.001:
			var t: float = clampf(
				(global_position - _previous_pulse_position).dot(segment)
					/ segment.length_squared(),
				0.0,
				1.0
			)
			closest_point = _previous_pulse_position + segment * t
		if global_position.distance_to(closest_point) <= pulse_trigger_radius:
			_begin_materialization(_direction)
	else:
		if global_position.distance_to(pulse_position) <= pulse_trigger_radius:
			_begin_materialization(_direction)

	_previous_pulse_position = pulse_position
	_has_previous_pulse = true


func _on_assembly_frontier_reached(platform: Node2D) -> void:
	if (
		_assembled
		or platform == null
		or not is_instance_valid(platform)
		or _visual_root == null
		or not is_instance_valid(_visual_root)
	):
		return
	# Objects positioned on a platform's row (coins, trap anchors, side structures)
	# can join the same event even if their center is not on the pulse's exact path.
	if absf(global_position.y - platform.global_position.y) <= frontier_height_tolerance:
		_begin_materialization(Vector2.UP)


func _begin_materialization(pulse_direction: Vector2) -> void:
	if _assembled or _visual_root == null or not is_instance_valid(_visual_root):
		return
	_assembled = true
	if _assembly_tween != null and _assembly_tween.is_valid():
		_assembly_tween.kill()

	var travel_direction: Vector2 = pulse_direction.normalized()
	if travel_direction.length_squared() <= 0.001:
		travel_direction = Vector2.UP

	_visual_root.visible = true
	_visual_root.position = _base_position - travel_direction * materialization_slide_distance
	_visual_root.scale = _base_scale * 0.90
	_visual_root.modulate = _base_modulate
	_visual_root.modulate.a = 0.0

	_assembly_tween = create_tween()
	_assembly_tween.set_parallel(true)
	_assembly_tween.tween_property(
		_visual_root,
		"position",
		_base_position,
		materialization_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_assembly_tween.tween_property(
		_visual_root,
		"scale",
		_base_scale,
		materialization_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_assembly_tween.tween_property(
		_visual_root,
		"modulate:a",
		_base_modulate.a,
		materialization_duration * 0.80
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_assembly_tween.set_parallel(false)
	_assembly_tween.tween_callback(_finish_materialization)


func _finish_materialization() -> void:
	_assembly_tween = null
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.position = _base_position
		_visual_root.scale = _base_scale
		_visual_root.modulate = _base_modulate
	_set_collision_shapes_enabled(true)


func _set_collision_shapes_enabled(enabled: bool) -> void:
	for shape in _collision_shapes:
		if shape != null and is_instance_valid(shape):
			shape.set_deferred("disabled", not enabled)
