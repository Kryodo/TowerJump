extends Node2D
## Long-form sequence test: Void -> A1 depth -> Void -> A2 integrated.
## The real main scene is instanced; production gameplay files remain untouched.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const BACKGROUND_SCRIPT: Script = preload("res://scripts/procedural_architecture_background.gd")
const BACKGROUND_NAVY := Color(0.007843138, 0.023529412, 0.050980393, 1.0) # #02060D
const WORLD_WIDTH: float = 720.0
const STRUCTURE_1_TOP_Y: float = -9000.0
const STRUCTURE_1_BOTTOM_Y: float = -6000.0
const STRUCTURE_2_TOP_Y: float = -26000.0
const STRUCTURE_2_BOTTOM_Y: float = -23000.0
# PaletteVariant 4 = A1 structural depth; 11 = A2/E dark-blue middle.
const A1_STRUCTURAL_DEPTH: int = 4
const A2_INTEGRATED_BLUE: int = 11

@export var initial_seed: int = 7319

var _game: Node2D
var _camera: Camera2D
var _ball: CharacterBody2D
var _base_background: ColorRect
var _height_label: Label
var _seed_label: Label
var _architecture_bands: Array[Node2D] = []
var _start_y: float
var _seed_rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seed_rng.randomize()
	_create_overlay()
	_spawn_game()


func _spawn_game() -> void:
	# Seed before instancing the game so fixed seeds reproduce platform patterns.
	seed(initial_seed)
	_game = MAIN_GAME_SCENE.instantiate() as Node2D
	if _game == null:
		push_error("Architecture Sequence Test: Could not instantiate scenes/main.tscn.")
		return
	_game.name = "TowerJumpMain"
	add_child(_game)

	_camera = _game.get_node_or_null("GameCamera") as Camera2D
	_ball = _game.get_node_or_null("Ball") as CharacterBody2D
	_base_background = _game.get_node_or_null("GameCamera/Background") as ColorRect
	if _camera == null or _ball == null or _base_background == null:
		push_error("Architecture Sequence Test: Main scene is missing GameCamera, Ball, or Background.")
		return

	_base_background.color = BACKGROUND_NAVY
	_start_y = _ball.global_position.y
	_architecture_bands.clear()
	_create_architecture_band("Structure1_A1Depth", STRUCTURE_1_TOP_Y, STRUCTURE_1_BOTTOM_Y, A1_STRUCTURAL_DEPTH)
	_create_architecture_band("Structure2_A2Integrated", STRUCTURE_2_TOP_Y, STRUCTURE_2_BOTTOM_Y, A2_INTEGRATED_BLUE)
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
		KEY_R:
			_set_seed(_seed_rng.randi_range(1, 2_000_000_000))
		KEY_1:
			_set_seed(7319)
		KEY_2:
			_set_seed(24017)
		KEY_3:
			_set_seed(91207)
		KEY_SPACE, KEY_ENTER:
			_restart_game()


func _create_architecture_band(band_name: String, top_y: float, bottom_y: float, palette_variant: int) -> void:
	var band := Node2D.new()
	band.name = band_name
	band.set_script(BACKGROUND_SCRIPT)
	band.set("environment_seed", initial_seed)
	band.set("palette_variant", palette_variant)
	band.set("world_width", WORLD_WIDTH)
	band.set("section_top_y", top_y)
	band.set("section_bottom_y", bottom_y)
	band.set("camera_path", NodePath("../GameCamera"))
	band.z_index = -50
	_game.add_child(band)
	# Match each bounded background fill to the global navy void.
	band.call("set_background_fill_override", BACKGROUND_NAVY)
	band.call("set_environment_seed", initial_seed)
	_architecture_bands.append(band)


func _create_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ArchitectureSequenceDebugOverlay"
	canvas.layer = 10
	add_child(canvas)

	_add_label(canvas, Vector2(22.0, 112.0),
		"ARCHITECTURE SEQUENCE  /  VOID -> STRUCTURE 1 -> VOID -> STRUCTURE 2",
		15, Color(0.43, 0.75, 0.85, 0.95))
	_add_label(canvas, Vector2(22.0, 136.0),
		"1 / 2 / 3: FIXED SEED   R: RANDOM SEED   SPACE / ENTER: RESTART RUN",
		10, Color(0.36, 0.54, 0.64, 0.95))

	_seed_label = Label.new()
	_seed_label.position = Vector2(22.0, 158.0)
	_set_label_theme(_seed_label, 13, Color(0.36, 0.66, 0.76, 0.95))
	canvas.add_child(_seed_label)

	_add_label(canvas, Vector2(22.0, 180.0),
		"S1: A1 DEPTH (DARK FAR / LIFTED BLUE-PURPLE MID) | S2: A2 (BLUE FAR / DARK BLUE MID)",
		10, Color(0.52, 0.70, 0.83, 0.96))

	_height_label = Label.new()
	_height_label.position = Vector2(22.0, 202.0)
	_set_label_theme(_height_label, 13, Color(0.45, 0.43, 0.74, 0.95))
	canvas.add_child(_height_label)

	_add_label(canvas, Vector2(22.0, 224.0),
		"VOID FIXED AT #02060D | MATCHED GEOMETRY SEED AND GAMEPLAY PRESENTATION",
		10, Color(0.36, 0.54, 0.64, 0.90))
	_update_seed_label(initial_seed)


func _add_label(parent: Node, position: Vector2, label_text: String, font_size: int, color: Color) -> void:
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


func _set_seed(value: int) -> void:
	initial_seed = value
	for band in _architecture_bands:
		band.call("set_environment_seed", value)
	_update_seed_label(value)


func _restart_game() -> void:
	get_tree().paused = false
	if is_instance_valid(_game):
		_game.free()
	_game = null
	_camera = null
	_ball = null
	_base_background = null
	_architecture_bands.clear()
	_spawn_game()


func _update_seed_label(value: int) -> void:
	if _seed_label != null:
		_seed_label.text = "ENVIRONMENT SEED  %d  (RESTART TO RESET ENTIRE RUN)" % value
