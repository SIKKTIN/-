#[compute]
#version 450
// Radix-2 DIT inverse FFT: one workgroup per row/column. Independent implementation.
layout(local_size_x=128,local_size_y=1,local_size_z=1) in;
layout(rgba32f,set=0,binding=0) readonly uniform image2DArray source_map;
layout(rgba32f,set=0,binding=1) writeonly uniform image2DArray target_map;
layout(push_constant,std430) uniform Params { ivec4 config; } p; // axis, ABI pad
shared vec4 ping[128]; shared vec4 pong[128];
vec2 cmul(vec2 a,vec2 b){return vec2(a.x*b.x-a.y*b.y,a.x*b.y+a.y*b.x);}
void main(){
    int x=int(gl_LocalInvocationID.x),row=int(gl_WorkGroupID.x),layer=int(gl_WorkGroupID.y);
    int reversed=int(bitfieldReverse(uint(x))>>25);
    ivec2 src=p.config.x==0?ivec2(reversed,row):ivec2(row,reversed);
    ping[x]=imageLoad(source_map,ivec3(src,layer)); barrier();
    for(int stage=0;stage<7;stage++){
        int span=1<<(stage+1),half_span=span/2,j=x%half_span,base=(x/span)*span;
        vec4 a=stage%2==0?ping[base+j]:pong[base+j];
        vec4 b=stage%2==0?ping[base+j+half_span]:pong[base+j+half_span];
        float angle=6.28318530718*float(j)/float(span);
        vec2 w=vec2(cos(angle),sin(angle));
        vec4 wb=vec4(cmul(b.xy,w),cmul(b.zw,w));
        vec4 result=a+(x%span<half_span?wb:-wb);
        if(stage%2==0)pong[x]=result;else ping[x]=result;
        barrier();
    }
    ivec2 dst=p.config.x==0?ivec2(x,row):ivec2(row,x);
    imageStore(target_map,ivec3(dst,layer),pong[x]/128.0);
}
