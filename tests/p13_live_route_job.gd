extends Node

var game
var route: String = "lock"
var state: String = "running"
var commands: Array = []
var command_index: int = 0
var point_index: int = 0
var walking: bool = false
var point_started: float = 0.0
var trace: Array = []
var result: Dictionary = {}

func configure(current_game, route_name: String) -> void:
	game = current_game
	route = route_name
	if route == "lock":
		commands = [
			{"kind":"reset","skills":["lockpick","lockpick","lockpick"],"seed":11},
			{"kind":"walk","actor":0,"points":[Vector2(430,235),Vector2(440,395)]},
			{"kind":"skill","actor":0},{"kind":"wait_door"},
			{"kind":"walk","actor":0,"points":[Vector2(560,395),Vector2(560,250),Vector2(945,250),Vector2(945,430),Vector2(1040,430)]},
			{"kind":"walk","actor":1,"points":[Vector2(440,395),Vector2(560,395),Vector2(560,250),Vector2(945,250),Vector2(945,470),Vector2(1040,470)]},
			{"kind":"walk","actor":2,"points":[Vector2(440,510),Vector2(440,395),Vector2(560,395),Vector2(560,500),Vector2(945,500),Vector2(1040,510)]}
		]
	else:
		commands = [
			{"kind":"reset","skills":["strong","strong","strong"],"seed":22},
			{"kind":"walk","actor":2,"points":[Vector2(440,510),Vector2(440,617),Vector2(600,617),Vector2(600,500),Vector2(945,500),Vector2(1040,500)]},
			{"kind":"walk","actor":0,"points":[Vector2(440,235),Vector2(440,617),Vector2(550,617),Vector2(550,250),Vector2(945,250),Vector2(945,470),Vector2(1040,470)]},
			{"kind":"walk","actor":1,"points":[Vector2(440,375),Vector2(440,617),Vector2(550,617),Vector2(550,500),Vector2(945,500),Vector2(1040,510)]}
		]

func _process(_delta: float) -> void:
	if command_index >= commands.size():
		_finish(game.phase == "complete", "completed" if game.phase == "complete" else "not_complete")
		return
	var command: Dictionary = commands[command_index]
	match command.kind:
		"reset":
			game.reset_round(command.skills,command.seed)
			_next()
		"skill":
			game.select_actor(command.actor)
			game.use_selected_skill()
			if not game.skills.actions.has(command.actor):
				_finish(false,"skill_not_started")
				return
			_next()
		"wait_door":
			if game.world.door_open:
				_next()
			elif game.elapsed-point_started > 5:
				_finish(false,"door_timeout")
		"walk":
			var actor = game.actors[command.actor]
			if actor.escaped:
				trace.append({"actor":command.actor,"escaped":true,"elapsed":game.elapsed})
				game.orders.stop(command.actor)
				_next()
				return
			if not walking:
				if not game.command_move(command.actor,command.points[point_index]):
					_finish(false,"cannot_start")
					return
				walking = true
				point_started = game.elapsed
			if not game.orders.active.has(command.actor) and actor.position.distance_to(command.points[point_index]) > 3:
				_finish(false,"captured_or_interrupted")
				return
			if actor.position.distance_to(command.points[point_index]) < 3:
				point_index += 1
				if point_index >= command.points.size():
					game.orders.stop(command.actor)
					_next()
				else:
					point_started = game.elapsed
					if not game.command_move(command.actor,command.points[point_index]):
						_finish(false,"unreachable")
			elif game.elapsed-point_started > 15:
				_finish(false,"blocked")

func _next() -> void:
	command_index += 1
	point_index = 0
	walking = false
	point_started = game.elapsed

func _finish(passed: bool, reason: String) -> void:
	game.orders.clear()
	state = "finished"
	result = {"passed":passed,"reason":reason,"route":route,"trace":trace,"command":command_index,"snapshot":game.snapshot()}
	var file := FileAccess.open("res://docs/tests/p13-live-r01-%s.json"%route,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	get_viewport().get_texture().get_image().save_png("res://docs/tests/p13-live-r01-%s.png"%route)
	set_process(false)
