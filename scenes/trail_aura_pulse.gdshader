shader_type canvas_item;

uniform int palette_mode = 0;
uniform float pulse_progress = -1.0;
uniform float pulse_strength = 0.0;
uniform float landing_pulse_progress = -1.0;
uniform float landing_pulse_strength = 0.0;

// Preserve the TrailAura gradient as the base color. A passing pulse adds a
// short-lived highlight strongest along each outside edge of the ribbon.
void fragment() {
	vec4 aura = COLOR;
	float along = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);
	float edge_distance = abs(across * 2.0 - 1.0);

	// Keep a constant soft falloff at the two sides of the aura. The outer
	// silhouette no longer oscillates; the existing gradient controls its shape.
	float edge_fade = 1.0 - smoothstep(0.91, 0.985, edge_distance);
	float edge_factor = smoothstep(0.42, 0.82, edge_distance);
	float pulse_gate = step(0.0, pulse_progress);
	float pulse_band = (
		1.0 - smoothstep(0.02, 0.105, abs(along - pulse_progress))
	) * pulse_gate;
	float pulse = pulse_band * pulse_strength;
	float landing_pulse_band = (
		1.0 - smoothstep(0.025, 0.125, abs(along - landing_pulse_progress))
	) * step(0.0, landing_pulse_progress);
	float landing_pulse = landing_pulse_band * landing_pulse_strength * edge_fade;

	vec3 pulse_color;
	vec3 landing_pulse_color;
	if (palette_mode == 1) {
		pulse_color = vec3(1.35, 0.72, 1.85);
		landing_pulse_color = vec3(1.9, 1.1, 2.65);
	} else {
		pulse_color = vec3(0.62, 1.18, 1.72);
		landing_pulse_color = vec3(0.9, 1.8, 2.55);
	}

	float edge_flash = max(pulse * edge_factor, landing_pulse * edge_factor * 1.15);
	aura.rgb = mix(aura.rgb, pulse_color, pulse * 0.12);
	aura.rgb += pulse_color * edge_flash * 0.72;
	aura.rgb += landing_pulse_color * landing_pulse * (0.28 + edge_factor * 0.42);
	aura.a = clamp(aura.a + pulse * 0.025 + edge_flash * 0.24 + landing_pulse * 0.035, 0.0, 0.98);
	aura.a *= edge_fade;
	COLOR = aura;
}
