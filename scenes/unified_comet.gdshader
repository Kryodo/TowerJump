shader_type canvas_item;

uniform int palette_mode = 0;
uniform float fragment_alpha_boost = 1.0;
uniform float crack_along_scale = 1.0;

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
	float cut_long = 1.0 - smoothstep(0.020, 0.043, long_crack);

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
	float cut_side = 1.0 - smoothstep(0.014, 0.032, side_crack);

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
	float cut_cross = 1.0 - smoothstep(0.017, 0.037, cross_crack);

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
	float cut_lower = 1.0 - smoothstep(0.013, 0.029, lower_crack);

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
	float cut_branch = 1.0 - smoothstep(0.010, 0.023, branch_crack);

	float cut = max(max(cut_long, cut_side), max(max(cut_cross, cut_lower), cut_branch));
	return 1.0 - cut;
}


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
	alpha *= crack_keep(UV);

	COLOR = vec4(body_color, alpha);
}
