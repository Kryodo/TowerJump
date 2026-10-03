extends Node
## Zentrale Quelle für Score, Highscore und Coins (als Autoload "GameManager"
## registriert). Der Score entspricht der höchsten bisher erreichten Höhe des Balls
## (in Punkten, nicht zeitbasiert) und sinkt nicht wieder, wenn der Ball fällt.
##
## Coins: run_coins zählt nur den aktuellen Run und wird bei reset() auf 0 gesetzt.
## Am Ende eines Runs (trigger_game_over()) wird run_coins zu total_coins addiert,
## das - wie der Highscore - dauerhaft in derselben SAVE_PATH-Datei liegt und einen
## App-Neustart übersteht.

signal score_changed(new_score: int)
signal coins_changed(run_coins: int)
signal game_over_triggered(score: int, highscore: int, is_new_highscore: bool, run_coins: int, total_coins: int)

const SAVE_PATH: String = "user://highscore.json"
const PIXELS_PER_POINT: float = 10.0 ## Höhengewinn in Pixel, der einem Punkt entspricht

var current_score: int = 0
var highscore: int = 0
var run_coins: int = 0
var total_coins: int = 0

func _ready() -> void:
	_load_data()

## Setzt Score und Run-Coins für einen neuen Run zurück. Wird von main.gd bei
## Szenenstart (auch nach reload_current_scene()) aufgerufen. total_coins bleibt
## dabei unangetastet, da es runübergreifend persistiert.
func reset() -> void:
	current_score = 0
	score_changed.emit(current_score)
	run_coins = 0
	coins_changed.emit(run_coins)

## Von Coin._collect() aufgerufen, sobald der Ball einen Coin einsammelt.
func add_coins(amount: int) -> void:
	run_coins += amount
	coins_changed.emit(run_coins)

## Meldet die aktuelle Höhe (in Pixel) über dem Startpunkt des Balls. Der Score
## steigt nur bei einer neuen maximalen Höhe, ein Rückfall des Balls senkt ihn nicht.
func report_height(height_px: float) -> void:
	var score: int = int(height_px / PIXELS_PER_POINT)
	if score > current_score:
		current_score = score
		score_changed.emit(current_score)

## Beendet den aktuellen Run, aktualisiert bei Bedarf den Highscore, addiert
## run_coins zu total_coins, persistiert beides gemeinsam und benachrichtigt
## Listener (z.B. HUD und Game-Over-Screen).
func trigger_game_over() -> void:
	var is_new_highscore: bool = current_score > highscore
	if is_new_highscore:
		highscore = current_score
	total_coins += run_coins
	_save_data()
	game_over_triggered.emit(current_score, highscore, is_new_highscore, run_coins, total_coins)

func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("highscore"):
		highscore = int(data["highscore"])
	if data.has("total_coins"):
		total_coins = int(data["total_coins"])

func _save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"highscore": highscore, "total_coins": total_coins}))
	file.close()
