extends Node2D
## Follow-up palette comparison: refine the successful A2/E recipe and test where purple tint belongs.
## The global navy backdrop and all non-fill presentation stay fixed.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const BACKGROUND_SCRIPT: Script = preload("res://scripts/procedural_architecture_background.gd")

const BACKGROUND_NAVY := Color(0.007843138, 0.023529412, 0.050980393, 1.0) # #02060D
const SECTION_TOP_Y: float = -10400.0
const SECTION_BOTTOM_Y: float = 1600.0

enum TestVariant {
	E_BASELINE = 11,
	E_BALANCED = 13,
	E_BRIGHTER = 14,
	PURPLE_FAR_BLUE_MID = 15,
	BLUE_FAR_PURPLE_MID = 16,
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
var _test_variant: int = TestVariant.E_BASELINE
var _start_y: float
var _seed_rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seed_rng.randomize()
	_create_overlay()
	_spawn_game()


func _spawn_game() -> void:
	seed(initial_seed)
	_game = MAIN_GAME_SCENE.instantiate() as Node2D
	if _game == null:
		push_error("Follow-up Palette Test: Could not instantiate scenes/main.tscn.")
		return
	_game.name = "TowerJumpMain"
	add_child(_game)

	_camera = _game.get_node_or_null("GameCamera") as Camera2D
	_ball = _game.get_node_or_null("Ball") as CharacterBody2D
	_base_background = _game.get_node_or_null("GameCamera/Background") as ColorRect
	if _camera == null or _ball == null or _base_background == null:
		push_error("Follow-up Palette Test: Main scene is missing GameCamera, Ball, or Background.")
		return

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
			_set_variant(TestVariant.E_BASELINE)
		KEY_B:
			_set_variant(TestVariant.E_BALANCED)
		KEY_C:
			_set_variant(TestVariant.E_BRIGHTER)
		KEY_D:
			_set_variant(TestVariant.PURPLE_FAR_BLUE_MID)
		KEY_E:
			_set_variant(TestVariant.BLUE_FAR_PURPLE_MID)
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
	_background.name = "FollowupPaletteArchitecture"
	_background.set_script(BACKGROUND_SCRIPT)
	_background.set("environment_seed", initial_seed)
	_background.set("palette_variant", _test_variant)
	_background.set("world_width", 720.0)
	_background.set("section_top_y", SECTION_TOP_Y)
	_background.set("section_bottom_y", SECTION_BOTTOM_Y)
	_background.set("camera_path", NodePath("../GameCamera"))
	_background.z_index = -50
	_game.add_child(_background)
	_background.call("set_environment_seed", initial_seed)
	_background.call("set_palette_variant", _test_variant)
	_background.call("set_background_fill_override", BACKGROUND_NAVY)


func _create_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "FollowupPaletteDebugOverlay"
	canvas.layer = 10
	add_child(canvas)

	var title := Label.new()
	title.position = Vector2(22.0, 112.0)
	title.text = "TEST 6  /  E PALETTE REFINEMENTS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.43, 0.75, 0.85, 0.95))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	canvas.add_child(title)

	var instructions_one := Label.new()
	instructions_one.position = Vector2(22.0, 136.0)
	instructions_one.text = "A: E BASE   B: BALANCED E   C: BRIGHTER E"
	instructions_one.add_theme_font_size_override("font_size", 10)
	instructions_one.add_theme_color_override("font_color", Color(0.36, 0.54, 0.64, 0.95))
	instructions_one.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	instructions_one.add_theme_constant_override("outline_size", 3)
	canvas.add_child(instructions_one)

	var instructions_two := Label.new()
	instructions_two.position = Vector2(22.0, 152.0)
	instructions_two.text = "D: PURPLE FAR + BLUE MID   E: BLUE FAR + PURPLE MID"
	instructions_two.add_theme_font_size_override("font_size", 10)
	instructions_two.add_theme_color_override("font_color", Color(0.36, 0.54, 0.64, 0.95))
	instructions_two.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	instructions_two.add_theme_constant_override("outline_size", 3)
	canvas.add_child(instructions_two)

	_seed_label = Label.new()
	_seed_label.position = Vector2(22.0, 174.0)
	_seed_label.add_theme_font_size_override("font_size", 13)
	_seed_label.add_theme_color_override("font_color", Color(0.36, 0.66, 0.76, 0.95))
	_seed_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_seed_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_seed_label)

	_variant_label = Label.new()
	_variant_label.position = Vector2(22.0, 196.0)
	_variant_label.add_theme_font_size_override("font_size", 12)
	_variant_label.add_theme_color_override("font_color", Color(0.52, 0.70, 0.83, 0.96))
	_variant_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_variant_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_variant_label)

	_height_label = Label.new()
	_height_label = Label.new()
	_height_label.position = Vector2(22.0, 218.0)
	_height_label.add_theme_font_size_override("font_size", 13)
	_height_label.add_theme_color_override("font_color", Color(0.45, 0.43, 0.74, 0.95))
	_height_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_height_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_height_label)

	var fixed_note := Label.new()
	fixed_note.position = Vector2(22.0, 240.0)
	fixed_note.text = "BACKGROUND #02060D  •  GEOMETRY / ACCENTS / PARALLAX FIXED"
	fixed_note.add_theme_font_size_override("font_size", 10)
	fixed_note.add_theme_color_override("font_color", Color(0.36, 0.54, 0.64, 0.90))
	fixed_note.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	fixed_note.add_theme_constant_override("outline_size", 3)
	canvas.add_child(fixed_note)

	var seed_instructions := Label.new()
	seed_instructions.position = Vector2(22.0, 260.0)
	seed_instructions.text = "1 / 2 / 3: FIXED SEED  •  R: RANDOM  •  SPACE / ENTER: RESTART"
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
		TestVariant.E_BASELINE:
			_variant_label.text = "A  /  E BASELINE - A2 FAR + DARK BLUE MID"
		TestVariant.E_BALANCED:
			_variant_label.text = "B  /  BALANCED E - DARKER BLUE-PURPLE FAR + LIFTED MID"
		TestVariant.E_BRIGHTER:
			_variant_label.text = "C  /  BRIGHTER E - BRIGHTER BLUE-PURPLE FAR + BLUE MID"
		TestVariant.PURPLE_FAR_BLUE_MID:
			_variant_label.text = "D  /  PURPLE FAR FILL + DARK BLUE MIDDLE"
		TestVariant.BLUE_FAR_PURPLE_MID:
			_variant_label.text = "E  /  BLUE FAR FILL + PURPLE MIDDLE"
		
func _update_seed_label(value: int) -> void:
	if _seed_label != null:
		_seed_label.text = "ENVIRONMENT SEED  %d" % value
