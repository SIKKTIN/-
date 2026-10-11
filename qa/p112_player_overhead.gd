extends "res://qa/p101_npc_responses.gd"

const Library = preload("res://scripts/presentation/character_library.gd")
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
const OUT := "res://docs/art/player-overhead-v50/"

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await frame()
	await frame()
	root.get_texture().get_image().save_png(OUT+label+".png")

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p112-overhead.cfg")
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
	main.position=Vector2(365,1480)
	game.guard.position=Vector2(730,1640)
	game.room_visibility.tick(1,true)
	game.map_camera.center_on(main.position)
	check("only_main_player_assigned_new_appearance",game.room_config.character_appearances=={"actor:0":"player_overhead_v50"})
	check("main_uses_approved_overhead_appearance",visual.appearance_definition.appearance_id=="player_overhead_v50")
	check("all_other_people_keep_legacy_direction_handling",game.presentation.visuals.filter(func(v):return v.actor!=main).all(func(v):return v.directional_sets.is_empty()))
	check("ground_and_door_collision_source_unchanged",FileAccess.get_sha256("res://scripts/core/actor_footprint.gd")=="000605f13e2e1b419c6669a3c7bacb7e99ac3438ee1a0080f097a92b0dd3cec8")
	var asset: Dictionary=Library.all().player_overhead_v50
	for name in asset.directional_variants:
		var spec: Dictionary=asset.directional_variants[name]
		check(name+"_original_RGBA_bytes_preserved",FileAccess.get_sha256(spec.texture)==spec.sha256)
		var image:=Image.load_from_file(spec.texture)
		check(name+"_actual_transparent_background",image!=null and image.detect_alpha()!=Image.ALPHA_NONE and image.get_pixel(0,0).a==0)
	var npc_before: Array=game.presentation.visuals.filter(func(v):return v.actor!=main).map(func(v):return [v.definition.texture,v.walk_fps,v.walk_frames.size()])
	var cache_before: int=WorldTexture.cache.size()
	var frame_audit: Dictionary={}
	for entry in [["down",Vector2.DOWN],["up",Vector2.UP],["right",Vector2.RIGHT],["left",Vector2.LEFT]]:
		var direction: String=entry[0]
		main.facing=entry[1]
		main.moved_this_frame=false
		visual.tick_visual(0)
		var source: String="right" if direction=="left" else direction
		var motion: Dictionary=Library.motion("player_overhead_v50",source)
		check(direction+"_idle_matches_correct_direction",visual.current_direction==source and visual.texture==motion.idle and visual.frame_name=="idle")
		check(direction+"_mirror_is_only_for_left",visual.flip_h==(direction=="left"))
		game.presentation.tick(0)
		game._update_ui()
		await capture("runtime-"+direction)
		main.moved_this_frame=true
		visual.walk_clock=0
		var visited: Dictionary={}
		var stable_feet:=true
		var native_textures:=true
		var heights: Array[float]=[]
		for i in range(16):
			visual.tick_visual(0.1)
			visited[visual.walk_frame_index]=true
			stable_feet=stable_feet and absf(visual.destination.end.y)<1
			native_textures=native_textures and visual.texture==motion.walk[visual.walk_frame_index]
			heights.append(visual.destination.size.y)
		check(direction+"_full_eight_frame_loop",visited.size()==8 and not visited.has(-1) and is_equal_approx(visual.walk_fps,10))
		check(direction+"_all_frames_use_registered_cropped_texture",native_textures)
		check(direction+"_feet_do_not_jump",stable_feet)
		check(direction+"_projected_height_stays_in_current_human_range",heights.min()>85 and heights.max()<106 and heights.max()-heights.min()<8)
		frame_audit[direction]={"frames":visited.keys(),"min_height":heights.min(),"max_height":heights.max()}
	main.facing=Vector2.RIGHT
	visual.walk_clock=.35
	visual.tick_visual(0)
	var phase_before: float=visual.walk_clock
	main.facing=Vector2.UP
	visual.tick_visual(0)
	check("turn_preserves_gait_phase",is_equal_approx(visual.walk_clock,phase_before) and visual.walk_frame_index==3)
	visual.refresh_appearance()
	check("refresh_does_not_reset_direction_or_gait",visual.current_direction=="up" and is_equal_approx(visual.walk_clock,phase_before))
	for i in range(100):
		main.facing=[Vector2.LEFT,Vector2.UP,Vector2.RIGHT,Vector2.DOWN][i%4]
		visual.tick_visual(.01)
	check("turning_reuses_preloaded_texture_cache",WorldTexture.cache.size()==cache_before)
	var npc_after: Array=game.presentation.visuals.filter(func(v):return v.actor!=main).map(func(v):return [v.definition.texture,v.walk_fps,v.walk_frames.size()])
	check("NPC_appearances_and_frame_rates_unchanged",npc_before==npc_after)
	main.moved_this_frame=false
	main.facing=Vector2.DOWN
	main.position=game.routines._target(0,"work")
	game.guard.position=main.position+Vector2(100,80)
	game.room_visibility.tick(1,true)
	game.map_camera.center_on(main.position)
	game.presentation.tick(0)
	game._update_ui()
	await capture("runtime-workshop")
	var failed: Array=checks.keys().filter(func(key):return not checks[key])
	FileAccess.open("res://docs/tests/p112-overhead.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"frame_audit":frame_audit},"\t"))
	print("Overhead player: ",checks.size()-failed.size()," passed, ",failed.size()," failed")
	quit(0 if failed.is_empty() else 1)
