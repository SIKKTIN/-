extends SceneTree
var results: Array=[]
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://smooth-opt-search.cfg")
	var game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04";root.add_child(game);await process_frame
	game.set_process(false);game.fullscreen_ui.set_process(false)
	game.actors[0].immune_until=INF
	var paths: Array=JSON.parse_string(FileAccess.get_file_as_string("res://docs/dev/smoothness-optimization-2026-10-14/route-cases.json"))
	var world=game.world
	for minute in [480,720,1200,1440]:
		game.schedule.clock_elapsed=(float(minute)-480.0)/1440.0*game.schedule.day_seconds
		game.schedule.tick(false);game._process(1.0/60)
		world._rebuild_navigation()
		for triple in world.pathfinding._navigation_sets():
			for grid in triple:
				world.pathfinding.connectivity.warm(grid)
				for path in paths:
					var from: Vector2i=world.pathfinding._nearest_nav_point(Vector2(path.from[0],path.from[1]),null,false,false,grid)
					var to: Vector2i=world.pathfinding._nearest_nav_point(Vector2(path.to[0],path.to[1]),null,false,false,grid)
					if from.x<0 or to.x<0 or not world.pathfinding.connectivity.connected(grid,from,to):continue
					var times: Dictionary={"jps":[],"astar":[]};var lengths: Dictionary={};var costs: Dictionary={}
					for repeat in range(5):
						for jumping in [true,false] if repeat%2==0 else [false,true]:
							grid.jumping_enabled=jumping
							var mark:=Time.get_ticks_usec()
							var route: PackedVector2Array=grid.get_point_path(from,to)
							var key: String="jps" if jumping else "astar"
							times[key].append((Time.get_ticks_usec()-mark)/1000.0)
							lengths[key]=route.size()
							var distance:=0.0
							for i in range(1,route.size()):distance+=route[i-1].distance_to(route[i])
							costs[key]=distance
					grid.jumping_enabled=true
					results.append({"minute":minute,"from":str(from),"to":str(to),"times":times,"lengths":lengths,"costs":costs})
	FileAccess.open("res://docs/dev/smoothness-optimization-2026-10-14/search-benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("SEARCH_BENCHMARK_DONE "+str(results.size()))
	game.queue_free();await process_frame;quit()
