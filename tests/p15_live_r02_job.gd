extends "res://tests/p13_live_r02_job.gd"

func configure(current_game, _route_name: String = "chat_lock") -> void:
	super.configure(current_game,_route_name)
	commands[1].points = [Vector2(700,235),Vector2(730,340)]
	commands[3].points = [Vector2(450,500),Vector2(700,500),Vector2(813,500),Vector2(813,395)]
	commands.pop_back()
	commands.append({"kind":"walk","actor":0,"points":[Vector2(650,280)]})
	commands.append({"kind":"wait_guard_low"})
	commands.append({"kind":"walk","actor":0,"points":[Vector2(813,200),Vector2(813,355),Vector2(920,355),Vector2(1040,395)]})

func _process(delta: float) -> void:
	if command_index < commands.size() and commands[command_index].kind == "wait_guard_low":
		if game.guard.state == "patrol" and game.guard.position.y >= 385 and game.guard.position.y <= 410 and game.guard.facing.y > 0.7:
			_next()
		elif game.elapsed-point_started > 10:
			_finish(false,"patrol_gap_timeout")
		return
	super._process(delta)

func _next() -> void:
	trace.append({"command":command_index,"elapsed":game.elapsed,"actor0":[game.actors[0].position.x,game.actors[0].position.y],"guard":[game.guard.position.x,game.guard.position.y],"facing":[game.guard.facing.x,game.guard.facing.y],"guard_state":game.guard.state})
	super._next()

func _finish(passed: bool, reason: String) -> void:
	game.orders.clear()
	state = "finished"
	result = {"passed":passed,"reason":reason,"route":route,"trace":trace,"command":command_index,"headless":DisplayServer.get_name() == "headless","snapshot":game.snapshot(),"presentation":game.presentation.snapshot()}
	var file := FileAccess.open("res://docs/tests/p15-live-r02.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("res://docs/tests/p15-live-r02.png")
	set_process(false)
