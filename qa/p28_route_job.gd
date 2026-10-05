extends "res://tests/p13_live_route_job.gd"

func _process(delta: float) -> void:
	if command_index < commands.size():
		if commands[command_index].kind == "load":
			game.load_room("r02",commands[command_index].skills,commands[command_index].seed)
			_next()
			return
		if commands[command_index].kind == "cancel":
			game.skills.cancel(commands[command_index].actor)
			_next()
			return
	super._process(delta)

func _finish(passed: bool, reason: String) -> void:
	game.orders.clear()
	state = "finished"
	result = {"passed":passed,"reason":reason,"route":route,"trace":trace,"snapshot":game.snapshot(),"scope":"Legacy deterministic route with explicit room loading; native renderer and live gameplay clock/AI."}
	FileAccess.open("res://docs/tests/p28-legacy-"+game.room_id+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	get_viewport().get_texture().get_image().save_png("res://docs/tests/p28-legacy-"+game.room_id+".png")
	set_process(false)
