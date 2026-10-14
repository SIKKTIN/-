extends RefCounted

# Stateless lifecycle coordinator. Frame/input stay in EscapeGame.
# Service reset order is intentional: do not iterate unordered component maps.

static func reset_round(game, fixed_skills: Array = [], seed_value: int = -1) -> void:
	_reset_controls(game)
	_reset_actors(game,fixed_skills,seed_value)
	_reset_services(game)
	_refresh_reset(game)

static func load_room(game, identifier: String, fixed_skills: Array = [], seed_value: int = -1) -> bool:
	var path := "res://data/rooms/%s.json" % identifier
	if not FileAccess.file_exists(path):
		game.show_status("这个房间还在制作。")
		return false
	if game.nine_point: game.nine_point.close()
	if game.skills:
		game.skills.clear_all()
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	config = preload("res://scripts/items/keycard_service.gd").decorate(config)
	game.room_config = config
	game.room_id = identifier
	preload("res://scripts/presentation/world_texture.gd").release_scene_cache()
	preload("res://scripts/presentation/character_library.gd").prepared_motions.clear()
	preload("res://scripts/presentation/region_terrain.gd").textures.clear()
	preload("res://scripts/presentation/region_terrain.gd").definitions.clear()
	game.world.art_textures.clear()
	game.world.configure(config,game.actors)
	for index in range(game.actors.size()):
		var start: Array = config.starts[index]
		game.actors[index].home = Vector2(start[0],start[1])
	game.guard.configure(game.world,game)
	if game.room_selector:
		var selector_index: int = game.ROOM_IDS.find(identifier)
		if selector_index >= 0:
			game.room_selector.select(selector_index)
	game.reset_round(fixed_skills,seed_value)
	return true

static func capture_actor(game, actor_id: int) -> void:
	if actor_id == game.PLAYER_ACTOR_ID and game.nine_point: game.nine_point.close()
	if actor_id==game.PLAYER_ACTOR_ID and game.looting: game.looting.close()
	if actor_id==game.PLAYER_ACTOR_ID:
		if game.map_viewer: game.map_viewer.close()
		if game.fullscreen_ui:
			game.fullscreen_ui.bag_open = false
			game.fullscreen_ui.refresh_inventory()
	if game.tutorial and game.tutorial.active:
		game.tutorial.on_capture(actor_id)
		return
	if game.phase != "playing" or actor_id < 0 or actor_id >= game.actors.size() or game.actors[actor_id].escaped or game.actors[actor_id].confined: return
	if game.dialogue: game.dialogue.close()
	if game.mobile_controls and game.selected_actor_id == actor_id:
		game.mobile_controls.cancel_input()
	if game.routines:
		game.routines.suspend(actor_id)
	if game.shop_panel and game.shop_panel.actor_id == actor_id:
		game.shop_panel.close()
	var actor = game.actors[actor_id]
	if game.social and actor_id==game.PLAYER_ACTOR_ID: game.social.player_captured(actor.position)
	if game.skills:
		game.skills.cancel(actor_id)
	actor.position = actor.home
	if game.room_access:
		game.room_access.capture(actor_id)
	actor.action_state = "idle"
	actor.immune_until = game.elapsed + 1.0
	actor.queue_redraw()
	game.orders.stop(actor_id)
	game.captures += 1
	if game.room_access and game.room_access.is_held(actor_id):
		game.confinement_counts[actor_id] += 1
		if actor_id == game.PLAYER_ACTOR_ID and game.confinement_counts[actor_id] >= 3:
			game.finish_failure("主角第三次被关禁闭 · 逃脱失败")
	if game.room_access == null or not game.room_access.is_held(actor_id):
		game.show_status("伙伴%d被送回起点；门、箱子、技能和已逃脱伙伴保留。" % (actor_id+1))


static func finish_failure(game, reason: String) -> void:
	if game.phase != "playing": return
	if game.nine_point: game.nine_point.close()
	if game.dialogue: game.dialogue.close()
	if game.looting: game.looting.close()
	game.failure_reason = reason
	game.phase = "failed"
	game.orders.clear()
	game.skills.clear_all()
	for actor in game.actors:
		actor.moved_this_frame = false
	game.guard.moved_this_frame = false
	game.dog.moved_this_frame = false
	game.status_text = reason+"，行动结束。可重新开始。"
	game.schedule.show_result(false)


static func on_actor_escaped(game, actor_id: int) -> void:
	if actor_id == game.PLAYER_ACTOR_ID and game.nine_point: game.nine_point.close()
	if game.tutorial and game.tutorial.active:
		game.actors[actor_id].escaped = false
		game.orders.stop(actor_id)
		game.show_status("入监日先熟悉作息；正式%d天开始后再寻找逃脱机会。" % game.schedule.escape_days,4)
		return
	game.inventory.carry_out(actor_id)
	if game.actors[game.PLAYER_ACTOR_ID].escaped:
		if game.looting: game.looting.close()
		game.phase = "complete"
		game.orders.clear()
		game.skills.clear_all()
		var carried: int = game.inventory.instances.values().filter(func(i): return i.location == "escaped").size()
		game.status_text = "主角逃脱成功！%.1f秒 · 抓回%d次 · 带出%d件 · 钱%d · R重开" % [game.elapsed,game.captures,carried,game.inventory.wallet]
		if game.schedule:
			game.schedule.show_result(true)


static func _reset_controls(game) -> void:
	if game.nine_point: game.nine_point.reset()
	if game.looting: game.looting.close()
	if game.map_viewer: game.map_viewer.reset()
	if game.quick_items: game.quick_items.reset()
	if game.tutorial: game.tutorial.cancel()
	if game.fullscreen_ui:
		game.fullscreen_ui.close_menu()
		game.fullscreen_ui.bag_open = false
	if game.mobile_controls:
		game.mobile_controls.cancel_input()

static func _reset_actors(game,fixed_skills: Array,seed_value: int) -> void:
	game.phase = "playing"
	game.elapsed = 0
	game.status_until = 0
	game.captures = 0
	var counts: Array[int] = [0,0,0]
	game.confinement_counts = counts
	game.failure_reason = ""
	if game.dialogue: game.dialogue.close()
	game.deal_number += 1
	game.deal_seed = randi() if seed_value < 0 else seed_value
	var random := RandomNumberGenerator.new()
	random.seed = game.deal_seed
	var choices: Array = game.room_config.get("skill_pool", ["chat","lockpick","strong"])
	if game.skills:
		game.skills.clear_all()
	if game.orders:
		game.orders.clear()
	for actor in game.actors:
		actor.reset_actor()
		actor.skill_id = str(fixed_skills[actor.actor_id]) if fixed_skills.size() == 3 else choices[random.randi_range(0,choices.size()-1)]

static func _reset_services(game) -> void:
	if game.inventory:
		game.inventory.reset(game.room_config)
	if game.trade:
		game.trade.reset(game.room_config)
	if game.shop_panel:
		game.shop_panel.close()
	if game.inventory_panel:
		game.inventory_panel.selected_item = ""
	if game.staff_traffic:
		game.staff_traffic.reset()
	if game.prison_alert:
		game.prison_alert.reset()
	if game.world:
		game.world.reset_world()
	if game.keycards: game.keycards.reset()
	if game.looting: game.looting.reset()
	if game.room_access:
		game.room_access.reset()
	if game.guard:
		game.guard.reset_guard()
		game.guard_position = game.guard.position
	if game.dog:
		game.dog.reset_dog()
	if game.presentation:
		game.presentation.reset()
	if game.routines:
		game.routines.reset()
	if game.schedule:
		game.schedule.reset()
		if game.tutorial and game.tutorial.completed and game.tutorial.eligible():
			game.schedule.calendar_day_offset = 1
			game.schedule.tick(false)
	if game.room_visibility: game.room_visibility.reset()
	if game.resident_staff: game.resident_staff.reset()
	if game.bath_service: game.bath_service.reset()
	if game.gate_watch:
		game.gate_watch.reset(game.room_config)
	if game.attributes:
		game.attributes.reset()
	if game.workshop:
		game.workshop.reset()
	if game.social: game.social.reset()
	if game.npc_life: game.npc_life.reset()

static func _refresh_reset(game) -> void:
	if game.room_access:
		game.room_access.tick()
	if game.routines:
		game.routines.tick()
	if game.developer_settings:
		game.developer_settings.close()
	game.show_status("你的移动、工作、吃饭和归寝都由你决定；NPC 按各自状态生活。",4)
	game.select_actor(0)
	if game.map_camera:
		game.map_camera.reset()
	if game.tutorial: game.tutorial.on_round_reset()
	game._update_ui()
	game.queue_redraw()

