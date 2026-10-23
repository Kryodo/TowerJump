shader_type canvas_item;
render_mode unshaded;

// This shader only changes existing glyph pixels. The energy lives in the
// text itself: a soft, travelling highlight follows a diagonal flow path.
uniform float flow_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flow_tint : source_color = vec4(0.40, 0.86, 1.0, 1.0);
uniform float flow_speed : hint_range(0.0, 60.0) = 26.0;
uniform float flow_period : hint_range(60.0, 180.0) = 138.0;

varying vec2 indicator_position;

void vertex() {
	indicator_position = VERTEX;
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV) * COLOR;

	float diagonal_position = indicator_position.x - indicator_position.y * 0.62;
	float flow_phase = mod(diagonal_position - TIME * flow_speed, flow_period);
	float wrapped_distance = min(flow_phase, flow_period - flow_phase);

	// A narrow, soft thread with a faint wake feels like energy running through
	// letter strokes, not a shape or panel drawn behind the indicator.
	float soft_flow = exp(-pow(wrapped_distance / 12.0, 2.0));
	float bright_thread = exp(-pow(wrapped_distance / 4.2, 2.0));
	float energy = clamp(flow_strength, 0.0, 1.0);

	vec3 highlight_color = mix(flow_tint.rgb, vec3(1.0), 0.38);
	float highlight_weight = clamp(
		energy * (0.16 * soft_flow + 0.62 * bright_thread),
		0.0,
		0.78
	);
	glyph.rgb = mix(glyph.rgb, max(glyph.rgb, highlight_color), highlight_weight);
	glyph.rgb += flow_tint.rgb * energy * soft_flow * 0.026;

	COLOR = glyph;
}
