shader_type canvas_item;

uniform int palette_mode = 0;
uniform float edge_time = 0.0;
uniform float edge_undulation_strength : hint_range(0.0, 0.16) = 0.105;
uniform float pulse_progress = -1.0;
uniform float pulse_strength = 0.0;

// Preserve the TrailAura gradient as the base color. Its broad edge motion
// deliberately counter-runs the mesh deformation to imply two sliding layers.
// Counter-moving broad waves create a subtle second membrane layer.
// Keep the frequency low and the two edge phases offset to avoid a cheap,
// synchronized sine-ribbon appearance.
float aura_counter_wave(float along, float time_value, float phase_offset) {
	float broad_wave = sin(
		along * 7.2 + time_value * 0.66
		+ sin(along * 3.0 + time_value * 0.22 + phase_offset * 0.35) * 0.60
		+ phase_offset
	);
	float secondary_wave = sin(
		along * 3.5 + time_value * 0.31 + phase_offset * 0.62
	);
	return broad_wave * 0.74 + secondary_wave * 0.26;
}

void fragment() {
	vec4 aura = COLOR;
	float along = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);
	float edge_distance = abs(across * 2.0 - 1.0);

	// This layer moves in the opposite direction to the mesh: broad edge
	// swells drift back toward the orb while the body swell travels down-tail.
	float upper_wave = aura_counter_wave(along, edge_time, 0.85);
	float lower_wave = aura_counter_wave(along, edge_time, 2.45);
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
	COLOR = aura;
}
