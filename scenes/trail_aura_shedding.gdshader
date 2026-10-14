shader_type canvas_item;

uniform float shedding_amount = 1.0;
uniform vec4 shed_gap_0 = vec4(-1.0, -1.0, 0.0, 0.0);
uniform vec4 shed_gap_1 = vec4(-1.0, -1.0, 0.0, 0.0);
uniform vec4 shed_gap_2 = vec4(-1.0, -1.0, 0.0, 0.0);

float gap_coverage(vec4 interval, float along, float across) {
	if (interval.x < 0.0 || interval.y <= interval.x) {
		return 0.0;
	}
	// x/y are the source range; z/w are its exact start/end skew distances.
	// UV.y=0/1 follows the two ribbon edges, matching the detached polygon.
	float edge_factor = mix(0.12, 1.0, clamp(across, 0.0, 1.0));
	float start = interval.x + interval.z * edge_factor;
	float end = interval.y - interval.w * edge_factor;
	if (end <= start) {
		return 0.0;
	}
	float gap_width = end - start;
	float feather = min(0.003, gap_width * 0.16);
	return smoothstep(start, start + feather, along)
		* (1.0 - smoothstep(end - feather, end, along));
}

float shed_gap_mask(float along, float across) {
	float gap = max(
		gap_coverage(shed_gap_0, along, across),
		max(
			gap_coverage(shed_gap_1, along, across),
			gap_coverage(shed_gap_2, along, across)
		)
	);
	return 1.0 - gap;
}

void fragment() {
	vec4 aura_color = COLOR;
	float along = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);
	float source_gap_mask = shed_gap_mask(along, across);

	// One small decorative chevron belongs to the aura alone. Major gaps
	// across all layers still come exclusively from real landing detachments.
	float across_edge = abs(across * 2.0 - 1.0);
	float decorative_center = 0.28 + 0.035 * across_edge;
	float decorative_distance = abs(along - decorative_center);
	float decorative_cut = 1.0 - smoothstep(0.004, 0.013, decorative_distance);
	source_gap_mask *= 1.0 - decorative_cut;

	COLOR = vec4(aura_color.rgb, aura_color.a * source_gap_mask);
}
