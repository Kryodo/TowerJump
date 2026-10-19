shader_type canvas_item;

// This pass is composited immediately after the background layers and before
// the ball/platforms. It therefore softens background scenery only.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_radius_pixels : hint_range(0.0, 8.0) = 3.0;
uniform float blur_strength : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	vec2 offset = SCREEN_PIXEL_SIZE * blur_radius_pixels;
	vec4 center = texture(screen_texture, SCREEN_UV);

	// Four bilinear-filtered diagonal taps approximate a small Gaussian blur
	// at low sample cost. Keep the original center to preserve mote visibility.
	vec4 diagonal_samples =
		texture(screen_texture, SCREEN_UV + offset * vec2(-1.0, -1.0)) +
		texture(screen_texture, SCREEN_UV + offset * vec2( 1.0, -1.0)) +
		texture(screen_texture, SCREEN_UV + offset * vec2(-1.0,  1.0)) +
		texture(screen_texture, SCREEN_UV + offset * vec2( 1.0,  1.0));

	vec4 softened = center * 0.36 + diagonal_samples * 0.16;
	COLOR = mix(center, softened, blur_strength);
}
