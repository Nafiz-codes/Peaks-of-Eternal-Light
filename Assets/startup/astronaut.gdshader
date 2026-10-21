shader_type canvas_item;
// Suppress lettering in the supplied photograph's background only.
void fragment() {
	vec4 photo = texture(TEXTURE, UV);
	float mask = 1.0;
	if (UV.y > 0.44 && UV.y < 0.51 && (UV.x < 0.331 || UV.x > 0.685)) { mask = 0.0; }
	if (UV.x > 0.675 && UV.y > 0.66) { mask = 0.0; }
	float luminance = max(photo.r, max(photo.g, photo.b));
	float edge = smoothstep(0.025, 0.12, luminance);
	COLOR *= vec4(photo.rgb, mask * edge);
}
