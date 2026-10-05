extends SceneTree

var game
var checks := {}

func _initialize() -> void:
	call_deferred("run")

func reset_job() -> void:
	game.load_room("r04", ["chat", "lockpick", "backpack"], 39)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	var plan: Array = game.routines.plans.duplicate(true)
	for id in range(3):
		plan[id][0] = "work"
		plan[id][1] = "rest"
		plan[id][2] = "work"
	game.routines.apply_today(plan)

func arrive() -> void:
	for index in range(1200):
		game._process(1.0/60)
		if game.routines.working_ids().size() == 3:
			break

func minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	game._update_ui()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	reset_job()
	checks.rules = game.routines.work_duration() == 60 and game.routines.work_wage() == 4
	game.schedule.set_time_speed(1)
	game._process(0.01)
	checks.walking_not_paid = game.inventory.wallet == 0 and game.routines.work_minutes == [0.0,0.0,0.0]
	game.schedule.set_time_speed(0)
	arrive()
	checks.real_three_arrivals = game.routines.working_ids().size() == 3 and game.orders.active.is_empty()
	checks.progress_not_fake_at_clock_zero = game.inventory.wallet == 0 and game.routines.work_minutes == [0.0,0.0,0.0]
	game.schedule.set_time_speed(1)
	game._process(4)
	checks.partial_no_pay = game.inventory.wallet == 0 and game.routines.work_minutes.all(func(v): return is_equal_approx(v,19.2))
	checks.working_status = game.routines.status_for(0) == "工作中 32%"
	var progress: Array = game.routines.work_minutes.duplicate()
	game.routine_panel.open()
	game._process(20)
	checks.pause_freezes_progress = game.routines.work_minutes == progress and game.inventory.wallet == 0 and paused
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game._process(20)
	checks.zero_speed_freezes_work = game.routines.work_minutes == progress and game.inventory.wallet == 0
	game.select_actor(0)
	game.stop_selected()
	game.schedule.set_time_speed(1)
	game._process(4)
	checks.manual_not_earning = is_equal_approx(game.routines.work_minutes[0],19.2) and is_equal_approx(game.routines.work_minutes[1],38.4)
	game.routines.resume(0)
	var before: float = game.schedule.clock_elapsed
	game._process(4.5)
	checks.first_payout_independent = game.inventory.wallet == 8 and game.routines.work_rounds == [0,1,1]
	checks.payout_remainder = is_equal_approx(game.routines.work_minutes[0],40.8) and game.routines.work_minutes.slice(1).all(func(v): return is_zero_approx(v))
	checks.receipt_visible = game.routines.recent_wages[1].amount == 4 and game.elapsed < game.routines.recent_wages[1].until
	progress = game.routines.work_minutes.duplicate()
	game.routines.accrue_work(before,game.schedule.clock_elapsed,[0,1,1,2])
	checks.idempotent_interval = game.inventory.wallet == 8 and game.routines.work_minutes == progress
	game.routines.resume(1)
	game.routines.resume(1)
	game._process(0)
	checks.resume_not_paying = game.inventory.wallet == 8 and game.routines.work_minutes == progress
	game._process(30)
	checks.multiple_rounds = game.inventory.wallet == 36 and game.routines.work_rounds == [3,3,3] and game.routines.work_earned == [12,12,12]
	progress = game.routines.work_minutes.duplicate()
	var left: float = 720-game.schedule.clock_minutes()
	var expected: int = 36
	for v in progress:
		expected += floori((v+left+0.0000001)/60)*4
	game._process(left/1440*game.schedule.day_seconds+0.1)
	checks.shift_boundary_paid = game.inventory.wallet == expected and game.routines.slot == 1
	checks.noon_not_working = game.routines.working_ids().is_empty()
	progress = game.routines.work_minutes.duplicate()
	game._process(2)
	checks.non_labor_not_earning = game.routines.work_minutes == progress and game.inventory.wallet == expected
	game.schedule.set_time_speed(0)
	for index in range(1000):
		game._process(1.0/60)
	minute(840)
	arrive()
	checks.afternoon_keeps_partial = game.routines.work_minutes == progress and game.routines.working_ids().size() == 3
	game.schedule.set_time_speed(1)
	game._process(0.1)
	checks.afternoon_can_finish_old_round = game.inventory.wallet > expected
	minute(1080) # Salary is spendable during the merchant's evening shift.
	for index in range(120):
		game.trade.tick(1.0/60)
	var merchant: Dictionary = game.trade.merchants.values()[0]
	var item_id: String = merchant.stock.filter(func(id): return game.inventory.instances[id].definition_id == "door_key")[0]
	var price: int = game.inventory.definitions.door_key.sell_price
	var wallet: int = game.inventory.wallet
	# Position fixture for commerce: the money itself is earned above, not set.
	game.actors[0].position = Vector2(merchant.position[0],merchant.position[1])+Vector2(0,60)
	var result: Dictionary = game.trade.try_buy(0,merchant.id,item_id)
	checks.earned_money_buys_key = result.ok and game.inventory.owns(0,item_id) and game.inventory.wallet == wallet-price
	progress = game.routines.work_minutes.duplicate()
	wallet = game.inventory.wallet
	game.orders.clear()
	for actor in game.actors:
		actor.position = actor.home
	minute(1440)
	game.schedule.skip_night()
	checks.next_day_keeps_pay_and_partial = game.routines.day == 2 and paused and game.inventory.wallet == wallet and game.routines.work_minutes == progress
	game.reset_round(["chat","lockpick","backpack"],39)
	checks.restart_clears_job_and_money = game.inventory.wallet == 0 and game.routines.work_minutes == [0.0,0.0,0.0] and game.routines.work_rounds == [0,0,0] and game.routines.recent_wages.is_empty()
	# An isolated closed-route fixture, without teleporting to the job.
	game.routine_panel.close()
	game.actors[0].position = Vector2(2100,1000)
	var plan: Array = game.routines.plans.duplicate(true)
	plan[0][0] = "work"
	game.routines.apply_today(plan)
	game.schedule.set_time_speed(1)
	game._process(12.5)
	checks.blocked_not_earning = game.routines.records[0].status == "blocked" and game.routines.work_minutes == [0.0,0.0,0.0] and game.inventory.wallet == 0
	reset_job()
	arrive()
	game.routines.take_control(1)
	game.routines.take_control(2)
	game.actors[0].action_state = "chatting"
	game.schedule.set_time_speed(1)
	game._process(12.5)
	checks.skill_not_earning = game.routines.work_minutes == [0.0,0.0,0.0] and game.inventory.wallet == 0
	game.actors[0].action_state = "idle"
	game.capture_actor(0)
	game._process(12.5)
	checks.captured_not_earning = game.routines.work_minutes == [0.0,0.0,0.0] and game.inventory.wallet == 0
	reset_job()
	arrive()
	game.routines.take_control(1)
	game.routines.take_control(2)
	game.actors[0].escaped = true
	game.schedule.set_time_speed(1)
	game._process(12.5)
	checks.escaped_not_earning = game.inventory.wallet == 0 and game.routines.work_minutes == [0.0,0.0,0.0]
	game.phase = "failed"
	game.routines.accrue_work(0,100,[0,1,2])
	checks.terminal_not_earning = game.inventory.wallet == 0
	for room_id in ["r01","r02","r03"]:
		game.load_room(room_id,["chat","lockpick","strong"],39)
		game.routine_panel.close()
		game.routines.plans[0][0] = "work"
		game.routines.records[0] = {"kind":"work","goal":game.actors[0].home,"status":"arrived","retry":0}
		game.schedule.set_time_speed(1)
		game._process(12.5)
		checks[room_id+"_no_fake_job"] = game.routines.work_minutes == [0.0,0.0,0.0] and game.inventory.wallet == 0
	var passed: bool = checks.values().all(func(v): return v)
	FileAccess.open("res://docs/tests/p40-work-pay.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Real three-worker arrivals, full clock-interval payroll; isolated blocked/skill/capture and merchant-position fixtures. No fake wallet top-up."},"\t")+"\n")
	print("P40_PAY passed=",passed," failed=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
