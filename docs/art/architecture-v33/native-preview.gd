extends SceneTree
const Assembly=preload("res://assembly.gd")
class Sheet extends Node2D:
	var assets: Dictionary
	var texture: Texture2D
	var icons: Dictionary
	var short_detail:=false
	func piece(id: String,p: Vector2) -> void:
		Assembly.draw_component(self,assets[id],texture,p)
	func _draw() -> void:
		if short_detail:
			piece("cafeteria_t_20_v33",Vector2(24,24))
			piece("cafeteria_wall_join_l_v33",Vector2(132,24))
			piece("cafeteria_t_20_v33",Vector2(170,24))
			piece("cafeteria_wall_join_r_v33",Vector2(238,24))
			return
		var font:=ThemeDB.fallback_font
		draw_string(font,Vector2(24,30),"COMPLETE SHORT T / 24-unit open arms; facade and plinth included",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("25332d"))
		piece("cafeteria_t_20_v33",Vector2(90,55))
		piece("cafeteria_t_v33",Vector2(250,55))
		draw_string(font,Vector2(90,205),"20 thick",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("25332d"))
		draw_string(font,Vector2(250,205),"24 thick",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("25332d"))
		# Exact source-contiguous, complete-body H/T/H assembly.
		var p:=Vector2(560,55)
		piece("cafeteria_wall_join_l_v33",p)
		piece("cafeteria_t_20_v33",p+Vector2(38,0))
		piece("cafeteria_wall_join_r_v33",p+Vector2(106,0))
		var v: Dictionary=assets["cafeteria_wall_v_l_20_v33"]
		var o:=p+Vector2(62,252.0*121.5/370.0)
		var clip:=Rect2(p+Vector2(62,121.5),Vector2(20,108.5))
		for k in range(2):Assembly.draw_component(self,v,texture,o+Vector2(0,k*float(v.render_size[1])),Vector2.ZERO,clip)
		piece("cafeteria_end_20_v33",p+Vector2(62,230))
		draw_string(font,Vector2(535,395),"Full wall H + short T + H / V / same-source end",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("25332d"))
		var i:=0
		for id in icons:
			var at:=Vector2(20+(i%8)*156,430+(i/8)*175)
			draw_texture_rect(icons[id],Rect2(at,Vector2(128,128)),false)
			draw_string(font,at+Vector2(0,150),str(i+1)+" "+str(id).replace("cafeteria_",""),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("25332d"))
			i+=1
func _initialize() -> void:call_deferred("preview")
func preview() -> void:
	root.size=Vector2i(1280,850)
	RenderingServer.set_default_clear_color(Color("a4ae9b"))
	var m: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v33/manifest.json"))
	var node:=Sheet.new();node.assets={};node.icons={}
	if OS.get_cmdline_user_args().has("short"):
		node.short_detail=true;node.scale=Vector2(3,3);root.size=Vector2i(920,520)
	var src: Texture2D=load(m.master_texture);var im:=src.get_image();im.generate_mipmaps();node.texture=ImageTexture.create_from_image(im)
	for a in m.assets:node.assets[a.id]=a;node.icons[a.id]=load(a.editor_icon)
	node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mat:=ShaderMaterial.new();mat.shader=load(m.edge_shader);node.material=mat
	root.add_child(node)
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image().save_png("res://native-preview.png")
	var checks=[]
	for a in m.assets:checks.append({"id":a.id,"valid":node.icons[a.id]!=null,"icon_type":node.icons[a.id].get_class()})
	var report={"saved":result==OK,"components":m.assets.size(),"gpu":RenderingServer.get_video_adapter_name(),"icons":checks,"complete_wall_assembly":"new source H/T/V/end only; no previous wall PNG", "native_only":true}
	FileAccess.open("res://native-preview.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print(JSON.stringify(report));quit(0 if result==OK else 1)
