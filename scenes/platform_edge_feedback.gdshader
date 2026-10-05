shader_type canvas_item;

varying float edge_local_x;

instance uniform float platform_width = 220.0;
instance uniform float approach_charge = 0.0;
instance uniform float approach_target_x = 0.5;
instance uniform float landing_confirm = 0.0;

void vertex() {
	edge_local_x = VERTEX.x;
}

void fragment() {
	float half_width = platform_width * 0.5;
	float x = clamp((edge_local_x + half_width) / platform_width, 0.0, 1.0);
	float target = clamp(approach_target_x, 0.0, 1.0);
	float charge = clamp(approach_charge, 0.0, 1.0);

	// The passive platform stays visibly neon, but the active state has
	// enough contrast to read as a deliberate "wake up" response.
	vec3 base_color = COLOR.rgb;
	vec3 active_color = vec3(0.35, 1.9, 2.7);
	vec3 core_color = vec3(0.72, 3.2, 4.0);

	// Two fronts travel inward from the ends toward the predicted landing point.
	float left_front = mix(0.0, target, charge);
	float right_front = mix(1.0, target, charge);

	float left_halo = (1.0 - smoothstep(0.0, 0.055, abs(x - left_front))) * charge;
	float right_halo = (1.0 - smoothstep(0.0, 0.055, abs(x - right_front))) * charge;
	float halo = max(left_halo, right_halo);

	float left_core = (1.0 - smoothstep(0.0, 0.014, abs(x - left_front))) * charge;
	float right_core = (1.0 - smoothstep(0.0, 0.014, abs(x - right_front))) * charge;
	float core = max(left_core, right_core);

	vec3 result = mix(base_color, active_color, halo * 0.82);
	result = mix(result, core_color, core);

	// A little extra intensity as the two fronts approach their meeting point.
	float convergence = smoothstep(0.78, 1.0, charge);
	result += core_color * convergence * 0.18 * charge;

	// Brief confirmation peak on landing.
	float confirm = clamp(landing_confirm, 0.0, 1.0);
	result += vec3(0.85, 3.6, 4.5) * confirm * confirm;

	COLOR.rgb = result;
}
