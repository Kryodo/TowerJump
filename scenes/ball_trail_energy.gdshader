shader_type canvas_item;

uniform float flow_speed : hint_range(0.0, 4.0) = 0.9;
uniform float energy_strength : hint_range(0.0, 3.0) = 1.35;
uniform float filament_strength : hint_range(0.0, 4.0) = 1.7;
uniform int palette_mode = 0;
uniform float trail_progress_start = 0.0;
uniform float trail_progress_scale = 1.0;
uniform float pulse_progress = -1.0;
uniform float pulse_strength = 0.0;
uniform float landing_kick_strength = 0.0;


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

	// The same travelling pulse used by the body and outer aura briefly
	// strengthens the core and pushes a bright ridge toward the ribbon edges.
	float pulse_gate = step(0.0, pulse_progress);
	float pulse_band = (
		1.0 - smoothstep(0.022, 0.105, abs(uv.x - pulse_progress))
	) * pulse_gate;
	float travelling_pulse = pulse_band * pulse_strength * trail_fade;
	// A quick localized kick lights the part of the stream emerging from
	// the orb without consuming the ambient pulse's full ribbon travel.
	float landing_head_kick = landing_kick_strength
		* (1.0 - smoothstep(0.02, 0.34, uv.x))
		* trail_fade;
	float pulse_edge = travelling_pulse * smoothstep(0.42, 0.82, edge_distance);
	// Landing flash stays in the head of the ribbon rather than moving across it.
	edge_strength = max(edge_strength, pulse_edge * 0.95);
	energy = max(energy, edge_strength * 0.42);
	energy = min(energy + travelling_pulse * 0.46 + landing_head_kick * 0.28, 2.0);


	// Palette-matched energy stream: saturated blue or rich violet.
	vec3 base_color;
	vec3 bright_color;
	vec3 edge_color;
	vec3 landing_kick_color;
	if (palette_mode == 1) {
		base_color = vec3(0.30, 0.035, 0.82);
		bright_color = vec3(1.12, 0.68, 1.48);
		edge_color = vec3(1.55, 0.88, 1.95);
		landing_kick_color = vec3(2.0, 1.15, 2.7);
	} else {
		base_color = vec3(0.025, 0.20, 0.95);
		bright_color = vec3(0.46, 0.96, 1.48);
		edge_color = vec3(0.58, 1.22, 1.82);
		landing_kick_color = vec3(0.95, 1.9, 2.65);
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

	// Additive HDR accents stay subtle at rest but flare briefly as the pulse passes.
	final_color += edge_color * edge_strength * 0.43;
	final_color += edge_color * travelling_pulse * 0.30;
	final_color += landing_kick_color * landing_head_kick * 0.32;

	COLOR = vec4(
		final_color,
		energy
	);
}