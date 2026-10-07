extends RefCounted

var game
var active: Dictionary = {}

func _init(escape_game) -> void:
	game = escape_game

func issue(actor_id: int, goal: Vector2, source: String = "manual") -> bool:
	if game.phase != "playing" or actor_id < 0 or actor_id >= game.actors.size():
		return false
	if source == "manual" and not game.actor_is_controllable(actor_id): return false
	var actor = game.actors[actor_id]
	if actor.escaped:
		return false
	var push: bool = source == "manual" and actor.skill_id == "strong"
	if not game.world.can_place_circle(goal,17,actor,true,not push):
		game.show_status("目标被墙、门或伙伴占据，请选择可站立的位置。")
		return false
	var path: PackedVector2Array = game.world.find_path(actor.position,goal,actor,true,push)
	if path.is_empty():
		game.show_status("这里暂时走不到：先打开通路，再下达移动指令。")
		return false
	if source == "manual" and game.routines:
		game.routines.take_control(actor_id)
	game.skills.cancel(actor_id,"收到移动指令，当前操作停止；撬锁进度保留。")
	active[actor_id] = {"source":source,"goal":goal,"path":path,"push":push,"stalled":0.0,"repath":0.0,"revision":game.world.obstacle_revision}
	if source == "manual":
		game.show_status("主角前往目标；S停止移动。",1.5)
	return true

func stop(actor_id: int) -> void:
	active.erase(actor_id)
	if actor_id >= 0 and actor_id < game.actors.size():
		game.actors[actor_id].moved_this_frame = false

func clear() -> void:
	for id in active.keys():
		stop(id)

func tick(delta: float) -> void:
	for id in active.keys():
		if game.phase != "playing":
			break
		var actor = game.actors[id]
		if actor.escaped:
			stop(id)
			continue
		var order: Dictionary = active[id]
		order.repath -= delta
		if actor.position.distance_to(order.goal) < 2.5:
			stop(id)
			continue
		var path: PackedVector2Array = order.path
		while not path.is_empty() and actor.position.distance_to(path[0]) < 2.5:
			path.remove_at(0)
		var blocked: bool = path.is_empty() or not game.world.motion_clear(actor.position,path[0],actor,true,order.push)
		if blocked and order.repath <= 0:
			path = game.world.find_path(actor.position,order.goal,actor,true,order.push)
			order.repath = 0.35
			order.revision = game.world.obstacle_revision
		order.path = path
		var moved := Vector2.ZERO
		if not path.is_empty():
			var difference: Vector2 = path[0] - actor.position
			var efficiency: float = game.attributes.move_efficiency(id) if game.attributes else 1.0
			var preparing: bool = game.schedule.preparing_for_work()
			var budget: float = game.MOVE_SPEED*efficiency*delta*game.schedule.preparation_move_scale()
			var origin: Vector2 = actor.position
			for step in range(64 if preparing else 1):
				if path.is_empty() or budget <= 0.001: break
				difference = path[0]-actor.position
				var request: Vector2 = difference.normalized()*minf(budget,difference.length())
				var actual: Vector2 = game.world.move_actor(actor,request,order.push,85*delta)
				budget -= request.length()
				if actor.position.distance_to(path[0]) < 2.5: path.remove_at(0)
				elif actual.length_squared() < 0.001: break
				moved = actor.position-origin
			order.path = path
		actor.moved_this_frame = moved.length_squared() > 0.001
		if actor.moved_this_frame:
			actor.facing = moved.normalized()
			order.stalled = 0.0
		else:
			order.stalled += delta
		if order.stalled > 1.0:
			stop(id)
			game.show_status("伙伴%d的路线被挡住了，请重新选择目标。" % (id+1))
		actor.queue_redraw()
		if game.world.check_exit(actor):
			stop(id)
			game.on_actor_escaped(id)

func snapshot() -> Array:
	var records: Array = []
	for id in active:
		var order: Dictionary = active[id]
		records.append({"actor_id":id,"goal":[order.goal.x,order.goal.y],"path_size":order.path.size(),"push":order.push,"stalled":order.stalled})
	return records
