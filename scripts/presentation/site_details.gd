@tool
extends RefCounted

# Shared editor/runtime floor paint. All coordinates are authored in world space.
# These marks are scenery, never collision or navigation geometry.
static func paint(painter: CanvasItem, specs: Array, offset := Vector2.ZERO, scale_factor := 1.0, clip := Rect2()) -> void:
	for spec in specs:
		if clip.has_area() and not visible_in(spec,clip): continue
		var color := Color(spec.get("color","#b4a36c"))
		color.a = float(spec.get("opacity",0.65))
		var kind: String = str(spec.get("kind","line"))
		if kind == "surface":
			var r: Array = spec.rect
			painter.draw_rect(Rect2(offset+Vector2(r[0],r[1])*scale_factor,Vector2(r[2],r[3])*scale_factor),color)
		elif kind == "label":
			var p: Array = spec.position
			var font: Font = load("res://art/fonts/NotoSansCJKsc-Regular.otf")
			painter.draw_string(font,offset+Vector2(p[0],p[1])*scale_factor,str(spec.text),HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(8,roundi(float(spec.get("size",24))*scale_factor)),color)
		elif kind in ["line","dash"]:
			var a: Array = spec.from
			var b: Array = spec.to
			var start := Vector2(a[0],a[1])
			var end := Vector2(b[0],b[1])
			var length := start.distance_to(end)
			if length < 1: continue
			var direction := (end-start)/length
			var segment := float(spec.get("segment",40)) if kind=="dash" else length
			var gap := float(spec.get("gap",30)) if kind=="dash" else 0.0
			var cursor := 0.0
			while cursor < length:
				var finish := minf(length,cursor+segment)
				# Fine gaps and uneven opacity make the industrial paint look worn.
				var stride := 17.0
				var local := cursor
				while local < finish:
					var paint_end := minf(finish,local+stride-0.8)
					var tint := color
					tint.a *= 0.72+0.25*absf(sin(local*0.127+start.x))
					painter.draw_line(offset+(start+direction*local)*scale_factor,offset+(start+direction*paint_end)*scale_factor,tint,maxf(1,float(spec.get("width",5))*scale_factor),true)
					local += stride
				cursor += segment+gap
		elif kind == "hatch":
			var r: Array = spec.rect
			var area := Rect2(r[0],r[1],r[2],r[3])
			var horizontal := area.size.x >= area.size.y
			var length := area.size.x if horizontal else area.size.y
			var thickness := area.size.y if horizontal else area.size.x
			painter.draw_rect(Rect2(offset+area.position*scale_factor,area.size*scale_factor),Color(0.2,0.23,0.21,0.25))
			for value in range(0,int(length),24):
				var a := area.position+Vector2(value,thickness) if horizontal else area.position+Vector2(0,value)
				var b := area.position+Vector2(minf(value+thickness,length),0) if horizontal else area.position+Vector2(thickness,minf(value+thickness,length))
				painter.draw_line(offset+a*scale_factor,offset+b*scale_factor,color,maxf(1,7*scale_factor),true)
		elif kind == "drain":
			var r: Array = spec.rect
			var area := Rect2(r[0],r[1],r[2],r[3])
			painter.draw_rect(Rect2(offset+area.position*scale_factor,area.size*scale_factor),Color("#414945"))
			painter.draw_rect(Rect2(offset+area.position*scale_factor,area.size*scale_factor),Color("#899185"),false,maxf(1,2*scale_factor))
			for x in range(int(area.position.x)+5,int(area.end.x)-2,8):
				painter.draw_line(offset+Vector2(x,area.position.y+3)*scale_factor,offset+Vector2(x,area.end.y-3)*scale_factor,Color("#242c2a"),maxf(1,3*scale_factor),true)

static func visible_in(spec: Dictionary, clip: Rect2) -> bool:
	if spec.has("rect"):
		var r: Array = spec.rect
		return Rect2(r[0],r[1],r[2],r[3]).grow(8).intersects(clip)
	if spec.has("position"):
		var p: Array = spec.position
		var height := float(spec.get("size",24))
		return Rect2(Vector2(p[0],p[1]-height),Vector2(str(spec.get("text","")).length()*height,height*1.5)).grow(8).intersects(clip)
	if spec.has("from") and spec.has("to"):
		var a: Array = spec.from
		var b: Array = spec.to
		var box := Rect2(Vector2(a[0],a[1]),Vector2.ZERO).expand(Vector2(b[0],b[1]))
		return box.grow(maxf(2,float(spec.get("width",5)))).intersects(clip)
	return true

static func hit_bounds(spec: Dictionary) -> Rect2:
	if spec.has("rect"):
		var r: Array = spec.rect
		return Rect2(r[0],r[1],r[2],r[3])
	if spec.has("position"):
		var p: Array = spec.position
		var height := float(spec.get("size",24))
		return Rect2(Vector2(p[0],p[1]-height),Vector2(maxi(1,str(spec.get("text","")).length())*height,height*1.5))
	if spec.has("from") and spec.has("to"):
		return Rect2(Vector2(spec.from[0],spec.from[1]),Vector2.ZERO).expand(Vector2(spec.to[0],spec.to[1])).grow(maxf(2,float(spec.get("width",5))/2))
	return Rect2()

static func hit_test(spec: Dictionary, point: Vector2, tolerance: float) -> bool:
	if spec.has("from") and spec.has("to"):
		var a := Vector2(spec.from[0],spec.from[1])
		var b := Vector2(spec.to[0],spec.to[1])
		return point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b)) <= float(spec.get("width",5))/2+tolerance
	return hit_bounds(spec).grow(tolerance).has_point(point)
