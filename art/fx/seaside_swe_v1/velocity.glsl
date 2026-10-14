#[compute]
#version 450
#include "common.glslinc"
void main() {
    ivec2 q=ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(q,ivec2(p.grid.xy)))) return;
    vec4 s=state(q); vec4 right=state(q+ivec2(1,0)); vec4 down=state(q+ivec2(0,1));
    float surface=s.x+bed(q), sx=right.x+bed(q+ivec2(1,0)), sy=down.x+bed(q+ivec2(0,1));
    float dt=p.grid.w, dx=p.grid.z;
    // Semi-Lagrangian advection of staggered face velocities.
    float cross_v=interpolate_state(vec2(q)+vec2(0.5,-0.5)).z;
    float cross_u=interpolate_state(vec2(q)+vec2(-0.5,0.5)).y;
    vec2 v=vec2(interpolate_state(vec2(q)-dt*vec2(s.y,cross_v)/dx).y,
                interpolate_state(vec2(q)-dt*vec2(cross_u,s.z)/dx).z);
    v -= dt*G*vec2(sx-surface,sy-surface)/dx;
    if ((s.x<DRY && sx<bed(q)+DRY) || (right.x<DRY && surface<bed(q+ivec2(1,0))+DRY)) v.x=0.0;
    if ((s.x<DRY && sy<bed(q)+DRY) || (down.x<DRY && surface<bed(q+ivec2(0,1))+DRY)) v.y=0.0;
    // Bound outgoing flux by donor depth; wet/dry boundaries remain positive.
    float donor_x=v.x>=0.0?s.x:right.x, donor_y=v.y>=0.0?s.x:down.x;
    v.x=clamp(v.x,-0.45*dx/dt,0.45*dx/dt);
    v.y=clamp(v.y,-0.45*dx/dt,0.45*dx/dt);
    if (donor_x<DRY) v.x=0.0;
    if (donor_y<DRY) v.y=0.0;
    float drag = 0.018 + (1.0-smoothstep(0.02,0.35,s.x))*0.9;
    v*=exp(-dt*drag);
    if (p.options.z<0.5) {
        float edge=min(float(q.x),p.grid.x-1.0-float(q.x));
        v*=exp(-dt*1.1*(1.0-smoothstep(0.0,12.0,edge)));
    }
    if (q.x>=int(p.grid.x)-1) v.x=0.0;
    if (q.y>=int(p.grid.y)-1) v.y=0.0;
    imageStore(face_velocity,q,vec4(v,0.0,0.0));
}
