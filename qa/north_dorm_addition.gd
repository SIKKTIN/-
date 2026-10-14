extends SceneTree
const OUT := "res://docs/art/north-dorm-addition/"
var checks := {}
func check(label: String, passed: bool): checks[label]=passed
func _initialize(): call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func shot(name: String):
	await frame(); await frame()
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://north-dorm-qa.cfg")
	root.size=Vector2i(1280,800); root.content_scale_size=root.size
	var saved:=FileAccess.get_sha256("res://data/rooms/r04.json")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"before.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"after.json"))
	for key in before:
		if key not in ["walls","architecture","fixtures","visibility_rooms","zones","lamps"]:check("unchanged "+key,before[key]==after[key])
	for key in ["fixtures","visibility_rooms","zones","lamps"]:
		check("preserved existing "+key,after[key].slice(0,before[key].size())==before[key])
	check("existing wall coordinates preserved outside junction",range(before.walls.size()).all(func(i):return i in [234,235] or before.walls[i]==after.walls[i]))
	var doc=preload("res://scripts/editor/map_document.gd").new()
	check("editor opens latest map",doc.open_file("res://data/rooms/r04.json"))
	check("map validation",doc.validate().errors.is_empty())
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); await frame()
	game.set_process(false); game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide(); game.world.admission_filter=Callable()
	var player=game.actors[0]
	var inside:=Vector2(430,460)
	var outside:=Vector2(740,460)
	player.position=inside
	game.room_visibility.tick(0,true)
	var furniture: Array=game.world.fixtures.filter(func(f):return str(f.id).begins_with("dorm-north-") and str(f.id)!="dorm-north-entry")
	check("five furnishings loaded",furniture.size()==5)
	for f in furniture:
		check(str(f.id)+" solid",not game.world.can_place_circle(f.rect.get_center(),game.ACTOR_RADIUS,null,false))
	check("interior free space",game.world.can_place_circle(inside,game.ACTOR_RADIUS,player,false))
	check("entrance full body clearance",game.world.can_place_circle(Vector2(690,460),game.ACTOR_RADIUS,player,false))
	check("route out",not game.world.find_path(inside,outside,player,false,true).is_empty())
	check("route in",not game.world.find_path(outside,inside,player,false,true).is_empty())
	check("upper right wall blocks",not game.world.can_place_circle(Vector2(690,270),game.ACTOR_RADIUS,player,false))
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="dorm-north")[0]
	check("roof hidden inside",not cover.visible)
	game.map_camera.center_on(Vector2(510,435));game.map_camera.force_update_scroll();game.presentation.tick(0)
	await shot("runtime-interior")
	player.position=Vector2(434,416);game.room_visibility.tick(0,true)
	check("locker accessible",game.looting.reason("dorm-north-locker").is_empty())
	check("locker searchable",game.looting.open("dorm-north-locker"))
	game.looting.close()
	player.position=Vector2(770,470);game.room_visibility.tick(0,true);game.presentation.tick(0)
	check("roof restored outside",cover.visible and cover.modulate.a==1)
	await shot("runtime-exterior")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame()
	editor.canvas.zoom=0.7;editor.canvas.origin=editor.canvas.size/2-Vector2(480,440)*0.7;editor.canvas.queue_redraw()
	await shot("editor")
	check("QA preserves saved map",saved==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)