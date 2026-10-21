shader_type canvas_item;

varying float edge_local_x;

instance uniform float platform_width = 220.0;
instance uniform float approach_charge = 0.0;
instance uniform float approach_target_x = 0.5;
instance uniform float landing_confirm = 0.0;
instance uniform float activated = 0.0;
instance uniform float idle_sheen_progress = -1.0;
instance uniform vec4 palette_idle_color : source_color = vec4(0.735, 0.472, 0.991, 1.0);
instance uniform vec4 palette_charge_color : source_color = vec4(0.19, 0.84, 1.0, 1.0);
instance uniform vec4 palette_charge_core_color : source_color = vec4(0.36, 0.88, 1.0, 1.0);
instance uniform vec4 palette_confirmation_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	edge_local_x = VERTEX.x;
}

void fragment() {
	float half_width = platform_width * 0.5;
	float x = clamp((edge_local_x + half_width) / platform_width, 0.0, 1.0);
	// The script supplies the already-constrained predicted landing point.
	// Keep the shader permissive so it does not secretly re-center the target.
	float target = clamp(approach_target_x, 0.02, 0.98);
	float charge = clamp(approach_charge, 0.0, 1.0);
	float active = clamp(activated, 0.0, 1.0);

	// Palette colors are authored as sRGB color values and converted by the
	// source_color hint. Separate emission gains preserve the original HDR feel.
	vec3 neutral_color = palette_idle_color.rgb;
	vec3 active_color = palette_charge_color.rgb * 3.2;
	vec3 active_core = palette_charge_core_color.rgb * 4.2;
	vec3 confirm_color = palette_confirmation_color.rgb * 4.2;

	// The charge is a continuous bilateral loading bar. Both sides always
	// start at the physical ends of the platform and advance toward the
	// predicted landing point. No separate dots or chunks are introduced.
	float left_front = target * charge;
	float right_front = target + (1.0 - target) * (1.0 - charge);

	// Slightly softer fronts on smaller platforms keep the progression
	// readable without making the effect look segmented.
	float front_width = mix(0.024, 0.016, clamp(platform_width / 320.0, 0.0, 1.0));
	float left_fill = 1.0 - smoothstep(left_front - front_width, left_front + front_width, x);
	float right_fill = smoothstep(right_front - front_width, right_front + front_width, x);
	float fill = max(left_fill, right_fill) * charge;

	vec3 result = mix(neutral_color, active_color, fill);

	// A restrained bright core rides the two advancing fronts so the charge
	// reads as active energy rather than a flat color wipe.
	float left_core = 1.0 - smoothstep(front_width * 0.35, front_width * 1.25, abs(x - left_front));
	float right_core = 1.0 - smoothstep(front_width * 0.35, front_width * 1.25, abs(x - right_front));
	float core = max(left_core, right_core) * charge;
	result = mix(result, active_core, core);

	// Once the platform has been landed on, it remains in its awake cyan
	// state. The approach animation itself never needs to know the landing
	// quality; confirmation is a separate layer.
	result = mix(result, active_color, active);

	// Completion flash is applied AFTER the activated state so it remains
	// visible as a true white connection moment, then settles back to cyan.
	float confirm = clamp(landing_confirm, 0.0, 1.0);
	result = mix(result, confirm_color, confirm);

	// Rare, one-shot mirror flash. A sparse subset of platforms is selected by
	// the platform script, which drives progress from 0 to 1 exactly once.
	// A negative value means no sheen is active.
	float idle_gate = (1.0 - charge) * (1.0 - active) * (1.0 - confirm);
	float sheen_active = step(0.0, idle_sheen_progress) * (1.0 - step(1.0, idle_sheen_progress));
	float sheen_progress = clamp(idle_sheen_progress, 0.0, 1.0);
	float sheen_position = mix(-0.10, 1.10, sheen_progress);
	float sheen_distance = abs(x - sheen_position);
	float sheen_field = 1.0 - smoothstep(0.028, 0.095, sheen_distance);
	float sheen_core = 1.0 - smoothstep(0.003, 0.020, sheen_distance);
	float sheen_mix = (sheen_field * 0.08 + sheen_core * 0.62) * idle_gate * sheen_active;
	vec3 sheen_color = mix(active_color, confirm_color, 0.62);
	result = mix(result, sheen_color, clamp(sheen_mix, 0.0, 0.52));

	COLOR.rgb = result;
}
