class_name EnvironmentSubzoneProfile
extends Resource
## A height-bounded section within a zone.
## Heights are positive climb-distance pixels measured upward from the run origin.

@export var subzone_id: StringName
@export var start_height_px: float = 0.0
@export var end_height_px: float = 0.0
@export var architecture_recipe: EnvironmentArchitectureRecipe
## Null values inherit the corresponding zone-level profile.
@export var theme_profile: EnvironmentThemeProfile
@export var ambient_profile: EnvironmentAmbientProfile
## Stable identity used for section-local deterministic seed derivation.
@export var seed_key: StringName
