extends CanvasLayer
## Game-Over-Overlay: bleibt unsichtbar bis GameManager.game_over_triggered feuert,
## zeigt dann Score/Highscore an und erlaubt einen sauberen Neustart der Szene.
## process_mode = WHEN_PAUSED, damit der Neustart-Button funktioniert, während
## der Rest des Spiels (get_tree().paused = true) eingefroren ist.

@onready var _score_label: Label = $Panel/VBoxContainer/ScoreLabel
@onready var _highscore_label: Label = $Panel/VBoxContainer/HighscoreLabel
@onready var _coins_label: Label = $Panel/VBoxContainer/CoinsLabel
@onready var _total_coins_label: Label = $Panel/VBoxContainer/TotalCoinsLabel
@onready var _new_highscore_label: Label = $Panel/VBoxContainer/NewHighscoreLabel
@onready var _restart_button: Button = $Panel/VBoxContainer/RestartButton

func _ready() -> void:
	visible = false
	GameManager.game_over_triggered.connect(_on_game_over)
	_restart_button.pressed.connect(_on_restart_pressed)

func _on_game_over(score: int, highscore: int, is_new_highscore: bool, run_coins: int, total_coins: int) -> void:
	_score_label.text = "Score: %d" % score
	_highscore_label.text = "Highscore: %d" % highscore
	_coins_label.text = "Coins gesammelt: %d" % run_coins
	_total_coins_label.text = "Coins gesamt: %d" % total_coins
	_new_highscore_label.visible = is_new_highscore
	visible = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
