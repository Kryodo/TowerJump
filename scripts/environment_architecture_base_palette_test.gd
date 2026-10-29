extends Node2D
## Final bounded comparison of A1 far-silhouette tints and A2 middle-fill alternatives.
## Keeps the original navy background, architecture geometry, accents and real game presentation fixed.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const BACKGROUND_SCRIPT: Script = preload("res://scripts/procedural_architecture_background.gd")

const BACKGROUND_NAVY := Color(0.007843138, 0.023529412, 0.050980393, 1.0) # #02060D
const SECTION_TOP_Y: float = -10400.0
const SECTION_BOTTOM_Y: float = 1600.0

enum TestVariant {
	A1_BASELINE = 4,
	A1_DARK_FAR = 9,
	A1_BRIGHT_FAR = 10,
	A2_BASELINE = 5,
	A2_DARK_BLUE_MID = 11,
	A2_DARK_PURPLE_MID = 12,
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
var _test_variant: int = TestVariant.A1_BASELINE
var _start_y: float
var _seed_rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Keep test controls available if the game-over screen pauses gameplay.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seed_rng.randomize()
	_create_overlay()
	_spawn_game()


func _spawn_game() -> void:
	# Keep the foreground repeatable when restarting a selected seed.
	seed(initial_seed)

	# Instantiate the actual game scene so camera, ball/trail, platforms,
	# ambient motes, WorldEnvironment and glow stay representative.
	_game = MAIN_GAME_SCENE.instantiate() as Node2D
	if _game == null:
		push_error("Base Palette Test: Could not instantiate scenes/main.tscn.")
		return
	_game.name = "TowerJumpMain"
	add_child(_game)

	_camera = _game.get_node_or_null("GameCamera") as Camera2D
	_ball = _game.get_node_or_null("Ball") as CharacterBody2D
	_base_background = _game.get_node_or_null("GameCamera/Background") as ColorRect
	if _camera == null or _ball == null or _base_background == null:
		push_error("Base Palette Test: Main scene is missing GameCamera, Ball, or Background.")
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
			_set_variant(TestVariant.A1_BASELINE)
		KEY_B:
			_set_variant(TestVariant.A1_DARK_FAR)
		KEY_C:
			_set_variant(TestVariant.A1_BRIGHT_FAR)
		KEY_D:
			_set_variant(TestVariant.A2_BASELINE)
		KEY_E:
			_set_variant(TestVariant.A2_DARK_BLUE_MID)
		KEY_F:
			_set_variant(TestVariant.A2_DARK_PURPLE_MID)
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
	_background.name = "BasePaletteArchitecture"
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
	canvas.name = "BasePaletteDebugOverlay"
	canvas.layer = 10
	add_child(canvas)

	var title := Label.new()
	title.position = Vector2(22.0, 112.0)
	title.text = "TEST 5  /  BASE COMPOSITION PALETTE"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.43, 0.75, 0.85, 0.95))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	canvas.add_child(title)

	var a1_instructions := Label.new()
	a1_instructions.position = Vector2(22.0, 136.0)
	a1_instructions.text = "A: A1 BASE   B: A1 DARK FAR TINT   C: A1 BRIGHT FAR TINT"
	a1_instructions.add_theme_font_size_override("font_size", 10)
	a1_instructions.add_theme_color_override("font_color", Color(0.36, 0.54, 0.64, 0.95))
	a1_instructions.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	a1_instructions.add_theme_constant_override("outline_size", 3)
	canvas.add_child(a1_instructions)

	var a2_instructions := Label.new()
	a2_instructions.position = Vector2(22.0, 152.0)
	a2_instructions.text = "D: A2 BASE   E: A2 DARK BLUE MID   F: A2 DARK BLUE-PURPLE MID"
	a2_instructions.add_theme_font_size_override("font_size", 10)
	a2_instructions.add_theme_color_override("font_color", Color(0.36, 0.54, 0.64, 0.95))
	a2_instructions.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	a2_instructions.add_theme_constant_override("outline_size", 3)
	canvas.add_child(a2_instructions)

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
		TestVariant.A1_BASELINE:
			_variant_label.text = "A  /  A1 BASELINE - NEAR-BLACK FAR, BLUE-PURPLE MID"
		TestVariant.A1_DARK_FAR:
			_variant_label.text = "B  /  A1 WITH DARK INDIGO FAR TINT"
		TestVariant.A1_BRIGHT_FAR:
			_variant_label.text = "C  /  A1 WITH BRIGHTER BLUE-PURPLE FAR TINT"
		TestVariant.A2_BASELINE:
			_variant_label.text = "D  /  A2 BASELINE - BRIGHTER FAR, ORIGINAL DARK MID"
		TestVariant.A2_DARK_BLUE_MID:
			_variant_label.text = "E  /  A2 WITH DARK BLUE MIDDLE FILL"
		TestVariant.A2_DARK_PURPLE_MID:
			_variant_label.text = "F  /  A2 WITH DARK BLUE-PURPLE MIDDLE FILL"


func _update_seed_label(value: int) -> void:
	if _seed_label != null:
		_seed_label.text = "ENVIRONMENT SEED  %d" % value
