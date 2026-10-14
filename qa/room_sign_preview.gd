extends SceneTree
const OUT:="res://docs/art/room-sign-size-v1/"
func _initialize() -> void:
	create_timer(45).timeout.connect(func():quit(124));call_deferred("run")
func frame() -> void:
	await process_frame;await RenderingServer.frame_post_draw
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://room-sign-size-preview.cfg")
	root.size=Vector2i(1200,720);root.content_scale_size=root.size;Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(OUT)
	var game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame();await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.guard.position=Vector2(2900,1500);game.dog.position=Vector2(2950,1500)
	game.actors[0].position=Vector2(1520,830);game.room_visibility.tick(0,true);game.presentation.tick(0)
	game.map_camera.zoom=Vector2(.83,.83)
	game.map_camera.position=Vector2(1380,640)-Vector2(root.size)/.83/2;game.map_camera.force_update_scroll()
	await frame();await frame()
	var report:Dictionary={}
	for volume in game.presentation.volumes:
		if volume.kind!="fixture":continue
		var f:Dictionary=game.world.fixtures[volume.wall_index]
		if f.id in ["chess-sign","campus-clinic-record-sign","reading-exterior-sign","clinic-exterior-sign"]:
			report[f.id]={"visible":volume.visible,"rect":str(volume.display_rect),"z":volume.z_index,"texture":str(game.world.art_textures[f.asset_id].get_size())}
	print("SIGN RENDER: ",JSON.stringify(report))
	var tag:="after" if OS.get_cmdline_user_args().has("--after") else "before"
	root.get_texture().get_image().save_png(OUT+tag+".png")
	FileAccess.open(OUT+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit()
