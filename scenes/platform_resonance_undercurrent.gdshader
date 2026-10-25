shader_type canvas_item;
render_mode unshaded, blend_add;

// One diffuse undercurrent with a readable low-frequency body, irregular
// anisotropic filaments, and occasional traveling accents. Contrast is kept
// strong enough for gameplay scale; noise only shapes the flow, not erases it.
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

	// The undercurrent remains under the platform and fades smoothly at its
	// lower and side edges. This gate is broad; it doesn't fragment the flow.
	float vertical_gate = smoothstep(1.5, 10.0, below)
		* (1.0 - smoothstep(64.0, 88.0, below));
	float horizontal_gate = 1.0 - smoothstep(
		platform_half_width + 16.0,
		platform_half_width + 78.0,
		abs(local_px.x)
	);
	float field_gate = vertical_gate * horizontal_gate;

	// Slow domain warping bends the field over time without tracing explicit
	// ribbons. Larger, anisotropic sampling makes streaks longer than they are
	// tall; the deformation stops them reading as straight parallel lines.
	vec2 p = local_px / vec2(54.0, 25.0);
	float warp_x = fbm(
		p * vec2(0.50, 0.72)
		+ vec2(-time * 0.065 + phase_offset * 0.001, time * 0.035)
	);
	float warp_y = fbm(
		p * vec2(0.66, 0.58)
		+ vec2(time * 0.048, -time * 0.070 + phase_offset * 0.002 + 3.7)
	);
	vec2 warped = p + (vec2(warp_x, warp_y) - 0.5) * 1.15;

	// Broad volume: a low-frequency haze which stays present between streaks.
	float body_noise = fbm(
		warped * vec2(0.72, 0.88)
		+ vec2(-time * 0.11, time * 0.035)
	);
	float body_detail = noise(
		warped * vec2(0.42, 0.70)
		+ vec2(time * 0.06, -time * 0.045 + 6.3)
	);
	float body_density = smoothstep(0.23, 0.54, body_noise)
		* (0.62 + body_detail * 0.38);

	// Directionally sampled noise forms broken, horizontally flowing ridges.
	// We use one main ridge field and one softer offset field, not a stack of
	// restrictive masks that would make almost every pixel vanish.
	float flow_noise_a = noise(
		warped * vec2(0.46, 3.00)
		+ vec2(-time * 0.16, time * 0.23 + phase_offset * 0.002)
	);
	float flow_noise_b = noise(
		warped * vec2(0.62, 4.15)
		+ vec2(time * 0.13, -time * 0.19 + 5.4 + phase_offset * 0.003)
	);
	float ridge_a = 1.0 - abs(flow_noise_a * 2.0 - 1.0);
	float ridge_b = 1.0 - abs(flow_noise_b * 2.0 - 1.0);
	float main_streaks = smoothstep(0.62, 0.87, ridge_a);
	float secondary_streaks = smoothstep(0.70, 0.92, ridge_b);

	// Modulation creates natural gaps and changing density, but its floor keeps
	// flow legible instead of multiplying the streaks into near-invisibility.
	float continuity = 0.48 + 0.52 * smoothstep(
		0.20, 0.62,
		noise(warped * vec2(0.48, 0.82) + vec2(-time * 0.12, time * 0.06))
	);
	float streak_density = clamp(
		(main_streaks * 0.78 + secondary_streaks * 0.34) * continuity,
		0.0, 1.0
	);

	// Short-lived highlights travel through the current field. They are a
	// minority of the visible structure, not a row of permanent bright dots.
	float fine_noise = noise(
		warped * vec2(1.75, 3.9)
		+ vec2(-time * 0.27, time * 0.31 + phase_offset * 0.006)
	);
	float fine_ridge = 1.0 - abs(fine_noise * 2.0 - 1.0);
	float traveling_lobe = 0.5 + 0.5 * sin(
		local_px.x * 0.035 - time * 1.15 + phase_offset * 0.013
		+ (body_detail - 0.5) * 2.0
	);
	float accents = smoothstep(0.75, 0.94, fine_ridge)
		* (0.42 + body_density * 0.58)
		* pow(traveling_lobe, 2.2);

	float living_pulse = 0.94 + 0.06 * sin(
		time * 0.92 + phase_offset * 0.01 + local_px.x * 0.009
	);
	float landing_active = step(0.0, landing_age)
		* (1.0 - smoothstep(0.0, 0.58, landing_age));
	float landing_pulse = landing_active * clamp(landing_strength, 0.0, 1.45);
	float energy_boost = 1.0
		+ clamp(approach_charge, 0.0, 1.0) * 0.10
		+ landing_pulse * 0.38;

	// Brighter than the previous diffuse pass, calibrated against the visible
	// ribbon proof. Body stays soft; contrast lives in the irregular streaks.
	float body_alpha = body_density * 0.14;
	float streak_alpha = streak_density * 0.31;
	float accent_alpha = accents * 0.22;
	float alpha = (body_alpha + streak_alpha + accent_alpha)
		* field_gate * living_pulse * energy_boost;
	alpha = clamp(alpha, 0.0, 0.50);

	vec3 body_color = vec3(0.13, 0.045, 1.02);
	vec3 streak_color = vec3(0.065, 0.34, 2.25);
	vec3 accent_color = vec3(0.20, 0.78, 2.90);
	vec3 energy_color = mix(
		body_color,
		streak_color,
		clamp(streak_density * 0.92 + accents * 0.18, 0.0, 1.0)
	);
	energy_color = mix(
		energy_color,
		accent_color,
		clamp(accents * 0.76 + landing_pulse * 0.18, 0.0, 0.78)
	);

	COLOR = vec4(energy_color, alpha);
}
