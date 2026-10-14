#[compute]
#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(rgba32f,set=0,binding=0) readonly uniform image2DArray spatial_map;
layout(rgba32f,set=0,binding=1) writeonly uniform image2DArray ocean_map;
void main(){
    ivec3 q=ivec3(gl_GlobalInvocationID); if(q.x>=128||q.y>=128||q.z>=2)return;
    vec4 a=imageLoad(spatial_map,ivec3(q.xy,q.z*2));
    vec4 b=imageLoad(spatial_map,ivec3(q.xy,q.z*2+1));
    imageStore(ocean_map,q,vec4(a.x,a.z,b.x,b.z)); // h, chopX, chopY, dh/dt
}
