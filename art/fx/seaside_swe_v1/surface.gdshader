shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sim_state : filter_linear;
uniform sampler2D bed_map : filter_linear;
uniform float dx = 0.35;
uniform int display_mode = 0;
uniform bool draw_foam = true;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 a=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+1.0),f.x),f.y);
}
float surface(vec2 uv) { return texture(sim_state,uv).r+texture(bed_map,uv).r; }
void fragment() {
    vec4 s=texture(sim_state,UV); float bed=texture(bed_map,UV).r;
    vec2 texel=1.0/vec2(textureSize(sim_state,0));
    float eta=s.x+bed;
    vec2 slope=vec2(surface(UV+vec2(texel.x,0))-surface(UV-vec2(texel.x,0)),
                    surface(UV+vec2(0,texel.y))-surface(UV-vec2(0,texel.y)))/(2.0*dx);
    if (s.x<0.002) {
        float n=noise(UV*140.0)*0.5+noise(UV*37.0)*0.5;
        vec3 land=mix(vec3(0.25,0.30,0.19),vec3(0.47,0.44,0.32),n);
        if (UV.y<0.8) land=mix(vec3(0.28,0.30,0.27),vec3(0.53,0.52,0.43),n);
        COLOR=vec4(land,1.0);
    } else if (display_mode==1) {
        COLOR=vec4(mix(vec3(0.12,0.23,0.40),vec3(0.99,0.67,0.18),clamp(eta*1.3+0.5,0.0,1.0)),1.0);
    } else if (display_mode==2) {
        COLOR=vec4(0.5+s.y*0.6,0.5+s.z*0.6,0.20+length(s.yz)*0.3,1.0);
    } else if (display_mode==3) {
        COLOR=vec4(vec3(s.w),1.0);
    } else {
        vec3 normal=normalize(vec3(-slope.x*3.5,-slope.y*3.5,1.0));
        vec3 light=normalize(vec3(-0.45,-0.55,0.70));
        vec3 half_dir=normalize(light+vec3(0,0,1));
        float spec=pow(max(dot(normal,half_dir),0.0),80.0);
        float diff=clamp(dot(normal,light),0.0,1.0);
        vec3 shallow=vec3(0.16,0.44,0.41), deep=vec3(0.045,0.20,0.28);
        vec3 water=mix(shallow,deep,1.0-exp(-s.x*0.85));
        water*=0.55+diff*0.75;
        water+=vec3(0.72,0.82,0.81)*spec*0.65;
        // This noise only gives calculated foam a grain; it cannot create foam itself.
        float grain=mix(0.55,1.0,noise(UV*360.0));
        float foam=draw_foam?smoothstep(0.015,0.65,s.w)*grain:0.0;
        water=mix(water,vec3(0.87,0.91,0.85),foam);
        COLOR=vec4(water,1.0);
    }
}
