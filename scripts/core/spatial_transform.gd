@tool
extends RefCounted

# Shared exact quarter-turn geometry for authoring and retained painters.
# Quarter turns use exact arithmetic, so four rotations return to the same grid.
static func point(p: Vector2, pivot: Vector2, turns: int, offset := Vector2.ZERO) -> Vector2:
	var v := p-pivot
	match posmod(turns,4):
		1: v = Vector2(-v.y,v.x)
		2: v = -v
		3: v = Vector2(v.y,-v.x)
	return pivot+v+offset

static func rectangle(r: Rect2, pivot: Vector2, turns: int, offset := Vector2.ZERO) -> Rect2:
	var dimensions := Vector2(r.size.y,r.size.x) if posmod(turns,2) else r.size
	return Rect2(point(r.get_center(),pivot,turns,offset)-dimensions/2,dimensions)

static func coords(values: Array, pivot: Vector2, turns: int, offset: Vector2) -> Array:
	# JSON stores doubles. Avoid converting calibrated fractional prop sizes to
	# float32 Vector2s while editing; retained painters can convert on rendering.
	var w: float = float(values[2]) if values.size()==4 else 0.0
	var h: float = float(values[3]) if values.size()==4 else 0.0
	var x: float = float(values[0])+w/2-pivot.x
	var y: float = float(values[1])+h/2-pivot.y
	var px := x
	var py := y
	match posmod(turns,4):
		1: px = -y; py = x
		2: px = -x; py = -y
		3: px = y; py = -x
	if posmod(turns,2):
		var saved := w
		w = h
		h = saved
	var result: Array = [pivot.x+px+offset.x-w/2,pivot.y+py+offset.y-h/2]
	if turns!=0:
		for index in range(2):
			if absf(float(result[index])-roundf(float(result[index])))<0.000000001: result[index] = roundf(float(result[index]))
	if values.size()==4: result.append_array([w,h])
	return result

