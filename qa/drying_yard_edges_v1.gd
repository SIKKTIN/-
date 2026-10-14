extends SceneTree
const OUT := "res://docs/art/drying-yard-edges-v1/"
const Terrain = preload("res://scripts/presentation/region_terrain.gd")
class GroundProbe extends Node2D:
	var config := {}
	func _draw() -> void:preload("res://scripts/presentation/region_terrain.gd").paint(self,config,Rect2(0,0,720,480))
var checks := {}
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func check(label: String, value: bool) -> void:
	checks[label]=value
	if not value:print("FAILED: ",label)
func raw(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func finish() -> void:
	var failed: Array=checks.keys().filter(func(label):return not checks[label])
	var mode := "candidate" if "--candidate" in OS.get_cmdline_user_args() else "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open(OUT+"checks-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"drying_yard_edge_checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://drying-yard-edges-v1-qa.cfg")
	root.size=Vector2i(1440,900)
	root.content_scale_size=root.size
	var doc=load("res://scripts/editor/map_document.gd").new()
	if "--candidate" in OS.get_cmdline_user_args():
		check("candidate opens",doc.open_file(OUT+"candidate-map.json"))
		check("candidate validates",doc.validate().errors.is_empty())
		finish()
		return
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before := raw(OUT+"before-map.json")
	var after := raw(OUT+"after-map.json")
	var record := raw(OUT+"registration.json")
	var same := true
	for key in before:
		if key not in ["terrain_patches","concept_plan"] and before[key]!=after[key]:same=false
	check("all floor furniture wall gate roof and rule data preserved",same)
	check("previous terrain patches preserved",before.terrain_patches==after.terrain_patches.filter(func(p):return p.get("id","") not in record.new_patch_ids))
	check("original transparent PNG preserved",FileAccess.get_sha256("res://"+record.png)==record.png_sha256)
	var source := Image.load_from_file("res://"+record.png)
	check("soft true alpha retained",source.get_format()==Image.FORMAT_RGBA8 and source.detect_alpha()==Image.ALPHA_BLEND and source.get_pixel(0,0).a==0)
	var patches: Array=after.terrain_patches.filter(func(p):return p.get("id","") in record.new_patch_ids)
	check("all fourteen ground border patches installed",patches.size()==14)
	check("new stones never block movement or sight",patches.all(func(p):return p.ground_only and not p.blocks_movement and not p.blocks_sight))
	for id in record.definitions:
		var texture: Texture2D=Terrain.texture(id,record.manifest)
		check("custom manifest ground sprite loads "+id,texture!=null and texture.get_width()<=1024)
	for p in patches:
		var a: Dictionary=Terrain.definitions[record.manifest][p.asset_id]
		var dims: Array=a.world_size
		var ratio: float=float(p.rect[2])/float(p.rect[3])
		var expected: float=float(dims[1])/float(dims[0]) if int(p.rotation_quarters)%2 else float(dims[0])/float(dims[1])
		check("ground strip keeps source proportions "+p.id,is_equal_approx(ratio,expected))
	check("right lawn stepped boundary has two return segments",patches.any(func(p):return str(p.id).contains("east-step-0")) and patches.any(func(p):return str(p.id).contains("east-step-outer")))
	# A real CanvasItem draw verifies per-patch manifest routing and UV rotation.
	if DisplayServer.get_name()!="headless":
		var viewport := SubViewport.new()
		viewport.size=Vector2i(720,480)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var probe := GroundProbe.new()
		probe.config={"terrain_manifest":"res://art/environment/factory_v46/manifest.json","floor_regions":[{"asset_id":"common_floor_v46","rect":[0,0,720,480],"tile_size":[320,320]}],"terrain_patches":[]}
		viewport.add_child(probe)
		await frame()
		await frame()
		var baseline := viewport.get_texture().get_image()
		var a: Dictionary=Terrain.definitions[record.manifest][record.definitions[0]]
		var b: Dictionary=Terrain.definitions[record.manifest][record.definitions[1]]
		probe.config.terrain_patches=[{"asset_id":a.id,"manifest":record.manifest,"rect":[20,70,a.world_size[0],a.world_size[1]],"rotation_quarters":0},
			{"asset_id":b.id,"manifest":record.manifest,"rect":[480,30,b.world_size[1],b.world_size[0]],"rotation_quarters":1}]
		probe.queue_redraw()
		await frame()
		await frame()
		var painted := viewport.get_texture().get_image()
		var horizontal := 0
		var vertical := 0
		var outside := 0
		for y in range(480):
			for x in range(720):
				if painted.get_pixel(x,y)!=baseline.get_pixel(x,y):
					if Rect2(18,68,364,a.world_size[1]+4).has_point(Vector2(x,y)):horizontal+=1
					elif Rect2(478,28,b.world_size[1]+4,364).has_point(Vector2(x,y)):vertical+=1
					else:outside+=1
		check("horizontal stones actually paint using their own manifest",horizontal>500)
		check("vertical stones actually paint after quarter turn",vertical>500)
		check("transparent strip does not paint a rectangular ground slab",outside==0)
		painted.save_png(OUT+"ground-render-probe.png")
		viewport.queue_free()
		await frame()
	var game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	for actor in game.actors:
		actor.immune_until=INF
		actor.set_process(false)
	game.guard.position=Vector2(3000,1500)
	game.dog.position=Vector2(3100,1500)
	var player=game.actors[0]
	player.position=Vector2(1460,2930)
	check("live map retains all border patches",game.room_config.terrain_patches.filter(func(p):return p.get("id","") in record.new_patch_ids).size()==14)
	check("stones are not furniture volumes or obstacles",not game.world.fixtures.any(func(f):return str(f.get("id","")).begins_with("drying-yard-stone-edge")))
	for x in [1335.0,1460.0,1585.0]:
		check("central walkway still clear "+str(x),game.world.motion_clear(Vector2(x,2580),Vector2(x,3280),player,false,true))
	for pair in [[Vector2(1280,2880),Vector2(1330,2880)],[Vector2(1600,2960),Vector2(1650,2960)],[Vector2(2090,2970),Vector2(2160,2970)]]:
		check("low border can be crossed "+str(pair[0]),game.world.motion_clear(pair[0],pair[1],player,false,true) and game.world.motion_clear(pair[1],pair[0],player,false,true))
	game.room_visibility.tick(0,true)
	game.map_camera.zoom=Vector2(.9,.9)
	game.map_camera.position=Vector2(1500,2860)-Vector2(root.size)/1.8
	game.map_camera.force_update_scroll()
	await frame()
	game.presentation.tick(0)
	await shot("runtime-stone-edges")
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	editor.open_now(path)
	await frame()
	await frame()
	check("saved map validates in editor",editor.document.validate().errors.is_empty())
	check("stone border belongs to protected editable ground layer",editor.layers.key_for("terrain_patches")=="ground" and editor.layers.locked.ground)
	check("editor lists all independent border pieces",editor.document.collection("terrain_patches").filter(func(p):return p.get("id","") in record.new_patch_ids).size()==14)
	editor.canvas.zoom=.65
	editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2820)*editor.canvas.zoom
	editor.resource_search.text="晾晒区"
	editor.rebuild_palette()
	editor.canvas.queue_redraw()
	await shot("editor-stone-edges")
	check("editor preview does not dirty the map",not editor.document.dirty())
	check("QA keeps saved map unchanged",FileAccess.get_sha256(path)==disk)
	editor.queue_free()
	await frame()
	finish()
