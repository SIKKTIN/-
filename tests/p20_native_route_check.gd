extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var room := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "r01"
	game.load_room(room, [], 20)
	game.presentation.lighting.set_period("night")
	var job = load("res://tests/p20_live_r02_job.gd" if room == "r02" else "res://tests/p20_live_r01_job.gd").new()
	game.add_child(job)
	job.configure(game,"chat_lock" if room == "r02" else "lock")
	var started := Time.get_ticks_msec()
	while job.state != "finished" and Time.get_ticks_msec()-started < 35000:
		await process_frame
	var passed: bool = job.state == "finished" and job.result.passed and game.captures == 0 and game.presentation.lighting.period == "night"
	print("P20_NATIVE_ROUTE ",room," passed=",passed," elapsed=",game.elapsed," captures=",game.captures," period=",game.presentation.lighting.period)
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0 if passed else 1)
