class_name EnvironmentLandmarkAnchor
extends Resource
## Deliberately authored landmark placement and reserved composition space.

@export var landmark_id: StringName
@export var subzone_id: StringName
@export var scene: PackedScene
## Positive climb-distance pixels measured upward from the run origin.
@export var height_anchor_px: float = 0.0
## Landmark-local reservation rectangle relative to the scene root.
## Its transformed bounds reserve both horizontal clearance and vertical space.
@export var clearance_bounds: Rect2 = Rect2()
## Optional theme override; null inherits the owning subzone/zone theme.
@export var theme_override: EnvironmentThemeProfile
## Stable seed key for surrounding procedural composition.
@export var seed_key: StringName
