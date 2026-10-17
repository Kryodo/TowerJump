shader_type canvas_item;
render_mode blend_add;

// Rendered on a ribbon wider than TrailAura. The bright contour sits just
// outside the original aura boundary; a softer field spreads behind it.
uniform int palette_mode = 1;
uniform float rim_breath = 0.86;
uniform float rim_position : hint_range(0.45, 0.75, 0.001) = 0.5714;

void fragment() {
	float along = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);
	float edge_distance = abs(across * 2.0 - 1.0);
	float time = TIME;

	// Small travelling variations make the contour feel energized rather
	// than like a static outline. Both ribbon edges use the same flow.
	float contour_wobble =
		sin(along * 15.0 - time * 0.62) * 0.012
		+ sin(along * 27.0 + time * 0.41 + 0.9) * 0.007;
	float contour_position = rim_position + 0.026 + contour_wobble;
	float distance_to_contour = edge_distance - contour_position;

	// Reveal the rim only at / outside the original aura edge. The wider
	// carrier line gives the soft field room to fall away without clipping.
	float outer_reveal = smoothstep(
		rim_position - 0.012,
		rim_position + 0.035,
		edge_distance
	);
	float outer_falloff = 1.0 - smoothstep(
		rim_position + 0.24,
		1.0,
		edge_distance
	);

	float near_glow = exp(-pow(distance_to_contour / 0.065, 2.0));
	float wide_glow = exp(-pow((distance_to_contour - 0.035) / 0.16, 2.0));
	float contour = exp(-pow(distance_to_contour / 0.023, 2.0));

	float flow =
		0.87 + 0.13 * sin(
			along * 31.0 - time * 1.05
			+ 0.45 * sin(along * 8.0 + time * 0.35)
		);
	float strength = (
		near_glow * 0.19
		+ wide_glow * 0.075
		+ contour * 0.22
	) * outer_reveal * outer_falloff * flow * rim_breath;

	// The line's gradient alpha still fades the halo naturally into the tail.
	float alpha = clamp(strength, 0.0, 0.34) * COLOR.a;

	vec3 glow_color;
	vec3 contour_color;
	if (palette_mode == 1) {
		glow_color = vec3(0.42, 0.055, 1.0);
		contour_color = vec3(1.20, 0.45, 2.3);
	} else {
		glow_color = vec3(0.045, 0.52, 1.15);
		contour_color = vec3(0.34, 1.22, 2.35);
	}

	float contour_mix = clamp(contour / max(near_glow + wide_glow + contour, 0.001), 0.0, 1.0);
	vec3 halo_color = mix(glow_color, contour_color, contour_mix);
	COLOR = vec4(halo_color, alpha);
}
