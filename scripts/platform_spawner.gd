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
const ForwardAssemblyPulseVisualScript := preload(
	"res://scripts/forward_assembly_pulse_visual.gd"
)
## PlatformPatterns ist über class_name (platform_patterns.gd) bereits global verfügbar.

## Feuert bei jeder (Neu-)Platzierung einer Plattform - sowohl beim initialen
## Befüllen des Pools als auch bei jedem Recycling. Der CoinSpawner hört darauf,
## um Coins in der Nähe neu generierter Plattformen zu platzieren. guarantee_coin
## kommt aus dem Pattern (z.B. Risk-Pattern-Bonus) und umgeht dort die normale
## Zufalls-Chance des CoinSpawners.
signal platform_placed(position: Vector2, half_width: float, guarantee_coin: bool, platform: Node2D)
## Reusable event stream for future traps, collectibles, and environment structures.
signal construction_pulse_advanced(
	position: Vector2,
	direction: Vector2,
	speed: float,
	frontier_platform: Node2D
)
signal assembly_frontier_reached(platform: Node2D)

@export var platform_scene: PackedScene
@export var pool_size: int = 14
@export var ball_path: NodePath
@export var camera_path: NodePath

@export_group("Forward Assembly Prototype")
## The smallest lead distance at low vertical speed.
@export_range(120.0, 320.0, 10.0) var assembly_min_lookahead_distance: float = 190.0
## Adaptive cap for spring-assisted and future high-speed movement.
@export_range(400.0, 1200.0, 25.0) var assembly_max_lookahead_distance: float = 900.0
## Includes surface materialization time plus a small steering/decision buffer.
@export_range(0.30, 1.20, 0.05) var assembly_required_lead_time_seconds: float = 0.66
## Pulse moves slightly faster than the ball so the reveal gets a readable lead.
@export_range(200.0, 1200.0, 50.0) var assembly_pulse_speed_bonus: float = 800.0
## Platforms sharing a height (route branches) assemble as one wave.
@export_range(0.0, 20.0, 1.0) var assembly_frontier_height_tolerance: float = 8.0
@export_range(0.0, 0.20, 0.01) var assembly_stagger: float = 0.055

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
var _ball: CharacterBody2D
var _camera: Camera2D
var _viewport_size: Vector2
var _highest_y: float = 0.0 ## y-Position der bisher höchsten (kleinster y-Wert) generierten Plattform
var _max_gap: float
var _last_type: int = Platform.PlatformType.NORMAL ## Typ (Platform.PlatformType) der zuletzt (in aufsteigender Höhen-Reihenfolge) platzierten Plattform
var _cursor_x: float = 0.0 ## x-Position der zuletzt platzierten Plattform (Bezugspunkt für dx der Patterns)
var _pending_slots: Array[Dictionary] = [] ## Noch nicht materialisierte Slots des aktuellen Patterns
var _previous_x_fraction: float = 0.5 ## This stores the normalized horizontal position of the last actually placed platform
var _generator_brain: PlatformGeneratorBrain
var _pulse_visual: Node2D = null
var _pulse_world_position: Vector2 = Vector2.ZERO
var _pulse_has_world_position: bool = false
var _has_started_construction: bool = false
var _current_lookahead_distance: float = 190.0
var _last_pulse_direction: Vector2 = Vector2.UP
var _last_pulse_speed: float = 0.0

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
	_ball = get_node(ball_path) as CharacterBody2D
	_camera = get_node(camera_path) as Camera2D
	
	# Erreichbarkeits-Berechnung: aus der Wurfparabel des Balls (v0 = jump_velocity,
	# a = gravity) folgt die maximal erreichbare Sprunghöhe h = v0^2 / (2 * g).
	# gap_safety_factor lässt etwas Puffer, damit Lücken bei ungünstigem Timing
	# trotzdem sicher schaffbar bleiben. Gilt für JEDE Plattform-zu-Plattform-Distanz,
	# unabhängig davon, welches Pattern sie erzeugt hat (siehe _next_platform_spec()).
	var max_jump_height: float = (_ball.jump_velocity ** 2) / (2.0 * _ball.gravity)
	_max_gap = maxf(max_jump_height * gap_safety_factor, min_gap + 40.0)

	_highest_y = _ball.global_position.y + 120.0
	_cursor_x = _ball.global_position.x

	for i in pool_size:
		var p := platform_scene.instantiate() as Node2D
		add_child(p)
		_platforms.append(p)

		var pos: Vector2
		var type: int
		var width_scale: float
		var guarantee_coin: bool
		var start_assembled: bool = false
		if i == 0:
			# Erste Plattform direkt unter dem Ball-Start (nicht Viewport-Mitte!): Bei
			# stretch/mode="canvas_items" + aspect="expand" kann die tatsächliche
			# Viewport-Breite je nach Fenster-/Bildschirmseitenverhältnis vom Design-Wert
			# abweichen, wodurch die Plattform sonst seitlich am Ball vorbei landen kann.
			# Außerdem immer NORMAL und extra breit, damit der Spielstart garantiert fair
			# ist. Verbraucht keinen Pattern-Slot.
			pos = Vector2(_ball.global_position.x, _highest_y)
			type = Platform.PlatformType.NORMAL
			width_scale = max_width_scale
			guarantee_coin = false
			start_assembled = true
		else:
			var spec := _next_platform_spec(p)
			pos = spec.position
			type = spec.type
			width_scale = spec.width_scale
			guarantee_coin = spec.guarantee_coin
		_last_type = type
		_cursor_x = pos.x
		p.call("spawn_as", type, pos, width_scale, start_assembled)
		platform_placed.emit(pos, p.call("half_width"), guarantee_coin, p)

	_current_lookahead_distance = assembly_min_lookahead_distance
	_pulse_visual = Node2D.new()
	_pulse_visual.name = "ForwardAssemblyPulseVisual"
	_pulse_visual.set_script(ForwardAssemblyPulseVisualScript)
	_pulse_visual.position = Vector2.ZERO
	_pulse_visual.z_as_relative = false
	_pulse_visual.z_index = 5
	add_child(_pulse_visual)

## Updates generator context, recycles platforms, and advances the visual construction frontier.
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
			platform_placed.emit(spec.position, p.call("half_width"), spec.guarantee_coin, p)

	# Assembly is updated after recycling so newly reused platforms participate
	# in the same frame's distance check, but remain hidden if they are far ahead.
	_update_forward_assembly(delta)


## The pulse is a real moving frontier, not a landing-triggered reveal batch.
## It traces a route between the nearest previous and next platform rows. A row
## begins materializing only when the pulse reaches it; later rows remain blocked
## by the nearest row, whether that row is already assembled or not.
func _update_forward_assembly(delta: float) -> void:
	if _ball == null or not is_instance_valid(_ball):
		return
	if _pulse_visual == null or not is_instance_valid(_pulse_visual):
		return

	if not _pulse_has_world_position:
		_pulse_world_position = _ball.global_position
		_pulse_has_world_position = true

	# No pulse is shown during the initial fall. After the first ascent, it
	# softly idles at its last frontier during descents and resumes on the next jump.
	if _ball.velocity.y >= -1.0:
		var idle_intensity: float = 0.22 if _has_started_construction else 0.0
		_pulse_visual.call(
			"set_pulse_state",
			to_local(_pulse_world_position),
			idle_intensity,
			false
		)
		return

	_has_started_construction = true
	var vertical_speed: float = absf(_ball.velocity.y)
	var frontier_platform: Node2D = _find_nearest_future_platform()
	if frontier_platform == null:
		_pulse_visual.call(
			"set_pulse_state",
			to_local(_pulse_world_position),
			0.18,
			false
		)
		return

	# Adapt the visible lead to actual vertical speed and the target's animation
	# duration. The cap is spatially bounded, and the nearest row remains the only
	# eligible reveal target, so increased speed does not expose the whole tower.
	var target_animation_time: float = maxf(
		float(frontier_platform.get("assembly_duration")),
		0.05
	)
	var required_lead_time: float = maxf(
		assembly_required_lead_time_seconds,
		target_animation_time
	)
	var desired_lookahead: float = clampf(
		vertical_speed * required_lead_time,
		assembly_min_lookahead_distance,
		assembly_max_lookahead_distance
	)
	_current_lookahead_distance = move_toward(
		_current_lookahead_distance,
		desired_lookahead,
		1800.0 * delta
	)

	var distance_ahead: float = (
		_ball.global_position.y - frontier_platform.global_position.y
	)
	var desired_pulse_y: float = maxf(
		frontier_platform.global_position.y,
		_ball.global_position.y - _current_lookahead_distance
	)
	var source_platform: Node2D = _find_nearest_source_platform()
	var desired_pulse_x: float = _get_route_pulse_x(
		source_platform,
		frontier_platform,
		desired_pulse_y
	)
	var desired_pulse_position := Vector2(desired_pulse_x, desired_pulse_y)
	var contact_position: Vector2 = _get_frontier_contact_position(
		source_platform,
		frontier_platform
	)

	var previous_pulse_position: Vector2 = _pulse_world_position
	var pulse_speed: float = vertical_speed + assembly_pulse_speed_bonus
	_pulse_world_position = _pulse_world_position.move_toward(
		desired_pulse_position,
		maxf(pulse_speed, 400.0) * delta
	)

	var pulse_delta: Vector2 = _pulse_world_position - previous_pulse_position
	if pulse_delta.length_squared() > 0.001:
		_last_pulse_direction = pulse_delta.normalized()
		_last_pulse_speed = pulse_delta.length() / maxf(delta, 0.0001)
	else:
		_last_pulse_speed = 0.0

	_pulse_visual.call(
		"set_pulse_state",
		to_local(_pulse_world_position),
		1.0,
		_last_pulse_speed > 1.0
	)
	construction_pulse_advanced.emit(
		_pulse_world_position,
		_last_pulse_direction,
		_last_pulse_speed,
		frontier_platform
	)

	# The pulse is the reveal trigger. Do not start the animation just because a
	# distance threshold was crossed; it must actually reach the frontier row.
	if (
		distance_ahead <= _current_lookahead_distance
		and _pulse_world_position.distance_to(contact_position) <= 24.0
	):
		_begin_frontier_row(frontier_platform)


func _find_nearest_future_platform() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for platform in _platforms:
		if (
			platform == null
			or not is_instance_valid(platform)
			or not platform.visible
			or not platform.has_method("is_assembly_pending")
		):
			continue
		var distance_ahead: float = _ball.global_position.y - platform.global_position.y
		if distance_ahead <= 1.0:
			continue
		if (
			distance_ahead < nearest_distance - 0.5
			or (
				absf(distance_ahead - nearest_distance) <= assembly_frontier_height_tolerance
				and (
					nearest == null
					or absf(platform.global_position.x - _ball.global_position.x)
						< absf(nearest.global_position.x - _ball.global_position.x)
				)
			)
		):
			nearest_distance = distance_ahead
			nearest = platform
	return nearest


func _find_nearest_source_platform() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for platform in _platforms:
		if (
			platform == null
			or not is_instance_valid(platform)
			or not platform.visible
			or not platform.has_method("half_width")
		):
			continue
		var distance_below: float = platform.global_position.y - _ball.global_position.y
		if distance_below < -1.0:
			continue
		if distance_below < nearest_distance:
			nearest_distance = distance_below
			nearest = platform
	return nearest


func _get_route_pulse_x(
	source_platform: Node2D,
	target_platform: Node2D,
	pulse_y: float
) -> float:
	if (
		source_platform == null
		or not is_instance_valid(source_platform)
		or target_platform == null
		or not is_instance_valid(target_platform)
	):
		return _ball.global_position.x

	var source_y: float = source_platform.global_position.y
	var target_y: float = target_platform.global_position.y
	var vertical_span: float = source_y - target_y
	if vertical_span <= 1.0:
		return target_platform.global_position.x

	# Smoothly trace the horizontal route between platform centers. The lateral
	# easing follows the actual pattern's geometry without adding a separate
	# bespoke path for every pattern type.
	var progress: float = clampf(
		(source_y - pulse_y) / vertical_span,
		0.0,
		1.0
	)
	var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
	var source_x: float = source_platform.global_position.x
	var target_center_x: float = target_platform.global_position.x
	var horizontal_delta: float = target_center_x - source_x
	var target_x: float = target_center_x
	var lateral_threshold: float = maxf(_viewport_size.x * 0.08, 24.0)
	if absf(horizontal_delta) >= lateral_threshold:
		# The travelling dot strikes the entering edge, where the platform's
		# left-to-right/right-to-left material boundary begins.
		target_x -= signf(horizontal_delta) * float(target_platform.call("half_width"))
	var curve_offset: float = sin(progress * PI) * clampf(
		(target_x - source_x) * 0.08,
		-26.0,
		26.0
	)
	return lerpf(source_x, target_x, eased_progress) + curve_offset


func _get_frontier_contact_position(
	source_platform: Node2D,
	target_platform: Node2D
) -> Vector2:
	var contact_x: float = target_platform.global_position.x
	if source_platform != null and is_instance_valid(source_platform):
		var horizontal_delta: float = (
			target_platform.global_position.x - source_platform.global_position.x
		)
		var lateral_threshold: float = maxf(_viewport_size.x * 0.08, 24.0)
		if absf(horizontal_delta) >= lateral_threshold:
			contact_x -= signf(horizontal_delta) * float(target_platform.call("half_width"))
	return Vector2(contact_x, target_platform.global_position.y)


func _begin_frontier_row(frontier_platform: Node2D) -> void:
	if frontier_platform == null or not is_instance_valid(frontier_platform):
		return

	var frontier_y: float = frontier_platform.global_position.y
	var frontier_group: Array[Node2D] = []
	for platform in _platforms:
		if (
			platform == null
			or not is_instance_valid(platform)
			or not platform.visible
			or not platform.has_method("is_assembly_pending")
		):
			continue
		if absf(platform.global_position.y - frontier_y) > assembly_frontier_height_tolerance:
			continue
		if bool(platform.call("is_assembly_pending")):
			frontier_group.append(platform)

	# A branching route reveals as one coherent event. Sorting makes the small
	# stagger deterministic and independent of pool order.
	frontier_group.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			return a.global_position.x < b.global_position.x
	)
	var source_platform: Node2D = _find_nearest_source_platform()
	for index in range(frontier_group.size()):
		var platform: Node2D = frontier_group[index]
		var direction_override: int = _choose_assembly_direction(
			source_platform,
			platform,
			index
		)
		platform.call(
			"begin_assembly",
			maxf(assembly_stagger, 0.0) * float(index),
			direction_override
		)
		assembly_frontier_reached.emit(platform)


func _choose_assembly_direction(
	source_platform: Node2D,
	target_platform: Node2D,
	branch_index: int
) -> int:
	if (
		source_platform == null
		or not is_instance_valid(source_platform)
		or target_platform == null
		or not is_instance_valid(target_platform)
	):
		return -1

	var horizontal_delta: float = (
		target_platform.global_position.x - source_platform.global_position.x
	)
	var lateral_threshold: float = maxf(_viewport_size.x * 0.08, 24.0)
	if absf(horizontal_delta) >= lateral_threshold:
		return 0 if horizontal_delta > 0.0 else 1

	# Near-vertical progressions use a center-out condensation so the pulse
	# can strike the center, where this reveal style naturally starts.
	return 3


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

		var next_pattern: PlatformPatterns.PatternType = \
			_generator_brain.choose_pattern_type()

		## Chooses the handoff based on the current and previous pattern context.
		var previous_pattern: PlatformPatterns.PatternType = \
			_generator_brain.get_previous_pattern()

		var entry_mode: PlatformPatterns.EntryMode = \
			_generator_brain.choose_entry_mode(
				next_pattern,
				previous_pattern
			)
			
		## Gets the current vertical generation pacing from the Generator Brain.
		var density: Dictionary = _generator_brain.get_generation_density()	
		
		_pending_slots = PlatformPatterns.build(
			next_pattern,
			difficulty,
			entry_mode,
			_previous_x_fraction,
			float(density["multiplier"])
		)

	var slot: Dictionary = _pending_slots.pop_front()
	var base_width: float = float(p.get("width"))
	
	var size_name: String = str(slot.get("size", "standard"))

	var target_width: float = PLATFORM_WIDTHS.get(
		_size_name_to_enum(size_name),
		PLATFORM_WIDTHS[PlatformSize.STANDARD]
	)
	
	var width_scale: float = target_width / base_width
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
		var gap_fraction: float = _scale_gap_fraction(float(slot.get("dy", 0.2)))
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
