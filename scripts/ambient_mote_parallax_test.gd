extends Node2D
## Compares the existing camera-attached ambient motes with three parallax depths.
## The main game scene is instantiated as a reference; production files are untouched.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const MOTE_PATHS: Array[NodePath] = [
	NodePath("GameCamera/AmbientMotes"),
	NodePath("GameCamera/AmbientMotesNear"),
	NodePath("GameCamera/AmbientMoteHighlights"),
]
const MOTE_LAYER_NAMES: Array[String] = [
	"AmbientMotesFarParallax",
	"AmbientMotesMidParallax",
	"AmbientMotesNearParallax",
]
const REPEAT_HEIGHT: float = 1520.0

enum TestVariant {
	CURRENT_SINGLE_DEPTH,
	ARCHITECTURE_MATCHED,
	SUBTLE_DEPTH,
	PRONOUNCED_DEPTH,
}

@export var initial_seed: int = 7319

var _game: Node2D
var _camera: Camera2D
var _ball: CharacterBody2D
var _emitters: Array[GPUParticles2D] = []
var _initial_transforms: Array[Transform2D] = []
var _initial_local_coords: Array[bool] = []
var _parallax_layers: Array[Parallax2D] = []
var _seed_label: Label
var _variant_label: Label
var _height_label: Label
var _variant: TestVariant = TestVariant.CURRENT_SINGLE_DEPTH
var _start_y: float
var _seed_rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seed_rng.randomize()
	_create_overlay()
	_spawn_game()


func _spawn_game() -> void:
	# Seed gameplay before instancing so each restart uses the same run setup.
	seed(initial_seed)
	_game = MAIN_GAME_SCENE.instantiate() as Node2D
	if _game == null:
		push_error("Ambient Mote Parallax: Could not instantiate scenes/main.tscn.")
		return
	_game.name = "TowerJumpMain"
	add_child(_game)

	_camera = _game.get_node_or_null("GameCamera") as Camera2D
	_ball = _game.get_node_or_null("Ball") as CharacterBody2D
	if _camera == null or _ball == null:
		push_error("Ambient Mote Parallax: Main scene is missing GameCamera or Ball.")
		return

	_emitters.clear()
	_initial_transforms.clear()
	_initial_local_coords.clear()
	for path in MOTE_PATHS:
		var emitter := _game.get_node_or_null(path) as GPUParticles2D
		if emitter == null:
			push_error("Ambient Mote Parallax: Missing mote emitter at %s." % path)
			return
		_emitters.append(emitter)
		_initial_transforms.append(emitter.transform)
		_initial_local_coords.append(emitter.local_coords)

	_start_y = _ball.global_position.y
	_set_variant(_variant)
	_update_seed_label(initial_seed)


func _process(_delta: float) -> void:
	if _ball != null and _height_label != null:
		_height_label.text = "CLIMB HEIGHT  %05d" % maxi(0, int(_start_y - _ball.global_position.y))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_A:
			_set_variant(TestVariant.CURRENT_SINGLE_DEPTH)
		KEY_B:
			_set_variant(TestVariant.ARCHITECTURE_MATCHED)
		KEY_C:
			_set_variant(TestVariant.SUBTLE_DEPTH)
		KEY_D:
			_set_variant(TestVariant.PRONOUNCED_DEPTH)
		KEY_1:
			_set_seed(7319)
		KEY_2:
			_set_seed(24017)
		KEY_3:
			_set_seed(91207)
		KEY_R:
			_set_seed(_seed_rng.randi_range(1, 2_000_000_000))
		KEY_SPACE, KEY_ENTER:
			_restart_game()


func _set_variant(value: TestVariant) -> void:
	_variant = value
	_restore_current_emitters()

	match _variant:
		TestVariant.CURRENT_SINGLE_DEPTH:
			pass
		TestVariant.ARCHITECTURE_MATCHED:
			_apply_parallax_scales([0.18, 0.46, 0.82])
		TestVariant.SUBTLE_DEPTH:
			_apply_parallax_scales([0.10, 0.30, 0.55])
		TestVariant.PRONOUNCED_DEPTH:
			_apply_parallax_scales([0.28, 0.62, 0.92])

	_update_variant_label()


func _restore_current_emitters() -> void:
	if _camera == null:
		return

	for i in range(_emitters.size()):
		var emitter: GPUParticles2D = _emitters[i]
		if not is_instance_valid(emitter):
			continue
		if emitter.get_parent() != _camera:
			emitter.reparent(_camera, true)
		emitter.transform = _initial_transforms[i]
		emitter.local_coords = _initial_local_coords[i]
		emitter.restart()

	for layer in _parallax_layers:
		if is_instance_valid(layer):
			layer.queue_free()
	_parallax_layers.clear()


func _apply_parallax_scales(scales: Array[float]) -> void:
	if _camera == null:
		return

	for i in range(_emitters.size()):
		var layer := Parallax2D.new()
		layer.name = MOTE_LAYER_NAMES[i]
		layer.scroll_scale = Vector2(1.0, scales[i])
		layer.repeat_size = Vector2(0.0, REPEAT_HEIGHT)
		layer.repeat_times = 2
		_game.add_child(layer)
		layer.global_position = _camera.global_position
		_parallax_layers.append(layer)

		var emitter: GPUParticles2D = _emitters[i]
		emitter.reparent(layer, true)
		# In local coordinates existing particles move with the parallax layer.
		emitter.local_coords = true
		emitter.restart()


func _set_seed(value: int) -> void:
	initial_seed = value
	_restart_game()


func _restart_game() -> void:
	get_tree().paused = false
	if is_instance_valid(_game):
		_game.free()
	_game = null
	_camera = null
	_ball = null
	_emitters.clear()
	_initial_transforms.clear()
	_initial_local_coords.clear()
	_parallax_layers.clear()
	_spawn_game()


func _create_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "AmbientMoteParallaxOverlay"
	canvas.layer = 10
	add_child(canvas)

	_add_label(
		canvas,
		Vector2(22.0, 110.0),
		"AMBIENT MOTE PARALLAX STUDY",
		14,
		Color(0.43, 0.75, 0.85, 0.95)
	)
	_add_label(
		canvas,
		Vector2(22.0, 133.0),
		"A: CURRENT ONE-DEPTH   B: ARCHITECTURE-MATCHED   C: SUBTLE   D: PRONOUNCED",
		9,
		Color(0.36, 0.54, 0.64, 0.95)
	)

	_seed_label = Label.new()
	_seed_label.position = Vector2(22.0, 155.0)
	_set_label_theme(_seed_label, 13, Color(0.36, 0.66, 0.76, 0.95))
	canvas.add_child(_seed_label)

	_variant_label = Label.new()
	_variant_label.position = Vector2(22.0, 177.0)
	_set_label_theme(_variant_label, 12, Color(0.52, 0.70, 0.83, 0.96))
	canvas.add_child(_variant_label)

	_height_label = Label.new()
	_height_label.position = Vector2(22.0, 199.0)
	_set_label_theme(_height_label, 13, Color(0.45, 0.43, 0.74, 0.95))
	canvas.add_child(_height_label)

	_add_label(
		canvas,
		Vector2(22.0, 221.0),
		"1 / 2 / 3: FIXED RUN SEED   R: RANDOM   SPACE / ENTER: RESTART",
		10,
		Color(0.36, 0.54, 0.64, 0.90)
	)
	_add_label(
		canvas,
		Vector2(22.0, 237.0),
		"ALL MODES KEEP THE CURRENT MOTE COUNTS, COLORS, SIZES AND EMISSION",
		9,
		Color(0.36, 0.54, 0.64, 0.90)
	)
	_update_seed_label(initial_seed)


func _add_label(
	parent: Node,
	position: Vector2,
	label_text: String,
	font_size: int,
	color: Color
) -> void:
	var label := Label.new()
	label.position = position
	label.text = label_text
	_set_label_theme(label, font_size, color)
	parent.add_child(label)


func _set_label_theme(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	label.add_theme_constant_override("outline_size", 3)


func _update_variant_label() -> void:
	if _variant_label == null:
		return
	match _variant:
		TestVariant.CURRENT_SINGLE_DEPTH:
			_variant_label.text = "A  /  CURRENT SINGLE GLOBAL-SPACE DEPTH"
		TestVariant.ARCHITECTURE_MATCHED:
			_variant_label.text = "B  /  FAR 0.18   MID 0.46   NEAR 0.82"
		TestVariant.SUBTLE_DEPTH:
			_variant_label.text = "C  /  FAR 0.10   MID 0.30   NEAR 0.55"
		TestVariant.PRONOUNCED_DEPTH:
			_variant_label.text = "D  /  FAR 0.28   MID 0.62   NEAR 0.92"


func _update_seed_label(value: int) -> void:
	if _seed_label != null:
		_seed_label.text = "RUN SEED  %d  (RESTART TO RESET)" % value
