extends SceneTree
const Store=preload("res://scripts/presentation/runtime_texture_store.gd")
const DEST="res://art/runtime_textures/"
var requests: Dictionary={}
var sources: Dictionary={}
func add(asset: Dictionary, base:=false):
	if not asset.has("texture"):return
	var key: String=Store.key(asset,base)
	if not requests.has(key):requests[key]={"asset":asset.duplicate(true),"base":base}
	else:
		var previous: Dictionary=requests[key].asset
		var old_size: Array=previous.get("render_size",previous.get("world_size",[]))
		var new_size: Array=asset.get("render_size",asset.get("world_size",[]))
		previous.merge(asset,true)
		if old_size.size()==2 and (new_size.size()!=2 or maxf(old_size[0],old_size[1])>maxf(new_size[0],new_size[1])):previous.render_size=old_size
func collect(value: Variant):
	if value is Dictionary:
		if value.has("texture") and str(value.texture).ends_with(".png"):add(value)
		for child in value.values():collect(child)
	elif value is Array:
		for child in value:collect(child)
func _initialize(): call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute(DEST)
	# Cover the measured runtime dependencies and each registered prop, so
	# editor placements also use ready-to-load pixels.
	var audit: Dictionary={}
	var audit_path: String="res://docs/dev/performance-audit-2026-10-14/forward_plus.json"
	if FileAccess.file_exists(audit_path):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(audit_path))
		if parsed is Dictionary:audit=parsed
	for entry in audit.get("textures",[]):
		var key: String=entry.key
		var bracket: int=key.find("[");var end: int=key.find("]",bracket)
		var asset: Dictionary={"texture":key.left(bracket),"region":JSON.parse_string(key.substr(bracket,end-bracket+1))}
		if asset.region.is_empty():asset.erase("region")
		if key.contains("::limit"):asset.runtime_size_limit=int(key.get_slice("::limit",1))
		add(asset,key.ends_with("::base"))
	for asset in preload("res://scripts/presentation/prop_catalog.gd").assets().values():add(asset)
	for asset in preload("res://scripts/presentation/character_library.gd").all().values():
		add({"texture":asset.texture,"region":asset.frames.idle},true)
		for f in asset.walk_animation.frames:add({"texture":asset.walk_animation.texture,"region":f.region})
		for f in asset.get("service_frames",{}).values():add({"texture":asset.texture,"region":f.region},true)
	# Extra terrain/floor manifests (including editor choices) are dynamic.
	var files: Array=[]
	walk_manifests("res://art",files)
	for file in files:
		var data=JSON.parse_string(FileAccess.get_file_as_string(file))
		if data is Dictionary:collect(data)
	for key in requests:
		var path: String=requests[key].asset.texture
		if not sources.has(path):sources[path]=[]
		sources[path].append(key)
	var index: Dictionary={"schema":1,"textures":{}}
	var unique_resources: Dictionary={}
	var failures: Array=[];var count:=0;var before_bytes:=0;var after_bytes:=0
	for path in sources:
		var source:=Image.load_from_file(path)
		if source==null or source.is_empty():failures.append(path);continue
		var modified: int=FileAccess.get_modified_time(path)
		var source_hash: String=FileAccess.get_sha256(path)
		for key in sources[path]:
			var request: Dictionary=requests[key];var asset: Dictionary=request.asset
			var region: Array=asset.get("region",[0,0,source.get_width(),source.get_height()])
			var rect:=Rect2i(int(region[0]),int(region[1]),int(region[2]),int(region[3]))
			if not Rect2i(Vector2i.ZERO,source.get_size()).encloses(rect):failures.append(key);continue
			var image:=source.get_region(rect)
			before_bytes+=image.get_data_size()
			var limit: int=Store.size_limit(asset,image.get_size())
			if maxi(image.get_width(),image.get_height())>limit:
				var ratio: float=float(limit)/maxi(image.get_width(),image.get_height())
				image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
			if not request.base:image.generate_mipmaps()
			after_bytes+=image.get_data_size()
			# [] and a full-image region, aliases and different upper limits can
			# resolve to identical pixels. Share their baked GPU resource too.
			var identity: String=path+source_hash+str(rect)+str(image.get_size())+str(request.base)
			var resource: String=DEST+identity.md5_text()+".res"
			if not unique_resources.has(resource):
				var texture:=ImageTexture.create_from_image(image)
				var error: int=ResourceSaver.save(texture,resource,ResourceSaver.FLAG_COMPRESS)
				if error!=OK:failures.append(key);continue
				unique_resources[resource]=image.get_data_size()
			index.textures[key]={"resource":resource,"source_modified":modified,"source_sha256":source_hash,"size":[image.get_width(),image.get_height()],"bytes":image.get_data_size(),"source_region":region,"base":request.base}
			count+=1
		if count%40< sources[path].size():print("BAKE_PROGRESS "+str(count)+" / "+str(requests.size()))
	FileAccess.open(DEST+"index.json",FileAccess.WRITE).store_string(JSON.stringify(index,"\t"))
	# Only remove our hash-named generated resources, never source artwork.
	if failures.is_empty():
		for file in DirAccess.get_files_at(DEST):
			var stem: String=file.get_basename()
			if file.ends_with(".res") and stem.length()==32 and stem.is_valid_hex_number(false) and not unique_resources.has(DEST+file):DirAccess.remove_absolute(DEST+file)
	var report: Dictionary={"requests":requests.size(),"baked":count,"source_files_decoded":sources.size(),"failures":failures,"source_pixels_mib":before_bytes/1048576.0,"baked_pixels_with_mips_mib":after_bytes/1048576.0}
	report.unique_resources=unique_resources.size()
	report.unique_pixels_mib=unique_resources.values().reduce(func(a,b):return a+b,0.0)/1048576.0
	var report_dir: String="res://docs/dev/performance-optimization-2026-10-14/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	FileAccess.open(report_dir+"bake.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("BAKE_DONE "+JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func walk_manifests(path: String, output: Array):
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".json") and file.contains("manifest"):output.append(path.path_join(file))
	for dir in DirAccess.get_directories_at(path):
		if dir!="runtime_textures":walk_manifests(path.path_join(dir),output)
