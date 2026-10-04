extends SceneTree

const DT := 1.0/60.0
var game
var trace: Array = []

func _initialize() -> void:
	call_deferred("_run")

func step(ticks: int) -> void:
	for index in range(ticks):
		game._process(DT)

func follow(actor_id: int, points: Array) -> bool:
	var actor = game.actors[actor_id]
	for point in points:
		if not game.command_move(actor_id,point):
			trace.append({"actor":actor_id,"goal":str(point),"failure":"unreachable","snapshot":game.snapshot()})
			return false
		var count: int = 0
		while not actor.escaped and actor.position.distance_to(point) > 3 and count < 900:
			game._process(DT)
			count += 1
			if not game.orders.active.has(actor_id) and not actor.escaped and actor.position.distance_to(point) > 3:
				trace.append({"actor":actor_id,"goal":str(point),"failure":"captured","snapshot":game.snapshot()})
				return false
		if count >= 900:
			trace.append({"actor":actor_id,"goal":str(point),"failure":"blocked","snapshot":game.snapshot()})
			game.orders.stop(actor_id)
			return false
	game.orders.stop(actor_id)
	return true

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r01",["lockpick","lockpick","lockpick"],11)
	var results := {}
	var lock_approach := follow(0,[Vector2(430,235),Vector2(440,395)])
	var lock_started: bool = game.skills.toggle(0)
	step(241)
	var lock_opened: bool = game.world.door_open
	var first := follow(0,[Vector2(560,395),Vector2(560,250),Vector2(945,250),Vector2(945,430),Vector2(1040,430)])
	var second := follow(1,[Vector2(440,395),Vector2(560,395),Vector2(560,250),Vector2(945,250),Vector2(945,470),Vector2(1040,470)])
	var third := follow(2,[Vector2(440,510),Vector2(440,395),Vector2(560,395),Vector2(560,500),Vector2(945,500),Vector2(1040,510)])
	results.lock_route = {"approach":lock_approach,"skill_started":lock_started,"door_opened":lock_opened,"routes":[first,second,third],"completed":game.phase == "complete","snapshot":game.snapshot()}
	game.reset_round(["strong","strong","strong"],22)
	var push_route := follow(2,[Vector2(440,510),Vector2(440,617),Vector2(600,617),Vector2(600,500),Vector2(945,500),Vector2(1040,500)])
	var push_first := follow(0,[Vector2(440,235),Vector2(440,617),Vector2(550,617),Vector2(550,250),Vector2(945,250),Vector2(945,470),Vector2(1040,470)])
	var push_second := follow(1,[Vector2(440,375),Vector2(440,617),Vector2(550,617),Vector2(550,500),Vector2(945,500),Vector2(1040,510)])
	results.push_route = {"routes":[push_route,push_first,push_second],"completed":game.phase == "complete","snapshot":game.snapshot()}
	results.trace = trace
	results.passed = results.lock_route.completed and results.push_route.completed
	var file := FileAccess.open("res://docs/tests/p11-r01-routes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	print("P05_RESULT ",JSON.stringify({"lock":results.lock_route.completed,"push":results.push_route.completed,"failures":trace.size(),"passed":results.passed}))
	if game.presentation:
		game.presentation.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.06).timeout
	quit(0 if results.passed else 1)
