extends SceneTree

var game
var trace: Array = []
var failure: String = ""
func _initialize() -> void:
	call_deferred("run")

func walk(point: Vector2, id: int = 0) -> bool:
	game.select_actor(id)
	if not game.command_move(id,point):
		failure = "order_rejected"
		return false
	var start: float = game.elapsed
	while game.elapsed-start < 20:
		await process_frame
		if game.actors[id].escaped:
			return true
		if not game.orders.active.has(id):
			if game.actors[id].position.distance_to(point) < 4:
				trace.append({"actor":id,"point":[point.x,point.y],"elapsed":game.elapsed})
				return true
			failure = "captured_or_stopped"
			return false
	failure = "walk_timeout"
	return false

func walk_points(points: Array, id: int = 0) -> bool:
	for point in points:
		if not await walk(point,id):
			return false
	return true

func departure(id: int) -> bool:
	var start: float = game.elapsed
	while game.elapsed-start < 80:
		await process_frame
		if game.guard.state == "patrol" and game.guard.position.y > 850 and game.guard.position.x > 1100:
			return await walk_points([Vector2(460,780),Vector2(700,780),Vector2(1040,580),Vector2(1400,580),Vector2(1533,730)],id)
	failure = "patrol_window_timeout"
	return false

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.load_room("r03",["backpack","chat","chat"],20)
	game.presentation.lighting.set_period("night")
	var ok := await walk_points([Vector2(460,780),Vector2(640,900)])
	for point in [Vector2(740,1000),Vector2(1130,980),Vector2(1410,1140)]:
		if ok:
			ok = await walk(point)
			for item in game.inventory.instances.values():
				if item.location == "ground" and item.definition_id == "scrap" and Vector2(item.position[0],item.position[1]).distance_to(point) < 1:
					ok = ok and game.inventory.try_pickup(0,item.id).ok
	if ok:
		ok = await walk_points([Vector2(1000,1000),Vector2(700,940),Vector2(640,780),Vector2(460,780),Vector2(360,400)])
	if ok:
		for id in game.inventory.items(0):
			ok = ok and game.trade.try_sell(0,"warehouse_dealer",id).ok
	var key := ""
	for id in game.trade.merchants.warehouse_dealer.stock:
		if game.inventory.instances[id].definition_id == "door_key":
			key = id
	if ok:
		ok = game.trade.try_buy(0,"warehouse_dealer",key).ok
		ok = ok and await departure(0)
		ok = ok and game.inventory.try_use(0,key).ok
		ok = ok and await walk_points([Vector2(1660,730),Vector2(1830,700)])
	for id in [1,2]:
		if ok:
			ok = await departure(id)
			ok = ok and await walk_points([Vector2(1660,730),Vector2(1830,700)],id)
	game.map_camera.position = Vector2(884,526)
	game.map_camera.pan_by(Vector2.ZERO)
	await process_frame
	await RenderingServer.frame_post_draw
	var image_path := "res://docs/tests/p20-live-r03.png"
	root.get_texture().get_image().save_png(image_path)
	var passed: bool = ok and game.phase == "complete" and game.captures == 0
	var report := {"passed":passed,"elapsed":game.elapsed,"captures":game.captures,"failure":failure,"snapshot":game.snapshot(),"trace":trace,"headless":DisplayServer.get_name()=="headless","image":image_path,"note":"Native real-frame-clock continuous AI: actual movement, three pickups, three sales, key purchase/use, all three escape. Automated gameplay, not human observation."}
	var file := FileAccess.open("res://docs/tests/p20-live-r03.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"passed":passed,"elapsed":game.elapsed,"captures":game.captures,"failure":failure}))
	quit(0 if passed else 1)
