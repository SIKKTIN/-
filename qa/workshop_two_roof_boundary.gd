extends SceneTree
const OUT := "res://docs/tests/workshop-two-roof-boundary/"
const Geometry = preload("res://scripts/presentation/roof_geometry.gd")
var checks := {}
var game
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func check(label: String, value: bool) -> void:
	checks[label]=value
	if not value: print("FAILED: "+label)
func read(path: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))
func show_at(point: Vector2, name: String) -> void:
	game.actors[0].position=point
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	await frame()
	game.presentation.tick(0)
	await frame()
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-two-roof-boundary-qa.cfg")
	root.size=Vector2i(1600,900)
	root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before := read(OUT+"before-map.json")
	var after := read(path)
	var original: Dictionary=before.visibility_rooms.filter(func(r):return r.id=="workshop-two")[0]
	var changed: Dictionary=after.visibility_rooms.filter(func(r):return r.id=="workshop-two")[0]
	var intact := true
	for key in before:
		if key not in ["visibility_rooms","zones"] and before[key]!=after[key]:intact=false
	check("walls doors furnishings floor and rules preserved",intact)
	check("other room covers preserved",before.visibility_rooms.filter(func(r):return r.id!="workshop-two")==after.visibility_rooms.filter(func(r):return r.id!="workshop-two"))
	check("other zones preserved",before.zones.filter(func(r):return r.id!="workshop-two")==after.zones.filter(func(r):return r.id!="workshop-two"))
	var saved_style: Dictionary=changed.duplicate(true)
	saved_style.rect=original.rect
	check("only workshop visibility bounds changed",saved_style==original)
	var document=load("res://scripts/editor/map_document.gd").new()
	check("corrected map loads and validates",document.open_file(path) and document.validate().errors.is_empty())
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	for actor in game.actors:actor.immune_until=INF
	game.guard.position=Vector2(2000,2500)
	game.dog.position=Vector2(1900,2500)
	var room: Dictionary=game.room_visibility.rooms.filter(func(r):return r.id=="workshop-two")[0]
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="workshop-two")[0]
	var old_spec: Dictionary=original.duplicate(true)
	old_spec.area=Rect2(original.rect[0],original.rect[1],original.rect[2],original.rect[3])
	var old_plan: Dictionary=Geometry.plan(game.world,old_spec)
	check("reproduces old roof extending beyond front wall",old_plan.roof.end.y==1780)
	check("roof now ends at south wall coping",cover.roof.end.y==1620)
	check("roof still meets north and side walls",cover.roof==Rect2(2280,940,1500,680))
	check("room mask ends at actual south wall foot line",room.area.end.y==1720)
	check("roof panels never cover outside facade or path",cover.panels.all(func(p):return p.end.y<=1620))
	check("existing blue gray style and details retained",cover.style=="workshop_two" and cover.get_child_count()==3)
	for side in ["north","south","east"]:
		check("roof recognizes authored "+side+" doorway",cover.ports.any(func(p):return p.id=="fixture:campus-workshop-two-"+side and p.side==side))
	check("roof does not cover doorway openings",cover.cutouts.all(func(c):return not cover.panels.any(func(p):return p.has_point(c.get_center()))))
	var player=game.actors[0]
	for side in ["north","south"]:
		var points: Array=[Vector2(3210,900),Vector2(3210,1180)] if side=="north" else [Vector2(2610,1860),Vector2(2610,1660)]
		check(side+" whole body crossing remains clear",game.world.motion_clear(points[0],points[1],player,false,true) and game.world.motion_clear(points[1],points[0],player,false,true))
	game.map_camera.following=false
	game.map_camera.zoom=Vector2.ONE*.9
	game.map_camera.center_on(Vector2(3030,1390))
	game.map_camera.force_update_scroll()
	await show_at(Vector2(3030,1860),"runtime-roof-fixed")
	check("opaque roof outside building",cover.visible and cover.modulate.a==1)
	await show_at(Vector2(3030,1760),"runtime-front-path")
	check("exterior path no longer classified as room",game.room_visibility.room_at(player.position)=="")
	check("walking outside ordinary south wall does not reveal room",cover.visible and game.room_visibility.active_id!="workshop-two")
	await show_at(Vector2(3030,1430),"runtime-interior")
	check("roof hides inside",not cover.visible and game.room_visibility.active_id=="workshop-two")
	await show_at(Vector2(2610,1860),"runtime-exit")
	check("roof restored after exit",cover.visible and cover.modulate.a==1)
	var expected_roof: Rect2=cover.roof
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	editor.open_now(path)
	await frame()
	# The editor builds the same roof plan from its own preview world.
	var spec: Dictionary=changed.duplicate(true)
	spec.area=room.area
	var preview_plan: Dictionary=Geometry.plan(editor.canvas.architecture_preview.world,spec)
	check("editor and game use identical roof bounds",preview_plan.roof==expected_roof)
	check("editor recognizes relocated south roof boundary",preview_plan.ports.any(func(p):return p.id=="fixture:campus-workshop-two-south" and p.side=="south"))
	editor.canvas.zoom=.6
	editor.canvas.origin=editor.canvas.size/2-Vector2(3030,1390)*editor.canvas.zoom
	editor.canvas.queue_redraw()
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+"editor-layout.png")
	check("QA leaves saved map unchanged",FileAccess.get_sha256(path)==disk)
	var failed: Array=checks.keys().filter(func(label):return not checks[label])
	FileAccess.open(OUT+("checks-headless.json" if DisplayServer.get_name()=="headless" else "checks-native.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"previous_roof":str(old_plan.roof),"corrected_roof":str(preview_plan.roof)},"\t"))
	print(JSON.stringify({"workshop_two_roof_checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)
