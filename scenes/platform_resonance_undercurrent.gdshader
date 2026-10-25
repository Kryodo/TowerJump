shader_type canvas_item;
render_mode unshaded, blend_add;

// VISIBILITY STRESS TEST for the diffuse undercurrent.
// Values are intentionally exaggerated to answer one question: can the
// noise-based flow be seen in gameplay, independent of final art direction?
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

	// Broad diagnostic footprint under the platform. Fade still exists, but
	// it is intentionally wide and gentle rather than hiding the undercurrent.
	float vertical_gate = smoothstep(-1.0, 7.0, below)
		* (1.0 - smoothstep(72.0, 98.0, below));
	float horizontal_gate = 1.0 - smoothstep(
		platform_half_width + 34.0,
		platform_half_width + 100.0,
		abs(local_px.x)
	);
	float field_gate = vertical_gate * horizontal_gate;

	// Broad domain warp keeps the field fluid and irregular.
	vec2 flow_uv = local_px / vec2(58.0, 23.0);
	float warp_a = fbm(
		flow_uv * vec2(0.42, 0.70)
		+ vec2(-time * 0.065 + phase_offset * 0.001, time * 0.045)
	);
	float warp_b = fbm(
		flow_uv * vec2(0.58, 0.62)
		+ vec2(time * 0.042, -time * 0.065 + 4.2 + phase_offset * 0.002)
	);
	vec2 warped = flow_uv
		+ (vec2(warp_a, warp_b) - 0.5) * vec2(1.20, 1.45);

	float body_noise = fbm(
		warped * vec2(0.66, 0.84)
		+ vec2(-time * 0.11, time * 0.055)
	);
	float body_detail = noise(
		warped * vec2(0.38, 0.65)
		+ vec2(time * 0.055, -time * 0.04 + 7.1)
	);
	// Broader threshold deliberately makes much more of the diffuse mass visible.
	float body_density = smoothstep(0.20, 0.49, body_noise)
		* (0.72 + body_detail * 0.28);

	float flow_a = fbm(
		warped * vec2(0.52, 2.55)
		+ vec2(-time * 0.15, time * 0.20 + phase_offset * 0.002)
	);
	float flow_b = fbm(
		warped * vec2(0.73, 3.45)
		+ vec2(time * 0.12, -time * 0.17 + 5.8 + phase_offset * 0.003)
	);
	float ridge_a = 1.0 - abs(flow_a * 2.0 - 1.0);
	float ridge_b = 1.0 - abs(flow_b * 2.0 - 1.0);
	float ridges = smoothstep(0.46, 0.76, ridge_a) * 0.86
		+ smoothstep(0.52, 0.80, ridge_b) * 0.52;
	float breakup_noise = noise(
		warped * vec2(0.46, 0.88)
		+ vec2(-time * 0.12, time * 0.07 + 2.8)
	);
	// Keep a strong continuity floor so the test cannot vanish from multiplying masks.
	float continuity = 0.78 + 0.22 * smoothstep(0.16, 0.62, breakup_noise);
	float streak_density = clamp(ridges * continuity, 0.0, 1.0);

	float fine_flow = noise(
		warped * vec2(1.45, 4.0)
		+ vec2(-time * 0.25, time * 0.29 + phase_offset * 0.005)
	);
	float fine_ridge = 1.0 - abs(fine_flow * 2.0 - 1.0);
	float traveler = 0.5 + 0.5 * sin(
		local_px.x * 0.032 - time * 1.05 + phase_offset * 0.014
		+ (body_detail - 0.5) * 2.1
	);
	float accents = smoothstep(0.66, 0.91, fine_ridge)
		* (0.40 + streak_density * 0.60)
		* pow(traveler, 1.6);

	float landing_active = step(0.0, landing_age)
		* (1.0 - smoothstep(0.0, 0.58, landing_age));
	float landing_pulse = landing_active * clamp(landing_strength, 0.0, 1.45);
	float energy_boost = 1.0
		+ clamp(approach_charge, 0.0, 1.0) * 0.15
		+ landing_pulse * 0.45;
	float living_pulse = 0.97 + 0.03 * sin(
		time * 0.9 + phase_offset * 0.01 + local_px.x * 0.008
	);

	// Deliberately high test values: body + broken streaks + accents.
	float body_alpha = body_density * 0.48;
	float streak_alpha = streak_density * 0.82;
	float accent_alpha = accents * 0.60;
	float alpha = (body_alpha + streak_alpha + accent_alpha)
		* field_gate * energy_boost * living_pulse;
	alpha = clamp(alpha, 0.0, 0.92);

	// Strong HDR cyan-blue is intentional for this test, not the final palette.
	vec3 body_color = vec3(0.22, 0.10, 2.20);
	vec3 streak_color = vec3(0.12, 0.72, 4.20);
	vec3 accent_color = vec3(0.30, 1.35, 6.00);
	vec3 energy_color = mix(
		body_color,
		streak_color,
		clamp(streak_density * 0.92 + accents * 0.18, 0.0, 1.0)
	);
	energy_color = mix(
		energy_color,
		accent_color,
		clamp(accents * 0.78 + landing_pulse * 0.18, 0.0, 0.82)
	);

	COLOR = vec4(energy_color, alpha);
}
