extends RefCounted

var game

func _init(current_game) -> void:
	game = current_game

func follow(actor_id: int, points: Array) -> Dictionary:
	var actor = game.actors[actor_id]
	var before_captures: int = game.captures
	game.select_actor(actor_id)
	for point in points:
		if not game.command_move(actor_id,point):
			return {"success":false,"reason":"unreachable","actor":actor_id}
		var began: float = game.elapsed
		while not actor.escaped and actor.position.distance_to(point) > 3:
			await game.get_tree().process_frame
			if not game.orders.active.has(actor_id) and not actor.escaped and actor.position.distance_to(point) > 3:
				return {"success":false,"reason":"captured","actor":actor_id,"snapshot":game.snapshot()}
			if game.elapsed-began > 15:
				game.orders.stop(actor_id)
				return {"success":false,"reason":"blocked","actor":actor_id,"goal":str(point),"snapshot":game.snapshot()}
	game.orders.stop(actor_id)
	return {"success":true,"escaped":actor.escaped,"new_captures":game.captures-before_captures,"elapsed":game.elapsed}

func open_lock() -> Dictionary:
	game.reset_round(["lockpick","lockpick","lockpick"],11)
	var approach: Dictionary = await follow(0,[Vector2(430,235),Vector2(440,395)])
	if not approach.success:
		return approach
	game.use_selected_skill()
	var began: float = game.elapsed
	while not game.world.door_open and game.elapsed-began < 5:
		await game.get_tree().process_frame
	return {"success":game.world.door_open,"elapsed":game.elapsed,"snapshot":game.snapshot()}
