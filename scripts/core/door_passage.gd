extends RefCounted

const Footprint = preload("res://scripts/core/actor_footprint.gd")
const Geometry = preload("res://scripts/presentation/doorway_geometry.gd")
var world
var portals: Array = []

func configure(source_world, rooms: Array) -> void:
	world = source_world
	portals.clear()
	for gate in world.access_doors+world.dorm_doors:
		_add(Geometry.projected_rect(world,gate),gate,gate in world.dorm_doors,false)
	_add(Geometry.projected_rect(world,{"rect":world.door}),{},false,true)
	for fixture in world.fixtures:
		if not Geometry.managed_fixture(fixture) or Geometry.controlled_fixture(fixture): continue
		var asset := str(fixture.asset_id)
		_add(Geometry.projected_rect(world,{"rect":fixture.rect}),{"closed":not (asset.contains("open") or asset=="doorway_free_v48")},false,false)
	for room in rooms:
		for port in room.roof_plan.ports:
			if port.id=="open-passage" and not portals.any(func(p):return p.rect.grow(4).intersects(port.rect)):
				_add(port.rect,{},false,false)

func _add(rect: Rect2, gate: Dictionary, dorm: bool, primary: bool) -> void:
	portals.append({"rect":rect,"gate":gate,"dorm":dorm,"primary":primary})

func solids(inspection := false) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for port in portals:
		var rect: Rect2 = port.rect
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
