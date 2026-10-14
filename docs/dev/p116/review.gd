extends "res://qa/p101_npc_responses.gd"

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p116-props-review.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	var stage:=OS.get_environment("ESCAPE_PROP_REVIEW_STAGE")
	if stage.is_empty():stage="after"
	var folder: String="res://docs/dev/p116/"+stage
	DirAccess.make_dir_recursive_absolute(folder)
	var points: Dictionary={"dorm":Vector2(430,1500),"workshop":game.routines._target(0,"work"),"cafeteria":Vector2(1350,2910),"laundry":Vector2(1340,3450),"clinic":Vector2(1600,610),"duty":Vector2(4110,550),"office":Vector2(4480,800),"warehouse":Vector2(4700,2800)}
	for id in points:
		game.actors[0].position=points[id]
		if not game.world.can_place_circle(points[id],8,game.actors[0],false,false):
			var found:=false
			for radius in [20,40,60,80,100]:
				if found:break
				for offset in [Vector2(0,1),Vector2(-1,0),Vector2(1,0),Vector2(0,-1)]:
					var candidate: Vector2=points[id]+offset*radius
					if game.world.can_place_circle(candidate,8,game.actors[0],false,false):
						game.actors[0].position=candidate
						found=true
						break
		game.guard.position=points[id]+Vector2(180,50)
		game.room_visibility.tick(1,true)
		game.map_camera.center_on(points[id])
		game.presentation.tick(0)
		game._update_ui()
		await frame()
		await frame()
		root.get_texture().get_image().save_png(folder+"/"+id+".png")
	print("Captured prop proportions: ",stage)
	quit()
