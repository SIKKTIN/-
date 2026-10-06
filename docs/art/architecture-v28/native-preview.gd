extends SceneTree
const Assembly=preload("res://assembly.gd")
class Sheet extends Node2D:
	var assets: Dictionary
	var old_assets: Dictionary
	var v27: Dictionary
	var texture: Texture2D
	var original: Texture2D
	var icons: Dictionary
	var detail_mode:=false
	func region(id: String, area: Rect2, clip:=Rect2()) -> void:
		var s: Array=old_assets[id].region
		var src:=Rect2(s[0],s[1],s[2],s[3])
		var visible:=area.intersection(clip) if clip.has_area() else area
		if not visible.has_area():return
		var ratio:=src.size/area.size
		draw_texture_rect_region(original,visible,Rect2(src.position+(visible.position-area.position)*ratio,visible.size*ratio))
	func _draw() -> void:
		if detail_mode:
			frame(Vector2(12,30),24);return
		var font:=ThemeDB.fallback_font
		draw_string(font,Vector2(24,24),"A28 COMPLETE L BLOCK / original facade and straight walls retained",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("26352f"))
		frame(Vector2(24,65),24);frame(Vector2(654,65),20)
		var i:=0
		for id in assets:
			var p:=Vector2(32+i*312,560)
			draw_rect(Rect2(p,Vector2(264,190)),Color("dedbc9"))
			draw_texture_rect(icons[id],Rect2(p+Vector2(68,30),Vector2(128,128)),false)
			draw_string(font,p+Vector2(0,220),str(id).replace("cafeteria_","").replace("_v28",""),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("26352f"));i+=1
	func frame(origin: Vector2,cross: int) -> void:
		var suffix:="_20" if cross==20 else ""
		var size:=cross+56
		var wing_y:=origin.y-6.48
		# Original wall body stays behind the empty inner quadrant of the L.
		region("cafeteria_wing_left_v24",Rect2(origin.x,wing_y,200,121.5),Rect2(origin+Vector2(cross,24),Vector2(200-cross,100)))
		region("cafeteria_wing_left_v24",Rect2(origin.x,wing_y,200,121.5),Rect2(origin.x+size,wing_y,200-size,30.48))
		region("cafeteria_wing_right_v24",Rect2(origin.x+380,wing_y,220,121.5),Rect2(origin.x+380,origin.y+24,220-cross,100))
		region("cafeteria_wing_right_v24",Rect2(origin.x+380,wing_y,220,121.5),Rect2(origin.x+380,wing_y,220-size,30.48))
		region("cafeteria_lintel_v24",Rect2(origin.x+200,wing_y,180,31.5))
		# Restore original tall door pillars, outside dedicated turn bounds.
		region("cafeteria_jamb_left_v24",Rect2(origin.x+168,wing_y,32,121.5))
		region("cafeteria_jamb_right_v24",Rect2(origin.x+380,wing_y,32,121.5))
		Assembly.draw_component(self,assets["cafeteria_turn_l"+suffix+"_v28"],texture,origin)
		Assembly.draw_component(self,assets["cafeteria_turn_r"+suffix+"_v28"],texture,origin+Vector2(600-size,0))
		for right in [false,true]:
			var id:="cafeteria_wall_v_"+("r" if right else "l")+suffix+"_v27"
			var px:=600-cross if right else 0
			var tile_y: float=v27[id].render_size[1]
			var cursor:=80.0
			var clip:=Rect2(origin+Vector2(px,80),Vector2(cross,300))
			while cursor<380:
				Assembly.draw_component(self,v27[id],original,origin+Vector2(px,cursor),Vector2.ZERO,clip)
				cursor+=tile_y
			draw_string(ThemeDB.fallback_font,origin+Vector2(105,190),str(cross)+" wall cross section",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("26352f"))
func _initialize() -> void:call_deferred("preview")
func mip(path: String) -> Texture2D:
	var source: Texture2D=load(path);var img:=source.get_image();img.generate_mipmaps();return ImageTexture.create_from_image(img)
func preview() -> void:
	root.size=Vector2i(1280,900);RenderingServer.set_default_clear_color(Color("a4ae9b"))
	var m: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v28/manifest.json"))
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v24/manifest.json"))
	var old27: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v27/manifest.json"))
	var node:=Sheet.new();node.assets={};node.old_assets={};node.v27={};node.icons={}
	node.texture=mip(m.master_texture);node.original=mip("res://art/architecture/v24/cafeteria_portal_v24.png")
	for a in m.assets:node.assets[a.id]=a;node.icons[a.id]=load(a.editor_icon)
	for a in old.assets:node.old_assets[a.id]=a
	for a in old27.assets:node.v27[a.id]=a
	node.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED;node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mat:=ShaderMaterial.new();mat.shader=load("res://art/architecture/v25/safe_edges_v25.gdshader");node.material=mat
	root.add_child(node)
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	var saved:=root.get_texture().get_image().save_png("res://native-preview.png")
	node.detail_mode=true;node.scale=Vector2(2,2);node.queue_redraw()
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	var detail:=root.get_texture().get_image().save_png("res://native-detail.png")
	var result={"saved":saved==OK,"detail_saved":detail==OK,"renderer":RenderingServer.get_video_adapter_name(),"components":4,"single_corner_source":m.master_texture,"old_walls_unchanged":true,"native_local_trial_only":true}
	FileAccess.open("res://native-preview.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n");print(JSON.stringify(result));quit(0 if saved==OK and detail==OK else 1)
