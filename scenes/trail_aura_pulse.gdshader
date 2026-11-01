shader_type canvas_item;

uniform int palette_mode = 0;
uniform float pulse_progress = -1.0;
uniform float pulse_strength = 0.0;
uniform float jump_boost_progress = -1.0;
uniform float jump_boost_strength = 0.0;
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
	float jump_boost_gate = step(0.0, jump_boost_progress);
	float jump_boost_band = (
		1.0 - smoothstep(0.014, 0.078, abs(along - jump_boost_progress))
	) * jump_boost_gate;
	float jump_boost = jump_boost_band * jump_boost_strength;

	vec3 pulse_color;
	if (palette_mode == 1) {
		pulse_color = vec3(1.35, 0.72, 1.85);
	} else {
		pulse_color = vec3(0.62, 1.18, 1.72);
	}

	// A restrained current runs along the aura for as long as Combo remains
	// active, tying the outer silhouette to the moving energy inside the skin.
	float combo_time = TIME * (1.0 + combo_energy * 0.45);
	float combo_wave = 0.5 + 0.5 * sin(
		along * 18.0 - combo_time * 2.25 + sin(along * 5.0 + combo_time * 0.55)
	);
	float combo_current = combo_energy
		* (0.35 + combo_wave * 0.65)
		* smoothstep(0.18, 0.72, edge_distance)
		* (1.0 - smoothstep(0.72, 1.0, along));
	// More visible animated light along the outside of the ribbon makes the
	// whole comet feel awake, while the feathered aura still stays translucent.
	aura.rgb = mix(aura.rgb, combo_tint, combo_current * 0.20);
	aura.rgb += combo_tint * combo_current * 0.10;

	float edge_flash = pulse * edge_factor;
	aura.rgb = mix(aura.rgb, pulse_color, pulse * 0.12);
	aura.rgb += pulse_color * edge_flash * 0.72;
	aura.rgb = mix(aura.rgb, pulse_color, jump_boost * 0.13);
	aura.rgb += pulse_color * jump_boost * (0.34 + edge_factor * 0.34);
	aura.a = clamp(
		aura.a + combo_current * 0.035 + pulse * 0.025 + edge_flash * 0.24
		+ jump_boost * (0.025 + edge_factor * 0.08),
		0.0,
		0.98
	);
	aura.a *= edge_fade;
	COLOR = aura;
}
