extends RefCounted

# World props are often reduced from >1,000 source pixels to <150 on screen.
# Crop atlas regions before building mipmaps so lower levels cannot bleed in
# adjacent artwork. Keep the original PNG and its import settings untouched.
static var cache: Dictionary = {}

static func load_regions(path: String, regions: Array, no_mipmaps: Array = []) -> Array[Texture2D]:
	var result: Array[Texture2D]=[]
	var keys: Array[String]=[]
	var missing:=false
	for i in range(regions.size()):
		var key:=path+JSON.stringify(regions[i])+("::base" if i in no_mipmaps else "")
		keys.append(key)
		if not cache.has(key):missing=true
	if missing:
		var original: Texture2D
		if FileAccess.file_exists(path+".import"):
			original=load(path)
		elif FileAccess.file_exists(path):
			var raw:=Image.load_from_file(path)
			if raw!=null and not raw.is_empty():original=ImageTexture.create_from_image(raw)
		if original!=null:
			var source_image: Image=original.get_image()
			if source_image!=null and source_image.is_compressed() and source_image.decompress()!=OK:source_image=null
			for i in range(regions.size()):
				if cache.has(keys[i]):continue
				var region: Array=regions[i]
				if source_image!=null and not source_image.is_empty():
					var cropped:=source_image.get_region(Rect2i(region[0],region[1],region[2],region[3]))
					if i in no_mipmaps or cropped.generate_mipmaps()==OK:
						cache[keys[i]]=ImageTexture.create_from_image(cropped)
						continue
				var atlas:=AtlasTexture.new()
				atlas.atlas=original
				atlas.region=Rect2(region[0],region[1],region[2],region[3])
				atlas.filter_clip=true
				cache[keys[i]]=atlas
	for key in keys:result.append(cache.get(key))
	return result

static func load_asset(asset: Dictionary) -> Texture2D:
	var key := str(asset.texture)+JSON.stringify(asset.get("region",[]))
	if int(asset.get("runtime_size_limit",0)) > 0:
		key += "::limit"+str(asset.runtime_size_limit)
	if cache.has(key):
		return cache[key]
	var image: Image
	# Bounded standalone sources need no full-size GPU upload. Exported builds
	# without source PNGs still use the imported resource fallback below.
	if int(asset.get("runtime_size_limit",0)) > 0 and FileAccess.file_exists(asset.texture):
		image = Image.load_from_file(asset.texture)
	var original: Texture2D
	if image == null and FileAccess.file_exists(str(asset.texture)+".import"):
		original = load(asset.texture)
	elif image == null and FileAccess.file_exists(asset.texture):
		# Newly delivered sprites can be previewed before the editor imports them.
		var raw := Image.load_from_file(asset.texture)
		if raw != null and not raw.is_empty():
			original = ImageTexture.create_from_image(raw)
	if original == null and image == null:
		return null
	var fallback: Texture2D = original
	if original != null and asset.has("region"):
		var region: Array = asset.region
		var atlas := AtlasTexture.new()
		atlas.atlas = original
		atlas.region = Rect2(region[0],region[1],region[2],region[3])
		atlas.filter_clip = true
		fallback = atlas
	if image == null: image = original.get_image()
	if image == null or image.is_empty():
		return fallback
	if image.is_compressed() and image.decompress() != OK:
		return fallback
	if asset.has("region"):
		var region: Array = asset.region
		image = image.get_region(Rect2i(region[0],region[1],region[2],region[3]))
	var limit := int(asset.get("runtime_size_limit",0))
	if limit > 0 and maxi(image.get_width(),image.get_height()) > limit:
		var ratio := float(limit)/maxi(image.get_width(),image.get_height())
		image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
	if image.generate_mipmaps() != OK:
		return fallback
	var texture := ImageTexture.create_from_image(image)
	cache[key] = texture
	return texture
