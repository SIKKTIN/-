extends SceneTree
const OUT="res://docs/tests/camera-zoom-follow/"
var game
var checks={}
var metrics=[]
func _initialize():
	create_timer(90).timeout.connect(func():quit(124))
	call_deferred("run")
func check(label: String,ok: bool):
	checks[label]=ok
	if not ok:print("FAIL: ",label)
func frame():
	await process_frame;await RenderingServer.frame_post_draw
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://camera-zoom-qa.cfg")
	root.size=Vector2i(1200,800);root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide();game.orders.clear();game.skills.clear_all()
	root.grab_focus();await frame()
	var camera=game.map_camera;var player=game.actors[0]
	check("native window focused",root.has_focus())
	var saved_bounds: Rect2=game.world.bounds
	for size in [Vector2i(1200,800),Vector2i(960,540)]:
		root.size=size;root.content_scale_size=size;await frame()
		for scale in [.7,1.0,1.35,2.0]:
			var tag=str(size)+" zoom="+str(scale)
			camera.zoom=Vector2.ONE*scale;player.position=Vector2(2000,2200)
			camera.reset();await frame()
			var center: Vector2=camera.view_rect().size/2
			var screen: Vector2=game.get_global_transform_with_canvas()*player.position
			check("locate centers player "+tag,screen.distance_to(center)<.1)
			check("visible world span "+tag,camera.world_view_rect().size.is_equal_approx(Vector2(size)/scale))
			camera.center_on(Vector2(2300,2500));await frame()
			check("center_on zoom correct "+tag,(game.get_global_transform_with_canvas()*Vector2(2300,2500)).distance_to(center)<.1)
			camera.locate_selected()
			camera.manual_pan_by(Vector2(80,40));var position_before: Vector2=camera.position
			camera.tick(.1)
			check("manual pan pauses follow "+tag,not camera.following and camera.position==position_before)
			camera.locate_selected()
			var begin:=Vector2(400,300)
			check("pointer begins "+tag,camera.begin_pointer(-1,begin))
			position_before=camera.position;camera.move_pointer(begin-Vector2(60,30))
			check("drag tracks screen distance "+tag,((camera.position-position_before)*camera.zoom).distance_to(Vector2(60,30))<.1)
			camera.end_pointer(begin-Vector2(60,30))
			camera.locate_selected()
			for i in range(120):
				player.position+=Vector2(2,1);camera.tick(1.0/60)
			var moving_error: Vector2=player.position-camera.world_view_size()/2-camera.position
			check("moving follow lag remains bounded "+tag,moving_error.length()<15)
			for i in range(120):camera.tick(1.0/60)
			await frame()
			screen=game.get_global_transform_with_canvas()*player.position
			check("follow settles at center "+tag,screen.distance_to(center)<.1 and camera.following)
			camera.pan_by(Vector2(99999,99999))
			check("bottom right boundary at zoom "+tag,camera.world_view_rect().end.distance_to(saved_bounds.end)<.1)
			camera.pan_by(Vector2(-99999,-99999))
			check("top left boundary at zoom "+tag,camera.position.distance_to(saved_bounds.position)<.1)
			game.world.bounds=Rect2(100,200,300,220);camera.reset();await frame()
			check("small map centered without panning "+tag,not camera.enabled_for_room and camera.world_view_rect().get_center().distance_to(game.world.bounds.get_center())<.1)
			game.world.bounds=saved_bounds
			metrics.append({"viewport":[size.x,size.y],"zoom":scale,"settled_player_screen":[screen.x,screen.y],"moving_lag":[moving_error.x,moving_error.y]})
	root.size=Vector2i(1200,800);root.content_scale_size=root.size;await frame()
	camera.zoom=Vector2.ONE*1.35;player.position=Vector2(1390,3320);camera.reset()
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	camera.position=player.position-camera.view_rect().size/2;camera.force_update_scroll();await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"before.png")
	camera.locate_selected();await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"after.png")
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks,"metrics":metrics},"\t"))
	print("Camera zoom follow: ",checks.size()," checks; failures=",failed)
	quit(0 if failed.is_empty() else 1)
