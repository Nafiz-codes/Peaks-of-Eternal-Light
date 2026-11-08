shader_type canvas_item;
render_mode unshaded;
uniform sampler2D earth_texture : source_color, filter_linear, repeat_enable;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
	vec2 uv = UV;
	vec2 p = uv * vec2(1.66, 1.0);
	float cloud = noise(p * 5.0) * noise(p * 11.0);
	vec3 col = vec3(0.008, 0.022, 0.043) + cloud * vec3(0.045, 0.14, 0.23);
	vec2 cell = floor(p * 520.0);
	vec2 point = fract(p * 520.0) - 0.5;
	float star = smoothstep(0.13, 0.0, length(point)) * step(0.965, hash(cell));
	col += star * vec3(0.5, 0.75, 0.9);
	vec2 globe = (p - vec2(1.70, 0.40)) / 0.66;
	float radius = length(globe);
	float atmosphere = exp(-abs(radius - 1.0) * 65.0);
	col += atmosphere * vec3(0.04, 0.32, 0.48);
	if (radius < 1.0) {
		vec3 normal = vec3(globe, sqrt(1.0 - radius * radius));
		float light = max(dot(normal, normalize(vec3(-0.9, -0.35, 0.6))), 0.0);
		vec2 sphere_uv = vec2(atan(normal.x, normal.z) / 6.283185 + 0.5, asin(normal.y) / 3.141593 + 0.5);
		vec3 surface = texture(earth_texture, sphere_uv).rgb * vec3(0.65, 0.85, 1.0);
		col = surface * (0.06 + light * 0.85) + pow(1.0 - normal.z, 5.0) * light * vec3(0.08, 0.36, 0.49);
	}
	vec2 flare = (uv - vec2(0.68, 0.92)) * vec2(1.66, 1.0);
	col += vec3(0.08, 0.65, 0.95) * exp(-length(flare) * 170.0);
	col += vec3(0.02, 0.24, 0.36) * exp(-abs(flare.y) * 800.0) * exp(-abs(flare.x) * 8.0);
	COLOR = vec4(col, 1.0);
}
