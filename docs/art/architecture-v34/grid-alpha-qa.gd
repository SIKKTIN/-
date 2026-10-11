extends SceneTree
const Volume=preload("res://scripts/presentation/world_volume.gd")
const TextureSource=preload("res://scripts/presentation/world_texture.gd")
class Owner extends RefCounted:
	var fixtures: Array=[]
	var art_textures: Dictionary={}
	var bounds:=Rect2(0,0,10000,10000)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var assets: Dictionary=load("res://scripts/presentation/prop_catalog.gd").assets()
	var results=[]
	for id in assets:
		var a: Dictionary=assets[id]
		if not a.has("grid_tile"):continue
		var viewport:=SubViewport.new();viewport.transparent_bg=true;viewport.size=Vector2i(a.render_size[0]*4,a.render_size[1]*4);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
		var owner:=Owner.new();owner.fixtures=[{"asset_id":id,"rect":Rect2(0,0,a.render_size[0],a.render_size[1]),"render_size":a.render_size}];owner.art_textures[id]=TextureSource.load_asset(a)
		var node:=Volume.new();node.scale=Vector2(4,4);viewport.add_child(node);node.configure(owner,"fixture",0,{},assets)
		for i in range(4):await process_frame
		await RenderingServer.frame_post_draw
		var im:=viewport.get_texture().get_image();var minimum:=1.0
		for x in range(im.get_width()):minimum=minf(minimum,minf(im.get_pixel(x,0).a,im.get_pixel(x,im.get_height()-1).a))
		for y in range(im.get_height()):minimum=minf(minimum,minf(im.get_pixel(0,y).a,im.get_pixel(im.get_width()-1,y).a))
		results.append({"id":id,"size_world":a.render_size,"grid_cells":[a.grid_tile.columns,a.grid_tile.rows],"four_edges_min_alpha":minimum,"passed":is_equal_approx(minimum,1.0)})
		viewport.queue_free();await process_frame
	var failed=results.filter(func(v):return not v.passed)
	FileAccess.open("res://docs/art/architecture-v34/grid-edge-alpha.json",FileAccess.WRITE).store_string(JSON.stringify({"tiles":results,"failed":failed,"passed":failed.is_empty()},"\t"))
	print(JSON.stringify({"tiles":results.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)
