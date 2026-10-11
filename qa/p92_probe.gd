extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_process(false)
 var g=game.guard
 var t=game.tutorial
 print("PROBE ",g.position," rendezvous=",t.rendezvous," zone=",g.allowed_zone()," guardcan=",game.world.can_place_circle(g.position,8,g)," goalcan=",game.world.can_place_circle(t.rendezvous,8,g)," doors=",game.world.dorm_doors)
 for point in [t.rendezvous,t._target("dorm_gate"),game.schedule.inspection_point(0),Vector2(660,410),Vector2(700,400)]:
  print("PATH ",point," = ",game.world.find_path(g.position,point,g,true))
 for i in range(15):
  game._process(0.05)
  print("TICK ",g.position," path=",g.path," deferred=",g.path_deferred," body=",game.world.body_solids.size())
 quit()
