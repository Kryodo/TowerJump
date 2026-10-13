shader_type canvas_item;

// 0 = saturated electric blue, 1 = rich violet.
// The trail controller sets this so orb and trail share one palette.
uniform int palette_mode = 0;
uniform vec2 trail_direction = vec2(0.0, 1.0);
// Shared with the trail contour so both sides pulse in sync.
uniform float rim_breath = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float time = TIME;
	float mask = texture(TEXTURE, UV).a;

	float breathing = 0.5 + 0.5 * sin(time * 1.35);
	float aura_breath = mix(0.72, 1.0, breathing);

	vec3 inner_body;
	vec3 outer_body;
	vec3 moving_energy;
	vec3 inner_energy_color;
	vec3 transition_color;
	vec3 ring_color;
	vec3 trail_flow_color;
	vec3 trail_flow_halo_color;
	vec3 core_color;
	vec3 aura_color;
	vec3 highlight_color;
	vec3 glint_color;

	if (palette_mode == 1) {
		inner_body = vec3(0.28, 0.035, 0.68);
		outer_body = vec3(0.045, 0.006, 0.16);
		moving_energy = vec3(0.52, 0.12, 1.25);
		inner_energy_color = vec3(0.58, 0.10, 1.5);
		transition_color = vec3(0.34, 0.045, 0.78);
		ring_color = vec3(2.7, 0.55, 5.2);
		trail_flow_color = vec3(1.55, 0.28, 3.2);
		trail_flow_halo_color = vec3(0.62, 0.09, 1.45);
		core_color = vec3(4.0, 3.25, 6.2);
		aura_color = vec3(1.45, 0.22, 3.1);
		highlight_color = vec3(1.0, 0.72, 1.5);
		glint_color = vec3(2.0, 1.55, 2.8);
	} else {
		inner_body = vec3(0.018, 0.22, 0.62);
		outer_body = vec3(0.003, 0.028, 0.15);
		moving_energy = vec3(0.04, 0.48, 1.25);
		inner_energy_color = vec3(0.025, 0.32, 1.05);
		transition_color = vec3(0.025, 0.20, 0.68);
		ring_color = vec3(0.18, 2.15, 5.2);
		trail_flow_color = vec3(0.10, 1.15, 2.75);
		trail_flow_halo_color = vec3(0.015, 0.42, 1.25);
		core_color = vec3(3.2, 5.1, 6.3);
		aura_color = vec3(0.04, 1.25, 3.0);
		highlight_color = vec3(0.65, 1.45, 2.25);
		glint_color = vec3(1.5, 2.5, 3.2);
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

	// Preserve the orb's rim, but let it yield locally where the trail enters.
	// This creates a soft neck opening rather than a complete missing lower arc.
	float outer_ring =
		smoothstep(0.90, 0.93, d)
		-
		smoothstep(0.956, 0.982, d);
	vec2 radial_direction = p / max(d, 0.001);
	vec2 trail_direction_normalized = trail_direction / max(length(trail_direction), 0.001);
	float tail_alignment = dot(radial_direction, trail_direction_normalized);
	float neck_cut = smoothstep(0.58, 0.84, tail_alignment);
	float ring_visibility = 1.0 - 0.88 * neck_cut;
	// Slightly reduce the rim overall so it doesn't overpower the shared contour.
	color += ring_color * outer_ring * rim_breath * 0.86 * ring_visibility;

	// The luminous centre gently pulses, but its edge is deliberately organic:
	// low-frequency angular waves break the perfect circular silhouette.
	float core_pulse = 0.5 + 0.5 * sin(time * 2.2);
	float core_radius = mix(0.245, 0.305, core_pulse);
	float core_wobble =
		1.0
		+ 0.10 * sin(angle * 3.0 + time * 0.72)
		+ 0.045 * sin(angle * 5.0 - time * 0.90 + 1.1)
		+ 0.025 * sin(angle * 2.0 + p.x * 2.8 - time * 0.55);
	float core_distance = d / max(core_wobble, 0.80);
	float core = 1.0 - smoothstep(core_radius * 0.70, core_radius, core_distance);
	// A slightly lower peak helps the orb and trail share the same energy budget.
	float core_brightness = mix(0.79, 0.96, core_pulse);
	color = mix(color, core_color * core_brightness, core);

	float core_aura =
		1.0 - smoothstep(core_radius * 0.62, core_radius * 1.8, core_distance);
	color += aura_color * core_aura * 0.28 * aura_breath;

	// Pull a live ribbon of energy in through the neck. Once inside the orb,
	// the single channel splits into two curved branches around the bright core.
	// The branches stay outside the core itself, then fade on the forward side.
	vec2 trail_side_direction = vec2(
		-trail_direction_normalized.y,
		trail_direction_normalized.x
	);
	float flow_along = dot(p, trail_direction_normalized);
	float flow_side = dot(p, trail_side_direction);
	float orbit_radius = 0.405 + 0.012 * sin(time * 1.25 + flow_along * 4.0);
	float orbit_along = clamp(flow_along, -orbit_radius, orbit_radius);
	float branch_offset = sqrt(max(
		orbit_radius * orbit_radius - orbit_along * orbit_along,
		0.0
	));
	float spread_amount = smoothstep(0.0, 0.20, orbit_radius - flow_along);
	float branch_wobble = spread_amount * (
		0.014 * sin(time * 2.1 - flow_along * 7.0 + abs(flow_side) * 5.0)
	);
	float branch_distance = abs(
		abs(flow_side) - max(branch_offset + branch_wobble, 0.0)
	);
	float flow_width = 0.034 + 0.006 * sin(time * 1.7 + flow_along * 5.0);
	float flow_line = 1.0 - smoothstep(flow_width, flow_width + 0.042, branch_distance);
	float flow_halo = 1.0 - smoothstep(
		flow_width + 0.015,
		flow_width + 0.135,
		branch_distance
	);
	float flow_pulse = 0.72 + 0.28 * (
		0.5 + 0.5 * sin(
			time * 4.0 - flow_along * 13.0
			+ sign(flow_side) * 1.3
			+ sin(flow_side * 8.0 + time * 1.1) * 0.45
		)
	);
	float flow_forward_fade = smoothstep(-0.40, -0.18, flow_along);
	float flow_surface_fade = 1.0 - smoothstep(0.99, 1.06, d);
	float flow_core_clearance = smoothstep(
		core_radius * 1.08,
		core_radius * 1.42,
		core_distance
	);
	float flow_visibility = flow_pulse * flow_forward_fade
		* flow_surface_fade * flow_core_clearance;
	color += trail_flow_color * flow_line * flow_visibility * 0.78;
	color += trail_flow_halo_color * flow_halo * flow_visibility * 0.20;

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
