shader_type canvas_item;

varying float edge_local_x;

instance uniform float platform_width = 220.0;
instance uniform float approach_charge = 0.0;
instance uniform float approach_target_x = 0.5;
instance uniform float landing_confirm = 0.0;
instance uniform float activated = 0.0;

void vertex() {
\tedge_local_x = VERTEX.x;
}

void fragment() {
\tfloat half_width = platform_width * 0.5;
\tfloat x = clamp((edge_local_x + half_width) / platform_width, 0.0, 1.0);
\tfloat target = clamp(approach_target_x, 0.18, 0.82);
\tfloat charge = clamp(approach_charge, 0.0, 1.0);
\tfloat active = clamp(activated, 0.0, 1.0);

\tvec3 neutral_color = vec3(0.22, 0.08, 0.65);
\tvec3 active_color = vec3(0.10, 2.15, 3.20);
\tvec3 confirm_color = vec3(1.35, 3.90, 4.60);

\t// The charge is a continuous bilateral loading bar. Both sides always
\t// start at the physical ends of the platform and advance toward the
\t// predicted landing point. No separate dots or chunks are introduced.
\tfloat left_front = target * charge;
\tfloat right_front = target + (1.0 - target) * (1.0 - charge);

\t// Slightly softer fronts on smaller platforms keep the progression
\t// readable without making the effect look segmented.
\tfloat front_width = mix(0.024, 0.016, clamp(platform_width / 320.0, 0.0, 1.0));
\tfloat left_fill = 1.0 - smoothstep(left_front - front_width, left_front + front_width, x);
\tfloat right_fill = smoothstep(right_front - front_width, right_front + front_width, x);
\tfloat fill = max(left_fill, right_fill) * charge;

\tvec3 result = mix(neutral_color, active_color, fill);

\t// Landing confirmation briefly peaks the already-connected edge.
\tfloat confirm = clamp(landing_confirm, 0.0, 1.0);
\tresult += confirm_color * confirm * confirm;

\t// Once the platform has been landed on, it remains in its awake cyan
\t// state. The approach animation itself never needs to know the landing
\t// quality; confirmation is a separate layer.
\tresult = mix(result, active_color, active);

\tCOLOR.rgb = result;
}
