extends "res://tests/p12_live_route_job.gd"

func configure(current_game, _route_name: String = "chat_lock") -> void:
	game = current_game
	route = "chat_lock"
	commands = [
		{"kind":"load", "skills":["chat","lockpick","strong"],"seed":33},
		{"kind":"walk","actor":0,"points":[Vector2(700,235),Vector2(700,355)]},
		{"kind":"skill","actor":0},
		{"kind":"walk","actor":1,"points":[Vector2(450,300),Vector2(813,300),Vector2(813,395)]},
		{"kind":"skill","actor":1},{"kind":"wait_door"},
		{"kind":"walk","actor":1,"points":[Vector2(920,395),Vector2(1040,395)]},
		{"kind":"walk","actor":2,"points":[Vector2(450,500),Vector2(813,500),Vector2(813,395),Vector2(920,395),Vector2(1040,435)]},
		{"kind":"cancel","actor":0},
		{"kind":"walk","actor":0,"points":[Vector2(700,200),Vector2(813,200),Vector2(813,355),Vector2(920,355),Vector2(1040,395)]}
	]

func _process(delta: float) -> void:
	if command_index < commands.size():
		if commands[command_index].kind == "load":
			game.load_room("r02", commands[command_index].skills, commands[command_index].seed)
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
	result = {"passed":passed,"reason":reason,"route":route,"trace":trace,"command":command_index,"snapshot":game.snapshot()}
	var file := FileAccess.open("res://docs/tests/p12-live-r02.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	get_viewport().get_texture().get_image().save_png("res://docs/tests/p12-live-r02.png")
	set_process(false)
