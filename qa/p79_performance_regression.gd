extends SceneTree
var game
var checks: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(label: String, ok: bool) -> void:
	checks[label]=ok
	print(label+": "+str(ok))
func reference_motion(a: Vector2,b: Vector2) -> bool:
	if not game.world.inside_room(a) or not game.world.inside_room(b):return false
	for rect in game.world.solid_rects():
		if game.world._segment_hits_rect(a,b,rect):return false
	return true
func reference_sight(a: Vector2,b: Vector2,inflate: float) -> bool:
	for rect in game.world.sight_rects():
		if game.world.ray_rect_fraction(a,b,rect.grow(inflate))>=0:return false
	return true
func nav_state() -> Array:
	var state: Array=[]
	for grid in [game.world.grid,game.world.guard_grid,game.world.inspection_grid]:
		var cells:=PackedByteArray()
		for y in range(grid.region.position.y,grid.region.end.y):
			for x in range(grid.region.position.x,grid.region.end.x):cells.append(int(grid.is_point_solid(Vector2i(x,y))))
		state.append(cells)
	return state
func run() -> void:
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p79-test-frame-settings.cfg")
	OS.set_environment("ESCAPE_FRAME_MODE","60")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.load_room("r04",["lockpick","chat","backpack"],79)
	game.routine_panel.close()
	check("default60",game.frame_settings.target_fps==60 and Engine.max_fps==60)
	var clock_speed: float=game.schedule.time_speed
	var physics_rate: int=Engine.physics_ticks_per_second
	game.fullscreen_ui.toggle_menu()
	var picker: OptionButton=game.fullscreen_ui.frame_mode
	picker.select(1)
	picker.item_selected.emit(1)
	check("menu90whilepaused",game.get_tree().paused and Engine.max_fps==90)
	var settings=load("res://scripts/core/frame_settings.gd").new()
	OS.set_environment("ESCAPE_FRAME_MODE","")
	settings.configure()
	check("persist90",settings.target_fps==90)
	check("rejectinvalidcap",not settings.apply(75,false) and Engine.max_fps==90)
	check("clockphysicsunchanged",clock_speed==game.schedule.time_speed and physics_rate==Engine.physics_ticks_per_second)
	game.fullscreen_ui.close_menu()
	check("menuunpauses",not paused)
	for size in [Vector2i(1200,720),Vector2i(960,540)]:
		root.size=size
		root.content_scale_size=size
		game.fullscreen_ui.layout()
		check("menu_fits_"+str(size.x),Rect2(Vector2.ZERO,Vector2(size)).encloses(game.fullscreen_ui.menu.get_global_rect()))
	var rng:=RandomNumberGenerator.new()
	rng.seed=7901
	var motion_mismatch:=0
	var sight_mismatch:=0
	for step in range(1600):
		var a:=Vector2(rng.randf_range(30,4200),rng.randf_range(30,3000))
		var b:=a+Vector2(rng.randf_range(-160,160),rng.randf_range(-160,160)) if step%2==0 else Vector2(rng.randf_range(30,4200),rng.randf_range(30,3000))
		if game.world.motion_clear(a,b)!=reference_motion(a,b):motion_mismatch+=1
		var inflate:=float(step%3)*5
		if game.world.line_clear(a,b,inflate)!=reference_sight(a,b,inflate):sight_mismatch+=1
	check("1600_exact_swept_collision",motion_mismatch==0)
	check("1600_exact_sight_lines",sight_mismatch==0)
	game.world._rebuild_navigation()
	for gate_id in ["cafeteria-entry","workshop-entry",str(game.world.access_doors.back().id)]:
		var gate: Dictionary=game.world.access_by_id(gate_id)
		game.world.set_access_closed(gate_id,not bool(gate.closed))
		game.world._rebuild_navigation()
		var incremental:=nav_state()
		game.world.navigation_layout.clear()
		game.world._rebuild_navigation()
		check("incremental_nav_exact_"+gate_id,incremental==nav_state())
	game.world.update_dorm_doors(true,[])
	game.world._rebuild_navigation()
	var dorm_incremental:=nav_state()
	game.world.navigation_layout.clear()
	game.world._rebuild_navigation()
	check("dorm_nav_exact",dorm_incremental==nav_state())
	var jump_mismatches:=0
	var path_collisions:=0
	for step in range(140):
		var grid=game.world.inspection_grid
		var a:=Vector2i(rng.randi_range(1,200),rng.randi_range(1,140))
		var b:=Vector2i(rng.randi_range(1,200),rng.randi_range(1,140))
		if grid.is_point_solid(a) or grid.is_point_solid(b):continue
		grid.jumping_enabled=false
		var old_path: PackedVector2Array=grid.get_point_path(a,b)
		grid.jumping_enabled=true
		var new_path: PackedVector2Array=grid.get_point_path(a,b)
		if old_path.is_empty()!=new_path.is_empty():jump_mismatches+=1
		var start: Vector2=grid.get_point_position(a)
		var goal: Vector2=grid.get_point_position(b)
		var path: PackedVector2Array=game.world.find_path(start,goal,game.guard,false)
		for point in path:
			game.world.planning_guard_doors=true
			if not game.world.motion_clear(start,point,game.guard):path_collisions+=1
			game.world.planning_guard_doors=false
			start=point
	check("jump_search_reachability",jump_mismatches==0)
	check("smoothed_paths_keep_exact_collision",path_collisions==0)
	game.schedule.clock_elapsed=(600.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.workshop.update_gate()
	game.world.begin_ai_paths()
	game.world.ai_path_spent_usec=1000
	game.guard.path.clear()
	game.world.find_path(Vector2(750,1300),Vector2(934,508),game.guard,false)
	check("expensive_route_defers_with_budget",game.guard.path_deferred)
	game.world.end_ai_paths()
	game.world.find_path(Vector2(750,1300),Vector2(934,508),game.guard,false)
	check("route_retries_without_budget",not game.guard.path_deferred)
	game.world.begin_ai_paths()
	game.world.ai_path_spent_usec=1000
	var dog_route: PackedVector2Array=game.world.find_path(Vector2(750,1300),Vector2(750,1330),game.dog,false)
	game.world.end_ai_paths()
	check("dog_keeps_own_navigation_contract",not dog_route.is_empty())
	game.actors[0].position=Vector2(1450,1300)
	game.actors[0].immune_until=0
	game.routines.take_control(0)
	game.workshop.grace[0]=0
	game.guard.position=Vector2(1580,1300)
	game.guard.release_target()
	game.world.begin_ai_paths()
	game.world.ai_path_spent_usec=1000
	game.guard.tick(0.01)
	game.world.end_ai_paths()
	check("budget_keeps_immediate_detection",game.guard.state=="chasing" and game.guard.target_id==0)
	for officer in game.gate_watch.guards:
		game.staff_traffic.records[officer.get_instance_id()].status="duty"
		officer.position=Vector2(1580,1300)
		officer.release_target()
		officer.tick(0.01)
		check("labor_capture_"+str(officer.guard_id),officer.state=="chasing")
	game.capture_actor(0)
	check("capture_enters_real_confinement",game.actors[0].confined and game.confinement_counts[0]==1)
	for count in range(2):
		game.room_access.release(0)
		game.actors[0].immune_until=0
		game.capture_actor(0)
	check("third_capture_still_fails",game.phase=="failed" and game.confinement_counts[0]==3)
	var report: Dictionary={"checks":checks,"failed":checks.keys().filter(func(k):return not checks[k]),"motion_mismatches":motion_mismatch,"sight_mismatches":sight_mismatch}
	FileAccess.open("res://docs/tests/p79-regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://p79-test-frame-settings.cfg"))
	print(JSON.stringify(report))
	quit(0 if report.failed.is_empty() else 1)
