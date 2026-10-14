extends SceneTree
const OUT := "res://docs/art/reading-room-restoration/"
var checks := {}
func check(label: String, passed: bool):checks[label]=passed
func _initialize():call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String):
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://reading-room-qa.cfg")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var saved:=FileAccess.get_sha256("res://data/rooms/r04.json")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"before.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"after.json"))
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration.json"))
	for key in before:
		if key not in ["fixtures","visibility_rooms","zones","lamps","floor_regions"]:check("unchanged "+key,before[key]==after[key])
	check("unrelated furniture unchanged except recorded concurrent workshop edit",before.fixtures.filter(func(f):return not str(f.id).begins_with("dorm-north-") and f.id not in registration.concurrent_fixture_changes)==after.fixtures.filter(func(f):return not str(f.id).begins_with("reading-") and f.id not in registration.concurrent_fixture_changes))
	check("other room visibility untouched",before.visibility_rooms.filter(func(r):return r.id!="dorm-north")==after.visibility_rooms.filter(func(r):return r.id!="reading-room"))
	check("bed toilet and wash furniture removed",not after.fixtures.any(func(f):return f.id in registration.removed_fixture_ids))
	var old_entry: Dictionary=before.fixtures.filter(func(f):return f.id=="dorm-north-entry")[0].duplicate(true)
	old_entry.id="reading-room-entry"
	check("door geometry preserved",old_entry==after.fixtures.filter(func(f):return f.id=="reading-room-entry")[0])
	var polish_before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"polish-before.json"))
	var polish_after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"polish-after.json"))
	check("final polish preserves all furniture including concurrent edits",polish_before.fixtures==polish_after.fixtures)
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	var assets=preload("res://scripts/presentation/prop_catalog.gd").assets()
	for entry in registration.assets:
		var id: String="reading_"+str(entry.key)+"_v1"
		check(id+" original PNG unchanged",FileAccess.get_sha256("res://"+entry.path)==entry.sha256)
		check(id+" editor registered",catalog.entries.any(func(e):return e.id==id))
		var texture=preload("res://scripts/presentation/world_texture.gd").load_asset(assets[id])
		check(id+" transparent texture loaded",texture!=null and texture.get_image().get_pixel(0,0).a<.05)
	var doc=preload("res://scripts/editor/map_document.gd").new()
	check("editor map opens",doc.open_file("res://data/rooms/r04.json"))
	check("map validates",doc.validate().errors.is_empty())
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.world.admission_filter=Callable()
	var player=game.actors[0]
	var entrance:=Vector2(740,460)
	player.position=Vector2(550,446);game.room_visibility.tick(0,true)
	check("reading room active",game.room_visibility.active_id=="reading-room")
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="reading-room")[0]
	check("inside roof hidden",not cover.visible)
	var furniture: Array=game.world.fixtures.filter(func(f):return str(f.id).begins_with("reading-") and f.get("blocks_movement",false))
	check("six physical furnishings",furniture.size()==6)
	for f in furniture:
		check(str(f.id)+" blocks footprint",not game.world.can_place_circle(f.rect.get_center(),game.ACTOR_RADIUS,null,false))
		for peer in furniture:
			if f.id<peer.id:check(str(f.id)+" separated from "+str(peer.id),not f.rect.intersects(peer.rect))
	for target in [Vector2(690,460),Vector2(550,446),Vector2(220,440),Vector2(400,310),Vector2(400,502)]:
		check("approach clear "+str(target),game.world.can_place_circle(target,game.ACTOR_RADIUS,player,false))
		check("entrance reaches "+str(target),not game.world.find_path(entrance,target,player,false,true).is_empty())
	for pair in [["reading-bookcase-left",Vector2(254,292)],["reading-bookcase-right",Vector2(418,292)],["reading-return",Vector2(620,390)]]:
		player.position=pair[1];game.room_visibility.tick(0,true)
		check(str(pair[0])+" approach reachable",not game.world.find_path(entrance,pair[1],player,false,true).is_empty())
		check(str(pair[0])+" search reachable",game.looting.reason(pair[0]).is_empty())
		check(str(pair[0])+" opens",game.looting.open(pair[0]))
		game.looting.tick(30)
		check(str(pair[0])+" contains clues",not game.looting.containers[pair[0]].ids.is_empty())
		game.looting.close()
	player.position=Vector2(550,446);game.room_visibility.tick(0,true)
	game.map_camera.center_on(Vector2(515,410));game.map_camera.force_update_scroll();game.presentation.tick(0)
	await shot("runtime-interior")
	game.presentation.lighting.set_period("night");await shot("runtime-night");game.presentation.lighting.set_period("day")
	player.position=Vector2(770,470);game.room_visibility.tick(0,true);game.presentation.tick(0)
	check("outside roof restored",cover.visible and cover.modulate.a==1)
	check("exit path clear",not game.world.find_path(Vector2(550,446),entrance,player,false,true).is_empty())
	await shot("runtime-exterior")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.canvas.zoom=.75;editor.canvas.origin=editor.canvas.size/2-Vector2(485,400)*.75;editor.canvas.queue_redraw()
	await shot("editor")
	check("saved map untouched by tests",saved==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)