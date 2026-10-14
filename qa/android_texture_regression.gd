extends SceneTree

const Store = preload("res://scripts/presentation/runtime_texture_store.gd")
const OUT = "res://docs/performance/android-first-build-20261014/"

func _initialize():call_deferred("run")

func run():
	var mobile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Store.ANDROID_INDEX))
	var desktop: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Store.INDEX))
	var failures: Array=[]
	var formats: Dictionary={}
	var unique: Dictionary={}
	if mobile.compression!="android_etc2_world":failures.append("wrong index compression")
	if mobile.textures.size()!=desktop.textures.size():failures.append("desktop/mobile coverage mismatch")
	Store.entries=mobile.textures
	Store.checked=true
	for key in mobile.textures:
		var entry: Dictionary=mobile.textures[key]
		var prior: Dictionary=desktop.textures.get(key,{})
		if prior.is_empty() or prior.get("size")!=entry.size or prior.get("source_sha256")!=entry.source_sha256:
			failures.append(key+": source or logical size mismatch")
		if not str(entry.resource).begins_with("res://art/runtime_textures_android/"):
			failures.append(key+": desktop resource in Android index")
		var start: int=key.find("[");var end: int=key.find("]",start)
		var asset: Dictionary={"texture":key.left(start),"region":JSON.parse_string(key.substr(start,end-start+1))}
		if key.contains("::limit"):asset.runtime_size_limit=int(key.get_slice("::limit",1))
		var texture=Store.texture(asset,bool(entry.base))
		if texture==null:failures.append(key+": load failed");continue
		if texture.get_size()!=Vector2(entry.size[0],entry.size[1]):failures.append(key+": logical size lost")
		if unique.has(entry.resource):continue
		unique[entry.resource]=true
		var pixels: Image=texture.get_image()
		var format: int=pixels.get_format()
		formats[format]=int(formats.get(format,0))+1
		if entry.vram_compressed and format not in [Image.FORMAT_ETC2_RGB8,Image.FORMAT_ETC2_RGBA8,Image.FORMAT_ETC2_RGB8A1]:
			failures.append(key+": expected ETC2 pixels, got "+str(format))
		if not entry.vram_compressed and pixels.is_compressed():failures.append(key+": lossless pixels changed")
	var result: Dictionary={"entries":mobile.textures.size(),"unique_resources":unique.size(),"formats":formats,"misses":Store.misses,"failures":failures}
	FileAccess.open(OUT+"texture-regression.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ANDROID_TEXTURE_CHECK "+JSON.stringify(result))
	quit(0 if failures.is_empty() and Store.misses==0 else 1)
