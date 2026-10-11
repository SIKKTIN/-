shader_type canvas_item;

// Low-alpha specks must never be promoted into opaque geometry.
// Dense painted interiors still become opaque, so an OPEN patch masks CLOSED.
varying vec4 architecture_tint;

void vertex() {
	architecture_tint = COLOR;
}

void fragment() {
	vec4 texel_color = texture(TEXTURE, UV);
	float source_alpha = texel_color.a;
	float edge_alpha = source_alpha * smoothstep(0.03, 0.12, source_alpha);
	float core_weight = smoothstep(0.90, 0.97, source_alpha);
	float output_alpha = mix(edge_alpha, 1.0, core_weight);
	COLOR = vec4(texel_color.rgb, output_alpha) * architecture_tint;
}
