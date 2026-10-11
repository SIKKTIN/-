shader_type canvas_item;
render_mode unshaded;
void fragment() {
    // UV slices inherit adjacent pixels from the same approved mother artwork.
    // Tile borders must not invent mortar, highlights, or color correction.
    COLOR = vec4(texture(TEXTURE,UV).rgb,1.0);
}
