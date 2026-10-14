@tool
extends Control

signal selected(ref: Dictionary)
signal placed(group: String, point: Vector2)
signal edited
signal blocked(message: String)
signal interaction_started
const Transform = preload("res://scripts/editor/map_transform.gd")
var group_refs: Array = []
var selection_scope := {"walls":true,"fixtures":true,"actors":false,"items":false,"routine":false}
var marquee_active := false
var marquee_start := Vector2.ZERO
var marquee_end := Vector2.ZERO
var group_dragging := false
var group_drag_start := Vector2.ZERO
var group_snapshot := {}
var selection_angle := 0
var group_pivot := Vector2.ZERO
var group_drag_delta := Vector2.ZERO
var document
var layers
var selection: Dictionary = {}
var tool := "select"
var placement_asset := ""
var zoom := 0.35
var origin := Vector2(24,24)
var drag_ref: Dictionary = {}
var drag_offset := Vector2.ZERO
var panning := false
var draw_start := Vector2.ZERO
var drawing_wall := false
var painting_floor := false
var floor_resizing := false
var floor_resize_anchor := Vector2.ZERO
var floor_material: Dictionary = {}
var erasing := false
var erased_count := 0
var eraser = preload("res://scripts/editor/map_eraser.gd").new()
var eraser_pointer := Vector2.ZERO
var eraser_hover: Dictionary = {}
var eraser_inside := false
var stroke_wall_count := 0
var stroke_surface_count := 0
var stroke_variant: Callable
var last_pointer := Vector2.ZERO
var textures: Dictionary = {}
var definitions: Dictionary = {}
var font: Font
var architecture_preview
var foreground
var render_profile := {}
var show_collision := false
var entry_refs: Array = []
var grid_line_count := 0
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
const Components = preload("res://scripts/presentation/wall_components.gd")

func setup(model, layer_model = null) -> void:
	document = model
	layers = layer_model if layer_model != null else load("res://scripts/editor/map_layers.gd").new()
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	font = load("res://art/fonts/NotoSansCJKsc-Regular.otf")
	definitions = load("res://scripts/presentation/prop_catalog.gd").assets()
	var active: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/active.json"))
	render_profile = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/%s.json" % active.profile))
	for manifest_path in [render_profile.environment,render_profile.props]:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		for asset in manifest.assets:
			if not definitions.has(asset.id):
				definitions[asset.id] = asset
	architecture_preview = preload("res://scripts/editor/architecture_preview.gd").new()
	add_child(architecture_preview)
	architecture_preview.setup(self,render_profile)
	foreground = preload("res://scripts/editor/canvas_overlay.gd").new()
	foreground.canvas = self
	foreground.z_index = 4095
	add_child(foreground)
	document.changed.connect(on_document_changed)
	gui_input.connect(handle_input)
	mouse_entered.connect(func(): eraser_inside = true; queue_redraw())
	mouse_exited.connect(func(): eraser_inside = false; queue_redraw())
	resized.connect(queue_redraw)
	on_document_changed()

func on_document_changed() -> void:
	load_map_textures()
	entry_refs = document.entries()
	queue_redraw()

func load_map_textures() -> void:
	if document==null or document.data.is_empty():return
	if not drag_ref.is_empty() and drag_ref.get("group","")=="fixtures":
		load_referenced_textures(document.value(drag_ref),{})
		return
	preload("res://scripts/presentation/region_terrain.gd").warm_map(document.data)
	load_referenced_textures(document.data,render_profile)

func load_referenced_textures(data: Variant, profile: Dictionary) -> void:
	var needed: Dictionary=preload("res://scripts/presentation/asset_dependencies.gd").ids(data,profile,definitions)
	for id in needed:
		if not textures.has(id):textures[id]=WorldTexture.load_asset(definitions[id])

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

func beneath_roof(point: Vector2) -> bool:
	if layers != null and not layers.is_visible("architecture"): return false
	for cell in document.data.get("confinement",{}).get("cells",[]):
		var building: Dictionary = cell.get("building",{})
		if building.get("roofed",false) and Rect2(cell.rect[0],cell.rect[1],cell.rect[2],cell.rect[3]-float(building.get("height",110))).has_point(point): return true
	return false

func at(point: Vector2, removable_only := false) -> Dictionary:
	var entries: Array = document.eraser_entries() if removable_only else entry_refs.duplicate()
	entries.reverse()
	# Points and small props win over enclosing zones and the map bounds.
	for pass_index in range(3):
		for ref in entries:
			if ref.group == "bounds" or not layers.is_editable(ref.group): continue
			if removable_only and not document.can_remove(ref): continue
			if removable_only and document.removal_refs([ref]).any(func(part): return not layers.is_editable(part.group)): continue
			if ref.group == "fixtures" and document.value(ref).get("hidden",false) and not show_collision: continue
			var background: bool = ref.group in ["bounds","guard_zone","dormitories","zones","confinement","visibility_rooms"]
			var layer_pass := 2 if layers.key_for(ref.group) == "ground" else 1 if background else 0
			if layer_pass != pass_index:
				continue
			var rect: Rect2 = document.geometry(ref)
			if ref.group == "fixtures" and not show_collision and beneath_roof(rect.get_center()): continue
			if document.is_rect(ref):
				if not show_collision and ref.group in ["walls","fixtures","door","crate","access_doors","dorm_doors"]:
					if architecture_preview.visual_hit(ref,world(point)): return ref
					continue
				if ref.group == "ground_details":
					if preload("res://scripts/presentation/site_details.gd").hit_test(document.value(ref),world(point),5/zoom): return ref
					continue
				if rect.grow(5/zoom).has_point(world(point)):
					return ref
			elif screen(rect.position).distance_to(point) <= 11:
				return ref
	return {}

func choose(ref: Dictionary) -> void:
	if not ref.is_empty() and not layers.is_editable(ref.group):
		blocked.emit("对象图层已隐藏或锁定，请先显示并解锁。")
		return
	selection = ref.duplicate()
	group_refs.clear()
	selection_angle = 0
	if not ref.is_empty():
		var item = document.wall_surface(int(ref.index)) if ref.group=="walls" else document.value(ref)
		if item is Dictionary: selection_angle = posmod(int(item.get("rotation_quarters",0)),4)*90
	selected.emit(selection)
	queue_redraw()

func choose_group(refs: Array) -> void:
	group_refs = refs.duplicate(true)
	if not refs.is_empty(): group_pivot = Transform.bounds(document,refs).get_center()
	selection = {} if refs.is_empty() else refs[0].duplicate()
	selection_angle = 0
	selected.emit(selection)
	queue_redraw()

func floor_at(point: Vector2) -> Dictionary:
	if not layers.is_editable("floor_regions"): return {}
	for index in range(document.collection("floor_regions").size()-1,-1,-1):
		var ref := {"group":"floor_regions","index":index}
		if document.can_remove(ref) and document.geometry(ref).has_point(world(point)): return ref
	return {}

func floor_corner(point: Vector2) -> int:
	if selection.get("group","") != "floor_regions" or not document.can_remove(selection): return -1
	var area: Rect2 = document.geometry(selection)
	var corners := [area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]
	for index in range(4):
		if screen(corners[index]).distance_to(point) <= 9: return index
	return -1

func floor_drag_rect(anchor: Vector2, end: Vector2) -> Rect2:
	var bounds: Rect2 = document.geometry({"group":"bounds","index":-1})
	var point: Vector2 = document.snap_point(end).clamp(bounds.position,bounds.end)
	var rect := Rect2(anchor,point-anchor).abs()
	var minimum: float = maxf(1,document.grid)
	rect.size = rect.size.max(Vector2.ONE*minimum)
	return document.clamp_floor_rect(rect)

func group_bounds() -> Rect2:
	var area := Transform.bounds(document,group_refs)
	if group_dragging: area.position += group_drag_delta
	return area

func marquee_select(area: Rect2) -> void:
	var refs: Array = []
	for ref in entry_refs:
		var key := str(layers.key_for(ref.group))
		var architectural: bool = ref.group in ["walls","door","access_doors","dorm_doors"]
		var semantic: bool = ref.group in ["visibility_rooms","zones","dormitories","confinement"]
		if semantic:
			# Room/floor metadata follows a building even when its debug overlay is off.
			if not selection_scope.walls or layers.locked[key]: continue
		elif not layers.is_editable(ref.group): continue
		elif architectural:
			if not selection_scope.walls: continue
		elif not bool(selection_scope.get(key,false)): continue
		if ref.group=="bounds" or ref.group in ["exit","escape_routes","crate","guard_zone","patrol"]: continue
		var r: Rect2 = document.geometry(ref)
		if area.grow(1).encloses(r) if document.is_rect(ref) else area.has_point(r.position): refs.append(ref.duplicate())
	choose_group(refs)
	blocked.emit("已框选 %d 个对象；拖动整体移动，R 右转，Shift+R 左转。" % refs.size() if not refs.is_empty() else "框内没有可编辑对象；请包住整栋建筑。")

func rotate_selection(turns := 1) -> bool:
	finish_gesture()
	var refs: Array = group_refs if not group_refs.is_empty() else [selection] if not selection.is_empty() else []
	if refs.is_empty(): return false
	for ref in refs:
		if layers.locked[layers.key_for(ref.group)]:
			blocked.emit("选中对象含锁定图层，请先解锁。")
			return false
	var snapshot: Dictionary = Transform.capture(document,refs,not group_refs.is_empty())
	if not group_refs.is_empty(): snapshot.pivot = group_pivot
	var target: Rect2 = Transform.rectangle(snapshot.bounds,snapshot.bounds.get_center(),turns)
	if not document.geometry({"group":"bounds","index":-1}).encloses(target):
		blocked.emit("旋转后超出地图边界，请先把建筑移到空旷处。")
		return false
	document.begin()
	Transform.apply(document,snapshot,turns)
	document.commit()
	selection_angle = posmod(selection_angle+turns*90,360)
	edited.emit()
	queue_redraw()
	return true

func finish_gesture(cancel := false) -> void:
	var edited_floor: bool = painting_floor or drag_ref.get("group","") == "floor_regions"
	var finished_floor_paint: bool = painting_floor and tool == "floor_paint" and not cancel
	var had_edit := not drag_ref.is_empty() or drawing_wall or painting_floor or erasing or group_dragging
	var erased := erased_count if erasing else 0
	if group_dragging:
		architecture_preview.preview_group_offset(group_refs,Vector2.ZERO)
		if not cancel and group_drag_delta!=Vector2.ZERO:
			Transform.apply(document,group_snapshot,0,group_drag_delta)
			group_pivot += group_drag_delta
	if had_edit:
		if cancel:
			document.cancel_transaction()
		else:
			document.commit()
	drag_ref.clear()
	group_dragging = false
	group_drag_delta = Vector2.ZERO
	group_snapshot.clear()
	if marquee_active and not cancel:
		marquee_select(Rect2(marquee_start,marquee_end-marquee_start).abs())
	marquee_active = false
	drawing_wall = false
	painting_floor = false
	floor_resizing = false
	if finished_floor_paint: tool = "floor_edit"
	erasing = false
	erased_count = 0
	eraser.candidates.clear()
	eraser_hover = {}
	panning = false
	if had_edit: edited.emit()
	if edited_floor: architecture_preview.schedule_refresh()
	if erased > 0: blocked.emit("已取消本次擦除。" if cancel else "已擦除 %d 个对象；Ctrl+Z 可撤销整次擦除。" % erased)
	queue_redraw()

func update_erase(pointer: Vector2) -> void:
	var refs: Array = eraser.sweep(self,eraser_pointer,pointer)
	if not refs.is_empty():
		erased_count += document.remove_many(refs)
		eraser.remap(document.last_removed_refs)
	eraser_pointer = pointer
	eraser_hover = {}
	queue_redraw()

func update_tile_stroke(end: Vector2) -> void:
	document.data.walls.resize(stroke_wall_count)
	if document.data.get("architecture",{}).has("wall_surfaces"):
		document.data.architecture.wall_surfaces.resize(stroke_surface_count)
	var delta: Vector2=end-draw_start
	if absf(delta.x)>=absf(delta.y):
		var x := minf(draw_start.x,end.x)
		var limit := x+maxf(20,absf(delta.x))
		while x<limit:
			var id := "prison_h_a" if limit-x>=40 else "prison_h_short_a"
			var p := Vector2(x,draw_start.y)
			if stroke_variant.is_valid(): id=stroke_variant.call(id,p)
			document.append_wall_tile(id,p)
			x+=float(definitions[id].render_size[0])
	else:
		var y := minf(draw_start.y,end.y)
		var limit := y+maxf(20,absf(delta.y))
		while y<limit:
			var id := "prison_v_long" if limit-y>=120 else "prison_v_a" if limit-y>=60 else "prison_v_short"
			var p := Vector2(draw_start.x,y)
			if stroke_variant.is_valid(): id=stroke_variant.call(id,p)
			document.append_wall_tile(id,p)
			y+=float(definitions[id].render_size[1])
	selection={"group":"walls","index":stroke_wall_count}
	document.changed.emit()
	queue_redraw()

func handle_input(event: InputEvent) -> void:
	if document == null or document.data.is_empty():
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			finish_gesture()
			var before := world(event.position)
			zoom = clampf(zoom*(1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1/1.15),0.08,3)
			origin = event.position-before*zoom
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and (tool == "pan" or Input.is_physical_key_pressed(KEY_SPACE))):
			if event.pressed: finish_gesture()
			panning = event.pressed
			last_pointer = event.position
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				finish_gesture()
				accept_event()
				return
			interaction_started.emit()
			if tool in ["floor_edit","floor_paint"]:
				if not layers.is_editable("floor_regions"):
					blocked.emit("地面图层已隐藏或锁定，请先显示并解锁。")
					return
				if tool == "floor_paint":
					var bounds: Rect2 = document.geometry({"group":"bounds","index":-1})
					if floor_material.is_empty() or not bounds.has_point(world(event.position)): return
					draw_start = document.snap_point(world(event.position)).clamp(bounds.position,bounds.end)
					document.begin()
					painting_floor = true
					choose(document.append_floor(floor_drag_rect(draw_start,draw_start),floor_material))
				else:
					var corner := floor_corner(event.position)
					if corner >= 0:
						var area: Rect2 = document.geometry(selection)
						var corners := [area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]
						floor_resize_anchor = corners[(corner+2)%4]
						drag_ref = selection.duplicate()
						floor_resizing = true
						document.begin()
					else:
						choose(floor_at(event.position))
						if not selection.is_empty():
							drag_ref = selection.duplicate()
							drag_offset = world(event.position)-document.geometry(selection).position
							document.begin()
			elif tool in ["select","marquee"] and not group_refs.is_empty() and group_bounds().has_point(world(event.position)):
				group_dragging = true
				group_drag_start = world(event.position)
				group_drag_delta = Vector2.ZERO
				group_snapshot = Transform.capture(document,group_refs)
				document.begin()
			elif tool=="marquee" or (tool=="select" and at(event.position).is_empty()):
				marquee_active = true
				marquee_start = world(event.position)
				marquee_end = marquee_start
				choose({})
			elif tool == "select":
				choose(at(event.position))
				if not selection.is_empty():
					drag_ref = selection.duplicate()
					drag_offset = world(event.position)-document.geometry(selection).position
					document.begin()
			elif tool == "eraser":
				choose({})
				eraser.capture(self)
				document.begin()
				erasing = true
				erased_count = 0
				eraser_pointer = event.position
				update_erase(event.position)
			elif tool == "walls":
				if not layers.is_editable("walls"):
					blocked.emit("墙门 / 机关图层已隐藏或锁定，请先显示并解锁。")
					accept_event()
					return
				if placement_asset != "":
					placed.emit("walls",world(event.position))
					accept_event()
					return
				draw_start = world(event.position).snapped(Vector2(20,20))
				stroke_wall_count=document.data.walls.size()
				stroke_surface_count=document.data.get("architecture",{}).get("wall_surfaces",[]).size()
				document.begin()
				drawing_wall = true
				update_tile_stroke(draw_start)
				choose(selection)
			else:
				if layers.is_editable(tool): placed.emit(tool,document.snap_point(world(event.position)))
				else: blocked.emit("当前放置图层已隐藏或锁定。")
			accept_event()
	elif event is InputEventMouseMotion:
		if panning:
			origin += event.position-last_pointer
			last_pointer = event.position
			queue_redraw()
			accept_event()
		elif erasing:
			update_erase(event.position)
			accept_event()
		elif painting_floor:
			document.set_geometry(selection,floor_drag_rect(draw_start,world(event.position)))
			accept_event()
		elif floor_resizing:
			document.set_geometry(drag_ref,floor_drag_rect(floor_resize_anchor,world(event.position)))
			accept_event()
		elif marquee_active:
			marquee_end = world(event.position)
			queue_redraw()
			accept_event()
		elif group_dragging:
			var delta: Vector2 = document.snap_point(world(event.position)-group_drag_start)
			var target: Rect2 = group_snapshot.bounds
			target.position += delta
			if document.geometry({"group":"bounds","index":-1}).encloses(target):
				group_drag_delta = delta
				architecture_preview.preview_group_offset(group_refs,delta)
				queue_redraw()
			accept_event()
		elif drawing_wall:
			update_tile_stroke(world(event.position).snapped(Vector2(20,20)))
			accept_event()
		elif not drag_ref.is_empty():
			document.move(drag_ref,world(event.position)-drag_offset)
			accept_event()
		elif tool == "eraser":
			eraser_pointer = event.position
			if architecture_preview.pending: architecture_preview.refresh()
			eraser_hover = at(event.position,true).duplicate()
			queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("303e40"))
	if document == null or document.data.is_empty():
		return
	var bounds: Rect2 = document.geometry({"group":"bounds","index":-1})
	var view := Rect2(world(Vector2.ZERO),size/zoom)
	var floor_rect := Rect2(screen(bounds.position),bounds.size*zoom)
	draw_rect(floor_rect,Color("a5af9a"))
	var floor_texture: Texture2D = textures.get(str(render_profile.get("floor_asset","")))
	if floor_texture != null:
		var tile := Vector2.ONE*float(render_profile.floor_tile_size)*zoom
		load("res://scripts/presentation/texture_tiles.gd").paint(self,floor_texture,floor_rect,tile,Rect2(Vector2.ZERO,size))
	if layers.is_visible("floor_regions"):
		preload("res://scripts/presentation/region_terrain.gd").paint(self,document.data,view,origin,zoom)
		preload("res://scripts/presentation/site_details.gd").paint(self,document.data.get("ground_details",[]),origin,zoom,view)
	architecture_preview.position = origin
	architecture_preview.scale = Vector2.ONE*zoom
	foreground.queue_redraw()
	var step: float = maxf(20,document.grid)
	grid_line_count = 0
	if step*zoom < 12: step = 100
	if step*zoom >= 6:
		var grid_areas: Array[Rect2]=[bounds]
		if document.data.has("floor_regions"):
			grid_areas.clear()
			for region in document.data.floor_regions:
				if bool(region.get("natural_ground",false)) or str(region.asset_id)=="earth_v45":continue
				var r: Array=region.rect
				grid_areas.append(Rect2(r[0],r[1],r[2],r[3]))
		for area in grid_areas:
			area = area.intersection(view)
			if not area.has_area(): continue
			for x in range(ceili(area.position.x/step),floori(area.end.x/step)+1):
				draw_line(screen(Vector2(x*step,area.position.y)),screen(Vector2(x*step,area.end.y)),Color(0.18,0.26,0.24,0.10),1)
				grid_line_count += 1
			for y in range(ceili(area.position.y/step),floori(area.end.y/step)+1):
				draw_line(screen(Vector2(area.position.x,y*step)),screen(Vector2(area.end.x,y*step)),Color(0.18,0.26,0.24,0.10),1)
				grid_line_count += 1
	var entries: Array = entry_refs
	# Enclosing regions are painted before furniture and points.
	for ref in entries:
		if not layers.is_visible(ref.group): continue
		if ref.group in ["guard_zone","zones","dormitories","confinement","visibility_rooms"]:
			var tint := Color("cf9975") if ref.group == "guard_zone" else Color("75c0b5") if ref.group == "dormitories" else Color("e0d29e")
			paint_rect(ref,tint,true)

func collision_geometry(ref: Dictionary, fallback: Rect2) -> Rect2:
	if architecture_preview == null or architecture_preview.boundary_clips.is_empty(): return fallback
	var id := "primary" if ref.group=="door" else "dorm-%d" % int(ref.index) if ref.group=="dorm_doors" else str(document.value(ref).get("id","")) if ref.group=="access_doors" else ""
	var view = architecture_preview.doorways.by_id(id)
	return fallback if view==null else view.visual_rect

func paint_foreground(painter: CanvasItem) -> void:
	if document == null or document.data.is_empty(): return
	var entries: Array = entry_refs
	var view := Rect2(world(Vector2.ZERO),size/zoom).grow(120/zoom)
	if show_collision and architecture_preview != null and layers.is_visible("walls"):
		for pieces in architecture_preview.boundary_clips.values():
			for area in pieces:
				painter.draw_rect(Rect2(screen(area.position),area.size*zoom),Color(0.9,0.3,0.2,0.3))
	for ref in entries:
		if not layers.is_visible(ref.group): continue
		if ref.group == "floor_regions": continue
		if ref.group in ["bounds","guard_zone","zones","dormitories","confinement","visibility_rooms"]:
			continue
		if not show_collision and ref.group in ["walls","fixtures","door","crate","access_doors"]: continue
		if not show_collision and ref.group == "dorm_doors" and document.data.has("concept_plan"): continue
		var rect: Rect2 = document.geometry(ref)
		if not view.intersects(rect) and not view.has_point(rect.position): continue
		if document.is_rect(ref):
			if show_collision and ref.group in ["walls","fixtures","door","crate","access_doors","dorm_doors"]:
				if ref.group == "walls" and document.wall_surface(int(ref.index)).has("collision_parts"):
					for part in document.wall_surface(int(ref.index)).collision_parts:
						var area := Rect2(rect.position+Vector2(part[0],part[1]),Vector2(part[2],part[3]))
						painter.draw_rect(Rect2(screen(area.position),area.size*zoom),Color(0.9,0.3,0.2,0.22))
				elif ref.group in ["door","access_doors","dorm_doors"]:
					var area := collision_geometry(ref,rect)
					painter.draw_rect(Rect2(screen(area.position),area.size*zoom),Color(0.9,0.3,0.2,0.22))
				elif ref.group == "fixtures" and document.value(ref).get("hidden",false):
					paint_rect(ref,Color(0.9,0.3,0.2,0.3),false,painter)
				else:
					paint_rect(ref,Color(0.9,0.3,0.2,0.22),false,painter)
			elif ref.group in ["exit","escape_routes"]: paint_rect(ref,Color(0.19,0.55,0.51,0.35),true,painter)
			elif ref.group == "dorm_doors" and not document.data.has("concept_plan"): paint_rect(ref,Color("a17b4b"),false,painter)
		else:
			var p := screen(rect.position)
			var color := Color("328b82") if ref.group in ["starts","work","meal","dine","free"] else Color("d5846a") if ref.group in ["patrol","gate_guards","guard_start"] else Color("efd69f")
			painter.draw_circle(p,7,color,true,-1,true)
			painter.draw_circle(p,8,Color("f2ebdd"),false,1,true)
			if zoom > 0.17:
				var short_names := {"starts":"伙伴","work":"工","meal":"餐","dine":"桌","free":"活动","patrol":"巡","gate_guards":"门岗","guard_start":"看守","merchants":"商人","resident_staff":"岗位","items":"物品"}
				var label: String = short_names.get(ref.group,ref.group)+(str(int(ref.index)+1) if int(ref.index) >= 0 else "")
				if zoom >= 0.45 or selection == ref or ref.group in ["starts","merchants","gate_guards"]:
					painter.draw_string(font,p+Vector2(10,4),label,HORIZONTAL_ALIGNMENT_LEFT,100,12,Color("243739"))
	var patrol: Array = document.data.get("patrol",[]) if layers.is_visible("patrol") else []
	for index in range(patrol.size()):
		var a: Array = patrol[index]
		var b: Array = patrol[(index+1)%patrol.size()]
		painter.draw_line(screen(Vector2(a[0],a[1])),screen(Vector2(b[0],b[1])),Color("cf795c"),2,true)
	if not group_refs.is_empty() or marquee_active:
		var area: Rect2 = Rect2(marquee_start,marquee_end-marquee_start).abs() if marquee_active else group_bounds()
		var box := Rect2(screen(area.position),area.size*zoom)
		var teal := Color("268f86")
		painter.draw_rect(box,Color(0.15,0.6,0.55,0.08))
		var corners := [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
		for index in range(4):
			painter.draw_dashed_line(corners[index],corners[(index+1)%4],teal,2,7)
			painter.draw_rect(Rect2(corners[index]-Vector2(4,4),Vector2(8,8)),Color("f6f2e7"))
			painter.draw_rect(Rect2(corners[index]-Vector2(4,4),Vector2(8,8)),teal,false,1.5)
		if not marquee_active:
			var center := box.get_center()
			painter.draw_line(center-Vector2(8,0),center+Vector2(8,0),teal,2,true)
			painter.draw_line(center-Vector2(0,8),center+Vector2(0,8),teal,2,true)
			painter.draw_arc(center,26,-PI*0.9,PI*0.2,24,teal,2,true)
			painter.draw_string(font,box.position+Vector2(4,-9),"建筑框选 · %d 个对象" % group_refs.size(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ffffff"))
	elif not selection.is_empty():
		var rect: Rect2 = document.geometry(selection)
		if document.is_rect(selection):
			painter.draw_rect(Rect2(screen(rect.position),rect.size*zoom).grow(3),Color("fff1b2"),false,3)
			if selection.group == "floor_regions" and tool == "floor_edit" and document.can_remove(selection):
				for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
					painter.draw_rect(Rect2(screen(corner)-Vector2(5,5),Vector2(10,10)),Color("fff1b2"))
		else:
			painter.draw_circle(screen(rect.position),13,Color("fff1b2"),false,3,true)
	if tool == "eraser" and eraser_inside:
		if not eraser_hover.is_empty() and document.can_remove(eraser_hover):
			var rect: Rect2 = document.geometry(eraser_hover)
			var areas: Array[Rect2] = []
			areas.append(rect.grow(5/zoom) if document.is_rect(eraser_hover) else Rect2(rect.position-Vector2.ONE*11/zoom,Vector2.ONE*22/zoom))
			if not show_collision and eraser_hover.group in ["walls","fixtures","access_doors","dorm_doors"]: areas.assign(architecture_preview.visual_hit_areas(eraser_hover))
			for area in areas:
				painter.draw_rect(Rect2(screen(area.position),area.size*zoom),Color(0.9,0.3,0.2,0.22))
				painter.draw_rect(Rect2(screen(area.position),area.size*zoom),Color("ef967e"),false,2)
		painter.draw_circle(eraser_pointer,10,Color("ef967e"),false,2,true)
		painter.draw_line(eraser_pointer-Vector2(4,0),eraser_pointer+Vector2(4,0),Color("fff1dc"),2,true)
		if erasing: painter.draw_string(font,eraser_pointer+Vector2(15,-12),"已擦除 %d" % erased_count,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("fff1dc"))
	if font:
		var hint := "橡皮擦 · 按住左键连续删除 · Ctrl+Z 撤销 · Esc 取消" if tool == "eraser" else "拖出矩形铺地板 · G 编辑地板 · Esc 取消" if tool == "floor_paint" else "点击地板选择 · 拖动移动 · 拖四角调整范围" if tool == "floor_edit" else "中键/空格拖动视野 · 滚轮缩放"
		painter.draw_string(font,Vector2(12,size.y-12),"%.0f%% · " % (zoom*100)+hint,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f2ebdd"))

func paint_rect(ref: Dictionary, color: Color, outline := false, painter: CanvasItem = null) -> void:
	if painter == null: painter = self
	var rect: Rect2 = document.geometry(ref)
	var on_screen := Rect2(screen(rect.position),rect.size*zoom)
	if outline:
		painter.draw_rect(on_screen,Color(color,0.12))
		painter.draw_rect(on_screen,color,false,1.5)
		if zoom > 0.17 and (ref.group in ["zones","visibility_rooms"] or selection == ref):
			var text: String = str(document.value(ref).get("name","区域")) if ref.group in ["zones","visibility_rooms"] else document.name_for(ref)
			painter.draw_string(font,on_screen.position+Vector2(4,14),text,HORIZONTAL_ALIGNMENT_LEFT,on_screen.size.x,12,Color("243739"))
	else:
		painter.draw_rect(on_screen,color)
