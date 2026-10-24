shader_type canvas_item;
render_mode unshaded, blend_add;

// The polygon canvas is intentionally larger than the platform. The material
// builds an irregular, diffuse field within it; density approaches zero well
// before the canvas boundary so no rectangular or capsule silhouette appears.
uniform vec2 field_size = vec2(360.0, 156.0);
uniform float platform_half_width = 110.0;
uniform float platform_half_height = 10.0;
uniform float approach_charge = 0.0;
uniform float approach_target_x = 0.5;
uniform float landing_age = -1.0;
uniform float landing_strength = 0.0;
uniform float landing_x = 0.0;
uniform float phase_offset = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	value += noise(p) * amplitude;
	p *= 2.03;
	amplitude *= 0.5;
	value += noise(p) * amplitude;
	p *= 2.01;
	amplitude *= 0.5;
	value += noise(p) * amplitude;
	p *= 2.02;
	amplitude *= 0.5;
	value += noise(p) * amplitude;
	return value;
}

float rect_sdf(vec2 p, vec2 half_size) {
	vec2 q = abs(p) - half_size;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

void fragment() {
	vec2 local_px = (UV - vec2(0.5)) * field_size;
	float signed_edge_distance = rect_sdf(
		local_px,
		vec2(platform_half_width, platform_half_height)
	);
	float outside_edge = smoothstep(-4.0, 4.5, signed_edge_distance);
	float distance_from_edge = max(signed_edge_distance, 0.0);

	// The falloff is the real silhouette of the field: broad, irregular and
	// feathered into the world. Noise changes the density, never its boundary.
	float spatial_falloff = exp(-distance_from_edge / 37.0)
		* (1.0 - smoothstep(43.0, 74.0, distance_from_edge));

	float time = TIME;
	vec2 p = local_px / vec2(35.0, 27.0);
	float warp_x = fbm(p * 0.68 + vec2(-time * 0.095 + phase_offset * 0.013, time * 0.035));
	float warp_y = fbm(p * 0.72 + vec2(time * 0.043, -time * 0.071 + phase_offset * 0.009));
	vec2 warped = p + (vec2(warp_x, warp_y) - 0.5) * 0.92;

	// Several slow scales of noise create vaporous volume with translucent
	// gaps. The advection makes the mass drift, not just pulse in place.
	float broad_noise = fbm(
		warped * vec2(0.72, 0.92)
		+ vec2(-time * 0.105, time * 0.032)
	);
	float medium_noise = fbm(
		warped * vec2(1.42, 1.72)
		+ vec2(time * 0.12, -time * 0.16)
	);
	float fine_noise = fbm(
		warped * vec2(2.55, 2.9)
		+ vec2(-time * 0.24, time * 0.19)
	);
	// A slower, larger density field creates soft pockets of energy inside the
	// cloud. It changes the cloud's volume without forming separate blobs.
	float deep_noise = fbm(
		warped * vec2(0.46, 0.62)
		+ vec2(time * 0.043, -time * 0.057)
	);

	float broad_volume = smoothstep(0.28, 0.70, broad_noise);
	float medium_volume = smoothstep(0.34, 0.73, medium_noise);
	float fine_volume = smoothstep(0.43, 0.76, fine_noise);
	float cloud_pockets = smoothstep(0.32, 0.70, deep_noise);
	float cloud_volume = clamp(
		broad_volume * 0.42
		+ medium_volume * 0.32
		+ fine_volume * 0.14
		+ cloud_pockets * 0.22,
		0.0, 1.0
	);

	// Layered soft wisps ripple through the cloud. These are deliberately
	// wider than a line, with very low opacity and no closed geometric outline.
	float ridge = 1.0 - abs(medium_noise * 2.0 - 1.0);
	float soft_wisps = smoothstep(0.42, 0.89, ridge) * (0.25 + cloud_volume * 0.75);
	float current_noise = fbm(
		warped * vec2(2.0, 1.15)
		+ vec2(-time * 0.32 + broad_noise * 0.55, time * 0.08)
	);
	float current_threads = smoothstep(0.63, 0.82, current_noise)
		* smoothstep(0.18, 0.76, cloud_volume);

	// Low-opacity, large-scale haze softens the field into the surrounding
	// darkness. This is part of the same cloud, not a separate circular halo.
	float haze_mass = smoothstep(0.22, 0.68, deep_noise)
		* (0.42 + broad_noise * 0.58);
	// Haze reaches a little farther than the main cloud, then fades completely
	// before the larger canvas edge so neighboring fields stay visually distinct.
	float haze_falloff = exp(-distance_from_edge / 46.0)
		* (1.0 - smoothstep(58.0, 86.0, distance_from_edge));

	// Underside currents are long, softly masked ridges in a warped flow field.
	// Noise bends and breaks them so they read as irregular streams, not lines.
	float flow_warp = fbm(
		warped * vec2(0.82, 1.48)
		+ vec2(-time * 0.13, time * 0.17)
	);
	float flow_phase = warped.x * 0.38
		+ warped.y * 0.13
		+ (flow_warp - 0.5) * 2.25
		- time * 0.42;
	float flow_ridge = 1.0 - abs(sin(
		flow_phase * 5.25 + sin(warped.y * 0.52 - time * 0.16) * 0.48
	));
	float flow_visibility = smoothstep(0.81, 0.965, flow_ridge)
		* smoothstep(0.27, 0.64, broad_noise);
	float underside_gate = smoothstep(
		platform_half_height + 2.0,
		platform_half_height + 13.0,
		local_px.y
	) * (1.0 - smoothstep(
		platform_half_height + 48.0,
		platform_half_height + 74.0,
		local_px.y
	));
	float underside_streams = flow_visibility * underside_gate;

	float breathe = 0.91 + 0.09 * sin(time * 1.05 + phase_offset);
	float base_density = (0.055 + cloud_volume * 0.26)
		+ soft_wisps * 0.10
		+ current_threads * 0.075
		+ cloud_pockets * 0.042;
	float cloud_alpha = base_density * spatial_falloff * outside_edge * breathe;
	cloud_alpha += haze_mass * haze_falloff * outside_edge * 0.018;
	cloud_alpha += underside_streams * spatial_falloff * 0.060;

	// Irregular edge light makes the energy feel attached to the neon hardware.
	// Because its brightness is modulated by noise, it never becomes a halo ring.
	float edge_light = exp(-distance_from_edge / 9.0)
		* (0.35 + 0.65 * broad_volume)
		* smoothstep(-5.0, 3.0, signed_edge_distance);
	cloud_alpha += edge_light * 0.095 * (0.82 + breathe * 0.18);

	// During approach, the field gently gathers around the predicted contact
	// area. The influence is broad and blended into the noise, never a badge.
	float target_x = (approach_target_x * 2.0 - 1.0) * platform_half_width;
	vec2 target_delta = local_px - vec2(target_x, -platform_half_height - 1.0);
	float approach_focus = exp(
		-pow(target_delta.x / 47.0, 2.0)
		-pow(target_delta.y / 25.0, 2.0)
	);
	float focus_density = approach_focus * clamp(approach_charge, 0.0, 1.0);
	cloud_alpha += focus_density * (0.045 + broad_volume * 0.055);

	// Landing diffuses a brief cloud-brightening impulse outward from the real
	// contact position. The ring is soft and noisy, not a crisp shockwave.
	float landing_gate = 1.0 - step(landing_age, -0.001);
	float landing_t = clamp(landing_age / 0.58, 0.0, 1.0);
	float landing_fade = (1.0 - landing_t) * landing_gate * landing_strength;
	vec2 impact_origin = vec2(landing_x, -platform_half_height - 1.5);
	vec2 impact_delta = local_px - impact_origin;
	float radial_distance = length(vec2(impact_delta.x, impact_delta.y * 1.12));
	float expanding_radius = 4.0 + landing_t * 58.0;
	float diffuse_front = exp(-pow((radial_distance - expanding_radius) / 12.0, 2.0));
	float impact_bloom = exp(-dot(impact_delta, impact_delta) / 420.0)
		* exp(-landing_age * 12.0) * landing_gate;
	cloud_alpha += (diffuse_front * 0.060 + impact_bloom * 0.12) * landing_fade;

	// Idle field leans gently toward the platform's purple idle light; active
	// charge blends toward the cyan energy already used by the platform edge.
	vec3 idle_tint = vec3(0.62, 0.20, 1.65);
	vec3 active_tint = vec3(0.16, 1.05, 2.65);
	vec3 cloud_color = mix(idle_tint, active_tint, clamp(approach_charge * 0.82 + impact_bloom * 0.42, 0.0, 1.0));
	cloud_color += vec3(0.10, 0.22, 0.42) * (soft_wisps * 0.30 + current_threads * 0.22);
	// Gentle violet depth in denser pockets; cool highlights in the currents.
	cloud_color += vec3(0.13, 0.035, 0.36) * cloud_pockets * 0.24;
	cloud_color += vec3(0.06, 0.16, 0.46) * underside_streams * 0.48;
	cloud_color *= 0.90 + cloud_volume * 0.16;

	float alpha = clamp(cloud_alpha * 1.22, 0.0, 0.34);
	COLOR = vec4(cloud_color, alpha);
}
