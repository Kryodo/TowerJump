shader_type canvas_item;

uniform int palette_mode = 0;
uniform float edge_time = 0.0;
uniform float edge_undulation_strength : hint_range(0.0, 0.26) = 0.20;
uniform float pulse_progress = -1.0;
uniform float pulse_strength = 0.0;
uniform float dissolve_start = 0.66;
uniform float dissolve_end = 0.94;
uniform float dissolve_enabled = 1.0;


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

float comet_dissolve_mask(vec2 uv) {
	float along = clamp(uv.x, 0.0, 1.0);
	float mirrored_across = abs(clamp(uv.y, 0.0, 1.0) * 2.0 - 1.0);
	float coarse_pattern = noise(vec2(
		along * 27.0 + mirrored_across * 2.2,
		mirrored_across * 4.6 + 1.7
	));
	float detail_pattern = noise(vec2(
		along * 53.0 + mirrored_across * 3.4 + 13.7,
		mirrored_across * 9.0 + 5.3
	));
	float breakup_pattern = mix(coarse_pattern, detail_pattern, 0.28);
	float dissolve_amount = smoothstep(dissolve_start, dissolve_end, along);
	float dissolve_threshold = mix(-0.14, 1.14, dissolve_amount);
	float visible_mask = smoothstep(
		dissolve_threshold - 0.075,
		dissolve_threshold + 0.075,
		breakup_pattern
	);
	return mix(1.0, visible_mask, clamp(dissolve_enabled, 0.0, 1.0));
}

// Preserve the TrailAura gradient as the base color. A passing pulse adds a
// short-lived highlight strongest along each outside edge of the ribbon.
void fragment() {
	vec4 aura = COLOR;
	float along = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);
	float edge_distance = abs(across * 2.0 - 1.0);

	// Match the broad, nested waves used by the live membrane geometry.
	float upper_wave =
		0.43 * sin(along * 8.3 - edge_time * 0.82
			+ sin(along * 3.1 + edge_time * 0.31) * 0.95
			+ sin(along * 5.7 - edge_time * 0.47 + 1.4) * 0.42)
		+ 0.25 * sin(along * 15.2 + edge_time * 1.07 + 1.7)
		+ 0.14 * sin(along * 26.7 - edge_time * 1.45 + 0.6)
		+ 0.18 * sin(along * 4.1 + edge_time * 0.43);
	float lower_phase = 2.05;
	float lower_wave =
		0.43 * sin(along * 8.3 - edge_time * 0.82
			+ sin(along * 3.1 + edge_time * 0.31 + lower_phase * 0.28) * 0.95
			+ sin(along * 5.7 - edge_time * 0.47 + 1.4 - lower_phase * 0.35) * 0.42
			+ lower_phase)
		+ 0.25 * sin(along * 15.2 + edge_time * 1.07 + 1.7 + lower_phase * 1.13)
		+ 0.14 * sin(along * 26.7 - edge_time * 1.45 + 0.6 - lower_phase * 0.72)
		+ 0.18 * sin(along * 4.1 + edge_time * 0.43 + lower_phase * 0.75);
	float edge_envelope = smoothstep(0.025, 0.19, along);
	float upper_threshold = 0.91 + upper_wave * edge_undulation_strength * edge_envelope;
	float lower_threshold = 0.91 + lower_wave * edge_undulation_strength * edge_envelope;
	float edge_threshold = mix(upper_threshold, lower_threshold, step(0.5, across));
	float edge_fade = 1.0 - smoothstep(edge_threshold, edge_threshold + 0.075, edge_distance);
	float edge_factor = smoothstep(0.42, 0.82, edge_distance);
	float pulse_gate = step(0.0, pulse_progress);
	float pulse_band = (
		1.0 - smoothstep(0.02, 0.105, abs(along - pulse_progress))
	) * pulse_gate;
	float pulse = pulse_band * pulse_strength;

	vec3 pulse_color;
	if (palette_mode == 1) {
		pulse_color = vec3(1.35, 0.72, 1.85);
	} else {
		pulse_color = vec3(0.62, 1.18, 1.72);
	}

	float edge_flash = pulse * edge_factor;
	aura.rgb = mix(aura.rgb, pulse_color, pulse * 0.12);
	aura.rgb += pulse_color * edge_flash * 0.72;
	aura.a = clamp(aura.a + pulse * 0.025 + edge_flash * 0.24, 0.0, 0.98);
	aura.a *= edge_fade;
	aura.a *= comet_dissolve_mask(UV);
	COLOR = aura;
}
