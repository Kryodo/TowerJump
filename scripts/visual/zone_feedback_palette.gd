extends Resource
class_name ZoneFeedbackPalette
## Semantic color roles for a zone. Cosmetic orb/trail materials may vary,
## but gameplay feedback reads these shared roles so quality meaning remains consistent.

@export_group("Platform State")
@export var idle_edge_color: Color = Color(0.50, 0.19, 0.98, 1.0)
@export var charge_edge_color: Color = Color(0.10, 2.15, 3.20, 1.0)
@export var charge_core_color: Color = Color(0.45, 3.15, 4.20, 1.0)
@export var confirmation_color: Color = Color(4.20, 4.20, 4.20, 1.0)

@export_group("Landing Quality")
## Bright periwinkle/lavender, related to idle violet but brighter and bluer.
@export var good_color: Color = Color(0.68, 0.54, 1.0, 1.0)
## Cyan/teal derived from the zone's charge/active energy role.
@export var epic_color: Color = Color(0.16, 0.83, 1.0, 1.0)
## Brilliant white-cyan derived from the landing connection highlight.
@export var perfect_color: Color = Color(0.84, 0.98, 1.0, 1.0)

@export_group("Secondary Feedback")
@export var reward_detail_color: Color = Color(0.84, 0.90, 0.96, 0.92)


func quality_color(quality: String) -> Color:
	match quality:
		"PERFECT":
			return perfect_color
		"EPIC":
			return epic_color
		_:
			return good_color
