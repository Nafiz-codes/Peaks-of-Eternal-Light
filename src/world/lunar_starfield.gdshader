shader_type sky;

uniform sampler2D earth_surface : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D earth_clouds : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D earth_night : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D earth_gloss : filter_linear_mipmap, repeat_enable;
// NASA/JPL topocentric apparent position in kilometers. Local scene units are meters.
uniform vec3 earth_position_km;
uniform float earth_radius_km = 6378.137;
uniform float earth_longitude : hint_range(-180.0, 180.0) = 20.0;
uniform vec3 earth_sun_direction = vec3(-0.65, 0.35, 0.68);

vec3 earth_color(vec3 ray, vec3 center, float radius) {
	float projection = dot(ray, center);
	float discriminant = radius * radius - (1.0 - projection * projection);
	vec3 normal = normalize(ray * (projection - sqrt(max(discriminant, 0.0))) - center);
	vec2 earth_uv = vec2(atan(normal.x, normal.z) / TAU + 0.5 + earth_longitude / 360.0,
		acos(clamp(normal.y, -1.0, 1.0)) / PI);
	vec3 surface = texture(earth_surface, earth_uv).rgb;
	float clouds = texture(earth_clouds, earth_uv).r;
	vec3 sunlight = normalize(earth_sun_direction);
	float day = dot(normal, sunlight);
	vec3 color = mix(surface, vec3(0.94), clouds * 0.88) * (0.025 + max(day, 0.0));
	color += texture(earth_night, earth_uv).rgb * (1.0 - smoothstep(-0.12, 0.08, day)) * (1.0 - clouds);
	float ocean = texture(earth_gloss, earth_uv).r;
	color += vec3(0.7, 0.82, 1.0) * pow(max(dot(normal, normalize(sunlight - ray)), 0.0), 80.0) * ocean * (1.0 - clouds) * max(day, 0.0);
	float rim = pow(1.0 - max(dot(normal, -ray), 0.0), 4.0);
	return color + vec3(0.12, 0.35, 0.75) * rim * smoothstep(-0.2, 0.4, day) * 0.4;
}

// Fixed pinpoints on a black sky. No atmospheric glow or animated twinkling.
float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	vec3 a = abs(direction);
	vec2 uv;
	float face;
	if (a.x >= a.y && a.x >= a.z) {
		uv = direction.yz / a.x;
		face = direction.x > 0.0 ? 1.0 : 2.0;
	} else if (a.y >= a.z) {
		uv = direction.xz / a.y;
		face = direction.y > 0.0 ? 3.0 : 4.0;
	} else {
		uv = direction.xy / a.z;
		face = direction.z > 0.0 ? 5.0 : 6.0;
	}
	vec2 grid = uv * 220.0;
	vec3 cell = vec3(floor(grid), face * 17.0);
	float chance = hash(cell);
	vec2 center = vec2(hash(cell + 7.0), hash(cell + 19.0)) * 0.5 + 0.25;
	float radius = mix(0.10, 0.24, hash(cell + 31.0));
	float distance = length(fract(grid) - center);
	float aa = max(length(fwidth(grid)) * 0.45, 0.015);
	float star = (1.0 - smoothstep(max(0.0, radius - aa), radius + aa, distance)) * step(0.9985, chance);
	vec3 tint = mix(vec3(0.80, 0.87, 1.0), vec3(1.0, 0.94, 0.83), hash(cell + 53.0));
	COLOR = vec3(0.0003, 0.0004, 0.0007) + tint * star * mix(0.45, 1.8, hash(cell + 71.0));
	vec3 earth_relative_km = earth_position_km - POSITION * 0.001;
	vec3 earth_center = normalize(earth_relative_km);
	// Normalize the ray/sphere calculation to avoid astronomical float precision loss.
	float earth_radius = earth_radius_km / length(earth_relative_km);
	float separation = length(cross(direction, earth_center));
	float edge_aa = max(fwidth(separation), 0.00001);
	if (dot(direction, earth_center) > 0.0 && separation < earth_radius) {
		float coverage = 1.0 - smoothstep(earth_radius - edge_aa, earth_radius, separation);
		COLOR = mix(COLOR, earth_color(direction, earth_center, earth_radius), coverage);
	}
}
