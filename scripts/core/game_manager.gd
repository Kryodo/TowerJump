extends Node
## Authoritative run-score owner for TowerJump.
## The total score combines the highest height reached with points earned from
## confirmed landings. Coins and persistent highscore behavior remain separate.

signal score_changed(new_score: int)
signal coins_changed(run_coins: int)
signal game_over_triggered(score: int, highscore: int, is_new_highscore: bool, run_coins: int, total_coins: int)

const SAVE_PATH: String = "user://highscore.json"
const PIXELS_PER_POINT: float = 10.0 ## Peak height in pixels converted into height-score points.

var current_score: int = 0
var highscore: int = 0
var height_score: int = 0
var landing_points: int = 0
var run_coins: int = 0
var total_coins: int = 0

# Run statistics are retained centrally for the results screen and future
# leaderboard payloads; display and scoring code never maintain duplicate totals.
var landing_count: int = 0
var good_landings: int = 0
var epic_landings: int = 0
var perfect_landings: int = 0
var clutch_landings: int = 0
var best_quality_chain: int = 0
var highest_streak: int = 0
var streaks_reached: int = 0
var streak_bonus_points: int = 0


func _ready() -> void:
	_load_data()


## Starts a new run. The saved highscore and total coins remain untouched.
func reset() -> void:
	height_score = 0
	landing_points = 0
	current_score = 0
	landing_count = 0
	good_landings = 0
	epic_landings = 0
	perfect_landings = 0
	clutch_landings = 0
	best_quality_chain = 0
	highest_streak = 0
	streaks_reached = 0
	streak_bonus_points = 0
	score_changed.emit(current_score)

	run_coins = 0
	coins_changed.emit(run_coins)


## Adds one authoritative landing result from LandingScoreController.
func record_landing_result(result: Dictionary) -> void:
	var points: int = maxi(int(result.get("total_points", 0)), 0)
	landing_points += points
	landing_count += 1

	match str(result.get("quality", "GOOD")):
		"EPIC":
			epic_landings += 1
		"PERFECT":
			perfect_landings += 1
		_:
			good_landings += 1

	if bool(result.get("clutch", false)):
		clutch_landings += 1

	var chain_count: int = int(result.get("chain_count", 0))
	best_quality_chain = maxi(best_quality_chain, chain_count)
	if bool(result.get("streak_active", false)):
		highest_streak = maxi(highest_streak, chain_count)
	if bool(result.get("streak_activated", false)):
		streaks_reached += 1
		streak_bonus_points += int(result.get("streak_bonus", 0))

	_refresh_current_score()


## Von Coin._collect() aufgerufen, sobald der Ball einen Coin einsammelt.
func add_coins(amount: int) -> void:
	run_coins += amount
	coins_changed.emit(run_coins)


## Peak height contributes to the total, but landing awards accumulate on top.
func report_height(height_px: float) -> void:
	var new_height_score: int = maxi(height_score, int(height_px / PIXELS_PER_POINT))
	if new_height_score == height_score:
		return
	height_score = new_height_score
	_refresh_current_score()


func _refresh_current_score() -> void:
	var updated_score: int = height_score + landing_points
	if updated_score == current_score:
		return
	current_score = updated_score
	score_changed.emit(current_score)


## Ends the run and persists the best total score plus accumulated coins.
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
