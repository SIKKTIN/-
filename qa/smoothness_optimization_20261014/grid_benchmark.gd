extends SceneTree
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("SMOOTH_TEST_VARIANT","after")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://smooth-opt-grid.cfg")
	var game=load("res://qa/smoothness_optimization_20261014/game.gd").new()
	game.room_id="r04";root.add_child(game);await process_frame
	game.set_process(false);game.fullscreen_ui.set_process(false)
	var world=game.world
	for actor in game.actors:actor.position=Vector2(750,3200)
	var report: Dictionary={"timings":{},"checks":{},"algorithm":{}}
	var ids: Array=["cafeteria-entry","cafeteria-entry-east","cafeteria-south","energy-entry","workshop-entry"]
	for mode in ["before","after"]:
		world.pathfinding=load("res://qa/smoothness_optimization_20261014/navigation_"+mode+".gd").new(world)
		var index_class=load("res://docs/dev/smoothness-optimization-2026-10-14/solid_spatial_index-before.gd" if mode=="before" else "res://scripts/core/solid_spatial_index.gd")
		world.solid_index=index_class.new();world.body_index=index_class.new();world.inspection_body_index=index_class.new()
		world.inspection_index=index_class.new();world.sight_index=index_class.new()
		for id in ids:world.set_access_closed(id,false,true)
		world.update_dorm_doors(false,[])
		world.navigation_layout=[];world._rebuild_navigation()
		report.algorithm[mode]={"jps":world.grid.jumping_enabled,"solids":world.static_solids.size()}
		var times: Array=[]
		for repeat in range(8):
			for id in ids:
				world.set_access_closed(id,repeat%2==0,true)
				var mark:=Time.get_ticks_usec()
				world._rebuild_navigation()
				times.append((Time.get_ticks_usec()-mark)/1000.0)
			report.checks[mode+"_inspection_separate_"+str(repeat)]=world.inspection_body_index.rects==world.inspection_body_solids
		report.timings[mode]=times
	var incremental:=snapshot(world)
	world.navigation_layout=[];world._rebuild_navigation()
	var full:=snapshot(world)
	for i in range(full.size()):report.checks["incremental_equals_full_"+str(i)]=incremental[i]==full[i]
	report.failed=report.checks.keys().filter(func(k):return not report.checks[k])
	FileAccess.open("res://docs/dev/smoothness-optimization-2026-10-14/grid-benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GRID_BENCHMARK_DONE "+JSON.stringify({"checks":report.checks.size(),"failed":report.failed,"algorithm":report.algorithm}))
	game.queue_free();await process_frame;quit(0 if report.failed.is_empty() else 1)
func snapshot(world) -> Array:
	var result: Array=[]
	for triple in world.pathfinding._navigation_sets():
		for grid in triple:
			var mask:=PackedByteArray();mask.resize(grid.region.size.x*grid.region.size.y)
			var i:=0
			for y in range(grid.region.position.y,grid.region.end.y):
				for x in range(grid.region.position.x,grid.region.end.x):
					mask[i]=int(grid.is_point_solid(Vector2i(x,y)));i+=1
			result.append(mask)
	return result
