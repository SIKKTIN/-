extends "res://qa/p128_drag_feedback.gd"

func _initialize():
	super._initialize()
	report_path="res://docs/dev/p137/validation/looting-check.json"

func drag_grid(grid, id: String, destination, point: Vector2i, grab:=Vector2i.ZERO):
	var entry: Dictionary=grid.entries.filter(func(e):return e.id==id)[0]
	var from: Vector2=grid.global_position+(Vector2(entry.rect.position+grab)+Vector2.ONE*0.5)*grid.cell
	await move_pointer(from)
	await mouse_button(true)
	await move_pointer(from+Vector2(18,0),true)
	check("manual_drag_started",root.gui_is_dragging())
	await move_pointer(destination.global_position+(Vector2(point+grab)+Vector2.ONE*0.5)*destination.cell,true)
	await mouse_button(false)

func image(label: String):
	await super.image(label)
	if label!="looting-1440":return
	var loot=game.looting
	var inv=game.inventory
	var ui=loot.panel
	var container: String=loot.containers.keys().filter(func(k):return loot.containers[k].fixture.loot_profile=="industrial")[0]
	stand_beside(container)
	loot.open(container)
	loot.tick(30)
	for id in inv.items(0):inv.try_drop(0,str(id))
	loot.take_all()
	for id in inv.items(0):inv.try_drop(0,str(id))
	game.actors[0].skill_id="chat"
	var cloth:=put("cloth")
	var bread:=put("bread")
	var wrench:=put("wrench")
	var gear:=put("gear")
	ui.refresh()
	await frame()
	await drag_grid(ui.bag_grid,cloth,ui.bag_grid,Vector2i(3,3),Vector2i(1,0))
	check("native_second_cell_grab_preserves_anchor",inv.grid_layout(0)[cloth]==Rect2i(3,3,2,1))
	var positions: Dictionary=inv.grid_layout(0).duplicate(true)
	ui.refresh()
	check("view_model_refreshes_same_ids_after_move",ui.bag_grid.entries.filter(func(e):return e.id==cloth)[0].rect==Rect2i(3,3,2,1))
	await drag_grid(ui.bag_grid,bread,ui.bag_grid,Vector2i(3,3))
	check("overlap_drop_keeps_all_positions",inv.grid_layout(0)==positions and inv.owns(0,bread))
	var boundary_result: Dictionary=loot.move_item(cloth,"bag","bag",Vector2i(4,3))
	check("multicell_out_of_bounds_keeps_positions",not boundary_result.ok and inv.grid_layout(0)==positions)
	await drag_grid(ui.bag_grid,cloth,ui.source_grid,Vector2i(2,2),Vector2i(1,0))
	var state: Dictionary=loot.containers[container]
	check("native_bag_to_cabinet_exact_cell",not inv.owns(0,cloth) and state.ids.count(cloth)==1 and state.layout[cloth]==Rect2i(2,2,2,1) and inv.instances[cloth].location=="container")
	check("returned_item_stays_discovered",state.revealed[cloth] and loot.pending_item().is_empty())
	check("removal_does_not_repack_others",inv.grid_layout(0)[bread]==positions[bread] and inv.grid_layout(0)[wrench]==positions[wrench])
	await drag_grid(ui.source_grid,cloth,ui.bag_grid,Vector2i(2,3),Vector2i(1,0))
	check("native_cabinet_to_bag_exact_cell",inv.owns(0,cloth) and inv.grid_layout(0)[cloth]==Rect2i(2,3,2,1) and not state.layout.has(cloth))
	await drag_grid(ui.bag_grid,gear,ui.source_grid,Vector2i(0,0))
	await drag_grid(ui.source_grid,gear,ui.source_grid,Vector2i(3,3))
	check("cabinet_internal_move_persists",state.layout[gear]==Rect2i(3,3,1,1))
	loot.close()
	loot.open(container)
	ui.refresh()
	check("reopening_retains_both_layouts",state.layout[gear]==Rect2i(3,3,1,1) and inv.grid_layout(0)[cloth]==Rect2i(2,3,2,1))
	await click_at(source_point(gear),true)
	check("quick_take_fills_first_free_without_repacking",inv.owns(0,gear) and inv.grid_layout(0)[cloth]==Rect2i(2,3,2,1))
	while inv.find_space(0,"gear").x>=0:put("gear")
	ui.refresh()
	await frame()
	check("full_bag_can_move_own_footprint",loot.move_item(gear,"bag","bag",inv.grid_layout(0)[gear].position).ok and inv.used_cells(0)==20)
	await drag_grid(ui.bag_grid,bread,ui.source_grid,Vector2i(0,0))
	var freed: Vector2i=positions[bread].position
	await drag_grid(ui.bag_grid,gear,ui.bag_grid,freed)
	check("rearrange_nearly_full_bag_ignores_own_cells",inv.grid_layout(0)[gear].position==freed and inv.used_cells(0)==19)
	var before: Dictionary=inv.grid_layout(0).duplicate(true)
	var owned_ids: Array=inv.items(0)
	var rejected: Dictionary=loot.move_item(bread,"source","bag",inv.grid_layout(0)[cloth].position)
	check("rejected_transfer_is_atomic",not rejected.ok and inv.items(0)==owned_ids and inv.grid_layout(0)==before and state.ids.has(bread))
	# A filled drawer rejects returned items without destroying them.
	while true:
		var free: Vector2i=preload("res://scripts/items/grid_packing.gd").first_space(state.layout,Vector2i(4,4),Vector2i.ONE)
		if free.x<0:break
		var item:=put("gear")
		if not inv.owns(0,item):break
		loot.move_item(item,"bag","source",free)
	var full_before: Dictionary=state.layout.duplicate(true)
	check("full_drawer_return_keeps_bag_owner",not loot.move_item(cloth,"bag","source",Vector2i(0,0)).ok and inv.owns(0,cloth) and state.layout==full_before)
	game.actors[0].skill_id="backpack"
	ui.refresh()
	await frame()
	ui.bag_scroll.scroll_vertical=roundi(ui.bag_grid.custom_minimum_size.y)
	await frame()
	# Origin may be above the scroll viewport: exercise the exact scrolled drop via source.
	var known: String=state.ids[0]
	await drag_grid(ui.source_grid,known,ui.bag_grid,Vector2i(0,5))
	check("expanded_last_row_accepts_exact_placement",inv.owns(0,known) and inv.grid_layout(0)[known].position==Vector2i(0,5))
	loot.close()
	for item in inv.items(0):inv.try_drop(0,str(item))
	cloth=put("cloth")
	gear=put("gear")
	game.fullscreen_ui.bag_open=true
	game._update_ui()
	var drawer=game.fullscreen_ui.inventory_drawer
	drawer.refresh()
	await frame()
	var slot: Button=game.inventory_panel.slots[0]
	await move_pointer(slot.get_global_rect().get_center())
	await mouse_button(true)
	await move_pointer(pointer+Vector2(18,0),true)
	check("standalone_bag_starts_native_drag",root.gui_is_dragging() and drawer.drag_preview.visible)
	await move_pointer(drawer.grid_holder.global_position+(Vector2(3,1)+Vector2.ONE*0.5)*drawer.grid_cell,true)
	await mouse_button(false)
	check("standalone_bag_manual_position",inv.grid_layout(0)[cloth].position==Vector2i(2,1))
	check("standalone_release_clears_feedback",not drawer.drag_preview.visible and drawer.drop_guide.state==0)
	game.fullscreen_ui.bag_open=false
	drawer.refresh()
	game.fullscreen_ui.bag_open=true
	drawer.refresh()
	check("standalone_reopen_keeps_layout",inv.grid_layout(0)[cloth].position==Vector2i(2,1))
	game.fullscreen_ui.bag_open=false
	var other: String=loot.containers.keys().filter(func(k):return not loot.containers[k].generated)[0]
	stand_beside(other)
	loot.open(other)
	var unknown: String=loot.containers[other].ids[0]
	var unknown_cell: Vector2i=loot.containers[other].layout[unknown].position
	check("unsearched_items_reserve_their_cells",not loot.move_item(gear,"bag","source",unknown_cell).ok and inv.owns(0,gear) and not loot.containers[other].revealed.get(unknown,false))
	var stale: Dictionary=ui.make_drag(gear,"bag")
	loot.close()
	loot.open(other)
	check("reopened_panel_rejects_stale_bag_drag",not ui.payload_reason(stale).is_empty() and inv.owns(0,gear))
	loot.close()
	stand_beside(container)
	loot.open(container)
	for item in inv.items(0):inv.try_drop(0,str(item))
	loot.take_all()
	for item in inv.items(0):inv.try_drop(0,str(item))
	var art_cloth:=put("cloth")
	var art_wrench:=put("wrench")
	var art_bread:=put("bread")
	var art_bandage:=put("bandage")
	inv.move_item(0,art_cloth,Vector2i(3,3))
	inv.move_item(0,art_wrench,Vector2i(1,1))
	inv.move_item(0,art_bread,Vector2i(4,0))
	loot.move_item(art_bandage,"bag","source",Vector2i(2,1))
	ui.bag_scroll.scroll_vertical=0
	ui.refresh()
	# ScrollContainer settles its child transform on the next layout frame.
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":
		await frame()
		await frame()
		root.get_texture().get_image().save_png("res://docs/dev/p130/manual-layout.png")
	await drag_grid(ui.bag_grid,art_bread,ui.source_grid,Vector2i(1,3))
	if DisplayServer.get_name()!="headless":
		await move_pointer(ui.bag_grid.global_position+(Vector2(4,0)+Vector2.ONE*0.5)*ui.bag_grid.cell)
		await mouse_button(true)
		# Bread moved to the drawer, so begin the actual preview from that side.
		await mouse_button(false)
		await start_drag(art_bread)
		await move_pointer(ui.bag_grid.global_position+(Vector2(3,2)+Vector2.ONE*0.5)*ui.bag_grid.cell,true)
		await frame()
		root.get_texture().get_image().save_png("res://docs/dev/p130/drag-footprint.png")
		await mouse_button(false)
	loot.close()
