shader_type canvas_item;

uniform int palette_mode = 0;
uniform float pulse_progress = -1.0;
uniform float pulse_strength = 0.0;
uniform float combo_energy = 0.0;
uniform vec3 combo_tint = vec3(0.24, 1.02, 1.42);

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

	vec3 pulse_color;
	if (palette_mode == 1) {
		pulse_color = vec3(1.35, 0.72, 1.85);
	} else {
		pulse_color = vec3(0.62, 1.18, 1.72);
	}

	// A restrained current runs along the aura for as long as Combo remains
	// active, tying the outer silhouette to the moving energy inside the skin.
	float combo_wave = 0.5 + 0.5 * sin(
		along * 18.0 - TIME * 2.25 + sin(along * 5.0 + TIME * 0.55)
	);
	float combo_current = combo_energy
		* (0.45 + combo_wave * 0.55)
		* smoothstep(0.18, 0.72, edge_distance)
		* (1.0 - smoothstep(0.72, 1.0, along));
	aura.rgb = mix(aura.rgb, combo_tint, combo_current * 0.095);
	aura.rgb += combo_tint * combo_current * 0.045;

	float edge_flash = pulse * edge_factor;
	aura.rgb = mix(aura.rgb, pulse_color, pulse * 0.12);
	aura.rgb += pulse_color * edge_flash * 0.72;
	aura.a = clamp(aura.a + combo_current * 0.014 + pulse * 0.025 + edge_flash * 0.24, 0.0, 0.98);
	aura.a *= edge_fade;
	COLOR = aura;
}
