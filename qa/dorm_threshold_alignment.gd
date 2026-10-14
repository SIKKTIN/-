extends "res://qa/dorm_door_passage_v4.gd"

const ALIGN_OUT := "res://docs/art/dorm-threshold-alignment/"

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ALIGN_OUT))
	var baseline := OS.get_cmdline_user_args().has("--baseline")
	var stage := "before" if baseline else "after"
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://dorm-threshold-alignment-qa.cfg")
	root.size=Vector2i(1200,720); root.content_scale_size=root.size
	Engine.max_fps=60
	var saved := FileAccess.get_sha256("res://data/rooms/r04.json")
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frame(); await frame()
	game.set_process(false); game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	game.phase="playing"; game.selected_actor_id=0; game.schedule.close(); game.orders.clear()
	for actor in game.room_access.dorm_occupants():
		actor.set_process(false); actor.set_physics_process(false); actor.position=Vector2(2800,3000)
	game.guard.position=Vector2(2800,3000)
	var player=game.actors[0]
	game.world.update_dorm_doors(false,[],game.room_access.dorm_occupants())
	var results := {}
	for gate in game.world.dorm_gates():
		var id: String=gate.id
		var door=game.room_visibility.doorways.by_id(id)
		var rect: Rect2=door.visual_rect
		var cap: Rect2=door.transform*door.patch_parts[0].area
		var end_cap: Rect2=door.transform*door.patch_parts[1].area
		var threshold: Rect2=door.transform*door.patch_parts[2].area
		check(id+" threshold width",is_equal_approx(threshold.size.x,28.0 if baseline else 20.0))
		if not baseline:
			check(id+" central strip aligns with both end nodes",is_equal_approx(threshold.position.x,cap.position.x) and is_equal_approx(threshold.end.x,cap.end.x) and is_equal_approx(threshold.position.x,end_cap.position.x) and is_equal_approx(threshold.end.x,end_cap.end.x))
		gate.closed=false; game.world._changed(true)
		var clear_rows: Array=[]
		for y in range(ceili(rect.position.y),floori(rect.end.y)+1,2):
			if game.world.motion_clear(Vector2(rect.position.x-12,y),Vector2(rect.end.x+65,y),player,false,true): clear_rows.append(y)
		check(id+" usable passage",not clear_rows.is_empty())
		var y: float=clear_rows[clear_rows.size()/2]
		player.position=Vector2(rect.position.x-12,y)
		walk(KEY_D,rect.end.x+65)
		check(id+" actual controls exit",player.position.x>=rect.end.x+65)
		walk(KEY_A,rect.position.x-12)
		check(id+" actual controls reenter",player.position.x<=rect.position.x-12)
		gate.closed=true; game.world._changed(true)
		player.position=Vector2(rect.end.x+70,y); walk(KEY_A,rect.position.x-12)
		check(id+" closed door blocks movement",player.position.x>rect.end.x)
		results[id]={"clear_rows":clear_rows,"open_parts":gate.visual_solid_parts,"closed_parts":gate.closed_visual_solid_parts,"closed_patches":gate.door_closed_patches}
		gate.closed=false; game.world._changed(true)
	check("all five dorm doors checked",results.size()==5)
	if not baseline:
		var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ALIGN_OUT+"before-checks.json"))
		# Normalize integer/float JSON types before comparing nested geometry.
		check("passage and closed state identical to baseline",JSON.parse_string(JSON.stringify(results))==original.geometry)
	var door=game.room_visibility.doorways.by_id("dorm-0")
	var rect: Rect2=door.visual_rect
	player.position=Vector2(rect.position.x-80,rect.end.y-40)
	game.map_camera.following=false
	game.map_camera.zoom=Vector2(1.5,1.5)
	game.map_camera.center_on(rect.get_center()+Vector2(-65,0)); game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	game.presentation.interaction.hint.hide()
	await frame(); await frame()
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(ALIGN_OUT+stage+"-open.png")
	check("saved map unchanged",saved==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(ALIGN_OUT+stage+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"geometry":results},"\t"))
	print(JSON.stringify({"stage":stage,"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
