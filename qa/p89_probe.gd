extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.routine_panel.close()
 game.schedule.set_time_speed(0)
 for door in game.room_visibility.doorways.doors:print(door.id,": ",door.visual_rect)
 print("BODY_SOLIDS ",game.world.body_solids.size())
 quit()
