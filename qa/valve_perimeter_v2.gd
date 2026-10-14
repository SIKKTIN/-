extends SceneTree
const OUT := "res://docs/art/valve-perimeter-v2/"
const Details = preload("res://scripts/presentation/site_details.gd")
var checks := {}
func _initialize() -> void:call_deferred("run")
func read(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func check(label: String,value: bool) -> void:
	checks[label]=value
	if not value:print("FAILED: ",label)
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://valve-perimeter-qa.cfg")
	root.size=Vector2i(1300,1100);root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before := read(OUT+"before-map.json")
	var after := read(path)
	var receipt := read(OUT+"registration.json")
	var doc=load("res://scripts/editor/map_document.gd").new()
	check("map loads",doc.open_file(path))
	check("map validates",doc.validate().errors.is_empty())
	for key in before:
		if key not in ["floor_regions","ground_details"]:check("unchanged "+key,before[key]==after[key])
	check("other floors unchanged",before.floor_regions.filter(func(s):return s.id!=receipt.changed_floor_id)==after.floor_regions.filter(func(s):return s.id!=receipt.changed_floor_id))
	check("other ground details unchanged",before.ground_details.filter(func(s):return s not in receipt.removed_ground_details)==after.ground_details.filter(func(s):return not s.get("valve_perimeter_generated",false)))
	var grass: Dictionary=after.floor_regions.filter(func(s):return s.id==receipt.changed_floor_id)[0]
	check("grass material loads",load("res://scripts/presentation/region_terrain.gd").texture(grass.asset_id,grass.manifest)!=null)
	var polygon := PackedVector2Array()
	for point: Array in grass.polygon:polygon.append(Vector2(grass.rect[0],grass.rect[1])+Vector2(point[0],point[1])*Vector2(grass.rect[2],grass.rect[3]))
	check("grass polygon triangulates",not Geometry2D.triangulate_polygon(polygon).is_empty())
	check("south approach remains paved",not Geometry2D.is_point_in_polygon(Vector2(3930,3720),polygon))
	for point in [Vector2(3650,3420),Vector2(4210,3420),Vector2(3930,3170),Vector2(3800,3720)]:
		check("grass surrounds platform "+str(point),Geometry2D.is_point_in_polygon(point,polygon))
	for id: String in receipt.added_ground_detail_ids:
		var s: Dictionary=after.ground_details.filter(func(s):return s.get("id","")==id)[0]
		check("yellow segment independently hit tested "+id,Details.hit_test(s,(Vector2(s.from[0],s.from[1])+Vector2(s.to[0],s.to[1]))/2,2))
		check("yellow line bold enough "+id,float(s.width)>=8 and float(s.opacity)>=.9)
	var refs: Array=[{"group":"floor_regions","index":after.floor_regions.find(grass)}]
	for id: String in receipt.added_ground_detail_ids:
		refs.append({"group":"ground_details","index":after.ground_details.find(after.ground_details.filter(func(s):return s.get("id","")==id)[0])})
	for ref: Dictionary in refs:
		check("perimeter can erase "+str(ref),doc.can_remove(ref))
		var saved := JSON.stringify(doc.data)
		doc.remove(ref);doc.undo()
		check("perimeter undo exact "+str(ref),JSON.stringify(doc.data)==saved)
	var game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game)
	await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	for actor in game.actors:
		actor.set_process(false);actor.set_physics_process(false);actor.immune_until=INF
	game.guard.position=Vector2(3500,1600);game.dog.position=Vector2(3500,1700)
	var actor=game.actors[0];actor.position=Vector2(3770,3790)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	var world=game.world
	check("gate remains locked",world.access_by_id("valve-maintenance-entry").closed)
	check("closed gate blocks entry",not world.motion_clear(Vector2(3930,3700),Vector2(3930,3590),actor,false,true))
	check("south public walkway remains clear",world.motion_clear(Vector2(3630,3790),Vector2(4240,3790),actor,false,true))
	check("west public passage remains clear",world.motion_clear(Vector2(3635,3290),Vector2(3635,3730),actor,false,true))
	check("east public passage remains clear",world.motion_clear(Vector2(4220,3300),Vector2(4220,3740),actor,false,true))
	world.set_access_closed("valve-maintenance-entry",false)
	check("south approach remains clear with gate open",world.motion_clear(Vector2(3930,3790),Vector2(3930,3700),actor,false,true))
	check("open gate allows entry",world.motion_clear(Vector2(3930,3700),Vector2(3930,3590),actor,false,true))
	world.set_access_closed("valve-maintenance-entry",true);game.room_visibility.doorways.tick(true)
	game.map_camera.following=false;game.map_camera.zoom=Vector2(1.1,1.1)
	game.map_camera.position=Vector2(3910,3430)-Vector2(root.size)/2.2;game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await shot("runtime-restored")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame();editor.open_now(path);await frame();await frame()
	editor.canvas.zoom=.67;editor.canvas.origin=editor.canvas.size/2-Vector2(3920,3410)*editor.canvas.zoom
	editor.resource_search.text="主阀门检修区";editor.rebuild_palette();editor.canvas.queue_redraw()
	await shot("editor-restored")
	check("QA leaves saved map unchanged",FileAccess.get_sha256(path)==disk)
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var mode := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open(OUT+"checks-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"perimeter_checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
