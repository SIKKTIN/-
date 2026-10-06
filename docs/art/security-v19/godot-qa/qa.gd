extends SceneTree

const ROOT = "E:/Project/Godot/这次怎么逃"
const DOC = ROOT + "/docs/art/security-v19"

func _initialize() -> void:
	var passed := true
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/props/security_v19/manifest.json"))
	var world_reports: Array = []
	for asset in world.assets:
		var imported := load(asset.texture) as Texture2D
		var raw := imported.get_image()
		var r: Array = asset.region
		var own := raw.get_region(Rect2i(r[0],r[1],r[2],r[3]))
		var g: Array = asset.ground_rect
		var footprint: Array = asset.footprint_world_size
		var sx: float = footprint[0]/g[2]
		var sy: float = footprint[1]/g[3]
		var valid: bool = not own.is_empty() and FileAccess.get_sha256(asset.texture) == asset.sha256 and absf(sx-sy) < 0.000001 and Rect2(Vector2.ZERO,Vector2(r[2],r[3])).encloses(Rect2(g[0],g[1],g[2],g[3]))
		valid = valid and absf(asset.anchor[1]-(g[1]+g[3]))<0.000001
		if asset.id == "access_reader":
			valid = valid and not asset.blocking and asset.render_mode == "wall_attachment" and asset.mount_anchor == asset.anchor
		passed = passed and valid
		world_reports.append({"id":asset.id,"region_size":[own.get_width(),own.get_height()],"scale_x":sx,"scale_y":sy,"passed":valid})
	var editor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/editor/v02/manifest.json"))
	var icon_reports: Array = []
	DirAccess.make_dir_recursive_absolute(DOC + "/native-icons-v19")
	for entry in editor.assets:
		var atlas := load(entry.editor_icon) as AtlasTexture
		var valid: bool = atlas != null and atlas.filter_clip and absf(atlas.get_width()-atlas.get_height())<=1
		var samples: Array = []
		if atlas:
			var source := atlas.atlas.get_image()
			var region_image := source.get_region(Rect2i(atlas.region))
			# Native Atlas draw geometry: transparent square canvas and the native margin offset.
			var square := Image.create(atlas.get_width(),atlas.get_height(),false,Image.FORMAT_RGBA8)
			square.fill(Color(0,0,0,0))
			square.blit_rect(region_image,Rect2i(Vector2i.ZERO,region_image.get_size()),Vector2i(atlas.margin.position))
			for size in [48,64]:
				var thumbnail := square.duplicate() as Image
				thumbnail.resize(size,size,Image.INTERPOLATE_LANCZOS)
				var bounds := thumbnail.get_used_rect()
				var sample_valid := thumbnail.get_size()==Vector2i(size,size) and bounds.size.x>0 and bounds.size.y>0
				valid = valid and sample_valid
				var png: String = DOC + "/native-icons-v19/" + entry.id + "_" + str(size) + ".png"
				var saved := OK
				if FileAccess.file_exists(png):
					var existing := Image.load_from_file(png)
					if existing.get_data() != thumbnail.get_data():
						push_error("Refuse overwrite differing QA PNG: " + png)
						quit(1)
						return
				else:
					saved = thumbnail.save_png(png)
				valid = valid and saved == OK
				samples.append({"size":size,"native_canvas":[atlas.get_width(),atlas.get_height()],"drawn_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"passed":sample_valid and saved==OK})
		passed = passed and valid
		icon_reports.append({"id":entry.id,"resource":entry.editor_icon,"native_class":"AtlasTexture","samples":samples,"passed":valid})
	passed = passed and world_reports.size()==4 and icon_reports.size()==13
	var output := {"passed":passed,"world_assets":world_reports,"editor_icons":icon_reports,"scope":"isolated Godot4.7.2 native AtlasTexture loading, source/region/margin geometry, Image raster thumbnails at48/64 and world ground/scale; source PNG unchanged; actual production editor integration pending"}
	var file := FileAccess.open(DOC+"/qa-godot-v19.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"  ")+"\n")
	print("A19 native QA passed=",passed," world=",world_reports.size()," icons=",icon_reports.size())
	quit(0 if passed else 1)
