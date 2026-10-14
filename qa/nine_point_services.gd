extends SceneTree
var game
var checks := {}
func _initialize():
	create_timer(60,true).timeout.connect(func(): quit(2))
	call_deferred("run")
func clock(minute: float):
	game.schedule.clock_elapsed = clock_value(minute)
	game.schedule.tick(false)
	game.room_access.tick()
	game.workshop.update_gate()
	game.routines.tick()
func clock_value(minute: float) -> float:
	return (minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://nine-services-qa.cfg")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame; await process_frame
	game.set_process(false)
	game.reset_round(["lockpick","chat","backpack"],73)
	game.tutorial.cancel()
	game.schedule.panel.hide()
	game.fullscreen_ui.close_menu()
	game.schedule.set_time_speed(0)
	clock(600)
	for i in 3:
		game.actors[i].position = game.routines._target(i,"work")
		if i == 0: game.routines.start_work(0)
		else: game.routines.resume(i)
		game.orders.stop(i)
	checks["player can still begin normal work"] = game.routines.is_working(0)
	var npc_before: int = game.social.person("prisoner:1").money
	game.routines.accrue_work(clock_value(600),clock_value(660),[0,1,2],{0:60,1:60,2:60})
	checks["only player wage reaches player wallet"] = game.inventory.wallet == game.routines.work_wage()
	checks["NPC wage stays in social ledger"] = game.social.person("prisoner:1").money == npc_before+game.routines.work_wage()
	var wallet_before: int = game.inventory.wallet
	game.routines.accrue_work(clock_value(600),clock_value(660),[0,1,2],{0:60,1:60,2:60})
	checks["duplicate work interval cannot pay twice"] = game.inventory.wallet == wallet_before
	game.routines.accrue_work(clock_value(660),clock_value(720),[0],{0:60})
	checks["second work wage can fund a five-unit wager"] = game.inventory.wallet == game.routines.work_wage()*2 and game.inventory.wallet >= 5
	clock(1030)
	game.schedule.set_time_speed(1)
	game.actors[0].position = Vector2(1090,454)
	game.room_visibility.tick(0)
	game.orders.clear()
	game.nine_point.open_table("chess-card-table")
	var time_before: float = game.schedule.clock_elapsed
	var elapsed_before: float = game.elapsed
	game._process(1.0)
	checks["card table keeps schedule and simulation running"] = not paused and game.schedule.clock_elapsed > time_before and game.elapsed > elapsed_before
	wallet_before = game.inventory.wallet
	game.nine_point.amount = 5
	checks["earned money accepted by minigame"] = game.nine_point.confirm_bet() and game.inventory.wallet == wallet_before-5
	game.nine_point.close()
	checks["closing paid game resumes world"] = not paused and not game.nine_point.is_open()
	clock(750)
	game.routines.take_control(0)
	var point: Vector2 = game.routines._target(0,"meal")
	game.actors[0].position = point
	wallet_before = game.inventory.wallet
	checks["normal lunch still starts after a card game"] = game.routines.start_meal(0)
	checks["lunch cannot alter wallet"] = game.inventory.wallet == wallet_before
	game.reset_round([],74)
	checks["new game resets card ledger and original wallet"] = game.inventory.wallet == 0 and game.nine_point.npc_banks == [200,200,200] and not paused
	var failed := checks.keys().filter(func(k):return not checks[k])
	var report := {"checks":checks,"count":checks.size(),"failed":failed,"legacy_note":"p76_lunch_wallet refers to removed routine_panel; this check uses current work/meal APIs."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/art/nine-point-v3/"))
	FileAccess.open("res://docs/art/nine-point-v3/services-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("Nine services ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
