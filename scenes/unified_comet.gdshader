shader_type canvas_item;

uniform int palette_mode = 0;
uniform float fragment_alpha_boost = 1.0;
// UV.x follows the shared trail from head (0) to tail (1).
// UV.y runs across the shape: edge (0/1), centre (0.5).
void fragment() {
	float along = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);
	float center_energy = 1.0 - smoothstep(0.0, 0.95, abs(across * 2.0 - 1.0));
	float tail_fade = 1.0 - smoothstep(0.74, 1.0, along);
	float head_energy = 1.0 - smoothstep(0.02, 0.42, along);
	float flow = 0.94 + 0.06 * sin(along * 24.0 - TIME * 1.3 + across * 2.0);

	vec3 head_color;
	vec3 tail_color;
	vec3 inner_energy_color;
	if (palette_mode == 1) {
		head_color = vec3(0.52, 0.10, 0.96);
		tail_color = vec3(0.11, 0.014, 0.34);
		inner_energy_color = vec3(1.12, 0.52, 1.65);
	} else {
		head_color = vec3(0.035, 0.36, 0.92);
		tail_color = vec3(0.006, 0.035, 0.25);
		inner_energy_color = vec3(0.22, 0.88, 1.42);
	}

	vec3 body_color = mix(head_color, tail_color, smoothstep(0.06, 0.94, along));
	body_color = mix(body_color, inner_energy_color, center_energy * (0.14 + 0.16 * head_energy));
	body_color *= flow;

	// Keep the translucent skin continuous from the orb into the tail.
	// Landing fragments are supplied by the outer-aura layer, never this body.
	float translucent_body_alpha = mix(0.30, 0.10, smoothstep(0.02, 0.92, along));
	float body_alpha = translucent_body_alpha;
	float core_alpha = center_energy * 0.10 * head_energy;
	float alpha = clamp((body_alpha + core_alpha) * tail_fade, 0.0, 0.94);
	alpha = clamp(alpha * fragment_alpha_boost, 0.0, 0.94);

	COLOR = vec4(body_color, alpha);
}
