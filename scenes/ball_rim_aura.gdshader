shader_type canvas_item;

uniform int palette_mode = 1;

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

	float alpha = outer_rim * travelling_energy * mix(0.045, 0.085, breathing);
	COLOR = vec4(rim_color * travelling_energy, alpha);
}
