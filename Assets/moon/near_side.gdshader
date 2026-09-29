shader_type spatial;
render_mode unshaded;
uniform sampler2D moon_image : source_color, filter_linear_mipmap;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    vec3 n = normalize(local_position);
    // Orthographic near-side photograph, not an equirectangular world map.
    // Original 1884 x 919 image: lunar disc centered at (942.0, 459.5).
    vec2 image_uv = vec2((942.0 + n.x * 459.5) / 1884.0, 0.5 - n.y * 0.5);
    vec3 photo = texture(moon_image, image_uv).rgb;
    float coverage = smoothstep(0.035, 0.08, n.z);
    ALBEDO = mix(vec3(0.12), photo, coverage);
}


