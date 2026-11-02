extends Node2D
## Runs the actual gameplay scene at an authored height without changing production gameplay files.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/gameplay/main.tscn")
const COMPOSITOR_SCRIPT: Script = preload("res://scripts/environment/environment_preview_compositor.gd")
const START_BALL_Y: float = 600.0

@export var zone_profile: EnvironmentZoneProfile = preload("res://resources/environment/zones/preview_diagnostic_zone.tres")
@export var theme_profiles: Array[EnvironmentThemeProfile] = [
	preload("res://resources/environment/themes/navy_resonance.tres"),
	preload("res://resources/environment/themes/amber_diagnostic.tres"),
]
@export var fixed_seeds: Array[int] = [7319, 24017, 91207]
@export var jump_heights: Array[float] = [1800.0, 5400.0, 9600.0]
@export var jump_in_height_px: float = 3600.0
@export var world_seed: int = 7319

var _game_root: Node2D
var _ball: CharacterBody2D
var _camera: Camera2D
var _compositor: EnvironmentPreviewCompositor
var _hud_label: Label
var _theme_index: int = 0
var _seed_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if zone_profile == null or theme_profiles.is_empty() or fixed_seeds.is_empty() or jump_heights.is_empty():
		push_error("Full-Game Jump-In: assign a zone, theme, fixed seeds, and jump-height presets.")
		return
	if fixed_seeds.size() != jump_heights.size():
		push_error("Full-Game Jump-In: fixed seed and jump-height preset arrays must have the same size.")
		return
	for profile in theme_profiles:
		if profile == null:
			push_error("Full-Game Jump-In: theme_profiles must not contain null entries.")
			return
	_create_hud()
	_spawn_game()


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1, KEY_2, KEY_3:
			var index := key_event.keycode - KEY_1
			if index < jump_heights.size():
				_seed_index = index
				_restart_game(jump_heights[index], fixed_seeds[index])
		KEY_R:
			_restart_game(_get_current_height(), world_seed)
		KEY_N:
			var resume_height := _get_current_height()
			world_seed = posmod(world_seed + 7919, 2147483646) + 1
			_restart_game(resume_height, world_seed)
		KEY_T:
			_theme_index = posmod(_theme_index + 1, theme_profiles.size())
			if _compositor != null:
				_compositor.set_theme_override(theme_profiles[_theme_index])
			_update_hud()


func _spawn_game() -> void:
	get_tree().paused = false
	seed(world_seed)
	_game_root = MAIN_GAME_SCENE.instantiate() as Node2D
	if _game_root == null:
		push_error("Full-Game Jump-In: scenes/gameplay/main.tscn did not instantiate as Node2D.")
		return
	_game_root.name = "TowerJumpMain"
	add_child(_game_root)

	# The main scene's _ready() records its normal 600 px ball origin first.
	# Moving the instantiated root afterwards preserves the absolute climb height.
	_game_root.position.y = -jump_in_height_px
	_ball = _game_root.get_node_or_null("Ball") as CharacterBody2D
	_camera = _game_root.get_node_or_null("GameCamera") as Camera2D
	if _ball == null or _camera == null:
		push_error("Full-Game Jump-In: production scene is missing Ball or GameCamera.")
		return

	_compositor = COMPOSITOR_SCRIPT.new() as EnvironmentPreviewCompositor
	_compositor.name = "EnvironmentPreviewCompositor"
	_compositor.zone_profile = zone_profile
	_compositor.world_seed = world_seed
	_compositor.theme_override = theme_profiles[_theme_index]
	_compositor.world_origin_height_px = jump_in_height_px
	_compositor.camera_path = NodePath("../GameCamera")
	_compositor.replace_game_ambient_emitters = true
	_compositor.z_index = -50
	_game_root.add_child(_compositor)
	_update_hud()


func _restart_game(height_px: float, seed_value: int) -> void:
	jump_in_height_px = maxf(height_px, 0.0)
	world_seed = seed_value
	if is_instance_valid(_game_root):
		_game_root.queue_free()
	_game_root = null
	_ball = null
	_camera = null
	_compositor = null
	call_deferred("_spawn_game")


func _get_current_height() -> float:
	if is_instance_valid(_ball):
		return maxf(START_BALL_Y - _ball.global_position.y, 0.0)
	return jump_in_height_px


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "FullGameJumpInHUD"
	canvas.layer = 10
	add_child(canvas)
	_hud_label = Label.new()
	_hud_label.position = Vector2(18.0, 118.0)
	_hud_label.size = Vector2(684.0, 180.0)
	_hud_label.add_theme_font_size_override("font_size", 15)
	_hud_label.add_theme_color_override("font_color", Color(0.77, 0.88, 0.95, 0.96))
	_hud_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_hud_label.add_theme_constant_override("outline_size", 3)
	_hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(_hud_label)


func _update_hud() -> void:
	if _hud_label == null:
		return
	var current_height := jump_in_height_px
	if is_instance_valid(_ball):
		current_height = START_BALL_Y - _ball.global_position.y
	var subzone := "VOID"
	var module_count := 0
	if is_instance_valid(_compositor):
		subzone = _compositor.get_subzone_id_at_height(current_height)
		module_count = int(_compositor.get_plan_summary().get("placement_count", 0))
	_hud_label.text = (
		"FULL-GAME ENVIRONMENT JUMP-IN   |   %s\n" % String(zone_profile.zone_id).to_upper()
		+ "HEIGHT: %dm   |   SUBZONE: %s   |   MODULES IN PLAN: %d\n" % [
			roundi(current_height),
			subzone,
			module_count,
		]
		+ "SEED: %d   |   THEME: %s\n" % [world_seed, String(theme_profiles[_theme_index].profile_id)]
		+ "TOUCH LEFT/RIGHT OR UI LEFT/RIGHT   1–3 JUMP-IN PRESETS   R RESTART   N NEXT SEED   T THEME"
	)
