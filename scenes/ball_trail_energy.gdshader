shader_type canvas_item;

uniform float flow_speed : hint_range(0.0, 4.0) = 0.9;
uniform float energy_strength : hint_range(0.0, 3.0) = 1.35;
uniform float filament_strength : hint_range(0.0, 4.0) = 1.7;
uniform int palette_mode = 0;
uniform float trail_progress_start = 0.0;
uniform float trail_progress_scale = 1.0;
uniform float shedding_amount = 1.0;
uniform float crack_along_scale = 1.0;
uniform float crack_width_scale = 1.8;
uniform bool alignment_test_single_crack = false;
uniform bool use_crack_alignment_map = false;
uniform sampler2D crack_alignment_map : filter_linear;

// Small deterministic noise
// ------------------------------------------------------------

float hash21(vec2 p)
{
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);

	return fract(p.x * p.y);
}


float noise(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);

	f = f * f * (3.0 - 2.0 * f);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(
		mix(a, b, f.x),
		mix(c, d, f.x),
		f.y
	);
}


// ------------------------------------------------------------
// Fractal noise
// ------------------------------------------------------------

float fbm(vec2 p)
{
	float value = 0.0;
	float amplitude = 0.5;

	value += noise(p) * amplitude;

	p *= 2.0;
	amplitude *= 0.5;

	value += noise(p) * amplitude;

	p *= 2.0;
	amplitude *= 0.5;

	value += noise(p) * amplitude;

	return value;
}


float crack_segment_distance(vec2 uv, vec2 start_uv, vec2 end_uv) {
	float scale = max(crack_along_scale, 1.0);
	vec2 p = vec2(uv.x * scale, uv.y);
	vec2 a = vec2(start_uv.x * scale, start_uv.y);
	vec2 b = vec2(end_uv.x * scale, end_uv.y);
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.000001), 0.0, 1.0);
	return length(pa - ba * h);
}

float crack_keep(vec2 uv) {
	// One long, broad, heavily angled fracture reaching almost edge-to-edge.
	float long_crack = min(
		min(
			min(
				crack_segment_distance(uv, vec2(0.220, 0.025), vec2(0.247, 0.160)),
				crack_segment_distance(uv, vec2(0.247, 0.160), vec2(0.216, 0.300))
			),
			min(
				crack_segment_distance(uv, vec2(0.216, 0.300), vec2(0.253, 0.435)),
				crack_segment_distance(uv, vec2(0.253, 0.435), vec2(0.226, 0.580))
			)
		),
		min(
			crack_segment_distance(uv, vec2(0.226, 0.580), vec2(0.258, 0.735)),
			crack_segment_distance(uv, vec2(0.258, 0.735), vec2(0.236, 0.945))
		)
	);
	float cut_long = 1.0 - smoothstep(0.020 * crack_width_scale, 0.043 * crack_width_scale, long_crack);
	if (alignment_test_single_crack) {
		return 1.0 - cut_long;
	}

	// A separate hooked split starts well inside the trail and runs out to one edge.
	float side_crack = min(
		min(
			crack_segment_distance(uv, vec2(0.408, 0.505), vec2(0.440, 0.625)),
			crack_segment_distance(uv, vec2(0.440, 0.625), vec2(0.416, 0.750))
		),
		min(
			crack_segment_distance(uv, vec2(0.416, 0.750), vec2(0.453, 0.865)),
			crack_segment_distance(uv, vec2(0.453, 0.865), vec2(0.434, 0.985))
		)
	);
	float cut_side = 1.0 - smoothstep(0.014 * crack_width_scale, 0.032 * crack_width_scale, side_crack);

	// This one starts at the opposite edge and travels through most of the body.
	float cross_crack = min(
		min(
			min(
				crack_segment_distance(uv, vec2(0.664, 0.025), vec2(0.632, 0.155)),
				crack_segment_distance(uv, vec2(0.632, 0.155), vec2(0.666, 0.285))
			),
			min(
				crack_segment_distance(uv, vec2(0.666, 0.285), vec2(0.636, 0.400)),
				crack_segment_distance(uv, vec2(0.636, 0.400), vec2(0.660, 0.525))
			)
		),
		min(
			crack_segment_distance(uv, vec2(0.660, 0.525), vec2(0.640, 0.635)),
			crack_segment_distance(uv, vec2(0.640, 0.635), vec2(0.671, 0.755))
		)
	);
	float cut_cross = 1.0 - smoothstep(0.017 * crack_width_scale, 0.037 * crack_width_scale, cross_crack);

	// Shorter, narrower, irregular fracture near the lower body.
	float lower_crack = min(
		min(
			crack_segment_distance(uv, vec2(0.827, 0.265), vec2(0.800, 0.395)),
			crack_segment_distance(uv, vec2(0.800, 0.395), vec2(0.836, 0.520))
		),
		min(
			crack_segment_distance(uv, vec2(0.836, 0.520), vec2(0.793, 0.665)),
			min(
				crack_segment_distance(uv, vec2(0.793, 0.665), vec2(0.822, 0.795)),
				crack_segment_distance(uv, vec2(0.822, 0.795), vec2(0.798, 0.935))
			)
		)
	);
	float cut_lower = 1.0 - smoothstep(0.013 * crack_width_scale, 0.029 * crack_width_scale, lower_crack);

	// A small branching spur makes the pattern feel fractured, not repeated.
	float branch_crack = min(
		min(
			crack_segment_distance(uv, vec2(0.286, 0.365), vec2(0.318, 0.430)),
			crack_segment_distance(uv, vec2(0.318, 0.430), vec2(0.297, 0.505))
		),
		min(
			crack_segment_distance(uv, vec2(0.297, 0.505), vec2(0.330, 0.568)),
			crack_segment_distance(uv, vec2(0.330, 0.568), vec2(0.315, 0.632))
		)
	);
	float cut_branch = 1.0 - smoothstep(0.010 * crack_width_scale, 0.023 * crack_width_scale, branch_crack);

	float cut = max(max(cut_long, cut_side), max(max(cut_cross, cut_lower), cut_branch));
	return 1.0 - cut;
}


void fragment()
{
	vec2 uv = UV;
	uv.x = clamp(trail_progress_start + uv.x * trail_progress_scale, 0.0, 1.0);

	float time = TIME * flow_speed;

	// --------------------------------------------------------
	// Center of the energy channel
	// --------------------------------------------------------

	float center = 1.0 - abs(uv.y * 2.0 - 1.0);

	center = smoothstep(
		0.0,
		0.8,
		center
	);


	// --------------------------------------------------------
	// Distort the energy field
	//
	// The important difference from the previous shader:
	// the field is now warped in BOTH dimensions.
	// --------------------------------------------------------

	vec2 p = uv;

	p.x *= 7.0;
	p.y *= 3.0;

	p.x -= time;


	float distortion = fbm(
		vec2(
			p.x * 0.7,
			p.y * 1.4 + time * 0.15
		)
	);

	p.y += (distortion - 0.5) * 2.0;


	// --------------------------------------------------------
	// Main turbulent energy field
	// --------------------------------------------------------

	float field = fbm(
		p * vec2(1.4, 2.2)
	);

	field = smoothstep(
		0.42,
		0.72,
		field
	);


	// --------------------------------------------------------
	// Secondary finer energy
	// --------------------------------------------------------

	float fine = fbm(
		p * vec2(3.5, 4.5) +
		vec2(-time * 0.7, time * 0.15)
	);

	fine = smoothstep(
		0.55,
		0.82,
		fine
	);


	// --------------------------------------------------------
	// Combine into irregular plasma
	// --------------------------------------------------------

	float energy =
		field * 0.75 +
		fine * filament_strength;


	// Keep everything concentrated inside the core.
	energy *= center;


	// --------------------------------------------------------
	// Soft base energy
	// --------------------------------------------------------

	float soft_energy =
		center *
		energy_strength *
		0.34;


	energy =
		soft_energy +
		energy * 0.55;


	// --------------------------------------------------------
	// Fade toward the tail.
	//
	// UV.x = 0 at ball
	// UV.x = 1 at tail
	// --------------------------------------------------------

	float trail_fade = 1.0 - smoothstep(
		0.72,
		1.0,
		uv.x
	);

	energy *= trail_fade;

	// Two restrained edge filaments create a brighter bridge to the orb rim.
	// They sit inside the translucent ribbon edges instead of outlining a hard tube.
	float edge_distance = abs(uv.y * 2.0 - 1.0);
	float edge_ridge =
		smoothstep(0.58, 0.76, edge_distance)
		*
		(1.0 - smoothstep(0.88, 0.97, edge_distance));
	float edge_waver =
		0.78 + 0.22 * sin(uv.x * 25.0 - time * 1.7 + sin(uv.x * 8.0 + time * 0.4));
	float edge_strength = edge_ridge * edge_waver * trail_fade;
	energy = max(energy, edge_strength * 0.42);

	// Map this Line2D's UVs into the outer aura's progress and width coordinates.
	// This compensates for the recessed energy head and the different width curves.
	vec2 crack_uv = uv;
	if (use_crack_alignment_map) {
		vec2 alignment = texture(crack_alignment_map, vec2(UV.x, 0.5)).rg;
		crack_uv.x = alignment.r;
		crack_uv.y = 0.5 + (UV.y - 0.5) * alignment.g;
	}
	float crack_mask = mix(1.0, crack_keep(crack_uv), clamp(shedding_amount, 0.0, 1.0));
	energy *= crack_mask;
	edge_strength *= crack_mask;


	// Palette-matched energy stream: saturated blue or rich violet.
	vec3 base_color;
	vec3 bright_color;
	vec3 edge_color;
	if (palette_mode == 1) {
		base_color = vec3(0.30, 0.035, 0.82);
		bright_color = vec3(1.12, 0.68, 1.48);
		edge_color = vec3(1.55, 0.88, 1.95);
	} else {
		base_color = vec3(0.025, 0.20, 0.95);
		bright_color = vec3(0.46, 0.96, 1.48);
		edge_color = vec3(0.58, 1.22, 1.82);
	}

	float brightness = clamp(
		energy,
		0.0,
		1.0
	);

	vec3 final_color = mix(
		base_color,
		bright_color,
		brightness
	);

	// Additive HDR accents stay subtle at rest but connect to the orb's bright rim.
	final_color += edge_color * edge_strength * 0.43;

	// The inner energy follows the outer skin's fissures.
	COLOR = vec4(
		final_color,
		energy
	);
}