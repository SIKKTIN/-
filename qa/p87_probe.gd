extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.load_room("r04",["lockpick","chat","backpack"],87)
 game.routine_panel.close()
 game.world.set_access_closed("workshop-entry",true)
 var world=game.world
 var room=game.room_visibility.rooms.filter(func(r):return r.id=="workshop")[0]
 var area: Rect2=room.roof_plan.roof
 print("ROOM ",room.area," ROOF ",area," CLOSED ",world._closed_perimeter(area)," COUNT ",world.solid_rects(false).size())
 print("PORTS ",room.roof_plan.ports)
 for edge in [0,1,2,3]:
  var vertical: bool=edge<2
  var line: float=area.position.x if edge==0 else area.end.x if edge==1 else area.position.y if edge==2 else area.end.y
  var low: float=area.position.y if vertical else area.position.x
  var high: float=area.end.y if vertical else area.end.x
  var spans: Array=[]
  for rect in world.solid_rects(false):
   var near: float=rect.position.x if vertical else rect.position.y
   var far: float=rect.end.x if vertical else rect.end.y
   if near>line or far<line:continue
   var start: float=rect.position.y if vertical else rect.position.x
   var end: float=rect.end.y if vertical else rect.end.x
   if end>=low and start<=high:spans.append(Vector2(maxf(low,start),minf(high,end)))
  spans.sort_custom(func(a,b):return a.x<b.x)
  var cursor: float=low
  var gaps: Array=[]
  for span in spans:
   if span.x>cursor+0.001:gaps.append([cursor,span.x])
   cursor=maxf(cursor,span.y)
  if cursor<high:gaps.append([cursor,high])
  print("EDGE ",edge," LINE ",line," GAPS ",gaps)
 quit()
