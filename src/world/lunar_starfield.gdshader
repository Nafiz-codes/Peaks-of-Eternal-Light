shader_type sky;

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
}
