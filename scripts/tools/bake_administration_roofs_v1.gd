extends SceneTree

const Store = preload("res://scripts/presentation/runtime_texture_store.gd")
const MANIFEST := "res://art/architecture/administration_roofs_v1/manifest.json"
const INDEX := "res://art/runtime_textures/index.json"

func _initialize():
	call_deferred("run")

func run():
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var index_text := FileAccess.get_file_as_string(INDEX)
	var index: Dictionary = JSON.parse_string(index_text)
	var additions := {}
	for asset: Dictionary in manifest.assets:
		var image := Image.load_from_file(str(asset.texture))
		var limit: int = int(asset.runtime_size_limit)
		if maxi(image.get_width(),image.get_height()) > limit:
			var ratio := float(limit)/maxi(image.get_width(),image.get_height())
			image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		var source_hash := FileAccess.get_sha256(str(asset.texture))
		var resource := "res://art/runtime_textures/"+(str(asset.texture)+source_hash+str(image.get_size())).md5_text()+".res"
		var error := ResourceSaver.save(ImageTexture.create_from_image(image), resource, ResourceSaver.FLAG_COMPRESS)
		if error != OK: quit(error); return
		additions[Store.key(asset)] = {
			"resource":resource, "source_modified":FileAccess.get_modified_time(str(asset.texture)),
			"source_sha256":source_hash,"size":[image.get_width(),image.get_height()],
			"bytes":image.get_data_size(),"source_region":[0,0,asset.texture_size[0],asset.texture_size[1]],"base":false,
		}
	if FileAccess.get_file_as_string(INDEX) != index_text:
		push_error("Runtime index changed during baking; retry against current index.")
		quit(1); return
	index.textures.merge(additions,true)
	FileAccess.open(INDEX,FileAccess.WRITE).store_string(JSON.stringify(index,"\t"))
	FileAccess.open("res://docs/art/administration-roofs-v1/bake.json",FileAccess.WRITE).store_string(JSON.stringify(additions,"\t"))
	print("Administrative roofs baked: ", additions.size(), " fitted textures; other resources preserved.")
	quit(0)
