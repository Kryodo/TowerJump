shader_type canvas_item;

// 0 = saturated electric blue, 1 = rich violet.
// The trail controller sets this so orb and trail share one palette.
uniform int palette_mode = 0;
uniform vec2 trail_direction = vec2(0.0, 1.0);
// Shared with the trail contour so both sides pulse in sync.
uniform float rim_breath = 1.0;

// Same deterministic noise family used by ball_trail_energy.gdshader.
// Reusing the trail's field structure keeps the texture turbulent rather than
// rendering a clean, unrelated stroke inside the orb.
float flow_hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float flow_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = flow_hash21(i);
	float b = flow_hash21(i + vec2(1.0, 0.0));
	float c = flow_hash21(i + vec2(0.0, 1.0));
	float d = flow_hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float flow_fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	value += flow_noise(p) * amplitude;
	p *= 2.0;
	amplitude *= 0.5;
	value += flow_noise(p) * amplitude;
	p *= 2.0;
	amplitude *= 0.5;
	value += flow_noise(p) * amplitude;
	return value;
}

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
	vec3 flow_base_color;
	vec3 flow_bright_color;
	vec3 flow_edge_color;
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
		flow_base_color = vec3(0.30, 0.035, 0.82);
		flow_bright_color = vec3(1.12, 0.68, 1.48);
		flow_edge_color = vec3(1.55, 0.88, 1.95);
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
		flow_base_color = vec3(0.025, 0.20, 0.95);
		flow_bright_color = vec3(0.46, 0.96, 1.48);
		flow_edge_color = vec3(0.58, 1.22, 1.82);
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

	// Carry the trail's broad, turbulent energy field into the orb. The
	// centerline remains continuous through the neck; once it reaches the core,
	// the same wide channel naturally fans into two curved lanes around it.
	vec2 trail_side_direction = vec2(
		-trail_direction_normalized.y,
		trail_direction_normalized.x
	);
	float flow_along = dot(p, trail_direction_normalized);
	float flow_side = dot(p, trail_side_direction);
	float flow_angle = abs(atan(flow_side, flow_along));
	float flow_progress = clamp(flow_angle / PI, 0.0, 1.0);

	// A noisy radius breaks the perfect semicircle while preserving one wide
	// continuous stream rather than two hairline strokes.
	float path_noise = flow_fbm(vec2(
		flow_progress * 3.2 - time * 0.12,
		abs(flow_side) * 4.0 + time * 0.08
	));
	float orbit_radius = 0.43
		+ (path_noise - 0.5) * 0.075
		+ 0.018 * sin(time * 1.25 + flow_progress * 6.0);
	float orbit_along = clamp(flow_along, -orbit_radius, orbit_radius);
	float branch_offset = sqrt(max(
		orbit_radius * orbit_radius - orbit_along * orbit_along,
		0.0
	));
	float branch_center = sign(flow_side) * branch_offset;
	float across_channel = flow_side - branch_center;

	// The half-width is in orb-radius units: 0.40 corresponds to roughly
	// 24 pixels across a 60-pixel ball, keeping the incoming channel close to
	// the trail's existing 26-pixel EnergyLine width.
	float flow_half_width = 0.40
		+ 0.018 * sin(time * 1.7 + flow_progress * 5.0);
	float channel_uv_y = 0.5 + across_channel / (2.0 * flow_half_width);

	// Reuse the trail shader's broad center energy, warped FBM plasma, finer
	// filaments, and soft base. The noise deforms the field across the whole
	// channel, so it reads as turbulent plasma—not a clean vector stripe.
	float channel_center = 1.0 - abs(channel_uv_y * 2.0 - 1.0);
	channel_center = smoothstep(0.0, 0.8, channel_center);
	vec2 flow_uv = vec2(flow_progress, channel_uv_y);
	vec2 flow_field_coord = flow_uv;
	flow_field_coord.x *= 7.0;
	flow_field_coord.y *= 3.0;
	flow_field_coord.x -= time * 0.9;

	float flow_distortion = flow_fbm(vec2(
		flow_field_coord.x * 0.7,
		flow_field_coord.y * 1.4 + time * 0.135
	));
	flow_field_coord.y += (flow_distortion - 0.5) * 1.25;

	float flow_field = flow_fbm(flow_field_coord * vec2(1.4, 2.2));
	flow_field = smoothstep(0.42, 0.72, flow_field);
	float flow_fine = flow_fbm(
		flow_field_coord * vec2(3.5, 4.5)
		+ vec2(-time * 0.63, time * 0.135)
	);
	flow_fine = smoothstep(0.55, 0.82, flow_fine);

	float flow_energy = (
		flow_field * 0.75
		+ flow_fine * 1.9
	) * channel_center;
	float flow_soft_base = channel_center * 1.5 * 0.34;
	flow_energy = flow_soft_base + flow_energy * 0.55;

	// Restrict the bright field to a broad, gently fading channel. The center
	// remains clear so the core is still the brightest point in the orb.
	float flow_core_clearance = smoothstep(
		core_radius * 0.99,
		core_radius * 1.42,
		core_distance
	);
	float flow_surface_fade = 1.0 - smoothstep(0.99, 1.06, d);
	float flow_front_fade = 1.0 - smoothstep(0.72, 0.99, flow_progress);
	float flow_visibility = flow_core_clearance * flow_surface_fade * flow_front_fade;

	// Match the trail shader's palette, keeping color and texture integrated
	// with the incoming stream rather than adding a separate neon stroke.
	vec3 flow_color = mix(
		flow_base_color,
		flow_bright_color,
		clamp(flow_energy, 0.0, 1.0)
	);
	float flow_edge_distance = abs(channel_uv_y * 2.0 - 1.0);
	float flow_edge_ridge =
		smoothstep(0.58, 0.76, flow_edge_distance)
		* (1.0 - smoothstep(0.88, 0.97, flow_edge_distance));
	float flow_edge_waver = 0.78 + 0.22 * sin(
		flow_progress * 25.0 - time * 1.53
		+ sin(flow_progress * 8.0 + time * 0.36)
	);
	float flow_edge_strength = flow_edge_ridge * flow_edge_waver * flow_visibility;

	float flow_blend = clamp(flow_energy * 0.64, 0.0, 0.86) * flow_visibility;
	color = mix(color, flow_color, flow_blend);
	color += flow_edge_color * flow_edge_strength * 0.22;

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
