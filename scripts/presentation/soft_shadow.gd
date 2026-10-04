extends RefCounted

# Feathered projected polygon; shadows are presentation only.
static func contact_rect(canvas: CanvasItem, footprint: Rect2, height: float, clip: Rect2, settings: Dictionary = {}) -> void:
	var direction: Array = settings.get("projection_offset",[11,7.2])
	var offset := Vector2(direction[0],direction[1])*height/20.0
	var top_right := footprint.position+Vector2(footprint.size.x,0)
	var bottom_left := footprint.position+Vector2(0,footprint.size.y)
	var points := Geometry2D.convex_hull(PackedVector2Array([footprint.position,top_right,footprint.end,bottom_left,footprint.position+offset,top_right+offset,footprint.end+offset,bottom_left+offset]))
	# convex_hull repeats the first vertex; polygon APIs expect unique vertices.
	points.remove_at(points.size()-1)
	var clip_polygon := PackedVector2Array([clip.position,clip.position+Vector2(clip.size.x,0),clip.end,clip.position+Vector2(0,clip.size.y)])
	# Small layered fringes approximate a soft penumbra, preserving the footprint.
	for fringe in range(3,-1,-1):
		var expanded := Geometry2D.offset_polygon(points,float(fringe)*1.4,Geometry2D.JOIN_ROUND)
		for polygon in expanded:
			for clipped in Geometry2D.intersect_polygons(polygon,clip_polygon):
				canvas.draw_colored_polygon(clipped,Color(0.14,0.16,0.14,float(settings.get("projection_alpha",0.104))/4))
	# A narrow south-edge contact shade grounds the object without a solid black box.
	for spread in range(3,0,-1):
		var strip := Rect2(footprint.position+Vector2(-spread,footprint.size.y-1),Vector2(footprint.size.x+spread*2,spread+1)).intersection(clip)
		if strip.has_area():
			canvas.draw_rect(strip,Color(0.12,0.14,0.12,float(settings.get("contact_alpha",0.16))/5))

static func contact_actor(canvas: CanvasItem, foot: Vector2, settings: Dictionary = {}) -> void:
	var direction: Array = settings.get("projection_offset",[10,6])
	for spread in range(3,0,-1):
		canvas.draw_ellipse(foot+Vector2(direction[0],direction[1])*0.5,15+spread*2,3+spread,Color(0.14,0.16,0.14,float(settings.get("projection_alpha",0.1))/4))
	canvas.draw_ellipse(foot+Vector2(0,1),12,3,Color(0.12,0.14,0.12,float(settings.get("contact_alpha",0.16))*0.56))
