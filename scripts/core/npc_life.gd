extends RefCounted

var game
var people: Dictionary = {}
var timer := 0.0
var decisions := 0

func _init(owner_game):
	game = owner_game
	reset()

func reset():
	people.clear()
	timer = 0
	decisions = 0
	register_people()

func register_people():
	if not game.social: return
	for id in game.social.people:
		var person: Dictionary = game.social.people[id]
		if person.role=="player": continue
		if not people.has(id): people[id] = {"id":id,"role":person.role,"intent":"","label":"","phase":"","next_think":-1.0,"goal":Vector2.ZERO,"decision":{}}

func phase() -> String:
	var minute: float = game.schedule.clock_minutes()
	if game.schedule.is_sleep_time(): return "sleep"
	if minute>=1160: return "dorm"
	if game.schedule.preparing_for_work() or game.routines.preparing_afternoon() or game.schedule.work_window().x>=0: return "work"
	if minute>=720 and minute<810: return "lunch"
	return "leisure"

func partner(actor_id: int):
	for actor in game.actors.slice(1):
		if actor.actor_id==actor_id or actor.escaped or actor.confined or game.routines.is_working(actor.actor_id) or game.routines.is_eating(actor.actor_id): continue
		var relation: Dictionary = game.social.relation("prisoner:%d" % actor_id,"prisoner:%d" % actor.actor_id)
		if relation.like< -30 or relation.trust<15: continue
		if actor.position.distance_to(game.actors[actor_id].position)<=350 and game.world.line_clear(actor.position,game.actors[actor_id].position): return actor
	return null

func choose(id: String, force := false) -> String:
	var person: Dictionary = game.social.person(id)
	var life: Dictionary = people[id]
	var context := phase()
	if context=="lunch" and game.routines.meal_minutes[person.node.actor_id]>=20: context = "leisure"
	var minute: float = game.schedule.absolute_minutes()
	if not force and life.phase==context and minute<life.next_think: return life.intent
	game.social.update_needs(person)
	var actions := []
	if context=="work": actions = [{"id":"work" if game.routines.allowed(0,"work") else "rest","self":0.7,"fit":person.traits.loyalty,"routine":1.0}]
	elif context in ["sleep","dorm"]: actions = [{"id":"rest","self":0.6+person.needs.fatigue/250,"fit":person.traits.caution,"routine":1.0}]
	elif context=="lunch" and game.routines.meal_minutes[person.node.actor_id]<20:
		actions = [{"id":"meal" if game.routines.has_cafeteria() else "rest","self":0.6+person.needs.hunger/250,"routine":1.0,"fit":person.traits.caution*0.3}]
	else:
		var fear: float = person.mood.fear/100.0
		actions = [
			{"id":"rest","self":person.needs.fatigue/100.0,"fit":person.traits.caution*0.7,"emotion":fear+person.mood.pressure/300,"routine":0.2,"cost":0.1},
			{"id":"walk","self":0.3-person.needs.fatigue/500,"fit":person.traits.ambition*0.5+(1-person.traits.caution)*0.4,"emotion":-fear*0.7,"cost":0.15},
			{"id":"socialize","available":is_instance_valid(partner(person.node.actor_id)),"self":0.15+maxf(0,30-person.mood.joy)/100,"fit":person.traits.generosity*0.95-person.traits.caution*0.15,"emotion":person.mood.joy/150-fear,"routine":0.15,"cost":0.1}]
	var decision: Dictionary = game.social.decide(id,"life:"+context,actions)
	life.intent = decision.action
	life.phase = context
	life.decision = person.last_decision.duplicate(true)
	life.next_think = minute+25+int(person.node.actor_id)*5
	life.label = {"work":"前往工位","meal":"前往取餐","rest":"休息","walk":"散步","socialize":"找人交谈"}[life.intent]
	life.goal = game.routines._target(person.node.actor_id,life.intent) if life.intent in ["work","meal"] else leisure_goal(person.node.actor_id,life.intent)
	decisions += 1
	return life.intent

func routine_for(actor_id: int) -> String:
	if game.actor_is_controllable(actor_id): return "idle"
	if game.tutorial and game.tutorial.active:
		var slot: int = game.routines.current_slot()
		return str(game.routines.plans[actor_id][slot]) if slot>=0 else "rest"
	var id := "prisoner:%d" % actor_id
	if not people.has(id): register_people()
	var kind := choose(id)
	return "free" if kind in ["walk","socialize"] else kind

func leisure_goal(actor_id: int, intent: String) -> Vector2:
	var actor = game.actors[actor_id]
	if intent=="rest": return actor.home
	if intent=="socialize":
		var other = partner(actor_id)
		if is_instance_valid(other):
			for offset in [Vector2(70,0),Vector2(-70,0),Vector2(0,70),Vector2(0,-70)]:
				var goal: Vector2 = other.position+offset
				if game.world.can_place_circle(goal,8,actor,true) and game.world.line_clear(goal,other.position): return goal
	var locations: Array = game.room_config.get("routine_points",{}).get("free",[])
	if locations.is_empty(): return actor.home
	var index := (actor_id+floori(game.schedule.absolute_minutes()/60))%locations.size()
	return game.world.routine_destination(Vector2(locations[index][0],locations[index][1]))

func destination(actor_id: int, kind: String) -> Variant:
	if game.actor_is_controllable(actor_id) or (game.tutorial and game.tutorial.active): return null
	var id := "prisoner:%d" % actor_id
	if not people.has(id): return null
	if kind in ["free","rest"]: return people[id].goal
	return null

func label(id: String) -> String:
	if not people.has(id): return game.social.mood_name(id)
	var person: Dictionary = game.social.person(id)
	var actor = person.node
	if not is_instance_valid(actor): return "离开了"
	if person.role=="prisoner":
		if actor.confined: return "禁闭中"
		if game.schedule.is_sleeping(actor.actor_id): return "睡觉"
		if game.routines.is_working(actor.actor_id): return "工作"
		if game.routines.is_eating(actor.actor_id): return "吃饭"
		if actor.action_state=="chatting": return "交谈"
		if game.routines.allowed(0,"work") and (game.schedule.preparing_for_work() or game.routines.preparing_afternoon()): return "前往工位"
		var moving: bool = game.orders.active.has(actor.actor_id)
		return {"work":"前往工位" if moving else "到岗待命","meal":"前往饭桌" if game.routines.carries_meal(actor.actor_id) else "前往取餐","rest":"回寝休息" if moving else "休息","walk":"散步","socialize":"找人交谈" if moving else "等人交谈"}.get(people[id].intent,game.routines.status_for(actor.actor_id))
	if person.role=="merchant": return actor.activity_text()
	var traffic: String = game.staff_traffic.label(actor) if game.staff_traffic else ""
	if not traffic.is_empty(): return traffic
	if actor.escaped or not actor.visible: return "休息"
	return {"chasing":"追捕","searching":"搜查","talking":"交谈","patrol":"查岗" if person.role=="overseer" else "守门" if person.role=="gate" else "巡逻"}.get(actor.state,"值勤")

func tick(delta: float):
	if game.phase!="playing" or game.get_tree().paused: return
	timer -= maxf(delta,0)
	if timer>0: return
	timer = 1.0
	register_people()
	for id in people:
		var life: Dictionary = people[id]
		var person: Dictionary = game.social.person(id)
		if not is_instance_valid(person.node): continue
		if person.role=="prisoner" and not person.node.escaped and not person.node.confined and not (game.tutorial and game.tutorial.active):
			var actor_id: int = person.node.actor_id
			var old_intent: String = life.intent
			var old_goal: Vector2 = life.goal
			var kind := routine_for(actor_id)
			var record: Dictionary = game.routines.records.get(actor_id,{})
			if not game.dialogue.holds_movement(person.node) and person.node.action_state=="idle" and (record.is_empty() or record.kind!=kind or old_intent!=life.intent or old_goal!=life.goal):
				game.routines._start(actor_id)
		life.label = label(id)
		if person.role!="prisoner":
			life.intent = life.label
			life.phase = "rest" if person.node.escaped or not person.node.visible else "duty"
			var goal: Variant = person.node.goal if person.role=="merchant" else person.node.get("path_goal")
			life.goal = goal if goal is Vector2 else person.node.position
		life["needs"] = person.needs.duplicate()

func snapshot() -> Dictionary:
	return {"people":people.duplicate(true),"decisions":decisions}
