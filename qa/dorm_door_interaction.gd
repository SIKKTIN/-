extends SceneTree
const OUT := "res://docs/art/dorm-door-v1/"
var checks := {}
func dorm_passage_y(door) -> float:
	return door.visual_rect.get_center().y-preload("res://scripts/core/actor_footprint.gd").DOOR_BODY.get_center().y
func check(label: String, passed: bool) -> void: checks[label] = passed
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frame(); await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	root.size = Vector2i(1200,800); root.content_scale_size = root.size
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://dorm-manual-qa.cfg")
	var disk := FileAccess.get_sha256("res://data/rooms/r04.json")
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"heavy-registration.json"))
	check("original heavy RGBA preserved",FileAccess.get_sha256("res://art/architecture/dorm_door_v1/components-heavy-v2.png")==registration.sha256)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); await frame(); await frame()
	game.set_process(false); game.fullscreen_ui.set_process(false)
	game.phase = "playing"
	game.world.admission_filter = Callable()
	game.schedule.clock_elapsed = 0
	var player = game.actors[0]
	game.selected_actor_id = 0
	var occupants: Array = game.room_access.dorm_occupants()
	for index in occupants.size():
		occupants[index].set_process(false)
		occupants[index].set_physics_process(false)
		occupants[index].position = Vector2(2700+index*40,2800)
	var gates: Array = game.world.dorm_gates()
	check("all five dorm entrances are interactive",gates.size()==5 and gates.all(func(g):return g.get("manual_door",false)))
	for gate in gates:
		var id: String = gate.id
		var door = game.room_visibility.doorways.by_id(id)
		var y: float = dorm_passage_y(door)
		var inside := Vector2(door.visual_rect.position.x-65,y)
		var outside := Vector2(door.visual_rect.end.x+60,y)
		player.position = inside
		game.world.update_dorm_doors(false,[])
		check(id+" inside handle reachable",game.room_access.dorm_nearby(player,gate))
		check(id+" wide pocket aperture",door.visual_rect.size.y==200)
		check(id+" compact shared frame",door.closed_patches[-1].destination[3]==28)
		var result: Dictionary = game.room_access.toggle_dorm(0,id)
		check(id+" manual close",result.ok and gate.closed and door.closed)
		check(id+" close changes collision",not game.world.motion_clear(inside,outside,player,false,true))
		for index in range(30): game.world.update_dorm_doors(false,[])
		check(id+" automatic day tick keeps manual choice",gate.closed)
		check(id+" label offers opening",game.room_access.dorm_label(id)=="开门")
		player.position = outside
		game.world.update_dorm_doors(false,[outside])
		check(id+" nearby guard does not reset manual daytime state",gate.closed)
		check(id+" outside handle reachable when shut",game.room_access.dorm_nearby(player,gate))
		result = game.room_access.toggle_dorm(0,id)
		check(id+" open from outside",result.ok and not gate.closed and not door.closed)
		check(id+" open changes collision",game.world.motion_clear(inside,outside,player,false,true))
		player.position = Vector2(door.visual_rect.get_center().x,y)
		result = game.room_access.toggle_dorm(0,id)
		check(id+" cannot close through player",not result.ok and not gate.closed and str(result.reason).contains("门口有人"))
		player.position = outside
		game.guard.position = Vector2(door.visual_rect.get_center().x,y)
		result = game.room_access.toggle_dorm(0,id)
		check(id+" cannot close through NPC",not result.ok and not gate.closed)
		game.guard.position = Vector2(3000,2800)
		player.position = outside+Vector2(300,0)
		result = game.room_access.toggle_dorm(0,id)
		check(id+" stale far-away action rejected",not result.ok and not gate.closed)
		player.position = outside
		game.fullscreen_ui.menu.show()
		result = game.room_access.toggle_dorm(0,id)
		check(id+" menu blocks interaction",not result.ok and not gate.closed)
		game.fullscreen_ui.menu.hide()
	# Close and reopen the real door through the actual E / mobile hint routes.
	var gate: Dictionary = gates[0]
	var door = game.room_visibility.doorways.by_id(gate.id)
	player.position = Vector2(door.visual_rect.position.x-65,dorm_passage_y(door))
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	var interaction = game.presentation.interaction
	interaction.refresh()
	var target: Array = interaction.targets.filter(func(t):return t.kind=="dorm_door" and t.id==gate.id)
	check("door enters interaction targets",target.size()==1)
	interaction.mobile_target_key = interaction._target_key(target[0])
	interaction.refresh()
	check("hint offers close action",interaction.mobile_label()=="关门")
	var event := InputEventKey.new(); event.keycode=KEY_E; event.pressed=true
	if DisplayServer.get_name()=="headless": interaction.activate_nearest()
	else: Input.parse_input_event(event); await frame()
	check("E closes actual door",gate.closed)
	check("hint switches to open",interaction.mobile_label()=="开门")
	interaction.hint.pressed.emit()
	check("click mobile hint opens actual door",not gate.closed)
	# Night locking uses the same gate state and cannot be bypassed by this action.
	player.position = Vector2(3000,3000)
	game.schedule.clock_elapsed = (24*60+30-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.stage_index = 0
	game.world.update_dorm_doors(true,[],game.room_access.dorm_occupants())
	check("night locks all five doors",gates.all(func(g):return g.closed))
	player.position = Vector2(door.visual_rect.end.x+60,dorm_passage_y(door))
	var result: Dictionary = game.room_access.toggle_dorm(0,str(gate.id))
	check("night refuses manual unlock",not result.ok and gate.closed and str(result.reason).contains("夜间"))
	check("night hint explains lock",game.room_access.dorm_label(str(gate.id))=="夜间锁定")
	game.world.update_dorm_doors(true,[player.position],game.room_access.dorm_occupants())
	check("guard key still opens night door",not gate.closed)
	game.world.update_dorm_doors(true,[],game.room_access.dorm_occupants())
	check("door relocks when guard leaves",gate.closed)
	game.schedule.clock_elapsed = 0
	game.schedule.stage_index = 1
	game.world.update_dorm_doors(false,[],game.room_access.dorm_occupants())
	check("morning clears manual override and opens",gates.all(func(g):return not g.closed and not g.has("manual_closed")))
	player.position = Vector2(door.visual_rect.position.x-65,dorm_passage_y(door))
	game.map_camera.following=false; game.map_camera.zoom=Vector2.ONE*1.35
	game.map_camera.position=door.visual_rect.get_center()+Vector2(-180,-20)-Vector2(root.size)/game.map_camera.zoom/2
	game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	interaction.refresh(); interaction.mobile_target_key=interaction._target_key(interaction.targets.filter(func(t):return t.kind=="dorm_door" and t.id==gate.id)[0]); interaction.refresh()
	await shot("heavy-interaction-open")
	game.room_access.toggle_dorm(0,str(gate.id)); interaction.refresh()
	await shot("heavy-interaction-closed")
	player.position = Vector2(door.visual_rect.end.x+60,dorm_passage_y(door))
	game.room_visibility.tick(0,true); game.presentation.tick(0); interaction.refresh()
	var cover = game.room_visibility.covers.filter(func(c):return c.room.id=="dorm-0")[0]
	var exposed: Rect2 = game.world.dorm_closure_rect(gate).intersection(cover.roof)
	check("roof masks inward frame and retains exterior aperture",cover.panels.any(func(p):return p.has_point(Vector2(door.visual_rect.position.x-6,door.visual_rect.get_center().y))) and not cover.panels.any(func(p):return p.has_point(door.visual_rect.get_center())))
	await shot("heavy-interaction-exterior")
	check("map draft and saved floor untouched",disk==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"interaction-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
