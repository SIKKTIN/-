extends "res://qa/p126_looting_gestures.gd"

func _initialize():
	super._initialize()
	report_path="res://docs/tests/p128-drag-feedback.json"

func start_drag(id: String):
	await super.start_drag(id)
	var ui=game.looting.panel
	check("drag_icon_is_visible",ui.drag_preview.is_visible_in_tree() and ui.drag_preview.icon!=null)
	check("drag_card_above_modal",ui.drag_preview.z_index>ui.panel.z_index and ui.drag_preview.get_parent()==ui.panel.get_parent() and ui.drag_preview.get_parent() is CanvasLayer)
	check("source_item_marked_as_moving",ui.source_grid.dragging_id==id)
	check("drag_overlay_does_not_intercept_input",ui.drag_preview.mouse_filter==Control.MOUSE_FILTER_IGNORE)

func mouse_button(pressed: bool, double_click:=false):
	await super.mouse_button(pressed,double_click)
	var ui=game.looting.panel
	if not pressed and not root.gui_is_dragging():
		check("release_clears_drag_card_and_source_marker",not ui.drag_preview.visible and ui.source_grid.dragging_id.is_empty())

func move_pointer(point: Vector2, held:=false):
	await super.move_pointer(point,held)
	var ui=game.looting.panel
	if not ui.drag_active:return
	check("drag_card_stays_within_screen",Rect2(Vector2.ZERO,Vector2(root.size)).encloses(ui.drag_preview.get_global_rect()))
	check("drag_card_follows_pointer",ui.drag_preview.get_global_rect().get_center().distance_to(point)<260)
	if ui.bag.get_global_rect().has_point(point):
		check("valid_or_invalid_cursor_card_matches_target",ui.drag_preview.state==ui.bag.drop_state and ui.drag_preview.state!=0)
	else:
		check("leaving_bag_removes_target_highlight",ui.bag.drop_state==0 and (ui.grid_at(point)!=null or ui.drag_preview.state==0))

func capture(label: String):
	var ui=game.looting.panel
	if label=="looting-drag-preview":
		check("valid_drag_has_release_instruction",ui.drag_preview.hint=="松手放入背包" and ui.gesture_hint.text.begins_with("松手放入背包"))
	if DisplayServer.get_name()=="headless":return
	game.presentation.tick(0)
	game._update_ui()
	ui.refresh()
	await frame()
	await frame()
	var pixels=root.get_texture().get_image()
	pixels.save_png("res://docs/dev/p128/"+label+".png")
	if label=="looting-drag-preview":
		# Compare the rendered icon region with the same card without its icon.
		# This catches a drag node that exists but is hidden behind the modal.
		var origin:=Vector2i(ui.drag_preview.global_position)
		var icon=ui.drag_preview.icon
		ui.drag_preview.icon=null
		ui.drag_preview.queue_redraw()
		await frame()
		await frame()
		var blank=root.get_texture().get_image()
		var changed:=0
		for y in range(origin.y+8,origin.y+120,2):
			for x in range(origin.x+10,origin.x+150,2):
				if color_delta(pixels.get_pixel(x,y),blank.get_pixel(x,y))>0.07:changed+=1
		check("drag_icon_actually_rendered_above_panel",changed>200)
		ui.drag_preview.icon=icon
		ui.drag_preview.queue_redraw()
		await frame()

func color_delta(a: Color, b: Color) -> float:
	return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
