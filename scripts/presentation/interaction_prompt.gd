extends Node

var game
var presentation
var button: Button
var actor_id: int = -1
var kind: String = ""
var extras: Dictionary = {}
var targets: Array = []
var mobile_target_key := ""
var _mobile_targets: Array = []
var hint
var outline: Sprite2D
var fixture_volumes: Dictionary = {}
var fixture_revision := -1
var pressed_hint_key := ""

func configure(owner_game, owner_presentation) -> void:
	game = owner_game
	presentation = owner_presentation
	button = Button.new()
	button.name = "WorldInteraction"
	button.size = Vector2(64,48)
	button.theme = presentation.mute_button.theme
	button.text = "E"
	button.add_theme_font_size_override("font_size",13)
	button.add_theme_constant_override("icon_max_width",25)
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(activate)
	game.get_node("HUD").add_child(button)
	hint = preload("res://scripts/ui/world_interaction_hint.gd").new()
	hint.name = "NearbyInteractionHint"
	hint.font = presentation.font
	hint.pressed.connect(_activate_hint)
	hint.button_down.connect(func(): pressed_hint_key = hint.target_key)
	hint.button_up.connect(func(): call_deferred("_clear_hint_press"))
	game.get_node("HUD").add_child(hint)
	outline = Sprite2D.new()
	outline.name = "InteractionTargetOutline"
	outline.centered = false
	outline.z_index = 54
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	outline.material = ShaderMaterial.new()
	outline.material.shader = preload("res://scripts/ui/interaction_outline.gdshader")
	game.get_node("HUD").add_child(outline)
	outline.hide()
	refresh()

func refresh() -> void:
	_refresh_targets()
	# Keep valid buttons visible across frames so a held touch can release normally.
	if not targets.any(func(t): return t.button == button):
		button.visible = false
	for b in extras.values():
		if not targets.any(func(t): return t.button == b):
			b.visible = false
	_mobile_targets = targets.duplicate()
	_mobile_targets.sort_custom(func(a,b): return a.distance < b.distance)
	if not _mobile_targets.any(func(t): return _target_key(t) == mobile_target_key):
		mobile_target_key = _target_key(_mobile_targets[0]) if not _mobile_targets.is_empty() else ""
	button.hide()
	for b in extras.values(): b.hide()
	_refresh_hint()

func _clear_hint_press():
	pressed_hint_key = ""

func _activate_hint():
	var key: String = hint.target_key
	if not pressed_hint_key.is_empty() and pressed_hint_key != key: return
	refresh()
	if key != mobile_target_key or not hint.visible or game.world_input_blocked(): return
	activate_mobile()

func _target_name(target: Dictionary) -> String:
	match str(target.kind):
		"recharge": return "浴室收费员"
		"shower": return "公共花洒"
		"loot": return str(game.looting.containers[target.id].fixture.get("loot_name","容器")).replace("私人物品柜","私人柜")
		"talk": return str(target.get("name","NPC"))
		"pickup": return game.inventory.item_name(str(target.id))
		"trade": return str(game.trade.merchants[target.id].get("name","商人"))
		"meal": return "食堂餐台"
		"work": return "劳动工位"
		"latch": return "后勤侧门"
		"card_door": return str(game.keycards.state(str(target.id)).name)
		"dorm_door": return "宿舍门"
		"nine_point": return "棋牌室牌桌"
		"skill": return {"chat":"看守","strong":"重物箱","lockpick":"门锁","lock_tool":"门锁"}.get(kind,"操作目标")
	return "互动目标"

func _target_visual(target: Dictionary) -> Dictionary:
	var anchor: Vector2 = target.button.get_meta("world_anchor",game.actors[actor_id].position+Vector2(0,-70))
	var rect := Rect2(anchor-Vector2(12,0),Vector2(24,12))
	var texture: Texture2D
	var flip_h := false
	var flip_v := false
	if target.kind in ["loot","shower","recharge","nine_point"]:
		if fixture_revision != game.world.fixtures_revision or fixture_volumes.is_empty() or not is_instance_valid(fixture_volumes.get(str(target.id))):
			fixture_revision = game.world.fixtures_revision
			fixture_volumes.clear()
			for volume in presentation.volumes:
				if volume.kind == "fixture": fixture_volumes[str(game.world.fixtures[volume.wall_index].id)] = volume
		var volume = fixture_volumes.get(str(target.id))
		if is_instance_valid(volume):
			rect = volume.display_rect
			texture = game.world.art_textures.get(volume.prop_id())
			var fixture: Dictionary = game.world.fixtures[volume.wall_index]
			flip_h = fixture.get("mirror_x",false)
			flip_v = fixture.get("mirror_y",false)
		elif target.kind=="loot": rect = game.looting.containers[target.id].fixture.rect
	elif target.kind == "pickup":
		var entry: Dictionary = game.inventory.instances[target.id]
		rect = Rect2(Vector2(entry.position[0],entry.position[1])-Vector2(15,15),Vector2(30,30))
	elif target.kind == "card_door":
		var gate: Dictionary=game.keycards.gate(str(target.id))
		if not gate.is_empty(): rect=preload("res://scripts/presentation/doorway_geometry.gd").projected_rect(game.world,gate)
	elif target.kind == "dorm_door":
		var gate: Dictionary = game.room_access.dorm_gate(str(target.id))
		if not gate.is_empty(): rect = game.world.dorm_closure_rect(gate)
	return {"rect":rect,"texture":texture,"flip_h":flip_h,"flip_v":flip_v}

func _refresh_hint():
	if not hint: return
	var target := _mobile_target()
	if target.is_empty() or game.world_input_blocked():
		hint.hide()
		outline.hide()
		return
	var visual := _target_visual(target)
	var transform: Transform2D = game.get_global_transform_with_canvas()
	var rect: Rect2 = transform*visual.rect
	var view: Rect2 = game.map_camera.view_rect() if game.map_camera else game.get_viewport_rect()
	if not view.has_point(rect.get_center()):
		hint.hide()
		outline.hide()
		return
	var actor = game.actors[actor_id]
	var actor_visual = actor.get_node_or_null("ArtVisual")
	var avoid: Array = [rect.grow(2)]
	if actor_visual: avoid.append(transform*Rect2(actor.position+actor_visual.body_bounds().position,actor_visual.body_bounds().size))
	var ui = game.fullscreen_ui
	if ui:
		if ui.button_layout and ui.button_layout.editing:
			hint.hide()
			outline.hide()
			return
		for control in [ui.clock,ui.wallet,ui.menu_button,ui.action_button,ui.ability_button,ui.bag_button,game.mobile_controls.pad,ui.target_button]:
			if is_instance_valid(control) and control.visible: avoid.append(control.get_global_rect().grow(4))
		for card in game.cards:
			if card.visible: avoid.append(card.get_global_rect().grow(4))
		if ui.quick_slots:
			for slot in ui.quick_slots.buttons:
				if slot.visible: avoid.append(slot.get_global_rect().grow(4))
	var action: String = mobile_label().get_slice("\n",1) if target.kind == "talk" else mobile_label()
	if target.kind=="card_door":
		var state: Dictionary=game.keycards.state(str(target.id))
		hint.set_content(str(state.name),str(state.action),mobile_target_key,str(state.status),bool(state.enabled))
	else: hint.set_content(_target_name(target),action,mobile_target_key)
	hint.place(rect,view,avoid)
	hint.show()
	outline.visible = visual.texture != null
	if outline.visible:
		outline.texture = visual.texture
		outline.flip_h = visual.flip_h
		outline.flip_v = visual.flip_v
		outline.position = rect.position
		outline.scale = rect.size/outline.texture.get_size()
		var uv_size := Vector2.ONE
		if outline.texture is AtlasTexture: uv_size = outline.texture.region.size/outline.texture.atlas.get_size()
		outline.material.set_shader_parameter("outline_step",uv_size*3.0/rect.size)

func _target_key(target: Dictionary) -> String:
	return "%d:%s:%s" % [game.selected_actor_id,target.kind,target.id]

func _mobile_target() -> Dictionary:
	for target in _mobile_targets:
		if _target_key(target) == mobile_target_key:
			return target
	return {}

func mobile_target_count() -> int:
	return _mobile_targets.size()

func mobile_available() -> bool:
	var target:=_mobile_target()
	if target.get("kind","")=="card_door" and not game.keycards.state(str(target.id)).enabled: return false
	return not game.world_input_blocked() and not target.is_empty()

func mobile_label() -> String:
	var target := _mobile_target()
	if target.is_empty():
		return "靠近互动"
	if target.kind == "recharge": return "充值水卡"
	if target.kind == "shower": return "中断洗澡" if game.bath_service.sessions.has(game.selected_actor_id) else "洗澡 · %d点" % game.bath_service.cost()
	if target.kind == "talk": return str(target.get("name","NPC"))+"\n聊天"
	if target.kind == "card_door":
		var state: Dictionary=game.keycards.state(str(target.id))
		return str(state.action) if state.enabled else "缺少房卡" if str(state.status).begins_with("需要") else "门禁锁定"
	if target.kind == "dorm_door": return game.room_access.dorm_label(str(target.id))
	if target.kind == "nine_point": return "九点 · 入座"
	if target.kind == "skill":
		return "停止操作" if game.skills.actions.has(game.selected_actor_id) else {"chat":"分散注意","lockpick":"撬锁","strong":"推箱"}.get(kind,"互动")
	return {"loot":"翻找","pickup":"拾取","trade":"购买","meal":"取餐","work":"工作","latch":"开侧门"}.get(target.kind,"互动")

func mobile_icon() -> Texture2D:
	var target := _mobile_target()
	return target.button.icon if not target.is_empty() else null

func cycle_mobile_target() -> void:
	refresh()
	if _mobile_targets.size() < 2:
		return
	for index in range(_mobile_targets.size()):
		if _target_key(_mobile_targets[index]) == mobile_target_key:
			mobile_target_key = _target_key(_mobile_targets[(index+1)%_mobile_targets.size()])
			break
	_refresh_hint()
	if game.fullscreen_ui:
		game.fullscreen_ui.refresh()

func activate_mobile() -> void:
	if game.mobile_controls:
		game.mobile_controls.cancel_input()
	refresh()
	var target := _mobile_target()
	if target.is_empty():
		return
	if target.kind == "skill":
		activate(false)
	else:
		_activate_extra(str(target.kind)+":"+str(target.id))

func _visible_target(target: Dictionary) -> bool:
	var point := Vector2.ZERO
	match str(target.kind):
		"talk":
			var npc: Dictionary = game.dialogue.find_target(str(target.id))
			return not npc.is_empty()
		"work": point = game.routines._target(game.selected_actor_id,"work")
		"pickup":
			var coords: Array = game.inventory.instances[target.id].position
			point = Vector2(coords[0],coords[1])
		"trade": point = game.trade.actors[target.id].interaction_point()
		"meal": point = game.routines._target(game.selected_actor_id,"meal")
		_: return true
	return not game.world.is_under_roof(point)

func _refresh_targets() -> void:
	kind = ""
	targets.clear()
	actor_id = game.selected_actor_id
	if game.world_input_blocked():
		return
	var actor = game.actors[actor_id]
	if actor.escaped:
		return
	_refresh_items(actor)
	_refresh_loot(actor)
	_refresh_bath(actor)
	_refresh_npcs(actor)
	_refresh_nine_point(actor)
	if game.keycards:
		for gate in game.keycards.gates():
			if not game.keycards.nearby(actor,gate): continue
			var area: Rect2=preload("res://scripts/presentation/doorway_geometry.gd").projected_rect(game.world,gate)
			var state: Dictionary=game.keycards.state(str(gate.id))
			var b:=_extra("card_door:"+str(gate.id),str(state.action),area.get_center(),str(state.status))
			targets.append({"button":b,"kind":"card_door","id":gate.id,"distance":actor.position.distance_to(actor.position.clamp(area.position,area.end))})
	for gate in game.world.dorm_gates():
		if gate.get("card_controlled",false): continue
		if not gate.get("manual_door",false) or not game.room_access.dorm_nearby(actor,gate): continue
		var area: Rect2 = game.world.dorm_closure_rect(gate)
		var nearest: Vector2 = actor.position.clamp(area.position,area.end)
		var b := _extra("dorm_door:"+str(gate.id),game.room_access.dorm_label(str(gate.id),gate),area.get_center(),"E 开门 / 关门；夜间门禁锁定，门口有人时不能关闭。")
		targets.append({"button":b,"kind":"dorm_door","id":gate.id,"distance":actor.position.distance_to(nearest)})
	for gate in game.world.access_doors:
		if gate.get("kind","") != "latch" or not gate.closed or not gate.has("interaction_point"): continue
		var coords: Array = gate.interaction_point
		var point: Vector2 = game.world.door_interaction_point(gate)
		if actor.position.distance_to(point) > 60 or not game.world.line_clear(actor.position,point): continue
		var b := _extra("latch:"+str(gate.id),"开侧门",point+Vector2(0,-60),"从内侧打开后勤通道。")
		targets.append({"button":b,"kind":"latch","id":gate.id,"distance":actor.position.distance_to(point)})
	if game.workshop and game.room_config.has("workshop") and game.workshop.on_duty() and not actor.confined and not game.routines.is_working(actor_id):
		var point: Vector2 = game.routines._target(actor_id,"work")
		if actor.position.distance_to(point) <= 85 and game.world.line_clear(actor.position,point):
			var b := _extra("work:station","工作",point+Vector2(0,-70),"返回自己的工位开始劳动；上班时监工会抓偷懒的人。")
			targets.append({"button":b,"kind":"work","id":"station","distance":actor.position.distance_to(point)})
	var anchor := Vector2.ZERO
	var active: bool = game.skills.actions.has(actor_id)
	var chat_target = game.skills.chat_guard(actor) if actor.skill_id == "chat" else null
	if active:
		kind = str(game.skills.actions[actor_id].kind)
		anchor = chat_target.position+Vector2(40,-80) if kind == "chat" and chat_target != null else game.skills.door_rect(actor).get_center()+Vector2(36,-55)
		button.tooltip_text = "停止操作（E）；撬锁进度保留。"
	elif actor.skill_id == "strong":
		var box: Rect2 = game.world.crate
		if actor.position.distance_to(actor.position.clamp(box.position,box.end)) > 35:
			return
		kind = "strong"
		anchor = box.get_center()+Vector2(0,-box.size.y/2-42)
		button.tooltip_text = "推箱：点击或E，向远离当前伙伴的方向推；S停止。"
	elif targets.any(func(t):return t.kind=="card_door"):
		return
	elif game.skills.target_reason(actor) == "":
		kind = actor.skill_id
		anchor = chat_target.position+Vector2(40,-80) if kind == "chat" and chat_target != null else game.skills.door_rect(actor).get_center()+Vector2(36,-55)
		button.tooltip_text = "停止操作（E）；撬锁进度保留。" if active else "分散注意（E）" if kind == "chat" else "撬锁（E）"
	else:
		return
	button.icon = presentation.skill_icons.get("lockpick" if kind == "lock_tool" else kind)
	button.set_meta("world_anchor",anchor)
	button.text = "停" if active else "E"
	var screen: Vector2 = game.get_global_transform_with_canvas()*anchor
	_place(button, screen)
	targets.append({"button": button, "kind": "skill", "id": "", "distance": -1.0 if active else actor.position.distance_to(chat_target.position if kind == "chat" and chat_target != null else game.skills.door_rect(actor).get_center())})

func _extra(key: String, text: String, anchor: Vector2, tooltip: String) -> Button:
	if not extras.has(key):
		var b := Button.new()
		b.name = "Interact_"+key
		b.size = Vector2(84, 48)
		b.theme = button.theme
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_activate_extra.bind(key))
		game.get_node("HUD").add_child(b)
		extras[key] = b
	var b: Button = extras[key]
	b.text = text
	if game.items_view:
		var icon_id := "trade" if key.begins_with("trade:") else "full" if game.inventory.items(game.selected_actor_id).size() >= game.inventory.capacity(game.selected_actor_id) else "pickup"
		b.icon = game.items_view.icon_for(icon_id)
		b.add_theme_constant_override("icon_max_width",20)
		b.expand_icon = true
		if key.begins_with("meal:"):
			b.icon = game.world.art_textures.get("cafeteria_tray")
		elif key.begins_with("talk:"):
			b.icon = presentation.skill_icons.get("chat")
			b.text = text
		elif icon_id == "full" and not key.begins_with("loot:"):
			b.text = "满包"
	if key.begins_with("recharge:") or key.begins_with("shower:"):
		b.text=text
		b.icon=game.fullscreen_ui.inventory_drawer.icon_for("water_card")
	if key.begins_with("dorm_door:") or key.begins_with("card_door:"):
		b.text = text
		b.icon = presentation.skill_icons.get("lockpick")
	b.tooltip_text = tooltip
	b.set_meta("world_anchor",anchor)
	_place(b, game.get_global_transform_with_canvas()*anchor)
	return b

func _refresh_bath(actor):
	var bath=game.bath_service
	if not bath or not bath.enabled():return
	if bath.sessions.has(actor_id):
		var id: String=bath.sessions[actor_id].station_id
		var b:=_extra("shower:"+id,"中断洗澡",bath.station_point(id)+Vector2(0,-85),"中断并退回本次水卡扣费。")
		targets.append({"button":b,"kind":"shower","id":id,"distance":-2.0})
		return
	if bath.recharge_reason(actor_id).is_empty():
		var id: String=str(bath.config.counter_id)
		var b:=_extra("recharge:"+id,"充值水卡",bath.counter_point()+Vector2(40,-80),"收费员充值水卡；首次充值免费领卡。")
		targets.append({"button":b,"kind":"recharge","id":id,"distance":actor.position.distance_to(bath.counter_point())})
	for id in bath.nearby_stations(actor.position):
		var b:=_extra("shower:"+str(id),"洗澡 · %d点" % bath.cost(),bath.station_point(str(id))+Vector2(0,-100),bath.shower_reason(actor_id,str(id)))
		targets.append({"button":b,"kind":"shower","id":str(id),"distance":actor.position.distance_to(bath.station_point(str(id)))})

func _refresh_nine_point(actor):
	if not game.nine_point: return
	for fixture in game.nine_point.tables():
		if not game.nine_point.reason(str(fixture.id)).is_empty(): continue
		var area: Rect2 = fixture.rect
		var b := _extra("nine_point:"+str(fixture.id),"九点 · 入座",area.get_center()+Vector2(0,-70),"2—4人比九点；可用游戏内金钱押注，也可免费练习。")
		targets.append({"button":b,"kind":"nine_point","id":fixture.id,"distance":actor.position.distance_to(actor.position.clamp(area.position,area.end))})

func _refresh_loot(actor):
	if not game.looting:return
	for id in game.looting.nearby_ids(actor.position):
		var fixture: Dictionary=game.looting.containers[id].fixture
		var rect: Rect2=fixture.rect
		var nearest: Vector2=actor.position.clamp(rect.position,rect.end)
		if actor.position.distance_to(nearest)>72 or not game.looting.reason(str(id)).is_empty():continue
		var b:=_extra("loot:"+str(id),"翻找",rect.get_center()+Vector2(0,-44),"翻找"+str(fixture.get("loot_name","容器"))+"；搜索期间时间继续。")
		targets.append({"button":b,"kind":"loot","id":id,"distance":actor.position.distance_to(nearest)})

func _place(b: Button, screen: Vector2) -> void:
	var view: Rect2 = game.map_camera.view_rect() if game.map_camera else Rect2(Vector2.ZERO,game.get_viewport_rect().size)
	b.visible = view.has_point(screen)
	b.position = (screen-b.size/2).clamp(view.position+Vector2(3,3),view.end-b.size-Vector2(3,3))

func _refresh_npcs(actor) -> void:
	if game.dialogue == null: return
	for target in game.dialogue.targets(actor.position,float(game.dialogue.config.range)):
		if not game.dialogue.reason_target(target).is_empty(): continue
		var npc = target.node
		var b := _extra("talk:"+str(target.id),"聊天",npc.position+Vector2(0,-82),"和"+str(target.name)+"聊天；普通聊天不暂停世界，看守照常执法。")
		targets.append({"button":b,"kind":"talk","id":str(target.id),"name":str(target.name),"distance":actor.position.distance_to(npc.position)})

func _refresh_items(actor) -> void:
	if not game.inventory or not game.trade:
		return
	for id in game.inventory.instances:
		var entry: Dictionary = game.inventory.instances[id]
		if entry.location != "ground":
			continue
		var point := Vector2(entry.position[0], entry.position[1])
		if actor.position.distance_to(point) > 60 or not game.world.line_clear(actor.position, point):
			continue
		var b := _extra("pickup:"+id, "拾取", point+Vector2(0,-48), "拾取（E）；满包时不会覆盖。")
		targets.append({"button": b, "kind": "pickup", "id": id, "distance": actor.position.distance_to(point)})
	for id in game.trade.merchants:
		if game.trade.reason(actor.actor_id, id) != "":
			continue
		var pos: Array = game.trade.merchants[id].position
		var point := Vector2(pos[0], pos[1])
		var hours: String = "小卖铺营业：08–20" if game.trade.actors[id].service_spec.has("service_offset") else "商人营业：12–14 / 17–20"
		var b := _extra("trade:"+id, "购买", point+Vector2(0,-86), hours+"；购买（E），时间继续运行。")
		targets.append({"button": b, "kind": "trade", "id": id, "distance": actor.position.distance_to(point)})
	if game.routines and game.routines.meal_reason(actor.actor_id).is_empty():
		var point: Vector2 = game.routines._target(actor.actor_id,"meal")
		var b := _extra("meal:cafeteria","取餐",point+Vector2(0,-76),"领取午餐（E）；自动前往自己的饭桌用餐，不占背包格。")
		targets.append({"button":b,"kind":"meal","id":"cafeteria","distance":actor.position.distance_to(point)})
	targets = targets.filter(func(target): return target.kind == "skill" or target.kind == "latch" or _visible_target(target))
	for key in extras.keys():
		if key.begins_with("pickup:") and not game.inventory.instances.has(key.substr(7)):
			extras[key].queue_free()
			extras.erase(key)

func _activate_extra(key: String) -> void:
	if game.world_input_blocked():
		return
	if key.begins_with("nine_point:"):
		game.nine_point.open_table(key.substr(11))
	elif key.begins_with("recharge:"):
		var result: Dictionary=game.bath_service.open_recharge(game.selected_actor_id)
		if not result.ok:game.show_status(str(result.reason))
	elif key.begins_with("shower:"):
		if game.bath_service.sessions.has(game.selected_actor_id):game.bath_service.cancel(game.selected_actor_id)
		else:
			var result: Dictionary=game.bath_service.start_shower(game.selected_actor_id,key.substr(7))
			game.show_status(str(result.reason),5)
	elif key.begins_with("loot:"):
		game.looting.open(key.substr(5))
	elif key.begins_with("talk:"):
		game.dialogue.open(key.substr(5))
	elif key.begins_with("pickup:"):
		var result: Dictionary = game.inventory.try_pickup(game.selected_actor_id, key.substr(7))
		game.show_status(str(result.reason) if str(result.reason) != "" else "物品已放入当前伙伴背包。")
	elif key.begins_with("meal:"):
		game.routines.start_meal(game.selected_actor_id)
	elif key.begins_with("work:"):
		game.workshop.start_work(game.selected_actor_id)
	elif key.begins_with("latch:"):
		game.room_access.open_latch(game.selected_actor_id,key.substr(6))
	elif key.begins_with("card_door:"):
		var result: Dictionary=game.keycards.toggle(game.selected_actor_id,key.substr(10))
		game.show_status(str(result.reason),4)
	elif key.begins_with("dorm_door:"):
		var result: Dictionary = game.room_access.toggle_dorm(game.selected_actor_id,key.substr(10))
		game.show_status(str(result.reason),4)
	else:
		game.shop_panel.open(key.substr(6))
	game._update_ui()
	refresh()

func activate_nearest() -> void:
	activate_mobile()

func activate(check_selection: bool = true) -> void:
	var previous_id := actor_id
	refresh()
	if kind.is_empty() or (check_selection and previous_id != game.selected_actor_id):
		return
	if kind == "strong":
		var actor = game.actors[actor_id]
		var box: Rect2 = game.world.crate
		var delta: Vector2 = box.get_center()-actor.position
		var direction := Vector2(signf(delta.x),0) if absf(delta.x) > absf(delta.y) else Vector2(0,signf(delta.y))
		if direction == Vector2.ZERO:
			return
		var goal: Vector2 = (actor.position+direction*65).clamp(game.world.bounds.position+Vector2(17,17),game.world.bounds.end-Vector2(17,17))
		game.command_move(actor_id,goal)
	else:
		game.use_selected_skill()
	refresh()

func snapshot() -> Dictionary:
	return {"visible":button.visible,"actor_id":actor_id,"kind":kind,"position":[button.position.x,button.position.y]}
