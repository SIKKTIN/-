@tool
extends Control

signal selected(ref: Dictionary)
signal placed(group: String, point: Vector2)
signal edited
var document
var selection: Dictionary = {}
var tool := "select"
var zoom := 0.35
var origin := Vector2(24,24)
var drag_ref: Dictionary = {}
var drag_offset := Vector2.ZERO
var panning := false
var draw_start := Vector2.ZERO
var drawing_wall := false
var last_pointer := Vector2.ZERO
var textures: Dictionary = {}
var font: Font
var show_collision := false
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")

func setup(model) -> void:
	document = model
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	font = load("res://art/fonts/NotoSansCJKsc-Regular.otf")
	for file in ["res://art/props/prison_v08/manifest.json","res://art/props/cafeteria_v14/manifest.json","res://art/props/manifest-v03.json"]:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
		for asset in manifest.get("assets",[]):
			textures[str(asset.id)] = WorldTexture.load_asset(asset)
	document.changed.connect(queue_redraw)
	gui_input.connect(handle_input)
	resized.connect(queue_redraw)

func fit() -> void:
	if document.data.is_empty() or size.x <= 0:
		return
	var bounds: Rect2 = document.geometry({"group":"bounds","index":-1})
	zoom = clampf(minf((size.x-48)/bounds.size.x,(size.y-48)/bounds.size.y),0.08,2)
	origin = (size-bounds.size*zoom)/2-bounds.position*zoom
	queue_redraw()

func screen(point: Vector2) -> Vector2:
	return origin+point*zoom

func world(point: Vector2) -> Vector2:
	return (point-origin)/zoom

func at(point: Vector2) -> Dictionary:
	var entries: Array = document.entries()
	entries.reverse()
	# Points and small props win over enclosing zones and the map bounds.
	for pass_index in range(2):
		for ref in entries:
			var background: bool = ref.group in ["bounds","guard_zone","dormitories","zones"]
			if background != (pass_index == 1):
				continue
			var rect: Rect2 = document.geometry(ref)
			if document.is_rect(ref):
				if rect.grow(5/zoom).has_point(world(point)):
					return ref
			elif screen(rect.position).distance_to(point) <= 11:
				return ref
	return {}

func choose(ref: Dictionary) -> void:
	selection = ref.duplicate()
	selected.emit(selection)
	queue_redraw()

func finish_gesture(cancel := false) -> void:
	if not drag_ref.is_empty() or drawing_wall:
		if cancel:
			document.cancel_transaction()
		else:
			document.commit()
			edited.emit()
	drag_ref.clear()
	drawing_wall = false
	panning = false
	queue_redraw()

func handle_input(event: InputEvent) -> void:
	if document == null or document.data.is_empty():
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var before := world(event.position)
			zoom = clampf(zoom*(1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1/1.15),0.08,3)
			origin = event.position-before*zoom
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and (tool == "pan" or Input.is_physical_key_pressed(KEY_SPACE))):
			panning = event.pressed
			last_pointer = event.position
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				finish_gesture()
			elif tool == "select":
				choose(at(event.position))
				if not selection.is_empty():
					drag_ref = selection.duplicate()
					drag_offset = world(event.position)-document.geometry(selection).position
					document.begin()
			elif tool == "walls":
				draw_start = document.snap_point(world(event.position))
				selection = document.add("walls",draw_start)
				# Add+resize are one undo transaction.
				document.undo()
				document.begin()
				document.data.walls.append([draw_start.x,draw_start.y,20,20])
				drawing_wall = true
				choose(selection)
			else:
				placed.emit(tool,document.snap_point(world(event.position)))
			accept_event()
	elif event is InputEventMouseMotion:
		if panning:
			origin += event.position-last_pointer
			last_pointer = event.position
			queue_redraw()
			accept_event()
		elif drawing_wall:
			var end: Vector2 = document.snap_point(world(event.position))
			var begin: Vector2 = draw_start.min(end)
			var dims: Vector2 = (end-draw_start).abs().max(Vector2(20,20))
			document.set_geometry(selection,Rect2(begin,dims))
			accept_event()
		elif not drag_ref.is_empty():
			document.move(drag_ref,world(event.position)-drag_offset)
			accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("303e40"))
	if document == null or document.data.is_empty():
		return
	var bounds: Rect2 = document.geometry({"group":"bounds","index":-1})
	draw_rect(Rect2(screen(bounds.position),bounds.size*zoom),Color("a5af9a"))
	var step: float = maxf(20,document.grid)
	if step*zoom >= 6:
		for x in range(floori(bounds.position.x/step),ceili(bounds.end.x/step)+1):
			draw_line(screen(Vector2(x*step,bounds.position.y)),screen(Vector2(x*step,bounds.end.y)),Color(0.18,0.26,0.24,0.18),1)
		for y in range(floori(bounds.position.y/step),ceili(bounds.end.y/step)+1):
			draw_line(screen(Vector2(bounds.position.x,y*step)),screen(Vector2(bounds.end.x,y*step)),Color(0.18,0.26,0.24,0.18),1)
	var entries: Array = document.entries()
	# Enclosing regions are painted before furniture and points.
	for ref in entries:
		if ref.group in ["guard_zone","zones","dormitories"]:
			var tint := Color("cf9975") if ref.group == "guard_zone" else Color("75c0b5") if ref.group == "dormitories" else Color("e0d29e")
			paint_rect(ref,tint,true)
	for ref in entries:
		if ref.group in ["bounds","guard_zone","zones","dormitories"]:
			continue
		var rect: Rect2 = document.geometry(ref)
		if document.is_rect(ref):
			var color := Color("435555") if ref.group == "walls" else Color("a17b4b") if ref.group in ["door","dorm_doors"] else Color("318c82") if ref.group == "exit" else Color("896b45")
			if ref.group == "fixtures":
				var asset: String = document.value(ref).asset_id
				var texture: Texture2D = textures.get(asset)
				if texture:
					draw_texture_rect(texture,Rect2(screen(rect.position),rect.size*zoom),false)
				else:
					paint_rect(ref,color)
				if show_collision:
					var item = document.value(ref)
					var overlay := Color(0.9,0.3,0.2,0.3) if item.get("blocks_movement",true) else Color(0.2,0.9,0.7,0.2)
					draw_rect(Rect2(screen(rect.position),rect.size*zoom),overlay)
			else:
				paint_rect(ref,color)
		else:
			var p := screen(rect.position)
			var color := Color("328b82") if ref.group in ["starts","work","meal","dine","free"] else Color("d5846a") if ref.group in ["patrol","gate_guards","guard_start"] else Color("efd69f")
			draw_circle(p,7,color,true,-1,true)
			draw_circle(p,8,Color("f2ebdd"),false,1,true)
			if zoom > 0.17:
				var short_names := {"starts":"伙伴","work":"工","meal":"餐","dine":"桌","free":"活动","patrol":"巡","gate_guards":"门岗","guard_start":"看守","merchants":"商人","items":"物品"}
				var label: String = short_names.get(ref.group,ref.group)+(str(int(ref.index)+1) if int(ref.index) >= 0 else "")
				if zoom >= 0.45 or selection == ref or ref.group in ["starts","merchants","gate_guards"]:
					draw_string(font,p+Vector2(10,4),label,HORIZONTAL_ALIGNMENT_LEFT,100,12,Color("243739"))
	var patrol: Array = document.data.get("patrol",[])
	for index in range(patrol.size()):
		var a: Array = patrol[index]
		var b: Array = patrol[(index+1)%patrol.size()]
		draw_line(screen(Vector2(a[0],a[1])),screen(Vector2(b[0],b[1])),Color("cf795c"),2,true)
	if not selection.is_empty():
		var rect: Rect2 = document.geometry(selection)
		if document.is_rect(selection):
			draw_rect(Rect2(screen(rect.position),rect.size*zoom).grow(3),Color("fff1b2"),false,3)
		else:
			draw_circle(screen(rect.position),13,Color("fff1b2"),false,3,true)
	if font:
		draw_string(font,Vector2(12,size.y-12),"%.0f%% · 中键/空格拖动视野 · 滚轮缩放" % (zoom*100),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f2ebdd"))

func paint_rect(ref: Dictionary, color: Color, outline := false) -> void:
	var rect: Rect2 = document.geometry(ref)
	var on_screen := Rect2(screen(rect.position),rect.size*zoom)
	if outline:
		draw_rect(on_screen,Color(color,0.12))
		draw_rect(on_screen,color,false,1.5)
		if zoom > 0.17 and (ref.group == "zones" or selection == ref):
			var text: String = str(document.value(ref).get("name","区域")) if ref.group == "zones" else document.name_for(ref)
			draw_string(font,on_screen.position+Vector2(4,14),text,HORIZONTAL_ALIGNMENT_LEFT,on_screen.size.x,12,Color("243739"))
	else:
		draw_rect(on_screen,color)
