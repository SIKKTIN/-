#[compute]
#version 450
// Tessendorf spectral evolution, Hermitian pairs, finite-depth dispersion.
layout(local_size_x=8, local_size_y=8, local_size_z=1) in;
layout(rgba32f,set=0,binding=0) readonly uniform image2DArray seed_map;
layout(rgba32f,set=0,binding=1) writeonly uniform image2DArray frequency_map;
layout(push_constant,std430) uniform Params { vec4 spec; } p; // time, amplitude multiplier, QA single mode, unused
vec2 cmul(vec2 a,vec2 b){return vec2(a.x*b.x-a.y*b.y,a.x*b.y+a.y*b.x);}
void main(){
    ivec3 q=ivec3(gl_GlobalInvocationID); int n=imageSize(seed_map).x;
    if(q.x>=n||q.y>=n||q.z>=2)return;
    ivec2 signed_q=ivec2(q.x<n/2?q.x:q.x-n,q.y<n/2?q.y:q.y-n);
    float length_m=q.z==0?134.4:33.6;
    vec2 k=vec2(signed_q)*6.28318530718/length_m;
    float mag=length(k), omega=sqrt(9.81*mag*tanh(mag*3.0));
    vec2 a=imageLoad(seed_map,q).xy;
    vec2 b=imageLoad(seed_map,ivec3((n-q.x)%n,(n-q.y)%n,q.z)).xy; b.y=-b.y;
    vec2 phase=vec2(cos(omega*p.spec.x),sin(omega*p.spec.x));
    vec2 ha=cmul(a,phase),hb=cmul(b,vec2(phase.x,-phase.y));
    vec2 h=(ha+hb)*p.spec.y;
    vec2 dh=cmul(vec2(0,omega),ha-hb)*p.spec.y;
    // QA isolates one Hermitian pair with a known analytical inverse transform.
    if(p.spec.z>0.5){
        h=(q.z==0&&((q.x==3&&q.y==5)||(q.x==n-3&&q.y==n-5)))?vec2(float(n*n)*0.5,0):vec2(0); dh=vec2(0);
    }
    vec2 ih=vec2(h.y,-h.x); // -i*h -> horizontal choppy displacement
    vec2 unit_k=mag>0.0?k/mag:vec2(0);
    imageStore(frequency_map,ivec3(q.xy,q.z*2),vec4(h,ih*unit_k.x));
    imageStore(frequency_map,ivec3(q.xy,q.z*2+1),vec4(ih*unit_k.y,dh));
}
