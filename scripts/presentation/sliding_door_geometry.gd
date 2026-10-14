extends RefCounted

# One physical leaf size, translated horizontally: no shrinking at open state.
static func leaves(gate: Dictionary, fraction: float) -> Array[Rect2]:
	var values: Array = gate.sliding_door.leaf_rect
	var size := Vector2(values[2],values[3])
	var offset := size.x*(1-clampf(fraction,0,1))
	return [Rect2(float(values[0])-offset,float(values[1]),size.x,size.y),Rect2(float(values[0])+size.x+offset,float(values[1]),size.x,size.y)]

static func world_solids(gate: Dictionary, opening: Rect2, fraction: float) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var values: Array = gate.sliding_door.solid_rect
	var dims: Array = gate.door_art_size
	for leaf in leaves(gate,fraction):
		var part := Rect2(leaf.position+Vector2(values[0],float(values[1])-float(gate.sliding_door.leaf_rect[1])),Vector2(values[2],values[3]))
		match posmod(int(gate.get("rotation_quarters",0)),4):
			1: part = Rect2(float(dims[1])-part.end.y,part.position.x,part.size.y,part.size.x)
			2: part.position = Vector2(dims[0],dims[1])-part.end
			3: part = Rect2(part.position.y,float(dims[0])-part.end.x,part.size.y,part.size.x)
		part.position += opening.position
		result.append(part)
	return result
