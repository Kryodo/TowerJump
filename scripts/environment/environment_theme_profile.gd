class_name EnvironmentThemeProfile
extends Resource
## Palette and structural-light treatment, kept separate from module geometry.
## The global navy void remains a world-level setting, not a per-theme background.

@export var profile_id: StringName

@export_group("Architectural fills")
@export var far_fill_a: Color = Color(0.004, 0.012, 0.026, 0.98)
@export var far_fill_b: Color = Color(0.006, 0.016, 0.032, 0.98)
@export var middle_fill: Color = Color(0.011, 0.024, 0.044, 0.96)
@export var near_detail: Color = Color(0.018, 0.13, 0.18, 0.20)

@export_group("Accents")
@export var accent_primary: Color = Color(0.012, 0.82, 1.15, 0.84)
@export var accent_secondary: Color = Color(0.42, 0.16, 0.88, 0.78)

@export_group("Structural light states")
@export var light_dormant: Color = Color(0.003, 0.004, 0.011, 0.98)
@export var light_subtle: Color = Color(0.085, 0.048, 0.142, 0.84)
@export var light_neon: Color = Color(0.36, 0.18, 0.54, 0.76)
