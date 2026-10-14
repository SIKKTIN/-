shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sim_state : filter_linear;
uniform sampler2D bed_map : filter_linear;
uniform sampler2D foam_map : filter_linear;
uniform sampler2DArray ocean_map : filter_linear;
uniform sampler2D grass_map : filter_linear_mipmap, repeat_enable;
uniform float dx=0.35;
uniform int display_mode=0;
uniform bool draw_foam=true;
uniform vec2 canvas_size=vec2(1200.0,700.0);
uniform vec2 world_size=vec2(134.4,89.6);
float hash(vec2 p){vec3 q=fract(vec3(p.xyx)*0.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float noise(vec2 p){vec2 a=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+1.0),f.x),f.y);}
vec4 ocean(vec2 world){return texture(ocean_map,vec3(fract(world/134.4),0.0))+texture(ocean_map,vec3(fract(world/33.6),1.0));}
float height(vec2 uv){
    float z=texture(bed_map,uv).r;
    vec2 world=uv*world_size;
    vec4 wave=ocean(world);
    float spectral=ocean(world-wave.yz*1.45).x;
    return mix(texture(sim_state,uv).x+z,spectral,smoothstep(0.65,2.5,-z));
}
void fragment(){
    vec2 uv=(floor(UV*canvas_size/1.2)+0.5)*1.2/canvas_size;
    vec4 s=texture(sim_state,uv);float z=texture(bed_map,uv).r;
    vec2 texel=vec2(0.24)/world_size;
    float h=height(uv);
    vec2 slope=vec2(height(uv+vec2(texel.x,0))-height(uv-vec2(texel.x,0)),height(uv+vec2(0,texel.y))-height(uv-vec2(0,texel.y)))/0.48;
    vec4 foam=texture(foam_map,uv);
    if(s.x<0.002){
        vec3 ground=texture(grass_map,uv*canvas_size/180.0).rgb*vec3(0.90,0.96,0.92);
        if(uv.y<0.80){
            vec2 dz=vec2(texture(bed_map,uv+vec2(texel.x,0)).r-texture(bed_map,uv-vec2(texel.x,0)).r,texture(bed_map,uv+vec2(0,texel.y)).r-texture(bed_map,uv-vec2(0,texel.y)).r)/0.48;
            float lit=dot(normalize(vec3(-dz*1.7,1)),normalize(vec3(-0.5,-0.6,1)));
            float brush=noise(uv*vec2(160,100));float facet=floor(clamp(lit*0.8+brush*0.18,0.0,1.0)*5.0)/5.0;
            ground=mix(vec3(.28,.29,.25),vec3(.57,.53,.42),facet)*(0.92+brush*0.13);
        }
        COLOR=vec4(ground,1);
    }else if(display_mode==1){COLOR=vec4(mix(vec3(.12,.23,.4),vec3(.99,.67,.18),clamp(h*1.3+.5,0.0,1.0)),1);}
    else if(display_mode==2){COLOR=vec4(.5+s.y*.6,.5+s.z*.6,.2+length(s.yz)*.3,1);}
    else if(display_mode==3){COLOR=vec4(foam.x,foam.y,foam.x*.35,1);}
    else{
        // All moving highlights and crests derive from the computed hybrid heightfield.
        vec3 n=normalize(vec3(-slope*2.15,1));
        vec3 light=normalize(vec3(-.45,-.55,.70));
        float diffuse=clamp(dot(n,light),0.0,1.0);
        diffuse=mix(diffuse,floor(diffuse*9.0)/9.0,.2);
        vec3 deep=vec3(.13,.265,.29),shallow=vec3(.36,.48,.40);
        vec3 water=mix(shallow,deep,1.0-exp(-s.x*.85));
        water*=.58+diffuse*.62;
        float reflect_band=smoothstep(.65,.91,n.z)*smoothstep(-.08,.26,-slope.y);
        water=mix(water,vec3(.43,.53,.49),reflect_band*.18);
        float glint=pow(max(dot(n,normalize(light+vec3(0,0,1))),0.0),35.0);
        water+=vec3(.62,.63,.52)*glint*.34;
        // Both density and fine structure are GPU fields advected by the solved flow.
        float grain=noise(foam.zw*1.65)*.7+noise(foam.zw*3.7)*.3;
        float clusters=smoothstep(.32,.69,grain);
        float cover=draw_foam?smoothstep(.09,.85,foam.x)*(.10+.80*clusters):0.0;
        vec3 froth=mix(vec3(.62,.70,.63),vec3(.88,.87,.74),clusters);
        water=mix(water,froth,cover*.92);
        COLOR=vec4(water,1);
    }
}
