extends RefCounted

const SLOTS := [
	{"id":"morning_work","label":"08–12","start":480,"end":720},
	{"id":"meal_rest","label":"12–14","start":720,"end":840},
	{"id":"afternoon_work","label":"14–18","start":840,"end":1080},
	{"id":"free_time","label":"18–20","start":1080,"end":1200},
	{"id":"dorm_free","label":"20–24","start":1200,"end":1440}
]
const NAMES := {"idle":"待命","work":"工作","rest":"休息","free":"自由活动"}
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
	slot = -1
	plans = []
	for index in range(3):
		plans.append(["idle","idle","idle","idle","idle"])
	records.clear()
	manual.clear()
	if game.get("routine_panel"):
		game.routine_panel.close()

func current_slot() -> int:
	var minute: float = game.schedule.clock_minutes()
	for index in range(SLOTS.size()):
		if minute >= SLOTS[index].start and minute < SLOTS[index].end:
			return index
	return -1

func allowed(index: int, kind: String) -> bool:
	return NAMES.has(kind) and (kind != "work" or (index in [0,2] and not game.room_config.get("routine_points",{}).get("work",[]).is_empty()))

func apply_today(value: Array) -> bool:
	if value.size() != 3 or game.schedule.is_sleep_time():
		return false
	for row in value:
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
	game.show_status("第%d天日常已安排；手动行动可接管，下一时段按表继续。" % day,4)
	return true

func take_control(actor_id: int) -> void:
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
	var points: Array = game.room_config.get("routine_points",{}).get(kind,[])
	if kind == "work" or (kind == "free" and slot != 4 and not points.is_empty()):
		var coords: Array = points[actor_id % points.size()]
		return Vector2(coords[0],coords[1])
	return game.actors[actor_id].home

func _start(actor_id: int) -> void:
	var actor = game.actors[actor_id]
	if actor.escaped or slot < 0 or manual.has(actor_id):
		return
	var kind: String = plans[actor_id][slot]
	if kind == "idle":
		return
	game.orders.stop(actor_id)
	game.skills.cancel(actor_id)
	var goal := _target(actor_id,kind)
	var record := {"kind":kind,"goal":goal,"status":"moving","retry":game.elapsed+3.0}
	records[actor_id] = record
	if actor.position.distance_to(goal) <= 12:
		record.status = "arrived"
	elif not game.orders.issue(actor_id,goal,"routine"):
		record.status = "blocked"
		game.show_status("伙伴%d的%s路线受阻，请手动开路或改安排。" % [actor_id+1,NAMES[kind]],4)

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
		plans.clear()
		for id in range(3):
			plans.append(["idle","idle","idle","idle","idle"])
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
		if game.actors[id].escaped:
			records.erase(id)
			continue
		if game.actors[id].position.distance_to(record.goal) <= 12 and not game.orders.active.has(id):
			record.status = "arrived"
		elif not game.orders.active.has(id) and game.elapsed >= record.retry:
			_start(id) # A blocked route retries at most once every three seconds.
	offer_morning()

func offer_morning() -> void:
	# The first routine tick precedes the UI's construction. Keep the request
	# pending until both panels exist; each new arrangement day gets one offer.
	if not morning_pending or game.phase != "playing" or game.schedule.remaining() <= 0 or current_slot() < 0:
		return
	if game.routine_panel == null or game.fullscreen_ui == null:
		return
	if game.routine_panel.panel.visible:
		game.routine_panel.reload()
	else:
		game.routine_panel.open()
	if game.routine_panel.panel.visible:
		morning_pending = false

func is_lawful(actor_id: int) -> bool:
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
	if game.phase != "playing" or slot not in [0, 2] or current_slot() != slot or manual.has(actor_id) or not records.has(actor_id):
		return false
	var actor = game.actors[actor_id]
	var record: Dictionary = records[actor_id]
	return record.kind == "work" and plans[actor_id][slot] == "work" and allowed(slot, "work") and not actor.escaped and actor.action_state == "idle" and not game.orders.active.has(actor_id) and actor.position.distance_to(record.goal) <= 12

func working_ids() -> Array:
	return range(3).filter(func(id): return is_working(id))

func work_progress(actor_id: int) -> float:
	return clampf(float(work_minutes[actor_id])/work_duration(), 0, 1)

func accrue_work(begin_clock: float, end_clock: float, workers: Array) -> void:
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
	var shift_end: float = 720.0 if minute >= 480 and minute < 720 else 1080.0 if minute >= 840 and minute < 1080 else -1.0
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
		var total: float = float(work_minutes[id])+actual_minutes
		var rounds := floori((total+0.0000001)/duration)
		work_minutes[id] = maxf(0, total-rounds*duration)
		if rounds <= 0:
			continue
		var amount: int = rounds*wage
		work_rounds[id] += rounds
		work_earned[id] += amount
		game.inventory.wallet += amount
		recent_wages[id] = {"amount": amount, "until": game.elapsed+2.4}
		paid += amount
		paid_names.append(str(id+1))
	if paid > 0:
		game.show_status("伙伴%s完成工作，工资 +%d。" % ["、".join(paid_names), paid], 3)

func status_for(actor_id: int) -> String:
	if manual.has(actor_id) and slot >= 0 and plans[actor_id][slot] != "idle":
		return "手动接管"
	if not records.has(actor_id):
		return ""
	var r: Dictionary = records[actor_id]
	if is_working(actor_id):
		return "工作中 %d%%" % floori(work_progress(actor_id)*100+0.000001)
	return "路线受阻" if r.status == "blocked" else "前往"+NAMES[r.kind] if game.orders.active.has(actor_id) else NAMES[r.kind]+"中"

func snapshot() -> Dictionary:
	return {"day":day,"slot":slot,"plans":plans.duplicate(true),"manual":manual.keys(),"states":game.actors.map(func(a): return status_for(a.actor_id)),"work_minutes":work_minutes.duplicate(),"work_rounds":work_rounds.duplicate(),"work_earned":work_earned.duplicate(),"working":working_ids()}
