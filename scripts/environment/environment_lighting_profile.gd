class_name EnvironmentLightingProfile
extends Resource
## Controlled distribution and optional restrained temporal behavior for structural lights.

enum LightState {
	DORMANT,
	SUBTLE,
	NEON,
}

@export var profile_id: StringName
@export_range(0.0, 1.0, 0.01) var dormant_share: float = 0.70
@export_range(0.0, 1.0, 0.01) var subtle_share: float = 0.25
@export_range(0.0, 1.0, 0.01) var neon_share: float = 0.05
@export_range(0.0, 2.0, 0.05) var intensity_scale: float = 1.0

## Off by default: static light states are the intended production baseline.
@export var flicker_enabled: bool = false
@export_range(0.1, 8.0, 0.1) var flicker_rate_hz: float = 1.2
@export_range(0.75, 1.0, 0.01) var flicker_minimum_alpha: float = 0.94


func state_for_seed(seed_value: int) -> LightState:
	var total := maxf(dormant_share + subtle_share + neon_share, 0.001)
	var bucket := float(posmod(seed_value, 10000)) / 10000.0 * total
	if bucket < dormant_share:
		return LightState.DORMANT
	if bucket < dormant_share + subtle_share:
		return LightState.SUBTLE
	return LightState.NEON


func color_for_state(theme: EnvironmentThemeProfile, state: LightState) -> Color:
	if theme == null:
		return Color(0.003, 0.004, 0.011, 0.98)
	var result: Color
	match state:
		LightState.SUBTLE:
			result = theme.light_subtle
		LightState.NEON:
			result = theme.light_neon
		_:
			result = theme.light_dormant
	result.r *= intensity_scale
	result.g *= intensity_scale
	result.b *= intensity_scale
	return result
