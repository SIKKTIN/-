extends SceneTree
const OUT := "E:/Project/Godot/这次怎么逃/docs/art/"
class Board extends Node2D:
	var merchant: Texture2D
	var merchant_def: Dictionary
	var textures: Dictionary
	var labels: Array
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0,0,1280,720),Color("f2ebdd"))
		draw_string(font,Vector2(24,34),"A05 | Native asset preview (not a game scene)",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("303b46"))
		draw_rect(Rect2(24,58,1232,143),Color("a6b2a3"))
		var rr: Array = merchant_def.region
		var a: Array = merchant_def.anchor
		var s: float = float(merchant_def.world_height)/rr[3]
		var base := Vector2(96,165)
		draw_line(Vector2(47,165),Vector2(144,165),Color("64786d"),1)
		draw_texture_rect(merchant,Rect2(base-Vector2(a[0],a[1])*s,Vector2(rr[2],rr[3])*s),false)
		draw_string(font,Vector2(45,188),"Merchant 64",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("303b46"))
		for i in range(3):
			draw_texture_rect(textures[labels[i]],Rect2(235+i*58,111,26,26),false)
		draw_string(font,Vector2(220,177),"Ground items: 26 world units",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("303b46"))
		for i in range(labels.size()):
			var x: float = 24+(i%5)*246
			var y: float = 220+(i/5)*140
			draw_rect(Rect2(x,y,233,122),Color("faf6ed"))
			for j in range(3):
				var size: int = [24,28,48][j]
				draw_texture_rect(textures[labels[i]],Rect2(x+14+j*61,y+20,size,size),false)
			draw_string(font,Vector2(x+10,y+104),str(labels[i])+" | 24/28/48",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("303b46"))
		draw_string(font,Vector2(24,552),"Slots 47x48: capacity 1 / capacity 3 (layout samples only)",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("303b46"))
		for i in range(4):
			var x: float = 24 if i==0 else 155+(i-1)*51
			draw_rect(Rect2(x,567,47,48),Color("faf6ed"))
			draw_rect(Rect2(x,567,47,48),Color("9aab9f"),false,2)
			draw_texture_rect(textures[["door_key","scrap","lock_tool","empty"][i]],Rect2(x+9,577,28,28),false)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://metadata.json"))
	var report := {"scope":"isolated Godot native import/decode/atlas and preview; not gameplay integration","rows":[],"passed":true}
	var pngs: Dictionary = {}
	for f in d.files:
		var t: Texture2D = load(f.test_texture)
		if t==null:
			report.passed=false
			continue
		var im: Image = t.get_image()
		var size_ok: bool = im.get_width()==(1254 if str(f.project_path).contains("merchant") else 128) and im.get_height()==(1254 if str(f.project_path).contains("merchant") else 128)
		var corners_clear: bool = im.get_pixel(0,0).a==0 and im.get_pixel(im.get_width()-1,im.get_height()-1).a==0
		var ok: bool = size_ok and corners_clear and im.detect_alpha()!=Image.ALPHA_NONE
		report.rows.append({"source":f.project_path,"imported_texture":f.test_texture,"native_resource_loaded":true,"width":im.get_width(),"height":im.get_height(),"alpha":im.detect_alpha(),"corners_clear":corners_clear,"passed":ok})
		report.passed=report.passed and ok
		if str(f.project_path).ends_with(".png"):
			pngs[f.project_path]=t
	var m: Dictionary = d.manifest.merchant
	var texture: Texture2D = pngs[str(m.texture).replace("res://","")]
	var r: Array = m.region
	var atlas := AtlasTexture.new()
	atlas.atlas=texture
	atlas.region=Rect2(r[0],r[1],r[2],r[3])
	var region_valid: bool = Rect2(Vector2.ZERO,texture.get_size()).encloses(atlas.region)
	var foot_world_error: float = absf(float(m.opaque_bounds[1]+m.opaque_bounds[3]-m.anchor[1]))*64/r[3]
	report.merchant={"region_valid":region_valid,"atlas_size":[atlas.get_width(),atlas.get_height()],"anchor":m.anchor,"opaque_bottom_foot_error_world":foot_world_error,"world_height":64}
	report.passed=report.passed and region_valid and foot_world_error<0.001
	var board := Board.new()
	board.merchant=atlas
	board.merchant_def=m
	board.textures={}
	board.labels=[]
	for a in d.icons:
		board.labels.append(a.id)
		board.textures[a.id]=pngs[a.texture]
	root.add_child(board)
	var args := OS.get_cmdline_user_args()
	if not args.has("--headless-check"):
		report.previews=[]
		for wh in [Vector2i(1280,720),Vector2i(960,540)]:
			root.size=wh
			board.scale=Vector2.ONE*(float(wh.x)/1280.0)
			board.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var name := "a05-native-preview-%dx%d-v07.png"%[wh.x,wh.y]
			var err: Error = root.get_texture().get_image().save_png(OUT+name)
			report.previews.append({"path":name,"size":[wh.x,wh.y],"saved":err==OK})
			report.passed=report.passed and err==OK
	var f := FileAccess.open(OUT+"a05-qa-native-v07.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	f.close()
	print(JSON.stringify({"native_imports":report.rows.size(),"passed":report.passed,"merchant":report.merchant}))
	quit(0 if report.passed else 1)
