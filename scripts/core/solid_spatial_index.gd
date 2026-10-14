extends RefCounted

# Exact collision geometry, with a small broad phase for circle placement.
const CELL := 128.0
var buckets: Dictionary = {}
var rects: Array[Rect2] = []
var revision := -1
var entries: Dictionary = {}
var entry_ids: Dictionary = {}
var next_id := 0

func rebuild(solids: Array[Rect2], new_revision: int) -> void:
	# A door revision can leave this particular collision class unchanged.
	# Reuse its buckets rather than reallocating every wall/furniture entry.
	if revision >= 0 and solids == rects:
		revision = new_revision
		return
	if revision < 0:
		buckets.clear();entries.clear();entry_ids.clear();next_id=0
	var wanted: Dictionary = {}
	for rect in solids: wanted[rect]=int(wanted.get(rect,0))+1
	# Stable IDs let a leaf edit update just its buckets. Array positions can
	# shift when a door closes; those shifts must not reindex every fixed wall.
	for rect: Rect2 in entry_ids.keys():
		var ids: Array=entry_ids[rect]
		var count: int=wanted.get(rect,0)
		while ids.size()>count:
			var id: int=ids.pop_back()
			_remove(rect,id);entries.erase(id)
		if ids.is_empty(): entry_ids.erase(rect)
	for rect: Rect2 in wanted:
		if not entry_ids.has(rect): entry_ids[rect]=[]
		var ids: Array=entry_ids[rect]
		while ids.size()<int(wanted[rect]):
			var id:=next_id;next_id+=1
			ids.append(id);entries[id]=rect;_insert(rect,id)
	revision = new_revision
	rects = solids.duplicate()

func _insert(rect: Rect2, id: int) -> void:
	var low := Vector2i(floori(rect.position.x/CELL),floori(rect.position.y/CELL))
	var high := Vector2i(floori(rect.end.x/CELL),floori(rect.end.y/CELL))
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var key := Vector2i(x,y)
			if not buckets.has(key): buckets[key]=[]
			buckets[key].append(id)

func _remove(rect: Rect2, id: int) -> void:
	var low := Vector2i(floori(rect.position.x/CELL),floori(rect.position.y/CELL))
	var high := Vector2i(floori(rect.end.x/CELL),floori(rect.end.y/CELL))
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var key := Vector2i(x,y)
			buckets[key].erase(id)
			if buckets[key].is_empty(): buckets.erase(key)

func nearby(point: Vector2, radius: float) -> Array[Rect2]:
	return intersecting(Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2))

func intersecting(area: Rect2) -> Array[Rect2]:
	var low := Vector2i(floori(area.position.x/CELL),floori(area.position.y/CELL))
	var high := Vector2i(floori(area.end.x/CELL),floori(area.end.y/CELL))
	var result: Array[Rect2] = []
	if low == high:
		for id in buckets.get(low,[]): result.append(entries[id])
		return result
	var seen := {}
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for id in buckets.get(Vector2i(x,y),[]):
				if seen.has(id): continue
				seen[id] = true
				result.append(entries[id])
	return result

func along_segment(from: Vector2, to: Vector2, radius: float) -> Array[Rect2]:
	var area := Rect2(from,Vector2.ZERO).expand(to).grow(radius)
	if maxf(area.size.x,area.size.y) <= CELL*4: return intersecting(area)
	# Samples at most one cell apart; a one-cell margin covers the whole
	# swept segment. This only selects candidates, exact tests remain unchanged.
	var steps := maxi(1,ceili(maxf(absf(to.x-from.x),absf(to.y-from.y))/CELL))
	var seen: Dictionary = {}
	var visited_buckets: Dictionary = {}
	var result: Array[Rect2] = []
	for step in range(steps+1):
		var point := from.lerp(to,float(step)/steps)
		var margin := Vector2.ONE*(radius+CELL)
		var low := Vector2i(floori((point.x-margin.x)/CELL),floori((point.y-margin.y)/CELL))
		var high := Vector2i(floori((point.x+margin.x)/CELL),floori((point.y+margin.y)/CELL))
		for y in range(low.y,high.y+1):
			for x in range(low.x,high.x+1):
				var key := Vector2i(x,y)
				if visited_buckets.has(key): continue
				visited_buckets[key]=true
				for id in buckets.get(key,[]):
					var rect: Rect2=entries[id]
					if seen.has(rect): continue
					seen[rect]=true
					result.append(rect)
	return result
