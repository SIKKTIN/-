extends "res://scripts/presentation/game_presentation.gd"
var profile_times: Dictionary = {}
func tick(delta: float) -> void:
	profile_times.clear()
	var audit_mark: int = Time.get_ticks_usec()
	var view: Rect2 = game.map_camera.world_view_rect() if game.map_camera else game.world.bounds
	for visual in visuals:
		visual.tick_visual(delta,view)
	profile_times["actors"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if dog_visual:
		dog_visual.tick_visual(delta)
	profile_times["dog"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	_tick_scene()
	profile_times["scene"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.items_view:
		game.items_view.tick_visuals()
	profile_times["items"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if lighting:
		lighting.tick()
	profile_times["lighting"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if interaction:
		interaction.refresh()
	profile_times["interaction"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	var now := _state()
	var active: bool = game.phase == "playing" and not game.get_tree().paused and not muted and audio_available
	var chat: bool = game.actors.any(func(a): return a.action_state == "chatting")
	var lock: bool = game.actors.any(func(a): return a.action_state == "lockpicking")
	var push: bool = previous.get("crate",now.crate).distance_squared_to(now.crate) > 0.0001
	_loop("chat_loop",active and chat)
	_loop("lockpick_loop",active and lock)
	_loop("crate_move_loop",active and push)
	if previous.get("deal",now.deal) == now.deal:
		if now.captures > previous.get("captures",now.captures):
			cue("captured")
			for id in range(3):
				if now.immune[id] > previous.get("immune",now.immune)[id]:
					visuals[id].show_event("captured")
		if now.guard == "chasing" and previous.get("guard",now.guard) != "chasing":
			cue("detected")
		if now.door and not previous.get("door",now.door):
			cue("door_open")
		var old_escaped: Array = previous.get("escaped",now.escaped)
		for index in range(3):
			if now.escaped[index] and not old_escaped[index]:
				cue("escaped")
		if now.phase == "complete" and previous.get("phase",now.phase) != "complete":
			cue("complete")
		for id in previous.get("actions",{}):
			if not now.actions.has(id) and (previous.actions[id].kind != "lockpick" or not now.door) and not now.escaped[id] and now.captures == previous.get("captures",now.captures):
				cue("cancelled")
				visuals[id].show_event("cancelled")
	previous = now
	profile_times["audio"]=(Time.get_ticks_usec()-audit_mark)/1000.0
