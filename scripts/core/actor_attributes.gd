extends RefCounted

var game
var config: Dictionary
var values: Array = []
var account_clock := 0.0

func _init(owner_game) -> void:
	game = owner_game
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/attributes.json"))
	reset()

func reset() -> void:
	values.clear()
	for id in range(3):
		values.append({"stamina":float(config.initial_stamina),"fullness":float(config.initial_fullness)})
	account_clock = 0.0

func work_efficiency(id: int) -> float:
	if values[id].stamina <= 0.000001:
		return 0.0
	return (0.7 if values[id].stamina < config.low_threshold else 1.0)*(0.65 if values[id].fullness < config.low_threshold else 1.0)

func move_efficiency(id: int) -> float:
	return (0.55 if values[id].stamina <= 0 else 0.8 if values[id].stamina < config.low_threshold else 1.0)*(0.8 if values[id].fullness < config.low_threshold else 1.0)

func behaviors() -> Array:
	var result := []
	for actor in game.actors:
		var kind := "idle"
		if actor.escaped:
			kind = "escaped"
		elif game.schedule.is_sleeping(actor.actor_id):
			kind = "sleep"
		elif actor.action_state == "chatting":
			kind = "chat"
		elif actor.action_state != "idle":
			kind = "skill"
		elif game.routines.is_eating(actor.actor_id):
			kind = "meal"
		elif game.routines.is_working(actor.actor_id):
			kind = "work"
		elif actor.moved_this_frame:
			kind = "move"
		elif not game.orders.active.has(actor.actor_id) and actor.position.distance_to(actor.home) <= 28:
			kind = "rest"
		result.append(kind)
	return result

func accrue(begin_clock: float, end_clock: float, states: Array) -> Dictionary:
	var work := {}
	if game.phase != "playing" or game.get_tree().paused or not is_finite(begin_clock) or not is_finite(end_clock) or end_clock <= begin_clock:
		return work
	var start: float = maxf(begin_clock,account_clock)
	if end_clock <= start:
		return work
	account_clock = end_clock
	var begin: float = float(game.schedule.config.start_minutes)+start/game.schedule.day_seconds*1440.0
	var end: float = float(game.schedule.config.start_minutes)+end_clock/game.schedule.day_seconds*1440.0
	var initial_minute := fposmod(begin,1440.0)
	var work_end: float = game.schedule.work_window(initial_minute).y
	work_end = floorf(begin/1440.0)*1440.0+work_end if work_end >= 0 else -1.0
	# Integrate at game-minute boundaries so a long frame cannot work beyond
	# exhaustion or credit a whole interval at its starting efficiency.
	while begin < end-0.0000001:
		var stop: float = minf(end,floorf(begin+0.0000001)+1.0)
		var minutes: float = stop-begin
		var minute := fposmod(begin+minutes/2,1440.0)
		for id in range(3):
			var kind: String = str(states[id])
			if kind == "escaped":
				continue
			var state: Dictionary = values[id]
			state.fullness -= float(config.fullness_drain_per_minute)*minutes
			if kind == "work" and begin < work_end:
				var labor: float = minf(minutes,maxf(0,work_end-begin))
				# The last fraction of a work minute cannot consume negative stamina.
				labor = minf(labor,state.stamina/float(config.work_stamina_per_minute))
				work[id] = float(work.get(id,0))+labor*work_efficiency(id)
				state.stamina -= float(config.work_stamina_per_minute)*labor
				state.fullness -= float(config.work_fullness_extra_per_minute)*labor
			elif kind == "move":
				state.stamina -= float(config.move_stamina_per_minute)*minutes
			elif kind in ["skill","chat"]:
				state.stamina -= float(config.chat_stamina_per_minute if kind == "chat" else config.skill_stamina_per_minute)*minutes
			elif kind == "rest":
				state.stamina += float(config.rest_stamina_per_minute)*minutes
				if not game.routines.has_cafeteria() and minute >= 720 and minute < 840:
					state.fullness += float(config.meal_fullness_per_minute)*game.routines.consume_meal(id,minutes)
			elif kind == "meal" and minute >= 720 and minute < 840:
				var eating: float = game.routines.consume_meal(id,minutes)
				state.stamina += float(config.rest_stamina_per_minute)*eating
				state.fullness += float(config.meal_fullness_per_minute)*eating
			elif kind == "sleep":
				state.stamina += float(config.sleep_stamina_per_minute)*minutes
			state.stamina = clampf(state.stamina,0,100)
			state.fullness = clampf(state.fullness,0,100)
		begin = stop
	return work

func skip_sleep(begin_clock: float, end_clock: float) -> void:
	accrue(begin_clock,end_clock,game.actors.map(func(actor): return "escaped" if actor.escaped else "sleep"))

func snapshot() -> Dictionary:
	return {"values":values.duplicate(true),"account_clock":account_clock}
