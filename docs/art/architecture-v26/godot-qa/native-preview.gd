extends SceneTree
const Assembly=preload("res://assembly.gd")
class Sheet extends Node2D:
	var assets: Dictionary
	var texture: Texture2D
	var labels: Dictionary
	var icons: Dictionary
	func _draw() -> void:
		var font:=ThemeDB.fallback_font
		draw_string(font,Vector2(32,24),"SAME MASTER / 64 UNIT / 128 PERIOD -- long walls, turns, 24 and 20 widths",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("24312c"))
		frame(Vector2(32,50),540,24)
		frame(Vector2(666,50),540,20)
		draw_string(font,Vector2(40,460),"24 wide / right turn phase76",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("24312c"))
		draw_string(font,Vector2(674,460),"20 wide / same stone scale, no horizontal squeeze",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("24312c"))
		var i:=0
		for id in assets:
			var p:=Vector2(28+(i%7)*176,510+(i/7)*190)
			draw_rect(Rect2(p,Vector2(152,152)),Color("e2e0d3"))
			var icon: Texture2D=icons[id]
			draw_texture_rect(icon,Rect2(p+Vector2(12,12),Vector2(128,128)),false)
			draw_string(font,p+Vector2(0,170),str(i+1)+" "+labels[id],HORIZONTAL_ALIGNMENT_LEFT,172,13,Color("24312c"))
			i+=1
	func frame(origin: Vector2,width: float,thickness: int) -> void:
		var suffix:="_20" if thickness==20 else ""
		var lc: Dictionary=assets["cafeteria_corner_l"+suffix+"_v26"]
		var rc: Dictionary=assets["cafeteria_corner_r"+suffix+"_v26"]
		Assembly.draw_component(self,lc,texture,origin)
		Assembly.draw_component(self,rc,texture,origin+Vector2(width-80,0),Vector2(width-80,0))
		var hc:=Rect2(origin+Vector2(80,0),Vector2(width-160,114))
		for x in range(0,int(width),128):
			Assembly.draw_component(self,assets.cafeteria_wall_h_v26,texture,origin+Vector2(x,0),Vector2(x,0),hc)
		for right in [false,true]:
			var id:="cafeteria_wall_v"+("_r" if right else "")+suffix+"_v26"
			var x:=width-thickness if right else 0.0
			var clip:=Rect2(origin+Vector2(x,150),Vector2(thickness,210))
			for y in range(128,360,128):
				Assembly.draw_component(self,assets[id],texture,origin+Vector2(x,y),Vector2(0,y),clip)
			Assembly.draw_component(self,assets["cafeteria_end"+suffix+"_v26"],texture,origin+Vector2(x,360))
func _initialize() -> void:
	call_deferred("preview")
func preview() -> void:
	root.size=Vector2i(1280,900)
	RenderingServer.set_default_clear_color(Color("a4ae9b"))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v26/manifest.json"))
	var node:=Sheet.new()
	var master: Texture2D=load(manifest.master_texture)
	var image:=master.get_image()
	image.generate_mipmaps()
	node.texture=ImageTexture.create_from_image(image)
	node.assets={}
	node.labels={}
	node.icons={}
	for asset in manifest.assets:
		node.assets[asset.id]=asset
		node.labels[asset.id]=str(asset.id).replace("cafeteria_","").replace("_v26","")
		node.icons[asset.id]=load(asset.editor_icon)
	node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mat:=ShaderMaterial.new()
	mat.shader=load("res://art/architecture/v25/safe_edges_v25.gdshader")
	node.material=mat
	root.add_child(node)
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var saved:=root.get_texture().get_image().save_png("res://native-preview.png")
	var result: Dictionary={"mode":"actual isolated Forward+ long H/V and left/right L native draw","renderer":RenderingServer.get_video_adapter_name(),"image_size":root.size,"screenshot_saved":saved==OK,"components":manifest.assets.size(),"same_texture":manifest.master_texture,"phase_right":76,"phase_vertical_continuation":22,"widths":[24,20],"not_actual_game_acceptance":true}
	FileAccess.open("res://native-preview.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print(JSON.stringify(result))
	quit(0 if saved==OK else 1)
