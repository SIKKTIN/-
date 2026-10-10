extends RefCounted

const SLOTS := [
	{"id":"morning_work","label":"09–12","start":540,"end":720},
	{"id":"meal_rest","label":"12–14","start":720,"end":840},
	{"id":"afternoon_work","label":"14–17","start":840,"end":1020},
	{"id":"free_time","label":"17–20","start":1020,"end":1200},
	{"id":"dorm_free","label":"20–24","start":1200,"end":1440}
]
const NAMES := {"idle":"待命","work":"工作","rest":"休息","free":"自由活动","meal":"吃饭"}
var game
var day := 1
var slot := -1
var plans: Array = []
var records: Dictionary = {}
var manual: Dictionary = {}
var morning_pending := true
var work_minutes: Array = [0.0, 0.0, 0.0]
var work_rounds: Array = [0, 0, 0]
var work_earned: Array = [0, 0, 0]
var work_account_clock := 0.0
var recent_wages: Dictionary = {}
const MEAL_MINUTES := 20.0
var meal_minutes: Array = [0.0, 0.0, 0.0]

func _init(owner_game) -> void:
	game = owner_game
	reset()

func reset() -> void:
	day = 1
	morning_pending = true
	work_minutes = [0.0, 0.0, 0.0]
	work_rounds = [0, 0, 0]
	work_earned = [0, 0, 0]
	work_account_clock = 0.0
	recent_wages.clear()
	meal_minutes = [0.0, 0.0, 0.0]
	slot = -1
	plans = default_plans()
	records.clear()
	manual.clear()
	if game.get("routine_panel"):
		game.routine_panel.close()

func default_plans() -> Array:
	var labor := "work" if allowed(0,"work") else "rest"
	var lunch := "meal" if has_cafeteria() else "rest"
	var result := []
	for id in range(3): result.append([labor,lunch,labor,"free","free"])
	return result

func current_slot() -> int:
	var minute: float = game.schedule.clock_minutes()
	if game.schedule.preparing_for_work(): return 0
	for index in range(SLOTS.size()):
		if minute >= SLOTS[index].start and minute < SLOTS[index].end:
			return index
	return -1

func allowed(index: int, kind: String) -> bool:
	if kind == "meal":
		return index == 1 and has_cafeteria()
	return NAMES.has(kind) and (kind != "work" or (index in [0,2] and not game.room_config.get("routine_points",{}).get("work",[]).is_empty()))

func has_cafeteria() -> bool:
	var points: Dictionary = game.room_config.get("routine_points",{})
	return points.get("meal",[]).size() >= 3 and points.get("dine",[]).size() >= 3

func apply_today(value: Array) -> bool:
	if value.size() != 3 or game.schedule.is_sleep_time():
		return false
	for id in range(value.size()):
		var row: Array = value[id]
		if not game.actor_is_controllable(id) and row != plans[id]: return false
		if row.size() != SLOTS.size():
			return false
		for index in range(SLOTS.size()):
			if not allowed(index,str(row[index])):
				return false
	var changed := []
	for id in range(3):
		if slot >= 0 and plans[id][slot] != value[id][slot]:
			changed.append(id)
	plans = value.duplicate(true)
	for id in changed:
		resume(id)
	game.show_status("第%d天主角日常已安排；其他囚徒按默认日程生活。" % day,4)
	return true

func take_control(actor_id: int) -> void:
	if not game.actor_is_controllable(actor_id): return
	suspend(actor_id)

func suspend(actor_id: int) -> void:
	# Custody can suspend any routine; player input can take over only the lead.
	manual[actor_id] = true
	records.erase(actor_id)
	if game.orders.active.has(actor_id) and game.orders.active[actor_id].get("source","") == "routine":
		game.orders.stop(actor_id)

func resume(actor_id: int) -> void:
	manual.erase(actor_id)
	records.erase(actor_id)
	if game.phase == "playing" and slot >= 0:
		_start(actor_id)

func _target(actor_id: int, kind: String) -> Vector2:
	if kind == "free" and slot == 3 and game.schedule.clock_minutes() >= 1160:
		return game.actors[actor_id].home
	var points: Array = game.room_config.get("routine_points",{}).get(kind,[])
	if kind in ["work","meal"] or (kind == "free" and slot != 4 and not points.is_empty()):
		var coords: Array = points[actor_id % points.size()]
		return game.world.routine_destination(Vector2(coords[0],coords[1])) if kind=="free" else Vector2(coords[0],coords[1])
	return game.actors[actor_id].home

func preparing_afternoon() -> bool:
	var minute: float = game.schedule.clock_minutes()
	return minute >= 810 and minute < 840

func consume_meal(actor_id: int, minutes: float) -> float:
	# Called by the attribute integrator only for actual seated meal time.
	var credit: float = minf(maxf(minutes,0),maxf(0,MEAL_MINUTES-float(meal_minutes[actor_id])))
	meal_minutes[actor_id] += credit
	return credit

func _start(actor_id: int, override_kind: String = "") -> void:
	var actor = game.actors[actor_id]
	if actor.escaped or actor.confined or slot < 0 or manual.has(actor_id):
		return
	var kind: String = str(plans[actor_id][slot]) if override_kind.is_empty() else override_kind
	if slot == 1 and preparing_afternoon() and plans[actor_id][2] == "work" and override_kind.is_empty():
		kind = "work"
	elif kind == "meal" and float(meal_minutes[actor_id]) >= MEAL_MINUTES-0.000001:
		kind = "free"
	if kind == "idle":
		return
	game.orders.stop(actor_id)
	game.skills.cancel(actor_id)
	var goal := _target(actor_id,kind)
	var record := {"kind":kind,"goal":goal,"status":"moving","retry":game.elapsed+3.0}
	if kind == "meal":
		record["meal_stage"] = "pickup"
	records[actor_id] = record
	_send(actor_id,record)

func _send(actor_id: int, record: Dictionary) -> void:
	var actor = game.actors[actor_id]
	var goal: Vector2 = record.goal
	record.retry = game.elapsed+3.0
	if actor.position.distance_to(goal) <= 12:
		record.status = "arrived"
	else:
		# Leave a closing room first, even when the next destination is locked.
		var exit: Variant = game.room_access.exit_goal(actor) if game.room_access else null
		if game.orders.issue(actor_id,exit if exit is Vector2 else goal,"routine"):
			record.status = "moving"
			return
		record.status = "blocked"
		game.show_status("伙伴%d的%s路线受阻，请手动开路或改安排。" % [actor_id+1,NAMES[record.kind]],4)
		return

func is_eating(actor_id: int) -> bool:
	if game.phase != "playing" or current_slot() != 1 or slot != 1 or manual.has(actor_id) or not records.has(actor_id):
		return false
	var actor = game.actors[actor_id]
	var record: Dictionary = records[actor_id]
	return float(meal_minutes[actor_id]) < MEAL_MINUTES-0.000001 and record.kind == "meal" and record.get("meal_stage","") == "dine" and not actor.escaped and actor.action_state == "idle" and not game.orders.active.has(actor_id) and actor.position.distance_to(record.goal) <= 12

func carries_meal(actor_id: int) -> bool:
	return current_slot() == 1 and records.has(actor_id) and records[actor_id].kind == "meal" and records[actor_id].get("meal_stage","") == "dine" and not manual.has(actor_id)

func meal_reason(actor_id: int) -> String:
	if not has_cafeteria() or current_slot() != 1 or game.phase != "playing":
		return "食堂供应午餐的时间为12:00–14:00。"
	if float(meal_minutes[actor_id]) >= MEAL_MINUTES-0.000001:
		return "今天的午餐已吃完，可以自由活动。"
	var actor = game.actors[actor_id]
	if actor.escaped or (records.has(actor_id) and records[actor_id].kind == "meal"):
		return "当前伙伴已在取餐或用餐。"
	for coords in game.room_config.routine_points.meal:
		var point := Vector2(coords[0],coords[1])
		if actor.position.distance_to(point) <= 75 and game.world.line_clear(actor.position,point):
			return ""
	return "靠近取餐窗口后领取午餐。"

func start_meal(actor_id: int) -> bool:
	if not game.actor_is_controllable(actor_id): return false
	var reason := meal_reason(actor_id)
	if not reason.is_empty():
		game.show_status(reason)
		return false
	manual.erase(actor_id)
	_start(actor_id,"meal")
	if records.has(actor_id): records[actor_id]["player_meal"] = true
	game.show_status("伙伴%d领取午餐，前往饭桌用餐。" % (actor_id+1),3)
	return true

func tick() -> void:
	if game.phase != "playing" or game.schedule.remaining() <= 0:
		return
	var next_slot := current_slot()
	if next_slot >= 0 and game.schedule.day_number() != day:
		for id in records.keys():
			if game.orders.active.has(id) and game.orders.active[id].get("source","") == "routine":
				game.orders.stop(id)
		day = game.schedule.day_number()
		morning_pending = true
		meal_minutes = [0.0, 0.0, 0.0]
		plans = default_plans()
		records.clear()
		manual.clear()
		slot = -1
		game.show_status("第%d天开始：安排今天的工作与活动。" % day,5)
	if slot != next_slot:
		for id in records.keys():
			if game.orders.active.has(id) and game.orders.active[id].get("source","") == "routine":
				game.orders.stop(id)
		records.clear()
		manual.clear()
		slot = next_slot
		for id in range(3):
			_start(id)
	for id in records.keys():
		var record: Dictionary = records[id]
		if slot == 1 and preparing_afternoon() and plans[id][2] == "work" and record.kind != "work" and not record.get("player_meal",false):
			_start(id,"work")
			record = records[id]
		elif record.kind == "meal" and float(meal_minutes[id]) >= MEAL_MINUTES-0.000001:
			_start(id,"free")
			record = records[id]
		# Default free routines leave enough travel time to obey 20:00 curfew.
		# A manually controlled lead retains the chosen route.
		if slot == 3 and record.kind == "free" and record.goal != _target(id,"free"):
			_start(id)
			record = records[id]
		if game.actors[id].escaped:
			records.erase(id)
			continue
		if game.actors[id].position.distance_to(record.goal) <= 12 and not game.orders.active.has(id):
			record.status = "arrived"
			if record.kind == "meal" and record.get("meal_stage","") == "pickup":
				record.meal_stage = "dine"
				var seats: Array = game.room_config.get("routine_points",{}).get("dine",[])
				record.goal = Vector2(seats[id % seats.size()][0],seats[id % seats.size()][1])
				_send(id,record)
			elif record.kind == "meal":
				game.actors[id].facing = Vector2.UP
		elif not game.orders.active.has(id) and game.elapsed >= record.retry:
			_send(id,record) # Retain the already collected meal when a route retries.
	offer_morning()

func offer_morning() -> void:
	# Daily plans keep running, but the retired planner must not pause a day.
	morning_pending = false

func is_lawful(actor_id: int) -> bool:
	if game.prison_alert != null and game.prison_alert.active:
		return false
	if slot < 0 or game.schedule.is_curfew() or manual.has(actor_id) or not records.has(actor_id):
		return false
	var r: Dictionary = records[actor_id]
	if game.actors[actor_id].action_state != "idle" or game.actors[actor_id].escaped:
		return false
	if game.actors[actor_id].position.distance_to(r.goal) <= 12:
		return true
	if r.status == "blocked":
		return true
	return game.orders.active.has(actor_id) and game.orders.active[actor_id].get("source","") == "routine" and game.orders.active[actor_id].goal == r.goal

func work_duration() -> float:
	return clampf(float(game.room_config.get("work_pay", {}).get("minutes_per_round", 60)), 1, 240)

func work_wage() -> int:
	return clampi(int(game.room_config.get("work_pay", {}).get("wage", 4)), 1, 1000)

func is_working(actor_id: int) -> bool:
	if game.schedule.preparing_for_work(): return false
	if game.phase != "playing" or slot not in [0, 2] or current_slot() != slot or manual.has(actor_id) or not records.has(actor_id):
		return false
	var actor = game.actors[actor_id]
	var record: Dictionary = records[actor_id]
	if game.attributes and game.attributes.values[actor_id].stamina <= 0.000001:
		return false
	return record.kind == "work" and plans[actor_id][slot] == "work" and allowed(slot, "work") and not actor.escaped and actor.action_state == "idle" and not game.orders.active.has(actor_id) and actor.position.distance_to(record.goal) <= 12

func working_ids() -> Array:
	return range(3).filter(func(id): return is_working(id))

func work_progress(actor_id: int) -> float:
	return clampf(float(work_minutes[actor_id])/work_duration(), 0, 1)

func accrue_work(begin_clock: float, end_clock: float, workers: Array, work_credit: Dictionary = {}) -> void:
	if game.phase != "playing" or game.get_tree().paused or not is_finite(begin_clock) or not is_finite(end_clock) or end_clock <= begin_clock:
		return
	var start: float = maxf(begin_clock, work_account_clock)
	if end_clock <= start:
		return
	# Consume every actual clock interval once, even when nobody was working.
	work_account_clock = end_clock
	var begin: float = float(game.schedule.config.start_minutes)+start/game.schedule.day_seconds*1440.0
	var end: float = float(game.schedule.config.start_minutes)+end_clock/game.schedule.day_seconds*1440.0
	var minute: float = fposmod(begin, 1440)
	var shift_end: float = game.schedule.work_window(minute).y
	if shift_end < 0:
		return
	var actual_minutes: float = maxf(0, minf(end, floorf(begin/1440)*1440+shift_end)-begin)
	var duration := work_duration()
	var wage := work_wage()
	var paid := 0
	var paid_names := PackedStringArray()
	for id in range(3):
		if id not in workers:
			continue
		var total: float = float(work_minutes[id])+float(work_credit.get(id,0) if game.attributes else actual_minutes)
		var rounds := floori((total+0.0000001)/duration)
		work_minutes[id] = maxf(0, total-rounds*duration)
		if rounds <= 0:
			continue
		var amount: int = rounds*wage
		work_rounds[id] += rounds
		work_earned[id] += amount
		# NPC income stays in its personal ledger, never the player wallet.
		if not game.actor_is_controllable(id):
			if game.social:
				var p: Dictionary = game.social.person("prisoner:%d" % id)
				if not p.is_empty(): p.money += amount
			continue
		game.inventory.wallet += amount
		recent_wages[id] = {"amount": amount, "until": game.elapsed+2.4}
		paid += amount
		paid_names.append(str(id+1))
	if paid > 0:
		game.show_status("伙伴%s完成工作，工资 +%d。" % ["、".join(paid_names), paid], 3)

func status_for(actor_id: int) -> String:
	if game.room_access and game.room_access.is_held(actor_id): return game.room_access.label_for(actor_id)
	if game.workshop and not game.workshop.warning_label(actor_id).is_empty(): return game.workshop.warning_label(actor_id)
	if manual.has(actor_id) and slot >= 0 and plans[actor_id][slot] != "idle":
		return "手动接管"
	if not records.has(actor_id):
		return ""
	var r: Dictionary = records[actor_id]
	if r.kind == "meal":
		return "路线受阻" if r.status == "blocked" else "用餐 %d/20分" % floori(float(meal_minutes[actor_id])) if is_eating(actor_id) else "前往饭桌" if carries_meal(actor_id) else "前往取餐"
	if r.kind == "work" and game.attributes and game.attributes.values[actor_id].stamina <= 0.000001:
		return "疲惫 · 请休息"
	if r.kind == "work" and (game.schedule.preparing_for_work() or preparing_afternoon()):
		return "前往劳动室" if game.orders.active.has(actor_id) else "到岗待命 · %s点开工" % ("14" if preparing_afternoon() else "8")
	if is_working(actor_id):
		return "工作中 %d%%" % floori(work_progress(actor_id)*100+0.000001)
	return "路线受阻" if r.status == "blocked" else "前往"+NAMES[r.kind] if game.orders.active.has(actor_id) else NAMES[r.kind]+"中"

func snapshot() -> Dictionary:
	return {"day":day,"slot":slot,"plans":plans.duplicate(true),"manual":manual.keys(),"states":game.actors.map(func(a): return status_for(a.actor_id)),"work_minutes":work_minutes.duplicate(),"work_rounds":work_rounds.duplicate(),"work_earned":work_earned.duplicate(),"working":working_ids(),"meal_minutes":meal_minutes.duplicate(),"preparing_afternoon":preparing_afternoon()}
