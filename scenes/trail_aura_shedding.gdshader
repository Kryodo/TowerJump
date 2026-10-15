shader_type canvas_item;

uniform float crack_along_scale = 1.0;
uniform float crack_width_scale = 1.8;
uniform float shedding_amount = 1.0;

float crack_segment_distance(vec2 uv, vec2 start_uv, vec2 end_uv) {
	float scale = max(crack_along_scale, 1.0);
	vec2 p = vec2(uv.x * scale, uv.y);
	vec2 a = vec2(start_uv.x * scale, start_uv.y);
	vec2 b = vec2(end_uv.x * scale, end_uv.y);
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.000001), 0.0, 1.0);
	return length(pa - ba * h);
}

float crack_keep(vec2 uv) {
	// One long, broad, heavily angled fracture reaching almost edge-to-edge.
	float long_crack = min(
		min(
			min(
				crack_segment_distance(uv, vec2(0.220, 0.025), vec2(0.247, 0.160)),
				crack_segment_distance(uv, vec2(0.247, 0.160), vec2(0.216, 0.300))
			),
			min(
				crack_segment_distance(uv, vec2(0.216, 0.300), vec2(0.253, 0.435)),
				crack_segment_distance(uv, vec2(0.253, 0.435), vec2(0.226, 0.580))
			)
		),
		min(
			crack_segment_distance(uv, vec2(0.226, 0.580), vec2(0.258, 0.735)),
			crack_segment_distance(uv, vec2(0.258, 0.735), vec2(0.236, 0.945))
		)
	);
	float cut_long = 1.0 - smoothstep(0.020 * crack_width_scale, 0.043 * crack_width_scale, long_crack);

	// A separate hooked split starts well inside the trail and runs out to one edge.
	float side_crack = min(
		min(
			crack_segment_distance(uv, vec2(0.408, 0.505), vec2(0.440, 0.625)),
			crack_segment_distance(uv, vec2(0.440, 0.625), vec2(0.416, 0.750))
		),
		min(
			crack_segment_distance(uv, vec2(0.416, 0.750), vec2(0.453, 0.865)),
			crack_segment_distance(uv, vec2(0.453, 0.865), vec2(0.434, 0.985))
		)
	);
	float cut_side = 1.0 - smoothstep(0.014 * crack_width_scale, 0.032 * crack_width_scale, side_crack);

	// This one starts at the opposite edge and travels through most of the body.
	float cross_crack = min(
		min(
			min(
				crack_segment_distance(uv, vec2(0.664, 0.025), vec2(0.632, 0.155)),
				crack_segment_distance(uv, vec2(0.632, 0.155), vec2(0.666, 0.285))
			),
			min(
				crack_segment_distance(uv, vec2(0.666, 0.285), vec2(0.636, 0.400)),
				crack_segment_distance(uv, vec2(0.636, 0.400), vec2(0.660, 0.525))
			)
		),
		min(
			crack_segment_distance(uv, vec2(0.660, 0.525), vec2(0.640, 0.635)),
			crack_segment_distance(uv, vec2(0.640, 0.635), vec2(0.671, 0.755))
		)
	);
	float cut_cross = 1.0 - smoothstep(0.017 * crack_width_scale, 0.037 * crack_width_scale, cross_crack);

	// Shorter, narrower, irregular fracture near the lower body.
	float lower_crack = min(
		min(
			crack_segment_distance(uv, vec2(0.827, 0.265), vec2(0.800, 0.395)),
			crack_segment_distance(uv, vec2(0.800, 0.395), vec2(0.836, 0.520))
		),
		min(
			crack_segment_distance(uv, vec2(0.836, 0.520), vec2(0.793, 0.665)),
			min(
				crack_segment_distance(uv, vec2(0.793, 0.665), vec2(0.822, 0.795)),
				crack_segment_distance(uv, vec2(0.822, 0.795), vec2(0.798, 0.935))
			)
		)
	);
	float cut_lower = 1.0 - smoothstep(0.013 * crack_width_scale, 0.029 * crack_width_scale, lower_crack);

	// A small branching spur makes the pattern feel fractured, not repeated.
	float branch_crack = min(
		min(
			crack_segment_distance(uv, vec2(0.286, 0.365), vec2(0.318, 0.430)),
			crack_segment_distance(uv, vec2(0.318, 0.430), vec2(0.297, 0.505))
		),
		min(
			crack_segment_distance(uv, vec2(0.297, 0.505), vec2(0.330, 0.568)),
			crack_segment_distance(uv, vec2(0.330, 0.568), vec2(0.315, 0.632))
		)
	);
	float cut_branch = 1.0 - smoothstep(0.010 * crack_width_scale, 0.023 * crack_width_scale, branch_crack);

	float cut = max(max(cut_long, cut_side), max(max(cut_cross, cut_lower), cut_branch));
	return 1.0 - cut;
}


void fragment() {
	// Preserve TrailAura's existing gradient, color, and alpha profile.
	// Only the designed fissures reduce alpha, reaching zero inside each cut.
	vec4 aura = COLOR;
	float crack_mask = crack_keep(UV);
	float keep_surface = mix(1.0, crack_mask, clamp(shedding_amount, 0.0, 1.0));
	aura.a *= keep_surface;
	COLOR = aura;
}
