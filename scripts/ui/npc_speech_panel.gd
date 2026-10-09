extends Panel

var tail := PackedVector2Array()

func point_to(mouth: Vector2) -> void:
	var point := mouth-position
	var next := PackedVector2Array()
	if not Rect2(Vector2.ZERO,size).has_point(point):
		var edge := Vector2(clampf(point.x,24,size.x-24),size.y-1)
		var side := Vector2(8,0)
		if point.y<0:
			edge.y = 1
		elif point.x<0 or point.x>size.x:
			edge = Vector2(1 if point.x<0 else size.x-1,clampf(point.y,20,size.y-20))
			side = Vector2(0,8)
		next = PackedVector2Array([edge-side,edge+side,point])
	if next!=tail:
		tail = next
		queue_redraw()

func _draw() -> void:
	if tail.size()==3:
		draw_colored_polygon(tail,Color("f2ebdd"))
		draw_line(tail[0],tail[2],Color("68796c"),1,true)
		draw_line(tail[2],tail[1],Color("68796c"),1,true)
	draw_circle(Vector2(17,22),4,Color("c49c5f"),true,-1,true)
	draw_line(Vector2(14,34),Vector2(154,34),Color("b8b8a7"),1,true)
