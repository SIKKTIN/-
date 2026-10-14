extends SceneTree
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("SMOOTH_TEST_VARIANT","after")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://smooth-opt-overlay.cfg")
	var game=load("res://qa/smoothness_optimization_20261014/game.gd").new()
	game.room_id="r04";root.add_child(game);await process_frame
	game.set_process(false);game.fullscreen_ui.set_process(false)
	var world=game.world
	var old=load("res://docs/dev/smoothness-optimization-2026-10-14/world_navigation-before.gd").new(world)
	var current=world.pathfinding
	var failed: Array=[];var count:=0
	for night in [false,true]:
		world.update_dorm_doors(night,[])
		world._rebuild_navigation()
		for triple in current._navigation_sets():
			for i in range(3):
				var grid: AStarGrid2D=triple[i]
				world.planning_guard_doors=i==2
				for actor in [null,game.actors[0],game.actors[1],game.guard,game.dog]:
					for avoid in [false,true]:
						for ignore_crate in [false,true]:
							for area in [world.crate.grow(world.RADIUS),Rect2(game.actors[0].position-Vector2.ONE*36,Vector2.ONE*72),Rect2(game.actors[1].position-Vector2.ONE*36,Vector2.ONE*72)]:
								var a: Array[Vector2i]=[];var b: Array[Vector2i]=[]
								old._overlay_rect(grid,area,a,actor,avoid,ignore_crate)
								for cell in a:grid.set_point_solid(cell,false)
								current._overlay_rect(grid,area,b,actor,avoid,ignore_crate)
								for cell in b:grid.set_point_solid(cell,false)
								count+=1
								if a!=b:failed.append({"case":count,"before":str(a),"after":str(b)})
	world.planning_guard_doors=false
	FileAccess.open("res://docs/dev/smoothness-optimization-2026-10-14/overlay-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":count,"failed":failed},"\t"))
	print("OVERLAY "+JSON.stringify({"checks":count,"failed":failed.size()}))
	game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
