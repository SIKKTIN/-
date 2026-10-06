extends SceneTree
const Assembly=preload("res://assembly.gd")
class Sheet extends Node2D:
	var assets: Dictionary
	var vertical: Dictionary
	var texture: Texture2D
	var original: Texture2D
	var icons: Dictionary
	var detail_mode:=false
	func old_region(area: Rect2,clip: Rect2) -> void:
		var visible_area:=area.intersection(clip)
		if not visible_area.has_area():return
		var ratio:=Vector2(573,375)/area.size
		draw_texture_rect_region(original,visible_area,Rect2(Vector2(140,172)+(visible_area.position-area.position)*ratio,visible_area.size*ratio))
	func reflected(a: Dictionary) -> Dictionary:
		var result:=a.duplicate(true)
		for p in result.assembly_patches:
			p.destination[0]=float(a.render_size[0])-float(p.destination[0])-float(p.destination[2])
			p.mirror_x=true
		return result
	func _draw() -> void:
		if detail_mode:frame(Vector2(16,30),24,false);return
		var font:=ThemeDB.fallback_font
		draw_string(font,Vector2(24,24),"NATURAL MASONRY JUNCTION / normal header+stem stones / original facade retained",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("26352f"))
		frame(Vector2(24,65),24,false);frame(Vector2(670,65),20,true)
		var i:=0
		for id in assets:
			var p:=Vector2(200+i*620,510)
			draw_rect(Rect2(p,Vector2(260,220)),Color("dedbc9"))
			draw_texture_rect(icons[id],Rect2(p+Vector2(66,35),Vector2(128,128)),false)
			draw_string(font,p+Vector2(0,245),str(id).replace("cafeteria_",""),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("26352f"));i+=1
	func frame(origin: Vector2,cross: int,mirror: bool) -> void:
		var id:="cafeteria_t_20_v30" if cross==20 else "cafeteria_t_v30"
		var a: Dictionary=assets[id]
		var tile_w: float=a.render_size[0]
		var left: float=(560-tile_w)/2
		var wing_y:=origin.y-6.48
		var clips: Array[Rect2]=[Rect2(origin.x,wing_y,left,27.48),Rect2(origin.x+left+tile_w,wing_y,560-left-tile_w,27.48),Rect2(origin.x,origin.y+21,560,103)]
		for x in range(0,560,144):
			for c in clips:old_region(Rect2(origin.x+x,wing_y,144,121.5),c)
		Assembly.draw_component(self,reflected(a) if mirror else a,texture,origin+Vector2(left,0))
		var suffix:="_20" if cross==20 else ""
		var v: Dictionary=vertical["cafeteria_wall_v_"+("r" if mirror else "l")+suffix+"_v27"]
		var cursor:=80.0
		var clip:=Rect2(origin+Vector2(left+56,80),Vector2(cross,270))
		while cursor<350:
			Assembly.draw_component(self,v,original,origin+Vector2(left+56,cursor),Vector2.ZERO,clip)
			cursor+=float(v.render_size[1])
		draw_string(ThemeDB.fallback_font,origin+Vector2(24,190),str(cross)+" stem"+(" / right mirror" if mirror else " / default"),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("26352f"))
func _initialize() -> void:call_deferred("preview")
func mip(path: String) -> Texture2D:
	var src: Texture2D=load(path);var img:=src.get_image();img.generate_mipmaps();return ImageTexture.create_from_image(img)
func preview() -> void:
	root.size=Vector2i(1280,850);RenderingServer.set_default_clear_color(Color("a4ae9b"))
	var m: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v30/manifest.json"))
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v27/manifest.json"))
	var node:=Sheet.new();node.assets={};node.vertical={};node.icons={}
	node.texture=mip(m.master_texture);node.original=mip("res://art/architecture/v24/cafeteria_portal_v24.png")
	for a in m.assets:node.assets[a.id]=a;node.icons[a.id]=load(a.editor_icon)
	for a in old.assets:node.vertical[a.id]=a
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
	var result={"saved":saved==OK,"detail_saved":detail==OK,"renderer":RenderingServer.get_video_adapter_name(),"components":2,"single_T_source":m.master_texture,"old_walls_unchanged":true,"native_local_trial_only":true,"default_and_right_mirror":true}
	FileAccess.open("res://native-preview.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n");print(JSON.stringify(result));quit(0 if saved==OK and detail==OK else 1)


