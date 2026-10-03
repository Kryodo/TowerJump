extends Node2D
## Objekt-Pool für Coins, die in der Nähe neu generierter Plattformen platziert werden.
##
## Reagiert auf das "platform_placed"-Signal des PlatformSpawners (feuert sowohl
## beim initialen Befüllen als auch bei jedem Plattform-Recycling) und platziert
## mit Wahrscheinlichkeit spawn_chance einen Coin leicht über der Plattform, sodass
## der Ball ihn beim normalen Sprung zur Plattform automatisch einsammelt.
##
## Pooling analog zu PlatformSpawner: `pool_size` Coin-Instanzen werden genau EINMAL
## erzeugt und nie gelöscht/neu instanziiert. Ein Coin gilt als "frei" (wiederverwend-
## bar), sobald er unter den sichtbaren Kamerabereich gescrollt ist - unabhängig
## davon, ob er zuvor eingesammelt wurde oder ungenutzt blieb (siehe _process()).
##
## WICHTIG (Node-Reihenfolge): Dieser Node muss im Szenenbaum VOR dem PlatformSpawner
## als Kind von Main stehen. Godot ruft _ready() von Geschwister-Nodes in
## Baumreihenfolge auf; die Signalverbindung hier muss stehen, bevor
## PlatformSpawner._ready() zum ersten Mal platform_placed feuert (für den initial
## befüllten Plattform-Pool), sonst würden die allerersten Plattformen nie einen
## Coin bekommen können.

@export var coin_scene: PackedScene
@export var pool_size: int = 10
@export var platform_spawner_path: NodePath
@export var camera_path: NodePath

@export_group("Platzierung")
@export var spawn_chance: float = 0.35 ## Wahrscheinlichkeit pro Plattform, dass ein Coin erscheint
@export var hover_height: float = 70.0 ## Abstand des Coins über der Plattformmitte
@export var horizontal_jitter_factor: float = 0.4 ## Anteil der Plattform-Halbbreite für zufälligen x-Versatz

var _coins: Array[Node2D] = []
var _free_indices: Array[int] = []
var _camera: Camera2D
var _viewport_size: Vector2

func _ready() -> void:
	_viewport_size = get_viewport_rect().size
	_camera = get_node(camera_path) as Camera2D

	for i in pool_size:
		var c := coin_scene.instantiate() as Node2D
		add_child(c)
		_coins.append(c)
		_free_indices.append(i)

	# Verbindung über den String-basierten Object.connect(): platform_spawner_path
	# ist statisch nur als "Node" bekannt, das Custom-Signal "platform_placed"
	# existiert aber nur auf dessen konkretem Skript - die typisierte
	# ".platform_placed.connect()"-Schreibweise würde daher die statische
	# GDScript-Analyse (Node kennt dieses Signal nicht) zum Scheitern bringen.
	var spawner: Node = get_node(platform_spawner_path)
	spawner.connect("platform_placed", _on_platform_placed)

func _process(_delta: float) -> void:
	if _camera == null:
		return
	# Gleiche Sichtbereichs-Grenze wie beim PlatformSpawner-Recycling: alles
	# deutlich unterhalb der Kamera gilt als "verlassen" und wird für die
	# Wiederverwendung freigegeben.
	var recycle_y: float = _camera.global_position.y + _viewport_size.y * 0.65
	for i in _coins.size():
		var c: Node2D = _coins[i]
		if bool(c.call("is_active")) and c.global_position.y > recycle_y:
			c.call("deactivate")
			_free_indices.append(i)

func _on_platform_placed(pos: Vector2, half_width: float, guarantee_coin: bool) -> void:
	# guarantee_coin kommt vom Risk-Pattern (siehe platform_patterns.gd): die riskante
	# Plattform bekommt garantiert einen Coin als Belohnung, statt nur mit
	# spawn_chance zu würfeln wie jede andere Plattform.
	if not guarantee_coin and (randf() > spawn_chance or _free_indices.is_empty()):
		return
	if _free_indices.is_empty():
		return
	var idx: int = _free_indices.pop_back()
	var jitter: float = half_width * horizontal_jitter_factor
	var coin_x: float = pos.x + randf_range(-jitter, jitter)
	var coin_y: float = pos.y - hover_height
	_coins[idx].call("spawn_as", Vector2(coin_x, coin_y))
