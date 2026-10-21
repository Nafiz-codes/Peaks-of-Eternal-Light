shader_type spatial;
render_mode unshaded;

uniform sampler2D surface_map : source_color, filter_linear_mipmap;
uniform sampler2D cloud_map : source_color, filter_linear_mipmap;
uniform sampler2D night_map : source_color, filter_linear_mipmap;

void fragment() {
	vec3 surface = texture(surface_map, UV).rgb;
	float clouds = texture(cloud_map, UV).r;
	vec3 normal = normalize(NORMAL);
	float day = dot(normal, normalize(vec3(-0.45, 0.7, 0.65)));
	vec3 color = mix(surface, vec3(0.95), clouds * 0.9) * (0.045 + max(day, 0.0) * 1.15);
	color += texture(night_map, UV).rgb * (1.0 - smoothstep(-0.1, 0.15, day)) * (1.0 - clouds) * 0.6;
	float rim = pow(1.0 - max(dot(normal, VIEW), 0.0), 4.0);
	ALBEDO = color + vec3(0.12, 0.35, 0.8) * rim * smoothstep(-0.3, 0.3, day) * 0.65;
}
