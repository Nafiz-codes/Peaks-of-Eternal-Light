shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Local training overlay follows the existing terrain, without editing its mesh.
uniform vec2 zone_center = vec2(35.0, -10.0);
varying vec3 world_position;
void vertex() {
	VERTEX.y += 0.025;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float radius = length(world_position.xz - zone_center);
	if (radius > 16.0) { discard; }
	float grain = fract(sin(dot(world_position.xz, vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = vec3(0.19, 0.20, 0.22) * mix(0.8, 1.2, grain);
	EMISSION = vec3(0.008, 0.009, 0.012);
	ROUGHNESS = 1.0;
	AO = 0.15;
	ALPHA = 0.96 * (1.0 - smoothstep(12.0, 16.0, radius));
}
void light() {
	// Headlights illuminate the simulated shadow; direct sunlight is suppressed.
	if (!LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
}
