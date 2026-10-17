shader_type canvas_item;

uniform int palette_mode = 0;
uniform float fragment_alpha_boost = 1.0;
// Keep this matched to ball_trail_energy.gdshader so both layers share a flow rhythm.
uniform float flow_speed = 0.9;
// Controls how strongly the moving current appears in the translucent skin.
uniform float surface_flow_strength : hint_range(0.0, 0.5) = 0.16;
// Low-amplitude edge waves alter the membrane's visible silhouette without moving geometry.
uniform float edge_undulation_strength : hint_range(0.0, 0.12) = 0.06;
uniform float pulse_progress = -1.0;
uniform float pulse_strength = 0.0;

// Deterministic noise shared with the inner energy shader.
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;

	value += noise(p) * amplitude;
	p *= 2.0;
	amplitude *= 0.5;

	value += noise(p) * amplitude;
	p *= 2.0;
	amplitude *= 0.5;

	value += noise(p) * amplitude;
	return value;
}

// UV.x follows the shared trail from head (0) to tail (1).
// UV.y runs across the shape: edge (0/1), centre (0.5).
void fragment() {
	float along = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);
	float center_energy = 1.0 - smoothstep(0.0, 0.95, abs(across * 2.0 - 1.0));
	float tail_fade = 1.0 - smoothstep(0.74, 1.0, along);
	float head_energy = 1.0 - smoothstep(0.02, 0.42, along);

	// Broad, layered waves travel along the outer boundary. They move the
	// visible membrane edge subtly, without perturbing the stable triangle mesh.
	float edge_time = TIME * flow_speed;
	float edge_wave =
		0.62 * sin(along * 12.0 - edge_time * 1.15
			+ sin(along * 4.8 + edge_time * 0.48) * 0.7)
		+ 0.25 * sin(along * 23.0 - edge_time * 1.65 + 1.2)
		+ 0.13 * sin(along * 7.0 + edge_time * 0.68);
	float edge_distance = abs(across * 2.0 - 1.0);
	float edge_threshold = 0.91 + edge_wave * edge_undulation_strength;
	float edge_fade = 1.0 - smoothstep(edge_threshold, edge_threshold + 0.075, edge_distance);

	float pulse_gate = step(0.0, pulse_progress);
	float pulse_band = (
		1.0 - smoothstep(0.025, 0.105, abs(along - pulse_progress))
	) * pulse_gate;
	float travelling_pulse = pulse_band * pulse_strength * tail_fade;
	float edge_mask = smoothstep(0.24, 0.82, abs(across * 2.0 - 1.0));

	float time = TIME * flow_speed;

	// Reuse the inner stream's warped noise coordinates so the body current
	// travels with its plasma instead of reading like a separate painted layer.
	vec2 p = vec2(along * 7.0, across * 3.0);
	p.x -= time;

	float distortion = fbm(vec2(p.x * 0.7, p.y * 1.4 + time * 0.15));
	p.y += (distortion - 0.5) * 2.0;

	float moving_field = smoothstep(0.42, 0.72, fbm(p * vec2(1.4, 2.2)));
	float moving_filaments = smoothstep(
		0.55,
		0.82,
		fbm(p * vec2(3.5, 4.5) + vec2(-time * 0.7, time * 0.15))
	);
	float surface_current = clamp(moving_field * 0.68 + moving_filaments * 0.32, 0.0, 1.0);
	// Keep traces visible in the membrane, while the central channel stays strongest.
	float surface_presence = surface_current
		* mix(0.38, 1.0, center_energy)
		* (0.78 + 0.22 * head_energy);

	// A restrained travelling pulse ties the translucent skin to the core flow.
	float flow = 0.96 + 0.04 * sin(
		along * 24.0 - time * 1.7
		+ sin(along * 8.0 + time * 0.4)
		+ across * 2.0
	);

	vec3 head_color;
	vec3 tail_color;
	vec3 inner_energy_color;
	vec3 pulse_color;
	if (palette_mode == 1) {
		head_color = vec3(0.52, 0.10, 0.96);
		tail_color = vec3(0.11, 0.014, 0.34);
		inner_energy_color = vec3(1.12, 0.52, 1.65);
		pulse_color = vec3(1.55, 0.78, 1.95);
	} else {
		head_color = vec3(0.035, 0.36, 0.92);
		tail_color = vec3(0.006, 0.035, 0.25);
		inner_energy_color = vec3(0.22, 0.88, 1.42);
		pulse_color = vec3(0.70, 1.38, 1.90);
	}

	vec3 body_color = mix(head_color, tail_color, smoothstep(0.06, 0.94, along));
	float core_influence = center_energy * (0.14 + 0.16 * head_energy);
	core_influence += surface_presence * surface_flow_strength;
	core_influence += travelling_pulse * 0.20;
	body_color = mix(body_color, inner_energy_color, clamp(core_influence, 0.0, 0.65));
	body_color *= flow;
	// The travelling current briefly lights the membrane's outer edges as well as its core.
	body_color += pulse_color * travelling_pulse * edge_mask * 0.52;

	// Keep the skin continuous and translucent; the pulse changes its visible light
	// without disturbing mesh geometry or physically shifting the outer edges.
	float translucent_body_alpha = mix(0.30, 0.10, smoothstep(0.02, 0.92, along));
	float body_alpha = translucent_body_alpha * mix(0.93, 1.06, surface_presence);
	float core_alpha = center_energy * (0.10 + surface_current * 0.02) * head_energy;
	float pulse_alpha = travelling_pulse * (0.025 + edge_mask * 0.11);
	float alpha = clamp((body_alpha + core_alpha + pulse_alpha) * tail_fade, 0.0, 0.94);
	alpha = clamp(alpha * fragment_alpha_boost, 0.0, 0.94);
	alpha *= edge_fade;

	COLOR = vec4(body_color, alpha);
}
