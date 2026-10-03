extends Node2D
## Orchestriert die Main-Szene und prüft den Fall-Death-Zustand.

@export var ball_path: NodePath
@export var camera_path: NodePath
@export var death_margin: float = 100.0 ## Zusätzlicher Puffer unter dem sichtbaren Bildschirmrand

@onready var _ball: CharacterBody2D = get_node(ball_path)
@onready var _camera: Camera2D = get_node(camera_path)

var _game_over: bool = false
var _start_y: float

func _ready() -> void:
	_start_y = _ball.global_position.y
	GameManager.reset()

func _process(_delta: float) -> void:
	if _game_over:
		return

	GameManager.report_height(_start_y - _ball.global_position.y)

	var viewport_height: float = get_viewport_rect().size.y
	var death_y: float = _camera.global_position.y + viewport_height * 0.5 + death_margin
	if _ball.global_position.y > death_y:
		_game_over = true
		GameManager.trigger_game_over()
		get_tree().paused = true
