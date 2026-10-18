shader_type canvas_item;

uniform int palette_mode = 0;
uniform float edge_time = 0.0;
uniform float pulse_progress = -1.0;
uniform float pulse_strength = 0.0;

// Preserve the TrailAura gradient as the base color. Its edge fade follows
// the same broad swell as the mesh; the travelling pulse gives the membrane a
// small local expansion as it passes, without turning the whole silhouette wavy.
// Mirrors _get_membrane_swell() in ball_trail.gd so both visible layers
// reveal the same slow, localized bulge rather than independent edge waves.
float membrane_swell(float along, float time_value, float side_offset) {
	float cycle = mod(time_value * 0.14, 1.0);
	float swell_center = mix(0.18, 0.82, cycle);
	float activation = smoothstep(0.0, 0.14, cycle)
		* (1.0 - smoothstep(0.78, 0.98, cycle));
	float offset = along - (swell_center + side_offset);
	float broad_bulge = exp(-offset * offset * 32.0);
	float relaxation_offset = along - (swell_center + side_offset + 0.16);
	float trailing_relaxation = exp(-relaxation_offset * relaxation_offset * 180.0);
	return activation * (broad_bulge - trailing_relaxation * 0.28);
}

void fragment() {
	vec4 aura = COLOR;
	float along = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);
	float edge_distance = abs(across * 2.0 - 1.0);

	// Keep the aura's edge fade synchronized with the mesh's single broad swell.
	float upper_swell = membrane_swell(along, edge_time, -0.025);
	float lower_swell = membrane_swell(along, edge_time, 0.035);
	float edge_envelope = smoothstep(0.025, 0.19, along);
	float pulse_gate = step(0.0, pulse_progress);
	float pulse_band = (
		1.0 - smoothstep(0.02, 0.105, abs(along - pulse_progress))
	) * pulse_gate;
	float pulse = pulse_band * pulse_strength;
	float pulse_offset = along - pulse_progress;
	float pulse_swell = exp(-pulse_offset * pulse_offset * 110.0) * pulse_gate * pulse_strength;
	float upper_threshold = 0.91 + (
		upper_swell * 0.075 + pulse_swell * 0.035
	) * edge_envelope;
	float lower_threshold = 0.91 + (
		lower_swell * 0.075 + pulse_swell * 0.025
	) * edge_envelope;
	float edge_threshold = mix(upper_threshold, lower_threshold, step(0.5, across));
	float edge_fade = 1.0 - smoothstep(edge_threshold, edge_threshold + 0.075, edge_distance);
	float edge_factor = smoothstep(0.42, 0.82, edge_distance);

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
