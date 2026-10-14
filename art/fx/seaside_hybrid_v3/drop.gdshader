shader_type canvas_item;
render_mode unshaded;
void fragment(){float r=length(UV-.5);COLOR.a*=1.0-smoothstep(.2,.5,r);}
