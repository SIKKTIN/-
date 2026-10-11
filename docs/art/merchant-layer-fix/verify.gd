extends SceneTree
const OUT := "res://docs/art/merchant-layer-fix/"
var checks := {}
var game
func _initialize() -> void:call_deferred("run")
func check(label: String,value: bool) -> void:
	checks[label]=value
	if not value:print("FAIL: ",label)
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func locate(actor,point: Vector2) -> void:
	actor.position=point
	game.trade.merchants[game.trade.actors.keys()[0]].position=[point.x,point.y]
	game.presentation.tick(0)
	game.items_view.queue_redraw()
func changed_pixels(a: Image,b: Image,area: Rect2i) -> int:
	var changed:=0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			if a.get_pixel(x,y)!=b.get_pixel(x,y):changed+=1
	return changed
func run() -> void:
	root.size=Vector2i(1200,760);root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frame();game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],52)
	game.routine_panel.close();game.orders.clear();game.schedule.set_time_speed(0)
	var player=game.actors[0]
	player.position=Vector2(1500,1580);game.room_visibility.tick(0,true)
	game.map_camera.center_on(Vector2(1200,1420));game.map_camera.following=false
	var actor=game.trade.actors.prison_dealer
	var stock: Array=game.trade.merchants.prison_dealer.stock.duplicate()
	locate(actor,Vector2(1200,1450))
	check("front landing is walkable",game.world.can_place_circle(actor.position,17,null,false))
	check("one body attached to merchant actor",actor.get_child_count()==1 and actor.get_child(0)==game.items_view.merchant_visuals.prison_dealer)
	# Render the same location with the old fixed layer and with foot sorting.
	actor.z_index=21;await frame();await frame()
	var before=root.get_texture().get_image()
	before.save_png(OUT+"front-before.png")
	game.presentation.tick(0);await frame();await frame()
	var after=root.get_texture().get_image()
	after.save_png(OUT+"front-after.png")
	var head=(actor.get_global_transform_with_canvas()*Vector2(0,-40))
	var face:=Rect2i(int(head.x)-14,int(head.y)-15,28,30)
	var count=changed_pixels(before,after,face)
	check("front body visibly clears foreground wall",count>60)
	check("merchant uses same foot depth as other actors",actor.z_index==1450)
	check("body renderer inherits actor depth",actor.get_child(0).z_index==0 and actor.get_child(0).z_as_relative)
	locate(actor,Vector2(1200,1370));await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"behind-wall.png")
	check("merchant behind wall keeps lower depth",actor.z_index==1370)
	actor.moved_this_frame=true;actor.walk_elapsed=0.24;actor.facing=Vector2.LEFT
	game.presentation.tick(0);await frame()
	check("walking frames preserved",game.items_view.merchant_frame_index(actor)>=0)
	check("ground items retain independent layer",game.items_view.z_index==21)
	locate(actor,Vector2(1855,825))
	check("merchant hidden under closed room cover",game.world.is_under_roof(actor.position) and not actor.get_child(0).visible)
	player.position=Vector2(1800,900);game.room_visibility.tick(0,true);game.presentation.tick(0)
	check("merchant appears when room revealed",not game.world.is_under_roof(actor.position) and actor.get_child(0).visible)
	check("shop stock unaffected",stock==game.trade.merchants.prison_dealer.stock)
	game.perspective_floor=false;game.items_view.tick_visuals()
	check("legacy flat mode retains depth",actor.z_index==21)
	game.perspective_floor=true
	var old_body=actor.get_child(0)
	game.load_room("r03",["lockpick","chat","backpack"],52);game.routine_panel.close();game.presentation.tick(0)
	check("map change removes old merchant body",not is_instance_valid(old_body) and not game.items_view.merchant_visuals.has("prison_dealer"))
	check("new map has one correct merchant body",game.items_view.merchant_visuals.size()==1 and game.trade.actors.warehouse_dealer.get_child_count()==1)
	game.reset_round();game.routine_panel.close();game.presentation.tick(0)
	check("round reset does not duplicate merchant",game.items_view.merchant_visuals.size()==1 and game.trade.actors.warehouse_dealer.get_child_count()==1)
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var result={"passed":checks.size()-failed.size(),"failed":failed,"checks":checks,"front_face_changed_pixels":count}
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	game.queue_free();await frame();quit(0 if failed.is_empty() else 1)
