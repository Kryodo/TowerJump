shader_type canvas_item;
render_mode unshaded, blend_add;

// TEMPORARY RENDERING DIAGNOSTIC.
// Intentionally bypass noise and flow masks. If this does not appear, the
// issue is the Polygon2D/material/visibility path rather than undercurrent art.
uniform vec2 field_size = vec2(392.0, 200.0);
uniform float platform_half_width = 110.0;
uniform float platform_half_height = 10.0;

void fragment() {
	vec2 local_px = (UV - vec2(0.5)) * field_size;
	float below = local_px.y - platform_half_height;

	// Large, unmistakable test plume; all boundaries remain softly feathered.
	float vertical_fade_in = smoothstep(-1.0, 6.0, below);
	float vertical_fade_out = 1.0 - smoothstep(56.0, 88.0, below);
	float horizontal_fade = 1.0 - smoothstep(
		platform_half_width + 8.0,
		platform_half_width + 78.0,
		abs(local_px.x)
	);
	float broad_unevenness = 0.78 + 0.22 * sin(
		local_px.x * 0.018 + local_px.y * 0.026
	);
	float alpha = vertical_fade_in * vertical_fade_out
		* horizontal_fade * broad_unevenness * 0.82;

	// Deliberately extreme HDR cyan for a clear yes/no render-path test.
	COLOR = vec4(0.10, 1.30, 5.00, alpha);
}
