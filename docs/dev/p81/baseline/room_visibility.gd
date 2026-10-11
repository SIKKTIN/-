extends RefCounted

const Cover = preload("res://scripts/presentation/room_cover.gd")
const RoofGeometry = preload("res://scripts/presentation/roof_geometry.gd")
const WallEdges = preload("res://scripts/presentation/roof_wall_edges.gd")
var game
var rooms: Array = []
var visited: Dictionary = {}
var active_id := ""
var revision := 0
var covers: Array = []
var wall_edges
var _current_area := Rect2()
var _hidden_areas: Array[Rect2] = []

func _init(owner_game) -> void:
	game = owner_game

# Old maps remain playable; editing writes these derived regions explicitly.
static func rooms_for(config: Dictionary) -> Array:
	if config.has("visibility_rooms"): return config.visibility_rooms.duplicate(true)
	var result: Array = []
	var dorms: Array = config.get("dormitories",[])
	if dorms.is_empty():
		var schedule: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/schedule.json"))
		dorms = schedule.get("room_dormitories",{}).get(str(config.get("id","")),[])
	for index in range(dorms.size()):
		result.append({"id":"dorm-%d" % index,"name":"寝室%d" % (index+1),"rect":dorms[index].duplicate(),"door_ids":[],"kind":"dorm"})
	var workshop: Dictionary = config.get("workshop",{})
	if workshop.has("room_rect"):
		result.append({"id":"workshop","name":"生产车间","rect":workshop.room_rect.duplicate(),"door_ids":[str(workshop.access_id)],"kind":"room"})
	for gate in config.get("access_doors",[]):
		if not gate.has("room_rect") or str(gate.id) == "loading-exit": continue
		var existing: Array = result.filter(func(room): return room.rect == gate.room_rect)
		if not existing.is_empty():
			if str(gate.id) not in existing[0].door_ids: existing[0].door_ids.append(str(gate.id))
		else:
			result.append({"id":str(gate.id)+"-room","name":"食堂" if str(gate.id)=="cafeteria-entry" else str(gate.get("name","房间")),"rect":gate.room_rect.duplicate(),"door_ids":[str(gate.id)],"kind":"room"})
	for cell in config.get("confinement",{}).get("cells",[]):
		result.append({"id":str(cell.id),"name":str(cell.get("name","禁闭室")),"rect":cell.rect.duplicate(),"door_ids":[str(cell.door_id)],"kind":"confinement"})
	for zone in config.get("zones",[]):
		if str(zone.get("id","")) in ["warehouse","laundry","equipment"]:
			var doors: Array = []
			var bounds := Rect2(zone.rect[0],zone.rect[1],zone.rect[2],zone.rect[3]).grow(40)
			for gate in config.get("access_doors",[]):
				if bounds.has_point(Rect2(gate.rect[0],gate.rect[1],gate.rect[2],gate.rect[3]).get_center()): doors.append(str(gate.id))
			result.append({"id":str(zone.id),"name":str(zone.name),"rect":zone.rect.duplicate(),"door_ids":doors,"kind":"room"})
	return result

func reset() -> void:
	if is_instance_valid(wall_edges): wall_edges.free()
	for cover in covers: cover.free()
	covers.clear()
	rooms.clear()
	visited.clear()
	active_id = ""
	_current_area = Rect2()
	for spec in rooms_for(game.room_config):
		var room: Dictionary = spec.duplicate(true)
		room.kind = str(spec.get("kind","room"))
		room.door_ids = spec.get("door_ids",[])
		room.area = Rect2(spec.rect[0],spec.rect[1],spec.rect[2],spec.rect[3])
		room.enter_area = room.area.grow(-4)
		room.roof_plan = RoofGeometry.plan(game.world,room)
		rooms.append(room)
	game.world.room_visibility = self
	tick(0,true)
	wall_edges = WallEdges.new()
	game.add_child(wall_edges)
	wall_edges.configure(self)
	for room in rooms:
		var cover = Cover.new()
		game.add_child(cover)
		cover.configure(self,room)
		covers.append(cover)
	revision += 1

func room_at(point: Vector2) -> String:
	for room in rooms:
		if room.area.has_point(point): return str(room.id)
	return ""

func visible_at(point: Vector2) -> bool:
	if _current_area.has_point(point): return true
	for area in _hidden_areas:
		if area.has_point(point): return false
	return true

func tick(delta: float, force := false) -> void:
	if not force and game.get_tree().paused: return
	if game.actors.is_empty(): return
	var point: Vector2 = game.actors[game.PLAYER_ACTOR_ID].position
	var next := active_id
	if not _current_area.has_area() or not _current_area.grow(6).has_point(point):
		next = ""
		for room in rooms:
			# Foot origin, not the sprite/head or another NPC, crosses the threshold.
			if room.enter_area.has_point(point):
				next = str(room.id)
				break
	if force or next != active_id:
		active_id = next
		_current_area = Rect2()
		_hidden_areas.clear()
		for room in rooms:
			if str(room.id)==next: _current_area = room.area
			else: _hidden_areas.append(room.area)
		if not next.is_empty(): visited[next] = true
		revision += 1
		# Presentation synchronizes volumes later in this same frame. A roof
		# transition changes visibility, never static terrain/wall geometry.
		for layer in game.presentation.scene_layers:
			if layer.kind == "fixture_shadows": layer.sync_shadow_visibility()
			elif layer.kind != "ground_static": layer.queue_redraw()
		if game.presentation.lighting: game.presentation.lighting.queue_redraw()
	for cover in covers: cover.tick(delta,force)

func hidden_areas() -> Array[Rect2]:
	return _hidden_areas
