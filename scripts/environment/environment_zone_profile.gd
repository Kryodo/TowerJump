class_name EnvironmentZoneProfile
extends Resource
## A bounded zone definition for the two-zone Art Library V1 pipeline.

@export var zone_id: StringName
## Positive climb-distance pixels measured upward from the run origin.
@export var start_height_px: float = 0.0
@export var end_height_px: float = 0.0
@export var theme_profile: EnvironmentThemeProfile
@export var ambient_profile: EnvironmentAmbientProfile
@export var subzones: Array[EnvironmentSubzoneProfile] = []
@export var landmark_anchors: Array[EnvironmentLandmarkAnchor] = []
