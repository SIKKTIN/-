shader_type canvas_item;
render_mode unshaded;
uniform vec2 tile_size = vec2(40.0,120.0);
uniform vec2 draw_origin = vec2(0.0);
uniform bool horizontal_ports = true;
uniform bool horizontal_left = true;
uniform bool horizontal_right = true;
uniform bool vertical_ports = false;
uniform bool north_port = false;
uniform bool north_stem = false;
uniform float stem_x = -1.0;
uniform float seam_width = 3.0;
uniform vec4 horizontal_profile = vec4(397.0,132.0,0.0,366.0);
uniform vec4 vertical_profile = vec4(712.0,600.0,114.0,0.0);
varying vec2 local_position;
void vertex() { local_position = VERTEX-draw_origin; }
void fragment() {
    vec2 p = clamp(local_position,vec2(0.0),tile_size);
    vec2 texsize = vec2(textureSize(TEXTURE,0));
    vec4 paint = texture(TEXTURE,UV);
    if(horizontal_ports) {
        float left = horizontal_left ? 1.0-smoothstep(1.0,seam_width,p.x) : 0.0;
        float right = horizontal_right ? 1.0-smoothstep(1.0,seam_width,tile_size.x-p.x) : 0.0;
        float weight = max(left,right);
        float profile_x = horizontal_profile.x;
        if(horizontal_profile.w>300.0) {
            float row = p.y/tile_size.y;
            // Keep stone joints in coping/plinth; plaster has no bright seam pillars.
            profile_x = row<0.23 ? 397.0 : (row>0.733 ? 394.0 : 500.0);
        }
        vec2 sample_point = vec2(profile_x,horizontal_profile.y+horizontal_profile.w*p.y/tile_size.y);
        vec3 edge_paint = texture(TEXTURE,sample_point/texsize).rgb;
        if(horizontal_profile.w>300.0 && (p.y/tile_size.y<0.23 || p.y/tile_size.y>0.733)) {
            vec3 ordinary_stone = texture(TEXTURE,vec2(500.0,sample_point.y)/texsize).rgb;
            edge_paint = mix(ordinary_stone,edge_paint,0.55);
        }
        paint.rgb = mix(paint.rgb,edge_paint,weight);
    }
    if(vertical_ports || north_port) {
        float distance_to_port = vertical_ports ? min(p.y,tile_size.y-p.y) : p.y;
        float weight = 1.0-smoothstep(1.0,seam_width,distance_to_port);
        vec2 sample_point = vec2(vertical_profile.x+vertical_profile.z*p.x/tile_size.x,vertical_profile.y);
        paint.rgb = mix(paint.rgb,texture(TEXTURE,sample_point/texsize).rgb,weight);
    }
    if(stem_x>=0.0 && p.x>=stem_x && p.x<=stem_x+20.0) {
        float port_distance = north_stem ? min(p.y,tile_size.y-p.y) : tile_size.y-p.y;
        float weight = 1.0-smoothstep(1.0,seam_width,port_distance);
        vec2 sample_point = vec2(vertical_profile.x+vertical_profile.z*(p.x-stem_x)/20.0,vertical_profile.y);
        paint.rgb = mix(paint.rgb,texture(TEXTURE,sample_point/texsize).rgb,weight);
    }
    // Every occupied rectangular grid block reaches its boundaries; no alpha padding.
    COLOR = vec4(paint.rgb,1.0);
}
