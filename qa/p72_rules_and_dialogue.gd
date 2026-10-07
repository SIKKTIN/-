extends SceneTree

var game
var checks := {}
var report := {}

func _initialize() -> void:
	call_deferred("run")

func check(label: String, ok: bool) -> void:
	checks[label] = ok
	print(label+": "+str(ok))

func clock(minute: float) -> void:
	game.schedule.clock_elapsed = (minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.workshop.update_gate()
	game.routines.tick()

func reset(skills: Array = ["lockpick","chat","backpack"]) -> void:
	game.reset_round(skills,72)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)

func labor() -> void:
	reset()
	clock(600)
	for actor in game.actors:
		actor.position = game.routines._target(actor.actor_id,"work")
		game.routines.resume(actor.actor_id)
	game.orders.clear()
	game.workshop.tick(0)

func approach(target: Dictionary) -> bool:
	for offset in [Vector2(70,0),Vector2(-70,0),Vector2(0,70),Vector2(0,-70),Vector2(50,50),Vector2(-50,-50)]:
		var point: Vector2 = target.node.position+offset
		if game.world.can_place_circle(point,17,game.actors[0],true) and game.world.line_clear(point,target.node.position):
			game.actors[0].position = point
			return true
	return false

func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.presentation.tick(0)
	game.fullscreen_ui.refresh()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p72-"+label+".png")

func alarm() -> void:
	clock(1500)
	game.orders.clear()
	game.actors[0].position = Vector2(1600,1040)
	game.guard.position = game.schedule.inspection_point(0)
	game.prison_alert.check_rollcall()

func run() -> void:
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	reset()
	game.actors[0].position = Vector2(1600,1040)
	game.mobile_controls.direction = Vector2.RIGHT
	var origin: Vector2 = game.actors[0].position
	game.mobile_controls.tick(0.1)
	var wake_distance: float = origin.distance_to(game.actors[0].position)
	check("wake_uses_normal_speed",absf(wake_distance-26)<0.1)
	game.mobile_controls.cancel_input()
	clock(1080)
	game.actors[0].position = origin
	game.mobile_controls.direction = Vector2.RIGHT
	game.mobile_controls.tick(0.1)
	check("wake_matches_other_daytime_speed",absf(origin.distance_to(game.actors[0].position)-wake_distance)<0.1)
	reset()
	game.schedule.set_time_speed(1)
	for step in range(165): game._process(0.05)
	check("normal_pace_arrives_before_0800",game.schedule.clock_minutes()<480 and game.actors.all(func(a): return game.workshop.area.grow(-17).has_point(a.position)))
	check("prework_does_not_pay",game.inventory.wallet==0 and game.routines.working_ids().is_empty())
	game._process(0.1)
	check("0800_still_locks",game.world.access_by_id("workshop-entry").closed and game.captures==0)
	labor()
	for step in range(3):
		game.capture_actor(1)
		game.room_access.release(1)
	check("npc_custody_not_player_failure",game.phase=="playing" and game.confinement_counts==[0,3,0])
	game.capture_actor(0)
	check("first_custody_playing",game.phase=="playing" and game.confinement_counts[0]==1)
	game.capture_actor(0)
	check("held_actor_not_counted_twice",game.confinement_counts[0]==1)
	game.room_access.release(0)
	game.capture_actor(0)
	check("second_custody_playing",game.phase=="playing" and game.confinement_counts[0]==2)
	game.room_access.release(0)
	clock(1880)
	game.routine_panel.close()
	check("custody_count_persists_across_days",game.confinement_counts[0]==2)
	game.capture_actor(0)
	check("third_custody_immediate_failure",game.phase=="failed" and game.confinement_counts[0]==3)
	check("failure_reason_is_custody",game.failure_reason.contains("第三次") and game.schedule.result_label.text.contains("第三次") and not game.schedule.result_label.text.contains("时间耗尽"))
	check("failure_closes_actions_and_dialogue",game.orders.active.is_empty() and game.skills.actions.is_empty() and not game.dialogue.panel.visible)
	var failed_clock: float = game.schedule.clock_elapsed
	game._process(2)
	check("failure_stops_simulation",game.schedule.clock_elapsed==failed_clock)
	await shot("third-custody-failure")
	reset()
	check("reset_clears_counts_and_failure",game.phase=="playing" and game.confinement_counts==[0,0,0] and game.failure_reason.is_empty())
	game.load_room("r01",["lockpick","chat","backpack"],72)
	game.routine_panel.close()
	for step in range(3): game.capture_actor(0)
	check("fallback_capture_is_not_confinement",game.phase=="playing" and game.confinement_counts[0]==0)
	game.load_room("r04",["lockpick","chat","backpack"],72)
	labor()
	var ids: Array = game.dialogue.targets().map(func(t): return t.id)
	check("registry_includes_every_live_human",ids.size()==game.actors.size()-1+1+game.gate_watch.guards.size()+1+game.trade.actors.size())
	check("registry_excludes_player_and_dog",not ids.has("prisoner:0") and not ids.any(func(id): return str(id).contains("dog")))
	var roles := {}
	for id in ids:
		var target: Dictionary = game.dialogue.find_target(id)
		var reachable := approach(target)
		var opened: bool = reachable and game.dialogue.open(id)
		check("chat_"+str(id),opened and game.dialogue.speaker.text.contains(str(target.name)))
		if opened:
			roles[target.role] = true
			check("chat_not_paused_"+str(id),not paused)
			game.dialogue.rules()
			check("role_rule_text_"+str(id),not game.dialogue.body.text.is_empty())
			if target.role == "prisoner":
				var npc = target.node
				check("chat_preserves_npc_work_"+str(id),game.routines.is_working(npc.actor_id) and not game.routines.manual.has(npc.actor_id))
			game.dialogue.close()
	check("all_normal_roles_have_dialogue",roles.has("prisoner") and roles.has("merchant") and roles.has("patrol") and roles.has("gate") and roles.has("overseer"))
	labor()
	var target: Dictionary = game.dialogue.find_target("prisoner:1")
	approach(target)
	game.presentation.interaction.refresh()
	check("chat_interaction_registered_for_lockpick_player",game.presentation.interaction._mobile_targets.any(func(t): return t.kind=="talk" and t.id=="prisoner:1"))
	game.presentation.interaction.mobile_target_key = "0:talk:prisoner:1"
	game.presentation.interaction.activate_mobile()
	check("interaction_opens_real_dialogue",game.dialogue.panel.visible and game.actors[0].action_state=="chatting")
	var before: float = game.schedule.clock_elapsed
	game.schedule.set_time_speed(1)
	game._process(0.1)
	check("chat_keeps_world_time_running",game.schedule.clock_elapsed>before and not paused)
	for dims in [Vector2i(1200,720),Vector2i(960,540)]:
		root.size = dims
		root.content_scale_size = dims
		game.fullscreen_ui.layout()
		game.dialogue.layout()
		var rect: Rect2 = game.dialogue.panel.get_global_rect()
		check("dialogue_safe_layout_"+str(dims.x),game.fullscreen_ui.safe_area().encloses(rect) and not rect.intersects(game.cards[0].get_global_rect()) and not rect.intersects(game.mobile_controls.pad.get_global_rect()) and not rect.intersects(game.fullscreen_ui.action_button.get_global_rect()))
		await shot("dialogue-"+str(dims.x))
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	game.fullscreen_ui._unhandled_input(escape)
	check("escape_closes_conversation",not game.dialogue.panel.visible and game.actors[0].action_state=="idle")
	game.dialogue.open("prisoner:1")
	game.actors[0].position = Vector2(1600,1040)
	game.dialogue.tick()
	check("out_of_range_closes_dialogue",not game.dialogue.panel.visible)
	reset()
	clock(1080)
	game.schedule.set_time_speed(1)
	target = game.dialogue.find_target("prisoner:1")
	approach(target)
	game.dialogue.open(str(target.id))
	var npc_before: Vector2 = target.node.position
	game.orders.tick(0.3)
	check("walking_prisoner_waits_during_chat",target.node.position==npc_before and game.orders.active.has(1))
	game.dialogue.close()
	game.orders.tick(0.3)
	check("prisoner_resumes_existing_route",target.node.position.distance_to(npc_before)>1 and not game.routines.manual.has(1))
	reset()
	clock(1080)
	game.schedule.set_time_speed(1)
	target = game.dialogue.targets().filter(func(t): return t.role=="merchant")[0]
	target.node.update_schedule()
	target.node.goal = Vector2(1700,610)
	approach(target)
	game.dialogue.open(str(target.id))
	var merchant_before: Vector2 = target.node.position
	target.node.tick(0.3)
	check("walking_merchant_waits_during_chat",target.node.position==merchant_before)
	game.dialogue.close()
	target.node.tick(0.3)
	check("merchant_resumes_after_chat",target.node.position.distance_to(merchant_before)>1)
	reset()
	clock(1080)
	target = game.dialogue.targets().filter(func(t): return t.role=="merchant")[0]
	target.node.update_schedule()
	approach(target)
	game.dialogue.open(str(target.id))
	game.dialogue.special()
	check("merchant_chat_can_open_purchase_panel",game.shop_panel.panel.visible and not game.dialogue.panel.visible)
	game.shop_panel.close()
	for skill in ["lockpick","chat","strong","backpack"]:
		reset([skill,"chat","backpack"])
		clock(1080)
		target = game.dialogue.find_target("prisoner:1")
		approach(target)
		check("ordinary_chat_available_with_"+skill,game.dialogue.open(str(target.id)))
		game.dialogue.close()
	labor()
	game.actors[0].position = Vector2(700,690)
	game.guard.position = Vector2(780,690)
	check("wall_blocks_chat",not game.dialogue.open("guard:patrol"))
	labor()
	game.actors[0].position = Vector2(1600,1040)
	game.guard.position = Vector2(1600,1110)
	game.dialogue.open("guard:patrol")
	check("ordinary_chat_does_not_distract",game.guard.state!="talking" and game.dialogue.special_button.disabled)
	game.guard.tick(0)
	check("chat_cannot_disable_arrest",game.guard.state=="chasing" and game.guard.target_id==0)
	game.guard.position = game.actors[0].position+Vector2(0,35)
	game.guard.tick(0)
	check("capture_closes_dialogue",game.actors[0].confined and not game.dialogue.panel.visible)
	reset(["chat","lockpick","backpack"])
	clock(1080)
	var gate = game.gate_watch.guards[0]
	target = game.dialogue.find_target("guard:"+gate.guard_id)
	approach(target)
	game.dialogue.open(str(target.id))
	game.dialogue.special()
	check("chat_skill_distracts_selected_gate",game.skills.chat_guard(game.actors[0])==gate and gate.state=="talking" and not gate.blocking_gate() and not game.dialogue.panel.visible)
	game.skills.cancel(0)
	check("ending_distraction_restores_gate",gate.chat_partner_id==-1 and gate.blocking_gate())
	labor()
	game.actors[0].skill_id = "chat"
	target = game.dialogue.find_target("guard:overseer")
	approach(target)
	game.dialogue.open(str(target.id))
	game.dialogue.special()
	check("overseer_can_be_selected_for_distraction",game.skills.chat_guard(game.actors[0])==game.workshop.overseer and game.workshop.overseer.state=="talking")
	game.skills.cancel(0)
	reset()
	alarm()
	check("night_absence_raises_alarm",game.prison_alert.active and game.prison_alert.reinforcements.size()==2)
	var extras: Array = game.prison_alert.reinforcements.map(func(g): return g.get_instance_id())
	var extra_target: Dictionary = game.dialogue.targets().filter(func(t): return t.role=="reinforcement")[0]
	approach(extra_target)
	check("reinforcement_has_basic_chat",game.dialogue.open(str(extra_target.id)))
	check("alert_refuses_distraction",game.dialogue.special_button.disabled)
	game.dialogue.close()
	clock(1879)
	check("alarm_persists_until_wake",game.prison_alert.active)
	game.guard.state = "chasing"
	game.guard.target_id = 0
	game.workshop.wanted[0] = true
	clock(1880)
	game.presentation.lighting.tick()
	check("dawn_clears_global_alert",not game.prison_alert.active and game.prison_alert.missing_ids.is_empty())
	check("dawn_withdraws_reinforcements",game.prison_alert.reinforcements.is_empty() and extras.all(func(id): return not is_instance_id_valid(id)))
	check("dawn_clears_chases_and_wanted",game.guard.state=="patrol" and game.guard.target_id==-1 and game.gate_watch.guards.all(func(g): return g.target_id==-1) and game.workshop.wanted.is_empty())
	check("dawn_paused_planner_still_opens",paused and game.routine_panel.panel.visible)
	check("dawn_clears_warning_lights",game.presentation.lighting.search_lights.is_empty())
	check("dawn_preserves_normal_day_guard_mode",not game.guard.global_alert() and not game.guard.alert_mode() and game.guard.half_fov()==PI)
	game.routine_panel.close()
	clock(2040)
	check("labor_alert_returns_without_global_alarm",game.guard.alert_mode() and not game.prison_alert.active)
	game.guard.position = game.schedule.inspection_point(0)
	clock(2940)
	game.orders.clear()
	game.actors[0].position = Vector2(1600,1040)
	game.prison_alert.check_rollcall()
	check("new_night_can_raise_new_alarm",game.prison_alert.active and game.prison_alert.reinforcements.size()==2)
	clock(3320)
	check("next_dawn_clears_again",not game.prison_alert.active and game.prison_alert.reinforcements.is_empty())
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game.fullscreen_ui.layout()
	await shot("dawn-alarm-cleared")
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	report = {"checks":checks,"failed":failed,"total":checks.size(),"wake_move_distance":wake_distance,"map_sha256":FileAccess.get_sha256("res://data/rooms/r04.json")}
	FileAccess.open("res://docs/tests/p72-rules-dialogue-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
