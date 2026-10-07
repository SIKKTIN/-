extends RefCounted

# Exact slab intersection, without allocating/indexing vectors for each axis.
# Callers have already excluded rectangles outside the maximum ray radius.
static func fraction(from: Vector2, delta: Vector2, rect: Rect2) -> float:
	var near := 0.0
	var far := 1.0
	if absf(delta.x) < 0.00001:
		if from.x < rect.position.x or from.x > rect.end.x: return -1.0
	else:
		var one := (rect.position.x-from.x)/delta.x
		var two := (rect.end.x-from.x)/delta.x
		near = maxf(near,minf(one,two))
		far = minf(far,maxf(one,two))
		if near > far: return -1.0
	if absf(delta.y) < 0.00001:
		if from.y < rect.position.y or from.y > rect.end.y: return -1.0
	else:
		var one := (rect.position.y-from.y)/delta.y
		var two := (rect.end.y-from.y)/delta.y
		near = maxf(near,minf(one,two))
		far = minf(far,maxf(one,two))
		if near > far: return -1.0
	return near
