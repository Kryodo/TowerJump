shader_type canvas_item;

uniform float platform_height = 20.0;
uniform float reflection_height = 2.0;
instance uniform float landing_pulse: hint_range(0.0, 1.0) = 0.0;
instance uniform float assembly_alpha: hint_range(0.0, 1.0) = 1.0;
instance uniform float assembly_progress: hint_range(0.0, 1.0) = 1.0;
instance uniform float assembly_direction: hint_range(0.0, 3.0) = 0.0;
instance uniform float assembly_seed = 0.0;

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
    // SURFACE MATERIALIZATION
    // --------------------------------------------------

    float progress = clamp(assembly_progress, 0.0, 1.0);
    float assembly_coordinate = 1.0 - uv.x;
    if (assembly_direction >= 0.5 && assembly_direction < 1.5) {
        assembly_coordinate = uv.x;
    } else if (assembly_direction >= 1.5 && assembly_direction < 2.5) {
        // The lower surface condenses first, then the construction front moves up.
        assembly_coordinate = uv.y;
    } else if (assembly_direction >= 2.5) {
        // A center-out reveal gives selected platforms a different construction rhythm.
        assembly_coordinate = 1.0 - abs(uv.x - 0.5) * 2.0;
    }

    // A low-frequency procedural breakup makes the moving edge feel like a
    // material forming in place rather than a perfectly straight UI wipe.
    vec2 noise_cell = floor(uv * vec2(28.0, 5.0));
    float noise_value = fract(
        sin(dot(
            noise_cell + vec2(assembly_seed, assembly_seed * 0.37),
            vec2(12.9898, 78.233)
        )) * 43758.5453
    );
    float boundary_coordinate = assembly_coordinate + (noise_value - 0.5) * 0.075;
    float reveal_threshold = 1.0 - progress;
    float assembly_mask = smoothstep(
        reveal_threshold - 0.045,
        reveal_threshold + 0.045,
        boundary_coordinate
    );
    if (progress <= 0.0001) {
        assembly_mask = 0.0;
    } else if (progress >= 0.999) {
        assembly_mask = 1.0;
    }

    // A narrow cyan highlight rides the advancing material boundary, then
    // disappears as the platform locks into its finished ceramic surface.
    float front_distance = abs(boundary_coordinate - reveal_threshold);
    float construction_front = 1.0 - smoothstep(0.006, 0.072, front_distance);
    construction_front *= 1.0 - smoothstep(0.88, 1.0, progress);
    body += vec3(0.0, 0.42, 0.92) * construction_front;

    // --------------------------------------------------
    // OUTPUT
    // --------------------------------------------------

    COLOR = vec4(
        body,
        COLOR.a * clamp(assembly_alpha, 0.0, 1.0) * assembly_mask
    );
}