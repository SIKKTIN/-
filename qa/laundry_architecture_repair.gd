extends SceneTree
const OUT="res://docs/art/laundry-architecture-repair-v3/"
var checks={}
var game
func _initialize():
	create_timer(120).timeout.connect(func():quit(124))
	call_deferred("run")
func raw(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func check(label: String, ok: bool):
	checks[label]=ok
	if not ok:print("FAIL: ",label)
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String):
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func by_id(values: Array) -> Dictionary:
	var result={}
	for value in values:result[value.id]=value
	return result
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://laundry-architecture-qa.cfg")
	root.size=Vector2i(1200,850);root.content_scale_size=root.size
	var before=raw(OUT+"input-map.json");var after=raw(OUT+"output-map.json");var record=raw(OUT+"registration.json")
	for key in before:
		if key not in ["fixtures","architecture","access_doors"]:check("preserved map field "+key,before[key]==after[key])
	var permitted=["cafeteria-rear-visual45"]
	for f in before.fixtures:
		if f.get("asset_id")=="laundry_downpipe_v1":permitted.append(f.id)
	check("furniture and bath retained",by_id(before.fixtures.filter(func(f):return f.id not in permitted))==by_id(after.fixtures.filter(func(f):return f.id not in permitted)))
	for i in before.architecture.wall_surfaces.size():
		var a: Dictionary=before.architecture.wall_surfaces[i].duplicate(true);var b: Dictionary=after.architecture.wall_surfaces[i].duplicate(true)
		a.erase("grid_tile_asset");b.erase("grid_tile_asset");a.erase("render_enabled");b.erase("render_enabled")
		if a!=b:check("wall geometry and collision retained",false)
	check("wall geometry retained",before.walls==after.walls)
	for gate in before.access_doors:
		var a: Dictionary=gate.duplicate(true);var b: Dictionary=by_id(after.access_doors)[gate.id].duplicate(true)
		a.erase("asset_id");b.erase("asset_id");a.erase("interaction_point");b.erase("interaction_point")
		check("gate behavior retained "+gate.id,a==b)
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	var fixture: Dictionary=by_id(game.world.fixtures)["cafeteria-rear-visual45"]
	var player=game.actors[0];var center: Vector2=fixture.rect.get_center()
	var outside=center+Vector2(0,-160);var inside=center+Vector2(0,130)
	game.guard.position=Vector2(3000,1500);game.dog.position=Vector2(3100,1500)
	var door=game.room_visibility.doorways.by_id("cafeteria-rear")
	check("door full wall height without oversized wings",door.visual_rect.size==Vector2(200,120) and door.visual_rect.end.y==fixture.rect.end.y)
	game.world.set_access_closed("cafeteria-rear",false);game.room_visibility.doorways.tick(true)
	for dx in [-40,0,40]:check("north bidirectional body crossing "+str(dx),game.world.motion_clear(outside+Vector2(dx,0),inside+Vector2(dx,0),player,false,true) and game.world.motion_clear(inside+Vector2(dx,0),outside+Vector2(dx,0),player,false,true))
	player.position=inside;game.room_visibility.tick(0,true);game.presentation.tick(0)
	game.map_camera.zoom=Vector2(0.96,0.96);game.map_camera.position=center+Vector2(80,255)-Vector2(root.size)/0.96/2;game.map_camera.force_update_scroll()
	await shot("runtime-open")
	game.world.set_access_closed("cafeteria-rear",true);game.room_visibility.doorways.tick(true)
	check("closed door blocks body both ways",not game.world.motion_clear(outside,inside,player,false,true) and not game.world.motion_clear(inside,outside,player,false,true))
	check("shared jambs for both states",door.open_patches.size()==3 and door.closed_patches.size()==4)
	var pipe_index=game.world.fixtures.find(by_id(game.world.fixtures)["laundry-downpipe"])
	check("exterior pipe crosses coping intact",game.presentation.volumes.any(func(v):return v.kind=="fixture" and v.wall_index==pipe_index and v.z_index==4096))
	await shot("runtime-closed")
	var side=game.world.access_by_id("laundry-equipment");var inside_side=Vector2(side.interaction_point[0],side.interaction_point[1]);var outside_side=Vector2(side.rect.position.x-70,inside_side.y)
	game.world.set_access_closed("laundry-equipment",false);game.room_visibility.doorways.tick(true)
	check("side door interaction point reachable",game.world.motion_clear(outside_side,inside_side,player,false,true) and game.world.motion_clear(inside_side,outside_side,player,false,true))
	game.world.set_access_closed("laundry-equipment",true);game.room_visibility.doorways.tick(true)
	check("locked side door blocks crossing",not game.world.motion_clear(outside_side,inside_side,player,false,true))
	player.position=outside;game.room_visibility.tick(0,true);game.presentation.tick(0)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="laundry")[0]
	check("roof opaque from outside",cover.visible and cover.modulate.a==1)
	await shot("runtime-roof")
	var definitions=preload("res://scripts/presentation/prop_catalog.gd").assets()
	for id in record.definition_ids:
		var texture=preload("res://scripts/presentation/world_texture.gd").load_asset(definitions[id])
		check("bounded texture "+id,texture!=null and maxf(texture.get_width(),texture.get_height())<=512)
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame();editor.open_now("res://data/rooms/r04.json");await frame()
	check("map validates",editor.document.validate().errors.is_empty())
	for id in record.definition_ids:check("palette registered "+id,editor.catalog.entries.any(func(a):return a.id==id))
	editor.canvas.zoom=0.62;editor.canvas.origin=editor.canvas.size/2-(center+Vector2(20,280))*0.62;editor.canvas.queue_redraw()
	editor.resource_search.text="洗衣室新版";editor.rebuild_palette()
	await shot("editor-layout")
	check("QA does not persist door state",by_id(raw("res://data/rooms/r04.json").fixtures)["cafeteria-rear-visual45"]==by_id(after.fixtures)["cafeteria-rear-visual45"])
	var failed=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"checks":checks,"failed":failed},"\t"))
	print("Laundry architecture QA: ",checks.size()," checks; failures=",failed)
	quit(0 if failed.is_empty() else 1)
