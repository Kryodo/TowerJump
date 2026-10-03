shader_type canvas_item;

render_mode unshaded, blend_add;

instance uniform float landing_energy: hint_range(0.0, 1.0) = 0.0;
instance uniform float landing_x: hint_range(0.0, 1.0) = 0.5;
instance uniform float platform_width = 220.0;

varying float platform_x;
varying float platform_y;

void vertex() {
	platform_x = VERTEX.x;
	platform_y = VERTEX.y;
}

void fragment() {

	// --------------------------------------------------
	// 1. NORMALIZED PLATFORM COORDINATES
	// --------------------------------------------------

	float half_width = platform_width * 0.5;

	float x = (
		platform_x + half_width
	) / platform_width;


	// --------------------------------------------------
	// 2. IDLE = COMPLETELY INVISIBLE
	// --------------------------------------------------

	float energy = landing_energy;

	float active = smoothstep(
		0.0,
		0.02,
		energy
	);


	// --------------------------------------------------
	// 3. IMPACT PHASE
	// --------------------------------------------------

	float impact = 1.0 - smoothstep(
		0.0,
		0.16,
		energy
	);

	// Quick bright flash at the actual landing point.
	float impact_distance = abs(
		x - landing_x
	);

	float impact_core = 1.0 - smoothstep(
		0.0,
		0.025,
		impact_distance
	);

	float impact_aura = 1.0 - smoothstep(
		0.02,
		0.10,
		impact_distance
	);

	float impact_strength =
		impact_core +
		impact_aura * 0.35;

	impact_strength *= impact;


	// --------------------------------------------------
	// 4. PROPAGATION
	// --------------------------------------------------

	// Wait briefly for the impact before the energy starts
	// travelling.
	float travel_phase = smoothstep(
		0.08,
		0.22,
		energy
	);

	// The front travels from the landing point toward
	// the right side of the platform.
	float travel_distance = 1.25;

	float front_x =
		landing_x +
		travel_phase * travel_distance;


	// --------------------------------------------------
	// 5. IRREGULAR ELECTRICAL FRONT
	// --------------------------------------------------

	float local_distance =
		x - front_x;

	// Wobble the front so it doesn't look like a
	// perfectly straight scanning line.
	float wobble =
		sin(
			x * 42.0 +
			energy * 28.0
		) * 0.018;

	local_distance += wobble;


	float front_core = 1.0 - smoothstep(
		0.0,
		0.018,
		abs(local_distance)
	);

	float front_aura = 1.0 - smoothstep(
		0.012,
		0.055,
		abs(local_distance)
	);


	// --------------------------------------------------
	// 6. SURFACE TRAIL BEHIND THE FRONT
	// --------------------------------------------------

	float behind =
		front_x - x;

	float trail = 1.0 - smoothstep(
		0.02,
		0.24,
		behind
	);

	// Don't allow trail in front of the energy.
	trail *= step(
		0.0,
		behind
	);

	// Trail becomes weaker over distance.
	trail *= 0.28;


	// --------------------------------------------------
	// 7. SMALL ELECTRICAL BRANCHES
	// --------------------------------------------------

	float branch_wave =
		sin(
			x * 75.0 +
			energy * 31.0
		);

	float branch_shape =
		smoothstep(
			0.55,
			0.90,
			branch_wave
		);

	float branch_distance =
		abs(local_distance);

	float branches = 1.0 - smoothstep(
		0.0,
		0.045,
		branch_distance
	);

	branches *= branch_shape;
	branches *= 0.55;


	// --------------------------------------------------
	// 8. FADE OUT AT THE END
	// --------------------------------------------------

	float fade = 1.0 - smoothstep(
		0.78,
		1.0,
		energy
	);


	// --------------------------------------------------
	// 9. SURFACE HEIGHT MASK
	// --------------------------------------------------

	// The effect is concentrated around the platform
	// surface rather than filling the entire LandingEnergy
	// rectangle.

	float surface_distance = abs(
		platform_y + 7.0
	);

	float surface_mask = 1.0 - smoothstep(
		2.0,
		15.0,
		surface_distance
	);


	// --------------------------------------------------
	// 10. COMBINE
	// --------------------------------------------------

	float intensity =
		impact_strength +
		front_core * 1.25 +
		front_aura * 0.35 +
		trail +
		branches;

	intensity *= fade;
	intensity *= surface_mask;
	intensity *= active;


	vec3 energy_color = vec3(
		0.0,
		0.85,
		1.0
	);

	COLOR = vec4(
		energy_color * intensity,
		intensity
	);
}