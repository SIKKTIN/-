extends RefCounted

const PLAYER := "prisoner:0"
const IMPACT_KEYS := ["body","resources","freedom","safety","information","relationships"]
var game
var config: Dictionary
var people: Dictionary = {}
var knowledge: Dictionary = {}
var now := 0.0
var think_timer := 0.0
var evaluations := 0
var revision := 0
var thought_cycles := 0
var last_thought := 0.0

func _init(owner_game):
	game = owner_game
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/social_characters.json"))
	reset()

func reset():
	people.clear()
	knowledge.clear()
	now = 0
	think_timer = 0
	evaluations = 0
	thought_cycles = 0
	last_thought = 0
	revision += 1
	register_people()

func register_people():
	for actor in game.actors: register("prisoner:%d" % actor.actor_id,"player" if actor.actor_id==0 else "prisoner",actor)
	register("guard:patrol","patrol",game.guard)
	if game.gate_watch:
		for actor in game.gate_watch.guards: register("guard:"+actor.guard_id,"gate",actor)
	if game.workshop and is_instance_valid(game.workshop.overseer): register("guard:overseer","overseer",game.workshop.overseer)
	if game.trade:
		for id in game.trade.actors:
			register("merchant:"+str(id),"merchant",game.trade.actors[id])
			game.trade.merchants[id].name = people["merchant:"+str(id)].name
	if game.prison_alert:
		for actor in game.prison_alert.reinforcements: register("guard:reinforcement:%d" % actor.get_instance_id(),"reinforcement",actor)

func register(id: String, role: String, actor):
	if not is_instance_valid(actor): return
	if not people.has(id):
		var spec: Dictionary = config.roster.get(id,{}).duplicate(true)
		if spec.is_empty():
			var serial := people.size()
			var surnames := ["刘","吴","梁","张","蒋","孙","韩","魏"]
			var given := ["立安","文平","志明","海成"]
			spec = {"name":surnames[serial%8]+given[(serial/8)%4],"role_name":"搜查看守" if role=="reinforcement" else "看守" if role=="gate" else "商人","trait_label":"谨慎","history":"在这里生活和工作，习惯先判断风险。","generosity":0.3,"caution":0.8,"loyalty":0.8,"ambition":0.5,"like":0,"trust":20}
		people[id] = {"id":id,"name":spec.name,"role":role,"role_name":spec.role_name,"traits":spec,"node":actor,"needs":{"hunger":20.0,"fatigue":15.0},"mood":{"joy":10.0,"anger":0.0,"fear":0.0,"pressure":0.0},"relations":{},"memories":[],"cooldowns":{},"money":4,"rations":1,"debt":0,"help_day":-1,"help_count":0,"last_decision":{},"busy_until":0.0,"line":"","line_until":0.0}
	people[id].node = actor
	actor.set_meta("social_id",id)
	actor.set_meta("display_name",people[id].name)

func person(id: String) -> Dictionary:
	return people.get(id,{})

func relation(id: String, other := PLAYER) -> Dictionary:
	var p := person(id)
	if p.is_empty(): return {"like":0.0,"trust":0.0,"fear":0.0}
	if not p.relations.has(other):
		p.relations[other] = {"like":float(p.traits.like) if other==PLAYER else 0.0,"trust":float(p.traits.trust) if other==PLAYER else 30.0,"fear":0.0}
	return p.relations[other]

func change_relation(id: String, other: String, liking: float, trust: float, fear := 0.0):
	var r := relation(id,other)
	r.like = clampf(r.like+liking,-100,100)
	r.trust = clampf(r.trust+trust,0,100)
	r.fear = clampf(r.fear+fear,0,100)
	revision += 1

func remember(id: String, kind: String, other: String, text: String, impact: Dictionary = {}):
	var p := person(id)
	if p.is_empty(): return
	p.memories.append({"kind":kind,"other":other,"text":text,"time":game.schedule.absolute_minutes(),"impact":impact.duplicate(true)})
	while p.memories.size()>12:
		var routine := -1
		for index in p.memories.size():
			if p.memories[index].kind in ["conversation","peer_chat"]:
				routine = index
				break
		p.memories.remove_at(maxi(routine,0))
	revision += 1

func mood_name(id: String) -> String:
	var p := person(id)
	if p.is_empty(): return "平静"
	if p.mood.fear>=45: return "害怕"
	if p.mood.anger>=40: return "烦躁"
	if p.mood.pressure>=45: return "紧张"
	if p.needs.fatigue>=65: return "疲惫"
	if p.mood.joy>=30: return "愉快"
	return "平静"

func summary(id: String) -> String:
	var r := relation(id)
	return "%s · 好感 %+d · 信任 %d" % [mood_name(id),roundi(r.like),roundi(r.trust)]

func localize(text: String) -> String:
	if people.has("prisoner:1") and people.has("prisoner:2"):
		text = text.replace("囚徒2或3",people["prisoner:1"].name+"或"+people["prisoner:2"].name)
	for index in range(3):
		var p := person("prisoner:%d" % index)
		if not p.is_empty(): text = text.replace("囚徒%d" % (index+1),p.name)
	if people.has("guard:overseer"): text = text.replace("老周",people["guard:overseer"].name)
	return text

func answer(id: String, fallback: String) -> String:
	if game.phase!="playing" or game.get_tree().paused or not accessible(id,125): return "靠近我，等有空时再谈。"
	var p := person(id)
	var r := relation(id)
	var staff: bool = p.role not in ["player","prisoner"]
	var urgent: bool = staff and p.role!="merchant" and p.node.state in ["chasing","searching"]
	var choice := decide(id,"answer",[
		{"id":"answer","available":not urgent,"self":0.1,"fit":p.traits.generosity*0.5+p.traits.loyalty*0.2+maxf(r.like/100,0)*0.3,"impact":{"information":0.5,"relationships":0.1},"emotion":-p.mood.anger/100,"routine":0.5 if staff else 0.0,"cost":0.1},
		{"id":"refuse","self":0.12,"fit":p.traits.caution*0.15+maxf(-r.like/100,0)*0.7,"emotion":p.mood.anger/100+p.mood.fear/100,"routine":0.35 if game.workshop.on_duty() else 0.0}])
	if choice.action=="refuse": return "现在不方便说这些，等我有空再来。"
	if not knowledge.has("rules:"+id):
		knowledge["rules:"+id] = {"source":id,"text":fallback}
		remember(id,"information",PLAYER,"告诉了你这里的规矩。",choice.impact)
	return fallback

func player_captured(point: Vector2):
	for id in people:
		var p: Dictionary = people[id]
		if p.role=="player" or not is_instance_valid(p.node) or not p.node.visible or game.world.is_under_roof(p.node.position): continue
		if p.node.position.distance_to(point)>180 or not game.world.line_clear(p.node.position,point): continue
		p.mood.fear = minf(100,p.mood.fear+25)
		change_relation(id,PLAYER,0,-2,5)
		remember(id,"capture",PLAYER,"亲眼看到你被抓走。",{"freedom":-0.8,"safety":-0.8})

func player_value(impact: Dictionary) -> float:
	var sum := 0.0
	var total := 0.0
	for key in IMPACT_KEYS:
		var weight: float = config.player_weights[key]
		if key=="body" and game.attributes.values[0].fullness<40: weight *= 2
		sum += weight*clampf(float(impact.get(key,0)),-1,1)
		total += weight
	return sum/total

func evaluate(id: String, action: Dictionary) -> Dictionary:
	var p := person(id)
	var r := relation(id)
	var affinity: float = clampf(r.like/100.0*0.6+(r.trust-50)/100.0*0.4,-1,1)
	var terms := {"self":30*clampf(float(action.get("self",0)),-1,1),"player":35*affinity*player_value(action.get("impact",{})),"personality":22*clampf(float(action.get("fit",0)),-1,1),"emotion":12*clampf(float(action.get("emotion",0)),-1,1),"routine":8*clampf(float(action.get("routine",0)),-1,1),"risk":-35*p.traits.caution*clampf(float(action.get("probability",0)),0,1)*clampf(float(action.get("loss",0)),0,1),"cost":-8*clampf(float(action.get("cost",0)),0,1)}
	var value := 0.0
	for term in terms.values(): value += float(term)
	return {"action":action.id,"score":value,"terms":terms,"impact":action.get("impact",{}).duplicate(true)}

func decide(id: String, context: String, actions: Array) -> Dictionary:
	var p := person(id)
	var scores := []
	for action in actions:
		if action.get("available",true): scores.append(evaluate(id,action))
	if scores.is_empty(): return {}
	evaluations += 1
	scores.sort_custom(func(a,b): return a.score>b.score)
	var chosen: Dictionary = scores[0]
	var previous: Dictionary = p.last_decision
	if previous.get("context","")==context and now<float(previous.get("until",0)):
		for score in scores:
			if score.action==previous.action and chosen.score<score.score+6: chosen = score
	p.last_decision = {"context":context,"action":chosen.action,"score":chosen.score,"terms":chosen.terms,"impact":chosen.impact,"candidates":scores,"until":now+8}
	return chosen

func accessible(id: String, distance := 160.0) -> bool:
	var p := person(id)
	var player = game.actors[0]
	return not p.is_empty() and is_instance_valid(p.node) and p.node.visible and not p.node.escaped and not player.escaped and not player.confined and not game.world.is_under_roof(p.node.position) and not game.world.is_under_roof(player.position) and player.position.distance_to(p.node.position)<=distance and game.world.line_clear(player.position,p.node.position)

func free_to_help(id: String) -> bool:
	var p := person(id)
	return p.role=="prisoner" and not p.node.escaped and not p.node.confined and not game.schedule.is_sleeping(p.node.actor_id) and not game.routines.is_working(p.node.actor_id) and not game.routines.is_eating(p.node.actor_id) and not game.workshop.on_duty()

func request_help(id: String) -> String:
	if game.phase!="playing" or game.get_tree().paused or not accessible(id,125): return "靠近我，等有空时再谈。"
	var p := person(id)
	if p.role!="prisoner": return "这件事不归我管。"
	if now<float(p.cooldowns.get("help",0)): return "刚才已经说过了，先给我一点时间。"
	if not free_to_help(id): return "现在得按作息做事，等休息时再说。"
	update_needs(p)
	var day := floori(game.schedule.absolute_minutes()/1440)
	if p.help_day!=day:
		p.help_day = day
		p.help_count = 0
	var r := relation(id)
	var fear: float = p.mood.fear/100.0
	var food: bool = p.help_count<1 and game.attributes.values[0].fullness<55 and p.rations>0 and game.attributes.values[p.node.actor_id].fullness>=55
	var money: bool = p.help_count<1 and not food and game.inventory.wallet<4 and p.money>=2
	var unknown: bool = not knowledge.has("workshop_warning")
	var choice := decide(id,"request_help",[
		{"id":"help","available":food or money,"self":-0.15,"impact":{"body":0.5 if food else 0.0,"resources":0.5 if money else 0.0,"relationships":0.2},"fit":p.traits.generosity*1.25-p.traits.ambition*0.25+minf(r.like/100.0,0)*0.9,"emotion":p.mood.joy/100.0-fear,"cost":0.35,"probability":0.1,"loss":0.2},
		{"id":"share","available":unknown and r.trust>=15,"self":0.05,"impact":{"information":0.8,"safety":0.4},"fit":p.traits.generosity*0.6-p.traits.ambition*0.15,"emotion":-fear*0.3,"cost":0.1},
		{"id":"refuse","self":0.12,"fit":p.traits.caution*0.3+p.traits.ambition*0.15+maxf(-r.like/100.0,0)*0.8,"emotion":fear+p.mood.anger/100.0,"routine":0.15}])
	p.cooldowns.help = now+30
	var line := "我得先顾好自己，这次帮不了你。"
	if choice.action=="help":
		p.help_count += 1
		if food:
			game.attributes.values[0].fullness = minf(100,game.attributes.values[0].fullness+12)
			game.attributes.values[p.node.actor_id].fullness -= 12
			p.rations -= 1
			line = "我分你半份口粮，先把肚子填上。"
		else:
			game.inventory.wallet += 2
			p.money -= 2
			line = "先借你2块钱，手头宽裕了记得还我。"
		p.debt += 1
		change_relation(id,PLAYER,-1,-1)
	elif choice.action=="share":
		knowledge.workshop_warning = {"source":id,"text":"监工发现偷懒后会警告3秒；持续劳动能慢慢消退警戒。"}
		line = "监工警告后有3秒。持续干活能让警戒慢慢消退，反复停工可躲不过去。"
		change_relation(id,PLAYER,1,1)
	remember(id,choice.action,PLAYER,line,choice.impact)
	express(id,line)
	return line

func chat(id: String, clicked: bool) -> String:
	var p := person(id)
	if p.is_empty(): return ""
	if clicked and accessible(id,125):
		if p.debt>0 and game.inventory.wallet>=2:
			game.inventory.wallet -= 2
			p.money += 2
			p.debt -= 1
			change_relation(id,PLAYER,8,10)
			p.mood.joy = minf(100,p.mood.joy+15)
			remember(id,"repayment",PLAYER,"你记得还人情，我信得过你。",{"relationships":0.4,"resources":-0.2})
			return "你记得还人情，我信得过你。"
		if now>=float(p.cooldowns.get("chat",-1)):
			change_relation(id,PLAYER,1,0.5)
			p.mood.joy = minf(100,p.mood.joy+4)
			p.cooldowns.chat = now+45
			remember(id,"conversation",PLAYER,"和你聊了几句。",{"relationships":0.05})
	if p.mood.anger>=40: return "今天心烦，有话就直说。"
	if p.mood.fear>=45: return "这会儿风声紧，别把我牵扯进去。"
	if p.debt>0: return "上次我已经帮过你了，手头宽裕了记得还我这个人情。"
	for memory in p.memories:
		if memory.kind in ["gift","repayment"]: return "你上次帮我的事，我还记着。"+p.traits.history
	return p.traits.get("greeting",p.traits.history)

func record_gift(receiver: int, item: String):
	var id := "prisoner:%d" % receiver
	change_relation(id,PLAYER,6,8)
	people[id].mood.joy = minf(100,people[id].mood.joy+12)
	remember(id,"gift",PLAYER,"你送给我"+item+"，这个人情我记着。",{"resources":-0.3,"relationships":0.4})
	express(id,"这个人情，我记下了。")

func record_purchase(id: String):
	change_relation(id,PLAYER,1,3)
	remember(id,"purchase",PLAYER,"做成了一笔交易。",{"resources":0.1,"relationships":0.1})

func express(id: String, line: String):
	var p := person(id)
	p.line = line
	p["activity"] = {"help":"帮了你","share":"分享情报","warn":"提醒你","report":"报告看守","ignore":"装作没看见","refuse":"拒绝帮忙"}.get(p.last_decision.get("action",""),"与你交谈")
	p.line_until = now+5
	if not game.dialogue or not game.dialogue.panel.visible: game.show_status(p.name+"：“"+line+"”",5)

func update_needs(p: Dictionary):
	if p.role in ["player","prisoner"]:
		var values: Dictionary = game.attributes.values[p.node.actor_id]
		p.needs.hunger = 100-values.fullness
		p.needs.fatigue = 100-values.stamina
	else:
		p.needs.fatigue = 35.0 if game.workshop.on_duty() else 15.0
	p.mood.pressure = clampf(p.needs.fatigue*0.35+p.needs.hunger*0.25+p.mood.fear*0.5,0,100)

func witness(id: String):
	var p := person(id)
	if not accessible(id,180) or p.node.confined or game.schedule.is_sleeping(p.node.actor_id): return
	var violation: bool = game.workshop.outside_violation(0) or (game.schedule.is_curfew() and not game.schedule.in_dormitory(0))
	if not violation: return
	if now<float(p.cooldowns.get("witness",0)): return
	var can_report: bool = game.guard.visible and not game.guard.escaped and p.node.position.distance_to(game.guard.position)<=240 and game.world.line_clear(p.node.position,game.guard.position) and game.guard.pursuit_allowed(game.actors[0])
	p.mood.fear = minf(100,p.mood.fear+10*p.traits.caution)
	var choice := decide(id,"witness",[
		{"id":"warn","self":0.0,"impact":{"safety":0.7,"information":0.4},"fit":p.traits.generosity*0.8-p.traits.loyalty*0.2,"emotion":-p.mood.fear/300,"probability":0.3,"loss":0.5,"cost":0.1},
		{"id":"report","available":can_report,"self":0.35,"impact":{"safety":-0.8,"freedom":-0.5,"relationships":-0.3},"fit":p.traits.loyalty*0.7+p.traits.ambition*0.7-p.traits.generosity*0.7,"emotion":p.mood.fear/200,"probability":0.15,"loss":0.6,"cost":0.2},
		{"id":"ignore","self":0.15,"fit":p.traits.caution*0.25,"emotion":p.mood.fear/200,"routine":0.2}])
	p.cooldowns.witness = now+20
	var line := "我没看见，别把我牵扯进去。"
	if choice.action=="warn": line = "你现在不该在这里，赶快回去，小心看守！"
	elif choice.action=="report":
		if not game.guard.receive_tip(p.node,game.actors[0].position): return
		line = "看守，有人没按规矩待在该待的地方！"
		change_relation(id,PLAYER,-4,-5,5)
		change_relation("guard:patrol",id,2,4)
		remember("guard:patrol","received_report",id,"听到了"+p.name+"的现场报告。",choice.impact)
	remember(id,choice.action,PLAYER,line,choice.impact)
	express(id,line)

func tick(delta: float):
	if game.phase!="playing" or game.get_tree().paused or (game.tutorial and game.tutorial.active): return
	now += maxf(delta,0)
	think_timer -= maxf(delta,0)
	if think_timer>0: return
	think_timer = 1.0
	var step := now-last_thought
	last_thought = now
	thought_cycles += 1
	register_people()
	for id in people:
		var p: Dictionary = people[id]
		if not is_instance_valid(p.node): continue
		update_needs(p)
		p.mood.joy = move_toward(p.mood.joy,10,0.3*step)
		p.mood.anger = move_toward(p.mood.anger,0,0.4*step)
		p.mood.fear = move_toward(p.mood.fear,0,0.3*step)
		if p.needs.hunger>70: p.mood.anger = minf(100,p.mood.anger+0.8*step)
		if p.role=="prisoner" and not (game.dialogue and game.dialogue.panel.visible):
			witness(id)
			if free_to_help(id) and accessible(id,125) and relation(id).like>=10 and game.attributes.values[0].fullness<40 and now>=float(p.cooldowns.get("help",0)):
				request_help(id)
	peer_conversation()
	revision += 1

func peer_conversation():
	for actor in game.actors.slice(1):
		var p := person(str(actor.get_meta("social_id","")))
		if p.is_empty(): continue
		if p.busy_until>0 and now>=p.busy_until and not game.dialogue.holds_movement(actor) and not game.skills.actions.has(actor.actor_id):
			if actor.action_state=="chatting": actor.action_state = "idle"
			p.busy_until = 0
	if game.dialogue and game.dialogue.panel.visible: return
	var a := person("prisoner:1")
	var b := person("prisoner:2")
	if a.is_empty() or b.is_empty() or not free_to_help(a.id) or not free_to_help(b.id): return
	if a.node.action_state!="idle" or b.node.action_state!="idle" or game.orders.active.has(1) or game.orders.active.has(2): return
	if now<float(a.cooldowns.get("peer",0)) or a.node.position.distance_to(b.node.position)>90 or not game.world.line_clear(a.node.position,b.node.position): return
	for pair in [[a,b],[b,a]]:
		var p: Dictionary = pair[0]
		var other: Dictionary = pair[1]
		p.cooldowns.peer = now+90
		p.busy_until = now+2
		p.node.action_state = "chatting"
		p.node.facing = p.node.position.direction_to(other.node.position)
		p.mood.joy = minf(100,p.mood.joy+5)
		change_relation(p.id,other.id,1,0.5)
		remember(p.id,"peer_chat",other.id,"和"+other.name+"聊了几句。")

func snapshot() -> Dictionary:
	var result := {}
	for id in people:
		result[id] = people[id].duplicate(true)
		result[id].erase("node")
	return {"people":result,"knowledge":knowledge.duplicate(true),"evaluations":evaluations,"thought_cycles":thought_cycles,"now":now}
