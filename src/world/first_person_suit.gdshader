shader_type spatial;
uniform sampler2D suit_texture : source_color, filter_linear_mipmap;
uniform vec4 suit_color : source_color = vec4(1.0);
uniform bool has_texture = false;
uniform mat4 world_to_body;
varying vec3 body_position;
varying vec3 view_position;
void vertex() {
	body_position = (world_to_body * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Cut away helmet, collar, backpack and upper chest only in first person.
	// Keep limbs below/outside that region, with a final camera safety clearance.
	if (body_position.y > 1.48 || (body_position.y > 1.02 && abs(body_position.x) < 0.28) || length(view_position) < 0.25) {
		discard;
	}
	ALBEDO = suit_color.rgb;
	if (has_texture) { ALBEDO *= texture(suit_texture, UV).rgb; }
	ROUGHNESS = 0.85;
}
