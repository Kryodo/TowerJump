class_name EnvironmentAmbientProfile
extends Resource
## Ambient mote treatment, separate from architecture geometry and palette.

@export var profile_id: StringName
@export var mote_tint: Color = Color(0.62, 0.92, 1.0, 1.0)
@export_range(0.0, 3.0, 0.05) var density_scale: float = 1.0

## Approved architecture-matched depth relationship.
@export_range(0.0, 1.0, 0.01) var far_parallax: float = 0.18
@export_range(0.0, 1.0, 0.01) var middle_parallax: float = 0.46
@export_range(0.0, 1.0, 0.01) var near_parallax: float = 0.82
