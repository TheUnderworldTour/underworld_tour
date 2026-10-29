shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 path_color : source_color = vec4(0.64, 0.49, 0.34, 1.0);
uniform vec4 edge_color : source_color = vec4(0.24, 0.16, 0.13, 1.0);
uniform float dot_spacing = 0.36;
uniform float dot_radius = 0.085;

// draws evenly spaced round dots using distance along the terrain-following ribbon
void fragment() {
	// the mesh supplies width across the ribbon and world-unit distance along it
	float across = (UV.x - 0.5) * 0.2;
	float along = mod(UV.y + dot_spacing * 0.5, dot_spacing) - dot_spacing * 0.5;
	float radius = length(vec2(across, along));
	float antialias = max(fwidth(radius), 0.001);
	if (radius > dot_radius + antialias) {
		discard;
	}
	// a quiet dark rim separates the center from thwe stone patches
	float rim = smoothstep(dot_radius - 0.022, dot_radius - 0.008, radius);
	ALBEDO = mix(path_color.rgb, edge_color.rgb, rim * 0.65);
	ALPHA = 1.0 - smoothstep(dot_radius - antialias, dot_radius + antialias, radius);
}
