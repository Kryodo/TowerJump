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

	// Let the secondary contour dissolve into the trail at its exit point.
	vec2 radial_direction = p / max(d, 0.001);
	vec2 normalized_trail_direction = trail_direction / max(length(trail_direction), 0.001);
	float trail_alignment = dot(radial_direction, normalized_trail_direction);
	// Make the secondary rim visibly dissolve into the comet's exit collar,
	// while retaining a faint residual glow rather than a hard cut-out.
	float trail_exit_fade = smoothstep(0.40, 0.90, trail_alignment);
	float exit_visibility = mix(1.0, 0.04, trail_exit_fade);
	outer_rim *= exit_visibility;

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

	float alpha = outer_rim * travelling_energy * mix(0.055, 0.105, breathing);
	COLOR = vec4(rim_color * travelling_energy, alpha);
}
