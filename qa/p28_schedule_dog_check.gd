extends SceneTree

var game
var checks := {}
var observations := {}

func _initialize() -> void:
	call_deferred("run")

func restart(room: String = "r01") -> void:
	game.load_room(room,["chat","lockpick","strong"],28)
	game.set_process(false)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for room in ["r01","r02","r03","r04"]:
		restart(room)
		var limit: float = game.schedule.limit_seconds
		checks[room+"_correct_budget"] = limit == {"r01":180.0,"r02":180.0,"r03":240.0,"r04":300.0}[room]
		checks[room+"_reset_clock"] = game.elapsed == 0 and game.schedule.clock_minutes() == 960 and not game.schedule.result_panel.visible
		game.elapsed = limit/3-0.001
		game.schedule.tick(false)
		checks[room+"_before_yard"] = not game.schedule.dog_active() and game.presentation.lighting.period == "day"
		game.elapsed = limit/3
		game.schedule.tick(false)
		checks[room+"_yard_boundary"] = game.schedule.dog_active() and game.schedule.stage_index == 1
		game.elapsed = limit*2/3
		game.schedule.tick(false)
		checks[room+"_lights_out_boundary"] = game.schedule.stage_index == 2 and game.presentation.lighting.period == "night" and game.guard.view_radius() == 155
		game.elapsed = limit-0.05
		game.command_move(0,game.actors[0].position+Vector2(0,30))
		game._process(0.2)
		checks[room+"_deadline_clamped"] = game.elapsed == limit and game.phase == "failed" and game.schedule.result_panel.visible
		checks[room+"_terminal_input"] = game.orders.active.is_empty() and game.skills.actions.is_empty() and not game.command_move(0,game.actors[0].position) and game.world_input_blocked()
		var before: float = game.elapsed
		game._process(1)
		checks[room+"_terminal_clock_frozen"] = game.elapsed == before
	restart("r04")
	game.schedule.toggle()
	game._process(1)
	checks.schedule_does_not_pause = game.elapsed == 1 and game.schedule.panel.visible and game.world_input_blocked()
	game.schedule.close()
	var merchant: String = game.trade.merchants.keys()[0]
	var coords: Array = game.trade.merchants[merchant].position
	game.actors[0].position = Vector2(coords[0]+35,coords[1])
	game.presentation.interaction.refresh()
	checks.trade_prompt_before_open = game.presentation.interaction.targets.any(func(t): return t.kind == "trade")
	game.shop_panel.open(merchant)
	checks.shop_layer_and_prompt = game.shop_panel.panel.visible and game.shop_panel.panel.z_index > game.presentation.interaction.extras["trade:"+merchant].z_index and game.presentation.interaction.targets.is_empty() and game.shop_panel.blocker.visible
	game.presentation.interaction._activate_extra("trade:"+merchant)
	game._process(1)
	checks.shop_does_not_pause = game.elapsed == 2 and game.shop_panel.panel.visible
	var id: String = game.inventory.add_ground("scrap",game.actors[0].position)
	checks.pickup_fixture_valid = game.inventory.try_pickup(0,id).ok
	game.inventory_panel._select(0)
	game.shop_panel.transact(false)
	checks.sale_while_modal = game.inventory.wallet == 3 and not game.inventory.items(0).has(id)
	game.inventory.wallet = 20
	game.shop_panel.offers.select(0)
	game.shop_panel.transact(true)
	checks.purchase_while_modal = game.inventory.items(0).size() == 1 and game.inventory.wallet == 11
	game.elapsed = 299.98
	game._process(0.1)
	checks.timeout_closes_shop = not game.shop_panel.panel.visible and not game.shop_panel.blocker.visible and game.schedule.result_panel.visible
	restart()
	game.elapsed = 179.99
	for actor in game.actors:
		actor.escaped = true
	game.on_actor_escaped(2)
	game._process(1)
	checks.success_before_deadline = game.phase == "complete" and game.elapsed == 179.99 and game.schedule.result_panel.visible
	for remaining_seconds in [0.02,0.005]:
		restart()
		game.actors[0].escaped = true
		game.actors[1].escaped = true
		game.actors[2].position = Vector2(994,510)
		game.elapsed = 180-remaining_seconds
		game.command_move(2,Vector2(1040,510))
		game._process(0.1)
		checks["last_movement_success" if remaining_seconds > 0.01 else "too_late_movement_fails"] = game.phase == ("complete" if remaining_seconds > 0.01 else "failed") and game.elapsed == 180
	restart()
	checks.reset_restores_day = game.presentation.lighting.period == "day" and game.guard.view_radius() == 210 and game.dog.state == "resting"
	game.dog.tick(1)
	checks.resting_dog_inactive = game.dog.state == "resting" and game.dog.bark_count == 0 and not game.dog.moved_this_frame
	game.elapsed = 60
	game.schedule.tick(false)
	game.dog.position = Vector2(870,490)
	game.actors[0].position = Vector2(910,490)
	game.guard.position = Vector2(850,250)
	game.guard.facing = Vector2.UP
	game.dog.tick(0.01)
	game.guard.tick(0)
	checks.dog_confirms_and_alerts = game.dog.target_id == 0 and game.dog.bark_count == 1
	checks.guard_investigates_without_omniscience = game.guard.state == "searching" and game.guard.target_id == -1
	checks.guard_rejects_safe_room_alert = not game.guard.investigate(game.actors[1].home)
	var captured: int = game.captures
	for i in range(100):
		game.elapsed += 0.01
		game.dog.tick(0.01)
	checks.bark_cooldown = game.dog.bark_count == 1
	checks.dog_does_not_capture = game.captures == captured
	game.guard.position = Vector2(870,430)
	game.guard.facing = Vector2.DOWN
	game.guard.tick(0)
	checks.guard_requires_then_uses_real_sight = game.guard.state == "chasing" and game.guard.target_id == 0
	game.actors[0].position = game.actors[0].home
	game.dog.tick(0.01)
	checks.safe_room_loses_dog = game.dog.target_id == -1 and game.dog.state == "patrol" and game.dog.trails.is_empty()
	restart()
	game.elapsed = 60
	game.schedule.tick(false)
	game.dog.position = Vector2(665,490)
	game.actors[0].position = Vector2(850,400)
	game.dog.trails = [{"actor_id":0,"point":Vector2(665,470),"time":59.0}]
	game.dog.sample_timer = 999
	game.dog.tick(0)
	checks.scent_tracks_floor_not_hidden_actor = game.dog.state == "tracking" and game.dog.path_goal == Vector2(665,470) and game.dog.bark_count == 0
	game.elapsed = 70.01
	game.dog.tick(0)
	checks.scent_expires = game.dog.trails.is_empty() and game.dog.target_id == -1
	game.dog.position = Vector2(660,400)
	game.actors[0].position = Vector2(840,400)
	game.dog.tick(0)
	checks.wall_blocks_direct_confirmation = game.dog.bark_count == 0
	checks.dog_safe_zone_constraint = not game.dog.movement_allowed(game.actors[1].home)
	game.dog.position = Vector2(530,250)
	game.world.move_actor(game.dog,Vector2(-100,0))
	checks.dog_cannot_enter_safe_room = game.dog.position.x >= game.world.guard_zone.position.x+17
	restart("r04")
	game.elapsed = 100
	game.schedule.tick(false)
	var initial: Vector2 = game.dog.position
	var distance := 0.0
	var valid := true
	for i in range(900):
		game.elapsed += 1.0/30
		var before: Vector2 = game.dog.position
		game.dog.tick(1.0/30)
		distance += before.distance_to(game.dog.position)
		valid = valid and game.world.can_place_circle(game.dog.position,17,game.dog,false)
	checks.r04_dog_patrol_navigates_furniture = distance > 400 and valid
	observations.r04_patrol = {"distance":distance,"start":[initial.x,initial.y],"end":game.dog.snapshot(),"navigation_builds":game.world.navigation_builds}
	var before: Vector2 = game.dog.position
	game.phase = "failed"
	game.dog.tick(1)
	checks.dog_stops_at_end = game.dog.position == before and not game.dog.moved_this_frame
	var passed: bool = checks.values().all(func(c): return c)
	var report := {"passed":passed,"checks":checks,"observations":observations,"scope":"Deterministic logic integration; fixture positioning is explicit. No human or mobile playtest claim."}
	FileAccess.open("res://docs/tests/p28-schedule-dog-logic.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("P28_LOGIC passed=",passed," checks=",checks.size()," failed=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
