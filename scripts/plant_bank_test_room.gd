extends Node2D
## Focused test room for comparing the current bounce with Plant / Bank.
## Launch with F6 (Run Current Scene); controls are also available in the HUD.

const Platform := preload("res://scripts/platform.gd")

@export var platform_scene: PackedScene
@export var ball_path: NodePath = NodePath("Ball")
@export var camera_path: NodePath = NodePath("GameCamera")
@export var camera_follow_speed: float = 6.0
@export var spawn_ahead_distance: float = 1450.0
@export var reset_fall_distance: float = 900.0

const BASE_WIDTH: float = 220.0
const PLATFORM_HEIGHT: float = 20.0
const START_POSITION := Vector2(360.0, 600.0)
const START_PLATFORM_Y_OFFSET: float = 160.0
const START_PLATFORM_WIDTH: float = 300.0

## The same repeatable sequence is used for every mode. Alternating long crosses,
## reversals, and wide reset platforms makes momentum preservation vs braking legible.
const PATTERN: Array[Dictionary] = [
    {"x": 180.0, "rise": 205.0, "width": 190.0, "tag": "01  /  APPROACH + BRAKE"},
    {"x": 590.0, "rise": 230.0, "width": 160.0, "tag": "02  /  LONG RIGHT CROSS"},
    {"x": 150.0, "rise": 230.0, "width": 170.0, "tag": "03  /  HARD REVERSAL"},
    {"x": 360.0, "rise": 205.0, "width": 290.0, "tag": "04  /  STABILITY RESET"},
    {"x": 555.0, "rise": 220.0, "width": 170.0, "tag": "05  /  CARRY RIGHT"},
    {"x": 140.0, "rise": 235.0, "width": 165.0, "tag": "06  /  LONG LEFT CROSS"},
    {"x": 360.0, "rise": 205.0, "width": 290.0, "tag": "07  /  STABILITY RESET"},
]

const MODE_NORMAL: int = 0
const MODE_PLANT: int = 1
const MODE_BANK: int = 2
const MODE_AUTO: int = 3

@onready var _ball: CharacterBody2D = get_node(ball_path)
@onready var _camera: Camera2D = get_node(camera_path)
@onready var _mode_label: Label = $HUD/Panel/Content/ModeLabel
@onready var _description_label: Label = $HUD/Panel/Content/DescriptionLabel
@onready var _live_velocity_label: Label = $HUD/Panel/Content/LiveVelocityLabel
@onready var _last_landing_label: Label = $HUD/Panel/Content/LastLandingLabel
@onready var _normal_button: Button = $HUD/Panel/Content/ModeButtons/NormalButton
@onready var _plant_button: Button = $HUD/Panel/Content/ModeButtons/PlantButton
@onready var _bank_button: Button = $HUD/Panel/Content/ModeButtons/BankButton
@onready var _auto_button: Button = $HUD/Panel/Content/ModeButtons/AutoButton
@onready var _reset_button: Button = $HUD/Panel/Content/ResetButton

var _spawned_nodes: Array[Node] = []
var _start_platform_y: float = 0.0
var _last_spawn_y: float = 0.0
var _pattern_index: int = 0


func _ready() -> void:
    _ball.set_rebound_mode(MODE_NORMAL)
    _ball.rebound_applied.connect(_on_rebound_applied)

    _normal_button.pressed.connect(func() -> void: _set_mode(MODE_NORMAL))
    _plant_button.pressed.connect(func() -> void: _set_mode(MODE_PLANT))
    _bank_button.pressed.connect(func() -> void: _set_mode(MODE_BANK))
    _auto_button.pressed.connect(func() -> void: _set_mode(MODE_AUTO))
    _reset_button.pressed.connect(_reset_run)

    _reset_run()
    _update_mode_ui()


func _process(delta: float) -> void:
    # Preserve the game's "camera follows upward only" behavior.
    if _ball.global_position.y < _camera.global_position.y:
        _camera.global_position.y = lerpf(
            _camera.global_position.y,
            _ball.global_position.y,
            clampf(camera_follow_speed * delta, 0.0, 1.0)
        )

    _ensure_platforms_ahead()
    _live_velocity_label.text = (
        "Live velocity   X %+.0f px/s     Y %+.0f px/s"
        % [_ball.velocity.x, _ball.velocity.y]
    )

    if _ball.global_position.y > _start_platform_y + reset_fall_distance:
        _reset_run()


func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return

    match event.keycode:
        KEY_1:
            _set_mode(MODE_NORMAL)
        KEY_2:
            _set_mode(MODE_PLANT)
        KEY_3:
            _set_mode(MODE_BANK)
        KEY_4:
            _set_mode(MODE_AUTO)
        KEY_R:
            _reset_run()


func _set_mode(mode: int) -> void:
    _ball.set_rebound_mode(mode)
    _update_mode_ui()


func _update_mode_ui() -> void:
    var mode_name: String = _ball.get_rebound_mode_name()
    _mode_label.text = "ACTIVE MODE: " + mode_name
    _normal_button.modulate = Color(0.40, 0.92, 1.0, 1.0) if _ball.rebound_mode == MODE_NORMAL else Color.WHITE
    _plant_button.modulate = Color(0.40, 0.92, 1.0, 1.0) if _ball.rebound_mode == MODE_PLANT else Color.WHITE
    _bank_button.modulate = Color(0.78, 0.58, 1.0, 1.0) if _ball.rebound_mode == MODE_BANK else Color.WHITE
    _auto_button.modulate = Color(1.0, 0.78, 0.40, 1.0) if _ball.rebound_mode == MODE_AUTO else Color.WHITE

    match _ball.rebound_mode:
        MODE_PLANT:
            _description_label.text = "PLANT  •  Landing damps lateral velocity to 10%. Use it to stop drift before a reversal or narrow route."
        MODE_BANK:
            _description_label.text = "BANK  •  Landing side redirects lateral movement; horizontal carry is retained, steering briefly strengthens, vertical rebound is 10% lower."
        MODE_AUTO:
            _description_label.text = "AUTO  •  Centered landing + low lateral speed = PLANT. Fast or off-center landing = BANK. Try counter-steering before contact."
        _:
            _description_label.text = "NORMAL  •  Existing bounce behavior. Use this as the baseline, then replay the same sequence in Plant and Bank."


func _on_rebound_applied(
    effective_mode: int,
    incoming_vx: float,
    outgoing_vx: float,
    landing_offset_ratio: float,
    vertical_scale: float
) -> void:
    var actual_name: String = _ball.get_rebound_mode_name(effective_mode)
    var selected_name: String = _ball.get_rebound_mode_name()
    var auto_prefix: String = "AUTO → " if selected_name == "AUTO" else ""
    _last_landing_label.text = (
        "LAST LANDING  %s%s    offset %+0.2f    vx %+.0f → %+.0f    vertical ×%.2f"
        % [auto_prefix, actual_name, landing_offset_ratio, incoming_vx, outgoing_vx, vertical_scale]
    )


func _reset_run() -> void:
    for node in _spawned_nodes:
        if is_instance_valid(node):
            remove_child(node)
            node.queue_free()
    _spawned_nodes.clear()

    _ball.global_position = START_POSITION
    _ball.velocity = Vector2.ZERO
    _camera.global_position = Vector2(360.0, 640.0)
    _start_platform_y = START_POSITION.y + START_PLATFORM_Y_OFFSET
    _last_spawn_y = _start_platform_y
    _pattern_index = 0

    _spawn_platform(
        Vector2(360.0, _start_platform_y),
        START_PLATFORM_WIDTH,
        "START  /  CONTROL REFERENCE"
    )
    _ensure_platforms_ahead()
    _last_landing_label.text = "LAST LANDING  —  land once to record rebound telemetry."


func _ensure_platforms_ahead() -> void:
    while _last_spawn_y > _ball.global_position.y - spawn_ahead_distance:
        _spawn_next_pattern_platform()


func _spawn_next_pattern_platform() -> void:
    var spec: Dictionary = PATTERN[_pattern_index % PATTERN.size()]
    _last_spawn_y -= float(spec["rise"])
    _spawn_platform(
        Vector2(float(spec["x"]), _last_spawn_y),
        float(spec["width"]),
        str(spec["tag"])
    )
    _pattern_index += 1


func _spawn_platform(world_position: Vector2, width_px: float, tag_text: String) -> void:
    var platform := platform_scene.instantiate() as Node2D
    add_child(platform)
    platform.set("width", BASE_WIDTH)
    platform.set("height", PLATFORM_HEIGHT)
    platform.call(
        "spawn_as",
        Platform.PlatformType.NORMAL,
        world_position,
        width_px / BASE_WIDTH
    )
    _spawned_nodes.append(platform)

    var tag := Label.new()
    tag.text = tag_text
    tag.position = world_position + Vector2(-105.0, -46.0)
    tag.add_theme_font_size_override("font_size", 14)
    tag.add_theme_color_override("font_color", Color(0.32, 0.84, 0.98, 0.88))
    tag.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.06, 1.0))
    tag.add_theme_constant_override("shadow_offset_x", 1)
    tag.add_theme_constant_override("shadow_offset_y", 1)
    tag.z_index = 5
    add_child(tag)
    _spawned_nodes.append(tag)
