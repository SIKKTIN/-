#[compute]
#version 450
#include "common.glslinc"
float hill(vec2 uv, vec2 center, vec2 radius, float height) {
    float r = length((uv-center)/radius);
    return height * (1.0-smoothstep(0.55,1.0,r));
}
void main() {
    ivec2 q = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(q,ivec2(p.grid.xy)))) return;
    vec2 uv = (vec2(q)+0.5)/p.grid.xy;
    float coast = 0.815 + 0.024*sin(uv.x*19.0) + 0.018*cos(uv.x*34.0);
    float z = -3.0 + 3.65*smoothstep(coast-0.36,coast+0.065,uv.y);
    z += hill(uv,vec2(0.17,0.70),vec2(0.075,0.071),2.8);
    z += hill(uv,vec2(0.77,0.67),vec2(0.065,0.058),3.0);
    z += hill(uv,vec2(0.85,0.78),vec2(0.065,0.09),1.8);
    if (p.options.z>0.5) z=-3.0;
    if (p.wave.w>0.5) {
        z = max(z, -3.0+hill(uv,vec2(0.45,0.40),vec2(0.013,0.0195),5.0));
        z = max(z, -3.0+hill(uv,vec2(0.55,0.40),vec2(0.013,0.0195),5.0));
        z = max(z, -3.0+hill(uv,vec2(0.475,0.59),vec2(0.011,0.0165),5.0));
        z = max(z, -3.0+hill(uv,vec2(0.525,0.59),vec2(0.011,0.0165),5.0));
        z = max(z, -3.0+hill(uv,vec2(0.475,0.75),vec2(0.011,0.0165),5.0));
        z = max(z, -3.0+hill(uv,vec2(0.525,0.75),vec2(0.011,0.0165),5.0));
    }
    float depth=max(0.0,-z);
    float eta=p.options.x>0.5 && p.options.x<1.5 ? incoming(uv,0.0) * smoothstep(0.03,0.6,depth) : 0.0;
    vec2 v=vec2(0.0,sqrt(G/3.0)*eta);
    float foam=0.0;
    if (p.options.x>1.5) {
        foam=exp(-dot((uv-vec2(0.30,0.50))*vec2(1.5,1.0),
                      (uv-vec2(0.30,0.50))*vec2(1.5,1.0))/0.001);
        v=vec2(0.8,0.0);
    }
    imageStore(terrain,q,vec4(z));
    imageStore(state_out,q,vec4(max(0.0,depth+eta),v,foam));
    imageStore(face_velocity,q,vec4(v,0.0,0.0));
}
