extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.presentation.lighting.set_period("night")
	var job = load("res://tests/p15_live_r02_job.gd").new()
	game.add_child(job)
	job.configure(game,"chat_lock")
	job.set_process(false)
	for tick in range(3600):
		game._process(1.0/60)
		job._process(1.0/60)
		if job.state == "finished":
			break
	print("P15_PLAN ",JSON.stringify({"passed":job.result.get("passed",false),"command":job.command_index,"reason":job.result.get("reason","timeout"),"captures":game.captures,"elapsed":game.elapsed,"trace":job.trace}))
	game.queue_free()
	await process_frame
	quit()
