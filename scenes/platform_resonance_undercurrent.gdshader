shader_type canvas_item;
render_mode unshaded, blend_add;

// Diffuse undercurrent: a noisy flowing field with broken filaments and brief
// luminous accents. The intensity is deliberately strong enough to read during
// normal play, while the noise field keeps it from resolving into hard ribbons.
uniform vec2 field_size = vec2(392.0, 200.0);
uniform float platform_half_width = 110.0;
uniform float platform_half_height = 10.0;
uniform float phase_offset = 0.0;
uniform float approach_charge = 0.0;
uniform float landing_age = -1.0;
uniform float landing_strength = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	value += noise(p) * amplitude;
	p *= 2.03;
	amplitude *= 0.5;
	value += noise(p) * amplitude;
	p *= 2.01;
	amplitude *= 0.5;
	value += noise(p) * amplitude;
	p *= 2.02;
	amplitude *= 0.5;
	value += noise(p) * amplitude;
	return value;
}

void fragment() {
	vec2 local_px = (UV - vec2(0.5)) * field_size;
	float time = TIME;
	float below = local_px.y - platform_half_height;

	// The field lives under the platform and fades on both axes. It is wider
	// and softer than the filament accents, but doesn't fill all nearby space.
	float vertical_gate = smoothstep(2.0, 12.0, below)
		* (1.0 - smoothstep(66.0, 90.0, below));
	float horizontal_gate = 1.0 - smoothstep(
		platform_half_width + 18.0,
		platform_half_width + 80.0,
		abs(local_px.x)
	);
	float field_gate = vertical_gate * horizontal_gate;

	vec2 p = local_px / vec2(34.0, 25.0);
	float warp_x = fbm(
		p * 0.48 + vec2(-time * 0.065 + phase_offset * 0.001, time * 0.025)
	);
	float warp_y = fbm(
		p * 0.52 + vec2(time * 0.043, -time * 0.058 + phase_offset * 0.003 + 4.7)
	);
	vec2 warped = p + (vec2(warp_x, warp_y) - 0.5) * 1.30;

	// Three scales ebb through one continuous field, rather than tracing fixed
	// paths. Differently advected noise makes the streaks bend, fragment and
	// reconnect over time.
	float broad_noise = fbm(
		warped * vec2(0.70, 0.94) + vec2(-time * 0.12, time * 0.035)
	);
	float medium_noise = fbm(
		warped * vec2(1.22, 1.62) + vec2(time * 0.13, -time * 0.17)
	);
	float fine_noise = fbm(
		warped * vec2(2.10, 2.42) + vec2(-time * 0.22, time * 0.16)
	);

	float body_density = smoothstep(0.31, 0.61, broad_noise)
		* (0.48 + smoothstep(0.30, 0.68, medium_noise) * 0.52);

	// Ridges from the warped noise create thin irregular filaments. A second
	// mask breaks them into variable lengths, preventing continuous line shapes.
	float ridge_field = 1.0 - abs(medium_noise * 2.0 - 1.0);
	float filament_ridges = smoothstep(0.67, 0.91, ridge_field)
		* smoothstep(0.30, 0.61, broad_noise)
		* smoothstep(0.27, 0.62, fine_noise);

	// Rare fine-scale glints are isolated accents within the diffuse stream.
	float fine_ridge = 1.0 - abs(fine_noise * 2.0 - 1.0);
	float accents = smoothstep(0.83, 0.96, fine_ridge)
		* smoothstep(0.42, 0.69, broad_noise)
		* smoothstep(0.31, 0.70, medium_noise);

	float living_pulse = 0.90 + 0.10 * sin(
		time * 1.1 + phase_offset * 0.01 + local_px.x * 0.012
	);
	float landing_active = step(0.0, landing_age)
		* (1.0 - smoothstep(0.0, 0.58, landing_age));
	float landing_pulse = landing_active * clamp(landing_strength, 0.0, 1.45);
	float energy_boost = 1.0 + clamp(approach_charge, 0.0, 1.0) * 0.12
		+ landing_pulse * 0.38;

	// Body remains diffuse; only the filaments and occasional accents get the
	// stronger emission needed to survive the normal gameplay camera distance.
	float alpha = (
		body_density * 0.18
		+ filament_ridges * 0.28
		+ accents * 0.20
	) * field_gate * living_pulse * energy_boost;
	alpha = clamp(alpha, 0.0, 0.44);

	vec3 body_color = vec3(0.12, 0.045, 1.05);
	vec3 filament_color = vec3(0.055, 0.34, 2.25);
	vec3 accent_color = vec3(0.20, 0.78, 2.85);
	vec3 energy_color = mix(
		body_color,
		filament_color,
		clamp(filament_ridges * 0.82 + accents * 0.22, 0.0, 1.0)
	);
	energy_color = mix(
		energy_color,
		accent_color,
		clamp(accents * 0.72 + landing_pulse * 0.20, 0.0, 0.72)
	);

	COLOR = vec4(energy_color, alpha);
}
