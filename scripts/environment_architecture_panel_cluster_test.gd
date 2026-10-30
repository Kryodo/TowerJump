extends Node2D
## Compact-panel refinement: compares the previous cluster layout with taller bays,
## smaller light-bearing apertures, and restrained flicker instead of traveling pulses.
## The actual main scene is used; production gameplay files remain untouched.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const BACKGROUND_SCRIPT: Script = preload("res://scripts/procedural_architecture_background.gd")
const BACKGROUND_NAVY := Color(0.007843138, 0.023529412, 0.050980393, 1.0) # #02060D
const WORLD_WIDTH: float = 720.0
const STRUCTURE_TOP_Y: float = -9000.0
const STRUCTURE_BOTTOM_Y: float = -6000.0

# PaletteVariant IDs from procedural_architecture_draw_layer.gd.
const PALETTE_A1_DEPTH: int = 4
const PALETTE_A2_INTEGRATED: int = 11
# LifeTreatment IDs are appended after the existing static treatment mappings.
const LIFE_BASELINE: int = 0
const LIFE_STRUCTURED_COMBINED: int = 5
const LIFE_PANEL_CLUSTERS: int = 6
const LIFE_PANEL_ENERGY_STATES: int = 7
const LIFE_COMPACT_PANEL_STATES: int = 8
const LIFE_COMPACT_PANEL_FLICKER: int = 9

enum TestVariant {
	A1_BASELINE,
	A1_EXISTING_COMBINED,
	A1_PANEL_CLUSTERS,
	A1_COMPACT_STATIC,
	A1_COMPACT_FLICKER,
	A2_BASELINE,
	A2_EXISTING_COMBINED,
	A2_PANEL_CLUSTERS,
	A2_COMPACT_STATIC,
	A2_COMPACT_FLICKER,
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
var _variant: TestVariant = TestVariant.A1_BASELINE
var _start_y: float
var _seed_rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seed_rng.randomize()
	_create_overlay()
	_spawn_game()


func _spawn_game() -> void:
	# Seed before the game scene enters the tree for repeatable platform patterns.
	seed(initial_seed)
	_game = MAIN_GAME_SCENE.instantiate() as Node2D
	if _game == null:
		push_error("Architecture Panel Clusters: Could not instantiate scenes/main.tscn.")
		return
	_game.name = "TowerJumpMain"
	add_child(_game)

	_camera = _game.get_node_or_null("GameCamera") as Camera2D
	_ball = _game.get_node_or_null("Ball") as CharacterBody2D
	_base_background = _game.get_node_or_null("GameCamera/Background") as ColorRect
	if _camera == null or _ball == null or _base_background == null:
		push_error("Architecture Panel Clusters: Main scene is missing GameCamera, Ball, or Background.")
		return

	_base_background.color = BACKGROUND_NAVY
	_start_y = _ball.global_position.y
	_create_architecture()
	_apply_variant()
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
			_set_variant(TestVariant.A1_BASELINE)
		KEY_B:
			_set_variant(TestVariant.A1_EXISTING_COMBINED)
		KEY_C:
			_set_variant(TestVariant.A1_PANEL_CLUSTERS)
		KEY_D:
			_set_variant(TestVariant.A1_COMPACT_STATIC)
		KEY_E:
			_set_variant(TestVariant.A1_COMPACT_FLICKER)
		KEY_F:
			_set_variant(TestVariant.A2_BASELINE)
		KEY_G:
			_set_variant(TestVariant.A2_EXISTING_COMBINED)
		KEY_H:
			_set_variant(TestVariant.A2_PANEL_CLUSTERS)
		KEY_I:
			_set_variant(TestVariant.A2_COMPACT_STATIC)
		KEY_J:
			_set_variant(TestVariant.A2_COMPACT_FLICKER)
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


func _create_architecture() -> void:
	_background = Node2D.new()
	_background.name = "PanelClusterArchitecture"
	_background.set_script(BACKGROUND_SCRIPT)
	_background.set("environment_seed", initial_seed)
	_background.set("palette_variant", PALETTE_A1_DEPTH)
	_background.set("life_treatment", LIFE_BASELINE)
	_background.set("world_width", WORLD_WIDTH)
	_background.set("section_top_y", STRUCTURE_TOP_Y)
	_background.set("section_bottom_y", STRUCTURE_BOTTOM_Y)
	_background.set("camera_path", NodePath("../GameCamera"))
	_background.z_index = -50
	_game.add_child(_background)
	_background.call("set_background_fill_override", BACKGROUND_NAVY)
	_background.call("set_environment_seed", initial_seed)


func _create_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ArchitecturePanelClusterOverlay"
	canvas.layer = 10
	add_child(canvas)

	_add_label(canvas, Vector2(22.0, 110.0),
		"COMPACT PANEL PASS  /  TALL RECESSES + RESTRAINED LIGHT SOURCES",
		14, Color(0.43, 0.75, 0.85, 0.95))
	_add_label(canvas, Vector2(22.0, 133.0),
		"A: A1 BASE   B: WINDOW REF   C: PREV CLUSTERS   D: COMPACT STATIC   E: FLICKER",
		9, Color(0.36, 0.54, 0.64, 0.95))
	_add_label(canvas, Vector2(22.0, 149.0),
		"F: A2 BASE   G: WINDOW REF   H: PREV CLUSTERS   I: COMPACT STATIC   J: FLICKER",
		9, Color(0.36, 0.54, 0.64, 0.95))

	_seed_label = Label.new()
	_seed_label.position = Vector2(22.0, 171.0)
	_set_label_theme(_seed_label, 13, Color(0.36, 0.66, 0.76, 0.95))
	canvas.add_child(_seed_label)

	_variant_label = Label.new()
	_variant_label.position = Vector2(22.0, 193.0)
	_set_label_theme(_variant_label, 12, Color(0.52, 0.70, 0.83, 0.96))
	canvas.add_child(_variant_label)

	_height_label = Label.new()
	_height_label.position = Vector2(22.0, 215.0)
	_set_label_theme(_height_label, 13, Color(0.45, 0.43, 0.74, 0.95))
	canvas.add_child(_height_label)

	_add_label(canvas, Vector2(22.0, 237.0),
		"1 / 2 / 3: FIXED SEED   R: RANDOM   SPACE / ENTER: RESTART",
		10, Color(0.36, 0.54, 0.64, 0.90))
	_add_label(canvas, Vector2(22.0, 253.0),
		"DORMANT / ACTIVE / ENERGIZED   |   STATIONARY SOURCES WITH CONTROLLED FLICKER",
		9, Color(0.36, 0.54, 0.64, 0.90))
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


func _set_variant(value: TestVariant) -> void:
	_variant = value
	_apply_variant()


func _apply_variant() -> void:
	if _background == null:
		return

	var palette: int = PALETTE_A1_DEPTH
	var life: int = LIFE_BASELINE
	match _variant:
		TestVariant.A1_BASELINE:
			palette = PALETTE_A1_DEPTH
			life = LIFE_BASELINE
		TestVariant.A1_EXISTING_COMBINED:
			palette = PALETTE_A1_DEPTH
			life = LIFE_STRUCTURED_COMBINED
		TestVariant.A1_PANEL_CLUSTERS:
			palette = PALETTE_A1_DEPTH
			life = LIFE_PANEL_CLUSTERS
		TestVariant.A1_COMPACT_STATIC:
			palette = PALETTE_A1_DEPTH
			life = LIFE_COMPACT_PANEL_STATES
		TestVariant.A1_COMPACT_FLICKER:
			palette = PALETTE_A1_DEPTH
			life = LIFE_COMPACT_PANEL_FLICKER
		TestVariant.A2_BASELINE:
			palette = PALETTE_A2_INTEGRATED
			life = LIFE_BASELINE
		TestVariant.A2_EXISTING_COMBINED:
			palette = PALETTE_A2_INTEGRATED
			life = LIFE_STRUCTURED_COMBINED
		TestVariant.A2_PANEL_CLUSTERS:
			palette = PALETTE_A2_INTEGRATED
			life = LIFE_PANEL_CLUSTERS
		TestVariant.A2_COMPACT_STATIC:
			palette = PALETTE_A2_INTEGRATED
			life = LIFE_COMPACT_PANEL_STATES
		TestVariant.A2_COMPACT_FLICKER:
			palette = PALETTE_A2_INTEGRATED
			life = LIFE_COMPACT_PANEL_FLICKER

	_background.call("set_palette_variant", palette)
	_background.call("set_life_treatment", life)
	_update_variant_label()


func _set_seed(value: int) -> void:
	initial_seed = value
	if _background != null:
		_background.call("set_environment_seed", value)
	_update_seed_label(value)


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
	match _variant:
		TestVariant.A1_BASELINE:
			_variant_label.text = "A1 DEPTH  /  BASELINE FAR SILHOUETTES"
		TestVariant.A1_EXISTING_COMBINED:
			_variant_label.text = "A1 DEPTH  /  EXISTING STRUCTURAL BAYS + WINDOWS"
		TestVariant.A1_PANEL_CLUSTERS:
			_variant_label.text = "A1 DEPTH  /  PREVIOUS LARGER PANEL CLUSTERS"
		TestVariant.A1_COMPACT_STATIC:
			_variant_label.text = "A1 DEPTH  /  TALL BAYS + COMPACT PANEL STATES"
		TestVariant.A1_COMPACT_FLICKER:
			_variant_label.text = "A1 DEPTH  /  COMPACT PANEL STATES + FLICKER"
		TestVariant.A2_BASELINE:
			_variant_label.text = "A2 INTEGRATED  /  BASELINE FAR SILHOUETTES"
		TestVariant.A2_EXISTING_COMBINED:
			_variant_label.text = "A2 INTEGRATED  /  EXISTING STRUCTURAL BAYS + WINDOWS"
		TestVariant.A2_PANEL_CLUSTERS:
			_variant_label.text = "A2 INTEGRATED  /  PREVIOUS LARGER PANEL CLUSTERS"
		TestVariant.A2_COMPACT_STATIC:
			_variant_label.text = "A2 INTEGRATED  /  TALL BAYS + COMPACT PANEL STATES"
		TestVariant.A2_COMPACT_FLICKER:
			_variant_label.text = "A2 INTEGRATED  /  COMPACT PANEL STATES + FLICKER"


func _update_seed_label(value: int) -> void:
	if _seed_label != null:
		_seed_label.text = "ENVIRONMENT SEED  %d  (RESTART TO RESET ENTIRE RUN)" % value
