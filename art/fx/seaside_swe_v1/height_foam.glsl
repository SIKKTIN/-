#[compute]
#version 450
#include "common.glslinc"
void main() {
    ivec2 q=ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(q,ivec2(p.grid.xy)))) return;
    vec4 s=state(q); vec2 v=faces(q);
    float left=q.x>0?faces(q-ivec2(1,0)).x:0.0;
    float up=q.y>0?faces(q-ivec2(0,1)).y:0.0;
    float hr=v.x>0.0?s.x:state(q+ivec2(1,0)).x;
    float hl=left>0.0?state(q-ivec2(1,0)).x:s.x;
    float hd=v.y>0.0?s.x:state(q+ivec2(0,1)).x;
    float hu=up>0.0?state(q-ivec2(0,1)).x:s.x;
    float h=max(0.0,s.x-p.grid.w/p.grid.z*(hr*v.x-hl*left+hd*v.y-hu*up));
    vec2 uv=(vec2(q)+0.5)/p.grid.xy;
    // Waves enter at the seaward boundary; the interior is advanced by the solver.
    if (p.wave.z>0.5 && q.y<6 && bed(q)<-1.0) {
        float eta=incoming(uv,p.wave.x);
        float weight=1.0-smoothstep(1.0,6.0,float(q.y));
        h=mix(h,max(0.0,-bed(q)+eta),weight);
        v.y=mix(v.y,sqrt(G/3.0)*eta,weight);
    }
    if (p.impulse.w!=0.0 && bed(q)<0.0) {
        vec2 d=(uv-p.impulse.xy)*vec2(p.grid.x/p.grid.y,1.0);
        h=max(0.0,h+p.impulse.w*exp(-dot(d,d)/(p.impulse.z*p.impulse.z)));
    }
    vec2 center_v=0.5*(v+vec2(left,up));
    vec2 back=vec2(q)-center_v*p.grid.w/p.grid.z;
    float advected=interpolate_state(back).w;
    float lap=state(q+ivec2(1,0)).w+state(q-ivec2(1,0)).w
             +state(q+ivec2(0,1)).w+state(q-ivec2(0,1)).w-4.0*s.w;
    float compression=max(0.0,-(v.x-left+v.y-up)/p.grid.z);
    float shallow=1.0-smoothstep(0.05,1.2,h);
    float production=max(0.0,compression-0.025)*(0.6+shallow*5.0);
    // Persistent transported foam; only new production is optional for the decay test.
    float foam=max(0.0,advected+0.06*p.grid.w/(p.grid.z*p.grid.z)*lap);
    if (p.options.y>0.5) foam+=production*p.grid.w*2.8;
    foam=clamp(foam*exp(-p.grid.w*0.35),0.0,1.0);
    if (h<DRY) { h=0.0; foam=0.0; }
    imageStore(state_out,q,vec4(h,v,foam));
}
