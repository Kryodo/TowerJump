shader_type canvas_item;

// Sparse, irregular chevron fissures at the outside of the aura ribbon.
// The central energy/body remain continuous; the pattern is not tiled across them.
float hash_cell(float value) {
	return fract(sin(value * 127.1 + 311.7) * 43758.5453123);
}

void fragment() {
	vec4 aura = COLOR;
	float along = clamp(UV.x, 0.0, 0.99999);
	float across = clamp(UV.y, 0.0, 1.0);
	float cell_id = floor(along * 11.0);
	float local_u = fract(along * 11.0);
	float selected = step(0.56, hash_cell(cell_id + 1.7));
	float anchor = 0.18 + hash_cell(cell_id + 9.1) * 0.64;
	float direction = mix(-1.0, 1.0, step(0.5, hash_cell(cell_id + 4.6)));
	float chevron_x = anchor + direction * abs(across - 0.5) * 0.24;
	float fissure_distance = abs(local_u - chevron_x);
	float fissure = (
		1.0 - smoothstep(0.012, 0.032, fissure_distance)
	) * selected;
	float outer_aura = smoothstep(0.18, 0.34, abs(across - 0.5));

	// Notches bite into the two outer flanks but never sever the ribbon's core.
	aura.a *= 1.0 - fissure * outer_aura * 0.78;
	COLOR = aura;
}
