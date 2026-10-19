shader_type canvas_item;

// 0 = saturated electric blue, 1 = rich violet.
// The trail controller sets this so orb and trail share one palette.
uniform int palette_mode = 0;
// Shared with the trail contour so both sides pulse in sync.
uniform float rim_breath = 1.0;
uniform float landing_anticipation = 0.0;
uniform float landing_confirmation = 0.0;

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

	// The luminous centre gently pulses, but its edge is deliberately organic:
	// low-frequency angular waves break the perfect circular silhouette.
	float core_pulse = 0.5 + 0.5 * sin(time * 2.2);
	// Keep the central plasma core slightly smaller so a wider, circular
	// outer core can glow behind it without competing with its bright centre.
	float core_radius = mix(0.23, 0.285, core_pulse) * (1.0 + landing_charge * 0.32);

	// A smooth, perfectly circular outer core sits behind the organic centre.
	// Its inner fade overlaps the centre so both colors melt together instead
	// of reading as two separate rings. Use d rather than core_distance so the
	// larger glow stays circular while the foreground plasma keeps its wobble.
	float outer_core = 1.0 - smoothstep(core_radius * 0.72, core_radius * 2.05, d);
	color += outer_core_color * outer_core * (0.38 + landing_charge * 0.18 + landing_flash * 0.32) * aura_breath;

	float core_wobble =
		1.0
		+ 0.10 * sin(angle * 3.0 + time * 0.72)
		+ 0.045 * sin(angle * 5.0 - time * 0.90 + 1.1)
		+ 0.025 * sin(angle * 2.0 + p.x * 2.8 - time * 0.55);
	float core_distance = d / max(core_wobble, 0.80);
	float core = 1.0 - smoothstep(core_radius * 0.70, core_radius, core_distance);
	// A slightly lower peak helps the orb and trail share the same energy budget.
	float core_brightness = mix(0.79, 0.96, core_pulse)
		* (1.0 + landing_charge * 0.18 + landing_flash * 0.70);
	vec3 live_core_color = mix(core_color, confirmation_core_color, landing_flash * 0.82);
	color = mix(color, live_core_color * core_brightness, core);

	float core_aura =
		1.0 - smoothstep(core_radius * 0.62, core_radius * 1.8, core_distance);
	color += aura_color * core_aura * (0.28 + landing_charge * 0.20) * aura_breath;
	color += confirmation_core_color * core_aura * landing_flash * 0.24;

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
