shader_type canvas_item;

varying float edge_local_x;
varying float edge_local_y;

instance uniform float platform_width = 220.0;
instance uniform float platform_height = 20.0;
instance uniform float edge_height = 8.0;
instance uniform float approach_charge = 0.0;
instance uniform float approach_target_x = 0.5;
instance uniform float landing_confirm = 0.0;
instance uniform float activated = 0.0;

void vertex() {
	edge_local_x = VERTEX.x;
	edge_local_y = VERTEX.y;
}

void fragment() {
	float half_width = platform_width * 0.5;
	float x = clamp((edge_local_x + half_width) / platform_width, 0.0, 1.0);
	float y = clamp(
		(edge_local_y + platform_height * 0.5) / max(edge_height, 0.001),
		0.0,
		1.0
	);

	// The script supplies the already-constrained predicted landing point.
	// Keep the shader permissive so it does not secretly re-center the target.
	float target = clamp(approach_target_x, 0.02, 0.98);
	float charge = clamp(approach_charge, 0.0, 1.0);
	float active = clamp(activated, 0.0, 1.0);

	vec3 neutral_color = vec3(0.50, 0.19, 0.98);
	vec3 active_color = vec3(0.10, 2.15, 3.20);
	vec3 active_core = vec3(0.45, 3.15, 4.20);
	vec3 confirm_color = vec3(4.20, 4.20, 4.20);

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

	// Material reflection: a clear, narrow top glint plus a softer inner
	// sheen. Keep the highlight palette-matched, but strong enough to read at
	// the edge's 8 px height without becoming a second outline.
	float upper_glint = 1.0 - smoothstep(0.0, 0.30, y);
	float inner_sheen = exp(-pow((y - 0.42) / 0.23, 2.0));
	float cyan_state = max(fill, active);
	vec3 purple_reflection = vec3(0.88, 0.64, 1.38);
	vec3 cyan_reflection = vec3(0.72, 2.95, 3.82);
	vec3 reflection_color = mix(purple_reflection, cyan_reflection, cyan_state);
	float reflection_strength = clamp(upper_glint * 0.42 + inner_sheen * 0.20, 0.0, 0.52);
	result = mix(result, reflection_color, reflection_strength);

	// Completion flash is applied AFTER the reflection so its white connection
	// moment remains unchanged, then settles back to the active cyan.
	float confirm = clamp(landing_confirm, 0.0, 1.0);
	result = mix(result, confirm_color, confirm);

	COLOR.rgb = result;
}
