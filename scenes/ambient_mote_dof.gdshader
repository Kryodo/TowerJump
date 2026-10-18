shader_type canvas_item;

// Texture-space blur keeps this effect limited to the ambient mote sprites.
// It avoids an extra full-screen render pass on the mobile renderer.
uniform float blur_radius : hint_range(0.0, 3.0) = 1.8;
uniform float blur_amount : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 radius = TEXTURE_PIXEL_SIZE * blur_radius;

	vec4 original = texture(TEXTURE, UV);
	vec4 softened = original * 0.36;

	softened += texture(TEXTURE, UV + vec2(radius.x, 0.0)) * 0.10;
	softened += texture(TEXTURE, UV - vec2(radius.x, 0.0)) * 0.10;
	softened += texture(TEXTURE, UV + vec2(0.0, radius.y)) * 0.10;
	softened += texture(TEXTURE, UV - vec2(0.0, radius.y)) * 0.10;

	softened += texture(TEXTURE, UV + radius) * 0.06;
	softened += texture(TEXTURE, UV - radius) * 0.06;
	softened += texture(TEXTURE, UV + vec2(radius.x, -radius.y)) * 0.06;
	softened += texture(TEXTURE, UV + vec2(-radius.x, radius.y)) * 0.06;

	// Mix back some of the source to keep each mote legible at mobile scale.
	COLOR = mix(original, softened, blur_amount) * COLOR;
}
