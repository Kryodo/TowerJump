extends CharacterBody2D
## Ball-Movement-Prototyp für TowerJump.
## - Fällt durch Gravitation
## - Springt automatisch beim Aufkommen auf einer Plattform (kein Jump-Button)
## - Horizontale Steuerung über Touch-Zonen (linke/rechte Bildschirmhälfte)
## - Screen-Wrap an den seitlichen Bildschirmrändern

@export var radius: float = 30.0            ## Radius für Kreis-Placeholder UND Kollisionsform (einzige Quelle)
@export var gravity: float = 1800.0         ## Fallbeschleunigung (px/s^2)
@export var jump_velocity: float = -1200.0  ## Vertikale Sprunggeschwindigkeit (negativ = nach oben)
@export_category("Horizontal Movement")
@export var max_horizontal_speed: float = 600.0
@export var horizontal_acceleration: float = 2200.0
@export var horizontal_deceleration: float = 1700.0

@export_category("State Activation Jump Boost")
@export_range(1.0, 1.20, 0.01) var combo_activation_jump_multiplier: float = 1.04
@export_range(1.0, 1.20, 0.01) var streak_activation_jump_multiplier: float = 1.06
@export_range(0.0, 60.0, 1.0) var combo_activation_jump_boost_cooldown_seconds: float = 15.0
@export var landing_score_controller_path: NodePath = NodePath("../LandingScoreController")

## Aktuelle Steuerrichtung, binär: -1 = voll links, 0 = keine, 1 = voll rechts
var input_direction: float = 0.0

## Downward speed captured immediately before move_and_slide resolves contact.
var landing_impact_velocity_y: float = 0.0

## Aktive Touches während des Haltens: Touch-Index -> Seite (-1 links, 1 rechts).
## Wird in _input() über ScreenTouch/ScreenDrag gepflegt, damit Mehrfach-Touch
## (z.B. beide Bildschirmhälften gleichzeitig) korrekt erkannt wird.
var _touch_sides: Dictionary = {}

var _combo_was_active: bool = false
var _streak_was_active: bool = false
var _pending_activation_jump_multiplier: float = 1.0
var _pending_activation_boost_kind: int = 0
var _combo_jump_boost_cooldown_remaining: float = 0.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

## Pflegt _touch_sides anhand von Touch-Press/-Release und -Drag-Events, damit
## auch ein über die Bildschirmmitte gezogener Finger die Seite aktualisiert.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_sides[event.index] = _touch_side(event.position.x)
		else:
			_touch_sides.erase(event.index)
	elif event is InputEventScreenDrag:
		if _touch_sides.has(event.index):
			_touch_sides[event.index] = _touch_side(event.position.x)

## Ordnet eine x-Koordinate der linken (-1) oder rechten (1) Bildschirmhälfte zu.
func _touch_side(x: float) -> int:
	return -1 if x < get_viewport_rect().size.x * 0.5 else 1

func _ready() -> void:
	# Kollisionsform zur Laufzeit aus `radius` generieren, damit es nur eine
	# Quelle für den Ball-Radius gibt (statt zusätzlich in der .tscn zu duplizieren).
	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision_shape.shape = shape
	add_to_group("player_ball") # Ermöglicht Coin.gd die Erkennung des Balls per Duck-Typing-Gruppe

	var score_controller: Node = get_node_or_null(landing_score_controller_path)
	if score_controller != null and score_controller.has_signal("combo_state_changed"):
		var state_callback := Callable(self, "_on_combo_state_changed")
		if not score_controller.is_connected("combo_state_changed", state_callback):
			score_controller.connect("combo_state_changed", state_callback)
		if score_controller.has_method("get_combo_state"):
			var initial_state: Dictionary = score_controller.call("get_combo_state")
			_on_combo_state_changed(initial_state)


func _on_combo_state_changed(state: Dictionary) -> void:
	var combo_active: bool = bool(state.get("combo_active", false))
	var streak_active: bool = bool(state.get("streak_active", false))

	# State activation happens synchronously inside the platform's landing
	# callback, just before this frame assigns the bounce velocity. Queue one
	# boost for that bounce only; Streak replaces Combo rather than stacking.
	if streak_active and not _streak_was_active:
		# Streak is its own milestone reward and ignores the Combo boost cooldown.
		_pending_activation_jump_multiplier = streak_activation_jump_multiplier
		_pending_activation_boost_kind = 2
	elif combo_active and not _combo_was_active:
		# This cooldown is deliberately scoped to the placeholder Combo boost;
		# Combo state, scoring and the future FLOW system continue normally.
		if _combo_jump_boost_cooldown_remaining <= 0.0:
			_pending_activation_jump_multiplier = combo_activation_jump_multiplier
			_pending_activation_boost_kind = 1
			_combo_jump_boost_cooldown_remaining = maxf(
				combo_activation_jump_boost_cooldown_seconds,
				0.0
			)

	_combo_was_active = combo_active
	_streak_was_active = streak_active


func _consume_activation_jump_boost() -> float:
	var multiplier: float = _pending_activation_jump_multiplier
	var boost_kind: int = _pending_activation_boost_kind
	_pending_activation_jump_multiplier = 1.0
	_pending_activation_boost_kind = 0

	if boost_kind > 0:
		var trail_visual: Node = get_node_or_null("TrailVisual")
		if trail_visual != null and trail_visual.has_method("play_activation_jump_boost"):
			trail_visual.call("play_activation_jump_boost", boost_kind == 2)

	return multiplier


func _physics_process(delta: float) -> void:
	_combo_jump_boost_cooldown_remaining = maxf(
		_combo_jump_boost_cooldown_remaining - delta,
		0.0
	)
	input_direction = _read_input_direction()

	# --- Gravitation ---
	velocity.y += gravity * delta

	# --- Horizontal movement with momentum ---
	var input_direction := Input.get_axis("ui_left", "ui_right")

	if abs(input_direction) > 0.01:
		var target_speed := input_direction * max_horizontal_speed

		# Accelerate toward the desired direction.
		velocity.x = move_toward(
			velocity.x,
			target_speed,
			horizontal_acceleration * delta
		)
	else:
		# No input: gradually lose horizontal momentum.
		velocity.x = move_toward(
			velocity.x,
			0.0,
			horizontal_deceleration * delta
		)

	landing_impact_velocity_y = velocity.y
	move_and_slide()

	# --- Auto-Bounce: beim Aufkommen automatisch abspringen ---
	if is_on_floor():
		velocity.y = jump_velocity * _landed_jump_multiplier()

	_screen_wrap()

## Ermittelt beim Aufkommen die Plattform unter dem Ball und liefert deren
## Sprunggeschwindigkeits-Multiplikator (>1 nur bei Spring-Plattformen, siehe
## platform.gd). Duck-Typing über has_method(), damit ball.gd nichts über
## Plattform-Varianten wissen muss - Seiteneffekte wie das Wegbrechen einer
## brüchigen Plattform passieren dabei innerhalb von Platform.on_ball_landed().
func _landed_jump_multiplier() -> float:
	var platform_multiplier: float = 1.0
	for i in get_slide_collision_count():
		var collider: Object = get_slide_collision(i).get_collider()

		if collider is Node and collider.has_method("on_ball_landed"):
			platform_multiplier = float(collider.call("on_ball_landed", global_position.x))
			break

	# Apply the milestone boost after platform-specific force (for example,
	# spring platforms), then consume it so no later jump inherits the bonus.
	return platform_multiplier * _consume_activation_jump_boost()

## Lässt den Ball auf der Gegenseite wieder auftauchen, wenn er den Bildschirm seitlich verlässt.
func _screen_wrap() -> void:
	var screen_width: float = get_viewport_rect().size.x
	if global_position.x < -radius:
		global_position.x = screen_width + radius
	elif global_position.x > screen_width + radius:
		global_position.x = -radius

## Liefert die Steuerrichtung (-1, 0 oder 1). Am PC gibt es keinen Touchscreen,
## daher wird dort ersatzweise über die Pfeiltasten (ui_left/ui_right) gesteuert.
func _read_input_direction() -> float:
	if should_use_touch_controls():
		return _read_touch_direction()
	return _read_keyboard_direction()

## Wertet _touch_sides aus: Touches auf nur einer Seite ergeben volle Auslenkung
## dorthin. Sind beide Seiten gleichzeitig berührt, heben sie sich zu 0 auf -
## dieselbe Kollisionsregel wie bei gleichzeitig gedrückten Pfeiltasten unten.
func _read_touch_direction() -> float:
	var has_left := false
	var has_right := false
	for side in _touch_sides.values():
		if side < 0:
			has_left = true
		else:
			has_right = true
	if has_left == has_right:
		return 0.0
	return -1.0 if has_left else 1.0

## Liefert bei gedrückter Pfeiltaste sofort volle Auslenkung. Bei gleichzeitig
## gedrückten ui_left/ui_right heben sich beide Richtungen zu 0 auf.
func _read_keyboard_direction() -> float:
	var dir: float = 0.0
	if Input.is_action_pressed("ui_left"):
		dir -= 1.0
	if Input.is_action_pressed("ui_right"):
		dir += 1.0
	return dir

## Entscheidet, ob die Touch-Zonen genutzt werden sollen (echtes mobiles Gerät)
## oder die Tastatur-Ersatzsteuerung (Editor/Desktop).
## OS.has_feature("editor") ist bei einem per F5 aus dem Editor gestarteten
## Spiel ebenfalls wahr, daher zusätzlich über OS.has_feature("mobile")
## gegenprüfen, damit ein Export mit fälschlich aktivem "editor"-Feature
## trotzdem korrekt die Touch-Steuerung nutzt.
static func should_use_touch_controls() -> bool:
	if OS.has_feature("editor"):
		return false
	return OS.has_feature("mobile")
