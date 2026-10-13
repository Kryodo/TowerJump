shader_type canvas_item;

uniform int palette_mode = 1;
uniform vec2 trail_direction = vec2(0.0, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float angle = atan(p.y, p.x);
	float time = TIME;

	// A narrow secondary contour just outside the orb's main rim.
	// Tiny radial waves make it feel alive without reading as a second filled aura.
	float ripple =
		0.006 * sin(angle * 3.0 - time * 0.78)
		+ 0.003 * sin(angle * 5.0 + time * 1.05 + 0.7);
	float radius = d + ripple;

	float outer_rim =
		smoothstep(0.885, 0.935, radius)
		*
		(1.0 - smoothstep(0.972, 1.035, radius));

	// The unified silhouette takes over from this rim at the trail-facing side.
	vec2 radial_direction = p / max(d, 0.001);
	vec2 tail_direction_normalized = trail_direction / max(length(trail_direction), 0.001);
	float tail_alignment = dot(radial_direction, tail_direction_normalized);
	float shared_join = smoothstep(0.38, 0.88, tail_alignment);
	// The secondary halo should softly support the contour at the neck rather
	// than vanish completely where the ball transitions into the tail.
	outer_rim *= mix(1.0, 0.24, shared_join);

	float travelling_energy =
		0.72
		+ 0.28 * (0.5 + 0.5 * sin(angle * 3.0 - time * 0.9 + sin(angle * 2.0)));

	float breathing = 0.5 + 0.5 * sin(time * 1.12 + 0.4);

	vec3 rim_color;
	if (palette_mode == 1) {
		rim_color = vec3(1.55, 0.48, 2.65);
	} else {
		rim_color = vec3(0.26, 1.42, 2.5);
	}

	float alpha = outer_rim * travelling_energy * mix(0.065, 0.112, breathing);
	COLOR = vec4(rim_color * travelling_energy, alpha);
}
