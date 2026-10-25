shader_type canvas_item;
render_mode unshaded, blend_add;

// A dedicated current layer, independent of the diffuse resonance cloud.
// Curved stream bodies stay recognizable at gameplay scale; soft cores travel
// through them, and all energy fades naturally into the darkness below.
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
	float x = local_px.x;
	float below = local_px.y - platform_half_height;

	// The currents live below the platform, with a quiet gap at the edge and
	// a wide feathered exit. The horizontal envelope lets the ends dissolve
	// rather than forming a rectangular under-platform graphic.
	float underside_gate = smoothstep(3.0, 12.0, below)
		* (1.0 - smoothstep(68.0, 90.0, below));
	float horizontal_gate = 1.0 - smoothstep(
		platform_half_width + 28.0,
		platform_half_width + 86.0,
		abs(x)
	);
	float field_gate = underside_gate * horizontal_gate;

	// Slowly moving noise bends each current differently. Three broad paths
	// overlap irregularly, suggesting a living stream instead of parallel lines.
	float bend_a = fbm(vec2(x * 0.014 + time * 0.11, 1.4 + phase_offset * 0.002));
	float bend_b = fbm(vec2(x * 0.012 - time * 0.08, 5.3 + phase_offset * 0.003));
	float bend_c = fbm(vec2(x * 0.019 + time * 0.07, 8.7 + phase_offset * 0.004));

	float center_a = platform_half_height + 27.0
		+ sin(x * 0.022 + time * 0.22 + phase_offset * 0.003) * 6.5
		+ (bend_a - 0.5) * 14.0;
	float center_b = platform_half_height + 46.0
		+ sin(x * 0.015 - time * 0.19 + phase_offset * 0.011) * 9.0
		+ (bend_b - 0.5) * 18.0;
	float center_c = platform_half_height + 61.0
		+ sin(x * 0.028 + time * 0.17 + phase_offset * 0.017) * 5.0
		+ (bend_c - 0.5) * 12.0;

	float dist_a = local_px.y - center_a;
	float dist_b = local_px.y - center_b;
	float dist_c = local_px.y - center_c;

	float body_a = exp(-pow(dist_a / 8.5, 2.0));
	float body_b = exp(-pow(dist_b / 9.5, 2.0));
	float body_c = exp(-pow(dist_c / 7.5, 2.0));
	float core_a = exp(-pow(dist_a / 2.8, 2.0));
	float core_b = exp(-pow(dist_b / 3.2, 2.0));
	float core_c = exp(-pow(dist_c / 2.5, 2.0));

	// Noise and traveling lobes make each stream ebb and flow without breaking
	// it into dots or making it disappear between pulses.
	float texture_a = 0.62 + 0.38 * noise(vec2(
		x * 0.026 - time * 0.18,
		below * 0.035 + phase_offset * 0.001
	));
	float texture_b = 0.58 + 0.42 * noise(vec2(
		x * 0.021 + time * 0.14,
		below * 0.031 + 6.0 + phase_offset * 0.002
	));
	float texture_c = 0.60 + 0.40 * noise(vec2(
		x * 0.031 - time * 0.16,
		below * 0.040 + 12.0 + phase_offset * 0.003
	));
	float travel_a = 0.72 + 0.28 * (0.5 + 0.5 * sin(x * 0.032 - time * 1.05 + phase_offset));
	float travel_b = 0.68 + 0.32 * (0.5 + 0.5 * sin(x * 0.026 + time * 0.82 + phase_offset * 1.7));
	float travel_c = 0.70 + 0.30 * (0.5 + 0.5 * sin(x * 0.038 - time * 0.94 + phase_offset * 2.3));

	float bodies = body_a * texture_a * 0.88
		+ body_b * texture_b * 0.82
		+ body_c * texture_c * 0.62;
	float cores = core_a * texture_a * travel_a * 0.78
		+ core_b * texture_b * travel_b * 0.86
		+ core_c * texture_c * travel_c * 0.58;

	// A landing briefly feeds energy into the same currents; idle state remains
	// clearly legible, so the landing response enhances rather than reveals them.
	float landing_active = step(0.0, landing_age)
		* (1.0 - smoothstep(0.0, 0.58, landing_age));
	float landing_pulse = landing_active * clamp(landing_strength, 0.0, 1.45);
	float flow_energy = 1.0 + clamp(approach_charge, 0.0, 1.0) * 0.12
		+ landing_pulse * 0.52;

	float alpha = (bodies * 0.13 + cores * 0.20)
		* field_gate * flow_energy;
	alpha = clamp(alpha, 0.0, 0.46);

	float core_fraction = clamp(cores / max(bodies + cores, 0.001), 0.0, 1.0);
	vec3 body_color = vec3(0.075, 0.20, 0.72);
	vec3 core_color = vec3(0.055, 0.42, 1.35);
	vec3 stream_color = mix(body_color, core_color, core_fraction);
	stream_color = mix(stream_color, vec3(0.16, 0.58, 1.55), landing_pulse * 0.35);

	COLOR = vec4(stream_color, alpha);
}
