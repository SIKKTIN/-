extends SceneTree
const OUT="res://docs/art/cafeteria-wall-style-v4/"
var checks={}
func _initialize():
	create_timer(90).timeout.connect(func():quit(124));call_deferred("run")
func raw(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func check(label: String,ok: bool):
	checks[label]=ok
	if not ok:print("FAIL: ",label)
func frame():
	await process_frame;await RenderingServer.frame_post_draw
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://cafeteria-wall-style-qa.cfg")
	root.size=Vector2i(1400,1000);root.content_scale_size=root.size
	var before=raw(OUT+"map-before.json");var after=raw(OUT+"map-after.json")
	var registration=raw(OUT+"registration.json")
	for key in before:
		if key!="fixtures":check("map field preserved "+str(key),before[key]==after[key])
	check("only windows repositioned",before.fixtures.filter(func(f):return f.id not in registration.changed_fixture_ids)==after.fixtures.filter(func(f):return f.id not in registration.changed_fixture_ids))
	var old_catalog=raw(OUT+"manifest-before.json");var catalog=raw(OUT+"manifest-after.json")
	check("other assets preserved",old_catalog.assets.filter(func(a):return a.id not in registration.changed_asset_ids)==catalog.assets.filter(func(a):return a.id not in registration.changed_asset_ids))
	for a in catalog.assets:
		if a.id not in registration.changed_asset_ids:continue
		check("no workshop stone in "+a.id,not a.assembly_patches.any(func(p):return str(p.get("texture_asset","")).begins_with("workshop")))
		var rim: Dictionary=a.assembly_patches.filter(func(p):return p.role=="blue_steel_coping")[0]
		check("same trim scale as south wall "+a.id,is_equal_approx(rim.destination[3],28.595/301*100))
	var game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.actors[0].position=Vector2(1480,2160);game.room_visibility.tick(0,true);game.presentation.tick(0)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="canteen")[0]
	check("inside roof hides",not cover.visible)
	game.map_camera.zoom=Vector2.ONE*.98;game.map_camera.center_on(Vector2(1500,2170));game.map_camera.force_update_scroll()
	await frame();await frame();var pixels: Image=root.get_texture().get_image()
	pixels.save_png(OUT+"runtime-interior.png")
	var transform: Transform2D=game.get_global_transform_with_canvas()
	for y in [1825,2425]:
		var blue=0
		for x in [1280,1720,1800]:
			var color:=pixels.get_pixelv(Vector2i(transform*Vector2(x,y)))
			if color.b>color.r and color.r<.65:blue+=1
		check("blue steel rendered along wall "+str(y),blue>=2)
	for id in ["cafeteria-entry","cafeteria-entry-east"]:
		var gate: Dictionary=game.world.access_by_id(id)
		var door=game.room_visibility.doorways.by_id(id)
		check("original door art bounds "+id,door.visual_rect==Rect2(gate.rect.get_center().x-90,1840,180,100))
		var p: Vector2=gate.rect.get_center()
		game.world.set_access_closed(id,false);game.room_visibility.doorways.tick(true)
		check("open door passes body "+id,game.world.motion_clear(p-Vector2(0,160),p+Vector2(0,130),game.actors[0],false,true))
		game.world.set_access_closed(id,true);game.room_visibility.doorways.tick(true)
		check("closed door blocks body "+id,not game.world.motion_clear(p-Vector2(0,160),p+Vector2(0,130),game.actors[0],false,true))
	game.actors[0].position=Vector2(1480,1640);game.room_visibility.tick(0,true);game.presentation.tick(0)
	check("exterior roof restores",cover.visible and cover.modulate.a==1)
	await frame();await frame();root.get_texture().get_image().save_png(OUT+"runtime-exterior.png")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame()
	editor.open_now("res://data/rooms/r04.json");await frame()
	check("map validates in editor",editor.document.validate().errors.is_empty())
	editor.canvas.zoom=.7;editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2150)*.7;editor.canvas.queue_redraw()
	await frame();await frame();root.get_texture().get_image().save_png(OUT+"editor.png")
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"\t"))
	print("Cafeteria wall style: ",checks.size()," checks; failures=",failed)
	quit(0 if failed.is_empty() else 1)
