shader_type canvas_item;
render_mode blend_add;

// This sprite is larger than the orb. The body itself is still drawn by
// ball.gdshader; this layer contributes only the atmosphere around its edge.
uniform int palette_mode = 0;
uniform float rim_breath = 1.0;
uniform float body_radius : hint_range(0.55, 0.90, 0.001) = 0.755;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float angle = atan(p.y, p.x);
	float time = TIME;

	// Tiny, slow variations keep the field from reading as a perfect neon ring.
	float contour_wobble =
		sin(angle * 3.0 - time * 0.72) * 0.0055
		+ sin(angle * 5.0 + time * 0.47 + 1.4) * 0.0035;
	float contour_radius = body_radius + 0.014 + contour_wobble;

	float outside_distance = max(d - body_radius, 0.0);
	float edge_reveal = smoothstep(body_radius - 0.008, body_radius + 0.035, d);
	float field_falloff =
		1.0 - smoothstep(body_radius + 0.105, body_radius + 0.245, d);

	// A compact glow carries the energy at the surface; a wider, softer
	// component expands outward to create depth instead of a single outline.
	float near_glow = exp(-pow(outside_distance / 0.070, 2.0));
	float wide_glow = exp(-pow(outside_distance / 0.165, 2.0));

	float angular_flow =
		0.5 + 0.5 * sin(
			angle * 4.0 - time * 0.95
			+ 0.4 * sin(angle * 2.0 + time * 0.38)
		);
	float organic_variation = 0.86 + angular_flow * 0.14;

	float field_strength =
		(near_glow * 0.20 + wide_glow * 0.105)
		* edge_reveal
		* field_falloff
		* organic_variation
		* rim_breath;

	float contour = exp(-pow((d - contour_radius) / 0.027, 2.0));
	float contour_strength = contour * edge_reveal * field_falloff * 0.24 * rim_breath;
	float strength = clamp(field_strength + contour_strength, 0.0, 0.42);

	vec3 glow_color;
	vec3 contour_color;
	if (palette_mode == 1) {
		glow_color = vec3(0.42, 0.055, 1.0);
		contour_color = vec3(1.20, 0.45, 2.3);
	} else {
		glow_color = vec3(0.045, 0.52, 1.15);
		contour_color = vec3(0.34, 1.22, 2.35);
	}

	float contour_mix = clamp(contour_strength / max(strength, 0.001), 0.0, 1.0);
	vec3 field_color = mix(glow_color, contour_color, contour_mix);
	COLOR = vec4(field_color, strength);
}
