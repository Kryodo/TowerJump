extends Node2D
## Architecture study wrapped around the actual Main scene.
## This intentionally reuses TowerJump's production WorldEnvironment, camera,
## ball, platforms, ambient motes, HUD and feedback so glow/readability are tested
## under the same rendering conditions as normal gameplay.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const BACKGROUND_SCRIPT: Script = preload("res://scripts/procedural_architecture_background.gd")

@export var initial_seed: int = 7319

var _game: Node2D
var _camera: Camera2D
var _ball: CharacterBody2D
var _background: Node2D
var _seed_label: Label
var _palette_label: Label
var _height_label: Label
var _palette_variant: int = 0
var _start_y: float
var _seed_rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Keep seed/restart controls available after the game-over screen pauses the
	# gameplay tree. This wrapper affects only the isolated test scene.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seed_rng.randomize()
	_create_overlay()
	_spawn_game()


func _spawn_game() -> void:
	# Reuse the actual main scene instead of a separately reconstructed lookalike.
	# This preserves the main scene's Canvas background mode, glow values, HDR
	# sources, ambient motes, ball/trail, platform glow and landing responses.
	_game = MAIN_GAME_SCENE.instantiate() as Node2D
	if _game == null:
		push_error("Architecture Test: Could not instantiate scenes/main.tscn.")
		return
	_game.name = "TowerJumpMain"
	add_child(_game)

	_camera = _game.get_node_or_null("GameCamera") as Camera2D
	_ball = _game.get_node_or_null("Ball") as CharacterBody2D
	if _camera == null or _ball == null:
		push_error("Architecture Test: Main scene is missing GameCamera or Ball.")
		return

	_start_y = _ball.global_position.y
	_create_background()


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
			_set_palette_variant(0)
		KEY_B:
			_set_palette_variant(1)
		KEY_C:
			_set_palette_variant(2)
		KEY_D:
			_set_palette_variant(3)
		KEY_E:
			_set_palette_variant(4)
		KEY_F:
			_set_palette_variant(5)
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


func _create_background() -> void:
	_background = Node2D.new()
	_background.name = "CoherentArchitectureBackground"
	_background.set_script(BACKGROUND_SCRIPT)
	_background.set("environment_seed", initial_seed)
	_background.set("palette_variant", _palette_variant)
	_background.set("world_width", 720.0)
	_background.set("section_top_y", -10400.0)
	_background.set("section_bottom_y", 1600.0)
	_background.set("camera_path", NodePath("../GameCamera"))

	# The main scene's background ColorRect sits at z=-60 and its ambient motes
	# around z=-30. The architecture sits between them: over the base fill but
	# below the actual game's ambient glow particles and gameplay.
	_background.z_index = -50
	_game.add_child(_background)
	_background.call("set_environment_seed", initial_seed)
	_background.call("set_palette_variant", _palette_variant)


func _create_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ArchitectureDebugOverlay"
	canvas.layer = 10
	add_child(canvas)

	var title := Label.new()
	title.position = Vector2(22.0, 112.0)
	title.text = "TEST 1  /  BACKGROUND + SILHOUETTE PALETTE"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.43, 0.75, 0.85, 0.95))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	canvas.add_child(title)

	var instructions := Label.new()
	instructions.position = Vector2(22.0, 136.0)
	instructions.text = "A–F: PALETTE   •   1 / 2 / 3: FIXED SEED   •   R: NEW SEED   •   SPACE: RESTART"
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

	_height_label = Label.new()
	_palette_label = Label.new()
	_palette_label.position = Vector2(22.0, 180.0)
	_palette_label.add_theme_font_size_override("font_size", 13)
	_palette_label.add_theme_color_override("font_color", Color(0.52, 0.70, 0.83, 0.96))
	_palette_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_palette_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_palette_label)

	_height_label.position = Vector2(22.0, 202.0)
	_height_label.add_theme_font_size_override("font_size", 13)
	_height_label.add_theme_color_override("font_color", Color(0.45, 0.43, 0.74, 0.95))
	_height_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_height_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_height_label)
	_update_seed_label(initial_seed)
	_update_palette_label()


func _randomize_seed() -> void:
	_set_seed(_seed_rng.randi_range(1, 2_000_000_000))


func _set_palette_variant(value: int) -> void:
	_palette_variant = clampi(value, 0, 5)
	if _background != null:
		_background.call("set_palette_variant", _palette_variant)
	_update_palette_label()


func _set_seed(value: int) -> void:
	if _background == null:
		return
	initial_seed = value
	_background.call("set_environment_seed", value)
	_update_seed_label(value)


func _restart_game() -> void:
	get_tree().paused = false
	if is_instance_valid(_game):
		_game.free()
	_game = null
	_camera = null
	_ball = null
	_background = null
	_spawn_game()


func _update_palette_label() -> void:
	if _palette_label == null:
		return
	match _palette_variant:
		0:
			_palette_label.text = "A0  /  CURRENT NAVY CONTROL"
		1:
			_palette_label.text = "B  /  NEAR-BLACK + REVERSED NAVY MASSES"
		2:
			_palette_label.text = "C  /  INTERMEDIATE BLUE-BLACK (CONTROL)"
		3:
			_palette_label.text = "D  /  C + SLIGHTLY BRIGHTER MIDDLE FILL"
		4:
			_palette_label.text = "E  /  A1 - NAVY + BRIGHTER MIDDLE FILL"
		5:
			_palette_label.text = "F  /  A2 - NAVY + BRIGHTER BLUE FAR MASSES"


func _update_seed_label(value: int) -> void:
	if _seed_label != null:
		_seed_label.text = "ENVIRONMENT SEED  %d" % value
