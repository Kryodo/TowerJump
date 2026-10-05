shader_type canvas_item;

varying float edge_local_x;

instance uniform float platform_width = 220.0;
instance uniform float approach_charge = 0.0;
instance uniform float approach_target_x = 0.5;

void vertex() {
	edge_local_x = VERTEX.x;
}

void fragment() {
	float half_width = platform_width * 0.5;

	float x = clamp(
		(edge_local_x + half_width) / platform_width,
		0.0,
		1.0
	);

	float target = clamp(
		approach_target_x,
		0.0,
		1.0
	);

	float charge = clamp(
		approach_charge,
		0.0,
		1.0
	);

	float left_front = mix(
		0.0,
		target,
		charge
	);

	float right_front = mix(
		1.0,
		target,
		charge
	);

	// Filled energy regions moving inward from both ends.
	float left_region = 1.0 - smoothstep(
		left_front - 0.008,
		left_front + 0.008,
		x
	);

	float right_region = smoothstep(
		right_front - 0.008,
		right_front + 0.008,
		x
	);

	left_region *= charge;
	right_region *= charge;

	float active_region = clamp(
		left_region + right_region,
		0.0,
		1.0
	);

	// Bright moving fronts.
	float left_front_glow = 1.0 - smoothstep(
		0.0,
		0.030,
		abs(x - left_front)
	);

	float right_front_glow = 1.0 - smoothstep(
		0.0,
		0.030,
		abs(x - right_front)
	);

	float front_glow = max(
		left_front_glow,
		right_front_glow
	) * charge;

	// Slightly stronger glow when the two sides are almost connected.
	float convergence = smoothstep(
		0.72,
		1.0,
		charge
	);

	float active = clamp(
		active_region * 0.82 +
		front_glow * 0.28 +
		convergence * front_glow * 0.35,
		0.0,
		1.0
	);

	vec3 base_color = COLOR.rgb;

	// Same neon language, but with a brighter energized state.
	vec3 energized_color = base_color * 1.55 +
		vec3(0.0, 0.45, 0.60);

	vec3 result = mix(
		base_color,
		energized_color,
		active
	);

	// Tiny final lift at full connection.
	result += vec3(0.0, 0.18, 0.24) * convergence * active;

	COLOR.rgb = result;
}
