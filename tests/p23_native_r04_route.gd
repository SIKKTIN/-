extends SceneTree

var game
var trace: Array = []
var failure := ""

func _initialize() -> void:
	call_deferred("run")

func move(id: int, point: Vector2) -> bool:
	game.select_actor(id)
	game.map_camera.center_on(point)
	if not game.command_move(id,point):
		failure = "order_rejected"
		return false
	var began: float = game.elapsed
	while game.elapsed-began < 35:
		await process_frame
		if game.actors[id].escaped:
			return true
		if not game.orders.active.has(id):
			if game.actors[id].position.distance_to(point) < 4:
				trace.append({"actor":id,"point":[point.x,point.y],"elapsed":game.elapsed})
				return true
			failure = "captured_or_stopped"
			return false
	failure = "move_timeout"
	return false

func sequence(id: int, points: Array) -> bool:
	for point in points:
		if not await move(id,point):
			return false
	return true

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.load_room("r04",["lockpick","chat","backpack"],23)
	game.presentation.lighting.set_period("night")
	root.warp_mouse(Vector2(535,394))
	var began := Time.get_ticks_msec()
	var passed := true
	for id in range(3):
		var waiting: float = game.elapsed
		while not (game.guard.state == "patrol" and game.guard.position.x > 1400 and game.guard.position.y > 1100):
			await process_frame
			if game.elapsed-waiting > 120:
				failure = "patrol_window_timeout"
				passed = false
				break
		if not passed:
			break
		passed = await sequence(id,[Vector2(540,970),Vector2(680,950),Vector2(700,680),Vector2(1450,680),Vector2(1817,770)])
		if passed and id == 0:
			game.use_selected_skill()
			var opening: float = game.elapsed
			while not game.world.door_open and game.elapsed-opening < 8:
				await process_frame
			passed = game.world.door_open
		if passed:
			passed = await sequence(id,[Vector2(1950,770),Vector2(2235,790)])
		if not passed:
			break
	passed = passed and game.phase == "complete" and game.captures == 0
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/tests/p23-native-r04-route.png")
	var file := FileAccess.open("res://docs/tests/p23-native-r04-route.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"elapsed":game.elapsed,"wall_seconds":float(Time.get_ticks_msec()-began)/1000,"captures":game.captures,"phase":game.phase,"failure":failure,"trace":trace,"scope":"Native real frame-clock full gameplay, guard AI continuously active; commands via game API, no actor teleport, no pause. Not a human or phone-device playtest."},"\t"))
	print(JSON.stringify({"passed":passed,"elapsed":game.elapsed,"captures":game.captures,"failure":failure}))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0 if passed else 1)
