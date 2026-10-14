shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float brightness = 1.0;
void fragment() {
	COLOR = vec4(texture(screen_texture, SCREEN_UV).rgb * brightness, 1.0);
}
