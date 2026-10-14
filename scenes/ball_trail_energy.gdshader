shader_type canvas_item;

uniform float flow_speed : hint_range(0.0, 4.0) = 0.9;
uniform float energy_strength : hint_range(0.0, 3.0) = 1.35;
uniform float filament_strength : hint_range(0.0, 4.0) = 1.7;
uniform int palette_mode = 0;
uniform float shedding_amount = 1.0;
uniform vec4 shed_gap_0 = vec4(-1.0, -1.0, 0.0, 0.0);
uniform vec4 shed_gap_1 = vec4(-1.0, -1.0, 0.0, 0.0);
uniform vec4 shed_gap_2 = vec4(-1.0, -1.0, 0.0, 0.0);

float gap_coverage(vec4 interval, float along, float across) {
	if (interval.x < 0.0 || interval.y <= interval.x) {
		return 0.0;
	}
	// x/y are the source range; z/w are its exact start/end skew distances.
	// UV.y=0/1 follows the two ribbon edges, matching the detached polygon.
	float edge_factor = mix(0.12, 1.0, clamp(across, 0.0, 1.0));
	float start = interval.x + interval.z * edge_factor;
	float end = interval.y - interval.w * edge_factor;
	if (end <= start) {
		return 0.0;
	}
	float gap_width = end - start;
	float feather = min(0.003, gap_width * 0.16);
	return smoothstep(start, start + feather, along)
		* (1.0 - smoothstep(end - feather, end, along));
}

float shed_gap_mask(float along, float across) {
	float gap = max(
		gap_coverage(shed_gap_0, along, across),
		max(
			gap_coverage(shed_gap_1, along, across),
			gap_coverage(shed_gap_2, along, across)
		)
	);
	return 1.0 - gap;
}

// ------------------------------------------------------------
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


void fragment()
{
	vec2 uv = UV;

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

	// Preserve the energy stream except where a matching geometry break exists.
	energy *= shed_gap_mask(uv.x, uv.y);


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

	COLOR = vec4(
		final_color,
		energy
	);
}