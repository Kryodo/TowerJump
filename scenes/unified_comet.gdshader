shader_type canvas_item;

uniform int palette_mode = 0;
uniform float shedding_amount = 1.0;
uniform float solid_piece = 0.0;
uniform vec4 shed_gap_0 = vec4(-1.0, -1.0, 0.0, 0.0);
uniform vec4 shed_gap_1 = vec4(-1.0, -1.0, 0.0, 0.0);
uniform vec4 shed_gap_2 = vec4(-1.0, -1.0, 0.0, 0.0);

float gap_coverage(vec4 interval, float along, float across) {
	if (interval.x < 0.0 || interval.y <= interval.x) {
		return 0.0;
	}
	float base_width = interval.y - interval.x;
	// Move the gap center across the ribbon to form a shallow chevron cut.
	float shaped_center = (interval.x + interval.y) * 0.5
		+ interval.z * abs(across * 2.0 - 1.0);
	float start = shaped_center - base_width * 0.5;
	float end = shaped_center + base_width * 0.5;
	float feather = min(0.003, base_width * 0.16);
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

	// The connected neck and detached islands share the same soft plasma body.
	// Landing-triggered gaps are supplied through shed_gap_mask below.
	float translucent_body_alpha = mix(0.30, 0.10, smoothstep(0.02, 0.92, along));
	// Separate polygons receive a modest alpha lift, not an opaque-material
	// switch. They should read as the same plasma body with edges removed.
	float body_alpha = translucent_body_alpha * mix(1.0, 1.35, solid_piece);
	float core_alpha = center_energy * 0.10 * head_energy * (1.0 - solid_piece);
	float alpha = clamp((body_alpha + core_alpha) * tail_fade, 0.0, 0.94);

	// A live detachment event is the only source of a full missing interval.
	// Do not keep decorative shader cracks running across the entire trail.
	alpha *= shed_gap_mask(along, across);

	COLOR = vec4(body_color, alpha);
}
