extends SceneTree

const DIR := "res://art/ui/nine_point_v2/"

func _initialize(): call_deferred("run")

func visible_bounds(image: Image) -> Rect2i:
	# Ignore almost transparent atlas padding when finding the sprite's anchor frame.
	var low := Vector2i(image.get_width(), image.get_height())
	var high := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 0.1: continue
			low = Vector2i(mini(low.x, x), mini(low.y, y))
			high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	return Rect2i(low, high-low+Vector2i.ONE)

func run():
	var sheet := Image.load_from_file(DIR+"cast-source.png")
	if sheet == null: quit(1); return
	var report := {"schema":2,"source_sha256":FileAccess.get_sha256(DIR+"cast-source.png"),"textures":{}}
	var ids := ["lin","zhou","xu","lu"]
	var views := ["front","back","side"]
	for row in 4:
		for col in 3:
			var start := Vector2i(sheet.get_width()*col/3,sheet.get_height()*row/4)
			var end := Vector2i(sheet.get_width()*(col+1)/3,sheet.get_height()*(row+1)/4)
			var cell := sheet.get_region(Rect2i(start,end-start))
			var bounds := visible_bounds(cell)
			if bounds.size.x < 40 or bounds.size.y < 40: quit(1); return
			var sprite := cell.get_region(bounds)
			var ratio := 256.0/maxi(sprite.get_width(),sprite.get_height())
			sprite.resize(roundi(sprite.get_width()*ratio),roundi(sprite.get_height()*ratio),Image.INTERPOLATE_LANCZOS)
			sprite.generate_mipmaps()
			var id: String = ids[row]+"_"+views[col]
			if ResourceSaver.save(ImageTexture.create_from_image(sprite),DIR+id+".res",ResourceSaver.FLAG_COMPRESS) != OK: quit(1); return
			report.textures[id] = {"region":[start.x+bounds.position.x,start.y+bounds.position.y,bounds.size.x,bounds.size.y],"size":[sprite.get_width(),sprite.get_height()],"bytes":sprite.get_data_size()}
	FileAccess.open(DIR+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("Seated v2: 12 tightly bounded sprites baked.")
	quit(0)
