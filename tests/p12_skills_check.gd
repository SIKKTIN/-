extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var checks := {}
	var configs := {}
	for seed_value in range(300):
		game.reset_round([],seed_value)
		var config: Array = game.actors.map(func(a): return a.skill_id)
		configs["/".join(config)] = true
	checks.all_27_configurations_observed = configs.size() == 27
	checks.repeats_allowed = configs.has("chat/chat/chat") and configs.has("lockpick/lockpick/lockpick") and configs.has("strong/strong/strong")
	game.reset_round([],31415)
	var once: Array = game.actors.map(func(a): return a.skill_id)
	game.reset_round([],31415)
	checks.seed_reproduces = once == game.actors.map(func(a): return a.skill_id)
	game.reset_round(["chat","chat","chat"])
	checks.unwinnable_has_clear_hint = game.hint_label.text.contains("缺少开路技能") and not game.world.door_open
	game.reset_round(["lockpick","lockpick","strong"])
	game.actors[0].position = Vector2(440,370)
	game.actors[1].position = Vector2(440,415)
	checks.first_lock_starts = game.skills.toggle(0)
	game.select_actor(1)
	checks.switch_keeps_operator = game.skills.actions.has(0) and game.actors[0].action_state == "lockpicking"
	checks.second_lock_starts = game.skills.toggle(1)
	game.skills.tick(2.0)
	checks.two_operators_open_in_two_seconds = game.world.door_open and game.world.lock_progress == 1.0 and game.skills.actions.is_empty()
	game.reset_round(["lockpick","strong","chat"])
	game.actors[0].position = Vector2(440,395)
	game.skills.toggle(0)
	game.skills.tick(1.0)
	var partial: float = game.world.lock_progress
	game.actors[0].position += Vector2(-20,0)
	game.skills.tick(0.1)
	checks.leave_interrupts_but_keeps_progress = not game.skills.actions.has(0) and is_equal_approx(game.world.lock_progress,partial) and is_equal_approx(partial,0.25)
	game.actors[0].position = Vector2(440,395)
	game.skills.toggle(0)
	game.capture_actor(0)
	checks.capture_cancels_only_operation_keeps_progress = not game.skills.actions.has(0) and is_equal_approx(game.world.lock_progress,partial) and game.actors[0].skill_id == "lockpick"
	game.reset_round(["chat","lockpick","strong"])
	game.guard.position = Vector2(690,250)
	game.actors[0].position = Vector2(620,215)
	game.actors[1].position = Vector2(760,290)
	checks.chat_starts = game.skills.toggle(0)
	var before: Vector2 = game.guard.position
	game.select_actor(1)
	game.skills.tick(0.1)
	game.guard.tick(0.1)
	checks.chat_stops_and_faces = game.guard.state == "talking" and game.guard.position == before and game.guard.facing.dot(game.guard.position.direction_to(game.actors[0].position)) > 0.999
	checks.backside_partner_safe = game.guard.state == "talking" and game.skills.actions.has(0)
	game.actors[1].position = Vector2(635,250)
	game.guard.tick(0.01)
	checks.other_visible_immediate_chase = game.guard.state == "chasing" and game.guard.target_id == 1 and not game.skills.actions.has(0)
	checks.chasing_guard_rejects_chat = not game.skills.toggle(0)
	game.reset_round(["strong","chat","lockpick"])
	var box_before: Rect2 = game.world.crate
	game.command_move(0,game.actors[0].position + Vector2(20,0))
	game.orders.tick(0.1)
	game.orders.stop(0)
	checks.no_remote_push = game.world.crate == box_before
	checks.passive_has_no_active_action = not game.skills.toggle(0) and game.skills.actions.is_empty()
	game.actors[0].position = Vector2(447,610)
	game.command_move(0,Vector2(580,610))
	game.orders.tick(1.0)
	game.orders.stop(0)
	checks.strong_push_has_contact_and_speed_cap = game.world.crate.position.x > box_before.position.x and game.world.push_distance <= 85.001
	game.reset_round(["chat","strong","lockpick"])
	game.actors[0].position = Vector2(447,610)
	game.command_move(0,Vector2(580,610))
	game.orders.tick(1.0)
	game.orders.stop(0)
	checks.non_strong_cannot_push = game.world.crate == game.world.original_crate
	var passed := true
	for value in checks.values():
		passed = passed and bool(value)
	checks.passed = passed
	var file := FileAccess.open("res://docs/tests/p12-skills.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"\t"))
	file.close()
	print("P04_RESULT ",JSON.stringify(checks))
	quit(0 if passed else 1)
