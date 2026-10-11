extends SceneTree
var game
func _initialize():call_deferred("run")
func run():
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.load_room("r04",["lockpick","chat","backpack"],83)
 game.routine_panel.close()
 game.schedule.set_time_speed(0)
 game.world.admission_filter=Callable()
 for g in game.world.access_doors: game.world.set_access_closed(g.id,false)
 game.world.update_dorm_doors(false,[])
 print("CAPS ",game.world.boundary_solids.size())
 for id in ["dorm-0","dorm-1","dorm-2","solitary-0","solitary-1","solitary-2"]:
  var d=game.room_visibility.doorways.by_id(id)
  var a=d.visual_rect.get_center()+Vector2(50,0)
  var b=d.visual_rect.get_center()-Vector2(170,35)
  print(id," ",a," ",b," destination=",game.world.can_place_circle(b,17,null,false)," path=",game.world.find_path(a,b,null,false,true))
 for pt in [Vector2(2100,1845),Vector2(2100,1860),Vector2(2100,1945),Vector2(500,400),Vector2(1400,1260)]:
  print("POINT ",pt," clear=",game.world.can_place_circle(pt,17,null,false)," blockers=",game.world.solid_rects(false).filter(func(r):return game.world._circle_hits_rect(pt,17,r)))

 quit()
