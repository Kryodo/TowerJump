shader_type canvas_item;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);

	float time = TIME;

	// --------------------------------------------------
	// BASE MASK
	// --------------------------------------------------

	float mask = texture(TEXTURE, UV).a;

	// --------------------------------------------------
	// AURA BREATHING
	// --------------------------------------------------

	float breathing =
	    0.5 + 0.5 * sin(time * 1.35);

	float aura_breath =
	    mix(0.65, 1.0, breathing);

	// --------------------------------------------------
	// BASE ENERGY BODY
	// --------------------------------------------------

	float body_falloff =
		1.0 - smoothstep(0.10, 0.90, d);

	vec3 inner_body =
		vec3(0.02, 0.42, 0.58);

	vec3 outer_body =
		vec3(0.01, 0.18, 0.28);

	vec3 body_color = mix(
		outer_body,
		inner_body,
		body_falloff
	);

	float body_strength =
		mix(0.85, 1.0, body_falloff);

	vec3 color =
		body_color * body_strength;

	// --------------------------------------------------
	// INTERNAL MOVING ENERGY
	// --------------------------------------------------

	// Angular/radial coordinates.
	float angle = atan(p.y, p.x);

	// Several slow-moving waves combine to create
	// organic energy movement instead of a simple
	// left-to-right scrolling texture.

	float wave_a =
		sin(
			angle * 4.0
			+ d * 9.0
			- time * 1.8
		);

	float wave_b =
		sin(
			angle * 7.0
			- d * 6.0
			+ time * 1.25
		);

	float wave_c =
		sin(
			p.x * 8.0
			+ p.y * 5.0
			+ time * 1.1
		);

	float energy_flow =
		(wave_a * 0.45)
		+ (wave_b * 0.35)
		+ (wave_c * 0.20);

	// Convert the combined waves into a soft
	// positive energy field.

	float energy_mask =
		smoothstep(
			-0.15,
			0.65,
			energy_flow
		);

	// Keep the movement mostly inside the body.
	float energy_fade =
		1.0 - smoothstep(0.30, 0.92, d);

	vec3 moving_energy =
		vec3(0.00, 0.72, 0.92);

	color +=
	    moving_energy
	    * energy_mask
	    * energy_fade
	    * 0.28
	    * mix(0.90, 1.0, breathing);

	// --------------------------------------------------
	// INNER ENERGY FIELD
	// --------------------------------------------------

	float inner_energy =
		1.0 - smoothstep(0.22, 0.72, d);

	vec3 inner_energy_color =
		vec3(0.00, 0.58, 0.76);

	color +=
		inner_energy_color
		* inner_energy
		* 0.35;

	// --------------------------------------------------
	// CONTINUOUS OUTER TRANSITION
	// --------------------------------------------------

	float outer_transition =
		1.0 - smoothstep(0.72, 0.94, d);

	vec3 transition_color =
		vec3(0.00, 0.32, 0.42);

	color +=
		transition_color
		* outer_transition
		* 0.25;

	// --------------------------------------------------
	// FINE OUTER CONTOUR
	// --------------------------------------------------

	float outer_ring =
		smoothstep(0.925, 0.945, d)
		-
		smoothstep(0.955, 0.975, d);

	vec3 ring_color =
		vec3(0.00, 2.2, 3.2);

	color +=
		ring_color
		* outer_ring
		* aura_breath;

	// --------------------------------------------------
	// TRUE CENTERED CORE PULSE
	// --------------------------------------------------

	// The pulse changes the core radius itself.
	// Everything remains centered at exactly (0,0).

	float core_pulse =
	    0.5 + 0.5 * sin(time * 2.2);

	float core_radius =
	    mix(0.255, 0.305, core_pulse);

	float core =
		1.0 - smoothstep(
			0.0,
			core_radius,
			d
		);

	// Slightly vary brightness together with size.
	float core_brightness =
	    mix(0.82, 1.0, core_pulse);

	vec3 core_color =
		vec3(1.5, 4.5, 5.5);

	color = mix(
		color,
		core_color * core_brightness,
		core
	);

	// --------------------------------------------------
	// CORE AURA
	// --------------------------------------------------

	float core_aura =
		1.0 - smoothstep(
			core_radius * 0.65,
			core_radius * 1.65,
			d
		);

	vec3 aura_color =
		vec3(0.00, 1.15, 1.55);

	color +=
		aura_color
		* core_aura
		* 0.30
		* aura_breath;

	// --------------------------------------------------
	// SUBTLE INTERNAL HIGHLIGHT
	// --------------------------------------------------

	vec2 highlight_pos =
		vec2(-0.28, -0.30);

	float highlight_dist =
		distance(p, highlight_pos);

	float highlight =
		1.0 - smoothstep(
			0.0,
			0.17,
			highlight_dist
		);

	vec3 highlight_color =
		vec3(0.25, 1.2, 1.4);

	color +=
		highlight_color
		* highlight
		* 0.20;

	// --------------------------------------------------
	// OUTPUT
	// --------------------------------------------------

	COLOR = vec4(color, mask);
}