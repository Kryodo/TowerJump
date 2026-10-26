extends "res://scripts/ball.gd"
## Isolated Plant/Bank experiment. The production ball.gd remains untouched.
## Normal preserves the existing bounce. Plant damps lateral movement at contact.
## Bank redirects movement using the landing side and briefly raises steering authority.
## Auto picks Plant only when the approach is centered and already slow; otherwise Bank.

signal rebound_applied(
    effective_mode: int,
    incoming_horizontal_velocity: float,
    outgoing_horizontal_velocity: float,
    landing_offset_ratio: float,
    vertical_rebound_scale: float
)

enum ReboundMode {
    NORMAL,
    PLANT,
    BANK,
    AUTO,
}

@export_category("Plant Rebound")
@export_range(0.0, 0.5, 0.02) var plant_lateral_retention: float = 0.10
@export_range(0.0, 1.0, 0.05) var auto_plant_speed_fraction: float = 0.28
@export_range(0.0, 1.0, 0.05) var auto_plant_center_ratio: float = 0.45

@export_category("Bank Rebound")
@export_range(0.0, 1.5, 0.05) var bank_lateral_retention: float = 0.95
@export_range(0.0, 500.0, 10.0) var bank_edge_impulse: float = 260.0
@export_range(0.65, 1.0, 0.01) var bank_vertical_multiplier: float = 0.90
@export_range(0.0, 0.5, 0.02) var bank_speed_boost_duration: float = 0.20
@export_range(1.0, 1.4, 0.02) var bank_steering_cap_multiplier: float = 1.18
@export_range(1.0, 1.4, 0.02) var bank_output_speed_cap_multiplier: float = 1.20

## Selectable by the test-room HUD; this is deliberately experimental, not final UX.
@export_enum("Normal", "Plant", "Bank", "Auto") var rebound_mode: int = ReboundMode.NORMAL

var last_effective_mode: int = ReboundMode.NORMAL
var last_incoming_horizontal_velocity: float = 0.0
var last_outgoing_horizontal_velocity: float = 0.0
var last_landing_offset_ratio: float = 0.0
var last_vertical_rebound_scale: float = 1.0

var _base_horizontal_speed_cap: float = 600.0
var _bank_speed_boost_remaining: float = 0.0
var _ui_touch_indices: Dictionary = {}

const HUD_TOUCH_EXCLUSION_BOTTOM: float = 350.0


func _ready() -> void:
    super._ready()
    _base_horizontal_speed_cap = max_horizontal_speed


## Ignore touches that start on the experiment controls. Gameplay touches below
## the HUD still use the existing left/right halves. Release is consumed too,
## so a UI tap can never leave a stuck steering touch behind.
func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and event.position.y <= HUD_TOUCH_EXCLUSION_BOTTOM:
            _ui_touch_indices[event.index] = true
            return
        if _ui_touch_indices.has(event.index):
            if not event.pressed:
                _ui_touch_indices.erase(event.index)
            return
    elif event is InputEventScreenDrag and _ui_touch_indices.has(event.index):
        return
    super._input(event)


## The Bank window temporarily raises the steering cap. We still delegate all
## ordinary input, gravity, wrapping, collision, and auto-bounce behavior to the
## existing ball script; only this experiment's brief steering authority changes.
func _physics_process(delta: float) -> void:
    var original_cap: float = max_horizontal_speed
    if _bank_speed_boost_remaining > 0.0:
        max_horizontal_speed = _base_horizontal_speed_cap * bank_steering_cap_multiplier
    super._physics_process(delta)
    max_horizontal_speed = original_cap
    _bank_speed_boost_remaining = maxf(_bank_speed_boost_remaining - delta, 0.0)


func _landed_jump_multiplier() -> float:
    var incoming_vx: float = velocity.x
    var landing_offset_ratio: float = 0.0
    var platform_center_x: float = global_position.x
    var platform_half_width: float = 110.0

    # Read the contact platform before the base callback emits landing events.
    for i in get_slide_collision_count():
        var collider: Object = get_slide_collision(i).get_collider()
        if collider is Node2D and collider.has_method("on_ball_landed"):
            var platform_node: Node2D = collider as Node2D
            platform_center_x = platform_node.global_position.x
            if platform_node.has_method("half_width"):
                platform_half_width = maxf(float(platform_node.call("half_width")), 1.0)
            break

    landing_offset_ratio = clampf(
        (global_position.x - platform_center_x) / platform_half_width,
        -1.0,
        1.0
    )

    var effective_mode: int = rebound_mode
    if rebound_mode == ReboundMode.AUTO:
        var slow_enough: bool = absf(incoming_vx) <= (
            _base_horizontal_speed_cap * auto_plant_speed_fraction
        )
        var centered_enough: bool = absf(landing_offset_ratio) <= auto_plant_center_ratio
        effective_mode = ReboundMode.PLANT if slow_enough and centered_enough else ReboundMode.BANK

    var outgoing_vx: float = incoming_vx
    var vertical_scale: float = 1.0

    match effective_mode:
        ReboundMode.PLANT:
            # Plant trades carried lateral motion for a predictable starting state.
            outgoing_vx = incoming_vx * plant_lateral_retention
        ReboundMode.BANK:
            # Contact side steers the rebound; incoming movement is mostly retained.
            outgoing_vx = (
                incoming_vx * bank_lateral_retention
                + landing_offset_ratio * bank_edge_impulse
            )
            outgoing_vx = clampf(
                outgoing_vx,
                -_base_horizontal_speed_cap * bank_output_speed_cap_multiplier,
                _base_horizontal_speed_cap * bank_output_speed_cap_multiplier
            )
            vertical_scale = bank_vertical_multiplier

    # Preserve the existing platform callback and activation-boost behavior.
    # It also ensures a spring platform still contributes its own multiplier.
    var base_jump_multiplier: float = super._landed_jump_multiplier()

    velocity.x = outgoing_vx
    if effective_mode == ReboundMode.BANK:
        _bank_speed_boost_remaining = maxf(
            _bank_speed_boost_remaining,
            bank_speed_boost_duration
        )

    last_effective_mode = effective_mode
    last_incoming_horizontal_velocity = incoming_vx
    last_outgoing_horizontal_velocity = outgoing_vx
    last_landing_offset_ratio = landing_offset_ratio
    last_vertical_rebound_scale = vertical_scale

    rebound_applied.emit(
        effective_mode,
        incoming_vx,
        outgoing_vx,
        landing_offset_ratio,
        vertical_scale
    )
    return base_jump_multiplier * vertical_scale


func set_rebound_mode(mode: int) -> void:
    rebound_mode = clampi(mode, ReboundMode.NORMAL, ReboundMode.AUTO)


func get_rebound_mode_name(mode: int = -1) -> String:
    var requested_mode: int = rebound_mode if mode < 0 else mode
    match requested_mode:
        ReboundMode.PLANT:
            return "PLANT"
        ReboundMode.BANK:
            return "BANK"
        ReboundMode.AUTO:
            return "AUTO"
        _:
            return "NORMAL"
