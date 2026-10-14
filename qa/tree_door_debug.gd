extends SceneTree
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	var game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var world=game.world
	var player=game.actors[0]
	for y in range(2220,2461,10):
		var a:=Vector2(4210,y)
		var b:=Vector2(4410,y)
		print("DOORPOSE ",y," from=",world.can_place_circle(a,8,player,false,false)," to=",world.can_place_circle(b,8,player,false,false)," clear=",world.motion_clear(a,b,player,false,true))
	var area:=Rect2(4190,2200,240,300)
	for r in world.static_solids:
		if r.intersects(area):print("STATIC ",r)
	for r in world.body_solids:
		if r.intersects(area):print("BODY ",r)
	quit()
