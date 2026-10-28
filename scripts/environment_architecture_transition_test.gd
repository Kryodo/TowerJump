extends Node2D
## A separate void -> structure -> void study using the actual TowerJump main
## scene. The production background stays #02060D while a bounded architecture
## band enters and leaves the view through the existing three parallax layers.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const BACKGROUND_SCRIPT: Script = preload("res://scripts/procedural_architecture_background.gd")

const STRUCTURE_TOP_Y: float = -9000.0
const STRUCTURE_BOTTOM_Y: float = -6000.0

const BG_ORIGINAL_NAVY := Color(0.007843138, 0.023529412, 0.050980393, 1.0) # #02060D
const BG_INTERMEDIATE_BLUE_BLACK := Color(0.003921569, 0.019607844, 0.039215688, 1.0) # #01050A
const BG_NEAR_BLACK := Color(0.003921569, 0.011764706, 0.02745098, 1.0) # #010307
const D_BACKGROUND_PALETTE_VARIANT: int = 3

# Existing palette enum values: E/A1 = 4, F/A2 = 5, new hybrid G = 6.
enum ArchitectureRecipe {
	A1_STRUCTURAL_DEPTH = 4,
	A2_INTEGRATED_FAR = 5,
	HYBRID = 6,
}

@export var initial_seed: int = 7319

var _game: Node2D
var _camera: Camera2D
var _ball: CharacterBody2D
var _base_background: ColorRect
var _background: Node2D
var _seed_label: Label
var _recipe_label: Label
var _height_label: Label
var _recipe: int = ArchitectureRecipe.A1_STRUCTURAL_DEPTH
var _d_background_trial: int = -1 # -1 means use E/F/G with the original navy background.
var _start_y: float
var _seed_rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Keep the test controls available if gameplay enters its paused game-over state.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seed_rng.randomize()
	_create_overlay()
	_spawn_game()


func _spawn_game() -> void:
	# Seed the global RNG before the real game enters the tree. This keeps the
	# platform-pattern choices that use Godot's global RNG comparable on restart.
	seed(initial_seed)

	# Use the actual game scene so camera follow, platforms, ball/trail, motes,
	# world glow and landing feedback match the normal game presentation.
	_game = MAIN_GAME_SCENE.instantiate() as Node2D
	if _game == null:
		push_error("Architecture Transition Test: Could not instantiate scenes/main.tscn.")
		return
	_game.name = "TowerJumpMain"
	add_child(_game)

	_camera = _game.get_node_or_null("GameCamera") as Camera2D
	_ball = _game.get_node_or_null("Ball") as CharacterBody2D
	_base_background = _game.get_node_or_null("GameCamera/Background") as ColorRect
	if _camera == null or _ball == null or _base_background == null:
		push_error("Architecture Transition Test: Main scene is missing GameCamera, Ball, or GameCamera/Background.")
		return

	_start_y = _ball.global_position.y
	_create_architecture()
	_update_recipe_label()


func _process(_delta: float) -> void:
	if _ball == null or _height_label == null:
		return
	_height_label.text = "CLIMB HEIGHT  %05d" % maxi(0, int(_start_y - _ball.global_position.y))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_E:
			_set_recipe(ArchitectureRecipe.A1_STRUCTURAL_DEPTH)
		KEY_F:
			_set_recipe(ArchitectureRecipe.A2_INTEGRATED_FAR)
		KEY_G:
			_set_recipe(ArchitectureRecipe.HYBRID)
		KEY_H:
			_set_d_background_trial(0)
		KEY_I:
			_set_d_background_trial(1)
		KEY_J:
			_set_d_background_trial(2)
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
	_background.name = "BoundedArchitectureTransition"
	_background.set_script(BACKGROUND_SCRIPT)
	_background.set("environment_seed", initial_seed)
	_background.set("palette_variant", int(_recipe))
	_background.set("world_width", 720.0)
	_background.set("section_top_y", STRUCTURE_TOP_Y)
	_background.set("section_bottom_y", STRUCTURE_BOTTOM_Y)
	_background.set("camera_path", NodePath("../GameCamera"))

	# Same placement used by the existing architecture study: the architecture
	# sits over the real background fill but behind the game's ambient mote layers.
	_background.z_index = -50
	_game.add_child(_background)
	_background.call("set_environment_seed", initial_seed)
	_apply_selected_presentation()


func _create_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ArchitectureTransitionDebugOverlay"
	canvas.layer = 10
	add_child(canvas)

	var title := Label.new()
	title.position = Vector2(22.0, 112.0)
	title.text = "TEST 3  /  VOID  ->  STRUCTURE  ->  VOID"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.43, 0.75, 0.85, 0.95))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	canvas.add_child(title)

	var instructions := Label.new()
	instructions.position = Vector2(22.0, 136.0)
	instructions.text = "E / F / G: RECIPE   •   H / I / J: D + BACKGROUND   •   1 / 2 / 3: SEED   •   SPACE: RESTART"
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

	_recipe_label = Label.new()
	_recipe_label.position = Vector2(22.0, 180.0)
	_recipe_label.add_theme_font_size_override("font_size", 13)
	_recipe_label.add_theme_color_override("font_color", Color(0.52, 0.70, 0.83, 0.96))
	_recipe_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_recipe_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_recipe_label)

	_height_label = Label.new()
	_height_label.position = Vector2(22.0, 202.0)
	_height_label.add_theme_font_size_override("font_size", 13)
	_height_label.add_theme_color_override("font_color", Color(0.45, 0.43, 0.74, 0.95))
	_height_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_height_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_height_label)

	var background_note := Label.new()
	background_note.position = Vector2(22.0, 224.0)
	background_note.text = "H / I / J CHANGE THE WHOLE-WORLD BACKGROUND; D FILLS STAY FIXED"
	background_note.add_theme_font_size_override("font_size", 10)
	background_note.add_theme_color_override("font_color", Color(0.36, 0.54, 0.64, 0.90))
	background_note.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	background_note.add_theme_constant_override("outline_size", 3)
	canvas.add_child(background_note)

	_update_seed_label(initial_seed)


func _set_recipe(value: int) -> void:
	_recipe = value
	_d_background_trial = -1
	_apply_selected_presentation()
	_update_recipe_label()


func _set_d_background_trial(value: int) -> void:
	# Keep D's structural fills identical while switching the entire world's backdrop.
	_recipe = D_BACKGROUND_PALETTE_VARIANT
	_d_background_trial = clampi(value, 0, 2)
	_apply_selected_presentation()
	_update_recipe_label()


func _selected_background_color() -> Color:
	match _d_background_trial:
		1:
			return BG_INTERMEDIATE_BLUE_BLACK
		2:
			return BG_NEAR_BLACK
		_:
			return BG_ORIGINAL_NAVY


func _apply_selected_presentation() -> void:
	var selected_background: Color = _selected_background_color()
	if _base_background != null:
		# This ColorRect covers the whole viewport on every frame/height, so this is
		# a true global void-color change rather than a band confined to the structure.
		_base_background.color = selected_background
	if _background != null:
		_background.call("set_palette_variant", _recipe)
		# Match the transition-band fill to the global background so no color seam
		# appears at the bounds. The manager override is off by default in the A-F scene.
		_background.call("set_background_fill_override", selected_background)


func _set_seed(value: int) -> void:
	if _background == null:
		return
	initial_seed = value
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
	_background = null
	_spawn_game()


func _update_recipe_label() -> void:
	if _recipe_label == null:
		return
	if _d_background_trial >= 0:
		match _d_background_trial:
			0:
				_recipe_label.text = "H  /  D FILLS + ORIGINAL NAVY  #02060D"
			1:
				_recipe_label.text = "I  /  D FILLS + INTERMEDIATE  #01050A"
			2:
				_recipe_label.text = "J  /  D FILLS + NEAR-BLACK  #010307"
		return
	match _recipe:
		ArchitectureRecipe.A1_STRUCTURAL_DEPTH:
			_recipe_label.text = "E / A1  -  STRUCTURAL DEPTH"
		ArchitectureRecipe.A2_INTEGRATED_FAR:
			_recipe_label.text = "F / A2  -  INTEGRATED FAR SILHOUETTES"
		ArchitectureRecipe.HYBRID:
			_recipe_label.text = "G  -  HYBRID (A2 FAR + A1 MIDDLE)"


func _update_seed_label(value: int) -> void:
	if _seed_label != null:
		_seed_label.text = "ENVIRONMENT SEED  %d" % value
