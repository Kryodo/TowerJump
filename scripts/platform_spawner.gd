extends Node2D
## Objekt-Pool für Plattformen mit endlosem Nach-oben-Scrollen.
##
## Statt fortlaufend instantiate()/queue_free() aufzurufen, werden `pool_size`
## Plattform-Instanzen genau EINMAL erzeugt. Fällt eine Plattform weit genug
## unter die Kamera, wird sie nicht gelöscht, sondern per spawn_as() an eine
## neue Stelle oberhalb der bisher höchsten Plattform "teleportiert" und so
## wiederverwendet ("recycelt"). Das hält die Anzahl an Nodes/Physics-Bodies
## für ein theoretisch endloses Spiel konstant.
##
## Statt jede Plattform unabhängig zu würfeln, wählt der Spawner pro "Abschnitt"
## ein komplettes Pattern (siehe platform_patterns.gd) und arbeitet dessen relative
## Slots einzeln ab - eine Plattform pro Aufruf von _next_platform_spec(), damit
## sich Pooling/Recycling nicht ändern müssen. Ist die Slot-Queue leer, wird ein
## neues Pattern gewürfelt (_choose_pattern_type(), an den Score gekoppelt).

const Platform := preload("res://scripts/platform.gd")
## PlatformPatterns ist über class_name (platform_patterns.gd) bereits global verfügbar.

## Feuert bei jeder (Neu-)Platzierung einer Plattform - sowohl beim initialen
## Befüllen des Pools als auch bei jedem Recycling. Der CoinSpawner hört darauf,
## um Coins in der Nähe neu generierter Plattformen zu platzieren. guarantee_coin
## kommt aus dem Pattern (z.B. Risk-Pattern-Bonus) und umgeht dort die normale
## Zufalls-Chance des CoinSpawners.
signal platform_placed(position: Vector2, half_width: float, guarantee_coin: bool)

@export var platform_scene: PackedScene
@export var pool_size: int = 14
@export var ball_path: NodePath
@export var camera_path: NodePath

@export var min_gap: float = 130.0        ## Minimaler vertikaler Abstand zwischen Plattformen
@export var gap_safety_factor: float = 0.85 ## Anteil der maximalen Sprunghöhe, der als Obergrenze genutzt wird
@export var horizontal_margin: float = 40.0 ## Abstand der Plattformmitte zum Bildschirmrand

@export_group("Schwierigkeitskurve")
@export var difficulty_max_score: float = 400.0 ## Score, ab dem die maximale Varianten-Mischung erreicht ist
@export var max_moving_weight: float = 0.30   ## Anteil "Beweglich" bei voller Schwierigkeit (nur für gewürfelte Slots)
@export var max_breakable_weight: float = 0.22 ## Anteil "Brüchig" bei voller Schwierigkeit (nur für gewürfelte Slots)
@export var spring_weight: float = 0.12       ## Anteil "Spring" - konstant, da Bonus statt Erschwernis
@export var width_shrink_at_max_difficulty: float = 0.8 ## Faktor auf width_scale bei voller Schwierigkeit
@export var min_width_scale: float = 0.55
@export var max_width_scale: float = 1.3
@export var gap_push_strength: float = 0.65 ## Wie stark Lücken bei steigender Schwierigkeit Richtung max_gap gezogen werden

@export_group("Pattern-Freischaltung")
@export var basic_weight_start: float = 3.0 ## Basic-Gewicht bei Score 0 - dominiert praktisch vollständig
@export var basic_weight_end: float = 0.6   ## Basic-Gewicht bei voller Schwierigkeit - bleibt als "Verschnaufpause" erhalten
## Reihenfolge/Index passend zu PlatformPatterns.PatternType OHNE Basic (das eigene
## Sonderbehandlung oben hat): [ZIGZAG, RISK, STAIRCASE, BOOST, MOVING_CHALLENGE].
## Wert = Schwierigkeit (0..1 von difficulty_max_score), ab der das Pattern überhaupt
## erscheinen kann; sein Gewicht wächst danach linear bis zum zugehörigen Max-Gewicht.
@export var pattern_unlock_difficulty: PackedFloat32Array = [0.15, 0.4, 0.3, 0.55, 0.7]
@export var pattern_max_weight: PackedFloat32Array = [1.0, 0.8, 1.0, 0.8, 0.9]

## Pattern Zigzag zest, delete later
@export_group("Pattern Testing")
@export var force_test_pattern: bool = false
@export var test_pattern: PlatformPatterns.PatternType = PlatformPatterns.PatternType.ZIGZAG

##Platform Sizes
enum PlatformSize {
	TINY,
	SMALL,
	STANDARD,
	WIDE,
	LARGE,
}

const PLATFORM_WIDTHS := {
	PlatformSize.TINY: 80.0,
	PlatformSize.SMALL: 120.0,
	PlatformSize.STANDARD: 180.0,
	PlatformSize.WIDE: 240.0,
	PlatformSize.LARGE: 300.0,
}

var _platforms: Array[Node2D] = []
var _camera: Camera2D
var _viewport_size: Vector2
var _highest_y: float = 0.0 ## y-Position der bisher höchsten (kleinster y-Wert) generierten Plattform
var _max_gap: float
var _last_type: int = Platform.PlatformType.NORMAL ## Typ (Platform.PlatformType) der zuletzt (in aufsteigender Höhen-Reihenfolge) platzierten Plattform
var _cursor_x: float = 0.0 ## x-Position der zuletzt platzierten Plattform (Bezugspunkt für dx der Patterns)
var _pending_slots: Array[Dictionary] = [] ## Noch nicht materialisierte Slots des aktuellen Patterns
var _previous_x_fraction: float = 0.5 ## This stores the normalized horizontal position of the last actually placed platform
var _generator_brain: PlatformGeneratorBrain

func _ready() -> void:
	_generator_brain = PlatformGeneratorBrain.new(
		difficulty_max_score,
		basic_weight_start,
		basic_weight_end,
		pattern_unlock_difficulty,
		pattern_max_weight,
		max_moving_weight,
		max_breakable_weight,
		spring_weight,
		width_shrink_at_max_difficulty,
		min_width_scale,
		max_width_scale
	)
	
	_viewport_size = get_viewport_rect().size
	var ball := get_node(ball_path) as CharacterBody2D
	_camera = get_node(camera_path) as Camera2D
	
	# Erreichbarkeits-Berechnung: aus der Wurfparabel des Balls (v0 = jump_velocity,
	# a = gravity) folgt die maximal erreichbare Sprunghöhe h = v0^2 / (2 * g).
	# gap_safety_factor lässt etwas Puffer, damit Lücken bei ungünstigem Timing
	# trotzdem sicher schaffbar bleiben. Gilt für JEDE Plattform-zu-Plattform-Distanz,
	# unabhängig davon, welches Pattern sie erzeugt hat (siehe _next_platform_spec()).
	var max_jump_height: float = (ball.jump_velocity ** 2) / (2.0 * ball.gravity)
	_max_gap = maxf(max_jump_height * gap_safety_factor, min_gap + 40.0)

	_highest_y = ball.global_position.y + 120.0
	_cursor_x = ball.global_position.x

	for i in pool_size:
		var p := platform_scene.instantiate() as Node2D
		add_child(p)
		_platforms.append(p)

		var pos: Vector2
		var type: int
		var width_scale: float
		var guarantee_coin: bool
		if i == 0:
			# Erste Plattform direkt unter dem Ball-Start (nicht Viewport-Mitte!): Bei
			# stretch/mode="canvas_items" + aspect="expand" kann die tatsächliche
			# Viewport-Breite je nach Fenster-/Bildschirmseitenverhältnis vom Design-Wert
			# abweichen, wodurch die Plattform sonst seitlich am Ball vorbei landen kann.
			# Außerdem immer NORMAL und extra breit, damit der Spielstart garantiert fair
			# ist. Verbraucht keinen Pattern-Slot.
			pos = Vector2(ball.global_position.x, _highest_y)
			type = Platform.PlatformType.NORMAL
			width_scale = max_width_scale
			guarantee_coin = false
		else:
			var spec := _next_platform_spec(p)
			pos = spec.position
			type = spec.type
			width_scale = spec.width_scale
			guarantee_coin = spec.guarantee_coin
		_last_type = type
		_cursor_x = pos.x
		p.call("spawn_as", type, pos, width_scale)
		platform_placed.emit(pos, p.call("half_width"), guarantee_coin)

## Updates generator context and recycles platforms during gameplay.
func _process(delta: float) -> void:
	if _camera == null:
		return

	_generator_brain.update_generation_context(delta)
	# Alles deutlich unterhalb des sichtbaren Bereichs (Kamera-Mitte + Puffer)
	# gilt als "verlassen" und wird recycelt, statt gelöscht zu werden. Brüchige
	# Plattformen sind davon nicht ausgenommen: sie werden nach dem Wegbrechen
	# unsichtbar/nicht-kollidierbar, bleiben aber an Ort und Stelle liegen und
	# durchlaufen denselben y-basierten Recycling-Pfad wie jede andere Plattform -
	# sie werden also erst NACH dem vollständigen Verschwinden neu platziert.
	var recycle_y: float = _camera.global_position.y + _viewport_size.y * 0.65
	for p in _platforms:
		if p.global_position.y > recycle_y:
			var spec := _next_platform_spec(p)
			_last_type = spec.type
			_cursor_x = spec.position.x
			p.call("spawn_as", spec.type, spec.position, spec.width_scale)
			platform_placed.emit(spec.position, p.call("half_width"), spec.guarantee_coin)

## Returns the biome section currently used by the Generator Brain.
func get_current_section() -> PlatformGeneratorBrain.BiomeSection:
	return _generator_brain.get_current_section()

## HELPER
func _size_name_to_enum(size_name: String) -> PlatformSize:
	match size_name:
		"tiny":
			return PlatformSize.TINY
		"small":
			return PlatformSize.SMALL
		"standard":
			return PlatformSize.STANDARD
		"wide":
			return PlatformSize.WIDE
		"large":
			return PlatformSize.LARGE
		_:
			return PlatformSize.STANDARD

## Liefert die Platzierungs-Daten für die NÄCHSTE Plattform, egal ob beim initialen
## Befüllen oder beim Recycling - beides ruft strikt in aufsteigender Höhen-Reihenfolge
## auf, wodurch _last_type/_highest_y/_cursor_x patternübergreifend konsistent bleiben.
## Ist die Slot-Queue des aktuellen Patterns leer, wird zuerst ein neues gewürfelt.
func _next_platform_spec(p: Node2D) -> Dictionary:
	if _pending_slots.is_empty():
		var difficulty: float = _generator_brain.get_difficulty()
		var next_pattern: PlatformPatterns.PatternType
		var entry_mode: PlatformPatterns.EntryMode = PlatformPatterns.EntryMode.NONE
		var density_multiplier: float = 1.0

		if force_test_pattern:
			# Keep the test deterministic: the same pattern loops continuously,
			# independent of score-based pattern selection.
			next_pattern = test_pattern
		else:
			next_pattern = _generator_brain.choose_pattern_type()

			## Chooses the handoff based on the current and previous pattern context.
			var previous_pattern: PlatformPatterns.PatternType = \
				_generator_brain.get_previous_pattern()

			entry_mode = _generator_brain.choose_entry_mode(
				next_pattern,
				previous_pattern
			)

			## Gets the current vertical pacing from the Generator Brain.
			var density: Dictionary = _generator_brain.get_generation_density()
			density_multiplier = float(density["multiplier"])

		_pending_slots = PlatformPatterns.build(
			next_pattern,
			difficulty,
			entry_mode,
			_previous_x_fraction,
			density_multiplier
		)

	var slot: Dictionary = _pending_slots.pop_front()
	var base_width: float = float(p.get("width"))
	
	var size_name: String = str(slot.get("size", "standard"))

	var target_width: float = PLATFORM_WIDTHS.get(
		_size_name_to_enum(size_name),
		PLATFORM_WIDTHS[PlatformSize.STANDARD]
	)
	
	var width_scale: float = target_width / base_width
	if not force_test_pattern:
		width_scale = _generator_brain.scale_width_scale(width_scale)
	var half_width: float = target_width * 0.5

	# branch=true (Risk-Pattern): teilt sich die Höhe mit der zuletzt platzierten
	# Plattform, statt eine neue Stufe zu erzeugen - beide bleiben dadurch vom
	# selben Vorgänger aus erreichbar, ganz ohne separate Sonderlogik dafür.
	var is_branch: bool = bool(slot.get("branch", false))
	if not is_branch:
		var max_gap: float = _max_gap
		if bool(slot.get("boosted_gap", false)) and _last_type == Platform.PlatformType.SPRING:
			max_gap = _boosted_max_gap(p)
		var gap_fraction: float
		if force_test_pattern and test_pattern == PlatformPatterns.PatternType.FAST_PACING_TEST:
			# Exact spacing is important for reproducing the same fast charge windows.
			gap_fraction = clampf(float(slot.get("dy", 0.2)), 0.0, 1.0)
		else:
			gap_fraction = _scale_gap_fraction(float(slot.get("dy", 0.2)))
		# Egal was das Pattern für dy vorgibt: der tatsächliche Gap bleibt IMMER
		# zwischen min_gap und (ggf. boost-erweitertem) max_gap geklemmt - dieselbe
		# physik-basierte Erreichbarkeits-Grenze wie zuvor, jetzt pro Slot angewandt.
		_highest_y -= lerp(min_gap, max_gap, gap_fraction)

	var min_x: float = half_width + horizontal_margin
	var max_x: float = _viewport_size.x - half_width - horizontal_margin

	var x_fraction: float = clampf(float(slot.get("x", 0.5)), 0.0, 1.0)
	var x: float = lerpf(min_x, max_x, x_fraction)
	
	_previous_x_fraction = x_fraction

	var type: int = int(slot.get("type", PlatformPatterns.TYPE_ROLL))
	if type == PlatformPatterns.TYPE_ROLL:
		type = _generator_brain.choose_platform_type(_last_type)
	# Fairness-Garantie gilt unabhängig davon, ob der Typ gewürfelt oder vom Pattern
	# fest vorgegeben wurde, und unabhängig von Pattern-Grenzen (siehe _last_type).
	if type == Platform.PlatformType.BREAKABLE and _last_type == Platform.PlatformType.BREAKABLE:
		type = Platform.PlatformType.NORMAL

	return {
		"position": Vector2(x, _highest_y),
		"type": type,
		"width_scale": width_scale,
		"guarantee_coin": bool(slot.get("guarantee_coin", false)),
	}

## Applies the Generator Brain's current difficulty to pattern-defined vertical spacing.
func _scale_gap_fraction(base_fraction: float) -> float:
	var difficulty: float = _generator_brain.get_difficulty()

	return clampf(
		lerp(
			base_fraction,
			1.0,
			difficulty * gap_push_strength
		),
		0.0,
		1.0
	)

## Erweiterte maximale Lücke direkt nach einer Spring-Plattform: aus h = v0^2 / (2g)
## folgt, dass eine um spring_multiplier erhöhte Absprunggeschwindigkeit die
## erreichbare Höhe um spring_multiplier^2 vergrößert - dieselbe physik-basierte
## Herleitung wie bei _max_gap, nur mit dem boost-multiplizierten v0.
func _boosted_max_gap(p: Node2D) -> float:
	var mult: float = float(p.get("spring_multiplier"))
	return _max_gap * mult * mult
