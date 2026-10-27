extends Node2D
## Standalone vertical playroom for validating procedural architectural scenery.
## Open scenes/environment_architecture_test_room.tscn and run the current scene.
## Existing production gameplay and scene setup are not modified.

const BALL_SCENE: PackedScene = preload("res://scenes/ball.tscn")
const PLATFORM_SCENE: PackedScene = preload("res://scenes/platform.tscn")
const PLATFORM_SPAWNER_SCRIPT: Script = preload("res://scripts/platform_spawner.gd")
const BACKGROUND_SCRIPT: Script = preload("res://scripts/procedural_architecture_background.gd")

@export var initial_seed: int = 7319
@export var camera_follow_speed: float = 6.0

var _ball: CharacterBody2D
var _camera: Camera2D
var _background: Node2D
var _seed_label: Label
var _height_label: Label
var _seed_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_seed_rng.randomize()
	# Reset run state before the spawner generates its initial platform pool.
	if is_instance_valid(GameManager):
		GameManager.reset()
	_setup_world_environment()
	_create_camera()
	_create_background()
	_create_ball()
	_create_platform_spawner()
	_create_overlay()


func _process(delta: float) -> void:
	if _ball == null or _camera == null:
		return

	# Matches the main game’s one-way camera behavior: the camera follows the
	# ball only when the ball reaches a new height, never on its descent.
	if _ball.global_position.y < _camera.global_position.y:
		_camera.global_position.y = lerp(
			_camera.global_position.y,
			_ball.global_position.y,
			clampf(camera_follow_speed * delta, 0.0, 1.0)
		)

	if _height_label != null:
		_height_label.text = "HEIGHT  %05d" % maxi(0, int(640.0 - _ball.global_position.y))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_R:
			_randomize_seed()
		KEY_1:
			_set_seed(7319)
		KEY_2:
			_set_seed(24017)
		KEY_3:
			_set_seed(91207)


func _setup_world_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ArchitectureEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.004, 0.009, 0.023, 1.0)
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.3
	environment.glow_hdr_threshold = 0.5
	environment.set("glow_levels/1", 0.8)
	environment.set("glow_levels/2", 0.7)
	environment.set("glow_levels/3", 1.0)
	environment.set("glow_levels/4", 0.2)
	world_environment.environment = environment
	add_child(world_environment)


func _create_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "GameCamera"
	_camera.position = Vector2(360.0, 640.0)
	_camera.zoom = Vector2.ONE
	add_child(_camera)


func _create_background() -> void:
	_background = Node2D.new()
	_background.name = "ProceduralArchitectureBackground"
	_background.set_script(BACKGROUND_SCRIPT)
	_background.set("environment_seed", initial_seed)
	_background.set("world_width", 720.0)
	_background.set("section_top_y", -10400.0)
	_background.set("section_bottom_y", 1600.0)
	_background.set("camera_path", NodePath("../GameCamera"))
	_background.z_index = -100
	add_child(_background)
	_background.call("set_environment_seed", initial_seed)


func _create_ball() -> void:
	_ball = BALL_SCENE.instantiate() as CharacterBody2D
	_ball.name = "Ball"
	_ball.position = Vector2(360.0, 600.0)
	add_child(_ball)


func _create_platform_spawner() -> void:
	# Reuse the existing platform and pattern systems so the experiment is judged
	# in the real TowerJump play context, rather than against an empty art viewer.
	var spawner := Node2D.new()
	spawner.name = "PlatformSpawner"
	spawner.set_script(PLATFORM_SPAWNER_SCRIPT)
	spawner.set("platform_scene", PLATFORM_SCENE)
	spawner.set("pool_size", 14)
	spawner.set("ball_path", NodePath("../Ball"))
	spawner.set("camera_path", NodePath("../GameCamera"))
	add_child(spawner)


func _create_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ArchitectureDebugOverlay"
	canvas.layer = 10
	add_child(canvas)

	var title := Label.new()
	title.position = Vector2(22.0, 18.0)
	title.text = "MONUMENTAL ARCHITECTURE  /  SILHOUETTE STUDY"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.62, 0.91, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	canvas.add_child(title)

	var instructions := Label.new()
	instructions.position = Vector2(22.0, 46.0)
	instructions.text = "ARROWS: STEER   •   R: NEW SEED   •   1 / 2 / 3: FIXED SEEDS"
	instructions.add_theme_font_size_override("font_size", 13)
	instructions.add_theme_color_override("font_color", Color(0.47, 0.67, 0.79, 0.92))
	instructions.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	instructions.add_theme_constant_override("outline_size", 3)
	canvas.add_child(instructions)

	_seed_label = Label.new()
	_seed_label.position = Vector2(22.0, 70.0)
	_seed_label.add_theme_font_size_override("font_size", 14)
	_seed_label.add_theme_color_override("font_color", Color(0.43, 0.78, 0.91, 0.94))
	_seed_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_seed_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_seed_label)

	_height_label = Label.new()
	_height_label.position = Vector2(22.0, 94.0)
	_height_label.add_theme_font_size_override("font_size", 14)
	_height_label.add_theme_color_override("font_color", Color(0.60, 0.54, 0.91, 0.92))
	_height_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_height_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_height_label)
	_update_seed_label(initial_seed)


func _randomize_seed() -> void:
	_set_seed(_seed_rng.randi_range(1, 2_000_000_000))


func _set_seed(value: int) -> void:
	if _background == null:
		return
	initial_seed = value
	_background.call("set_environment_seed", value)
	_update_seed_label(value)


func _update_seed_label(value: int) -> void:
	if _seed_label != null:
		_seed_label.text = "ENVIRONMENT SEED  %d" % value
