extends Control

const MAP := Rect2(10,30,190,116)
var game
var pointer_id: int = -2
var locate_button: Button
var stop_button: Button

func configure(owner_game) -> void:
	game = owner_game
	position = Vector2(774,126)
	size = Vector2(210,200)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	locate_button = Button.new()
	locate_button.name = "LocateActor"
	locate_button.text = "定位伙伴"
	locate_button.position = Vector2(10,150)
	locate_button.size = Vector2(94,44)
	locate_button.theme = game.presentation.mute_button.theme
	locate_button.add_theme_font_size_override("font_size",14)
	locate_button.focus_mode = Control.FOCUS_NONE
	locate_button.pressed.connect(game.map_camera.locate_selected)
	add_child(locate_button)
	stop_button = Button.new()
	stop_button.name = "StopActor"
	stop_button.text = "停止行动"
	stop_button.position = Vector2(108,150)
	stop_button.size = Vector2(92,44)
	stop_button.theme = locate_button.theme
	stop_button.add_theme_font_size_override("font_size",14)
	stop_button.focus_mode = Control.FOCUS_NONE
	stop_button.pressed.connect(game.stop_selected)
	add_child(stop_button)

func map_area() -> Rect2:
	return Rect2(10,10,size.x-20,size.y-70) if game.fullscreen_ui else MAP

func map_rect() -> Rect2:
	var bounds: Rect2 = game.world.bounds
	var scale_factor: float = minf(map_area().size.x/bounds.size.x,map_area().size.y/bounds.size.y)
	var fitted: Vector2 = bounds.size*scale_factor
	return Rect2(map_area().get_center()-fitted/2,fitted)

func to_map(point: Vector2) -> Vector2:
	var rect := map_rect()
	var bounds: Rect2 = game.world.bounds
	return rect.position + (point-bounds.position)/bounds.size*rect.size

func to_world(point: Vector2) -> Vector2:
	var rect := map_rect()
	var uv: Vector2 = ((point-rect.position)/rect.size).clamp(Vector2.ZERO,Vector2.ONE)
	return game.world.bounds.position+uv*game.world.bounds.size

func frame_rect() -> Rect2:
	var view: Rect2 = game.map_camera.world_view_rect().intersection(game.world.bounds)
	return Rect2(to_map(view.position),to_map(view.end)-to_map(view.position))

func blocked() -> bool:
	return game == null or game.map_camera.interaction_blocked() or not get_window().has_focus()

func _process(_delta: float) -> void:
	visible = game != null and not game.world_input_blocked() and (game.fullscreen_ui == null or not game.fullscreen_ui.minimap_collapsed)
	if blocked():
		pointer_id = -2
	queue_redraw()

func _input(event: InputEvent) -> void:
	if blocked():
		pointer_id = -2
		return
	if event is InputEventScreenTouch:
		var local: Vector2 = event.position-global_position
		if event.pressed and pointer_id == -2 and map_rect().has_point(local):
			pointer_id = event.index
			game.map_camera.center_on(to_world(local))
			get_viewport().set_input_as_handled()
		elif not event.pressed and pointer_id == event.index:
			pointer_id = -2
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and pointer_id == event.index:
		game.map_camera.center_on(to_world(event.position-global_position))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer_id == -1:
		game.map_camera.center_on(to_world(event.position-global_position))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and pointer_id == -1:
		pointer_id = -2
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if blocked():
		return
	if event is InputEventMouseButton and event.device != -1 and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and pointer_id == -2 and map_rect().has_point(event.position):
		pointer_id = -1
		game.map_camera.center_on(to_world(event.position))
		accept_event()

func draw_world_rect(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(to_map(rect.position),to_map(rect.end)-to_map(rect.position)),color)

func _draw() -> void:
	if not game:
		return
	draw_style_box(game.presentation.mute_button.theme.get_stylebox("normal","Button"),Rect2(Vector2.ZERO,size))
	if not game.fullscreen_ui:
		draw_string(game.presentation.font,Vector2(10,22),"小地图 · 点击 / 拖动",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("303b46"))
	draw_rect(map_area(),Color("465557"))
	var rect := map_rect()
	draw_rect(rect,Color("91a190"))
	draw_world_rect(game.world.guard_zone.intersection(game.world.bounds),Color("adab89"))
	for zone in game.room_config.get("zones",[]):
		var values: Array = zone.rect
		draw_world_rect(Rect2(values[0],values[1],values[2],values[3]),Color(zone.color))
	for wall in game.world.walls:
		draw_world_rect(wall,Color("465557"))
	for fixture in game.world.fixtures:
		draw_world_rect(fixture.rect,Color("526566") if fixture.get("blocks_sight",false) else Color("897b5d"))
	draw_world_rect(game.world.crate,Color("926d3a"))
	if not game.world.door_open:
		draw_world_rect(game.world.door,Color("775b8b"))
	draw_world_rect(game.world.exit_area.intersection(game.world.bounds),Color("36ab92"))
	for merchant in game.trade.merchants.values():
		var coords: Array = merchant.position
		draw_circle(to_map(Vector2(coords[0],coords[1])),3,Color("ebcb75") if game.trade.is_open(merchant.id) else Color("a79768"))
	for item in game.inventory.instances.values():
		if item.location == "ground":
			var coords: Array = item.position
			draw_circle(to_map(Vector2(coords[0],coords[1])),2,Color("e6c691"))
	draw_circle(to_map(game.guard.position),4,Color("c65b4b"))
	if game.dog:
		var dog_point := to_map(game.dog.position)
		draw_rect(Rect2(dog_point-Vector2(3,3),Vector2(6,6)),Color("715037") if game.dog.state == "resting" else Color("df8c39"))
	for actor in game.actors:
		if not actor.escaped:
			var point := to_map(actor.position)
			if actor.actor_id == game.selected_actor_id:
				draw_arc(point,6,0,TAU,20,Color("ffffff"),1.5)
			draw_circle(point,3.5,Color("248a82"))
	draw_rect(frame_rect(),Color("ffffff"),false,2)
	draw_rect(rect,Color("536052"),false,1)
