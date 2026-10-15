shader_type canvas_item;

uniform float shedding_amount = 1.0;

float hash_cell(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Shared stable fracture pattern: the aura opens at the same irregular cells
// as the unified skin and energy stream instead of painting over their gaps.
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

void fragment() {
	vec4 aura_color = COLOR;
	float along = clamp(UV.x, 0.0, 1.0);
	float fracture_progress = smoothstep(0.36, 0.78, along) * shedding_amount;
	float fracture_mask = mix(1.0, shedding_pattern(UV), fracture_progress);
	COLOR = vec4(aura_color.rgb, aura_color.a * fracture_mask);
}
