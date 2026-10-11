shader_type canvas_item;

// Preserve source RGB and antialiased silhouette while making the painted
// building core opaque. Some generated dense pixels have alpha 251..253.
// This prevents CLOSED door details or floor textures bleeding through.
varying vec4 architecture_tint;

void vertex() {
	architecture_tint = COLOR;
}

void fragment() {
	vec4 texel_color = texture(TEXTURE, UV);
	float silhouette_alpha = smoothstep(0.02, 0.25, texel_color.a);
	COLOR = vec4(texel_color.rgb, silhouette_alpha) * architecture_tint;
}
