extends SceneTree

const DIR := "res://art/ui/nine_point_v1/"
var report := {}

func _initialize(): call_deferred("run")

func save_texture(image: Image, path: String, limit: int) -> bool:
	if image.is_empty(): return false
	var ratio := minf(1.0,float(limit)/maxi(image.get_width(),image.get_height()))
	image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var error := ResourceSaver.save(ImageTexture.create_from_image(image),DIR+path+".res",ResourceSaver.FLAG_COMPRESS)
	report[path] = {"size":[image.get_width(),image.get_height()],"bytes":image.get_data_size(),"resource":DIR+path+".res"}
	return error == OK

func run():
	var background := Image.load_from_file(DIR+"background-source.png")
	var sheet := Image.load_from_file(DIR+"cast-source.png")
	if background == null or sheet == null: quit(1); return
	if not save_texture(background,"background",1600): quit(1); return
	var ids := ["lin","zhou","xu","lu"]
	var views := ["front","back","side"]
	var regions := {}
	for row in 4:
		for col in 3:
			var start := Vector2i(sheet.get_width()*col/3,sheet.get_height()*row/4)
			var end := Vector2i(sheet.get_width()*(col+1)/3,sheet.get_height()*(row+1)/4)
			var cell := sheet.get_region(Rect2i(start,end-start))
			var used := cell.get_used_rect()
			if cell.detect_alpha() == Image.ALPHA_NONE or used.size.x < 40 or used.size.y < 40:
				push_error("Missing transparent seated sprite cell"); quit(1); return
			var id: String = ids[row]+"_"+views[col]
			regions[id] = [start.x+used.position.x,start.y+used.position.y,used.size.x,used.size.y]
			if not save_texture(cell.get_region(used),id,256): quit(1); return
	var manifest := {"schema":1,"source_kind":"built-in-imagegen-original-png","background_sha256":FileAccess.get_sha256(DIR+"background-source.png"),"cast_sha256":FileAccess.get_sha256(DIR+"cast-source.png"),"regions":regions,"textures":report}
	FileAccess.open(DIR+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	FileAccess.open("res://docs/art/nine-point-v1/bake.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	print("Nine point background + 12 bounded seated textures baked.")
	quit(0)
