shader_type canvas_item;

varying float edge_local_x;

instance uniform float platform_width = 220.0;
instance uniform float approach_charge = 0.0;
instance uniform float approach_target_x = 0.5;
instance uniform float landing_confirm = 0.0;
instance uniform float activated = 0.0;

void vertex() {
	edge_local_x = VERTEX.x;
}

void fragment() {
	float half_width = platform_width * 0.5;
	float x = clamp((edge_local_x + half_width) / platform_width, 0.0, 1.0);
	float target = clamp(approach_target_x, 0.0, 1.0);
	float charge = clamp(approach_charge, 0.0, 1.0);
	float active = clamp(activated, 0.0, 1.0);

	// The platform stays visibly neon even when idle. The neutral state is
	// intentionally pale so the HDR cyan activation reads immediately.
	vec3 neutral_color = vec3(0.72, 1.35, 1.55);
	vec3 active_color = vec3(0.10, 2.15, 3.20);
	vec3 active_core = vec3(0.45, 3.15, 4.20);
	vec3 confirm_color = vec3(1.35, 3.90, 4.60);

	// Continuous bilateral loading:
	// the left side fills from x=0 toward the predicted impact point,
	// while the right side fills from x=1 toward that same point.
	float left_front = target * charge;
	float right_front = target + (1.0 - target) * (1.0 - charge);

	float left_fill = 1.0 - smoothstep(left_front - 0.018, left_front + 0.018, x);
	float right_fill = smoothstep(right_front - 0.018, right_front + 0.018, x);
	float fill = max(left_fill, right_fill) * charge;

	// A restrained travelling shimmer moves through the already-filled
	// sections. It keeps the charge alive without turning it into separate dots.
	float shimmer_phase = fract(TIME * 0.75);
	float left_shimmer_center = mix(0.0, left_front, shimmer_phase);
	float right_shimmer_center = mix(1.0, right_front, shimmer_phase);
	float left_shimmer = (1.0 - smoothstep(0.0, 0.075, abs(x - left_shimmer_center))) * left_fill;
	float right_shimmer = (1.0 - smoothstep(0.0, 0.075, abs(x - right_shimmer_center))) * right_fill;
	float shimmer = max(left_shimmer, right_shimmer) * charge;

	vec3 result = mix(neutral_color, active_color, fill);
	result = mix(result, active_core, shimmer * 0.32);

	// Once connected, the whole edge remains awake instead of returning
	// to the passive state.
	result = mix(result, active_color, active);

	// Brief confirmation flash on the successful connection.
	float confirm = clamp(landing_confirm, 0.0, 1.0);
	result += confirm_color * confirm * confirm;

	COLOR.rgb = result;
}
