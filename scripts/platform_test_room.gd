extends Node2D
## Isolierte Test-Szene zum Kalibrieren von Plattform-Breiten und vertikalen/
## horizontalen Abständen, UNABHÄNGIG von PlatformSpawner/PlatformPatterns.
##
## Statt Pattern-Slots relativ zur Spawn-Breite (wie platform_spawner.gd) zu
## würfeln, definiert jede _section_N()-Funktion unten eine feste, exakte
## Sequenz von Plattformen. dx/dy sind reine PIXELWERTE (kein Bruchteil wie bei
## PlatformPatterns!), damit sich einzelne Übergänge direkt und vorhersagbar
## nachjustieren lassen. Um eine Section zu verändern, genügt es, die
## betreffende _section_N()-Funktion zu editieren - _ready() (die eigentliche
## Spawn-Logik) bleibt unangetastet.

const Platform := preload("res://scripts/platform.gd")

@export var platform_scene: PackedScene
@export var ball_path: NodePath

## --- Breiten-Vokabular (px) ---
const WIDTH_TINY: float = 100.0
const WIDTH_SMALL: float = 140.0
const WIDTH_STANDARD: float = 190.0
const WIDTH_WIDE: float = 260.0
const WIDTH_LARGE: float = 320.0
const WIDTH_ENDLESS: float = 2000.0 ## Sichere Lande-Plattform nach der letzten Section

const PLATFORM_HEIGHT: float = 30.0

## Referenzbreite für die width_scale-Umrechnung (siehe platform.gd):
## Platform.width wird immer auf WIDTH_STANDARD gesetzt, width_scale wird pro
## Plattform aus gewünschte_breite_px / BASE_WIDTH berechnet.
const BASE_WIDTH: float = WIDTH_STANDARD

const START_Y_OFFSET: float = 150.0 ## Abstand der ersten Plattform unter dem Ball-Start
const FINAL_GAP: float = 220.0      ## Abstand der Endlos-Plattform zur letzten Test-Plattform

@onready var _ball: CharacterBody2D = get_node(ball_path)

func _ready() -> void:
	var sequence: Array[Dictionary] = _build_sequence()
	var cursor := Vector2(_ball.global_position.x, _ball.global_position.y + START_Y_OFFSET)

	for i in sequence.size():
		var spec: Dictionary = sequence[i]
		if i > 0:
			cursor.x += float(spec.dx)
			cursor.y -= float(spec.dy)
		_spawn_platform(spec.type, cursor, float(spec.width))

	# Endlos-Plattform zum sicheren Landen - kein Game-Over-Trigger in dieser Szene.
	cursor.y -= FINAL_GAP
	_spawn_platform(Platform.PlatformType.NORMAL, cursor, WIDTH_ENDLESS)

## Reiht die fünf Test-Sections lückenlos aneinander - jede startet exakt dort,
## wo die vorherige endet (siehe Klassenkommentar oben).
func _build_sequence() -> Array[Dictionary]:
	var sequence: Array[Dictionary] = []
	sequence.append_array(_section_1_comfortable_intro())
	sequence.append_array(_section_2_narrower_landing())
	sequence.append_array(_section_3_movement())
	sequence.append_array(_section_4_breaking_recovery())
	sequence.append_array(_section_5_precision())
	return sequence

## SECTION 1 - Comfortable Introduction: Wide -> Standard -> Wide.
## dy 160-180 (pro Übergang leicht variiert), dx 150px abwechselnd links/rechts.
func _section_1_comfortable_intro() -> Array[Dictionary]:
	return [
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_WIDE, "dy": 0.0, "dx": 0.0}, # Start, direkt unter dem Ball
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_STANDARD, "dy": 170.0, "dx": 150.0},
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_WIDE, "dy": 160.0, "dx": -150.0},
	]

## SECTION 2 - Narrower Landing: Standard -> Small -> Standard.
## dy 190-220, dx 200px abwechselnd.
func _section_2_narrower_landing() -> Array[Dictionary]:
	return [
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_STANDARD, "dy": 200.0, "dx": 200.0},
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_SMALL, "dy": 210.0, "dx": -200.0},
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_STANDARD, "dy": 220.0, "dx": 200.0},
	]

## SECTION 3 - Movement: Small -> Moving -> Standard.
## dy 200-240, dx 180px. Die Moving-Plattform (150-170px) nutzt die bestehende
## sin()-Oszillation aus platform.gd (move_radius/move_speed) unverändert.
func _section_3_movement() -> Array[Dictionary]:
	return [
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_SMALL, "dy": 200.0, "dx": -180.0},
		{"type": Platform.PlatformType.MOVING, "width": 160.0, "dy": 220.0, "dx": 180.0},
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_STANDARD, "dy": 240.0, "dx": -180.0},
	]

## SECTION 4 - Breaking/Recovery: Breaking -> Standard -> Wide.
## dy 180-220, dx 170px. Die Breaking-Plattform (140-170px) bricht nach der
## Landung über die bestehende Logik in platform.gd (on_ball_landed) weg.
func _section_4_breaking_recovery() -> Array[Dictionary]:
	return [
		{"type": Platform.PlatformType.BREAKABLE, "width": 155.0, "dy": 180.0, "dx": 170.0},
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_STANDARD, "dy": 200.0, "dx": -170.0},
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_WIDE, "dy": 220.0, "dx": 170.0},
	]

## SECTION 5 - Precision: Small -> Small -> Wide.
## dy 240-280, dx 250px. Die letzte Wide-Plattform ist bewusst als
## "Erleichterung nach Herausforderung" gedacht.
func _section_5_precision() -> Array[Dictionary]:
	return [
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_SMALL, "dy": 240.0, "dx": -250.0},
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_SMALL, "dy": 260.0, "dx": 250.0},
		{"type": Platform.PlatformType.NORMAL, "width": WIDTH_WIDE, "dy": 280.0, "dx": -250.0},
	]

## Instanziert (kein Pooling - diese Szene ist ein einmaliger, kurzer Testlauf)
## eine Plattform an `pos` mit exakt `width_px` sichtbarer Breite und
## PLATFORM_HEIGHT Höhe, umgerechnet über die bestehende width_scale-Mechanik.
func _spawn_platform(type: int, pos: Vector2, width_px: float) -> void:
	var p := platform_scene.instantiate() as Node2D
	add_child(p)
	p.set("width", BASE_WIDTH)
	p.set("height", PLATFORM_HEIGHT)
	p.call("spawn_as", type, pos, width_px / BASE_WIDTH)
