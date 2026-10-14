extends Control

signal chosen(id: String)
signal quick_take(id: String)
const LootArt=preload("res://scripts/ui/looting_skin.gd")
var game
var font: Font
var dimensions:=Vector2i(4,4)
var cell:=64.0
var entries: Array=[]
var selected: String=""
var scanning: String=""
var progress:=0.0
var view_key: Array=[]
var canvas_surface:=false
var empty_text: String=""
var styles: Dictionary={}
var looting_ui
var source_side:=false
var dragging_id: String=""
var drop_rect:=Rect2i()
var drop_state:=0

func style(kind: String) -> StyleBoxFlat:
	var key:=kind+str(canvas_surface)
	if styles.has(key):return styles[key]
	var background:=Color(0.97,0.94,0.87,0.03) if canvas_surface else Color(0.10,0.12,0.11,0.20)
	var border:=Color(0.33,0.32,0.27,0.38) if canvas_surface else Color(0.63,0.67,0.59,0.27)
	if kind=="unknown":background=Color(0.06,0.08,0.075,0.78)
	if kind=="item":background=Color(0.20,0.18,0.13,0.045) if canvas_surface else Color(0.05,0.07,0.06,0.22)
	if kind=="selected":border=LootArt.AMBER;background=Color(0.7,0.48,0.13,0.11)
	var result:=LootArt.box(background,border,5,0)
	if canvas_surface and kind not in ["selected","unknown"]:result.set_border_width_all(0)
	if kind=="selected":result.set_border_width_all(2)
	styles[key]=result
	return result

func draw_slot(kind: String, rect: Rect2):
	draw_style_box(style(kind),rect)
	if not canvas_surface or kind in ["selected","unknown"]:return
	for x in range(4,int(rect.size.x)-4,7):
		for y in [2.0,rect.size.y-2]:
			draw_line(rect.position+Vector2(x,y),rect.position+Vector2(x+3,y),Color(0.31,0.30,0.25,0.45),1,true)
	for y in range(4,int(rect.size.y)-4,7):
		for x in [2.0,rect.size.x-2]:
			draw_line(rect.position+Vector2(x,y),rect.position+Vector2(x,y+3),Color(0.31,0.30,0.25,0.45),1,true)

func update_view(shape: Vector2i, items: Array, selected_item: String, scanning_item: String="", fraction:=0.0):
	dimensions=shape
	entries=items
	selected=selected_item
	scanning=scanning_item
	progress=fraction
	custom_minimum_size=Vector2(shape)*cell
	var key: Array=[shape,items,selected_item,scanning_item,int(fraction*24),cell,canvas_surface,empty_text]
	if key!=view_key:view_key=key.duplicate(true);queue_redraw()

func rect_for(entry: Dictionary) -> Rect2:
	var grid: Rect2i=entry.rect
	return Rect2(Vector2(grid.position)*cell+Vector2(2,2),Vector2(grid.size)*cell-Vector2(4,4))

func _draw():
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			var occupied:=entries.any(func(entry):return entry.rect.has_point(Vector2i(x,y)))
			if occupied:continue
			var rect:=Rect2(Vector2(x,y)*cell+Vector2(2,2),Vector2.ONE*(cell-4))
			draw_slot("empty",rect)
			if not canvas_surface:
				var center:=rect.get_center()
				draw_line(center-Vector2(3,0),center+Vector2(3,0),Color(0.63,0.67,0.59,0.14),1,true)
				draw_line(center-Vector2(0,3),center+Vector2(0,3),Color(0.63,0.67,0.59,0.14),1,true)
	for entry in entries:
		var rect:=rect_for(entry)
		var known: bool=entry.get("known",true)
		var active: bool=str(entry.id)==scanning
		draw_slot("selected" if str(entry.id)==selected and known else ("item" if known else "unknown"),rect)
		if known:
			var icon: Texture2D=game.fullscreen_ui.inventory_drawer.icon_for(str(entry.kind))
			if icon:
				var area:=rect.grow(-5)
				var fitted: Vector2=icon.get_size()*minf(area.size.x/icon.get_width(),area.size.y/icon.get_height())
				var icon_rect:=Rect2(area.position+(area.size-fitted)/2,fitted)
				draw_texture_rect(icon,icon_rect,false,Color(1,1,1,0.3) if str(entry.id)==dragging_id else Color.WHITE)
				preload("res://scripts/ui/keycard_art.gd").caption(self,game,str(entry.id),font,icon_rect)
			if str(entry.id)==dragging_id:
				draw_string(font,rect.position+Vector2(7,rect.size.y-6),"移动中",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-14,13,LootArt.AMBER)
		else:
			var stripe:=rect.grow(-4)
			for k in range(0,int(stripe.size.x+stripe.size.y),12):
				var start:=Vector2(maxf(0,k-stripe.size.y),minf(stripe.size.y,k))
				var end:=Vector2(minf(stripe.size.x,k),maxf(0,k-stripe.size.x))
				draw_line(stripe.position+start,stripe.position+end,Color(0.55,0.59,0.52,0.07),3,true)
			var label:="?"
			var width: float=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x
			draw_string(font,rect.get_center()+Vector2(-width/2,9),label,HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("a2a696"))
		if active:
			draw_style_box(style("selected"),rect)
			draw_arc(rect.get_center(),18,-PI/2,-PI/2+TAU*progress,28,LootArt.AMBER,2,true)
	if not empty_text.is_empty() and drop_state==0:
		var width: float=font.get_string_size(empty_text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		var center:=Vector2(dimensions)*cell/2
		draw_style_box(LootArt.box(Color(0.10,0.14,0.13,0.88),Color(0.6,0.64,0.56,0.2),4,0),Rect2(center-Vector2(width/2+12,17),Vector2(width+24,34)))
		draw_string(font,center+Vector2(-width/2,5),empty_text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,LootArt.MUTED)

	if drop_state!=0:
		var area:=Rect2(Vector2(drop_rect.position)*cell+Vector2(2,2),Vector2(drop_rect.size)*cell-Vector2(4,4))
		var color:=Color("48c7a0") if drop_state==1 else Color("de795f")
		draw_rect(area,Color(color,0.24),true)
		draw_rect(area,color,false,3)

func preview_placement(rect: Rect2i, state: int):
	if drop_rect==rect and drop_state==state:return
	drop_rect=rect
	drop_state=state
	queue_redraw()

func _gui_input(event: InputEvent):
	if event is InputEventMouseMotion:
		tooltip_text=""
		for entry in entries:
			if rect_for(entry).has_point(event.position):
				tooltip_text=game.inventory.item_name(str(entry.id)) if entry.get("known",true) else "尚未发现的物品"
				break
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		for entry in entries:
			if rect_for(entry).has_point(event.position):
				chosen.emit(str(entry.id))
				if event.double_click and entry.get("known",true):quick_take.emit(str(entry.id))
				accept_event()
				return

func _get_drag_data(at_position: Vector2):
	if looting_ui==null:return null
	for entry in entries:
		if rect_for(entry).has_point(at_position) and entry.get("known",true):
			var payload: Dictionary=looting_ui.make_drag(str(entry.id),"source" if source_side else "bag",Vector2i((at_position/cell).floor())-entry.rect.position)
			if payload.is_empty():return null
			chosen.emit(str(entry.id))
			return payload
	return null

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return looting_ui!=null and looting_ui.can_drop_grid(self,looting_ui.drag_pointer-global_position,data)

func _drop_data(_at_position: Vector2, data):
	if looting_ui!=null:looting_ui.drop_grid(self,looting_ui.drag_pointer-global_position,data)

func _notification(what: int):
	if what==NOTIFICATION_DRAG_END and looting_ui!=null:
		looting_ui.finish_drag(get_viewport().gui_is_drag_successful())
