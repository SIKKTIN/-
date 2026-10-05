extends SceneTree
const OUT := "E:/Project/Godot/这次怎么逃/docs/art/a06-qa-native-v08.json"
func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://metadata.json"))
	var report := {"scope":"isolated headless Godot native PNG import/AtlasTexture and ground mapping; no main game/window started","passed":true,"assets":[]}
	for a in data.manifest.assets:
		var texture: Texture2D = load("res://textures/"+str(a.texture).get_file())
		if texture==null:
			report.passed=false
			continue
		var im: Image = texture.get_image()
		var r: Array = a.region
		var g: Array = a.ground_rect
		var world: Array = a.footprint_world_size
		var atlas := AtlasTexture.new()
		atlas.atlas=texture
		atlas.region=Rect2(r[0],r[1],r[2],r[3])
		var valid: bool = Rect2(Vector2.ZERO,texture.get_size()).encloses(atlas.region) and Rect2(0,0,r[2],r[3]).encloses(Rect2(g[0],g[1],g[2],g[3]))
		var size_ok: bool = texture.get_width()==a.texture_size[0] and texture.get_height()==a.texture_size[1]
		var corners_clear: bool = im.get_pixel(0,0).a==0 and im.get_pixel(im.get_width()-1,im.get_height()-1).a==0
		var alpha: int = im.detect_alpha()
		var ratio := Vector2(float(world[0])/g[2],float(world[1])/g[3])
		# R.pos = (100,200); map region onto R without treating transparent canvas as footprint.
		var logical := Rect2(100,200,world[0],world[1])
		var visual := Rect2(logical.position-Vector2(g[0],g[1])*ratio,Vector2(r[2],r[3])*ratio)
		var mapped := Rect2(visual.position+Vector2(g[0],g[1])*ratio,Vector2(g[2],g[3])*ratio)
		var registration_error: float = mapped.position.distance_to(logical.position)+mapped.size.distance_to(logical.size)
		var elevation_error: float = absf(float(a.elevation_world)-(logical.position.y-visual.position.y))
		var south_padding: float = visual.end.y-logical.end.y
		var source_ok: bool = FileAccess.get_sha256("res://textures/"+str(a.texture).get_file())==a.sha256
		var ok: bool = valid and size_ok and corners_clear and alpha!=Image.ALPHA_NONE and source_ok and registration_error<0.001 and elevation_error<0.001 and south_padding>=0 and south_padding<2
		report.assets.append({"id":a.id,"imported":true,"native_size":[texture.get_width(),texture.get_height()],"alpha":alpha,"corners_clear":corners_clear,"region_valid":valid,"png_hash_matches_original":source_ok,"mapped_ground_error_world":registration_error,"elevation_error_world":elevation_error,"south_padding_world":south_padding,"native_visual_size_world":[visual.size.x,visual.size.y],"passed":ok})
		report.passed=report.passed and ok
	var f := FileAccess.open(OUT,FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t")+"\n")
	f.close()
	print(JSON.stringify({"passed":report.passed,"native_imports":report.assets.size()}))
	quit(0 if report.passed else 1)
