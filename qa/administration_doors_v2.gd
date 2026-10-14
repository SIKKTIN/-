extends SceneTree
const OUT := "res://docs/art/administration-doors-v2/"
const Depth = preload("res://scripts/presentation/world_depth.gd")
var checks := {}
var game
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func check(label: String, value: bool) -> void:
	checks[label]=value
	if not value:print("FAILED: "+label)
func read(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func duty_state(closed: bool) -> void:
	var f: Dictionary=game.world.fixtures.filter(func(v):return v.id=="campus-duty")[0]
	f.asset_id="doorway_duty_closed_v2" if closed else "doorway_duty_open_v2"
	game.world.door_passage.configure(game.world,game.room_visibility.rooms)
	game.world._changed()
	game.room_visibility.doorways.configure(game.world,game.room_visibility.rooms,game.room_config)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://administration-doors-v2-qa.cfg")
	root.size=Vector2i(1440,900)
	root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before := read(OUT+"before-map.json")
	var after := read(OUT+"after-map.json")
	var current := read(path)
	var record := read(OUT+"registration.json")
	var same := true
	for key in before:
		if key not in ["fixtures","access_doors"] and before[key]!=after[key]:same=false
	check("other map fields walls roofs and rules preserved",same)
	check("other furniture unchanged",before.fixtures.filter(func(v):return v.id not in record.changed_fixture_ids)==after.fixtures.filter(func(v):return v.id not in record.changed_fixture_ids))
	check("other access gates unchanged",before.access_doors.filter(func(v):return v.id!="office-entry")==after.access_doors.filter(func(v):return v.id!="office-entry"))
	var original_office: Dictionary=before.access_doors.filter(func(v):return v.id=="office-entry")[0]
	var current_office: Dictionary=after.access_doors.filter(func(v):return v.id=="office-entry")[0].duplicate(true)
	current_office.erase("asset_id")
	current_office.erase("interaction_point")
	check("office retains locked identity and permission",current_office==original_office)
	check("current saved map retains the new door fixtures",after.fixtures.filter(func(v):return v.id in record.changed_fixture_ids)==current.fixtures.filter(func(v):return v.id in record.changed_fixture_ids))
	check("current saved map retains office door settings",after.access_doors.filter(func(v):return v.id=="office-entry")==current.access_doors.filter(func(v):return v.id=="office-entry"))
	check("original workshop PNG unchanged",FileAccess.get_sha256(record.source_png)==record.source_png_sha256)
	check("original workshop manifest unchanged",FileAccess.get_sha256("res://art/architecture/workshop_door_v2/manifest.json")==record.source_sha256)
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	for actor in game.actors:actor.immune_until=INF
	game.guard.position=Vector2(3000,2300)
	game.dog.position=Vector2(3000,2400)
	var player=game.actors[0]
	player.position=Vector2(4210,880)
	check("duty default remains open",not game.world.door_passage.by_id("fixture:campus-duty").closed)
	check("office default remains closed",game.world.access_by_id("office-entry").closed)
	for pair in [["duty","fixture:campus-duty",3990.0],["office","office-entry",4450.0]]:
		var door=game.room_visibility.doorways.by_id(pair[1])
		check(pair[0]+" two states installed",door.custom_texture!=null and door.closed_custom_texture!=null and door.open_patches.size()==3 and door.closed_patches.size()==2)
		check(pair[0]+" shares stable workshop frame",door.open_patches[-1].texture==door.closed_patches[-1].texture and door.open_patches[-1].source==door.closed_patches[-1].source and door.open_patches[-1].destination==door.closed_patches[-1].destination)
		check(pair[0]+" frame stays fixed on wall",door.visual_rect==Rect2(pair[2]-90,580,180,120) and not door.vertical)
		check(pair[0]+" old facade fully cut out",game.room_visibility.portal_cuts.has(door.visual_rect))
		check(pair[0]+" independent threshold below characters",door.has_node("ThresholdFloor") and door.get_node("ThresholdFloor").z_index==12 and not door.get_node("ThresholdFloor").z_as_relative)
		check(pair[0]+" uses foreground depth limit",door.gate.get("body_depth_limited",false) and door.z_index<Depth.for_y(704,game.world.bounds.end.y))
	game.world.set_access_closed("office-entry",false)
	for pair in [["duty",3990.0],["office",4450.0]]:
		var outside := Vector2(pair[1],790)
		var inside := Vector2(pair[1],605)
		check(pair[0]+" open full body crossing both directions",game.world.motion_clear(outside,inside,player,false,true) and game.world.motion_clear(inside,outside,player,false,true))
		check(pair[0]+" foreground stays free near door",game.world.can_place_circle(Vector2(pair[1]-70,728),8,player,false,false))
	player.position=Vector2(4450,800)
	game.world.set_access_closed("office-entry",true)
	check("closed office blocks whole body",not game.world.motion_clear(Vector2(4450,790),Vector2(4450,605),player,false,true))
	duty_state(true)
	check("closed duty asset renders closed state",game.room_visibility.doorways.by_id("fixture:campus-duty").closed)
	check("closed duty blocks whole body",not game.world.motion_clear(Vector2(3990,790),Vector2(3990,605),player,false,true))
	game.map_camera.center_on(Vector2(4230,625))
	game.map_camera.force_update_scroll()
	await frame()
	game.presentation.tick(0)
	await shot("runtime-closed")
	player.position=game.world.door_interaction_point(game.world.access_by_id("office-entry"))
	game.room_visibility.tick(0,true)
	check("office can be selected by existing unlock actions",game.skills.door_id(player)=="office-entry" and game.skills.door_reason(player).is_empty())
	var key: String=game.inventory.add_ground("door_key",player.position)
	var pickup: Dictionary=game.inventory.try_pickup(0,key)
	if not pickup.ok:print("KEY PICKUP: ",pickup.reason)
	check("office key pickup",pickup.ok)
	var use: Dictionary=game.inventory.try_use(0,key)
	if not use.ok:print("KEY USE: ",use.reason)
	check("existing key opens office",use.ok and not game.world.access_by_id("office-entry").closed)
	check("office key consumed",game.inventory.instances[key].location=="consumed")
	duty_state(false)
	game.presentation.tick(0)
	await shot("runtime-open")
	for pair in [["duty",Vector2(3990,550)],["office",Vector2(4450,550)]]:
		player.position=pair[1]
		game.room_visibility.tick(0,true)
		var cover=game.room_visibility.covers.filter(func(c):return c.room.id==pair[0])[0]
		check(pair[0]+" entering hides roof",not cover.visible)
	player.position=Vector2(4230,880)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	for room in ["duty","office"]:
		var cover=game.room_visibility.covers.filter(func(c):return c.room.id==room)[0]
		check(room+" exiting restores opaque roof",cover.visible and cover.modulate.a==1)
	for id in ["duty-sign","office-entry-sign"]:
		var index: int=game.world.fixtures.find(game.world.fixtures.filter(func(f):return f.id==id)[0])
		check(id+" name plate visible outside",game.presentation.volumes.any(func(v):return v.kind=="fixture" and v.wall_index==index and v.visible))
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	editor.open_now(path)
	await frame()
	check("editor validates saved map",editor.document.validate().errors.is_empty())
	for room in ["duty","office"]:
		for state in ["open","closed"]:
			var id: String="doorway_"+room+"_"+state+"_v2"
			check("palette exposes "+id,editor.catalog.entries.any(func(v):return v.id==id))
	check("duty legacy open resolves new assembly",editor.canvas.definitions.doorway_duty_open_v1.door_presentation.door_art=="doorway_duty_open_v2")
	editor.canvas.zoom=.85
	editor.canvas.origin=editor.canvas.size/2-Vector2(4230,430)*editor.canvas.zoom
	editor.canvas.queue_redraw()
	var duty_index: int=editor.document.data.fixtures.find(editor.document.data.fixtures.filter(func(f):return f.id=="campus-duty")[0])
	var office_index: int=editor.document.data.access_doors.find(editor.document.data.access_doors.filter(func(g):return g.id=="office-entry")[0])
	editor.document.set_property({"group":"fixtures","index":duty_index},"asset_id","doorway_duty_closed_v2")
	await frame()
	await frame()
	check("editor closed duty state shown",editor.canvas.architecture_preview.doorways.by_id("fixture:campus-duty").closed)
	await shot("editor-closed")
	editor.document.undo()
	check("undo restores default open duty",editor.document.data.fixtures[duty_index].asset_id=="doorway_duty_open_v2")
	editor.document.set_property({"group":"access_doors","index":office_index},"initial_closed",false)
	await frame()
	await frame()
	check("editor office state follows gate",not editor.canvas.architecture_preview.doorways.by_id("office-entry").closed)
	await shot("editor-open")
	editor.document.undo()
	check("editor state previews leave no draft changes",not editor.document.dirty())
	check("QA never saves state simulation into map",FileAccess.get_sha256(path)==disk)
	var failed: Array=checks.keys().filter(func(label):return not checks[label])
	FileAccess.open(OUT+("checks-headless.json" if DisplayServer.get_name()=="headless" else "checks-native.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"administration_door_checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)
