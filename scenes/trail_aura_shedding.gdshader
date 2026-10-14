shader_type canvas_item;

// The aura's chevron fissures are explicit Line2D overlays generated in
// ball_trail.gd. Avoid shader-UV masking here so the cracks remain predictable.
void fragment() {
	COLOR = COLOR;
}
