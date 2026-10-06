extends SceneTree

var game
var checks := {}
var native := false
var width := 1200

func _initialize() -> void:
	call_deferred("run")

func minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	game.presentation.tick(0)

func fresh() -> void:
	game.load_room("r04",["chat","lockpick","backpack"],52)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.orders.clear()

func frame() -> void:
	await process_frame
	if native: await RenderingServer.frame_post_draw

func shot(label: String, center: Vector2) -> void:
	if not native: return
	game.map_camera.center_on(center)
	game.map_camera.following = false
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p62-access-%d-%s.png" % [width,label])

func run() -> void:
	native = DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): width = int(args[0])
	root.content_scale_size = Vector2i(width,720 if width == 1200 else 540)
	root.size = root.content_scale_size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	fresh()
	checks.map_larger = game.world.bounds.size == Vector2(2800,2200)
	checks.all_new_art_loaded = ["cafeteria_gate_closed_v23","cafeteria_gate_open_v23","prison_notice_board","wash_basin","access_reader","solitary_bed","solitary_door_closed_v23","solitary_door_open_v23"].all(func(id): return game.world.art_textures.has(id))
	checks.map_lamps_authoritative = game.presentation.lighting.lamp_specs == game.room_config.lamps
	checks.new_lamps_in_bounds = game.room_config.lamps.all(func(spec): return game.world.bounds.has_point(Vector2(spec.position[0],spec.position[1])))
	checks.old_notice_preserved = game.presentation.asset_definitions.has("notice_board") and game.presentation.asset_definitions.has("prison_notice_board")
	var doc = load("res://scripts/editor/map_document.gd").new()
	doc.open_file("res://data/rooms/r04.json")
	var validation: Dictionary = doc.validate()
	checks.map_valid = validation.errors.is_empty()
	checks.route_work = range(3).all(func(id): return not game.world.find_path(game.actors[id].home,Vector2(game.room_config.routine_points.work[id][0],game.room_config.routine_points.work[id][1]),game.actors[id],false).is_empty())
	checks.route_free = range(3).all(func(id): return not game.world.find_path(game.actors[id].home,Vector2(game.room_config.routine_points.free[id][0],game.room_config.routine_points.free[id][1]),game.actors[id],false).is_empty())
	checks.patrol_closed_rooms = game.world.patrol.all(func(point): return game.world.can_place_circle(point,17,game.guard,false) and not game.world.find_path(game.world.guard_start,point,game.guard,false).is_empty())
	checks.day_no_arrest = not game.guard.curfew_alert()
	minute(719.99)
	checks.before_noon_locked = game.world.access_by_id("cafeteria-entry").closed
	var from := Vector2(1010,1100)
	var to := Vector2(1010,1300)
	checks.closed_gate_blocks_route = game.world.find_path(from,to,game.actors[0],false).is_empty()
	checks.closed_gate_blocks_movement = not game.world.motion_clear(from,to,game.actors[0])
	var revision: int = game.world.obstacle_revision
	game.room_access.tick()
	checks.no_rebuild_unchanged_gate = revision == game.world.obstacle_revision
	await shot("canteen-closed",Vector2(1270,1420))
	minute(720)
	checks.noon_opens = not game.world.access_by_id("cafeteria-entry").closed
	checks.noon_path_opens = not game.world.find_path(from,to,game.actors[0],false).is_empty()
	checks.meal_routes = range(3).all(func(id): return not game.world.find_path(game.actors[id].home,Vector2(game.room_config.routine_points.meal[id][0],game.room_config.routine_points.meal[id][1]),game.actors[id],false).is_empty())
	game.routines.tick()
	for id in range(3):
		game.routines.manual.erase(id)
		game.routines._start(id,"meal")
	for step in range(1200):
		game.elapsed += 1.0/60.0
		game.orders.tick(1.0/60.0)
		game.routines.tick()
	checks.meal_actual_arrival = range(3).all(func(id): return game.routines.is_eating(id))
	await shot("canteen-open",Vector2(1380,1660))
	minute(839.99)
	checks.before_two_open = not game.world.access_by_id("cafeteria-entry").closed
	game.guard.position = Vector2(1200,1600)
	game.dog.position = Vector2(1100,1600)
	minute(840)
	checks.npcs_not_trapped = game.guard.position.y < 1200 and game.dog.position.y < 1200
	checks.two_closes = game.world.access_by_id("cafeteria-entry").closed
	checks.closing_evacuates = game.actors.all(func(actor): return not Rect2(720,1200,1304,1000).has_point(actor.position) and game.world.can_place_circle(actor.position,17,actor,true))
	checks.closing_cancels_orders = game.orders.active.is_empty()
	minute(2160)
	checks.next_day_noon_reopens = not game.world.access_by_id("cafeteria-entry").closed
	fresh()
	minute(780)
	for id in range(3): game.capture_actor(id)
	checks.three_held = game.room_access.held.size() == 3
	checks.held_physical_rooms = range(3).all(func(id): return game.actors[id].confined and game.actors[id].confinement_rect.has_point(game.actors[id].position) and game.world.can_place_circle(game.actors[id].position,17,game.actors[id],true))
	checks.no_same_spawn = game.actors[0].position.distance_to(game.actors[1].position) > 100 and game.actors[1].position.distance_to(game.actors[2].position) > 100
	checks.cannot_walk_out = not game.command_move(0,Vector2(400,1430))
	checks.cannot_self_pick = not game.skills.toggle(1)
	checks.custody_label = "禁闭" in game.routines.status_for(0)
	checks.dog_ignores_custody = not game.dog._valid_actor(0)
	minute(899.99)
	checks.no_early_release = game.room_access.held.size() == 3
	minute(900)
	checks.two_hour_release = game.room_access.held.is_empty() and game.actors.all(func(actor): return not actor.confined)
	checks.release_positions_clear = game.actors.all(func(actor): return game.world.can_place_circle(actor.position,17,actor,true))
	fresh()
	minute(900)
	game.capture_actor(0)
	game.actors[1].position = Vector2(400,1430)
	checks.rescue_target = game.skills.door_id(game.actors[1]) == "solitary-0"
	checks.start_rescue = game.skills.toggle(1)
	game.skills.tick(2)
	checks.partial_rescue_progress = game.world.access_by_id("solitary-0").progress > 0 and game.room_access.is_held(0)
	game.select_actor(2)
	checks.switch_keeps_rescue = game.skills.actions.has(1)
	await shot("confinement",Vector2(350,1500))
	game.skills.tick(3)
	checks.rescue_releases = not game.actors[0].confined and not game.room_access.is_held(0)
	checks.rescue_not_main_gate = not game.world.door_open
	checks.released_cell_clear = game.world.can_place_circle(game.actors[0].position,17,game.actors[0],true)
	checks.rescue_action_finishes = not game.skills.actions.has(1)
	game.capture_actor(0)
	checks.recapture_locks_again = game.world.access_by_id("solitary-0").closed and game.world.access_by_id("solitary-0").progress == 0
	game.reset_round(["chat","lockpick","backpack"],52)
	game.routine_panel.close()
	checks.restart_clears_custody = game.room_access.held.is_empty() and game.actors.all(func(actor): return not actor.confined)
	for room in ["r01","r02","r03"]:
		game.load_room(room,["chat","lockpick","backpack"],52)
		game.routine_panel.close()
		game.capture_actor(0)
		checks[room+"_legacy_capture"] = game.world.access_doors.is_empty() and game.actors[0].position == game.actors[0].home and not game.actors[0].confined
	fresh()
	minute(1380)
	game.capture_actor(0)
	minute(1440)
	checks.confinement_night_lit = game.presentation.lighting.lamps.any(func(light): return light.enabled and light.position.distance_to(game.actors[0].position) < 220)
	await shot("confinement-night",Vector2(350,1300))
	checks.midnight_keeps_custody = game.room_access.is_held(0) and game.actors[0].confined
	game.guard.position = game.schedule.inspection_point(0)
	game.prison_alert.check_rollcall()
	checks.registered_custody_not_missing = not game.prison_alert.active
	checks.custody_blocks_skip_night = not game.schedule.can_skip_night()
	minute(1499.99)
	checks.overnight_not_early = game.room_access.is_held(0)
	minute(1500)
	checks.overnight_two_hours_release = not game.room_access.is_held(0)
	fresh()
	minute(900)
	game.capture_actor(0)
	game.actors[1].position = Vector2(400,1430)
	var key: String = game.inventory.add_ground("door_key",game.actors[1].position)
	checks.key_pickup = game.inventory.try_pickup(1,key).ok
	checks.key_rescue = game.inventory.try_use(1,key).ok and not game.actors[0].confined and not game.world.door_open
	game.capture_actor(2)
	game.actors[1].position = Vector2(400,2150)
	var tool: String = game.inventory.add_ground("lock_tool",game.actors[1].position)
	checks.tool_pickup = game.inventory.try_pickup(1,tool).ok
	checks.tool_rescue_start = game.inventory.try_use(1,tool).ok
	game.skills.tick(7)
	checks.tool_rescue_finish = not game.actors[2].confined and not game.world.door_open
	fresh()
	checks.editor_lists_rule_objects = doc.entries().filter(func(ref): return ref.group == "access_doors").size() == 4 and doc.entries().filter(func(ref): return ref.group == "confinement").size() == 3
	var ref := {"group":"access_doors","index":0}
	var original: Rect2 = doc.geometry(ref)
	doc.begin()
	doc.set_geometry(ref,Rect2(original.position+Vector2(20,0),original.size))
	doc.commit()
	checks.gate_visual_moves_with_rule = doc.data.fixtures.filter(func(f): return f.get("access_id","") == "cafeteria-entry")[0].rect[0] == original.position.x+20
	doc.undo()
	checks.gate_move_undo = doc.geometry(ref) == original and doc.data.cafeteria.entrance[0] == original.position.x
	game.load_room("r04",["chat","chat","lockpick"],52)
	game.routine_panel.close()
	minute(780)
	game.actors[0].position = Vector2(2090,685)
	game.actors[1].position = Vector2(2090,980)
	game.actors[2].position = Vector2(2090,850)
	checks.gate_still_guarded = game.gate_watch.blocking()
	checks.day_gate_chat_one = game.skills.toggle(0)
	checks.day_gate_chat_two = game.skills.toggle(1)
	checks.two_chats_clear_gate = not game.gate_watch.blocking()
	checks.main_lockpick_still_works = game.skills.toggle(2)
	game.skills.tick(5)
	checks.main_gate_opens = game.world.door_open
	checks.exit_with_chat_cover = game.command_move(2,game.world.exit_area.get_center())
	for step in range(700):
		game.elapsed += 1.0/60.0
		game.orders.tick(1.0/60.0)
	checks.first_escape_under_cover = game.actors[2].escaped
	minute(1200)
	checks.night_gate_no_day_watch = not game.gate_watch.blocking()
	for id in range(2): checks["exit_order_"+str(id)] = game.command_move(id,Vector2(2840,810+80*id))
	for step in range(900):
		game.elapsed += 1.0/60.0
		game.orders.tick(1.0/60.0)
	checks.all_escape_complete = game.phase == "complete" and game.actors.all(func(a): return a.escaped)
	await shot("escape",Vector2(2640,850))
	var file := FileAccess.open("res://docs/tests/p62-access-access-%s-%d.json" % ["native" if native else "headless",width],FileAccess.WRITE)
	var passed: bool = checks.values().all(func(v): return v == true)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"validation":validation,"snapshot":game.room_access.snapshot()},"\t"))
	print("P62_ACCESS passed=",passed," count=",checks.size()," failed=",checks.keys().filter(func(k): return not checks[k]))
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
