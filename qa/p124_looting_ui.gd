extends "res://qa/p123_looting.gd"

func _initialize():
	report_path="res://docs/tests/p124-looting-ui.json"
	super._initialize()

func capture(label: String):
	if DisplayServer.get_name()=="headless":return
	game.presentation.tick(0)
	game._update_ui()
	game.looting.panel.refresh()
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/dev/p124/"+label+".png")

func click_at(point: Vector2):
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	root.push_input(motion,true)
	await frame()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=point
		event.global_position=point
		root.push_input(event,true)
		await frame()

func image(label: String):
	var ui=game.looting.panel
	ui.refresh()
	await frame()
	var area:=Rect2(Vector2.ZERO,ui.panel.size)
	check(label+"_tray_and_bag_are_separate",not ui.source.get_rect().intersects(ui.bag.get_rect()))
	check(label+"_detail_and_actions_fit",[ui.detail,ui.stop_button,ui.take_button,ui.all_button].all(func(control):return area.encloses(control.get_rect())))
	check(label+"_source_grid_fits_tray",Rect2(Vector2.ZERO,ui.source.size).encloses(ui.source_scroll.get_rect()) and ui.source_grid.custom_minimum_size.x<=ui.source_scroll.size.x)
	check(label+"_bag_grid_fits_lining",Rect2(Vector2.ZERO,ui.bag.size).encloses(ui.bag_scroll.get_rect()) and ui.bag_grid.custom_minimum_size.x<=ui.bag_scroll.size.x)
	check(label+"_search_text_is_readable",ui.search_label.get_minimum_size().y<=ui.search_label.size.y and ui.search_label.get_theme_font("font").get_string_size(ui.search_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<=ui.search_label.size.x)
	await capture(label)
	if label!="looting-1440":return
	var loot=game.looting
	var inv=game.inventory
	loot.tick(30)
	# Existing tall items can prevent another tall item fitting despite free cell count.
	for item in inv.items(0):inv.try_drop(0,str(item))
	loot.take_all()
	check("empty_source_has_explicit_caption",ui.source_grid.empty_text=="已经翻找干净" and ui.all_button.disabled and ui.stop_button.disabled)
	await capture("looting-empty")
	game.actors[0].skill_id="backpack"
	while inv.find_space(0,"gear").x>=0:put("gear")
	ui.refresh()
	await frame()
	check("expanded_bag_keeps_six_rows",ui.bag_grid.dimensions==Vector2i(5,6) and ui.bag_grid.custom_minimum_size.y>ui.bag_scroll.size.y)
	ui.bag_scroll.scroll_vertical=roundi(ui.bag_grid.custom_minimum_size.y)
	await frame()
	await frame()
	var target: String=""
	for entry in ui.bag_grid.entries:
		if entry.rect.position.y==5:target=entry.id;break
	var entry: Dictionary=ui.bag_grid.entries.filter(func(item):return item.id==target)[0]
	var point: Vector2=ui.bag_grid.global_position+ui.bag_grid.rect_for(entry).get_center()
	check("last_row_is_visible_after_scrolling",ui.bag_scroll.get_global_rect().has_point(point))
	await click_at(point)
	check("last_row_accepts_actual_pointer_selection",ui.bag_selected==target and ui.take_button.text=="放下" and not ui.take_button.disabled)
	await capture("looting-expanded")
	await click_at(ui.take_button.get_global_rect().get_center())
	check("selected_last_row_can_be_dropped_by_ui",not inv.owns(0,target))
