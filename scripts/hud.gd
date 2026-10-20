extends CanvasLayer
## Displays the run total, coins and current same-quality combo progress.

@onready var _score_label: Label = $ScoreLabel
@onready var _coin_label: Label = $CoinLabel
@onready var _platform_spawner: Node = get_node("../PlatformSpawner")

var _landing_score_controller: Node
var _combo_status_label: Label

var _debug_displayed_section: PlatformGeneratorBrain.BiomeSection = \
	PlatformGeneratorBrain.BiomeSection.EARLY

## Tracks whether the temporary section label has displayed its first state.
var _debug_section_initialized: bool = false


func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.coins_changed.connect(_on_coins_changed)
	_on_score_changed(GameManager.current_score)
	_on_coins_changed(GameManager.run_coins)
	_create_combo_status_label()

	_landing_score_controller = get_node_or_null("../LandingScoreController")
	if _landing_score_controller != null:
		_landing_score_controller.connect("combo_state_changed", _on_combo_state_changed)
		_on_combo_state_changed(_landing_score_controller.call("get_combo_state"))


func _create_combo_status_label() -> void:
	_combo_status_label = Label.new()
	_combo_status_label.name = "ComboStatusLabel"
	_combo_status_label.position = Vector2(20.0, 101.0)
	_combo_status_label.size = Vector2(460.0, 34.0)
	_combo_status_label.visible = false
	_combo_status_label.add_theme_font_size_override("font_size", 18)
	_combo_status_label.add_theme_color_override("font_color", Color(0.62, 0.88, 1.0, 1.0))
	_combo_status_label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.05, 0.98))
	_combo_status_label.add_theme_constant_override("outline_size", 4)
	add_child(_combo_status_label)


func _on_score_changed(new_score: int) -> void:
	_score_label.text = "Score: %d" % new_score


func _on_coins_changed(new_run_coins: int) -> void:
	_coin_label.text = "● %d" % new_run_coins


func _on_combo_state_changed(state: Dictionary) -> void:
	if _combo_status_label == null:
		return

	var chain_count: int = int(state.get("chain_count", 0))
	if chain_count <= 0:
		_combo_status_label.visible = false
		return

	_combo_status_label.visible = true
	var quality: String = str(state.get("quality", "GOOD"))
	var combo_active: bool = bool(state.get("combo_active", false))
	var streak_active: bool = bool(state.get("streak_active", false))
	var multiplier: float = float(state.get("multiplier", 1.0))
	var activation_count: int = int(state.get("combo_activation_landings", 3))
	var color: Color

	match quality:
		"PERFECT":
			color = Color(0.86, 0.98, 1.0, 1.0)
		"EPIC":
			color = Color(0.72, 0.44, 1.0, 1.0)
		_:
			color = Color(0.40, 0.86, 1.0, 1.0)

	if streak_active:
		_combo_status_label.text = "%s STREAK  ×%.2f  ·  %d" % [
			quality, multiplier, chain_count
		]
		color = Color(1.0, 0.73, 0.30, 1.0)
	elif combo_active:
		_combo_status_label.text = "%s COMBO  ×%.2f  ·  %d" % [
			quality, multiplier, chain_count
		]
	else:
		_combo_status_label.text = "%s CHAIN  %d/%d" % [
			quality, chain_count, activation_count
		]
	_combo_status_label.add_theme_color_override("font_color", color)


func _process(_delta: float) -> void:
	update_debug_section_label()


## Shows the current biome section with a temporary fade-in transition.
func update_debug_section_label() -> void:
	var section: PlatformGeneratorBrain.BiomeSection = \
		_platform_spawner.get_current_section()

	## Allows the initial section to display once at game start.
	if not _debug_section_initialized:
		_debug_section_initialized = true
		_debug_displayed_section = section
	else:
		if section == _debug_displayed_section:
			return

		_debug_displayed_section = section

	var label: Label = $DebugSectionLabel

	match section:
		PlatformGeneratorBrain.BiomeSection.EARLY:
			label.text = "EARLY FOREST"
		PlatformGeneratorBrain.BiomeSection.MID:
			label.text = "MID FOREST"
		PlatformGeneratorBrain.BiomeSection.LATE:
			label.text = "LATE FOREST"
		PlatformGeneratorBrain.BiomeSection.DEEP:
			label.text = "DEEP FOREST"

	label.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
