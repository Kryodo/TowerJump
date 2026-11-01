shader_type canvas_item;
render_mode unshaded;

// This shader only changes existing glyph pixels. The energy lives in the
// text itself: a soft, travelling highlight follows a diagonal flow path.
uniform float flow_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flow_tint : source_color = vec4(0.40, 0.86, 1.0, 1.0);
uniform float flow_speed : hint_range(0.0, 60.0) = 26.0;
uniform float flow_period : hint_range(60.0, 180.0) = 92.0;

varying vec2 indicator_position;

void vertex() {
	indicator_position = VERTEX;
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV) * COLOR;

	float diagonal_position = indicator_position.x - indicator_position.y * 0.62;
	float flow_phase = mod(diagonal_position - TIME * flow_speed, flow_period);
	float wrapped_distance = min(flow_phase, flow_period - flow_phase);

	// A continuous, low-amplitude current keeps the glyphs feeling energized
	// between the brighter traveling threads instead of leaving long dead gaps.
	float broad_wave = 0.5 + 0.5 * sin(
		diagonal_position * 0.052 - TIME * 1.55
		+ 0.35 * sin(diagonal_position * 0.028 + TIME * 0.7)
	);
	float secondary_wave = 0.5 + 0.5 * sin(
		diagonal_position * 0.094 - TIME * 2.05 + 1.8
	);
	float current_wave = clamp(broad_wave * 0.72 + secondary_wave * 0.28, 0.0, 1.0);

	// The highlight is deliberately broader and brighter now, while staying
	// clipped to glyph alpha so no detached bars or background shapes appear.
	float soft_flow = exp(-pow(wrapped_distance / 18.0, 2.0));
	float bright_thread = exp(-pow(wrapped_distance / 5.4, 2.0));
	float energy = clamp(flow_strength, 0.0, 1.0);

	vec3 highlight_color = mix(flow_tint.rgb, vec3(1.0), 0.62);
	vec3 current_color = mix(flow_tint.rgb, vec3(1.0), 0.30 + current_wave * 0.28);
	float current_weight = energy * (0.18 + current_wave * 0.22);
	glyph.rgb = mix(glyph.rgb, max(glyph.rgb, current_color), current_weight);

	float highlight_weight = clamp(
		energy * (0.28 * soft_flow + 0.78 * bright_thread),
		0.0,
		0.84
	);
	glyph.rgb = mix(glyph.rgb, max(glyph.rgb, highlight_color), highlight_weight);
	glyph.rgb += flow_tint.rgb * energy * (0.035 + current_wave * 0.035);

	COLOR = glyph;
}
