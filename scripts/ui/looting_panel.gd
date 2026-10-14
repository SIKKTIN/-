extends Node

const LootArt=preload("res://scripts/ui/looting_skin.gd")
const Grid=preload("res://scripts/ui/item_grid.gd")
const DragPreview=preload("res://scripts/ui/looting_drag_preview.gd")
var looting
var game
var panel: Panel
var blocker: ColorRect
var header: Control
var title: Label
var header_icon: TextureRect
var danger: Label
var source: Panel
var bag: Panel
var source_tag: Panel
var bag_tag: Panel
var capacity_tag: Panel
var source_title: Label
var source_count: Label
var bag_title: Label
var capacity: Label
var search_label: Label
var bar: ProgressBar
var source_scroll: ScrollContainer
var bag_scroll: ScrollContainer
var source_grid
var bag_grid
var detail: Panel
var thumbnail: TextureRect
var item_name: Label
var footprint: Label
var description: Label
var note: Label
var search_toggle: Button
var gesture_hint: Label
var close_button: Button
var bag_selected: String=""
var layout_key:=Rect2()
var interaction_epoch:=0
var drag_active:=false
var drag_error: String=""
var drag_preview
var drag_pointer:=Vector2.ZERO
var drag_payload: Dictionary={}
var view_model=preload("res://scripts/ui/looting_view_model.gd").new()

func configure(controller):
	looting=controller
	game=looting.game
	var hud=game.get_node("HUD")
	blocker=ColorRect.new()
	blocker.name="LootingBlocker"
	blocker.color=Color(0.025,0.04,0.035,0.38)
	blocker.z_index=180
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	hud.add_child(blocker)
	panel=LootArt.Frame.new()
	panel.name="LootingPanel"
	panel.z_index=181
	hud.add_child(panel)
	header=Control.new()
	header.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(header)
	header_icon=image(header)
	header_icon.texture=preload("res://art/ui/looting_v02/search.svg")
	title=label(header,24,LootArt.LIGHT)
	danger=label(header,14,Color("f2b7a0"))
	danger.text="！正在被追捕"
	close_button=button(header,"×",func():looting.close();game._update_ui())
	close_button.add_theme_font_size_override("font_size",26)
	for state in ["normal","hover","pressed","disabled"]:
		var close_style: StyleBoxFlat=close_button.get_theme_stylebox(state).duplicate()
		close_style.set_content_margin_all(2)
		close_button.add_theme_stylebox_override(state,close_style)
	for kind in ["drawer","bag"]:
		var surface:=LootArt.Surface.new()
		surface.surface_texture=LootArt.texture(kind)
		surface.drawer_surface=kind=="drawer"
		panel.add_child(surface)
		if kind=="drawer":source=surface
		else:bag=surface
	source_tag=tag(source)
	bag_tag=tag(bag,true)
	capacity_tag=tag(bag,true)
	source_title=label(source_tag,18)
	source_count=label(source_tag,13)
	bag_title=label(bag_tag,20)
	bag_title.text="随身背包"
	capacity=label(capacity_tag,17)
	capacity.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	search_label=label(source,14,LootArt.AMBER)
	search_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	bar=ProgressBar.new()
	bar.show_percentage=false
	bar.max_value=1
	bar.add_theme_stylebox_override("background",LootArt.box(Color("232b29"),Color("7c816b"),6,0))
	var fill:=StyleBoxFlat.new()
	fill.bg_color=LootArt.AMBER
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill",fill)
	source.add_child(bar)
	search_toggle=Button.new()
	search_toggle.name="ToggleSearch"
	search_toggle.focus_mode=Control.FOCUS_NONE
	search_toggle.tooltip_text="点击暂停 / 继续翻找"
	for state in ["normal","hover","pressed","disabled","focus"]:
		search_toggle.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	search_toggle.pressed.connect(looting.toggle_search)
	source.add_child(search_toggle)
	source_scroll=scroll(source)
	bag_scroll=scroll(bag)
	source_grid=Grid.new()
	bag_grid=Grid.new()
	bag_grid.canvas_surface=true
	source_grid.source_side=true
	for grid in [source_grid,bag_grid]:
		grid.game=game
		grid.looting_ui=self
		grid.font=game.fullscreen_ui.font
		grid.mouse_filter=Control.MOUSE_FILTER_STOP
		grid.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	source_scroll.add_child(source_grid)
	bag_scroll.add_child(bag_grid)
	source_grid.chosen.connect(func(id):bag_selected="";looting.select(id))
	source_grid.quick_take.connect(_take_source)
	bag_grid.chosen.connect(func(id):bag_selected=id;looting.selected_id="";refresh())
	bag.mouse_filter=Control.MOUSE_FILTER_STOP
	for surface in [source,bag]:
		surface.set_drag_forwarding(no_drag,can_drop_surface.bind(surface),drop_surface.bind(surface))
	for viewport in [source_scroll,bag_scroll]:
		viewport.set_drag_forwarding(no_drag,can_drop_surface.bind(viewport),drop_surface.bind(viewport))
	detail=Panel.new()
	detail.add_theme_stylebox_override("panel",LootArt.box(Color(0.11,0.16,0.15,0.3),Color(0.62,0.68,0.59,0.22),5))
	detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(detail)
	thumbnail=image(detail)
	item_name=label(detail,20,LootArt.LIGHT)
	footprint=label(detail,13,LootArt.MUTED)
	footprint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	description=label(detail,13,LootArt.MUTED)
	description.mouse_filter=Control.MOUSE_FILTER_PASS
	note=label(panel,12,LootArt.MUTED)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	gesture_hint=label(panel,16,LootArt.LIGHT)
	gesture_hint.text="双击快速收纳 · 拖动自由摆放\n背包与柜子之间可来回拖动"
	drag_preview=DragPreview.new()
	drag_preview.name="LootingDragPreview"
	drag_preview.font=game.fullscreen_ui.font
	hud.add_child(drag_preview)
	drag_preview.hide()
	hide_panel()

func label(parent: Control, font_size: int, color:=LootArt.INK) -> Label:
	var result:=Label.new()
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font",game.fullscreen_ui.font)
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	result.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(result)
	return result

func image(parent: Control) -> TextureRect:
	var result:=TextureRect.new()
	result.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	result.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(result)
	return result

func tag(parent: Control, sewn:=false) -> Panel:
	var result: Panel=LootArt.SewnTag.new() if sewn else LootArt.PaperTag.new()
	parent.add_child(result)
	return result

func button(parent: Control, text: String, callback: Callable, accent:=false) -> Button:
	var result:=Button.new()
	result.text=text
	result.focus_mode=Control.FOCUS_NONE
	result.add_theme_font_override("font",game.fullscreen_ui.font)
	result.add_theme_font_size_override("font_size",18)
	LootArt.style_button(result,accent)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func scroll(parent: Control) -> ScrollContainer:
	var result:=ScrollContainer.new()
	# Hidden horizontal scrolling lets the viewport shrink before its child minimum updates.
	# Grid width is fitted in layout(), so the settled view never needs horizontal scrolling.
	result.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	result.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	result.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	parent.add_child(result)
	return result

func show_panel():
	interaction_epoch+=1
	bag_selected=""
	note.text="翻找时，时间继续"
	note.add_theme_color_override("font_color",LootArt.MUTED)
	source_scroll.scroll_vertical=0
	bag_scroll.scroll_vertical=0
	panel.show()
	blocker.show()
	layout()
	refresh()

func hide_panel():
	interaction_epoch+=1
	drag_active=false
	clear_drag_feedback()
	if panel and source_grid:
		var viewport:=panel.get_viewport()
		if viewport.gui_is_dragging() and owned_drag(viewport.gui_get_drag_data()) and viewport.has_method("gui_cancel_drag"):
			viewport.call("gui_cancel_drag")
	if bag:bag.drop_state=0;bag.queue_redraw()
	if panel:panel.hide()
	if blocker:blocker.hide()
	bag_selected=""

func layout():
	var safe: Rect2=game.fullscreen_ui.safe_area()
	layout_key=safe
	blocker.position=Vector2.ZERO
	blocker.size=game.get_viewport_rect().size
	var compact:=safe.size.y<600
	var width:=minf(860 if compact else 1000,safe.size.x)
	var top: float=safe.position.y+(4 if compact else 112)
	var height:=minf(560,safe.end.y-top-8)
	panel.position=Vector2(safe.get_center().x-width/2,top)
	panel.size=Vector2(width,height)
	header.position=Vector2(18,8)
	header.size=Vector2(width-36,48)
	header_icon.position=Vector2(5,9)
	header_icon.size=Vector2(30,30)
	title.position=Vector2(47,7)
	title.size=Vector2(width-160,34)
	title.add_theme_font_size_override("font_size",21 if compact else 24)
	close_button.position=Vector2(header.size.x-43,1)
	close_button.size=Vector2(42,42)
	danger.position=Vector2(header.size.x-203,13)
	danger.size=Vector2(150,25)
	var body_height:=height-150
	var source_width: float=(width-44)*4/9
	source.position=Vector2(14,60)
	source.size=Vector2(source_width,body_height)
	bag.position=Vector2(source_width+28,52)
	bag.size=Vector2(width-source_width-42,body_height+8)
	var cell:=floorf(minf(minf((source_width-68)/4,(bag.size.x-66)/5),(body_height-96)/4))
	source_grid.cell=cell
	bag_grid.cell=cell
	var source_x:=floorf((source_width-cell*4)/2+7)
	var bag_x:=floorf((bag.size.x-cell*5)/2)
	source_scroll.position=Vector2(source_x,74)
	bag_scroll.position=Vector2(bag_x,82)
	source_scroll.size=Vector2(cell*4+12,cell*4+1)
	bag_scroll.size=Vector2(cell*5+12,cell*4+1)
	# Both grids align; only the expanded 30-cell bag scrolls below four rows.
	source_tag.position=Vector2(source_x,13)
	source_tag.size=Vector2(minf(180,cell*4-132),53)
	source_title.position=Vector2(18,4)
	source_title.size=Vector2(source_tag.size.x-32,25)
	source_title.add_theme_font_size_override("font_size",16 if compact else 18)
	source_count.position=Vector2(18,29)
	source_count.size=Vector2(source_tag.size.x-32,19)
	bar.position=Vector2(source_tag.position.x+source_tag.size.x+12,20)
	bar.size=Vector2(source_scroll.position.x+cell*4-bar.position.x,10)
	search_label.position=Vector2(bar.position.x,36)
	search_label.size=Vector2(bar.size.x,24)
	search_toggle.position=Vector2(bar.position.x,12)
	search_toggle.size=Vector2(bar.size.x,50)
	bag_tag.position=Vector2(bag_x,14 if compact else 26)
	bag_tag.size=Vector2(144,43)
	bag_title.position=Vector2(18,8)
	bag_title.size=Vector2(112,27)
	capacity_tag.position=Vector2(bag_x+cell*5-111,14 if compact else 26)
	capacity_tag.size=Vector2(111,43)
	capacity.position=Vector2(4,8)
	capacity.size=Vector2(103,27)
	detail.position=Vector2(14,height-83)
	detail.size=Vector2(source_width,61)
	thumbnail.position=Vector2(9,6)
	thumbnail.size=Vector2(48,48)
	item_name.position=Vector2(68,3)
	item_name.size=Vector2(source_width-161,27)
	item_name.add_theme_font_size_override("font_size",18 if compact else 20)
	footprint.position=Vector2(source_width-89,8)
	footprint.size=Vector2(79,19)
	description.position=Vector2(68,31)
	description.size=Vector2(source_width-79,29)
	gesture_hint.position=Vector2(bag.position.x+24,height-74)
	gesture_hint.size=Vector2(bag.size.x-40,49)
	note.position=Vector2(20,height-20)
	note.size=Vector2(width-40,18)

func refresh():
	if not looting.is_open():return
	if game.fullscreen_ui.safe_area()!=layout_key:layout()
	var state: Dictionary=looting.containers[looting.current_id]
	var fixture: Dictionary=state.fixture
	title.text="翻找物资 · %s"%str(fixture.get("loot_location","园区"))
	danger.visible=game.guard.state=="chasing" or game.workshop.chase_count(0)>0
	title.size.x=(danger.position.x-14 if danger.visible else close_button.position.x-14)-title.position.x
	source_title.text=str(fixture.get("loot_name","储物柜"))
	var discovered:=0
	for id in state.ids:
		if state.revealed.get(id,false):discovered+=1
	source_count.text="已发现 %d / %d"%[discovered,state.ids.size()]
	capacity.text="%d / %d格"%[game.inventory.used_cells(0),game.inventory.capacity(0)]
	capacity.add_theme_color_override("font_color",Color("9b503e") if game.inventory.used_cells(0)>=game.inventory.capacity(0) else LootArt.INK)
	var pending: String=looting.pending_item()
	var fraction:=0.0
	if not pending.is_empty():
		var duration: float=game.inventory.instances[pending].search_seconds
		fraction=float(state.progress[pending])/duration
		search_label.text=("翻找中" if looting.searching else "已暂停")+" · %.1f秒"%(duration-float(state.progress[pending]))
	else:search_label.text="翻找完成" if not state.ids.is_empty() else "容器已空"
	bar.value=fraction if not pending.is_empty() else 1.0
	var entries: Array=view_model.source_items(looting)
	source_grid.empty_text="已经翻找干净" if state.ids.is_empty() else ""
	source_grid.update_view(Vector2i(4,4),entries,looting.selected_id,pending if looting.searching else "",fraction)
	if not game.inventory.owns(0,bag_selected):bag_selected=""
	bag_grid.update_view(game.inventory.grid_size(0),view_model.bag_items(game.inventory),bag_selected)
	var chosen: String=bag_selected if not bag_selected.is_empty() else looting.selected_id
	var known: bool=not bag_selected.is_empty() or state.revealed.get(chosen,false)
	var kind: String=str(game.inventory.instances[chosen].definition_id) if known and game.inventory.instances.has(chosen) else ""
	var definition: Dictionary=game.inventory.definitions.get(kind,{})
	item_name.text=game.inventory.item_name(chosen) if known and not chosen.is_empty() else str(definition.get("name","尚未发现" if not chosen.is_empty() else "选择物品"))
	footprint.text=""
	if not kind.is_empty():
		var shape: Vector2i=game.inventory.item_size(kind)
		footprint.text="占用 %d 格"%(shape.x*shape.y)
	description.text=str(definition.get("description","翻找后可以拿取。" if not state.ids.is_empty() else "已翻找完，可关闭继续探索。"))
	if known and not chosen.is_empty():description.text=game.inventory.item_description(chosen)
	description.tooltip_text=description.text
	thumbnail.texture=game.fullscreen_ui.inventory_drawer.icon_for(kind)
	search_toggle.disabled=pending.is_empty()
	search_toggle.mouse_filter=Control.MOUSE_FILTER_IGNORE if search_toggle.disabled else Control.MOUSE_FILTER_STOP

func notice(result: Dictionary):
	note.text=str(result.reason)
	note.add_theme_color_override("font_color",Color("93cab1") if result.ok else Color("e8b669"))
	refresh()

func _take_source(id: String):
	var result: Dictionary=looting.take(id)
	if result.ok:
		bag_selected=id
		looting.selected_id=""
	notice(result)

func make_drag(id: String, origin: String="source", grab:=Vector2i.ZERO) -> Dictionary:
	if not looting.is_open():return {}
	var state: Dictionary=looting.containers[looting.current_id]
	if origin=="source" and (not state.ids.has(id) or not state.revealed.get(id,false)):return {}
	if origin=="bag" and not game.inventory.owns(0,id):return {}
	drag_active=true
	drag_error=""
	drag_payload={"kind":"loot_item","controller":looting.get_instance_id(),"epoch":interaction_epoch,"container":looting.current_id,"id":id,"origin":origin,"grab":grab}
	var kind: String=game.inventory.instances[id].definition_id
	drag_preview.icon=game.fullscreen_ui.inventory_drawer.icon_for(kind)
	drag_preview.item_name=str(game.inventory.definitions[kind].name)
	drag_preview.state=0
	drag_preview.hint="拖到空闲格子"
	drag_preview.show()
	drag_preview.queue_redraw()
	var origin_grid=source_grid if origin=="source" else bag_grid
	origin_grid.dragging_id=id
	origin_grid.queue_redraw()
	move_drag_preview(drag_pointer)
	note.text="拖到目标格子，绿色可放置，红色表示放不下"
	note.add_theme_color_override("font_color",LootArt.MUTED)
	return drag_payload

func _input(event: InputEvent):
	if not panel or not panel.visible:return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		drag_pointer=event.position
		if drag_active:move_drag_preview(drag_pointer)

func move_drag_preview(point: Vector2):
	var viewport_size: Vector2=game.get_viewport_rect().size
	var position:=point+Vector2(18,16)
	if position.x+drag_preview.size.x>viewport_size.x-6:position.x=point.x-drag_preview.size.x-18
	if position.y+drag_preview.size.y>viewport_size.y-6:position.y=point.y-drag_preview.size.y-16
	drag_preview.global_position=position.clamp(Vector2(6,6),viewport_size-drag_preview.size-Vector2(6,6))
	var target=grid_at(point)
	if target!=null:
		can_drop_grid(target,point-target.global_position,drag_payload)
	else:
		reset_drop_targets()
		drag_error=""
		drag_preview.feedback(0,"拖到空闲格子")
		gesture_hint.text="拖动自由摆放，也可拖回柜子\n松手放在绿色预览的格子中"
		gesture_hint.add_theme_color_override("font_color",LootArt.LIGHT)

func grid_at(point: Vector2):
	for grid in [source_grid,bag_grid]:
		var viewport=source_scroll if grid==source_grid else bag_scroll
		if viewport.get_global_rect().has_point(point) and grid.get_global_rect().has_point(point):return grid
	return null

func reset_drop_targets():
	for grid in [source_grid,bag_grid]:
		grid.preview_placement(Rect2i(),0)
	for surface in [source,bag]:
		if surface.drop_state!=0:surface.drop_state=0;surface.queue_redraw()

func clear_drag_feedback():
	if drag_preview:drag_preview.hide()
	drag_payload={}
	if source_grid:
		for grid in [source_grid,bag_grid]:grid.dragging_id="";grid.queue_redraw()
		reset_drop_targets()
	if gesture_hint:gesture_hint.text="双击快速收纳 · 拖动自由摆放\n背包与柜子之间可来回拖动"
	if gesture_hint:gesture_hint.add_theme_color_override("font_color",LootArt.LIGHT)

func owned_drag(data) -> bool:
	return data is Dictionary and data.get("kind","")=="loot_item" and data.get("controller",-1)==looting.get_instance_id()

func no_drag(_at_position: Vector2):
	return null

func payload_reason(data) -> String:
	if not owned_drag(data):return "不是可移动的物资。"
	if data.get("epoch",-1)!=interaction_epoch or data.get("container","")!=looting.current_id or not looting.is_open():return "这次翻找已结束。"
	return ""

func target_point(grid, local: Vector2, data: Dictionary) -> Vector2i:
	return Vector2i((local/grid.cell).floor())-Vector2i(data.get("grab",Vector2i.ZERO))

func can_drop_grid(grid, local: Vector2, data) -> bool:
	if not owned_drag(data):return false
	var error:=payload_reason(data)
	var point:=target_point(grid,local,data)
	var target: String="source" if grid.source_side else "bag"
	if error.is_empty():error=looting.move_reason(str(data.id),str(data.get("origin","source")),target,point)
	var next_state:=1 if error.is_empty() else -1
	var other=bag_grid if grid==source_grid else source_grid
	other.preview_placement(Rect2i(),0)
	var surface=source if grid==source_grid else bag
	var other_surface=bag if grid==source_grid else source
	other_surface.drop_state=0
	other_surface.queue_redraw()
	if surface.drop_state!=next_state:surface.drop_state=next_state;surface.queue_redraw()
	var kind: String=game.inventory.instances.get(str(data.id),{}).get("definition_id","")
	grid.preview_placement(Rect2i(point,game.inventory.item_size(kind)),next_state)
	drag_error=error
	if drag_active:
		var instruction: String="松手放回柜子" if target=="source" else "松手放入背包"
		drag_preview.feedback(next_state,instruction if error.is_empty() else "此处无法放置")
		gesture_hint.text=instruction+"\n保留你选择的格子位置" if error.is_empty() else error
		gesture_hint.add_theme_color_override("font_color",Color("93dfc4") if error.is_empty() else Color("f0a48b"))
	return error.is_empty()

func drop_grid(grid, local: Vector2, data):
	if not can_drop_grid(grid,local,data):
		notice({"ok":false,"reason":payload_reason(data) if not payload_reason(data).is_empty() else drag_error})
		return
	var target: String="source" if grid.source_side else "bag"
	var result: Dictionary=looting.move_item(str(data.id),str(data.get("origin","source")),target,target_point(grid,local,data))
	if result.ok:
		bag_selected=str(data.id) if target=="bag" else ""
		if target=="bag":looting.selected_id=""
		game.inventory_panel.refresh()
	notice(result)

func can_drop_surface(_local: Vector2, data, _surface: Control) -> bool:
	return can_drop_at(drag_pointer,data)

func drop_surface(_local: Vector2, data, _surface: Control):
	drop_at(drag_pointer,data)

# Coordinates here are global; grids call the explicitly local variants above.
func can_drop_at(global_point: Vector2, data) -> bool:
	var grid=grid_at(global_point)
	return grid!=null and can_drop_grid(grid,global_point-grid.global_position,data)

func drop_at(global_point: Vector2, data):
	var grid=grid_at(global_point)
	if grid!=null:drop_grid(grid,global_point-grid.global_position,data)

func finish_drag(successful: bool):
	if bag:bag.drop_state=0;bag.queue_redraw()
	clear_drag_feedback()
	gesture_hint.add_theme_color_override("font_color",LootArt.LIGHT)
	if not drag_active:return
	drag_active=false
	if not successful and looting.is_open():
		note.text=drag_error if not drag_error.is_empty() else "已取消移动，物品仍留在原处。"
		note.add_theme_color_override("font_color",LootArt.MUTED)
