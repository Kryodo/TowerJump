extends Node2D
## Compares subtle middle-architecture depth treatments with approved far apertures
## and architecture-matched ambient mote layers held constant.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const BACKGROUND_SCRIPT: Script = preload("res://scripts/procedural_architecture_background.gd")
const BACKGROUND_NAVY := Color(0.007843138, 0.023529412, 0.050980393, 1.0)
const WORLD_WIDTH: float = 720.0
const STRUCTURE_TOP_Y: float = -10400.0
const STRUCTURE_BOTTOM_Y: float = 1600.0
const PALETTE_A1_DEPTH: int = 4
const PALETTE_A2_INTEGRATED: int = 11
const LIFE_COMPACT_PANEL_FLICKER: int = 8
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
const MOTE_PARALLAX_SCALES: Array[float] = [0.18, 0.46, 0.82]
const REPEAT_HEIGHT: float = 1520.0

enum MiddleTreatment {
	BASELINE,
	STEPPED_INSETS,
	INSETS_AND_MECHANICAL_RECESSES,
}

@export var initial_seed: int = 7319

var _game: Node2D
var _camera: Camera2D
var _ball: CharacterBody2D
var _emitters: Array[GPUParticles2D] = []
var _parallax_layers: Array[Parallax2D] = []
var _architecture: Node2D
var _middle_treatment: MiddleTreatment = MiddleTreatment.BASELINE
var _debug_contrast_enabled: bool = false
var _palette_variant: int = PALETTE_A2_INTEGRATED
var _seed_label: Label
var _variant_label: Label
var _palette_label: Label
var _debug_label: Label
var _height_label: Label
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
		push_error("Middle Architecture Detail Test: Could not instantiate scenes/main.tscn.")
		return
	_game.name = "TowerJumpMain"
	add_child(_game)

	_camera = _game.get_node_or_null("GameCamera") as Camera2D
	_ball = _game.get_node_or_null("Ball") as CharacterBody2D
	if _camera == null or _ball == null:
		push_error("Middle Architecture Detail Test: Main scene is missing GameCamera or Ball.")
		return

	_emitters.clear()
	for path in MOTE_PATHS:
		var emitter := _game.get_node_or_null(path) as GPUParticles2D
		if emitter == null:
			push_error("Middle Architecture Detail Test: Missing mote emitter at %s." % path)
			return
		_emitters.append(emitter)

	_start_y = _ball.global_position.y
	_create_architecture()
	_apply_locked_mote_parallax()
	_set_middle_treatment(_middle_treatment)
	_set_palette(_palette_variant)
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
			_set_middle_treatment(MiddleTreatment.BASELINE)
		KEY_B:
			_set_middle_treatment(MiddleTreatment.STEPPED_INSETS)
		KEY_C:
			_set_middle_treatment(MiddleTreatment.INSETS_AND_MECHANICAL_RECESSES)
		KEY_D:
			_set_debug_contrast(not _debug_contrast_enabled)
		KEY_5:
			_set_palette(PALETTE_A1_DEPTH)
		KEY_6:
			_set_palette(PALETTE_A2_INTEGRATED)
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
	_architecture = Node2D.new()
	_architecture.name = "MiddleArchitectureDetailStudy"
	_architecture.set_script(BACKGROUND_SCRIPT)
	_architecture.set("environment_seed", initial_seed)
	_architecture.set("palette_variant", _palette_variant)
	_architecture.set("life_treatment", LIFE_COMPACT_PANEL_FLICKER)
	_architecture.set("world_width", WORLD_WIDTH)
	_architecture.set("section_top_y", STRUCTURE_TOP_Y)
	_architecture.set("section_bottom_y", STRUCTURE_BOTTOM_Y)
	_architecture.set("camera_path", NodePath("../GameCamera"))
	_architecture.z_index = -50
	_game.add_child(_architecture)
	_architecture.call("set_background_fill_override", BACKGROUND_NAVY)
	_architecture.call("set_environment_seed", initial_seed)


func _apply_locked_mote_parallax() -> void:
	# Keep the approved depth relationship fixed throughout this study:
	# far 0.18 / middle 0.46 / near 0.82.
	for i in range(_emitters.size()):
		var layer := Parallax2D.new()
		layer.name = MOTE_LAYER_NAMES[i]
		layer.scroll_scale = Vector2(1.0, MOTE_PARALLAX_SCALES[i])
		layer.repeat_size = Vector2(0.0, REPEAT_HEIGHT)
		layer.repeat_times = 2
		_game.add_child(layer)
		layer.global_position = _camera.global_position
		_parallax_layers.append(layer)

		var emitter: GPUParticles2D = _emitters[i]
		emitter.reparent(layer, true)
		emitter.local_coords = true
		emitter.restart()


func _set_middle_treatment(value: MiddleTreatment) -> void:
	_middle_treatment = value
	if _architecture != null:
		_architecture.call("set_mid_detail_treatment", int(_middle_treatment))
	_update_variant_label()


func _set_debug_contrast(value: bool) -> void:
	_debug_contrast_enabled = value
	if _architecture != null:
		_architecture.call("set_mid_detail_debug", _debug_contrast_enabled)
	if _debug_label != null:
		_debug_label.text = (
			"DETAIL DEBUG CONTRAST  /  ON"
			if _debug_contrast_enabled
			else "DETAIL DEBUG CONTRAST  /  OFF"
		)


func _set_palette(value: int) -> void:
	_palette_variant = value
	if _architecture != null:
		_architecture.call("set_palette_variant", _palette_variant)
	if _palette_label != null:
		_palette_label.text = (
			"ARCHITECTURE PALETTE  /  A1 DEPTH"
			if _palette_variant == PALETTE_A1_DEPTH
			else "ARCHITECTURE PALETTE  /  A2 INTEGRATED"
		)


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
	_architecture = null
	_emitters.clear()
	_parallax_layers.clear()
	_spawn_game()


func _create_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "MiddleArchitectureDetailOverlay"
	canvas.layer = 10
	add_child(canvas)

	_add_label(
		canvas,
		Vector2(22.0, 110.0),
		"MIDDLE ARCHITECTURE DETAIL STUDY",
		14,
		Color(0.43, 0.75, 0.85, 0.95)
	)
	_add_label(
		canvas,
		Vector2(22.0, 133.0),
		"A: CURRENT   B: STEPPED INSETS   C: INSETS + MECHANICAL RECESSES",
		9,
		Color(0.36, 0.54, 0.64, 0.95)
	)
	_add_label(
		canvas,
		Vector2(22.0, 149.0),
		"FAR APERTURE FLICKER + APPROVED MOTE DEPTH ARE FIXED",
		9,
		Color(0.36, 0.54, 0.64, 0.95)
	)

	_seed_label = Label.new()
	_seed_label.position = Vector2(22.0, 171.0)
	_set_label_theme(_seed_label, 13, Color(0.36, 0.66, 0.76, 0.95))
	canvas.add_child(_seed_label)

	_variant_label = Label.new()
	_variant_label.position = Vector2(22.0, 193.0)
	_set_label_theme(_variant_label, 12, Color(0.52, 0.70, 0.83, 0.96))
	canvas.add_child(_variant_label)

	_palette_label = Label.new()
	_palette_label.position = Vector2(22.0, 215.0)
	_set_label_theme(_palette_label, 12, Color(0.45, 0.62, 0.82, 0.96))
	canvas.add_child(_palette_label)

	_height_label = Label.new()
	_height_label.position = Vector2(22.0, 237.0)
	_set_label_theme(_height_label, 13, Color(0.45, 0.43, 0.74, 0.95))
	canvas.add_child(_height_label)

	_add_label(
		canvas,
		Vector2(22.0, 259.0),
		"5 / 6: A1 / A2 PALETTE   |   1 / 2 / 3: FIXED SEED   R: RANDOM",
		10,
		Color(0.36, 0.54, 0.64, 0.90)
	)
	_add_label(
		canvas,
		Vector2(22.0, 275.0),
		"D: DEBUG CONTRAST TOGGLE   |   SPACE / ENTER: RESTART",
		9,
		Color(0.36, 0.54, 0.64, 0.90)
	)

	_debug_label = Label.new()
	_debug_label.position = Vector2(270.0, 237.0)
	_set_label_theme(_debug_label, 11, Color(0.78, 0.84, 0.95, 0.98))
	canvas.add_child(_debug_label)

	_update_seed_label(initial_seed)
	_set_palette(_palette_variant)
	_set_debug_contrast(_debug_contrast_enabled)
	_update_variant_label()


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
	match _middle_treatment:
		MiddleTreatment.BASELINE:
			_variant_label.text = "A  /  ORIGINAL MIDDLE ARCHITECTURE"
		MiddleTreatment.STEPPED_INSETS:
			_variant_label.text = "B  /  STEPPED STRUCTURAL INSET PLATES"
		MiddleTreatment.INSETS_AND_MECHANICAL_RECESSES:
			_variant_label.text = "C  /  INSET PLATES + DARK MECHANICAL RECESSES"


func _update_seed_label(value: int) -> void:
	if _seed_label != null:
		_seed_label.text = "ENVIRONMENT SEED  %d  (RESTART TO RESET)" % value
