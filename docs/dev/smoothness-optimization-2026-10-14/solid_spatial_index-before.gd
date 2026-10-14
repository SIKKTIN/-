extends RefCounted

# Exact collision geometry, with a small broad phase for circle placement.
const CELL := 128.0
var buckets: Dictionary = {}
var rects: Array[Rect2] = []
var revision := -1

func rebuild(solids: Array[Rect2], new_revision: int) -> void:
	revision = new_revision
	rects = solids.duplicate()
	buckets.clear()
	for id in range(rects.size()):
		var rect: Rect2 = rects[id]
		var low := Vector2i(floori(rect.position.x/CELL),floori(rect.position.y/CELL))
		var high := Vector2i(floori(rect.end.x/CELL),floori(rect.end.y/CELL))
		for y in range(low.y,high.y+1):
			for x in range(low.x,high.x+1):
				var key := Vector2i(x,y)
				if not buckets.has(key): buckets[key] = []
				buckets[key].append(id)

func nearby(point: Vector2, radius: float) -> Array[Rect2]:
	return intersecting(Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2))

func intersecting(area: Rect2) -> Array[Rect2]:
	var low := Vector2i(floori(area.position.x/CELL),floori(area.position.y/CELL))
	var high := Vector2i(floori(area.end.x/CELL),floori(area.end.y/CELL))
	var result: Array[Rect2] = []
	if low == high:
		for id in buckets.get(low,[]): result.append(rects[id])
		return result
	var seen := {}
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for id in buckets.get(Vector2i(x,y),[]):
				if seen.has(id): continue
				seen[id] = true
				result.append(rects[id])
	return result

func along_segment(from: Vector2, to: Vector2, radius: float) -> Array[Rect2]:
	var area := Rect2(from,Vector2.ZERO).expand(to).grow(radius)
	if maxf(area.size.x,area.size.y) <= CELL*4: return intersecting(area)
	# Samples at most one cell apart; a one-cell margin covers the whole
	# swept segment. This only selects candidates, exact tests remain unchanged.
	var steps := maxi(1,ceili(maxf(absf(to.x-from.x),absf(to.y-from.y))/CELL))
	var seen: Dictionary = {}
	var result: Array[Rect2] = []
	for step in range(steps+1):
		for rect in nearby(from.lerp(to,float(step)/steps),radius+CELL):
			if not seen.has(rect):
				seen[rect] = true
				result.append(rect)
	return result
