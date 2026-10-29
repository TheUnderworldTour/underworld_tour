shader_type spatial;
render_mode cull_disabled;

uniform vec4 basalt_color : source_color = vec4(0.16, 0.095, 0.17, 1.0);
uniform vec4 warm_rock_color : source_color = vec4(0.33, 0.14, 0.14, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.18, 0.025, 1.0);
varying vec3 ground_position;

// returns repeatable per-cell values for stone centers and color variation
vec2 cell_random(vec2 cell) {
	return fract(sin(vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
}

// passes the undisplaced mesh position to the fragment shader for the ground pattern
void vertex() {
	ground_position = VERTEX;
}

// shades irregular basalt cells with dark borders and occasional ember seams
void fragment() {
	// set the stone scale in mesh coordinates so the pattern follows the board
	vec2 point = ground_position.xz * 0.85;
	vec2 cell = floor(point);
	float nearest = 10.0;
	float second_nearest = 10.0;
	vec2 stone = vec2(0.0);
	// search neighboring cells for the two closest stone centers
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = cell + vec2(float(x), float(y));
			vec2 center = neighbor + 0.2 + cell_random(neighbor) * 0.6;
			float distance_to_center = distance(point, center);
			if (distance_to_center < nearest) {
				second_nearest = nearest;
				nearest = distance_to_center;
				stone = neighbor;
			} else {
				second_nearest = min(second_nearest, distance_to_center);
			}
		}
	}
	// similar distances identify borders between neighboring stones
	float edge = second_nearest - nearest;
	float seams = 1.0 - smoothstep(0.015, 0.065, edge);
	float variation = cell_random(stone).x;
	vec3 rock = mix(basalt_color.rgb, warm_rock_color.rgb, variation * 0.7);
	// broad, graphic stone shapes with occasional quiet ember seams.
	// light only a sparse subset of seams to keep the ground pattern readable
	float embers = seams * smoothstep(0.66, 0.92, cell_random(stone + 17.0).y);
	ALBEDO = mix(rock, vec3(0.055, 0.025, 0.055), seams * 0.8);
	// add material glow without introducing the future lava river or scene lights
	EMISSION = ember_color.rgb * embers * 0.65;
	ROUGHNESS = 0.92;
}
