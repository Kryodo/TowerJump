extends CanvasLayer
## Zeigt Score und aktuelle Run-Coins live während des Spiels an.

@onready var _score_label: Label = $ScoreLabel
@onready var _coin_label: Label = $CoinLabel

@onready var _platform_spawner: Node = get_node("../PlatformSpawner")

var _debug_displayed_section: PlatformGeneratorBrain.BiomeSection = \
	PlatformGeneratorBrain.BiomeSection.EARLY

## Tracks whether the temporary section label has displayed its first state.
var _debug_section_initialized: bool = false

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.coins_changed.connect(_on_coins_changed)
	_on_score_changed(GameManager.current_score)
	_on_coins_changed(GameManager.run_coins)

func _on_score_changed(new_score: int) -> void:
	_score_label.text = "Score: %d" % new_score

func _on_coins_changed(new_run_coins: int) -> void:
	_coin_label.text = "● %d" % new_run_coins


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
