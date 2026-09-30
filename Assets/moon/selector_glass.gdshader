shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 panel_size = vec2(160.0, 40.0);

void fragment() {
	vec2 half_size = max(panel_size, vec2(1.0)) * 0.5;
	float radius = min(14.0, min(half_size.x, half_size.y));
	vec2 edge = abs((UV - 0.5) * panel_size) - half_size + radius;
	float distance_to_edge = length(max(edge, vec2(0.0))) + min(max(edge.x, edge.y), 0.0) - radius;
	float mask = 1.0 - smoothstep(-1.0, 1.0, distance_to_edge);
	vec3 blurred = vec3(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			blurred += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * SCREEN_PIXEL_SIZE * 2.0).rgb;
		}
	}
	blurred /= 25.0;
	vec3 tint = mix(vec3(0.035, 0.07, 0.12), vec3(0.18, 0.26, 0.34), 1.0 - UV.y);
	COLOR = vec4(mix(blurred, tint, 0.58), mask * 0.94);
}
