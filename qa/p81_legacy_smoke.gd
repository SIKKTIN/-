extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_process(false)
 var checks := {}
 for room in ["r01","r02","r03"]:
  game.load_room(room,["lockpick","chat","backpack"],81)
  game.routine_panel.close()
  var layer=game.room_visibility.doorways
  checks[room+"_door_registered"]=layer.by_id("primary")!=null and layer.by_id("primary").style=="locked"
  game.world.open_door()
  game.room_visibility.tick(0.3)
  checks[room+"_open_state_synced"]=not layer.by_id("primary").closed
 var failed: Array=checks.keys().filter(func(k):return not checks[k])
 FileAccess.open("res://docs/tests/p81-legacy-smoke.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"total":checks.size()},"\t"))
 print(JSON.stringify({"checks":checks,"failed":failed}))
 quit(0 if failed.is_empty() else 1)
