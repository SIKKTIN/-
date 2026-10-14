shader_type canvas_item;
render_mode unshaded;

uniform vec2 outline_step = vec2(0.01);
uniform vec4 outline_color : source_color = vec4(0.91,0.66,0.24,0.95);

void fragment() {
	float center = texture(TEXTURE, UV).a;
	float edge = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			edge = max(edge, texture(TEXTURE, UV + vec2(float(x),float(y))*outline_step).a);
		}
	}
	// Preserve the original painting; only the transparent silhouette edge is lit.
	COLOR = vec4(outline_color.rgb,outline_color.a*smoothstep(0.25,0.6,edge)*(1.0-smoothstep(0.15,0.55,center)));
}
