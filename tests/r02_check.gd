extends "res://tests/route_check.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r02",["chat","lockpick","strong"],33)
	var results := {}
	var approach_chat := follow(0,[Vector2(700,235),Vector2(700,355)])
	var chat_started: bool = game.skills.toggle(0)
	var guard_stopped: Vector2 = game.guard.position
	var approach_lock := follow(1,[Vector2(450,300),Vector2(813,300),Vector2(813,395)])
	var lock_started: bool = game.skills.toggle(1)
	step(241)
	var door_open: bool = game.world.door_open
	var sustained: bool = game.skills.actions.has(0) and game.guard.position == guard_stopped
	var lock_exited := follow(1,[Vector2(920,395),Vector2(1040,395)])
	var third_exited := follow(2,[Vector2(450,500),Vector2(813,500),Vector2(813,395),Vector2(920,395),Vector2(1040,435)])
	game.skills.cancel(0)
	var chatter_exited := follow(0,[Vector2(700,200),Vector2(813,200),Vector2(813,355),Vector2(920,355),Vector2(1040,395)])
	results.chat_lock = {"approach_chat":approach_chat,"chat_started":chat_started,"approach_lock":approach_lock,"lock_started":lock_started,"door_open":door_open,"chat_sustained":sustained,"exits":[lock_exited,third_exited,chatter_exited],"completed":game.phase == "complete","snapshot":game.snapshot()}
	game.load_room("r02",["strong","strong","strong"],44)
	var first := follow(2,[Vector2(185,650),Vector2(804,650),Vector2(804,617),Vector2(885,617),Vector2(885,510),Vector2(1040,510)])
	var second := follow(0,[Vector2(180,650),Vector2(804,650),Vector2(804,617),Vector2(885,617),Vector2(885,470),Vector2(1040,470)])
	var third := follow(1,[Vector2(235,650),Vector2(804,650),Vector2(804,617),Vector2(885,617),Vector2(885,430),Vector2(1040,430)])
	results.push = {"exits":[first,second,third],"completed":game.phase == "complete","snapshot":game.snapshot()}
	game.load_room("r02",["lockpick","lockpick","lockpick"],55)
	var solo_approach := follow(0,[Vector2(700,235),Vector2(813,300),Vector2(813,395)])
	var solo_started: bool = game.skills.toggle(0)
	step(241)
	results.solo_control = {"approach":solo_approach,"started":solo_started,"door_open":game.world.door_open,"captures":game.captures,"progress":game.world.lock_progress,"snapshot":game.snapshot()}
	results.trace = trace
	results.passed = results.chat_lock.completed and results.push.completed and sustained and game.captures > 0
	var file := FileAccess.open("res://docs/tests/p11-r02-routes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	print("P06_RESULT ",JSON.stringify({"chat_lock":results.chat_lock.completed,"push":results.push.completed,"chat_sustained":sustained,"solo_captures":game.captures,"failures":trace.size(),"passed":results.passed}))
	if game.presentation:
		game.presentation.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.06).timeout
	quit(0 if results.passed else 1)
