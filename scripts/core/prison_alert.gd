extends RefCounted

const Guard = preload("res://scripts/actors/guard.gd")
var game
var active := false
var missing_ids: Array[int] = []
var checked_rooms: Dictionary = {}
var inspection_day := -1
var triggered_minute := -1.0
var reinforcements: Array = []
var routes: Dictionary = {}

func _init(owner_game) -> void:
	game = owner_game

func reset() -> void:
	for officer in reinforcements:
		for visual in officer.get_children():
			game.presentation.visuals.erase(visual)
		officer.free()
	reinforcements.clear()
	routes.clear()
	active = false
	missing_ids.clear()
	checked_rooms.clear()
	inspection_day = -1
	triggered_minute = -1

func officers() -> Array:
	var result: Array = [game.guard]
	if game.gate_watch:
		result.append_array(game.gate_watch.guards)
	result.append_array(reinforcements)
	return result

func check_rollcall() -> void:
	if active or game.phase != "playing" or game.get_tree().paused or not game.schedule.is_sleep_time():
		return
	if inspection_day != game.schedule.day_number():
		inspection_day = game.schedule.day_number()
		checked_rooms.clear()
	for actor in game.actors:
		if actor.confined: continue # Registered custody is not a missing prisoner.
		var checkpoint: Vector2 = game.schedule.inspection_point(actor.actor_id)
		# Only an actual room visit counts. Walls/gates cannot be inspected through.
		if not game.schedule.dormitory(actor.actor_id).grow(-17).has_point(game.guard.position) or game.guard.position.distance_to(checkpoint) > 35 or not game.world.line_clear(game.guard.position,actor.home):
			continue
		checked_rooms[actor.actor_id] = game.schedule.absolute_minutes()
		if actor.escaped or not game.schedule.in_dormitory(actor.actor_id):
			missing_ids.append(actor.actor_id)
			_raise_alarm()
			return

func _raise_alarm() -> void:
	active = true
	triggered_minute = game.schedule.absolute_minutes()
	game.cancel_guard_chat("查寝发现缺员，看守结束交谈！")
	for index in range(2):
		var officer = Guard.new()
		officer.name = "SearchReinforcement%d" % (index+1)
		game.add_child(officer)
		officer.configure(game.world,game)
		# Deploy at a physical patrol entrance, never at the fugitive.
		var candidates: Array = [game.world.guard_start+Vector2(0,48*(index+1)),game.world.guard_start+Vector2(48*(index+1),0)]
		candidates.append_array(game.world.patrol)
		for point in candidates:
			if game.world.can_place_circle(point,17,officer,true) and reinforcements.all(func(other): return other.position.distance_to(point) >= 36):
				officer.position = point
				break
		reinforcements.append(officer)
		game.gate_watch.attach_visual(officer)
	var search_points: Array[Vector2] = []
	for actor in game.actors:
		search_points.append(game.schedule.inspection_point(actor.actor_id))
	search_points.append_array(game.world.patrol)
	for kind in ["work","free"]:
		for entry in game.room_config.get("routine_points",{}).get(kind,[]):
			search_points.append(Vector2(entry[0],entry[1]))
	var team := officers()
	for index in range(team.size()):
		var officer = team[index]
		officer.release_target()
		officer.chat_partner_id = -1
		officer.returning_from_inspection = false
		officer.escaped = false
		officer.show()
		officer.route_index = 0
		var route: Array[Vector2] = []
		var offset: int = index*search_points.size()/team.size()
		for step in range(search_points.size()):
			route.append(search_points[(offset+step)%search_points.size()])
		routes[officer.get_instance_id()] = route
	game.show_status("查寝发现伙伴%d缺员！全厂区警戒，增派2名混混搜查。" % (missing_ids[0]+1),8)

func search_route(officer) -> Array[Vector2]:
	return routes.get(officer.get_instance_id(),game.world.patrol)

func tick(delta: float) -> void:
	check_rollcall()
	if active and game.phase == "playing" and not game.get_tree().paused:
		for officer in reinforcements:
			officer.tick(delta)

func snapshot() -> Dictionary:
	return {"active":active,"missing_ids":missing_ids.duplicate(),"checked_rooms":checked_rooms.duplicate(),"triggered_minute":triggered_minute,"reinforcements":reinforcements.map(func(g): return g.snapshot()),"officer_count":officers().size()}
