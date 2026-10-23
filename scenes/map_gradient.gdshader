shader_type spatial;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.1, 0.3, 0.9, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);

varying float map_z;

void vertex() {
	map_z = VERTEX.z;
}

void fragment() {
	float progress = clamp((map_z + 20.0) / 40.0, 0.0, 1.0);
	ALBEDO = mix(top_color.rgb, bottom_color.rgb, progress);
}
