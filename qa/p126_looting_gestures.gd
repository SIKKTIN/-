extends "res://qa/p123_looting.gd"

var pointer:=Vector2.ZERO

func _initialize():
	report_path="res://docs/tests/p126-looting-gestures.json"
	super._initialize()

func move_pointer(point: Vector2, held:=false):
	var event:=InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	event.relative=point-pointer
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	pointer=point
	root.push_input(event,true)
	await frame()

func mouse_button(pressed: bool, double_click:=false):
	var event:=InputEventMouseButton.new()
	event.position=pointer
	event.global_position=pointer
	event.button_index=MOUSE_BUTTON_LEFT
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed=pressed
	event.double_click=double_click
	root.push_input(event,true)
	await frame()

func click_at(point: Vector2, double_click:=false):
	await move_pointer(point)
	await mouse_button(true,double_click)
	await mouse_button(false)

func source_point(id: String) -> Vector2:
	var ui=game.looting.panel
	var entry: Dictionary=ui.source_grid.entries.filter(func(item):return item.id==id)[0]
	return ui.source_grid.global_position+ui.source_grid.rect_for(entry).get_center()

func start_drag(id: String):
	var point:=source_point(id)
	await move_pointer(point)
	await mouse_button(true)
	await move_pointer(point+Vector2(18,0),true)
	await frame()

func capture(label: String):
	if DisplayServer.get_name()=="headless":return
	game.presentation.tick(0)
	game._update_ui()
	game.looting.panel.refresh()
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/dev/p126/"+label+".png")

func image(label: String):
	var ui=game.looting.panel
	ui.refresh()
	await frame()
	var area:=Rect2(Vector2.ZERO,ui.panel.size)
	check(label+"_tray_and_bag_are_separate",not ui.source.get_rect().intersects(ui.bag.get_rect()))
	check(label+"_footer_fits",area.encloses(ui.detail.get_rect()) and area.encloses(ui.gesture_hint.get_rect()))
	check(label+"_source_grid_fits_tray",Rect2(Vector2.ZERO,ui.source.size).encloses(ui.source_scroll.get_rect()) and ui.source_grid.custom_minimum_size.x<=ui.source_scroll.size.x)
	check(label+"_bag_grid_fits_lining",Rect2(Vector2.ZERO,ui.bag.size).encloses(ui.bag_scroll.get_rect()) and ui.bag_grid.custom_minimum_size.x<=ui.bag_scroll.size.x)
	check(label+"_search_text_is_readable",ui.search_label.get_minimum_size().y<=ui.search_label.size.y and ui.search_label.get_theme_font("font").get_string_size(ui.search_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<=ui.search_label.size.x)
	check(label+"_no_transfer_action_buttons",not ui.panel.find_children("*","Button",true,false).any(func(b):return b.text in ["拿取","全部拿取","放下","暂停翻找","继续翻找"]))
	var loot=game.looting
	var inv=game.inventory
	var state: Dictionary=loot.containers[loot.current_id]
	if label=="looting-unknown":
		var unknown: String=state.ids[0]
		check("unknown_item_has_no_drag_data",ui.source_grid._get_drag_data(source_point(unknown)-ui.source_grid.global_position)==null)
		await click_at(source_point(unknown),true)
		check("unknown_double_click_does_not_transfer",not inv.owns(0,unknown) and state.ids.has(unknown))
		await click_at(ui.search_toggle.get_global_rect().get_center())
		check("header_click_pauses_search",not loot.searching)
		await click_at(ui.search_toggle.get_global_rect().get_center())
		check("header_click_resumes_search",loot.searching)
	await capture(label)
	if label!="looting-1440":return
	loot.tick(30)
	var double_item: String=state.ids[1]
	await click_at(source_point(double_item),true)
	check("real_double_click_collects_nonfirst_item",inv.owns(0,double_item) and not state.ids.has(double_item) and ui.bag_selected==double_item)
	var count: int=inv.items(0).count(double_item)
	ui.source_grid.quick_take.emit(double_item)
	check("repeated_double_click_cannot_duplicate",inv.items(0).count(double_item)==count)
	var drag_item: String=state.ids[0]
	await start_drag(drag_item)
	check("actual_mouse_motion_starts_drag",root.gui_is_dragging())
	await move_pointer(ui.bag_grid.global_position+Vector2(inv.find_space(0,str(inv.instances[drag_item].definition_id)))*ui.bag_grid.cell+Vector2(root.gui_get_drag_data().get("grab",Vector2i.ZERO))*ui.bag_grid.cell+Vector2.ONE*ui.bag_grid.cell/2,true)
	check("valid_target_is_highlighted",ui.bag.drop_state==1)
	await capture("looting-drag-preview")
	await mouse_button(false)
	check("actual_drag_to_bag_transfers_once",inv.owns(0,drag_item) and inv.items(0).count(drag_item)==1 and not state.ids.has(drag_item))
	check("drop_clears_highlight",ui.bag.drop_state==0 and not root.gui_is_dragging())
	var cancel_item: String=state.ids[0]
	await start_drag(cancel_item)
	await move_pointer(Vector2(8,root.size.y-8),true)
	await mouse_button(false)
	check("dropping_outside_keeps_original_owner",state.ids.has(cancel_item) and inv.instances[cancel_item].location=="container" and not inv.owns(0,cancel_item))
	while inv.find_space(0,"gear").x>=0:put("gear")
	ui.refresh()
	await frame()
	await start_drag(cancel_item)
	await move_pointer(ui.bag_scroll.get_global_rect().get_center(),true)
	check("full_bag_has_invalid_target_feedback",ui.bag.drop_state==-1 and not ui.can_drop_at(Vector2.ZERO,root.gui_get_drag_data()))
	await mouse_button(false)
	check("full_bag_drop_never_loses_item",state.ids.has(cancel_item) and inv.instances[cancel_item].location=="container" and inv.used_cells(0)==20)
	await click_at(source_point(cancel_item),true)
	check("full_bag_double_click_never_loses_item",state.ids.has(cancel_item) and not inv.owns(0,cancel_item))
	var old_data: Dictionary=ui.make_drag(cancel_item)
	var container: String=loot.current_id
	loot.close()
	loot.open(container)
	ui.drop_at(Vector2.ZERO,old_data)
	check("reopened_panel_rejects_stale_drag",state.ids.has(cancel_item) and not ui.payload_reason(old_data).is_empty())
	game.actors[0].skill_id="backpack"
	while inv.find_space(0,"gear").x>=0:put("gear")
	ui.refresh()
	await frame()
	check("expanded_bag_keeps_six_rows",ui.bag_grid.dimensions==Vector2i(5,6) and ui.bag_grid.custom_minimum_size.y>ui.bag_scroll.size.y)
	ui.bag_scroll.scroll_vertical=roundi(ui.bag_grid.custom_minimum_size.y)
	await frame()
	await frame()
	var entry: Dictionary=ui.bag_grid.entries.filter(func(item):return item.rect.position.y==5)[0]
	var point: Vector2=ui.bag_grid.global_position+ui.bag_grid.rect_for(entry).get_center()
	await click_at(point,true)
	check("last_bag_row_selects_without_discarding",ui.bag_selected==entry.id and inv.owns(0,entry.id))
	await capture("looting-expanded")
	await start_drag(cancel_item)
	loot.close()
	check("closing_panel_cancels_drag_preview",not root.gui_is_dragging() and state.ids.has(cancel_item))
	await mouse_button(false)
