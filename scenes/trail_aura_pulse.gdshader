shader_type canvas_item;

uniform int palette_mode = 0;
uniform float edge_time = 0.0;
uniform float edge_undulation_strength : hint_range(0.0, 0.16) = 0.07;
uniform float pulse_progress = -1.0;
uniform float pulse_strength = 0.0;

// Preserve the TrailAura gradient as the base color. A passing pulse adds a
// short-lived highlight strongest along each outside edge of the ribbon.
void fragment() {
	vec4 aura = COLOR;
	float along = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);
	float edge_distance = abs(across * 2.0 - 1.0);

	// Follow the same two differently phased edge waves used by the mesh geometry.
	float upper_wave =
		0.62 * sin(along * 12.0 - edge_time * 1.15
			+ sin(along * 4.8 + edge_time * 0.48) * 0.7)
		+ 0.25 * sin(along * 23.0 - edge_time * 1.65 + 1.2)
		+ 0.13 * sin(along * 7.0 + edge_time * 0.68);
	float lower_phase = 1.65;
	float lower_wave =
		0.62 * sin(along * 12.0 - edge_time * 1.15
			+ sin(along * 4.8 + edge_time * 0.48) * 0.7 + lower_phase)
		+ 0.25 * sin(along * 23.0 - edge_time * 1.65 + 1.2 + lower_phase * 0.8)
		+ 0.13 * sin(along * 7.0 + edge_time * 0.68 + lower_phase * 0.6);
	float upper_threshold = 0.84 + upper_wave * edge_undulation_strength;
	float lower_threshold = 0.84 + lower_wave * edge_undulation_strength;
	float edge_threshold = mix(upper_threshold, lower_threshold, step(0.5, across));
	float edge_fade = 1.0 - smoothstep(edge_threshold, edge_threshold + 0.07, edge_distance);
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
	COLOR = aura;
}
