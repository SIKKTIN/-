shader_type particles;
render_mode disable_force,disable_velocity;
uniform sampler2D sim_state;
uniform sampler2D bed_map;
uniform sampler2D foam_map;
uniform vec2 canvas_size=vec2(1200,700);
uniform bool enabled=true;
uniform bool qa_emit_all=false;
float hash(uint x){x^=x>>16u;x*=0x7feb352du;x^=x>>15u;x*=0x846ca68bu;x^=x>>16u;return float(x&0x00ffffffu)/16777216.0;}
void start(){
    uint seed=NUMBER*1664525u+RANDOM_SEED;
    float x=hash(seed+1u);
    float coast=.815+.024*sin(x*19.0)+.018*cos(x*34.0);
    // Proposal distribution follows the bathymetry; acceptance still depends on solved impact.
    vec2 uv=vec2(x,coast-.082+mix(-.026,.018,hash(seed+2u)));
    if(hash(seed+3u)<.22){
        vec2 centers[6]={vec2(.45,.4),vec2(.55,.4),vec2(.475,.59),vec2(.525,.59),vec2(.475,.75),vec2(.525,.75)};
        int i=int(hash(seed+4u)*5.999);uv=centers[i]+vec2(hash(seed+5u)-.5,hash(seed+6u)-.5)*vec2(.044,.06);
    }
    vec4 state=texture(sim_state,uv);float foam=texture(foam_map,uv).r;
    float z=texture(bed_map,uv).r;
    float impact=foam*(1.0-smoothstep(.15,1.3,state.x));
    ACTIVE=qa_emit_all||(enabled&&state.x>=.012&&z>= -1.4&&impact>=.12&&hash(seed+7u)<=impact*.7);
    TRANSFORM=mat4(1.0);
    TRANSFORM[3].xy=uv*canvas_size;
    VELOCITY=vec3(state.yz*vec2(8.9,7.8)+vec2(hash(seed+8u)-.5,hash(seed+9u)-.5)*15.0,0);
    CUSTOM=vec4(0,0,15.0+hash(seed+10u)*25.0,.65+hash(seed+11u)*.5);
    float size=.20+hash(seed+12u)*.35;TRANSFORM[0].x=size;TRANSFORM[1].y=size;
    COLOR=vec4(.87,.87,.74,.8);
}
void process(){
    CUSTOM.x+=DELTA;
    TRANSFORM[3].xy+=VELOCITY.xy*DELTA;
    // Project vertical ballistic motion into the 2D view.
    TRANSFORM[3].y-=CUSTOM.z*DELTA;CUSTOM.z-=65.0*DELTA;
    COLOR.a=.8*clamp(1.0-CUSTOM.x/CUSTOM.w,0.0,1.0);
    if(CUSTOM.x>CUSTOM.w)ACTIVE=false;
}
