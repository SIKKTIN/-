#[compute]
#version 450
// Hybrid common ABI revision 3: transported material coordinates in foam.zw.
#include "common.glslinc"
void main(){
    ivec2 q=ivec2(gl_GlobalInvocationID.xy);if(any(greaterThanEqual(q,ivec2(p.grid.xy))))return;
    vec2 world=(vec2(q)+0.5)*p.grid.z;
    vec4 s=state(q);float depth=s.x,z=bed(q);
    float offshore=smoothstep(0.6,2.5,-z);
    vec4 wave=ocean(world);vec2 drift=s.yz+wave.yz*0.9*offshore;
    vec4 transported=foam_advect(vec2(q)-drift*p.grid.w/p.grid.z);
    if(p.options.w>0.5){imageStore(foam_out,q,vec4(transported.xy*exp(-p.grid.w*0.35),transported.zw));return;}
    float d=0.55;
    vec2 wxp=ocean(world+vec2(d,0)).yz,wxm=ocean(world-vec2(d,0)).yz;
    vec2 wyp=ocean(world+vec2(0,d)).yz,wym=ocean(world-vec2(0,d)).yz;
    vec2 ddx=(wxp-wxm)/(2.0*d),ddy=(wyp-wym)/(2.0*d);
    float chop=1.65;
    float jac=(1.0+chop*ddx.x)*(1.0+chop*ddy.y)-chop*chop*ddx.y*ddy.x;
    float whitecap=max(0.0,0.66-jac)*1.15*offshore;
    float shallow=1.0-smoothstep(0.08,1.15,depth);
    float compression=max(0.0,-(state(q+ivec2(1,0)).y-state(q-ivec2(1,0)).y
                            +state(q+ivec2(0,1)).z-state(q-ivec2(0,1)).z)/(2.0*p.grid.z));
    float impact=max(0.0,compression-0.055)*(0.25+shallow*3.2);
    // Foam is born in small cells only at a physical source, then the pattern itself is transported.
    float seed=random_cell(vec2(q)+floor(p.wave.x*9.0)*vec2(23,17));
    float source=(whitecap+impact)*float(p.options.y>0.5);
    float density=transported.x*exp(-p.grid.w*0.52)+source*p.grid.w*1.9;
    float fragments=transported.y*exp(-p.grid.w*0.42)+source*p.grid.w*1.6*smoothstep(0.32,0.78,seed);
    vec2 result=clamp(vec2(density,fragments),0.0,1.0);
    if(depth<DRY)result=vec2(0);
    // Material coordinates travel and deform with the flow; render detail is evaluated here,
    // rather than at fixed screen UVs. Newly wetted dry cells retain their original coordinates.
    imageStore(foam_out,q,vec4(result,depth<DRY?world:transported.zw));
}
