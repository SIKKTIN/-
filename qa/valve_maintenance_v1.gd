extends SceneTree
const OUT := "res://docs/art/valve-maintenance-v1/"
const Catalog = preload("res://scripts/presentation/prop_catalog.gd")
const Textures = preload("res://scripts/presentation/world_texture.gd")
var checks := {}
var game
func _initialize() -> void:call_deferred("run")
func read(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func check(label: String,value: bool) -> void:
	checks[label]=value
	if not value:print("FAILED: ",label)
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://valve-maintenance-qa.cfg")
	root.size=Vector2i(1500,1100)
	root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before := read(OUT+"before-map.json")
	var after := read(path)
	var registration := read(OUT+"registration.json")
	var perimeter := read("res://docs/art/valve-perimeter-v2/registration.json") if after.ground_details.any(func(s):return s.get("valve_perimeter_generated",false)) else {}
	var production := read(OUT+"production-assets.json")
	var doc=load("res://scripts/editor/map_document.gd").new()
	check("map loads",doc.open_file(path))
	check("map validates",doc.validate().errors.is_empty())
	for key in before:
		if key=="ground_details" and not perimeter.is_empty():
			check("other map data retained "+key,before[key].filter(func(s):return s not in perimeter.removed_ground_details)==after[key].filter(func(s):return not s.get("valve_perimeter_generated",false)))
		elif key not in ["fixtures","access_doors","floor_regions"]:check("other map data retained "+key,before[key]==after[key])
	check("other props retained",before.fixtures.filter(func(f):return f.id not in registration.removed_fixture_ids)==after.fixtures.filter(func(f):return not f.get("valve_maintenance_generated",false)))
	check("other access rules retained",before.access_doors==after.access_doors.filter(func(g):return g.id!=registration.added_access_id))
	check("other floors retained",before.floor_regions.filter(func(f):return f.id not in registration.changed_floor_ids)==after.floor_regions.filter(func(f):return f.id not in registration.changed_floor_ids))
	check("platform original footprint retained",after.fixtures.filter(func(f):return f.id=="valve-maintenance-base")[0].rect==registration.platform_rect)
	check("original baked valve platform removed",not after.fixtures.any(func(f):return f.id=="energy-court-valve-platform"))
	var definitions := Catalog.assets()
	for source in production.pngs:
		check("source PNG byte identical "+source.key,FileAccess.get_sha256("res://"+source.path)==source.sha256)
		var pixels := Image.load_from_file("res://"+source.path)
		check("real transparent alpha "+source.key,pixels.get_pixel(0,0).a<.01 and pixels.detect_alpha()!=Image.ALPHA_NONE)
	for id in production.definition_ids:
		check("asset loads "+id,definitions.has(id) and Textures.load_asset(definitions[id])!=null)
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	for actor in game.actors:
		actor.set_process(false);actor.set_physics_process(false);actor.immune_until=INF
	game.guard.position=Vector2(3500,1600)
	game.dog.position=Vector2(3500,1700)
	game.actors[0].position=Vector2(3770,3790)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	var world=game.world
	var actor=game.actors[0]
	var gate=world.access_by_id("valve-maintenance-entry")
	check("maintenance gate starts locked",gate.closed and gate.kind=="locked")
	check("closed gate blocks south entry",not world.motion_clear(Vector2(3930,3700),Vector2(3930,3590),actor,false,true))
	check("west fence blocks sideways entry",not world.motion_clear(Vector2(3650,3430),Vector2(3740,3430),actor,false,true))
	check("east fence blocks sideways entry",not world.motion_clear(Vector2(4210,3430),Vector2(4130,3430),actor,false,true))
	check("north fence blocks entry",not world.motion_clear(Vector2(3890,3175),Vector2(3890,3270),actor,false,true))
	check("northwest diagonal fence blocks entry",not world.motion_clear(Vector2(3715,3245),Vector2(3770,3300),actor,false,true))
	check("southeast diagonal fence blocks entry",not world.motion_clear(Vector2(4170,3600),Vector2(4100,3535),actor,false,true))
	check("south public walkway clear",world.motion_clear(Vector2(3630,3790),Vector2(4240,3790),actor,false,true))
	check("west public service passage clear",world.motion_clear(Vector2(3635,3290),Vector2(3635,3730),actor,false,true))
	check("east warehouse access passage clear",world.motion_clear(Vector2(4220,3300),Vector2(4220,3740),actor,false,true))
	check("base does not create full-rectangle air wall",not world.fixtures.filter(func(f):return f.id=="valve-maintenance-base")[0].blocks_movement)
	world.set_access_closed("valve-maintenance-entry",false)
	game.room_visibility.doorways.tick(true)
	check("authorized open gate permits entry",world.motion_clear(Vector2(3930,3700),Vector2(3930,3590),actor,false,true))
	check("west inspection path reachable",not world.find_path(Vector2(3930,3700),Vector2(3820,3555),actor,false,true).is_empty())
	check("east inspection path reachable",not world.find_path(Vector2(3930,3700),Vector2(4060,3555),actor,false,true).is_empty())
	game.map_camera.following=false;game.map_camera.zoom=Vector2(.92,.92)
	game.map_camera.position=Vector2(3900,3350)-Vector2(root.size)/1.84
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await shot("runtime-open")
	world.set_access_closed("valve-maintenance-entry",true)
	game.room_visibility.doorways.tick(true)
	game.presentation.tick(0)
	await shot("runtime-closed")
	var door=game.room_visibility.doorways.door_by_id.get("valve-maintenance-entry")
	check("custom gate presentation connected",door!=null and door.closed_patches.size()==1 and door.open_patches.size()==3)
	for f in world.fixtures.filter(func(f):return f.get("valve_maintenance_generated",false)):
		var v=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and world.fixtures[v.wall_index].id==f.id)[0]
		if f.id!="valve-maintenance-gate":check("outdoor part visible "+f.id,v.visible)
		if f.blocks_movement:check("collider exists "+f.id,not world.fixture_collision_rects(f).is_empty())
		if f.id=="valve-maintenance-base":check("base art matches 500px physical width",is_equal_approx(v.display_rect.size.x,500))
		if f.id=="valve-maintenance-machine":
			check("machine sprite keeps calibrated width",is_equal_approx(v.display_rect.size.x,230))
			var df: Dictionary=definitions[f.asset_id]
			var pixels := Image.load_from_file(df.texture)
			var region: Array=df.region
			for point in [Vector2(3930,3340),Vector2(3820,3480)]:
				var uv: Vector2=(point-v.display_rect.position)/v.display_rect.size
				var pixel := Vector2i(Vector2(region[0],region[1])+uv*Vector2(region[2],region[3]))
				check("pipe connects to opaque valve port "+str(point),pixels.get_pixelv(pixel).a>.80)
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor);await frame();await frame()
	editor.open_now(path);await frame();await frame()
	for id in production.definition_ids:
		if definitions[id].get("editor_hidden",false):continue
		check("asset available in editor "+id,editor.catalog.entries.any(func(e):return e.id==id))
	for id in registration.added_fixture_ids:
		var index: int=editor.document.data.fixtures.find(editor.document.data.fixtures.filter(func(f):return f.id==id)[0])
		var ref: Dictionary={"group":"fixtures","index":index}
		check("can select component "+id,not editor.canvas.architecture_preview.visual_hit_areas(ref).is_empty())
		check("can erase component "+id,editor.document.can_remove(ref))
		var saved := JSON.stringify(editor.document.data)
		editor.document.remove(ref)
		check("erase removes component "+id,not editor.document.data.fixtures.any(func(f):return f.id==id))
		editor.document.undo()
		check("undo restores component "+id,JSON.stringify(editor.document.data)==saved)
	editor.canvas.zoom=.67;editor.canvas.origin=editor.canvas.size/2-Vector2(3920,3375)*editor.canvas.zoom
	editor.resource_search.text="主阀门检修区";editor.rebuild_palette();editor.canvas.queue_redraw()
	await shot("editor-restored")
	check("QA leaves map unchanged",FileAccess.get_sha256(path)==disk)
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var mode := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open(OUT+"checks-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"valve_maintenance_checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
