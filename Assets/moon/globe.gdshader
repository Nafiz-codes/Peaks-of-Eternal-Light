shader_type spatial;
render_mode unshaded;
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D legacy_color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// RGB stores the east/north/radial normal, in linear data space.
uniform sampler2D relief_map : filter_linear_mipmap, repeat_enable;
uniform bool use_legacy_map = false;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    vec3 radial = normalize(local_position);
    float longitude = atan(radial.x, radial.z);
    float latitude = asin(clamp(radial.y, -1.0, 1.0));
    // NASA maps: -180..180 east-positive longitude; north at the top.
    // Clamp V to texel centers so filtering never wraps north into south.
    vec2 map_uv = vec2(longitude / TAU + 0.5, 0.5 - latitude / PI);
    vec2 color_uv = vec2(map_uv.x, clamp(map_uv.y, 0.5 / 2048.0, 1.0 - 0.5 / 2048.0));
    // Correct the atan discontinuity before choosing mip levels at the far-side seam.
    vec2 dx = dFdx(map_uv);
    vec2 dy = dFdy(map_uv);
    dx.x -= round(dx.x);
    dy.x -= round(dy.x);
    vec3 color = textureGrad(color_map, color_uv, dx, dy).rgb;
    if (use_legacy_map) { color = textureGrad(legacy_color_map, color_uv, dx, dy).rgb; }
    vec2 relief_uv = vec2(map_uv.x, clamp(map_uv.y, 0.5 / 720.0, 1.0 - 0.5 / 720.0));
    vec3 detail = normalize(textureGrad(relief_map, relief_uv, dx, dy).rgb * 2.0 - 1.0);
    vec3 east = vec3(cos(longitude), 0.0, -sin(longitude));
    vec3 north = vec3(-sin(latitude) * sin(longitude), cos(latitude), -sin(latitude) * cos(longitude));
    vec3 surface_normal = normalize(east * detail.x + north * detail.y + radial * detail.z);
    vec3 view_normal = normalize(mat3(VIEW_MATRIX * MODEL_MATRIX) * surface_normal);
    // Camera-relative inspection light keeps every hemisphere readable.
    float lighting = 0.28 + 0.72 * max(dot(view_normal, normalize(vec3(-0.35, 0.45, 1.0))), 0.0);
    ALBEDO = color * lighting;
}

