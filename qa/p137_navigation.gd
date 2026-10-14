extends SceneTree
var checks: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(id: String, passed: bool) -> void:checks[id]=passed
func run() -> void:
	var grid:=AStarGrid2D.new()
	grid.region=Rect2i(-4,-3,64,64)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(-3,61):grid.set_point_solid(Vector2i(28,y),true)
	var index=preload("res://scripts/world/navigation_connectivity.gd").new()
	index.warm(grid)
	check("closed_partition_rejected",not index.connected(grid,Vector2i(8,8),Vector2i(44,44)))
	check("same_region_connected",index.connected(grid,Vector2i(0,0),Vector2i(27,55)))
	var builds: int=index.chunk_builds
	grid.set_point_solid(Vector2i(28,18),false)
	index.touch(grid,Vector2i(28,18))
	check("dirty_index_does_not_reject",index.connected(grid,Vector2i(8,8),Vector2i(44,44)))
	index.warm(grid)
	check("opening_gate_connects_regions",index.connected(grid,Vector2i(8,8),Vector2i(44,44)))
	check("only_one_chunk_rebuilt",index.chunk_builds==builds+1)
	grid.set_point_solid(Vector2i(28,18),true)
	index.touch(grid,Vector2i(28,18))
	index.warm(grid)
	check("closing_gate_disconnects_regions",not index.connected(grid,Vector2i(8,8),Vector2i(44,44)))
	var rng:=RandomNumberGenerator.new()
	rng.seed=137
	for n in range(400):
		var cell:=Vector2i(rng.randi_range(-4,59),rng.randi_range(-3,60))
		grid.set_point_solid(cell,true)
		index.touch(grid,cell)
	index.warm(grid)
	var matches:=true
	for n in range(250):
		var a:=Vector2i(rng.randi_range(-4,59),rng.randi_range(-3,60))
		var b:=Vector2i(rng.randi_range(-4,59),rng.randi_range(-3,60))
		if grid.is_point_solid(a) or grid.is_point_solid(b):continue
		if index.connected(grid,a,b)!=not grid.get_id_path(a,b).is_empty():matches=false
	check("components_match_native_astar_at_250_pairs",matches)
	var game=load("res://scenes/main.tscn").instantiate()
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p137-qa.cfg")
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.load_room("r04",["chat","chat","backpack"],137)
	game.schedule.clock_elapsed=(840.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.set_time_speed(0)
	game._process(0.001)
	var officer=game.workshop.overseer
	officer.position=Vector2(1501.775,2316.954)
	var measurements: Array=[]
	var rejected: int=game.world.pathfinding.connectivity.rejections
	for n in range(20):
		game.world.begin_ai_paths()
		var start:=Time.get_ticks_usec()
		var path=game.world.find_path(officer.position,Vector2(1140.51,1913.58),officer,false)
		measurements.append((Time.get_ticks_usec()-start)/1000.0)
		check("known_failed_route_stays_empty_%d" % n,path.is_empty())
		game.world.end_ai_paths()
	check("known_failed_route_rejected_before_astar",game.world.pathfinding.connectivity.rejections>=rejected+40)
	check("known_failed_route_max_under_3ms",measurements.max()<3.0)
	var failed: Array=checks.keys().filter(func(key):return not checks[key])
	FileAccess.open("res://docs/dev/p137/navigation-check.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"failed_route_ms":measurements},"\t"))
	print(JSON.stringify({"failed":failed,"failed_route_ms":measurements}))
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
