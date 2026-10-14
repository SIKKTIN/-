extends RefCounted

static func first_space(occupied: Dictionary, dimensions: Vector2i, shape: Vector2i) -> Vector2i:
	for y in range(dimensions.y-shape.y+1):
		for x in range(dimensions.x-shape.x+1):
			var candidate:=Rect2i(Vector2i(x,y),shape)
			if not occupied.values().any(func(rect):return rect.intersects(candidate)):
				return candidate.position
	return Vector2i(-1,-1)

static func pack(entries: Array, dimensions: Vector2i) -> Dictionary:
	var result: Dictionary={}
	for entry in entries:
		var shape: Vector2i=entry.shape
		var point:=first_space(result,dimensions,shape)
		if point.x>=0:result[str(entry.id)]=Rect2i(point,shape)
	return result

# Validate the entire footprint before any ownership or position changes.
static func fits(occupied: Dictionary, dimensions: Vector2i, candidate: Rect2i, ignore: String="") -> bool:
	if not Rect2i(Vector2i.ZERO,dimensions).encloses(candidate):return false
	for id in occupied:
		if str(id)!=ignore and occupied[id].intersects(candidate):return false
	return true
