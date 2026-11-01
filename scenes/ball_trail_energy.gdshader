shader_type canvas_item;

uniform float flow_speed : hint_range(0.0, 4.0) = 0.9;
uniform float energy_strength : hint_range(0.0, 3.0) = 1.35;
uniform float filament_strength : hint_range(0.0, 4.0) = 1.7;
uniform int palette_mode = 0;
uniform float trail_progress_start = 0.0;
uniform float trail_progress_scale = 1.0;
uniform float pulse_progress = -1.0;
uniform float pulse_strength = 0.0;
uniform float jump_boost_progress = -1.0;
uniform float jump_boost_strength = 0.0;
uniform float landing_kick_strength = 0.0;
uniform float landing_kick_progress = 0.0;
uniform float combo_energy = 0.0;
uniform vec3 combo_tint = vec3(0.24, 1.02, 1.42);


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

	float time = TIME * flow_speed * (1.0 + combo_energy * 0.58);

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

	// Existing turbulence becomes more coherent and luminous while Combo is
	// active. The wave travels with the plasma rather than spawning new particles.
	float combo_wave = 0.5 + 0.5 * sin(
		uv.x * 18.0 - time * 2.35
		+ sin(uv.x * 6.0 + time * 0.55)
		+ uv.y * 2.2
	);
	float combo_current = clamp(
		(field * 0.38 + fine * 0.62)
		* (0.72 + combo_wave * 0.28)
		* combo_energy
		* trail_fade,
		0.0,
		1.0
	);

	// Paired filaments snake through the ribbon and travel toward its tail.
	// They become part of the existing plasma field only while Combo is active.
	float thread_phase = uv.x * 11.0 - time * 2.3
		+ sin(uv.x * 4.8 + time * 0.62);
	float thread_a = 0.28 + 0.13 * sin(thread_phase);
	float thread_b = 0.72 + 0.10 * sin(thread_phase * 0.88 + 2.1);
	float thread_flicker = 0.78 + 0.22 * sin(uv.x * 27.0 - time * 2.8 + uv.y * 4.0);
	float combo_threads = (
		exp(-pow((uv.y - thread_a) / 0.050, 2.0)) * 0.85
		+ exp(-pow((uv.y - thread_b) / 0.045, 2.0)) * 0.78
	) * thread_flicker * combo_energy * trail_fade;

	energy = min(energy + combo_current * 0.16 + combo_threads * 0.44, 2.0);

	// The same travelling pulse used by the body and outer aura briefly
	// strengthens the core and pushes a bright ridge toward the ribbon edges.
	float pulse_gate = step(0.0, pulse_progress);
	float pulse_band = (
		1.0 - smoothstep(0.022, 0.105, abs(uv.x - pulse_progress))
	) * pulse_gate;
	float travelling_pulse = pulse_band * pulse_strength * trail_fade;
	// Activation boost is a separate fast front; it never interrupts the regular
	// full-release pulse or the tail-to-orb landing kick.
	float jump_boost_gate = step(0.0, jump_boost_progress);
	float jump_boost_band = (
		1.0 - smoothstep(0.014, 0.075, abs(uv.x - jump_boost_progress))
	) * jump_boost_gate;
	float jump_boost_front = jump_boost_band * jump_boost_strength * trail_fade;
	// On landing, a quick energy front sweeps from the tail (uv.x = 1)
	// back toward the orb (uv.x = 0). A slight cross-stream warp makes the
	// flash wander through the turbulent plasma rather than scan like a ruler.
	float landing_front_wander = (
		0.018 * sin(uv.y * 8.0 + time * 4.2)
		+ 0.009 * sin(uv.y * 15.0 - time * 5.7)
	);
	float landing_front_center = clamp(landing_kick_progress + landing_front_wander, 0.0, 1.0);
	float landing_kick_gate = step(0.0, landing_kick_progress);
	float landing_kick_front = 1.0 - smoothstep(
		0.018,
		0.075,
		abs(uv.x - landing_front_center)
	);
	float landing_kick_wake = (
		1.0 - smoothstep(0.0, 0.23, max(uv.x - landing_kick_progress, 0.0))
	) * (
		1.0 - smoothstep(0.0, 0.08, max(landing_kick_progress - uv.x, 0.0))
	);
	float landing_head_kick = landing_kick_strength
		* max(landing_kick_front, landing_kick_wake * 0.24)
		* landing_kick_gate
		* trail_fade;
	float pulse_edge = travelling_pulse * smoothstep(0.42, 0.82, edge_distance);
	float boost_edge = jump_boost_front * smoothstep(0.36, 0.82, edge_distance);
	// Landing flash stays in the head of the ribbon rather than moving across it.
	edge_strength = max(edge_strength, max(pulse_edge * 0.95, boost_edge * 0.80));
	energy = max(energy, edge_strength * 0.42);
	energy = min(
		energy + travelling_pulse * 0.46 + landing_head_kick * 0.23
		+ jump_boost_front * 0.40,
		2.0
	);


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
	final_color += landing_kick_color * landing_head_kick * 0.24;
	final_color += landing_kick_color * jump_boost_front * 0.30;
	final_color = mix(final_color, combo_tint, combo_current * 0.38);
	final_color += combo_tint * combo_current * 0.16;
	final_color = mix(final_color, combo_tint, combo_threads * 0.34);
	final_color += combo_tint * combo_threads * 0.48;

	COLOR = vec4(
		final_color,
		energy
	);
}