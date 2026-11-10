shader_type spatial;
render_mode diffuse_burley;

// Meter-scaled surface detail, continuous between the ground and horizon.
uniform vec3 dust_dark : source_color = vec3(0.24, 0.225, 0.20);
uniform vec3 dust_light : source_color = vec3(0.48, 0.455, 0.405);
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
float crater_relief(vec2 p) {
	vec2 cell = floor(p / 3.4);
	float height = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = cell + vec2(float(x), float(y));
			float seed = hash(id);
			vec2 center = (id + 0.2 + 0.6 * vec2(hash(id + 7.0), hash(id + 19.0))) * 3.4;
			float radius = mix(0.22, 1.05, seed * seed);
			float r = length(p - center) / radius;
			float irregular = 0.92 + 0.16 * noise(p * 9.0);
			float rim = exp(-pow((r * irregular - 1.0) / 0.13, 2.0));
			float bowl = 1.0 - smoothstep(0.25, 0.96, r);
			height += radius * (0.07 * rim - 0.09 * bowl);
		}
	}
	return height;
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	float distance_fade = 1.0 - smoothstep(22.0, 95.0, length(VERTEX));
	float relief = crater_relief(p);
	float patches = noise(p * 0.18) * 0.55 + noise(p * 0.85) * 0.3 + noise(p * 3.0) * 0.15;
	float grit = noise(p * 65.0);
	float gravel = pow(noise(p * 18.0), 5.0);
	float height = (relief + (noise(p * 5.0) - 0.5) * 0.012 + gravel * 0.025 + grit * 0.0015) * distance_fade;
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 n = normalize(NORMAL);
	vec3 r1 = cross(dy, n);
	vec3 r2 = cross(n, dx);
	float determinant = dot(dx, r1);
	vec3 gradient = (dFdx(height) * r1 + dFdy(height) * r2) / (abs(determinant) + 0.000001) * sign(determinant);
	NORMAL = normalize(n - gradient);
	vec3 dust = mix(dust_dark, dust_light, patches);
	dust *= 0.92 + 0.16 * mix(0.5, grit, distance_fade);
	dust *= 1.0 + clamp(relief * 1.7, -0.13, 0.09);
	ALBEDO = dust;
	ROUGHNESS = 0.98;
	SPECULAR = 0.12;
	AO = 1.0 - clamp(-relief * 1.8, 0.0, 0.18);
}
