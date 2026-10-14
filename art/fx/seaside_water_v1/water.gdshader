shader_type canvas_item;
render_mode unshaded;

// Prototype mask derived from the concept's sea hues. Production coastline
// tiles can supply an authored mask instead, leaving gameplay surfaces fixed.
uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform float strength : hint_range(0.0, 1.5) = 1.0;
uniform float speed : hint_range(0.0, 2.0) = 0.8;
uniform float manual_time = -1.0;

float water_mask(vec3 c) {
	return smoothstep(0.035,0.11,c.b-c.r)*smoothstep(0.02,0.09,c.g-c.r);
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float mask = water_mask(original.rgb);
	float t = (manual_time >= 0.0 ? manual_time : TIME) * speed;
	vec2 p = UV*vec2(8.0,6.2);
	float a = texture(flow_noise,p+vec2(t*0.018,-t*0.026)).r;
	float b = texture(flow_noise,p*1.73+vec2(-t*0.023,t*0.015)).r;
	vec2 shift = vec2(a-0.5,b-0.5)*0.008*strength;
	vec4 drift = texture(TEXTURE,clamp(UV+shift,vec2(0.001),vec2(0.999)));
	// Sampling a pier/rock must never drag its pixels across the water edge.
	vec3 base = mix(original.rgb,drift.rgb,water_mask(drift.rgb)*0.78);
	float wave = sin(UV.y*234.0+UV.x*57.0+t*2.0+a*12.0+b*9.0);
	float sparkle = pow(max(wave,0.0),18.0)*smoothstep(0.52,0.8,a);
	float sheen = (a-b)*0.20+wave*0.035;
	vec3 water = base*(1.0+sheen*strength);
	water += vec3(0.64,0.77,0.74)*sparkle*0.30*strength;
	// Wash advances and retreats within the sea, without moving the shore.
	float coastline = 0.777+sin(UV.x*23.0)*0.021+sin(UV.x*47.0)*0.011;
	float edge = exp(-abs(UV.y-coastline-sin(t*1.25)*0.009)*145.0);
	float wash = edge*smoothstep(0.42,0.73,b)*(.45+.35*sin(t*1.25));
	float d1 = distance(UV*vec2(1.0,0.8),vec2(0.38,0.253));
	float d2 = distance(UV*vec2(1.0,0.8),vec2(0.635,0.253));
	float radius = 0.025+sin(t*1.8)*0.006;
	float pile_wash = (exp(-abs(d1-radius)*240.0)+exp(-abs(d2-radius)*240.0))*smoothstep(0.43,0.7,a);
	water = mix(water,vec3(0.73,0.84,0.80),clamp((wash+pile_wash*0.18)*strength,0.0,0.5));
	COLOR = vec4(mix(original.rgb,water,mask*clamp(strength,0.0,1.0)),original.a);
}
