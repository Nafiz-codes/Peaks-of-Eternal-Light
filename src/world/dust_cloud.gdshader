shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float opacity = 0.0;
uniform float phase = 0.0;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 vec2 p=UV*5.0+vec2(phase+TIME*0.18,-TIME*0.13);
 float n=noise(p)*0.55+noise(p*2.1+TIME*0.08)*0.3+noise(p*4.2)*0.15;
 float edge=1.0-smoothstep(0.23,0.5,length(UV-vec2(0.5)));
 ALBEDO=mix(vec3(0.24,0.23,0.21),vec3(0.58,0.55,0.49),n);
 float depth=texture(scene_depth,SCREEN_UV).r;
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc=vec3(SCREEN_UV,depth)*2.0-1.0;
 #else
 vec3 ndc=vec3(SCREEN_UV*2.0-1.0,depth);
 #endif
 vec4 view=INV_PROJECTION_MATRIX*vec4(ndc,1.0);
 float soft_intersection=clamp((-view.z/view.w + VERTEX.z)/1.5,0.0,1.0);
 ALPHA=edge*smoothstep(0.18,0.75,n)*opacity*soft_intersection;
}

