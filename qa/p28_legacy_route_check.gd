extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var room: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "r01"
	game.load_room(room,["lockpick","lockpick","lockpick"],11)
	var job = load("res://qa/p28_route_job.gd").new()
	job.configure(game,"chat_lock" if room == "r02" else "lock")
	if room == "r02":
		var fixture = load("res://tests/p13_live_r02_job.gd").new()
		fixture.configure(game,"chat_lock")
		job.commands = fixture.commands.duplicate(true)
		fixture.free()
	game.add_child(job)
	var started := Time.get_ticks_msec()
	while job.state != "finished" and Time.get_ticks_msec()-started < 35000:
		await process_frame
	var passed: bool = job.state == "finished" and job.result.passed and game.captures == 0
	print("P28_LEGACY_ROUTE ",room," passed=",passed," elapsed=",game.elapsed," captures=",game.captures)
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
