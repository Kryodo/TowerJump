class_name PlatformPatterns
## Datenquelle für das Pattern-basierte Plattform-Spawning.
##
## Ein Pattern ist eine Array[Dictionary] aus "Slots" - relative Vorgaben für eine
## zusammenhängende Gruppe von Plattformen, die der PlatformSpawner nacheinander in
## real erreichbare Plattformen übersetzt (siehe platform_spawner.gd, _materialize_pattern()).
## Jeder Slot kennt nur RELATIVE Werte, keine absoluten Pixel/Welt-Koordinaten:
##
##   dx:          Horizontale Verschiebung relativ zur vorherigen Plattform, als
##                Bruchteil [-1.0, 1.0] der verfügbaren Spawn-Breite. -1.0 = ganz
##                links, 1.0 = ganz rechts, 0.0 = an Ort und Stelle bleiben.
##   dy:           Vertikaler Abstand zur vorherigen Plattform, als Bruchteil [0.0, 1.0]
##                zwischen min_gap (0.0) und dem physik-basierten max_gap (1.0). Der
##                Spawner klemmt diesen Wert IMMER in den erreichbaren Bereich - ein
##                Pattern kann also nie eine unerreichbare Lücke erzeugen.
##   width_scale: Breiten-Faktor für Platform.width_scale (Standard 1.0, falls fehlend).
##   type:        Platform.PlatformType-Wert, ODER TYPE_ROLL (-1), um den Typ stattdessen
##                über die bestehende, schwierigkeitsgewichtete Auswahl (inkl. der
##                Breakable-Fairness-Regel) würfeln zu lassen.
##   branch:      Wenn true, teilt sich dieser Slot die Höhe (dy wird ignoriert / als 0
##                behandelt) mit dem VORHERIGEN Slot, statt eine neue Stufe zu erzeugen.
##                Damit lassen sich zwei parallele Plattformen auf gleicher Höhe (Risk-
##                Pattern) beschreiben, ohne die Erreichbarkeits-Logik zu duplizieren.
##   guarantee_coin: Wenn true, platziert der CoinSpawner hier garantiert einen Coin
##                statt nur mit der normalen spawn_chance zu würfeln (Belohnung fürs
##                Risiko im Risk-Pattern).
##   boosted_gap: Wenn true, darf dieser Slot die vom Sprung-Boost der vorherigen
##                Spring-Plattform erweiterte maximale Lücke ausnutzen statt der
##                normalen max_gap (Boost-Sequenz).
##
## Enge Ansprüche wie "Basic nur mit NORMAL" ergeben sich NICHT aus fest codierten
## Typen, sondern daraus, dass TYPE_ROLL bei Schwierigkeit 0 ohnehin nur NORMAL würfelt
## (siehe PlatformSpawner._choose_platform_type) - Basic bleibt also am Spielanfang
## automatisch "gefahrlos", ohne dass dieses Pattern eine Sonderregel bräuchte.

const Platform := preload("res://scripts/platform.gd")

const TYPE_ROLL: int = -1

enum PatternType {
	BASIC,
	ZIGZAG,
	RISK,
	STAIRCASE,
	DIAGONAL,
	CROSS_SCREEN,
	CENTER_EDGE,
}

enum EntryMode {
	NONE,
	OPPOSITE,
	CONTINUE,
	CENTER,
	ADAPTIVE,
}

## Builds a pattern and applies the requested generation modifiers.
static func build(
	type: PatternType,
	difficulty: float = 0.0,
	entry_mode: EntryMode = EntryMode.NONE,
	previous_x: float = 0.5,
	density_multiplier: float = 1.0
) -> Array[Dictionary]:

	var slots: Array[Dictionary] = []

	match type:
		PatternType.BASIC:
			slots = _basic(difficulty)

		PatternType.ZIGZAG:
			slots = _zigzag(difficulty, entry_mode, previous_x)

		PatternType.RISK:
			slots = _risk(difficulty, entry_mode, previous_x)

		PatternType.STAIRCASE:
			slots = _staircase(difficulty, entry_mode, previous_x)

		PatternType.DIAGONAL:
			slots = _diagonal(difficulty, entry_mode, previous_x)

		PatternType.CROSS_SCREEN:
			slots = _cross_screen(difficulty, entry_mode, previous_x)

		PatternType.CENTER_EDGE:
			slots = _center_edge(difficulty, entry_mode, previous_x)

		_:
			slots = _basic(difficulty)

	## Applies global vertical pacing without changing the pattern's horizontal shape.
	_apply_density_modifier(slots, density_multiplier)

	return slots

## Adjusts vertical spacing while preserving the pattern's horizontal structure.
static func _apply_density_modifier(
	slots: Array[Dictionary],
	density_multiplier: float
) -> void:

	if is_equal_approx(density_multiplier, 1.0):
		return

	for slot in slots:
		var dy: float = float(slot.get("dy", 0.0))
		slot["dy"] = dy * density_multiplier

## ENTRY HELPER
static func _apply_entry_mode(
	slots: Array[Dictionary],
	entry_mode: EntryMode,
	previous_x: float
) -> Array[Dictionary]:

	if slots.is_empty():
		return slots

	var first_x: float = float(slots[0].get("x", 0.5))

	match entry_mode:

		EntryMode.OPPOSITE:
			if previous_x < 0.5 and first_x < 0.5:
				for slot in slots:
					slot["x"] = 1.0 - float(slot.get("x", 0.5))

			elif previous_x >= 0.5 and first_x >= 0.5:
				for slot in slots:
					slot["x"] = 1.0 - float(slot.get("x", 0.5))

		EntryMode.CONTINUE:
			if previous_x < 0.5 and first_x >= 0.5:
				for slot in slots:
					slot["x"] = 1.0 - float(slot.get("x", 0.5))

			elif previous_x >= 0.5 and first_x < 0.5:
				for slot in slots:
					slot["x"] = 1.0 - float(slot.get("x", 0.5))

		EntryMode.CENTER:
			slots[0]["x"] = 0.50

		EntryMode.ADAPTIVE:
			# Basic gets no forced direction for now.
			pass

		EntryMode.NONE:
			pass

	return slots

## BASIC TRANSITION/BRIDGE DISPATCHER
static func _basic(difficulty: float) -> Array[Dictionary]:
	if difficulty < 0.20:
		return _basic_calm()

	if difficulty < 0.40:
		return _basic_dense()

	## if difficulty < 0.60:
		## return _basic_transitional()

	if difficulty < 0.80:
		return _basic_sparse()

	return _basic_recovery()

## Basic_calm Variant
static func _basic_calm() -> Array[Dictionary]:
	var variant: int = randi_range(0, 2)

	if variant == 0:
		return [
			{
				"x": 0.22,
				"dy": 0.26,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.48,
				"dy": 0.28,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.72,
				"dy": 0.30,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.54,
				"dy": 0.28,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	if variant == 1:
		return [
			{
				"x": 0.78,
				"dy": 0.26,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.52,
				"dy": 0.28,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.28,
				"dy": 0.30,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.46,
				"dy": 0.28,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.32,
			"dy": 0.26,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.68,
			"dy": 0.28,
			"size": "wide",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.46,
			"dy": 0.30,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.18,
			"dy": 0.28,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Basic_dense Variant
static func _basic_dense() -> Array[Dictionary]:
	var variant: int = randi_range(0, 2)

	if variant == 0:
		return [
			{
				"x": 0.20,
				"dy": 0.15,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.42,
				"dy": 0.17,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.66,
				"dy": 0.16,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.82,
				"dy": 0.18,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.56,
				"dy": 0.17,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	if variant == 1:
		return [
			{
				"x": 0.80,
				"dy": 0.15,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.60,
				"dy": 0.17,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.36,
				"dy": 0.16,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.18,
				"dy": 0.18,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.46,
				"dy": 0.17,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.30,
			"dy": 0.14,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.74,
			"dy": 0.16,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.52,
			"dy": 0.15,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.16,
			"dy": 0.18,
			"size": "wide",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.64,
			"dy": 0.17,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Basic_sparse Variant
static func _basic_sparse() -> Array[Dictionary]:
	var variant: int = randi_range(0, 2)

	if variant == 0:
		return [
			{
				"x": 0.16,
				"dy": 0.40,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.68,
				"dy": 0.46,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.38,
				"dy": 0.42,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.84,
				"dy": 0.44,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	if variant == 1:
		return [
			{
				"x": 0.84,
				"dy": 0.40,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.30,
				"dy": 0.46,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.62,
				"dy": 0.42,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.14,
				"dy": 0.44,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.24,
			"dy": 0.42,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.86,
			"dy": 0.48,
			"size": "wide",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.48,
			"dy": 0.40,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.12,
			"dy": 0.46,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Basic_recovery Variant
static func _basic_recovery() -> Array[Dictionary]:
	var variant: int = randi_range(0, 2)

	if variant == 0:
		return [
			{
				"x": 0.18,
				"dy": 0.24,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.46,
				"dy": 0.26,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.72,
				"dy": 0.28,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.54,
				"dy": 0.25,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	if variant == 1:
		return [
			{
				"x": 0.82,
				"dy": 0.24,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.58,
				"dy": 0.26,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.30,
				"dy": 0.28,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.48,
				"dy": 0.25,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.24,
			"dy": 0.23,
			"size": "wide",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.72,
			"dy": 0.25,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.42,
			"dy": 0.27,
			"size": "wide",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.86,
			"dy": 0.24,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## ZIGZAG PATTERN
## ZIGTAG DISPATCHER
static func _zigzag(
	difficulty: float,
	entry_mode: PlatformPatterns.EntryMode,
	previous_x: float
) -> Array[Dictionary]:

	var slots: Array[Dictionary]

	if difficulty < 0.25:
		slots = _zigzag_gentle()
	elif difficulty < 0.50:
		slots = _zigzag_deep_switchback()
	elif difficulty < 0.75:
		slots = _zigzag_broken_ascent()
	else:
		slots = _zigzag_extreme()

	return _apply_entry_mode(slots, entry_mode, previous_x)

## Zigzag_Gentle Variant
## Early Forest:
## Moderate horizontal movement, comfortable rhythm and mostly forgiving platforms.
static func _zigzag_gentle() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.30,
				"dy": 0.26,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.70,
				"dy": 0.30,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.28,
				"dy": 0.32,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.72,
				"dy": 0.30,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.32,
				"dy": 0.28,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.70,
			"dy": 0.26,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.30,
			"dy": 0.30,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.72,
			"dy": 0.32,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.28,
			"dy": 0.30,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.68,
			"dy": 0.28,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
	]


## Zigzag_Deep_Switchback Variant
## Mid Forest:
## Stronger edge-to-edge movement and more committed steering.
static func _zigzag_deep_switchback() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.18,
				"dy": 0.30,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.84,
				"dy": 0.42,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.22,
				"dy": 0.36,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.82,
				"dy": 0.44,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.20,
				"dy": 0.40,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.82,
			"dy": 0.30,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.16,
			"dy": 0.42,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.78,
			"dy": 0.36,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.18,
			"dy": 0.44,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.80,
			"dy": 0.40,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
	]


## Zigzag_Broken_Ascent Variant
## Late Forest:
## Deliberately breaks the predictable left-right rhythm.
static func _zigzag_broken_ascent() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.20,
				"dy": 0.30,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.86,
				"dy": 0.48,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.46,
				"dy": 0.34,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.76,
				"dy": 0.52,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.14,
				"dy": 0.42,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.80,
			"dy": 0.30,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.14,
			"dy": 0.48,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.54,
			"dy": 0.34,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.22,
			"dy": 0.52,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.86,
			"dy": 0.42,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
	]


## Zigzag_Extreme Variant
## Deep Forest / high difficulty:
## Very large horizontal commitments with small landing targets.
static func _zigzag_extreme() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.12,
				"dy": 0.38,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.88,
				"dy": 0.50,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.18,
				"dy": 0.46,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.90,
				"dy": 0.54,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.10,
				"dy": 0.48,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.88,
			"dy": 0.38,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.12,
			"dy": 0.50,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.82,
			"dy": 0.46,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.10,
			"dy": 0.54,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.90,
			"dy": 0.48,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## DIAGONAL PATTERN DISPATCHER
static func _diagonal(
	difficulty: float,
	entry_mode: PlatformPatterns.EntryMode,
	previous_x: float
) -> Array[Dictionary]:

	var slots: Array[Dictionary]

	if difficulty < 0.25:
		slots = _diagonal_short()
	elif difficulty < 0.50:
		slots = _diagonal_long()
	elif difficulty < 0.75:
		slots = _diagonal_alternating()
	else:
		slots = _diagonal_extreme()

	return _apply_entry_mode(slots, entry_mode, previous_x)

## Diagonal_short Variant
## Early Forest:
## Short, sustained diagonal movement with a comfortable steering rhythm.
static func _diagonal_short() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.22,
				"dy": 0.26,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.36,
				"dy": 0.30,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.50,
				"dy": 0.32,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.64,
				"dy": 0.34,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.78,
				"dy": 0.30,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.78,
			"dy": 0.26,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.64,
			"dy": 0.30,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.50,
			"dy": 0.32,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.36,
			"dy": 0.34,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.22,
			"dy": 0.30,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Diagonal_long Variant
## Mid Forest:
## Longer horizontal commitment with increasingly deliberate steering.
static func _diagonal_long() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.12,
				"dy": 0.30,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.32,
				"dy": 0.38,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.55,
				"dy": 0.42,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.78,
				"dy": 0.45,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.90,
				"dy": 0.40,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.90,
			"dy": 0.30,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.78,
			"dy": 0.38,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.55,
			"dy": 0.42,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.32,
			"dy": 0.45,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.12,
			"dy": 0.40,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Diagonal_alternating Variant
## Late Forest:
## Breaks the clean diagonal rhythm with a directional reversal.
static func _diagonal_alternating() -> Array[Dictionary]:
	var start_left: bool = randf() < 0.5

	if start_left:
		return [
			{
				"x": 0.15,
				"dy": 0.34,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.38,
				"dy": 0.44,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.68,
				"dy": 0.48,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.52,
				"dy": 0.38,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.85,
				"dy": 0.50,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.85,
			"dy": 0.34,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.62,
			"dy": 0.44,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.32,
			"dy": 0.48,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.48,
			"dy": 0.38,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.15,
			"dy": 0.50,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Diagonal_extreme Variant
## Deep Forest:
## Large diagonal commitments with small landing targets.
static func _diagonal_extreme() -> Array[Dictionary]:
	var start_left: bool = randf() < 0.5

	if start_left:
		return [
			{
				"x": 0.10,
				"dy": 0.40,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.38,
				"dy": 0.52,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.82,
				"dy": 0.58,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.62,
				"dy": 0.46,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.92,
				"dy": 0.60,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.90,
			"dy": 0.40,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.62,
			"dy": 0.52,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.18,
			"dy": 0.58,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.38,
			"dy": 0.46,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.08,
			"dy": 0.60,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## CROSS_SCREEN PATTERN DISPATCHER
static func _cross_screen(
	difficulty: float,
	entry_mode: PlatformPatterns.EntryMode,
	previous_x: float
) -> Array[Dictionary]:

	var slots: Array[Dictionary]

	if difficulty < 0.25:
		slots = _cross_screen_gentle()
	elif difficulty < 0.50:
		slots = _cross_screen_long()
	elif difficulty < 0.75:
		slots = _cross_screen_broken()
	else:
		slots = _cross_screen_extreme()

	return _apply_entry_mode(slots, entry_mode, previous_x)

## Cross_Screen_Gentle Variant
static func _cross_screen_gentle() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.12,
				"dy": 0.28,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.55,
				"dy": 0.32,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.88,
				"dy": 0.34,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.58,
				"dy": 0.30,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.88,
			"dy": 0.28,
			"size": "wide",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.45,
			"dy": 0.32,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.12,
			"dy": 0.34,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.42,
			"dy": 0.30,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Cross_Screen_Long Variant
static func _cross_screen_long() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.10,
				"dy": 0.32,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.50,
				"dy": 0.42,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.90,
				"dy": 0.48,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.40,
				"dy": 0.38,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.90,
			"dy": 0.32,
			"size": "wide",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.50,
			"dy": 0.42,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.10,
			"dy": 0.48,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.60,
			"dy": 0.38,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Cross_Screen_Broken Variant
static func _cross_screen_broken() -> Array[Dictionary]:
	var start_left: bool = randf() < 0.5

	if start_left:
		return [
			{
				"x": 0.08,
				"dy": 0.34,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.72,
				"dy": 0.46,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.30,
				"dy": 0.18,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.90,
				"dy": 0.50,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.48,
				"dy": 0.40,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.92,
			"dy": 0.34,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.28,
			"dy": 0.46,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.70,
			"dy": 0.18,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.10,
			"dy": 0.50,
			"size": "wide",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.52,
			"dy": 0.40,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Cross_Screen_Extreme Variant
static func _cross_screen_extreme() -> Array[Dictionary]:
	var start_left: bool = randf() < 0.5

	if start_left:
		return [
			{
				"x": 0.06,
				"dy": 0.40,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.90,
				"dy": 0.52,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.35,
				"dy": 0.58,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.94,
				"dy": 0.54,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.12,
				"dy": 0.60,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.94,
			"dy": 0.40,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.10,
			"dy": 0.52,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.65,
			"dy": 0.58,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.06,
			"dy": 0.54,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.88,
			"dy": 0.60,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## CENTER-EDGE-OPPOSITE EDGE PATTERN DISPATCHER
static func _center_edge(
	difficulty: float,
	entry_mode: PlatformPatterns.EntryMode,
	previous_x: float
) -> Array[Dictionary]:

	var slots: Array[Dictionary]

	if difficulty < 0.25:
		slots = _center_edge_gentle()
	elif difficulty < 0.50:
		slots = _center_edge_long()
	elif difficulty < 0.75:
		slots = _center_edge_broken()
	else:
		slots = _center_edge_extreme()

	return _apply_entry_mode(slots, entry_mode, previous_x)

## Center_edge_gentle Variant
## Early Forest:
## Clear center → edge → opposite edge movement with forgiving spacing.
static func _center_edge_gentle() -> Array[Dictionary]:
	var left_first: bool = randf() < 0.5

	if left_first:
		return [
		{
			"x": 0.50,
			"dy": 0.28,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.12,
			"dy": 0.34,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.88,
			"dy": 0.38,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
	]

	return [
		{
			"x": 0.50,
			"dy": 0.28,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.88,
			"dy": 0.34,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.12,
			"dy": 0.38,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Center_edge_long Variant
## Mid Forest:
## Stronger edge commitment while preserving the center → edge identity.
static func _center_edge_long() -> Array[Dictionary]:
	var left_first: bool = randf() < 0.5

	if left_first:
		return [
			{
				"x": 0.50,
				"dy": 0.32,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.08,
				"dy": 0.44,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.92,
				"dy": 0.50,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.50,
			"dy": 0.32,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.92,
			"dy": 0.44,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.08,
			"dy": 0.50,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Center_edge_broken Variant
## Late Forest:
## Center → edge → opposite edge, followed by a broken inward movement.
static func _center_edge_broken() -> Array[Dictionary]:
	var left_first: bool = randf() < 0.5

	if left_first:
		return [
			{
				"x": 0.50,
				"dy": 0.34,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.08,
				"dy": 0.46,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.82,
				"dy": 0.52,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.38,
				"dy": 0.42,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.50,
			"dy": 0.34,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.92,
			"dy": 0.46,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.18,
			"dy": 0.52,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.62,
			"dy": 0.42,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Center_edge_extreme Variant
## Deep Forest:
## Extreme edge commitments with small landing targets and a broken return.
static func _center_edge_extreme() -> Array[Dictionary]:
	var left_first: bool = randf() < 0.5

	if left_first:
		return [
			{
				"x": 0.50,
				"dy": 0.38,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.06,
				"dy": 0.52,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.94,
				"dy": 0.60,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.32,
				"dy": 0.48,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.50,
			"dy": 0.38,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.94,
			"dy": 0.52,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.06,
			"dy": 0.60,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.68,
			"dy": 0.48,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## RISK PATTERN DISPATCHER
static func _risk(
	difficulty: float,
	entry_mode: PlatformPatterns.EntryMode,
	previous_x: float
) -> Array[Dictionary]:

	var slots: Array[Dictionary]

	if difficulty < 0.25:
		slots = _risk_gentle()
	elif difficulty < 0.50:
		slots = _risk_committed()
	elif difficulty < 0.75:
		slots = _risk_broken()
	else:
		slots = _risk_extreme()

	return _apply_entry_mode(slots, entry_mode, previous_x)

## Risk_gentle Variant
static func _risk_gentle() -> Array[Dictionary]:
	var left_first: bool = randf() < 0.5

	if left_first:
		return [
			{
				"x": 0.35,
				"dy": 0.24,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.62,
				"dy": 0.28,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.88,
				"dy": 0.36,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.18,
				"dy": 0.32,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.65,
			"dy": 0.24,
			"size": "wide",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.38,
			"dy": 0.28,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.12,
			"dy": 0.36,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.82,
			"dy": 0.32,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Risk_commited Variant
static func _risk_committed() -> Array[Dictionary]:
	var left_first: bool = randf() < 0.5

	if left_first:
		return [
			{
				"x": 0.22,
				"dy": 0.30,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.78,
				"dy": 0.38,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.94,
				"dy": 0.30,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.34,
				"dy": 0.42,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.78,
			"dy": 0.30,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.22,
			"dy": 0.38,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.06,
			"dy": 0.30,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.66,
			"dy": 0.42,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Risk_broken Variant
static func _risk_broken() -> Array[Dictionary]:
	var left_first: bool = randf() < 0.5

	if left_first:
		return [
			{
				"x": 0.14,
				"dy": 0.34,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.82,
				"dy": 0.46,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.48,
				"dy": 0.34,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.92,
				"dy": 0.50,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.28,
				"dy": 0.42,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.86,
			"dy": 0.34,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.18,
			"dy": 0.46,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.52,
			"dy": 0.34,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.08,
			"dy": 0.50,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.72,
			"dy": 0.42,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Risk_extreme Variant
static func _risk_extreme() -> Array[Dictionary]:
	var left_first: bool = randf() < 0.5

	if left_first:
		return [
			{
				"x": 0.08,
				"dy": 0.40,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.92,
				"dy": 0.52,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.36,
				"dy": 0.44,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.94,
				"dy": 0.58,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.16,
				"dy": 0.48,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.92,
			"dy": 0.40,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.08,
			"dy": 0.52,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.64,
			"dy": 0.44,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.06,
			"dy": 0.58,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.84,
			"dy": 0.48,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Plattformen steigen gleichmäßig diagonal in eine Richtung - schnelles Hochklettern
## in vorhersehbaren, moderaten Schritten.
static func _staircase(
	difficulty: float,
	entry_mode: PlatformPatterns.EntryMode,
	previous_x: float
) -> Array[Dictionary]:

	var slots: Array[Dictionary]

	if difficulty < 0.25:
		slots = _staircase_gentle()
	elif difficulty < 0.50:
		slots = _staircase_long()
	elif difficulty < 0.75:
		slots = _staircase_broken()
	else:
		slots = _staircase_gauntlet()

	return _apply_entry_mode(slots, entry_mode, previous_x)

## Staircase_gentle variant
static func _staircase_gentle() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.22,
				"dy": 0.22,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.38,
				"dy": 0.24,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.54,
				"dy": 0.24,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.70,
				"dy": 0.26,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.84,
				"dy": 0.24,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.78,
			"dy": 0.22,
			"size": "wide",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.62,
			"dy": 0.24,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.46,
			"dy": 0.24,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.30,
			"dy": 0.26,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.16,
			"dy": 0.24,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Staircase_long variant
static func _staircase_long() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.14,
				"dy": 0.28,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.34,
				"dy": 0.34,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.56,
				"dy": 0.38,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.78,
				"dy": 0.40,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.90,
				"dy": 0.34,
				"size": "wide",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.86,
			"dy": 0.28,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.66,
			"dy": 0.34,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.44,
			"dy": 0.38,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.22,
			"dy": 0.40,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.10,
			"dy": 0.34,
			"size": "wide",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Staircase_broken pattern variant
static func _staircase_broken() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.14,
				"dy": 0.30,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.36,
				"dy": 0.44,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.30,
				"dy": 0.18,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.66,
				"dy": 0.46,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.88,
				"dy": 0.40,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.86,
			"dy": 0.30,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.64,
			"dy": 0.44,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.70,
			"dy": 0.18,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.34,
			"dy": 0.46,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.12,
			"dy": 0.40,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
	]

## Staircase_gauntlet pattern variant
static func _staircase_gauntlet() -> Array[Dictionary]:
	var left_to_right: bool = randf() < 0.5

	if left_to_right:
		return [
			{
				"x": 0.10,
				"dy": 0.38,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.34,
				"dy": 0.50,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.62,
				"dy": 0.56,
				"size": "tiny",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.88,
				"dy": 0.52,
				"size": "small",
				"type": Platform.PlatformType.NORMAL,
			},
			{
				"x": 0.74,
				"dy": 0.22,
				"size": "standard",
				"type": Platform.PlatformType.NORMAL,
			},
		]

	return [
		{
			"x": 0.90,
			"dy": 0.38,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.66,
			"dy": 0.50,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.38,
			"dy": 0.56,
			"size": "tiny",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.12,
			"dy": 0.52,
			"size": "small",
			"type": Platform.PlatformType.NORMAL,
		},
		{
			"x": 0.26,
			"dy": 0.22,
			"size": "standard",
			"type": Platform.PlatformType.NORMAL,
		},
	]
