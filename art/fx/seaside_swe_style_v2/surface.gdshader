shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sim_state : filter_linear;
uniform sampler2D bed_map : filter_linear;
uniform sampler2D grass_map : filter_linear_mipmap, repeat_enable;
uniform float dx = 0.35;
uniform int display_mode = 0;
uniform bool draw_foam = true;
uniform vec2 canvas_size = vec2(1200.0,700.0);
float hash(vec2 p) {
    // Polynomial hash avoids many transcendental instructions per screen pixel.
    vec3 q=fract(vec3(p.xyx)*0.1031);
    q+=dot(q,q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}
float noise(vec2 p) {
    vec2 a=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+1.0),f.x),f.y);
}
float surface(vec2 uv) { return texture(sim_state,uv).r+texture(bed_map,uv).r; }
void fragment() {
    // Small brush-sized cells soften the synthetic specular without reducing solver resolution.
    vec2 uv=(floor(UV*canvas_size/1.6)+0.5)*1.6/canvas_size;
    vec4 s=texture(sim_state,uv);
    float z=texture(bed_map,uv).r;
    vec2 texel=1.0/vec2(textureSize(sim_state,0));
    float eta=s.x+z;
    vec2 slope=vec2(surface(uv+vec2(texel.x,0))-surface(uv-vec2(texel.x,0)),
                    surface(uv+vec2(0,texel.y))-surface(uv-vec2(0,texel.y)))/(2.0*dx);
    float brush=noise(uv*vec2(160.0,100.0));
    if (s.x<0.002) {
        vec3 grass=texture(grass_map,uv*canvas_size/180.0).rgb;
        vec3 ground=grass*vec3(0.90,0.96,0.92);
        // Exposed shoals use lit rock facets; no fixed foam or waves are painted here.
        if (uv.y<0.80) {
            vec2 dz=vec2(texture(bed_map,uv+vec2(texel.x,0)).r-texture(bed_map,uv-vec2(texel.x,0)).r,
                         texture(bed_map,uv+vec2(0,texel.y)).r-texture(bed_map,uv-vec2(0,texel.y)).r)/(2.0*dx);
            vec3 rock_normal=normalize(vec3(-dz*1.7,1.0));
            float lit=dot(rock_normal,normalize(vec3(-0.5,-0.6,1.0)));
            float facet=floor(clamp(lit*0.8+brush*0.18,0.0,1.0)*5.0)/5.0;
            ground=mix(vec3(0.28,0.29,0.25),vec3(0.57,0.53,0.42),facet);
            ground*=0.92+brush*0.13;
        }
        COLOR=vec4(ground,1.0);
    } else if (display_mode==1) {
        COLOR=vec4(mix(vec3(0.12,0.23,0.40),vec3(0.99,0.67,0.18),clamp(eta*1.3+0.5,0.0,1.0)),1.0);
    } else if (display_mode==2) {
        COLOR=vec4(0.5+s.y*0.6,0.5+s.z*0.6,0.20+length(s.yz)*0.3,1.0);
    } else if (display_mode==3) {
        COLOR=vec4(vec3(s.w),1.0);
    } else {
        vec3 normal=normalize(vec3(-slope*1.9,1.0));
        vec3 light=normalize(vec3(-0.45,-0.55,0.70));
        float diff=clamp(dot(normal,light),0.0,1.0);
        float paint_light=mix(diff,floor(diff*6.0)/6.0,0.28);
        vec3 shallow=vec3(0.38,0.49,0.42), deep=vec3(0.15,0.27,0.29);
        vec3 water=mix(shallow,deep,1.0-exp(-s.x*0.9));
        water*=0.70+paint_light*0.42;
        water*=0.97+brush*0.05;
        // Highlights are broad, dull and warm; all normals still come from the solved height.
        vec3 half_dir=normalize(light+vec3(0,0,1));
        float spec=pow(max(dot(normal,half_dir),0.0),24.0);
        water+=vec3(0.36,0.37,0.30)*spec*0.18;
        // Broken brush clusters give the transported foam texture. They never generate foam.
        float fleck=noise(uv*vec2(250.0,160.0))*0.65+noise(uv*vec2(480.0,300.0))*0.35;
        float fragments=smoothstep(0.35,0.68,fleck);
        float foam=draw_foam?smoothstep(0.16,0.88,s.w)*(0.15+fragments*0.75):0.0;
        vec3 warm_foam=mix(vec3(0.66,0.70,0.60),vec3(0.88,0.87,0.74),fragments);
        water=mix(water,warm_foam,foam);
        COLOR=vec4(water,1.0);
    }
}
