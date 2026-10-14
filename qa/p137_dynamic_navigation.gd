extends SceneTree
var checks: Dictionary={}
func _initialize() -> void:call_deferred("run")
func snapshot(world) -> Array:
	var result: Array=[]
	for triple in world.pathfinding._navigation_sets():
		for grid in triple:
			var mask:=PackedByteArray()
			mask.resize(grid.region.size.x*grid.region.size.y)
			var i:=0
			for y in range(grid.region.position.y,grid.region.end.y):
				for x in range(grid.region.position.x,grid.region.end.x):
					mask[i]=int(grid.is_point_solid(Vector2i(x,y)))
					i+=1
			result.append(mask)
	return result
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p137-qa.cfg")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.load_room("r04",["chat","chat","backpack"],137)
	var world=game.world
	var fixed: Array[Rect2]=world.wall_collision_rects()
	var copy: Array[Rect2]=world.wall_collision_rects()
	copy.append(Rect2(-900,-900,5,5))
	checks["caller_cannot_mutate_fixed_geometry"]=world.wall_collision_rects()==fixed
	for n in range(3):
		world.set_access_closed("workshop-entry",n%2==0,true)
		world.update_dorm_doors(n==1,[])
		world.pathfinding._rebuild_navigation()
		var incremental:=snapshot(world)
		world.navigation_layout=[]
		world.pathfinding._rebuild_navigation()
		var rebuilt:=snapshot(world)
		for i in range(rebuilt.size()):
			checks["incremental_matches_full_%d_grid_%d" % [n,i]]=incremental[i]==rebuilt[i]
			if incremental[i]!=rebuilt[i]:
				var differences: Array=[]
				for c in range(rebuilt[i].size()):
					if incremental[i][c]!=rebuilt[i][c]:
						var grid=world.pathfinding._navigation_sets()[i/3][i%3]
						var point: Vector2=grid.get_point_position(grid.region.position+Vector2i(c%grid.region.size.x,c/grid.region.size.x))
						if differences.size()<5:differences.append({"point":str(point),"incremental":incremental[i][c],"full":rebuilt[i][c],"inspection_bodies":world.inspection_body_solids.filter(func(r):return r.has_point(point)).map(func(r):return str(r)),"inspection_solids":world.inspection_solids.filter(func(r):return world._circle_hits_rect(point,world.RADIUS,r)).map(func(r):return str(r))})
				print("NAV_DIFFERENCES "+JSON.stringify(differences))
		checks["fixed_walls_unchanged_after_gate_%d" % n]=world.wall_collision_rects()==fixed
	var config: Dictionary=game.room_config.duplicate(true)
	config.walls.append([20,20,20,20])
	world.configure(config,game.actors)
	checks["map_reload_invalidates_fixed_geometry"]=world.wall_collision_rects().has(Rect2(20,20,20,20))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open("res://docs/dev/p137/dynamic-navigation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks,"failed":failed}))
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
