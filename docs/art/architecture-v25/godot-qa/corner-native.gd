extends SceneTree
class JunctionCanvas extends Node2D:
	var portal: Texture2D
	var top: Texture2D
	var corner: Texture2D
	var patches: Array
	func _draw() -> void:
		for patch in patches:
			var d: Array = patch.destination
			var s: Array = patch.source
			draw_texture_rect_region(corner, Rect2(d[0],d[1],d[2],d[3]),Rect2(s[0],s[1],s[2],s[3]))
		draw_texture_rect_region(portal,Rect2(80,-7.776,120,121.5),Rect2(362.4,172,474.6,375))
		draw_texture_rect(top,Rect2(0,150,24,128),false)
func _initialize() -> void:
	call_deferred("render_junction")
func render_junction() -> void:
	root.size=Vector2i(800,760)
	RenderingServer.set_default_clear_color(Color("929d87"))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v25/manifest.json"))
	var asset: Dictionary
	for entry in manifest.assets:
		if entry.id=="cafeteria_corner_l_v25":
			asset=entry
	var canvas:=JunctionCanvas.new()
	canvas.portal=load("res://art/architecture/v24/cafeteria_portal_v24.png")
	canvas.top=load("res://art/architecture/v25/cafeteria_return_top_v25.png")
	canvas.corner=load(asset.texture)
	canvas.patches=asset.assembly_patches
	canvas.position=Vector2(40,40)
	canvas.scale=Vector2(2.5,2.5)
	var mat:=ShaderMaterial.new()
	mat.shader=load("res://art/architecture/v25/safe_edges_v25.gdshader")
	canvas.material=mat
	root.add_child(canvas)
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image()
	var saved:=img.save_png("res://corner-native.png")
	var result: Dictionary={"mode":"isolated actual Forward+ L corner assembly draw","renderer":RenderingServer.get_video_adapter_name(),"patches_drawn":asset.assembly_patches.size(),"image_size":img.get_size(),"screenshot_saved":saved==OK,"not_actual_game_acceptance":true}
	FileAccess.open("res://corner-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print(JSON.stringify(result))
	quit(0 if saved==OK else 1)
