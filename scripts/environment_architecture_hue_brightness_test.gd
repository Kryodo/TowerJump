extends Node2D
## Isolated far-silhouette hue-versus-brightness study.
## Keeps the original TowerJump navy background, middle fill, geometry, accents,
## parallax and real gameplay presentation constant while selecting four far fills.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const BACKGROUND_SCRIPT: Script = preload("res://scripts/procedural_architecture_background.gd")

const BACKGROUND_NAVY := Color(0.007843138, 0.023529412, 0.050980393, 1.0) # #02060D
const SECTION_TOP_Y: float = -10400.0
const SECTION_BOTTOM_Y: float = 1600.0

enum TestVariant {
	CONTROL_A0 = 0,
	HUE_ONLY = 7,
	BRIGHTNESS_ONLY = 8,
	COMBINED_A2 = 5,
}

@export var initial_seed: int = 7319

var _game: Node2D
var _camera: Camera2D
var _ball: CharacterBody2D
var _base_background: ColorRect
var _background: Node2D
var _seed_label: Label
var _variant_label: Label
var _height_label: Label
var _test_variant: int = TestVariant.CONTROL_A0
var _start_y: float
var _seed_rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Keep test controls available even if the game-over screen pauses gameplay.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seed_rng.randomize()
	_create_overlay()
	_spawn_game()


func _spawn_game() -> void:
	# Make gameplay choices using Godot's global RNG repeatable when restarting
	# a selected seed. Architecture itself uses its own deterministic per-layer RNG.
	seed(initial_seed)

	# Reuse the actual game scene, preserving camera, ball/trail, platforms, motes,
	# glow and landing feedback.
	_game = MAIN_GAME_SCENE.instantiate() as Node2D
	if _game == null:
		push_error("Hue/Brightness Test: Could not instantiate scenes/main.tscn.")
		return
	_game.name = "TowerJumpMain"
	add_child(_game)

	_camera = _game.get_node_or_null("GameCamera") as Camera2D
	_ball = _game.get_node_or_null("Ball") as CharacterBody2D
	_base_background = _game.get_node_or_null("GameCamera/Background") as ColorRect
	if _camera == null or _ball == null or _base_background == null:
		push_error("Hue/Brightness Test: Main scene is missing GameCamera, Ball, or Background.")
		return

	# This experiment explicitly holds the original global void color constant.
	_base_background.color = BACKGROUND_NAVY
	_start_y = _ball.global_position.y
	_create_architecture()
	_update_variant_label()


func _process(_delta: float) -> void:
	if _ball == null or _height_label == null:
		return
	_height_label.text = "HEIGHT  %05d" % maxi(0, int(_start_y - _ball.global_position.y))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_A:
			_set_variant(TestVariant.CONTROL_A0)
		KEY_B:
			_set_variant(TestVariant.HUE_ONLY)
		KEY_C:
			_set_variant(TestVariant.BRIGHTNESS_ONLY)
		KEY_D:
			_set_variant(TestVariant.COMBINED_A2)
		KEY_R:
			_randomize_seed()
		KEY_1:
			_set_seed(7319)
		KEY_2:
			_set_seed(24017)
		KEY_3:
			_set_seed(91207)
		KEY_SPACE, KEY_ENTER:
			_restart_game()


func _create_architecture() -> void:
	_background = Node2D.new()
	_background.name = "HueBrightnessArchitecture"
	_background.set_script(BACKGROUND_SCRIPT)
	_background.set("environment_seed", initial_seed)
	_background.set("palette_variant", _test_variant)
	_background.set("world_width", 720.0)
	_background.set("section_top_y", SECTION_TOP_Y)
	_background.set("section_bottom_y", SECTION_BOTTOM_Y)
	_background.set("camera_path", NodePath("../GameCamera"))

	# Same layer order and game rendering conditions as the existing palette room.
	_background.z_index = -50
	_game.add_child(_background)
	_background.call("set_environment_seed", initial_seed)
	_background.call("set_palette_variant", _test_variant)
	_background.call("set_background_fill_override", BACKGROUND_NAVY)


func _create_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HueBrightnessDebugOverlay"
	canvas.layer = 10
	add_child(canvas)

	var title := Label.new()
	title.position = Vector2(22.0, 112.0)
	title.text = "TEST 4  /  FAR FILL: HUE VS BRIGHTNESS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.43, 0.75, 0.85, 0.95))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	canvas.add_child(title)

	var instructions := Label.new()
	instructions.position = Vector2(22.0, 136.0)
	instructions.text = "A: CONTROL   •   B: HUE ONLY   •   C: BRIGHTNESS ONLY   •   D: COMBINED A2"
	instructions.add_theme_font_size_override("font_size", 10)
	instructions.add_theme_color_override("font_color", Color(0.36, 0.54, 0.64, 0.95))
	instructions.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	instructions.add_theme_constant_override("outline_size", 3)
	canvas.add_child(instructions)

	_seed_label = Label.new()
	_seed_label.position = Vector2(22.0, 158.0)
	_seed_label.add_theme_font_size_override("font_size", 13)
	_seed_label.add_theme_color_override("font_color", Color(0.36, 0.66, 0.76, 0.95))
	_seed_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_seed_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_seed_label)

	_variant_label = Label.new()
	_variant_label.position = Vector2(22.0, 180.0)
	_variant_label.add_theme_font_size_override("font_size", 12)
	_variant_label.add_theme_color_override("font_color", Color(0.52, 0.70, 0.83, 0.96))
	_variant_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_variant_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_variant_label)

	_height_label = Label.new()
	_height_label.position = Vector2(22.0, 202.0)
	_height_label.add_theme_font_size_override("font_size", 13)
	_height_label.add_theme_color_override("font_color", Color(0.45, 0.43, 0.74, 0.95))
	_height_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_height_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_height_label)

	var fixed_note := Label.new()
	fixed_note.position = Vector2(22.0, 224.0)
	fixed_note.text = "BACKGROUND #02060D  •  MIDDLE FILL / GEOMETRY / ACCENTS FIXED"
	fixed_note.add_theme_font_size_override("font_size", 10)
	fixed_note.add_theme_color_override("font_color", Color(0.36, 0.54, 0.64, 0.90))
	fixed_note.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	fixed_note.add_theme_constant_override("outline_size", 3)
	canvas.add_child(fixed_note)

	var seed_instructions := Label.new()
	seed_instructions.position = Vector2(22.0, 244.0)
	seed_instructions.text = "1 / 2 / 3: FIXED SEED  •  R: RANDOM SEED  •  SPACE / ENTER: RESTART"
	seed_instructions.add_theme_font_size_override("font_size", 10)
	seed_instructions.add_theme_color_override("font_color", Color(0.36, 0.54, 0.64, 0.90))
	seed_instructions.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	seed_instructions.add_theme_constant_override("outline_size", 3)
	canvas.add_child(seed_instructions)

	_update_seed_label(initial_seed)


func _set_variant(value: int) -> void:
	_test_variant = value
	if _background != null:
		_background.call("set_palette_variant", _test_variant)
	_update_variant_label()


func _set_seed(value: int) -> void:
	initial_seed = value
	if _background != null:
		_background.call("set_environment_seed", value)
	_update_seed_label(value)


func _randomize_seed() -> void:
	_set_seed(_seed_rng.randi_range(1, 2_000_000_000))


func _restart_game() -> void:
	get_tree().paused = false
	if is_instance_valid(_game):
		_game.free()
	_game = null
	_camera = null
	_ball = null
	_base_background = null
	_background = null
	_spawn_game()


func _update_variant_label() -> void:
	if _variant_label == null:
		return
	match _test_variant:
		TestVariant.CONTROL_A0:
			_variant_label.text = "A  /  CONTROL - ORIGINAL DARK FAR FILLS"
		TestVariant.HUE_ONLY:
			_variant_label.text = "B  /  HUE ONLY - BLUE-PURPLE LEAN, MATCHED LUMINANCE"
		TestVariant.BRIGHTNESS_ONLY:
			_variant_label.text = "C  /  BRIGHTNESS ONLY - ORIGINAL HUE, A2-LIKE LUMINANCE"
		TestVariant.COMBINED_A2:
			_variant_label.text = "D  /  COMBINED A2 - BRIGHTER BLUE-DIRECTION FAR FILLS"


func _update_seed_label(value: int) -> void:
	if _seed_label != null:
		_seed_label.text = "ENVIRONMENT SEED  %d" % value
