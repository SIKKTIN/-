extends SceneTree
const Store = preload("res://scripts/presentation/runtime_texture_store.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var entries := {}
	var total := 0
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/departure_gate_v1/manifest.json"))
	for asset in manifest.assets:
		var path:String=asset.texture
		var source:=Image.load_from_file(path)
		var r:Array=asset.region
		var rect:=Rect2i(r[0],r[1],r[2],r[3])
		var image:=source.get_region(rect)
		var limit:int=Store.size_limit(asset,image.get_size())
		if maxi(image.get_width(),image.get_height())>limit:
			var ratio:float=float(limit)/maxi(image.get_width(),image.get_height())
			image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		var source_hash:=FileAccess.get_sha256(path)
		var identity:String=path+source_hash+str(rect)+str(image.get_size())+str(false)
		var resource:String="res://art/runtime_textures/"+identity.md5_text()+".res"
		var result:=ResourceSaver.save(ImageTexture.create_from_image(image),resource,ResourceSaver.FLAG_COMPRESS)
		if result!=OK:quit(1);return
		entries[Store.key(asset)]={"resource":resource,"source_modified":FileAccess.get_modified_time(path),"source_sha256":source_hash,"size":[image.get_width(),image.get_height()],"bytes":image.get_data_size(),"source_region":r,"base":false}
		total+=image.get_data_size()
	var path:=Store.INDEX
	var sha:=FileAccess.get_sha256(path)
	var index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	index.textures.merge(entries,true)
	var temp:=path+".departure.tmp"
	FileAccess.open(temp,FileAccess.WRITE).store_string(JSON.stringify(index,"\t"))
	if FileAccess.get_sha256(path)!=sha:DirAccess.remove_absolute(temp);quit(2);return
	var result:=DirAccess.rename_absolute(temp,path)
	FileAccess.open("res://docs/art/departure-gate-v1/runtime-textures.json",FileAccess.WRITE).store_string(JSON.stringify({"entries":entries,"bytes":total},"\t"))
	print("DEPARTURE_BAKE: ",JSON.stringify({"textures":entries.size(),"bytes":total,"result":result}))
	quit(0 if result==OK else 1)
