extends SceneTree
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var fixture=game.world.fixtures.filter(func(f):return f.id=="campus-clinic")[0]
	var door=game.room_visibility.doorways.by_id("fixture:campus-clinic")
	print("DOOR ",fixture," visual ",door.visual_rect)
	var foot=Vector2(door.visual_rect.position.x+70,door.visual_rect.end.y+40)
	print("FOOT ",foot," body ",preload("res://scripts/core/actor_footprint.gd").body_at(foot))
	for solid in game.world.body_solids:
		if solid.has_point(foot):print("BODY HIT ",solid)
	for solid in game.world.solid_rects(false):
		if game.world._circle_hits_rect(foot,game.ACTOR_RADIUS,solid):print("FOOT HIT ",solid)
	print("CLEAR ",game.world.can_place_circle(foot,game.ACTOR_RADIUS,game.actors[0],false))
	quit()
