extends "res://qa/p101_npc_responses.gd"

func _initialize():
	create_timer(60).timeout.connect(func():quit(124))
	call_deferred("run")

func joined(visual) -> bool:
	var head: Dictionary=visual.sprite_section(true)
	var body: Dictionary=visual.sprite_section(false)
	var h: Rect2=head.destination
	var b: Rect2=body.destination
	var hs: Rect2=head.source
	var bs: Rect2=body.source
	return h.has_area() and b.has_area() and h.merge(b).is_equal_approx(visual.destination) and hs.merge(bs).is_equal_approx(visual.source_region) and is_equal_approx(h.end.y,b.position.y) and is_equal_approx(hs.end.y,bs.position.y)

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p115-head.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	var main=game.actors[0]
	var visual=game.presentation.visuals[0]
	main.position=Vector2(690,1438.6)
	main.facing=Vector2.RIGHT
	game.guard.position=Vector2(740,1590)
	game.room_visibility.tick(1,true)
	game.map_camera.center_on(main.position+Vector2(-80,-90))
	game.presentation.tick(0)
	check("head_above_retained_wall",visual.head_overlay.z_index>game.room_visibility.wall_edges.z_index)
	check("body_still_uses_foot_depth",main.z_index==preload("res://scripts/presentation/world_depth.gd").for_y(main.position.y,game.world.bounds.end.y))
	check("idle_sections_join_without_overlap",joined(visual))
	var cached: Array=visual.walk_textures.duplicate()
	main.moved_this_frame=true
	for i in range(8):
		visual.walk_clock=(i+0.25)/visual.walk_fps
		main.facing=Vector2.LEFT if i%2==0 else Vector2.RIGHT
		visual.tick_visual(0)
		check("walk_sections_join_"+str(i),visual.walk_frame_index==i and joined(visual) and visual.texture==cached[i])
	check("head_inherits_body_visibility",visual.head_overlay.is_visible_in_tree())
	check("sun_and_flashlight_reach_head_layer",game.presentation.lighting.sun.range_z_max>=visual.head_overlay.z_index and game.presentation.lighting.guard_light.range_z_max>=visual.head_overlay.z_index)
	check("lamps_reach_head_layer",game.presentation.lighting.lamps.all(func(lamp):return lamp.range_z_max>=visual.head_overlay.z_index))
	var other=game.presentation.visuals[1]
	other.actor.position=Vector2(450,1810)
	other.tick_visual(0)
	check("hidden_room_character_has_no_floating_head",not other.head_overlay.is_visible_in_tree())
	main.escaped=true
	visual.tick_visual(0)
	check("escaped_character_has_no_floating_head",not visual.head_overlay.is_visible_in_tree())
	main.escaped=false
	visual.tick_visual(0,Rect2(5000,4000,50,50))
	check("offscreen_character_has_no_floating_head",not visual.head_overlay.is_visible_in_tree())
	main.moved_this_frame=false
	main.facing=Vector2.RIGHT
	game.presentation.tick(0)
	game._update_ui()
	if DisplayServer.get_name()!="headless":
		await frame()
		await frame()
		root.get_texture().get_image().save_png("res://docs/dev/p115/head-at-door.png")
		game.presentation.lighting.set_period("night")
		await frame()
		await frame()
		root.get_texture().get_image().save_png("res://docs/dev/p115/head-at-door-night.png")
	var failed: Array=checks.keys().filter(func(key):return not checks[key])
	FileAccess.open("res://docs/tests/p115-head-layer.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	quit(0 if failed.is_empty() else 1)
