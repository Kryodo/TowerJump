shader_type canvas_item;

// 0 = saturated electric blue, 1 = rich violet.
// The trail controller sets this so orb and trail share one palette.
uniform int palette_mode = 0;
// Shared with the trail contour so both sides pulse in sync.
uniform float rim_breath = 1.0;
uniform float landing_anticipation = 0.0;
uniform float landing_confirmation = 0.0;
// Quality-chain feedback is rendered inside the orb, close to the plasma core.
// Progress is 0..3; quality is 0=Good, 1=Epic, 2=Perfect.
uniform float quality_chain_progress = 0.0;
uniform int quality_chain = 0;
uniform int combo_core_quality = 0;
uniform float combo_core_blend = 0.0;
uniform float combo_activation_flash = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float time = TIME;
	float mask = texture(TEXTURE, UV).a;
	float landing_charge = clamp(landing_anticipation, 0.0, 1.0);
	float landing_flash = clamp(landing_confirmation, 0.0, 1.0);

	float breathing = 0.5 + 0.5 * sin(time * 1.35);
	float aura_breath = mix(0.72, 1.0, breathing);

	vec3 inner_body;
	vec3 outer_body;
	vec3 moving_energy;
	vec3 inner_energy_color;
	vec3 transition_color;
	vec3 ring_color;
	vec3 core_color;
	vec3 aura_color;
	vec3 outer_core_color;
	vec3 highlight_color;
	vec3 glint_color;
	vec3 confirmation_core_color;

	if (palette_mode == 1) {
		inner_body = vec3(0.28, 0.035, 0.68);
		outer_body = vec3(0.045, 0.006, 0.16);
		moving_energy = vec3(0.52, 0.12, 1.25);
		inner_energy_color = vec3(0.58, 0.10, 1.5);
		transition_color = vec3(0.34, 0.045, 0.78);
		ring_color = vec3(2.7, 0.55, 5.2);
		core_color = vec3(4.0, 3.25, 6.2);
		aura_color = vec3(1.45, 0.22, 3.1);
		outer_core_color = vec3(1.35, 0.18, 3.0);
		highlight_color = vec3(1.0, 0.72, 1.5);
		glint_color = vec3(2.0, 1.55, 2.8);
		confirmation_core_color = vec3(5.0, 4.4, 6.4);
	} else {
		inner_body = vec3(0.018, 0.22, 0.62);
		outer_body = vec3(0.003, 0.028, 0.15);
		moving_energy = vec3(0.04, 0.48, 1.25);
		inner_energy_color = vec3(0.025, 0.32, 1.05);
		transition_color = vec3(0.025, 0.20, 0.68);
		ring_color = vec3(0.18, 2.15, 5.2);
		core_color = vec3(3.2, 5.1, 6.3);
		aura_color = vec3(0.04, 1.25, 3.0);
		outer_core_color = vec3(0.06, 1.28, 3.15);
		highlight_color = vec3(0.65, 1.45, 2.25);
		glint_color = vec3(1.5, 2.5, 3.2);
		confirmation_core_color = vec3(4.7, 6.0, 6.5);
	}

	// Saturated energy body with a deeper outer edge for visual depth.
	float body_falloff = 1.0 - smoothstep(0.04, 1.02, d);
	vec3 body_color = mix(outer_body, inner_body, body_falloff);
	float body_strength = mix(0.88, 1.12, body_falloff);
	vec3 color = body_color * body_strength;

	// Slow internal waves create a living energy field without noisy detail.
	float angle = atan(p.y, p.x);
	float wave_a = sin(angle * 4.0 + d * 9.0 - time * 1.8);
	float wave_b = sin(angle * 7.0 - d * 6.0 + time * 1.25);
	float wave_c = sin(p.x * 8.0 + p.y * 5.0 + time * 1.1);
	float energy_flow = wave_a * 0.45 + wave_b * 0.35 + wave_c * 0.20;
	float energy_mask = smoothstep(-0.15, 0.65, energy_flow);
	float energy_fade = 1.0 - smoothstep(0.30, 0.92, d);
	color += moving_energy * energy_mask * energy_fade * 0.34 * mix(0.90, 1.0, breathing);

	float inner_energy = 1.0 - smoothstep(0.22, 0.75, d);
	color += inner_energy_color * inner_energy * 0.32;

	// Broad shell fill bridges the core aura to the rim, avoiding a dark
	// background-colored band inside the orb. Fade it only near the silhouette.
	float shell_fill =
		smoothstep(0.18, 0.58, d)
		*
		(1.0 - smoothstep(0.78, 0.985, d));
	color += transition_color * shell_fill * 0.48;

	float outer_transition = 1.0 - smoothstep(0.36, 0.99, d);
	color += transition_color * outer_transition * 0.18;

	// Keep a restrained interior contour. The broader force-field glow is
	// rendered behind the orb, so this no longer needs to read as a hard border.
	float outer_ring =
		smoothstep(0.90, 0.93, d)
		-
		smoothstep(0.956, 0.982, d);
	color += ring_color * outer_ring * rim_breath * 0.22;

	// The activation hit temporarily expands the core and its inner glow. The
	// sustained hue remains tied to Combo; the hit itself quickly decays.
	float core_pulse = 0.5 + 0.5 * sin(time * 1.8);
	float chain_tint_strength = clamp(combo_core_blend, 0.0, 1.0);
	float combo_hit = clamp(combo_activation_flash, 0.0, 1.0);

	vec3 combo_core_color;
	if (combo_core_quality == 2) {
		combo_core_color = vec3(5.2, 6.0, 6.3); // Perfect: brilliant white-cyan
	} else if (combo_core_quality == 1) {
		combo_core_color = vec3(7.2, 0.06, 2.5); // Epic: warmer hot rose, distinct from violet aura
	} else {
		combo_core_color = vec3(0.02, 2.15, 3.2); // Good: electric cyan
	}

	float core_radius = mix(0.245, 0.272, core_pulse)
		* (1.0 + landing_charge * 0.34 + combo_hit * 0.34);

	// Preserve the orb's idle outer-core accent. The inner core carries the
	// quality transformation; blending the surrounding accent into that hue
	// made Epic merge into one broad purple spot.
	float outer_core = 1.0 - smoothstep(core_radius * 0.72, core_radius * 2.05, d);
	vec3 live_outer_core_color = outer_core_color;
	color += live_outer_core_color * outer_core
		* (0.38 + landing_charge * 0.24 + landing_flash * 0.32 + combo_hit * 0.72)
		* aura_breath;

	float core = 1.0 - smoothstep(core_radius * 0.70, core_radius, d);
	float core_brightness = mix(0.79, 0.96, core_pulse)
		* (1.0 + landing_charge * 0.18 + landing_flash * 0.70 + combo_hit * 0.15);
	vec3 live_core_color = mix(core_color, combo_core_color, chain_tint_strength);
	// Keep the landing confirmation flash, but let the activated quality hue
	// remain visible through the same moment instead of being washed to white.
	float confirmation_override = landing_flash * mix(0.82, 0.28, chain_tint_strength);
	live_core_color = mix(live_core_color, confirmation_core_color, confirmation_override);
	color = mix(color, live_core_color * core_brightness, core);
	// Three segments fill sequentially around the breathing core. The lit
	// segments remain on; a narrow animated highlight travels along each one.
	float chain_ring_radius = core_radius + 0.115 + core_pulse * 0.008;
	float chain_ring_distance = abs(d - chain_ring_radius);
	// Keep the segments integrated with the plasma; their hue and narrow
	// highlight define the progress without a dark backing shape.
	float chain_ring = 1.0 - smoothstep(0.002, 0.028, chain_ring_distance);
	float ring_angle_normalized = fract((angle + PI) / TAU);
	float ring_sector_position = ring_angle_normalized * 3.0;
	float ring_sector_index = floor(ring_sector_position);
	float ring_sector_phase = fract(ring_sector_position);
	float ring_sector_enabled = step(ring_sector_index + 1.0, quality_chain_progress);
	float ring_sector_gap_mask = step(0.075, ring_sector_phase) * step(ring_sector_phase, 0.925);
	float ring_travel_position = fract(time * 0.30);
	float ring_travel_highlight = exp(-pow((ring_sector_phase - ring_travel_position) / 0.065, 2.0));
	float chain_ring_alpha = chain_ring * ring_sector_enabled * ring_sector_gap_mask;
	float ring_light_strength = 0.72 + ring_travel_highlight * 0.65 + combo_hit * 0.80;
	vec3 chain_ring_color;
	if (quality_chain == 2) {
		chain_ring_color = vec3(4.1, 5.0, 5.3); // Perfect: white-cyan
	} else if (quality_chain == 1) {
		chain_ring_color = vec3(6.5, 0.025, 5.4); // Epic progress: bright fuchsia, distinct from warmer core
	} else {
		chain_ring_color = vec3(0.05, 2.65, 4.0); // Good: cyan
	}
	// Keep ring brightness independent of the core tint: the ring means progress,
	// while the core hue change is reserved for Combo activation.
	float ring_emission_strength = 0.46;
	if (quality_chain == 1) {
		ring_emission_strength = 0.54;
	}
	color += chain_ring_color * chain_ring_alpha * ring_light_strength * ring_emission_strength * aura_breath;
	float core_aura =
		1.0 - smoothstep(core_radius * 0.62, core_radius * 1.8, d);
	float active_core_aura_suppression = 1.0 - core * chain_tint_strength * (combo_core_quality == 1 ? 0.96 : 0.72);
	color += aura_color * core_aura * (0.28 + landing_charge * 0.20) * aura_breath * active_core_aura_suppression;
	color += confirmation_core_color * core_aura * landing_flash * 0.24;

	// A fast, narrow rim flash makes confirmation visible without trying to
	// push an already-white centre much brighter.
	// Keep the confirmation ring outside the expanded core silhouette so it
	// reads as a separate event. A saturated palette accent gives it contrast
	// without depending on an even brighter white centre.
	float confirmation_ring = exp(-pow((d - core_radius * 1.24) / max(core_radius * 0.085, 0.001), 2.0));
	float confirmation_bloom = exp(-pow((d - core_radius * 1.34) / max(core_radius * 0.24, 0.001), 2.0));
	vec3 confirmation_ring_color = mix(ring_color, confirmation_core_color, 0.18);
	color += confirmation_ring_color * confirmation_ring * landing_flash * 1.05;
	color += outer_core_color * confirmation_bloom * landing_flash * 0.30;

	// Broad upper-left reflection and a small specular glint add orb-like depth.
	vec2 highlight_pos = vec2(-0.28, -0.30);
	vec2 highlight_delta = p - highlight_pos;
	float highlight_dist = length(vec2(highlight_delta.x * 0.78, highlight_delta.y * 1.35));
	float highlight = 1.0 - smoothstep(0.015, 0.29, highlight_dist);
	color += highlight_color * highlight * 0.19;

	vec2 glint_pos = vec2(-0.20, -0.43);
	float glint_dist = distance(p, glint_pos);
	float glint = 1.0 - smoothstep(0.015, 0.095, glint_dist);
	color += glint_color * glint * 0.22;

	COLOR = vec4(color, mask);
}
