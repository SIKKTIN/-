extends "res://qa/p126_looting_gestures.gd"

var drag_sequence := 0

func move_pointer(point: Vector2, held := false):
	# Native OS hover messages must agree with synthetic viewport input. This
	# keeps a real cursor from overwriting the tested drop point during a draw.
	if DisplayServer.get_name() != "headless": root.warp_mouse(point)
	await super.move_pointer(point,held)

func shot(label: String):
	if DisplayServer.get_name()=="headless":return
	game.presentation.tick(0)
	game.fullscreen_ui.refresh()
	await frame()
	await frame()
	var error := root.get_texture().get_image().save_png("res://docs/dev/p135/"+label+".png")
	check(label+"_saved",error==OK)

func bag_drag(id: String, destination: Vector2):
	var drawer = game.fullscreen_ui.inventory_drawer
	var index: int = game.inventory.items(0).find(id)
	var source: Button = game.inventory_panel.slots[index]
	await move_pointer(source.get_global_rect().get_center())
	await mouse_button(true)
	await move_pointer(pointer+Vector2(18,0),true)
	drag_sequence += 1
	check("bag_drag_%d_starts"%drag_sequence,root.gui_is_dragging() and drawer.drag_preview.visible and drawer.drag_preview.icon!=null)
	await move_pointer(destination,true)

func bind_drag(id: String, index: int, capture := false):
	var drawer = game.fullscreen_ui.inventory_drawer
	var before: Dictionary = game.inventory.grid_layout(0).duplicate(true)
	var stage := "%d_row_%d" % [index,before[id].position.y]
	await bag_drag(id,drawer.binding_buttons[index].get_global_rect().get_center())
	check("binding_target_"+stage+"_highlighted",drawer.binding_buttons[index].drop_state==1 and drawer.drag_preview.hint=="松手绑定")
	if capture:await shot("binding-drag")
	await mouse_button(false)
	check("bind_"+stage+"_keeps_positions",game.inventory.grid_layout(0)==before and game.inventory.owns(0,id))
	check("bind_"+stage+"_matches_kind",game.quick_items.bindings[index]==game.inventory.instances[id].definition_id)
	check("binding_release_cleans_preview",not drawer.drag_preview.visible and drawer.binding_buttons.all(func(b):return b.drop_state==0))

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p135-quick-items.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p135-quick-items-buttons.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	game.reset_round(["chat","backpack","strong"],135)
	game.world.admission_filter=Callable()
	var inv = game.inventory
	var quick = game.quick_items
	var ui = game.fullscreen_ui
	var drawer = ui.inventory_drawer
	var loot = game.looting
	check("starts_with_empty_shortcuts",quick.bindings==["","","",""])
	check("map_not_default_owned",not quick.owns_kind("factory_map") and not game.map_viewer.open() and not ui.map_toggle.visible and not game.mini_map.visible)
	check("button_preferences_still_validate",ui.button_layout.valid_position("action",ui.safe_area().get_center()))
	check("map_icon_trimmed_and_loadable",drawer.icon_for("factory_map") is AtlasTexture and drawer.icon_for("factory_map").get_width()>100)
	var office: String = loot.containers.keys().filter(func(id):return loot.containers[id].fixture.loot_profile=="office")[0]
	check("office_map_accessible",stand_beside(office) and loot.open(office))
	var state: Dictionary = loot.containers[office]
	var map_id: String = state.ids.filter(func(id):return inv.instances[id].definition_id=="factory_map")[0]
	check("map_requires_search",not loot.take(map_id).ok and not quick.bind_item(0,map_id).ok)
	loot.tick(30)
	check("search_then_take_map",loot.take(map_id).ok and quick.owns_kind("factory_map"))
	loot.close()
	for id in inv.items(0):inv.try_drop(0,str(id))
	check("test_items_spawn_on_walkable_ground",stand_beside(office))
	var wrench := put("wrench")
	var key := put("door_key")
	var bread := put("bread")
	var bread2 := put("bread")
	var bandage := put("bandage")
	map_id=put("factory_map")
	var cloth := put("cloth")
	var tool := put("lock_tool")
	inv.move_item(0,cloth,Vector2i(3,3))
	inv.move_item(0,bandage,Vector2i(1,3))
	game.attributes.values[0].fullness=50
	game.attributes.values[0].stamina=50
	ui.bag_open=true
	game._update_ui()
	await frame()
	await frame()
	await frame()
	check("bag_blocks_world_not_item_actions",game.world_input_blocked() and not game.world_input_blocked(true) and not game.mobile_controls.begin_pad(-1,Vector2(90,600)))
	await bind_drag(map_id,0,true)
	await bind_drag(bread,1)
	await bind_drag(bandage,2)
	await bind_drag(tool,3)
	var bindings: Array = quick.bindings.duplicate()
	await bag_drag(cloth,drawer.binding_buttons[0].get_global_rect().get_center())
	check("materials_show_invalid_binding",drawer.binding_buttons[0].drop_state==-1)
	await mouse_button(false)
	check("invalid_binding_keeps_original",quick.bindings==bindings and inv.owns(0,cloth))
	await bag_drag(map_id,Vector2(6,root.size.y-6))
	await mouse_button(false)
	check("outside_drop_does_not_bind_or_lose",quick.bindings==bindings and inv.owns(0,map_id))
	var stale: Dictionary = drawer.make_drag(Vector2.ONE*10,inv.items(0).find(map_id))
	ui.bag_open=false
	ui.refresh()
	ui.bag_open=true
	ui.refresh()
	check("stale_binding_payload_rejected",not drawer.can_bind(Vector2.ZERO,stale,1))
	for size in [Vector2i(960,540),Vector2i(1200,720),Vector2i(1440,900)]:
		root.size=size
		root.content_scale_size=size
		await frame()
		ui.layout()
		ui.refresh()
		await frame()
		var area: Rect2 = ui.safe_area()
		check("bag_fits_%d"%size.x,area.encloses(drawer.paper.get_global_rect()) and not drawer.paper.get_global_rect().intersects(ui.clock.get_global_rect()))
		check("binding_row_inside_modal_%d"%size.x,drawer.binding_buttons.all(func(b):return drawer.paper.get_global_rect().encloses(b.get_global_rect())))
		check("bag_grid_and_details_separate_%d"%size.x,not drawer.bag_surface.get_global_rect().intersects(drawer.detail.get_global_rect()) and drawer.bag_surface.get_global_rect().encloses(drawer.grid_scroll.get_global_rect()))
		await shot("backpack-%d"%size.x)
		ui.bag_open=false
		ui.refresh()
		var first: Button = ui.quick_slots.buttons[0]
		check("vertical_bar_fits_%d"%size.x,ui.quick_slots.buttons.all(func(b):return area.encloses(b.get_global_rect()) and b.position.x==first.position.x and b.size.x<=54 and not b.get_global_rect().intersects(ui.action_button.get_global_rect())))
		check("hud_bar_and_binding_share_order_%d"%size.x,ui.quick_slots.buttons.map(func(b):return b.state.kind)==quick.bindings)
		await shot("hud-%d"%size.x)
		ui.bag_open=true
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	await frame()
	ui.layout()
	ui.refresh()
	game.actors[0].skill_id="backpack"
	inv.move_item(0,map_id,Vector2i(2,5))
	ui.refresh()
	await frame()
	await frame()
	drawer.grid_scroll.scroll_vertical=roundi(drawer.grid_holder.custom_minimum_size.y)
	await frame()
	await frame()
	check("expanded_bag_last_row_visible",drawer.grid_scroll.get_global_rect().has_point(game.inventory_panel.slots[inv.items(0).find(map_id)].get_global_rect().get_center()))
	await bind_drag(map_id,0)
	check("binding_scrolled_item_keeps_last_row",inv.grid_layout(0)[map_id].position==Vector2i(2,5))
	ui.bag_open=false
	ui.refresh()
	var stable_positions: Dictionary = inv.grid_layout(0).duplicate(true)
	await click_at(ui.quick_slots.buttons[1].get_global_rect().get_center())
	check("click_shortcut_uses_food",not inv.owns(0,bread) and inv.owns(0,bread2) and game.attributes.values[0].fullness==75)
	check("remaining_food_keeps_binding",quick.bindings[1]=="bread" and quick.state(1).count==1)
	check("consume_never_repacks_other_items",inv.grid_layout(0)[map_id]==stable_positions[map_id] and inv.grid_layout(0)[cloth]==stable_positions[cloth])
	await click_at(ui.quick_slots.buttons[1].get_global_rect().get_center())
	check("exhausted_food_turns_unavailable",quick.state(1).count==0 and not str(quick.state(1).reason).is_empty() and quick.bindings[1]=="bread")
	var full_bread := put("bread")
	check("reacquiring_food_reuses_binding",quick.state(1).count==1)
	check("fullness_full_does_not_consume",not quick.activate(1).ok and inv.owns(0,full_bread))
	game.attributes.values[0].fullness=50
	var use_key := InputEventKey.new()
	use_key.keycode=KEY_2
	use_key.pressed=true
	root.push_input(use_key,true)
	await frame()
	check("number_key_uses_bound_item_not_npc_selection",not inv.owns(0,full_bread) and game.attributes.values[0].fullness==75 and game.selected_actor_id==0)
	await click_at(ui.quick_slots.buttons[2].get_global_rect().get_center())
	check("bandage_shortcut_uses_real_effect",game.attributes.values[0].stamina==70 and not inv.owns(0,bandage))
	check("tool_away_from_door_has_reason",not str(quick.state(3).reason).is_empty() and not quick.activate(3).ok and inv.owns(0,tool))
	await click_at(ui.quick_slots.buttons[0].get_global_rect().get_center())
	check("map_shortcut_opens_without_consuming",game.map_viewer.is_open() and inv.owns(0,map_id) and game.world_input_blocked())
	await click_at(game.map_viewer.mark_button.get_global_rect().get_center())
	await click_at(game.map_viewer.canvas.get_global_rect().get_center())
	check("map_supports_player_markers",game.map_viewer.markers.size()==1)
	var wheel := InputEventMouseButton.new()
	wheel.position=game.map_viewer.canvas.get_global_rect().get_center()
	wheel.global_position=wheel.position
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.pressed=true
	root.push_input(wheel,true)
	await frame()
	wheel.pressed=false
	root.push_input(wheel,true)
	await frame()
	check("paper_map_zoom_preserves_markers",game.map_viewer.canvas.zoom>1 and game.map_viewer.markers.size()==1)
	await shot("map-viewer")
	await click_at(game.map_viewer.close_button.get_global_rect().get_center())
	check("map_closes_and_restores_world",not game.map_viewer.is_open() and not game.world_input_blocked())
	check("map_drop_disables_shortcut",inv.try_drop(0,map_id).ok and not quick.owns_kind("factory_map") and not quick.activate(0).ok and not game.map_viewer.open())
	check("map_pickup_restores_binding",inv.try_pickup(0,map_id).ok and quick.bindings[0]=="factory_map" and quick.state(0).count==1)
	check("map_return_office_accessible",stand_beside(office) and loot.open(office))
	var point: Vector2i = preload("res://scripts/items/grid_packing.gd").first_space(state.layout,Vector2i(4,4),Vector2i(2,1))
	check("map_return_to_container_removes_access",loot.move_item(map_id,"bag","source",point).ok and not quick.owns_kind("factory_map") and not game.map_viewer.open())
	check("returned_map_stays_revealed",state.revealed.get(map_id,false))
	check("retake_map_restores_same_shortcut",loot.take(map_id).ok and quick.owns_kind("factory_map") and quick.bindings[0]=="factory_map")
	loot.close()
	ui.bag_open=true
	ui.refresh()
	var button = drawer.binding_buttons[3]
	var right := InputEventMouseButton.new()
	await move_pointer(button.get_global_rect().get_center())
	right.position=pointer
	right.global_position=pointer
	right.button_index=MOUSE_BUTTON_RIGHT
	right.pressed=true
	root.push_input(right,true)
	await frame()
	check("right_click_unbinds_without_item_loss",quick.bindings[3].is_empty() and inv.owns(0,tool))
	quick.bind_item(3,tool)
	ui.refresh()
	var touch := InputEventScreenTouch.new()
	touch.index=9
	touch.position=button.get_global_rect().get_center()
	touch.pressed=true
	root.push_input(touch,true)
	await create_timer(0.75).timeout
	touch.pressed=false
	root.push_input(touch,true)
	await frame()
	check("touch_long_press_unbinds_without_item_loss",quick.bindings[3].is_empty() and inv.owns(0,tool))
	quick.bind_item(3,tool)
	ui.bag_open=false
	ui.refresh()
	var gate: Dictionary = game.world.access_by_id("maintenance-entry")
	game.actors[0].position=game.world.door_interaction_point(gate)
	game.world.set_access_closed(str(gate.id),true)
	check("tool_shortcut_uses_real_six_second_action",quick.activate(3).ok and game.skills.actions.has(0) and game.skills.actions[0].kind=="lock_tool" and not inv.owns(0,tool))
	game.skills.tick(6.01)
	check("shortcut_tool_opens_real_gate",not game.world.access_by_id(str(gate.id)).closed)
	quick.bind_item(0,key)
	check("bind_replaces_target_only",quick.bindings[0]=="door_key" and quick.bindings[1]=="bread")
	quick.bind_item(2,key)
	check("same_kind_has_one_binding",quick.bindings[0].is_empty() and quick.bindings[2]=="door_key")
	ui.bag_open=true
	ui.refresh()
	game.actors[0].immune_until=game.elapsed+5
	var old_clock: float=game.schedule.clock_elapsed
	game._process(0.2)
	check("world_clock_continues_while_managing_bag",game.schedule.clock_elapsed>old_clock and not paused)
	game.capture_actor(0)
	check("capture_dismisses_backpack_without_losing_items",not ui.bag_open and not drawer.paper.visible and inv.owns(0,map_id))
	check("carried_map_can_still_be_read_after_capture",game.map_viewer.open() and inv.owns(0,map_id))
	game.capture_actor(0)
	check("capture_dismisses_map_view",not game.map_viewer.is_open())
	game.reset_round(["chat","backpack","strong"],136)
	check("reset_clears_bindings_and_map_notes",quick.bindings==["","","",""] and game.map_viewer.markers.is_empty() and not game.map_viewer.is_open())
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	var file := FileAccess.open("res://docs/dev/p135/quick-items.json",FileAccess.WRITE)
	if file==null:
		push_error("Could not save quick-items report: %s" % FileAccess.get_open_error())
		quit(1)
		return
	file.store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	file.close()
	print(JSON.stringify({"failed":failed,"check_count":checks.size()}))
	quit(0 if failed.is_empty() else 1)
