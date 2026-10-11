extends SceneTree
const Assembly=preload("res://assembly.gd")
class Sheet extends Node2D:
	var assets: Dictionary
	var old_assets: Dictionary
	var texture: Texture2D
	var icons: Dictionary
	var detail_mode:=false
	func region(id: String, area: Rect2, clip:=Rect2()) -> void:
		var s: Array=old_assets[id].region
		var src:=Rect2(s[0],s[1],s[2],s[3])
		var visible_area:=area.intersection(clip) if clip.has_area() else area
		var ratio:=src.size/area.size
		draw_texture_rect_region(texture,visible_area,Rect2(src.position+(visible_area.position-area.position)*ratio,visible_area.size*ratio))
	func _draw() -> void:
		var font:=ThemeDB.fallback_font
		if detail_mode:
			frame(Vector2(24,40),24)
			return
		draw_string(font,Vector2(24,24),"ORIGINAL V24 ART -- complete wings / columns / lintel preserved; local turns and returns only",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("26352f"))
		frame(Vector2(24,65),24)
		frame(Vector2(654,65),20)
		var i:=0
		for id in assets:
			var p:=Vector2(24+(i%5)*250,500+(i/5)*195)
			draw_rect(Rect2(p,Vector2(224,160)),Color("dedbc9"))
			draw_texture_rect(icons[id],Rect2(p+Vector2(48,14),Vector2(128,128)),false)
			draw_string(font,p+Vector2(0,180),str(i+1)+" "+str(id).replace("cafeteria_","").replace("_v27",""),HORIZONTAL_ALIGNMENT_LEFT,245,14,Color("26352f"))
			i+=1
	func frame(origin: Vector2,width: int) -> void:
		var suffix:="_20" if width==20 else ""
		var y:=origin.y-6.48
		region("cafeteria_wing_left_v24",Rect2(origin.x,y,200,121.5),Rect2(origin.x+80,y,120,121.5))
		region("cafeteria_wing_right_v24",Rect2(origin.x+380,y,220,121.5),Rect2(origin.x+380,y,140,121.5))
		region("cafeteria_lintel_v24",Rect2(origin.x+200,y,180,31.5))
		Assembly.draw_component(self,assets["cafeteria_corner_l"+suffix+"_v27"],texture,origin)
		Assembly.draw_component(self,assets["cafeteria_corner_r"+suffix+"_v27"],texture,origin+Vector2(520,0))
		for right in [false,true]:
			var id:="cafeteria_wall_v_"+("r" if right else "l")+suffix+"_v27"
			var x:=600-width if right else 0
			var tile_y: float=assets[id].render_size[1]
			var clip:=Rect2(origin+Vector2(x,150),Vector2(width,190))
			var cursor:=24.0
			while cursor<340:
				Assembly.draw_component(self,assets[id],texture,origin+Vector2(x,cursor),Vector2.ZERO,clip)
				cursor+=tile_y
			Assembly.draw_component(self,assets["cafeteria_end"+suffix+"_v27"],texture,origin+Vector2(x,340))
		draw_string(ThemeDB.fallback_font,origin+Vector2(100,180),str(width)+" cross / original H face",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("26352f"))
func _initialize() -> void:
	call_deferred("preview")
func preview() -> void:
	root.size=Vector2i(1280,960)
	RenderingServer.set_default_clear_color(Color("a4ae9b"))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v27/manifest.json"))
	var originals: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v24/manifest.json"))
	var node:=Sheet.new()
	var source: Texture2D=load(manifest.master_texture)
	var img:=source.get_image();img.generate_mipmaps()
	node.texture=ImageTexture.create_from_image(img)
	node.assets={};node.old_assets={};node.icons={}
	for a in manifest.assets:
		node.assets[a.id]=a
		node.icons[a.id]=load(a.editor_icon)
	for a in originals.assets: node.old_assets[a.id]=a
	node.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mat:=ShaderMaterial.new();mat.shader=load("res://art/architecture/v25/safe_edges_v25.gdshader");node.material=mat
	root.add_child(node)
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var saved:=root.get_texture().get_image().save_png("res://native-preview.png")
	node.detail_mode=true;node.scale=Vector2(2,2);node.queue_redraw()
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var detail_saved:=root.get_texture().get_image().save_png("res://native-detail.png")
	var result: Dictionary={"mode":"isolated actual native local assembly, not game acceptance","renderer":RenderingServer.get_video_adapter_name(),"saved":saved==OK,"components":manifest.assets.size(),"widths":[24,20],"source":manifest.master_texture,"original_H_unchanged":true,"new_PNG":0,"full_texture_wrap":false}
	FileAccess.open("res://native-preview.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	result.detail_saved=detail_saved==OK
	FileAccess.open("res://native-preview.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print(JSON.stringify(result));quit(0 if saved==OK and detail_saved==OK else 1)
