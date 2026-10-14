extends RefCounted

# Static reachability at grid resolution. Cardinal components also describe
# ONLY_IF_NO_OBSTACLES diagonals: both adjacent cardinal cells must be free.
# Small chunks let a door edit rebuild its neighbourhood, not the whole map.
const SIDE := 16
const CELLS := SIDE*SIDE
var indexes: Dictionary = {}
var builds := 0
var chunk_builds := 0
var rejections := 0

func reset() -> void:
	indexes.clear()

func has_index(grid: AStarGrid2D) -> bool:
	return indexes.has(grid.get_instance_id())

func touch(grid: AStarGrid2D, cell: Vector2i) -> void:
	var index: Dictionary = indexes.get(grid.get_instance_id(),{})
	if not index.is_empty(): index.dirty[_chunk(cell,index.region)] = true

func warm(grid: AStarGrid2D) -> void:
	var id := grid.get_instance_id()
	if not indexes.has(id):
		var index: Dictionary = {"region":grid.region,"chunks":{},"graph":{},"components":{},"dirty":{}}
		indexes[id] = index
		var dimensions := Vector2i(ceili(grid.region.size.x/float(SIDE)),ceili(grid.region.size.y/float(SIDE)))
		for y in range(dimensions.y):
			for x in range(dimensions.x): _build_chunk(grid,index,Vector2i(x,y))
		for chunk in index.chunks: _link_chunk(index,chunk)
		_components(index)
		builds += 1
		return
	var index: Dictionary = indexes[id]
	if index.dirty.is_empty(): return
	for chunk in index.dirty:
		for node in index.chunks[chunk].nodes:
			for adjacent in index.graph[node]: index.graph[adjacent].erase(node)
			index.graph.erase(node)
		_build_chunk(grid,index,chunk)
	for chunk in index.dirty: _link_chunk(index,chunk)
	index.dirty.clear()
	_components(index)
	builds += 1

func connected(grid: AStarGrid2D, from: Vector2i, to: Vector2i) -> bool:
	# Missing/stale indexes must never incorrectly reject a valid route.
	var index: Dictionary = indexes.get(grid.get_instance_id(),{})
	if index.is_empty() or not index.dirty.is_empty(): return true
	var a := _node(index,from)
	var b := _node(index,to)
	var result: bool = a>=0 and b>=0 and index.components[a]==index.components[b]
	if not result: rejections += 1
	return result

func _chunk(cell: Vector2i, region: Rect2i) -> Vector2i:
	var relative := cell-region.position
	return Vector2i(relative.x/SIDE,relative.y/SIDE)

func _node(index: Dictionary, cell: Vector2i) -> int:
	var region: Rect2i = index.region
	if not region.has_point(cell): return -1
	var chunk := _chunk(cell,region)
	var local := cell-region.position-chunk*SIDE
	var data: Dictionary = index.chunks[chunk]
	var label: int = data.labels[local.y*SIDE+local.x]
	return data.base+label if label>0 else -1

func _build_chunk(grid: AStarGrid2D, index: Dictionary, chunk: Vector2i) -> void:
	var region: Rect2i = index.region
	var origin := region.position+chunk*SIDE
	var labels := PackedInt32Array()
	labels.resize(CELLS)
	for y in range(SIDE):
		for x in range(SIDE):
			var cell := origin+Vector2i(x,y)
			if not region.has_point(cell) or grid.is_point_solid(cell): labels[y*SIDE+x] = -1
	var base: int = (chunk.y*ceili(region.size.x/float(SIDE))+chunk.x)*(CELLS+1)
	var nodes: Array[int] = []
	var label := 0
	for seed in range(CELLS):
		if labels[seed]!=0: continue
		label += 1
		var queue: Array[int] = [seed]
		labels[seed] = label
		var cursor := 0
		while cursor<queue.size():
			var cell: int = queue[cursor]
			cursor += 1
			var x := cell%SIDE
			for next in [cell-1 if x>0 else -1,cell+1 if x<SIDE-1 else -1,cell-SIDE,cell+SIDE]:
				if next>=0 and next<CELLS and labels[next]==0:
					labels[next] = label
					queue.append(next)
		var node := base+label
		nodes.append(node)
		index.graph[node] = {}
	index.chunks[chunk] = {"labels":labels,"base":base,"nodes":nodes}
	chunk_builds += 1

func _link_chunk(index: Dictionary, chunk: Vector2i) -> void:
	var origin: Vector2i = index.region.position+chunk*SIDE
	for i in range(SIDE):
		for pair in [[origin+Vector2i(i,0),Vector2i.UP],[origin+Vector2i(i,SIDE-1),Vector2i.DOWN],[origin+Vector2i(0,i),Vector2i.LEFT],[origin+Vector2i(SIDE-1,i),Vector2i.RIGHT]]:
			var a := _node(index,pair[0])
			var b := _node(index,pair[0]+pair[1])
			if a<0 or b<0: continue
			index.graph[a][b] = true
			index.graph[b][a] = true

func _components(index: Dictionary) -> void:
	index.components.clear()
	var group := 0
	for seed in index.graph:
		if index.components.has(seed): continue
		group += 1
		var queue: Array = [seed]
		index.components[seed] = group
		var cursor := 0
		while cursor<queue.size():
			var node: int = queue[cursor]
			cursor += 1
			for next in index.graph[node]:
				if index.components.has(next): continue
				index.components[next] = group
				queue.append(next)
