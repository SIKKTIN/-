extends RefCounted

const Footprint = preload("res://scripts/core/actor_footprint.gd")
const Geometry = preload("res://scripts/presentation/doorway_geometry.gd")
var world
var portals: Array = []

func configure(source_world, rooms: Array) -> void:
	world = source_world
	portals.clear()
	for gate in world.access_doors+world.dorm_doors:
		gate.merge(Geometry.art_spec(gate),false)
		if gate.has("sliding_door"): gate.slide_fraction = 1.0 if gate.get("closed",false) else 0.0
		_add(Geometry.projected_rect(world,gate),gate,gate in world.dorm_doors,false)
	_add(Geometry.projected_rect(world,Geometry.primary_spec(world)),{},false,true)
	for fixture in world.fixtures:
		if not Geometry.managed_fixture(fixture) or Geometry.controlled_fixture(fixture): continue
		var asset := str(fixture.asset_id)
		var gate: Dictionary = Geometry.art_spec(fixture).duplicate(true)
		gate.id = "fixture:"+str(fixture.get("id",fixture.rect))
		gate.closed = not (asset.contains("open") or asset=="doorway_free_v48")
		if gate.has("sliding_door"): gate.slide_fraction = 1.0 if gate.closed else 0.0
		_add(Geometry.projected_rect(world,gate),gate,bool(gate.get("manual_door",false)),false)
	for room in rooms:
		for port in room.roof_plan.ports:
			if port.id=="open-passage" and not portals.any(func(p):return p.rect.grow(4).intersects(port.rect)):
				_add(port.rect,{},false,false)

func _add(rect: Rect2, gate: Dictionary, dorm: bool, primary: bool) -> void:
	portals.append({"rect":rect,"gate":gate,"dorm":dorm,"primary":primary})

func by_id(id: String) -> Dictionary:
	for port in portals:
		if str(port.gate.get("id",""))==id: return port.gate
	return {}

func solids(inspection := false) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for port in portals:
		var rect: Rect2 = port.rect
		if port.gate.has("sliding_door"):
			for part in preload("res://scripts/presentation/sliding_door_geometry.gd").world_solids(port.gate,rect,float(port.gate.get("slide_fraction",0))):
				result.append_array(Footprint.silhouette_obstacles(part))
			continue
		if port.gate.has("visual_solid_parts"):
			var closed: bool = port.gate.get("closed",false) and not (inspection and port.dorm) and (str(port.gate.get("kind","")) != "open" or port.gate.get("manual_door",false))
			var pieces: Array = port.gate.get("closed_visual_solid_parts",port.gate.visual_solid_parts) if closed else port.gate.visual_solid_parts
			for values in pieces:
				var part := Rect2(values[0],values[1],values[2],values[3])
				var dims: Array = port.gate.door_art_size
				match posmod(int(port.gate.get("rotation_quarters",0)),4):
					1: part = Rect2(float(dims[1])-part.end.y,part.position.x,part.size.y,part.size.x)
					2: part.position = Vector2(dims[0],dims[1])-part.end
					3: part = Rect2(part.position.y,float(dims[0])-part.end.x,part.size.y,part.size.x)
				part.position += rect.position
				var obstacles: Array[Rect2] = []
				if port.gate.get("body_profile","")=="human_silhouette":
					obstacles.append_array(Footprint.silhouette_obstacles(part))
				else:
					obstacles.append(Footprint.door_anchor_obstacle(part))
				for obstacle in obstacles:
					if port.gate.get("body_depth_limited",false):
						# A person in front of a raised facade is drawn in front of it.
						# Projected head overlap must not block the clear foreground.
						# Keep whole-body checks behind the door and foot contact at its base.
						var limit: float = Footprint.front_contact_y(port.gate.rect)
						obstacle.size.y = minf(obstacle.end.y,limit)-obstacle.position.y
					if obstacle.has_area(): result.append(obstacle)
			continue
		if port.gate.has("visual_jambs"):
			for values in port.gate.visual_jambs:
				result.append(Footprint.door_anchor_obstacle(Rect2(rect.position+Vector2(values[0],values[1]),Vector2(values[2],values[3]))))
			continue
		var vertical: bool = rect.size.y>rect.size.x
		var cap := minf(8,rect.size.y*0.20) if vertical else minf(9,rect.size.x*0.10)
		var first := Rect2(rect.position,Vector2(rect.size.x,cap)) if vertical else Rect2(rect.position,Vector2(cap,rect.size.y))
		var last := Rect2(rect.position.x,rect.end.y-cap,rect.size.x,cap) if vertical else Rect2(rect.end.x-cap,rect.position.y,cap,rect.size.y)
		result.append(Footprint.door_anchor_obstacle(first))
		result.append(Footprint.door_anchor_obstacle(last))
		var closed: bool = not world.door_open if port.primary else bool(port.gate.get("closed",false))
		if str(port.gate.get("kind",""))=="open" or (inspection and port.dorm): closed=false
		if closed:
			var leaf := Rect2(rect.position+Vector2(0,cap),rect.size-Vector2(0,cap*2)) if vertical else Rect2(rect.position+Vector2(cap,0),rect.size-Vector2(cap*2,0))
			result.append(Footprint.door_anchor_obstacle(leaf))
	return result
