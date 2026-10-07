extends SceneTree

var game
var checks := {}
var native := false

func _initialize() -> void:
	call_deferred("run")

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
	root.get_texture().get_image().save_png("res://docs/tests/p71-regression-"+label+".png")

func clock(minute: float) -> void:
	game.schedule.clock_elapsed = (minute-float(game.schedule.config.start_minutes))/1440*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	game.workshop.update_gate()
	game.routines.tick()

func walk(seconds: float) -> void:
	for step in range(ceili(seconds*30)):
		game.elapsed += 1.0/30
		game.routines.tick()
		game.orders.tick(1.0/30)

func run() -> void:
	native = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	checks.initial_planner_pauses = paused and game.routine_panel.panel.visible
	checks.defaults_in_fresh_game = game.routines.plans == [["work","meal","work","free","free"],["work","meal","work","free","free"],["work","meal","work","free","free"]]
	checks.npc_cards_read_only = game.cards[1].disabled and game.cards[2].disabled
	checks.npc_planner_read_only = range(5).all(func(slot): return game.routine_panel.selectors[slot][1].disabled and game.routine_panel.selectors[slot][2].disabled)
	await shot("default-planner",Vector2(1050,650))
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	var original_records: Dictionary = game.routines.records.duplicate(true)
	for id in [1,2]:
		game.select_actor(id)
		checks["cannot_select_"+str(id)] = game.selected_actor_id==0
		game.select_at(game.actors[id].position)
		checks["cannot_body_select_"+str(id)] = game.selected_actor_id==0
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_1+id
		game._unhandled_input(key)
		checks["cannot_shortcut_select_"+str(id)] = game.selected_actor_id==0
		checks["cannot_manual_command_"+str(id)] = not game.command_move(id,game.actors[id].home)
		checks["cannot_manual_order_"+str(id)] = not game.orders.issue(id,game.actors[id].home)
		checks["cannot_skill_"+str(id)] = not game.skills.toggle(id)
		game.routines.take_control(id)
		checks["cannot_cancel_auto_"+str(id)] = not game.routines.manual.has(id) and game.routines.records.has(id)
		checks["cannot_manual_meal_"+str(id)] = not game.routines.start_meal(id)
		var item: String = game.inventory.add_ground("scrap",game.actors[id].position)
		checks["cannot_npc_pickup_"+str(id)] = not game.inventory.try_pickup(id,item).ok
	checks.auto_orders_preserved = game.routines.records == original_records and game.orders.active.has(1) and game.orders.active.has(2)
	game.selected_actor_id = 1
	game.mobile_controls.direction = Vector2.RIGHT
	var npc_position: Vector2 = game.actors[1].position
	game.mobile_controls.tick(0.1)
	checks.joystick_rejects_invalid_selection = game.actors[1].position==npc_position and game.mobile_controls.direction==Vector2.ZERO
	game.selected_actor_id = 0
	game.mobile_controls.direction = Vector2.RIGHT
	game.mobile_controls.tick(0.1)
	checks.player_can_take_control = game.routines.manual.has(0) and not game.routines.manual.has(1) and game.mobile_controls.controlled_id==0
	game.mobile_controls.cancel_input()
	game.routines.resume(0)
	checks.player_can_resume_default = not game.routines.manual.has(0) and game.orders.active.has(0)
	var changed: Array = game.routines.plans.duplicate(true)
	changed[1][0] = "idle"
	checks.npc_plan_change_rejected = not game.routines.apply_today(changed)
	changed = game.routines.plans.duplicate(true)
	changed[0][0] = "rest"
	checks.player_plan_edit_allowed = game.routines.apply_today(changed) and game.routines.plans[1][0]=="work"
	game.routines.apply_today(game.routines.default_plans())
	walk(20)
	clock(480)
	checks.auto_work_arrived = game.routines.is_working(1) and game.routines.is_working(2)
	var begin: float = game.schedule.clock_elapsed
	var finish: float = begin+game.schedule.day_seconds*60/1440.0
	var credit: Dictionary = game.attributes.accrue(begin,finish,game.attributes.behaviors())
	game.routines.accrue_work(begin,finish,game.routines.working_ids(),credit)
	checks.npc_work_pays = game.routines.work_earned[1]>0 and game.routines.work_earned[2]>0 and game.inventory.wallet>0
	await shot("automatic-work",Vector2(1230,580))
	clock(720)
	walk(25)
	checks.auto_meal_arrived = game.routines.is_eating(1) and game.routines.is_eating(2)
	var fullness: float = game.attributes.values[1].fullness
	var lunch_begin: float = game.schedule.clock_elapsed
	game.attributes.accrue(lunch_begin,lunch_begin+game.schedule.day_seconds*30/1440.0,game.attributes.behaviors())
	checks.npc_lunch_restores_fullness = game.attributes.values[1].fullness>fullness
	await shot("automatic-lunch",Vector2(1250,1750))
	clock(840)
	walk(20)
	checks.auto_afternoon_work = game.routines.is_working(1) and game.routines.is_working(2)
	clock(1080)
	walk(20)
	checks.auto_free_activity = [1,2].all(func(id): return game.routines.records[id].kind=="free" and not game.orders.active.has(id))
	clock(1200)
	walk(25)
	checks.auto_return_dorm = [1,2].all(func(id): return game.schedule.in_dormitory(id) and game.actors[id].position.distance_to(game.actors[id].home)<12)
	clock(1440)
	walk(5)
	checks.auto_sleep = game.schedule.is_sleeping(1) and game.schedule.is_sleeping(2)
	clock(1880)
	checks.new_morning_planner = paused and game.routine_panel.panel.visible
	checks.new_day_defaults = game.routines.day==2 and game.routines.plans==game.routines.default_plans() and game.routines.manual.is_empty()
	game.routine_panel.close()
	game.capture_actor(1)
	checks.npc_custody_suspends_routine = game.actors[1].confined and not game.routines.records.has(1)
	clock(2041)
	checks.npc_custody_release_resumes = not game.actors[1].confined and not game.routines.manual.has(1) and game.routines.records.has(1)
	game.load_room("r01",["lockpick","chat","strong"],70)
	game.routine_panel.close()
	checks.map_without_facilities_falls_back = game.routines.plans[1][0]=="rest" and game.routines.plans[1][1]=="rest"
	game.load_room("r04",["lockpick","chat","backpack"],70)
	game.routine_panel.close()
	clock(1200)
	game.routines.take_control(0)
	game.orders.stop(0)
	game.actors[0].position = game.skills.door_point(game.actors[0])
	checks.player_can_open_gate_alone_at_night = game.skills.toggle(0)
	game.skills.tick(5)
	checks.night_gate_open = game.world.door_open
	checks.player_can_order_escape = game.command_move(0,game.world.exit_area.get_center())
	walk(10)
	game._update_ui()
	checks.player_alone_wins = game.phase=="complete" and not game.actors[1].escaped and not game.actors[2].escaped
	checks.victory_keeps_player_selection = game.selected_actor_id==0
	checks.goal_one_person = game.fullscreen_ui.goal.text=="逃脱 1/1" and game.schedule.result_label.text.contains("逃出 1 / 1")
	await shot("single-victory",Vector2(2500,850))
	game.reset_round(["lockpick","chat","backpack"],70)
	game.routine_panel.close()
	checks.reset_restores_defaults = game.routines.plans==game.routines.default_plans() and game.selected_actor_id==0 and not game.actors[0].escaped
	game.finish_timeout()
	checks.deadline_failure = game.phase=="failed" and game.schedule.result_label.text.contains("逃出 0 / 1")
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"native":native,"checks":checks,"failed":failed,"passed":checks.size()-failed.size(),"total":checks.size()}
	FileAccess.open("res://docs/tests/p71-regression-single-player-%s.json" % ["native" if native else "headless"],FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
