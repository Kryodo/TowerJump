shader_type canvas_item;

uniform float platform_height = 20.0;
uniform float reflection_height = 2.0;
instance uniform float landing_pulse: hint_range(0.0, 1.0) = 0.0;
instance uniform float assembly_alpha: hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 uv = UV;

    // --------------------------------------------------
    // 1. PIXEL POSITION
    // --------------------------------------------------

    float pixel_y = uv.y * platform_height;


    // --------------------------------------------------
    // 2. VERY DARK BASE MATERIAL
    // --------------------------------------------------

    vec3 upper_body = vec3(0.012, 0.028, 0.045);
    vec3 lower_body = vec3(0.003, 0.006, 0.010);

    float body_gradient = smoothstep(
        2.0,
        platform_height,
        pixel_y
    );

    vec3 body = mix(
        upper_body,
        lower_body,
        body_gradient
    );


    // --------------------------------------------------
    // 3. SOFT CYAN LIGHT RECEIVED FROM NEON
    // --------------------------------------------------

    vec3 cyan = vec3(0.0, 0.28, 0.40);

    float reflection = 1.0 - smoothstep(
        0.0,
        reflection_height,
        pixel_y
    );

    reflection *= 0.16;

    body += cyan * reflection;


	// --------------------------------------------------
	// 4. SUBTLE UPPER MATERIAL HIGHLIGHT
	// --------------------------------------------------

	float upper_highlight = 1.0 - smoothstep(
	    0.0,
	    1.5,
	    pixel_y
	);

	upper_highlight *= 0.10;

	body += vec3(0.10, 0.14, 0.16) * upper_highlight;


    // --------------------------------------------------
    // 5. LOWER EDGE DARKENING
    // --------------------------------------------------

    float lower_edge = smoothstep(
        platform_height - 2.0,
        platform_height,
        pixel_y
    );

    body *= 1.0 - lower_edge * 0.45;


    // --------------------------------------------------
    // 6. SUBTLE SIDE EDGE SHADING
    // --------------------------------------------------

    float side_edge = min(uv.x, 1.0 - uv.x);

    float edge_darkening = 1.0 - smoothstep(
        0.0,
        0.025,
        side_edge
    );

    body *= 1.0 - edge_darkening * 0.12;
	
	// --------------------------------------------------
	// 7. LANDING ENERGY WAVE
	// --------------------------------------------------

	vec3 landing_color = vec3(0.012, 0.065, 0.14);

	float wave_position = landing_pulse;

	// Soft outer energy field.
	float wave_outer = 1.0 - smoothstep(
	    0.04,
	    0.18,
	    abs(pixel_y / platform_height - wave_position)
	);

	// Narrow brighter center.
	float wave_core = 1.0 - smoothstep(
	    0.01,
	    0.055,
	    abs(pixel_y / platform_height - wave_position)
	);

	// Combine the soft field and bright core.
	float wave = wave_outer * 0.35 + wave_core * 0.65;

	// Fade the wave in at the top and completely out after the bottom.
	float wave_presence = smoothstep(
	    0.0,
	    0.08,
	    landing_pulse
	);

	wave *= wave_presence;

	body += landing_color * wave;

    // --------------------------------------------------
    // OUTPUT
    // --------------------------------------------------

    COLOR = vec4(body, COLOR.a * clamp(assembly_alpha, 0.0, 1.0));
}