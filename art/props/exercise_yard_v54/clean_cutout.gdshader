shader_type canvas_item;
varying vec4 painted_tint;
void vertex() { painted_tint = COLOR; }
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	// Generated sprites retain their original alpha; discard low-alpha halos
	// instead of baking a second ground shadow into the sprite.
	COLOR = vec4(texel.rgb,smoothstep(0.55,0.88,texel.a))*painted_tint;
}
