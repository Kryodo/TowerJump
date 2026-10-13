shader_type canvas_item;

uniform int palette_mode = 0;
uniform float shedding_amount = 1.0;

float hash_cell(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Stable Voronoi-like fracture cells. Their borders create narrow cracks,
// while a subset of cells disappears to make the skin look physically shed.
float shedding_pattern(vec2 uv) {
	vec2 p = vec2(uv.x * 10.5, uv.y * 3.0);
	vec2 base_cell = floor(p);
	vec2 local_pos = fract(p);
	float nearest_distance = 10.0;
	float second_distance = 10.0;
	vec2 nearest_cell = base_cell;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 cell_id = base_cell + neighbor;
			vec2 jitter = vec2(
				hash_cell(cell_id + vec2(2.71, 8.13)),
				hash_cell(cell_id + vec2(17.23, 4.21))
			);
			vec2 site = neighbor + vec2(0.20) + jitter * 0.60;
			float site_distance = length(local_pos - site);
			if (site_distance < nearest_distance) {
				second_distance = nearest_distance;
				nearest_distance = site_distance;
				nearest_cell = cell_id;
			} else if (site_distance < second_distance) {
				second_distance = site_distance;
			}
		}
	}

	float border_distance = max(second_distance - nearest_distance, 0.0);
	float shard_interior = smoothstep(0.018, 0.072, border_distance);
	float shard_kept = 1.0 - smoothstep(
		0.40,
		0.70,
		hash_cell(nearest_cell + vec2(7.7, 19.3))
	);
	return shard_interior * shard_kept;
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

	// A translucent unified skin sits above the old trail strokes. The flow and
	// fragments remain visible beneath it, while the exposed contour defines the
	// actual silhouette. The orb sprite is drawn later and preserves its core.
	float body_alpha = mix(0.30, 0.10, smoothstep(0.02, 0.92, along));
	float core_alpha = center_energy * 0.10 * head_energy;
	float alpha = clamp((body_alpha + core_alpha) * tail_fade, 0.0, 0.42);

	// The upper trail remains coherent. Fracture damage accumulates farther
	// down the tail, exposing transparent gaps between surviving plasma pieces.
	float fracture_progress = smoothstep(0.36, 0.78, along) * shedding_amount;
	float fracture_mask = mix(1.0, shedding_pattern(UV), fracture_progress);
	alpha *= fracture_mask;

	COLOR = vec4(body_color, alpha);
}
