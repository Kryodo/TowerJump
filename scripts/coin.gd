extends Area2D
## Wiederverwendbare Münze (Area2D) mit Kreis-Platzhalter-Visual, analog zu Ball/
## Plattform per _draw() gezeichnet (kein Sprite-Asset nötig).
##
## Pooling: der CoinSpawner erzeugt Instanzen genau EINMAL. spawn_as() platziert
## einen Coin (aus dem Pool) an einer neuen Stelle und macht ihn einsammelbar,
## deactivate() parkt ihn unsichtbar/ohne Kollision für die spätere Wiederverwendung.
##
## Berührt der Ball die Münze, spielt _collect() einen kurzen Scale-Pop + Fade,
## ruft GameManager.add_coins(1) auf und blendet die Münze aus. Sie bleibt danach
## an Ort und Stelle liegen (unsichtbar), bis der CoinSpawner sie regulär als
## außerhalb des Kamera-Sichtbereichs erkennt und für die Wiederverwendung freigibt -
## analog zum Recycling-Verhalten brüchiger Plattformen (siehe platform.gd).

@export var radius: float = 14.0
@export var coin_color: Color = Color(1.0, 0.84, 0.15, 1.0)
@export var coin_outline_color: Color = Color(0.75, 0.55, 0.05, 1.0)
@export var coin_shine_color: Color = Color(1.0, 0.95, 0.6, 1.0)

@export_group("Einsammel-Effekt")
@export var collect_pop_scale: float = 1.4
@export var collect_duration: float = 0.25

var _is_active: bool = false
var _is_collected: bool = false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision_shape.shape = shape
	body_entered.connect(_on_body_entered)
	deactivate()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, coin_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, coin_outline_color, 2.0, true)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.28, coin_shine_color)

func is_active() -> bool:
	return _is_active

## Einziger Einstiegspunkt, über den der CoinSpawner Coins platziert (Pool-Entnahme).
func spawn_as(new_position: Vector2) -> void:
	global_position = new_position
	_is_active = true
	_is_collected = false
	scale = Vector2.ONE
	modulate = Color.WHITE
	visible = true
	monitoring = true
	_collision_shape.disabled = false
	queue_redraw()

## Parkt den Coin unsichtbar/ohne Kollision - bereit für die Wiederverwendung
## durch den CoinSpawner (Pool-Rückgabe).
func deactivate() -> void:
	_is_active = false
	visible = false
	monitoring = false
	_collision_shape.disabled = true

func _on_body_entered(body: Node) -> void:
	if not _is_active or _is_collected or not body.is_in_group("player_ball"):
		return
	_collect()

## monitoring/disabled werden hier deferred gesetzt, da wir innerhalb der
## body_entered-Signalverarbeitung stecken - eine direkte Änderung während der
## laufenden Physik-Query-Auswertung wirft in Godot einen Fehler.
func _collect() -> void:
	_is_collected = true
	set_deferred("monitoring", false)
	_collision_shape.set_deferred("disabled", true)
	GameManager.add_coins(1)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * collect_pop_scale, collect_duration * 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ZERO, collect_duration * 0.65)
	tween.parallel().tween_property(self, "modulate:a", 0.0, collect_duration * 0.65)
	tween.tween_callback(func() -> void: visible = false)
