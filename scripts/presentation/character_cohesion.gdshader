shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.0) = 0.88;
uniform vec4 scene_tint : source_color = vec4(0.98, 0.97, 0.94, 1.0);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * vertex_tint;
	float value = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(vec3(value), pixel.rgb, saturation) * scene_tint.rgb, pixel.a);
}
