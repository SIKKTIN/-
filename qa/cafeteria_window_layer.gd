extends SceneTree
const OUT="res://docs/art/cafeteria-window-layer-v1/"
var checks={}
func _initialize():
	create_timer(90).timeout.connect(func():quit(124));call_deferred("run")
func frame():
	await process_frame;await RenderingServer.frame_post_draw
func check(label: String,ok: bool):
	checks[label]=ok
	if not ok:print("FAIL: ",label)
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var baseline="before" in OS.get_cmdline_user_args()
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://cafeteria-window-layer-qa.cfg")
	root.size=Vector2i(1400,1000);root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.actors[0].position=Vector2(1480,2160);game.room_visibility.tick(0,true);game.presentation.tick(0)
	game.map_camera.zoom=Vector2.ONE*.98;game.map_camera.center_on(Vector2(1500,2170));game.map_camera.force_update_scroll()
	await frame();await frame()
	var capture: Image=root.get_texture().get_image()
	capture.save_png(OUT+("before.png" if baseline else "after.png"))
	var windows: Array=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and game.world.fixtures[v.wall_index].id in ["canteen-redesign-window-0","canteen-redesign-window-1"])
	if not baseline:
		var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-before.json"))
		var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-after.json"))
		var normalized: Dictionary=after.duplicate(true)
		for f in normalized.fixtures:
			if f.id in ["canteen-redesign-window-0","canteen-redesign-window-1"]:
				f.erase("show_in_room");f.erase("in_front_of_wall_trim")
		check("only two window layer flags changed",normalized==before)
		var old: Image=Image.load_from_file(OUT+"before.png")
		var transform: Transform2D=game.get_global_transform_with_canvas()
		for w in windows:
			var fixture: Dictionary=game.world.fixtures[w.wall_index]
			check("window above retained wall edge "+fixture.id,w.z_index>game.room_visibility.wall_edges.z_index)
			check("window visible inside "+fixture.id,w.visible)
			var changed=0
			for dy in [3,6,9]:
				for dx in [20,40,70,90]:
					var pixel:=Vector2i(transform*(w.display_rect.position+Vector2(dx,dy)))
					if capture.get_pixelv(pixel).to_html(false)!=old.get_pixelv(pixel).to_html(false):changed+=1
			check("formerly clipped upper glass restored "+fixture.id,changed>=8)
		game.actors[0].position=Vector2(1480,1640);game.room_visibility.tick(0,true);game.presentation.tick(0)
		for w in windows:check("window hidden outside "+game.world.fixtures[w.wall_index].id,not w.visible)
		await frame();await frame();root.get_texture().get_image().save_png(OUT+"exterior.png")
		game.actors[0].position=Vector2(1480,2160);game.room_visibility.tick(0,true);game.presentation.tick(0)
		for w in windows:check("window restores on reentry "+game.world.fixtures[w.wall_index].id,w.visible)
	game.queue_free();await frame()
	if not baseline:
		var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame()
		editor.open_now("res://data/rooms/r04.json");await frame()
		check("editor map validates",editor.document.validate().errors.is_empty())
		editor.canvas.zoom=.7;editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2150)*.7;editor.canvas.queue_redraw()
		await frame();await frame();root.get_texture().get_image().save_png(OUT+"editor.png")
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+("baseline-checks.json" if baseline else "checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"\t"))
	print("Cafeteria window layer: ",checks.size()," checks; failures=",failed)
	quit(0 if failed.is_empty() else 1)
