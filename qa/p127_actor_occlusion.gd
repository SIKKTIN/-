extends "res://qa/p101_npc_responses.gd"

func _initialize():
	create_timer(60).timeout.connect(func():quit(124))
	call_deferred("run")

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p127-occlusion.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	var main=game.actors[0]
	var visual=game.presentation.visuals[0]
	main.position=Vector2(690,1438.6)
	main.facing=Vector2.RIGHT
	game.guard.position=Vector2(740,1590)
	game.room_visibility.tick(1,true)
	game.map_camera.center_on(main.position+Vector2(-80,-90))
	game.presentation.tick(0)
	check("complete_pose_inherits_body_depth",visual.z_as_relative and visual.z_index==0 and main.z_index==preload("res://scripts/presentation/world_depth.gd").for_y(main.position.y,game.world.bounds.end.y))
	check("no_character_has_independent_head_layer",game.presentation.visuals.all(func(v):return v.get_node_or_null("HeadOverlay")==null))
	check("whole_character_below_retained_wall",main.z_index+visual.z_index<game.room_visibility.wall_edges.z_index)
	check("idle_draws_complete_frame",visual.destination.has_area() and visual.source_region.has_area() and visual.body_bounds().is_equal_approx(visual.destination))
	var cached: Array=visual.walk_textures.duplicate()
	main.moved_this_frame=true
	for i in range(cached.size()):
		visual.walk_clock=(i+0.25)/visual.walk_fps
		main.facing=Vector2.LEFT if i%2==0 else Vector2.RIGHT
		visual.tick_visual(0)
		check("walk_complete_pose_"+str(i),visual.walk_frame_index==i and visual.texture==cached[i] and visual.destination.has_area() and visual.source_region.size==cached[i].get_size() and visual.get_child_count()==0)
	main.escaped=true
	visual.tick_visual(0)
	check("escaped_character_hidden_as_one_pose",not visual.visible)
	main.escaped=false
	visual.tick_visual(0,Rect2(5000,4000,50,50))
	check("offscreen_character_hidden_as_one_pose",not visual.visible)
	main.moved_this_frame=false
	main.facing=Vector2.RIGHT
	game.presentation.tick(0)
	game._update_ui()
	if DisplayServer.get_name()!="headless":
		game.fullscreen_ui.fps_badge.hide()
		await frame()
		await frame()
		root.get_texture().get_image().save_png("res://docs/dev/p127/character-at-door.png")
	var failed: Array=checks.keys().filter(func(key):return not checks[key])
	FileAccess.open("res://docs/tests/p127-actor-occlusion.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	quit(0 if failed.is_empty() else 1)
