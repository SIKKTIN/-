extends "res://scripts/presentation/game_presentation.gd"
var profile_times: Dictionary={}
func tick(delta: float) -> void:
	var qa_stamp: int=Time.get_ticks_usec()
	profile_times.clear()
	var view: Rect2 = game.map_camera.world_view_rect() if game.map_camera else game.world.bounds
	profile_times["var view: Rect2 = game.map_camera.world_view_rect() if game.map_camera else game.world.bounds"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	for visual in visuals:
		visual.tick_visual(delta,view)
	profile_times["for visual in visuals:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if dog_visual:
		dog_visual.tick_visual(delta)
	profile_times["if dog_visual:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	_tick_scene()
	profile_times["_tick_scene()"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.items_view:
		game.items_view.tick_visuals()
	profile_times["if game.items_view:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if lighting:
		lighting.tick()
	profile_times["if lighting:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if interaction:
		interaction.refresh()
	profile_times["if interaction:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	var now := _state()
	profile_times["var now := _state()"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	var active: bool = game.phase == "playing" and not game.get_tree().paused and not muted and audio_available
	profile_times["var active: bool = game.phase == \"playing\" and not game.get_tree().paused and not muted and audio_available"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	var chat: bool = game.actors.any(func(a): return a.action_state == "chatting")
	profile_times["var chat: bool = game.actors.any(func(a): return a.action_state == \"chatting\")"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	var lock: bool = game.actors.any(func(a): return a.action_state == "lockpicking")
	profile_times["var lock: bool = game.actors.any(func(a): return a.action_state == \"lockpicking\")"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	var push: bool = previous.get("crate",now.crate).distance_squared_to(now.crate) > 0.0001
	profile_times["var push: bool = previous.get(\"crate\",now.crate).distance_squared_to(now.crate) > 0.0001"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	_loop("chat_loop",active and chat)
	profile_times["_loop(\"chat_loop\",active and chat)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	_loop("lockpick_loop",active and lock)
	profile_times["_loop(\"lockpick_loop\",active and lock)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	_loop("crate_move_loop",active and push)
	profile_times["_loop(\"crate_move_loop\",active and push)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
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
	profile_times["if previous.get(\"deal\",now.deal) == now.deal:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	previous = now
	profile_times["previous = now"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
