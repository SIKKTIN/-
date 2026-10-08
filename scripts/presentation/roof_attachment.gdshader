shader_type canvas_item;
render_mode unshaded;
varying vec4 roof_tint;
void vertex() { roof_tint = COLOR; }
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	// Discard the generated cutout's diffuse halo, retain its actual outline.
	float alpha = smoothstep(0.65, 0.9, texel.a);
	COLOR = vec4(texel.rgb, alpha) * roof_tint;
}
