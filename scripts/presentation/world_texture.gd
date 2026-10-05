extends RefCounted

# World props are often reduced from >1,000 source pixels to <150 on screen.
# Crop atlas regions before building mipmaps so lower levels cannot bleed in
# adjacent artwork. Keep the original PNG and its import settings untouched.
static var cache: Dictionary = {}

static func load_asset(asset: Dictionary) -> Texture2D:
	var key := str(asset.texture)+JSON.stringify(asset.get("region",[]))
	if cache.has(key):
		return cache[key]
	var original: Texture2D = load(asset.texture)
	if original == null:
		return null
	var fallback: Texture2D = original
	if asset.has("region"):
		var region: Array = asset.region
		var atlas := AtlasTexture.new()
		atlas.atlas = original
		atlas.region = Rect2(region[0],region[1],region[2],region[3])
		atlas.filter_clip = true
		fallback = atlas
	var image := original.get_image()
	if image == null or image.is_empty():
		return fallback
	if image.is_compressed() and image.decompress() != OK:
		return fallback
	if asset.has("region"):
		var region: Array = asset.region
		image = image.get_region(Rect2i(region[0],region[1],region[2],region[3]))
	if image.generate_mipmaps() != OK:
		return fallback
	var texture := ImageTexture.create_from_image(image)
	cache[key] = texture
	return texture
