extends SceneTree
const OUT := "res://docs/art/north-west-roads-v5/"
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://north-west-roads-preview.cfg")
	root.size=Vector2i(1440,950);root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"before-map.json"))
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration.json"))
	var doc=load("res://scripts/editor/map_document.gd").new()
	assert(doc.open_file(path))
	var report := {"map_valid":doc.validate().errors.is_empty(),
		"saved_floors_retained":before.floor_regions==doc.data.floor_regions.filter(func(f):return not f.get("north_west_roads_generated",false)),
		"saved_objects_retained":before.fixtures==doc.data.fixtures.filter(func(f):return not f.get("north_west_roads_generated",false)),
		"architecture_retained":before.walls==doc.data.walls and before.access_doors==doc.data.access_doors and before.architecture==doc.data.architecture,
		"stone_source_unchanged":FileAccess.get_sha256(receipt.source_png)==receipt.source_sha256}
	var game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game)
	await frame();game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	for actor in game.actors:
		actor.set_process(false);actor.set_physics_process(false);actor.immune_until=INF
	var actor=game.actors[0];actor.position=Vector2(800,880)
	var old_world=load("res://scripts/world/prison_world.gd").new()
	var new_world=load("res://scripts/world/prison_world.gd").new()
	old_world.configure(before,[]);new_world.configure(doc.data,[])
	report.original_collision_geometry_retained=old_world.solid_rects(false)==new_world.solid_rects(false) and old_world.body_solids==new_world.body_solids
	for route in [["west street",Vector2(800,280),Vector2(800,1780)],
		["north street junction",Vector2(800,880),Vector2(2200,880)],
		["south street junction",Vector2(800,1660),Vector2(1020,1770)]]:
		report[str(route[0])+" reachable"]=not game.world.find_path(route[1],route[2],actor,false,true).is_empty()
	for gap in receipt.door_gaps:
		var center: float=gap[1]+gap[3]/2
		report["west doorway approach "+str(center)]=game.world.motion_clear(Vector2(740,center),Vector2(810,center),actor,false,true)
		report["west doorway collision unchanged "+str(center)]=old_world.motion_clear(Vector2(710,center),Vector2(810,center),null,false,true)==new_world.motion_clear(Vector2(710,center),Vector2(810,center),null,false,true)
	old_world.free();new_world.free()
	for id: String in receipt.added_fixture_ids:
		var f: Dictionary=game.world.fixtures.filter(func(f):return f.id==id)[0]
		report["nonblocking "+id]=not f.blocks_movement and not game.world.static_solids.has(f.rect)
		var node=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and game.world.fixtures[v.wall_index].id==id)[0]
		var expected := Vector2(20,f.rect.size.y) if int(f.get("rotation_quarters",0))%2 else Vector2(f.rect.size.x,20)
		report["display calibrated "+id]=node.visible and node.display_rect.size.is_equal_approx(expected)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	game.map_camera.following=false;game.map_camera.zoom=Vector2(.47,.47)
	game.map_camera.position=Vector2(1550,1080)-Vector2(root.size)/.94;game.map_camera.force_update_scroll()
	await shot("runtime-roads")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame();editor.open_now(path);await frame();await frame()
	editor.canvas.zoom=.49;editor.canvas.origin=editor.canvas.size/2-Vector2(1590,1080)*editor.canvas.zoom
	editor.resource_search.text="宿舍北侧连接道路";editor.rebuild_palette();editor.canvas.queue_redraw()
	for id: String in receipt.added_fixture_ids:
		var fixture: Dictionary=editor.document.data.fixtures.filter(func(f):return f.id==id)[0]
		var ref := {"group":"fixtures","index":editor.document.data.fixtures.find(fixture)}
		report["editable "+id]=editor.document.can_remove(ref) and not editor.canvas.architecture_preview.visual_hit_areas(ref).is_empty()
	await shot("editor-roads")
	report.map_not_modified_during_preview=FileAccess.get_sha256(path)==disk
	var failed: Array=report.keys().filter(func(k):return not report[k])
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":report,"failed":failed},"\t"))
	print(JSON.stringify({"checks":report.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)
