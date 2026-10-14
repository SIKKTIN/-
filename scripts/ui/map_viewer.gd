extends Node

const Art = preload("res://scripts/ui/looting_skin.gd")

class PaperMap extends Control:
	var viewer
	var zoom := 1.0
	var pan := Vector2.ZERO
	var dragging := false
	var paper_style: StyleBoxFlat
	func _ready():
		clip_contents = true
		paper_style = Art.box(Color("e7d9b9"),Color("ac9b79"),5,0)
		resized.connect(queue_redraw)
	func transform() -> Transform2D:
		var bounds: Rect2 = viewer.game.world.bounds
		var scale_factor := minf((size.x-44)/bounds.size.x,(size.y-34)/bounds.size.y)*zoom
		return Transform2D(0,Vector2.ONE*scale_factor,0,size/2+pan-bounds.get_center()*scale_factor)
	func world_point(point: Vector2) -> Vector2:
		return transform().affine_inverse()*point
	func project_rect(rect: Rect2) -> Rect2:
		var t := transform()
		return Rect2(t*rect.position,t.basis_xform(rect.size))
	func reset_view():
		zoom = 1
		pan = Vector2.ZERO
		dragging = false
		queue_redraw()
	func _draw():
		draw_style_box(paper_style,Rect2(Vector2.ZERO,size))
		var bounds: Rect2 = viewer.game.world.bounds
		var extent := project_rect(bounds)
		draw_rect(extent,Color("c7c5a2"))
		for zone in viewer.zones:
			var color := Color("c1c5a5") if zone.get("floor", "") == "grass" else Color("d8cdb2")
			draw_rect(project_rect(zone.area),color)
		for room in viewer.rooms:
			var rect := project_rect(room.area)
			draw_style_box(Art.box(Color("d8cfb8"),Color("8a826c"),1,0),rect)
		for wall in viewer.walls: draw_rect(project_rect(wall),Color("777263"))
		for fixture in viewer.fixtures: draw_rect(project_rect(fixture),Color(0.49,0.46,0.36,0.48))
		for zone in viewer.labels:
			var rect := project_rect(zone.area)
			var text: String = zone.name
			var font_size := 12 if rect.size.x < 70 else 14
			var text_width: float = viewer.game.presentation.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			if rect.size.x < text_width+4 or rect.size.y < font_size+5: continue
			var center := rect.get_center()
			draw_style_box(Art.box(Color(0.91,0.86,0.73,0.95),Color("b0a182"),2,0),Rect2(center-Vector2(text_width/2+5,11),Vector2(text_width+10,22)))
			draw_string(viewer.game.presentation.font,center+Vector2(-text_width/2,5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Art.INK)
		for point in viewer.markers:
			var screen: Vector2 = transform()*point
			draw_arc(screen,10,0,TAU,36,Color("a87932"),2,true)
			draw_line(screen-Vector2(5,0),screen+Vector2(5,0),Color("a87932"),1.5,true)
			draw_line(screen-Vector2(0,5),screen+Vector2(0,5),Color("a87932"),1.5,true)
		# Gentle fold lines, without a full-screen noisy texture or live radar.
		for ratio in [0.33,0.66]: draw_line(Vector2(size.x*ratio,8),Vector2(size.x*ratio,size.y-8),Color(0.5,0.44,0.32,0.09),1,true)
		draw_string(viewer.game.presentation.font,Vector2(size.x-25,25),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Art.INK)
		draw_line(Vector2(size.x-19,40),Vector2(size.x-19,29),Art.INK,2,true)
		draw_rect(extent,Color("777263"),false,1.5)
	func _gui_input(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
				var anchor := world_point(event.position)
				zoom = clampf(zoom*(1.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.15),1,3)
				pan += event.position-transform()*anchor
				queue_redraw()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed and viewer.marking: viewer.add_marker(world_point(event.position))
				else: dragging = event.pressed
			accept_event()
		elif event is InputEventMouseMotion and dragging:
			pan = (pan+event.relative).clamp(-size,size)
			queue_redraw()
			accept_event()
		elif event is InputEventScreenTouch:
			if event.pressed and viewer.marking: viewer.add_marker(world_point(event.position))
			dragging = event.pressed and not viewer.marking and not event.canceled
			accept_event()
		elif event is InputEventScreenDrag and dragging:
			pan = (pan+event.relative).clamp(-size,size)
			queue_redraw()
			accept_event()

var game
var panel: Panel
var blocker: ColorRect
var title: Label
var canvas
var close_button: Button
var mark_button: Button
var clear_button: Button
var controls_hint: Label
var marking := false
var markers: Array[Vector2] = []
var rooms: Array = []
var walls: Array = []
var zones: Array = []
var fixtures: Array = []
var labels: Array = []
var geometry_key: Array = []
var layout_key := Rect2()

func configure(owner_game):
	game = owner_game
	var hud: Node = game.get_node("HUD")
	blocker = ColorRect.new()
	blocker.name = "PaperMapBlocker"
	blocker.color = Color(0.025,0.04,0.035,0.42)
	blocker.z_index = 150
	hud.add_child(blocker)
	panel = Art.Frame.new()
	panel.name = "PaperMapViewer"
	panel.z_index = 151
	hud.add_child(panel)
	title = Label.new()
	title.text = "园区地图"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font",game.presentation.font)
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_color",Art.LIGHT)
	panel.add_child(title)
	canvas = PaperMap.new()
	canvas.viewer = self
	panel.add_child(canvas)
	close_button = button("×",close)
	mark_button = button("手动标记",func(): marking = not marking; mark_button.text = "结束标记" if marking else "手动标记")
	clear_button = button("清除标记",func(): markers.clear(); canvas.queue_redraw())
	controls_hint = Label.new()
	controls_hint.text = "拖动查看 · 滚轮缩放 · 查看不消耗"
	controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_hint.add_theme_font_override("font",game.presentation.font)
	controls_hint.add_theme_font_size_override("font_size",13)
	controls_hint.add_theme_color_override("font_color",Art.MUTED)
	panel.add_child(controls_hint)
	panel.hide()
	blocker.hide()

func button(text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_override("font",game.presentation.font)
	result.add_theme_font_size_override("font_size",17)
	Art.style_button(result)
	result.pressed.connect(callback)
	panel.add_child(result)
	return result

func is_open() -> bool:
	return panel != null and panel.visible

func layout():
	var safe: Rect2 = game.fullscreen_ui.safe_area()
	layout_key = safe
	var top: float = safe.position.y+112
	panel.size = Vector2(minf(1000,safe.size.x),minf(590,safe.end.y-top-6))
	panel.position = Vector2(safe.get_center().x-panel.size.x/2,top)
	blocker.size = game.get_viewport_rect().size
	title.position = Vector2(22,12)
	close_button.position = Vector2(panel.size.x-62,10)
	close_button.size = Vector2(44,42)
	canvas.position = Vector2(18,60)
	canvas.size = panel.size-Vector2(36,130)
	mark_button.position = Vector2(20,panel.size.y-57)
	mark_button.size = Vector2(130,42)
	clear_button.position = Vector2(162,panel.size.y-57)
	clear_button.size = Vector2(130,42)
	controls_hint.position = Vector2(312,panel.size.y-43)
	controls_hint.size = Vector2(panel.size.x-332,28)

func sync_geometry():
	var key: Array = [game.room_id,game.world.fixtures_revision]
	if geometry_key == key: return
	geometry_key = key
	rooms = preload("res://scripts/core/room_visibility.gd").rooms_for(game.room_config)
	for room in rooms: room["area"] = Rect2(room.rect[0],room.rect[1],room.rect[2],room.rect[3])
	walls = game.world.walls.duplicate()
	fixtures = []
	for fixture in game.world.fixtures:
		if fixture.get("solid",false): fixtures.append(fixture.rect)
	zones = []
	labels = rooms.duplicate()
	for spec in game.room_config.get("zones",[]):
		var zone: Dictionary = spec.duplicate()
		zone["area"] = Rect2(spec.rect[0],spec.rect[1],spec.rect[2],spec.rect[3])
		zones.append(zone)
		if not labels.any(func(room): return room.name == zone.name): labels.append(zone)

func open() -> bool:
	if not game.inventory.available(0) or not game.quick_items.owns_kind("factory_map") or game.world_input_blocked(true): return false
	game.mobile_controls.cancel_input()
	game.orders.stop(0)
	game.fullscreen_ui.bag_open = false
	game.fullscreen_ui.refresh_inventory()
	sync_geometry()
	marking = false
	mark_button.text = "手动标记"
	layout()
	canvas.reset_view()
	panel.show()
	blocker.show()
	game._update_ui()
	return true

func close():
	if panel: panel.hide()
	if blocker: blocker.hide()
	if canvas: canvas.dragging = false
	if game and game.fullscreen_ui: game.fullscreen_ui.refresh()

func reset():
	close()
	markers.clear()
	geometry_key.clear()

func add_marker(point: Vector2):
	if not game.world.bounds.has_point(point): return
	if markers.size() >= 32: markers.pop_front()
	markers.append(point)
	canvas.queue_redraw()

func _process(_delta: float):
	if not is_open(): return
	if not game.inventory.available(0) or not game.quick_items.owns_kind("factory_map"):
		close()
		return
	if layout_key != game.fullscreen_ui.safe_area(): layout()

func _unhandled_input(event: InputEvent):
	if is_open() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
