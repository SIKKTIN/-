extends Node2D

var game
var escaped := false
var facing := Vector2.RIGHT
var moved_this_frame := false
var walk_clock := 0.0
var walk_elapsed := 0.0
var timetable: Array = []
var entry: Dictionary = {}
var goal := Vector2.ZERO
var path := PackedVector2Array()
var path_timer := 0.0
var path_revision := -1
var stalled_time := 0.0
var route_status := ""

func configure(owner_game, spec: Dictionary) -> void:
	game = owner_game
	position = Vector2(spec.position[0],spec.position[1])
	timetable = spec.get("routine",[]).duplicate(true)
	update_schedule()

func update_schedule() -> void:
	var minute: float = game.schedule.clock_minutes() if game.schedule else 480.0
	var next: Dictionary = {}
	for activity in timetable:
		if minute >= float(activity.minute):
			next = activity
	if next.is_empty() or entry == next:
		return
	entry = next
	goal = Vector2(entry.position[0],entry.position[1])
	path.clear()
	path_timer = 0.0
	stalled_time = 0.0

func at_destination() -> bool:
	return position.distance_to(goal) <= 8.0

func is_open() -> bool:
	update_schedule()
	return game.phase == "playing" and game.schedule != null and not game.schedule.is_curfew() and str(entry.get("kind","rest")) == "shop" and at_destination()

func activity_text() -> String:
	if is_open():
		return "营业中"
	if not at_destination():
		return "前往摊位" if entry.get("kind","") in ["shop","commute"] else "前往休息" if entry.get("kind","") == "rest" else "前往车间"
	return {"work":"车间工作","rest":"休息中","commute":"待营业","shop":"未营业"}.get(str(entry.get("kind","rest")),"休息中")

func tick(delta: float) -> void:
	moved_this_frame = false
	if game.phase != "playing" or game.get_tree().paused:
		return
	update_schedule()
	if at_destination() or game.schedule.time_speed <= 0:
		walk_clock = 0.0
		walk_elapsed = 0.0
		return
	# Routine movement follows the game clock, keeping commute duration stable
	# when the developer changes time speed. Player commands retain their speed.
	var step_time: float = maxf(delta,0)*game.schedule.time_speed
	path_timer -= step_time
	var invalid: bool = path_revision != game.world.obstacle_revision and not path.is_empty() and not game.world.motion_clear(position,path[0],self)
	if path_timer <= 0 and (path.is_empty() or invalid or stalled_time >= 0.4):
		path = game.world.find_path(position,goal,self,true)
		path_revision = game.world.obstacle_revision
		path_timer = 0.5
		route_status = "路线受阻" if path.is_empty() else ""
	while not path.is_empty() and position.distance_to(path[0]) <= 4:
		path.remove_at(0)
	if not path.is_empty():
		var offset: Vector2 = path[0]-position
		facing = offset.normalized()
		moved_this_frame = game.world.move_actor(self,facing*minf(95*step_time,offset.length())).length_squared() > 0.001
	stalled_time = 0.0 if moved_this_frame else stalled_time+step_time
	walk_clock = fposmod(walk_clock+maxf(delta,0)*TAU/0.5,TAU) if moved_this_frame else 0.0
	walk_elapsed = fposmod(walk_elapsed+maxf(delta,0),1000.0) if moved_this_frame else 0.0

func snapshot() -> Dictionary:
	return {"position":[position.x,position.y],"facing":[facing.x,facing.y],"moving":moved_this_frame,"walk_clock":walk_clock,"activity":activity_text(),"open":is_open(),"goal":[goal.x,goal.y],"path_size":path.size(),"route_status":route_status}
