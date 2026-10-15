shader_type canvas_item;

// Transverse alpha cutouts adapted from the proven crack-distance mask in
// experiment-comet-crack-masking. Positions follow the fragment-gap rhythm
// of experiment-comet-shedding, starting after the connected ~38% head.
//
// Line2D UV convention used by the working crack mask:
// UV.x = along the trail; UV.y = across its width.
// The trail remains one continuous Line2D; only alpha is removed.
uniform float cutout_strength = 1.0;

float crack_segment_distance(vec2 uv, vec2 start_uv, vec2 end_uv) {
	vec2 pa = uv - start_uv;
	vec2 ba = end_uv - start_uv;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.000001), 0.0, 1.0);
	return length(pa - ba * h);
}

// Each fracture crosses almost the entire ribbon width, with small alternating
// jogs along the trail axis. This reproduces chipped, oblique fragment edges
// rather than producing a field of isolated interior cells.
float gap_0_distance(vec2 uv) {
	return min(
		min(
			min(crack_segment_distance(uv, vec2(0.389, 0.000), vec2(0.405, 0.200)),
				crack_segment_distance(uv, vec2(0.405, 0.200), vec2(0.394, 0.400))),
			min(crack_segment_distance(uv, vec2(0.394, 0.400), vec2(0.412, 0.600)),
				crack_segment_distance(uv, vec2(0.412, 0.600), vec2(0.399, 0.800)))
		),
		crack_segment_distance(uv, vec2(0.399, 0.800), vec2(0.408, 1.000))
	);
}

float gap_1_distance(vec2 uv) {
	return min(
		min(
			min(crack_segment_distance(uv, vec2(0.492, 0.000), vec2(0.508, 0.200)),
				crack_segment_distance(uv, vec2(0.508, 0.200), vec2(0.498, 0.400))),
			min(crack_segment_distance(uv, vec2(0.498, 0.400), vec2(0.515, 0.600)),
				crack_segment_distance(uv, vec2(0.515, 0.600), vec2(0.502, 0.800)))
		),
		crack_segment_distance(uv, vec2(0.502, 0.800), vec2(0.511, 1.000))
	);
}

float gap_2_distance(vec2 uv) {
	return min(
		min(
			min(crack_segment_distance(uv, vec2(0.618, 0.000), vec2(0.602, 0.200)),
				crack_segment_distance(uv, vec2(0.602, 0.200), vec2(0.615, 0.400))),
			min(crack_segment_distance(uv, vec2(0.615, 0.400), vec2(0.598, 0.600)),
				crack_segment_distance(uv, vec2(0.598, 0.600), vec2(0.611, 0.800)))
		),
		crack_segment_distance(uv, vec2(0.611, 0.800), vec2(0.602, 1.000))
	);
}

float gap_3_distance(vec2 uv) {
	return min(
		min(
			min(crack_segment_distance(uv, vec2(0.700, 0.000), vec2(0.717, 0.200)),
				crack_segment_distance(uv, vec2(0.717, 0.200), vec2(0.706, 0.400))),
			min(crack_segment_distance(uv, vec2(0.706, 0.400), vec2(0.723, 0.600)),
				crack_segment_distance(uv, vec2(0.723, 0.600), vec2(0.708, 0.800)))
		),
		crack_segment_distance(uv, vec2(0.708, 0.800), vec2(0.716, 1.000))
	);
}

float gap_4_distance(vec2 uv) {
	return min(
		min(
			min(crack_segment_distance(uv, vec2(0.825, 0.000), vec2(0.807, 0.200)),
				crack_segment_distance(uv, vec2(0.807, 0.200), vec2(0.821, 0.400))),
			min(crack_segment_distance(uv, vec2(0.821, 0.400), vec2(0.803, 0.600)),
				crack_segment_distance(uv, vec2(0.803, 0.600), vec2(0.817, 0.800)))
		),
		crack_segment_distance(uv, vec2(0.817, 0.800), vec2(0.808, 1.000))
	);
}

float gap_5_distance(vec2 uv) {
	return min(
		min(
			min(crack_segment_distance(uv, vec2(0.905, 0.000), vec2(0.923, 0.200)),
				crack_segment_distance(uv, vec2(0.923, 0.200), vec2(0.911, 0.400))),
			min(crack_segment_distance(uv, vec2(0.911, 0.400), vec2(0.927, 0.600)),
				crack_segment_distance(uv, vec2(0.927, 0.600), vec2(0.913, 0.800)))
		),
		crack_segment_distance(uv, vec2(0.913, 0.800), vec2(0.921, 1.000))
	);
}

float fracture_keep(vec2 uv) {
	// The first cut marks the end of the connected head. Subsequent cuts
	// separate long surviving sections all the way toward the tail.
	float d0 = gap_0_distance(uv);
	float d1 = gap_1_distance(uv);
	float d2 = gap_2_distance(uv);
	float d3 = gap_3_distance(uv);
	float d4 = gap_4_distance(uv);
	float d5 = gap_5_distance(uv);

	float cut0 = 1.0 - smoothstep(0.008, 0.023, d0);
	float cut1 = 1.0 - smoothstep(0.010, 0.027, d1);
	float cut2 = 1.0 - smoothstep(0.008, 0.024, d2);
	float cut3 = 1.0 - smoothstep(0.011, 0.028, d3);
	float cut4 = 1.0 - smoothstep(0.008, 0.023, d4);
	float cut5 = 1.0 - smoothstep(0.010, 0.026, d5);

	float cut = max(max(max(cut0, cut1), max(cut2, cut3)), max(cut4, cut5));
	return 1.0 - cut;
}

void fragment() {
	vec4 aura = COLOR;
	float crack_mask = fracture_keep(UV);
	float keep_surface = mix(1.0, crack_mask, clamp(cutout_strength, 0.0, 1.0));

	// Fully remove the core of each cut; the soft edge is only anti-aliasing.
	// EnergyLine is a separate draw call and is intentionally left untouched.
	if (keep_surface < 0.08 && cutout_strength >= 0.99) {
		discard;
	}
	aura.a *= keep_surface;
	COLOR = aura;
}
