shader_type canvas_item;

varying vec2 edge_local_position;

instance uniform float platform_width = 220.0;
instance uniform float platform_height = 20.0;
instance uniform float edge_height = 8.0;
instance uniform float approach_charge = 0.0;
instance uniform float approach_target_x = 0.5;
instance uniform float landing_confirm = 0.0;
instance uniform float activated = 0.0;
instance uniform float idle_sheen_progress = -1.0;

void vertex() {
	edge_local_position = VERTEX.xy;
}

void fragment() {
	float half_width = platform_width * 0.5;
	float x = clamp((edge_local_position.x + half_width) / platform_width, 0.0, 1.0);
	// The script supplies the already-constrained predicted landing point.
	// Keep the shader permissive so it does not secretly re-center the target.
	float target = clamp(approach_target_x, 0.02, 0.98);
	float charge = clamp(approach_charge, 0.0, 1.0);
	float active = clamp(activated, 0.0, 1.0);

	vec3 neutral_color = vec3(0.50, 0.19, 0.98);
	vec3 active_color = vec3(0.10, 2.15, 3.20);
	vec3 active_core = vec3(0.45, 3.15, 4.20);
	vec3 confirm_color = vec3(4.20, 4.20, 4.20);

	// The charge is a continuous bilateral loading bar. Both sides always
	// start at the physical ends of the platform and advance toward the
	// predicted landing point. No separate dots or chunks are introduced.
	float left_front = target * charge;
	float right_front = target + (1.0 - target) * (1.0 - charge);

	// Slightly softer fronts on smaller platforms keep the progression
	// readable without making the effect look segmented.
	float front_width = mix(0.024, 0.016, clamp(platform_width / 320.0, 0.0, 1.0));
	float left_fill = 1.0 - smoothstep(left_front - front_width, left_front + front_width, x);
	float right_fill = smoothstep(right_front - front_width, right_front + front_width, x);
	float fill = max(left_fill, right_fill) * charge;

	vec3 result = mix(neutral_color, active_color, fill);

	// A restrained bright core rides the two advancing fronts so the charge
	// reads as active energy rather than a flat color wipe.
	float left_core = 1.0 - smoothstep(front_width * 0.35, front_width * 1.25, abs(x - left_front));
	float right_core = 1.0 - smoothstep(front_width * 0.35, front_width * 1.25, abs(x - right_front));
	float core = max(left_core, right_core) * charge;
	result = mix(result, active_core, core);

	// Once the platform has been landed on, it remains in its awake cyan
	// state. The approach animation itself never needs to know the landing
	// quality; confirmation is a separate layer.
	result = mix(result, active_color, active);

	// Completion flash is applied AFTER the activated state so it remains
	// visible as a true white connection moment, then settles back to cyan.
	float confirm = clamp(landing_confirm, 0.0, 1.0);
	result = mix(result, confirm_color, confirm);

	// A diffuse reflection that melts into the existing neon edge.
	// Avoid a distinct core or clipped band: the whole highlight is feathered
	// with a broad Gaussian falloff so it reads as light, not a shape sliding by.
	float idle_gate = (1.0 - charge) * (1.0 - active) * (1.0 - confirm);
	float sheen_active = step(0.0, idle_sheen_progress) * (1.0 - step(1.0, idle_sheen_progress));
	float sheen_progress = clamp(idle_sheen_progress, 0.0, 1.0);
	float sheen_position = mix(-0.12, 1.12, sheen_progress);
	float sheen_y = clamp(
		(edge_local_position.y + platform_height * 0.5) / max(edge_height, 0.001),
		0.0,
		1.0
	);
	// Keep the reflection oblique, but less aggressively tilted and less like
	// a crisp diagonal cut across the narrow edge.
	float sheen_axis = x - sheen_position + (sheen_y - 0.5) * 0.15;
	float sheen_distance = abs(sheen_axis);
	float sheen_bloom = exp(-pow(sheen_distance / 0.34, 2.0) * 1.9);
	// Tiny, broad variation prevents the glow from reading as a perfectly
	// uniform capsule while avoiding a separate bright stripe.
	float sheen_flow = 0.94 + 0.06 * sin(sheen_y * 3.2 + sheen_progress * 1.4);
	float sheen_mix = sheen_bloom * sheen_flow * 0.18 * idle_gate * sheen_active;
	vec3 sheen_color = vec3(1.55, 2.35, 2.75);
	result = mix(result, sheen_color, clamp(sheen_mix, 0.0, 0.18));

	COLOR.rgb = result;
}
