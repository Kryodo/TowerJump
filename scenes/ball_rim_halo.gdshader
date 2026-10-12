shader_type canvas_item;

// Low-key outer energy field for the ball. The sprite is drawn behind the orb,
// with its own larger scale so only the soft region beyond the rim remains visible.
uniform int palette_mode = 1;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float time = TIME;
	float d = length(p);

	// Very small angular distortion keeps this reading as energy rather than a ring.
	float ripple =
		0.012 * sin(angle * 3.0 - time * 0.8)
		+ 0.006 * sin(angle * 5.0 + time * 1.1);
	float radius = d + ripple;

	float inner_fade = smoothstep(0.80, 0.93, radius);
	float outer_fade = 1.0 - smoothstep(1.00, 1.28, radius);
	float halo = inner_fade * outer_fade;

	float breathing = 0.5 + 0.5 * sin(time * 1.15 + 0.6);
	float flow = 0.90 + 0.10 * (0.5 + 0.5 * sin(angle * 3.0 - time * 0.75));

	vec3 halo_color;
	if (palette_mode == 1) {
		halo_color = vec3(2.7, 0.72, 4.5);
	} else {
		halo_color = vec3(0.30, 2.7, 4.5);
	}

	float alpha = halo * mix(0.095, 0.15, breathing) * flow;
	COLOR = vec4(halo_color * flow, alpha);
}
