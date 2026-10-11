shader_type canvas_item;
render_mode unshaded;
uniform sampler2D port_reference_texture : filter_linear_mipmap;
uniform vec2 tile_size=vec2(40.0,120.0);
uniform vec2 draw_origin=vec2(0.0);
uniform bool horizontal_ports=true;
uniform bool horizontal_left=true;
uniform bool horizontal_right=true;
uniform bool vertical_ports=false;
uniform bool north_port=false;
uniform bool south_port=false;
uniform bool north_stem=false;
uniform bool south_stem=true;
uniform float stem_x=-1.0;
uniform float horizontal_offset=0.0;
uniform float horizontal_extent=120.0;
uniform vec4 horizontal_profile=vec4(1030.0,130.0,0.0,370.0);
uniform vec4 vertical_profile=vec4(710.0,600.0,120.0,0.0);
varying vec2 local_position;
void vertex(){local_position=VERTEX-draw_origin;}
float port_weight(float d){return 1.0-smoothstep(0.7,2.5,d);}
void fragment(){
    vec2 p=clamp(local_position,vec2(0.0),tile_size);
    vec2 refsize=vec2(textureSize(port_reference_texture,0));
    vec4 base=texture(TEXTURE,UV);
    vec3 paint=base.rgb;
    float opacity=smoothstep(0.12,0.75,base.a);
    // The extra top cell in a lower corner is its upward arc, not a facade
    // connection. Horizontal ports begin on the next row, beside a 120h wall.
    if(horizontal_ports&&p.y>=horizontal_offset){
        float w=max(horizontal_left?port_weight(p.x):0.0,horizontal_right?port_weight(tile_size.x-p.x):0.0);
        vec2 edge=vec2(horizontal_profile.x,horizontal_profile.y+horizontal_profile.w*(p.y-horizontal_offset)/horizontal_extent);
        paint=mix(paint,texture(port_reference_texture,edge/refsize).rgb,w);
        opacity=mix(opacity,1.0,w);
    }
    if(vertical_ports||north_port||south_port){
        float w=max((vertical_ports||north_port)?port_weight(p.y):0.0,(vertical_ports||south_port)?port_weight(tile_size.y-p.y):0.0);
        vec2 edge=vec2(vertical_profile.x+vertical_profile.z*p.x/tile_size.x,vertical_profile.y);
        paint=mix(paint,texture(port_reference_texture,edge/refsize).rgb,w);
        opacity=mix(opacity,1.0,w);
    }
    if(stem_x>=0.0&&p.x>=stem_x&&p.x<=stem_x+20.0){
        float w=max(north_stem?port_weight(p.y):0.0,south_stem?port_weight(tile_size.y-p.y):0.0);
        vec2 edge=vec2(vertical_profile.x+vertical_profile.z*(p.x-stem_x)/20.0,vertical_profile.y);
        paint=mix(paint,texture(port_reference_texture,edge/refsize).rgb,w);
        opacity=mix(opacity,1.0,w);
    }
    COLOR=vec4(paint,opacity);
}
