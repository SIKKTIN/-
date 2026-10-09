extends Node2D

const REPLAN_SECONDS := 0.75
const DASH := 14.0
const GAP := 10.0
var tutorial
var game
var enabled := false
var target := Vector2.ZERO
var target_key := ""
var arrival_radius := 24.0
var route := PackedVector2Array()
var planned_from := Vector2.ZERO
var planned_target := Vector2.ZERO
var planned_key := ""
var planned_revision := -1
var dirty := true
var retry := 0.0
var validation_timer := 0.0
var redraw_timer := 0.0
var flow := 0.0
var arrived := false
var plan_count := 0
var max_plan_usec := 0

func configure(owner_tutorial):
	tutorial = owner_tutorial
	game = tutorial.game
	name = "TutorialNavigation"
	# Above the ground, below people, furniture, walls and roofs.
	z_index = 13
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = ink
	hide()

func set_guidance(show_route: bool, goal: Vector2, key: String, radius: float):
	enabled = show_route
	target = goal
	arrival_radius = radius
	if key!=target_key:
		target_key = key
		request_refresh()
		visible = false
	if not enabled: hide()

func request_refresh():
	dirty = true
	retry = 0

func reset():
	enabled = false
	route.clear()
	planned_key = ""
	target_key = ""
	planned_revision = -1
	arrived = false
	request_refresh()
	hide()

func _process(delta: float):
	update_route(delta)

func update_route(delta: float):
	if not enabled or not tutorial.ui_visible():
		hide()
		return
	var actor = game.actors[game.PLAYER_ACTOR_ID]
	var start: Vector2 = actor.position
	if start.distance_to(target)<=arrival_radius and game.world.line_clear(start,target):
		arrived = true
		hide()
		return
	if arrived:
		arrived = false
		request_refresh()
	retry -= maxf(delta,0)
	validation_timer -= maxf(delta,0)
	var revision: int = game.world.obstacle_revision
	if planned_key!=target_key or planned_revision!=revision:
		request_refresh()
	if start.distance_to(planned_from)>=96 or target.distance_to(planned_target)>=24:
		dirty = true
	# Trim completed corners without searching again for every footstep.
	while not route.is_empty():
		var passed := start.distance_to(route[0])<14
		if not passed and route.size()>1:
			var nearest := Geometry2D.get_closest_point_to_segment(start,route[0],route[1])
			passed = nearest.distance_to(route[0])>1 and start.distance_to(nearest)<14
		if not passed: break
		route.remove_at(0)
	if validation_timer<=0 and not route.is_empty():
		validation_timer = 0.2
		if not game.world.motion_clear(start,route[0],actor,false):
			dirty = true
			hide()
			# Never display a line through a newly blocked first segment.
			route.clear()
	if dirty and retry<=0:
		var began := Time.get_ticks_usec()
		route = game.world.find_path(start,target,actor,false)
		max_plan_usec = maxi(max_plan_usec,Time.get_ticks_usec()-began)
		plan_count += 1
		planned_from = start
		planned_target = target
		planned_key = target_key
		planned_revision = revision
		dirty = false
		retry = REPLAN_SECONDS
		validation_timer = 0.2
		# An unreachable destination stays hidden until the world or origin changes.
	visible = not route.is_empty()
	if not visible: return
	flow = fmod(flow+maxf(delta,0)*32,360)
	redraw_timer -= maxf(delta,0)
	if redraw_timer<=0:
		redraw_timer = 0.05
		queue_redraw()

func _draw():
	if not visible or route.is_empty(): return
	var points := PackedVector2Array([game.actors[game.PLAYER_ACTOR_ID].position])
	points.append_array(route)
	var view: Rect2 = game.map_camera.world_view_rect().grow(12)
	var dashes := PackedVector2Array()
	var arrows := PackedVector2Array()
	var traveled := 0.0
	for i in range(points.size()-1):
		var segment := points[i+1]-points[i]
		var length := segment.length()
		if length<0.01: continue
		var direction := segment/length
		var end := traveled+length
		var dash_start := floorf((traveled-flow)/(DASH+GAP))*(DASH+GAP)+flow
		while dash_start<end:
			var low := maxf(maxf(traveled,dash_start),26)
			var high := minf(end,dash_start+DASH)
			if high>low:
				var a: Vector2 = points[i]+direction*(low-traveled)
				var b: Vector2 = points[i]+direction*(high-traveled)
				if Rect2(a.min(b),a.max(b)-a.min(b)).grow(4).intersects(view):
					dashes.append(a)
					dashes.append(b)
			dash_start += DASH+GAP
		var arrow_at := ceilf((maxf(38,traveled)-flow)/90)*90+flow
		while arrow_at<end:
			var point: Vector2 = points[i]+direction*(arrow_at-traveled)
			if arrow_at>=38 and view.has_point(point):
				var wing := direction.orthogonal()*4
				arrows.append_array(PackedVector2Array([point-direction*6+wing,point,point,point-direction*6-wing]))
			arrow_at += 90
		traveled = end
	if not dashes.is_empty():
		draw_multiline(dashes,Color(Color("245c59"),0.65),5,true)
		draw_multiline(dashes,Color(Color("7ac6b2"),0.95),2.5,true)
	if not arrows.is_empty(): draw_multiline(arrows,Color(Color("f2ebdd"),0.95),2,true)
	var goal: Vector2 = route[-1]
	if view.has_point(goal):
		draw_polyline(PackedVector2Array([goal+Vector2(0,-6),goal+Vector2(6,0),goal+Vector2(0,6),goal+Vector2(-6,0),goal+Vector2(0,-6)]),Color("e6c483"),2,true)
