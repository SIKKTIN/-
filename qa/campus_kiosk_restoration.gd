extends SceneTree
const OUT := "res://docs/art/campus-kiosk-v1/"
var checks := {}
var game
func _initialize(): call_deferred("run")
func check(label: String, passed: bool): checks[label]=passed
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func shot(name: String):
	if is_instance_valid(game): game.presentation.tick(0)
	await frame();await frame()
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(OUT+name+".png")
func time(minute: float):
	game.schedule.clock_elapsed=(minute-float(game.schedule.config.start_minutes))/1440*game.schedule.day_seconds
	game.trade.tick(0)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://kiosk-qa.cfg")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var stamp:=FileAccess.get_sha256("res://data/rooms/r04.json")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"installation-before.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"installation-after.json"))
	for key in before:
		if key not in ["walls","architecture","fixtures","visibility_rooms","floor_regions","zones","merchants","lamps"]:check("preserved "+key,before[key]==after[key])
	check("original roaming merchant unchanged",before.merchants==after.merchants.filter(func(m):return m.id!="campus_kiosk"))
	check("other room visibility unchanged",before.visibility_rooms.filter(func(r):return r.id!="repair_2")==after.visibility_rooms.filter(func(r):return r.id!="campus-kiosk"))
	check("other floor regions unchanged",before.floor_regions.filter(func(f):return f.id!="campus-repair_copy1")==after.floor_regions.filter(func(f):return f.id!="kiosk-floor"))
	var installation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"installation.json"))
	check("unrelated fixtures unchanged",before.fixtures.filter(func(f):return f.id not in installation.removed_fixture_ids)==after.fixtures.filter(func(f):return f.id!="kiosk-building"))
	check("old walls removed",before.walls.size()-after.walls.size()==44)
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	check("kiosk is placeable in editor",catalog.entries.any(func(e):return e.id=="kiosk_building_v1"))
	for entry in installation.assets:check(str(entry.key)+" original PNG unchanged",FileAccess.get_sha256("res://"+entry.path)==entry.sha256)
	var document=preload("res://scripts/editor/map_document.gd").new()
	check("map opens",document.open_file("res://data/rooms/r04.json"))
	print("map open error: "+document.last_error)
	check("map validates",document.validate().errors.is_empty())
	print("map validation: "+JSON.stringify(document.validate()))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.world.admission_filter=Callable()
	var player=game.actors[0]
	player.position=Vector2(2640,2470);game.room_visibility.tick(0,true)
	check("customer outside room",game.room_visibility.active_id!="campus-kiosk")
	check("front approach has no invisible wall",game.world.can_place_circle(player.position,game.ACTOR_RADIUS,player,false))
	check("customer cannot walk through store",not game.world.can_place_circle(Vector2(2640,2400),game.ACTOR_RADIUS,player,false))
	for p in [Vector2(2250,2280),Vector2(3030,2340),Vector2(2640,2500)]:
		check("surrounding path reachable "+str(p),not game.world.find_path(player.position,p,player,false,true).is_empty())
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="campus-kiosk")[0]
	check("dedicated roof loaded",cover.style=="kiosk" and cover.roof_texture!=null and cover.visible)
	time(480);check("08:00 opens",game.trade.is_open("campus_kiosk"))
	check("old merchant remains closed before lunch",not game.trade.is_open("prison_dealer"))
	var old_merchant=game.trade.actors.prison_dealer
	var old_position: Vector2=old_merchant.position
	time(720);old_merchant.position=old_merchant.goal
	check("old merchant lunch hours unchanged after arrival",game.trade.is_open("prison_dealer"))
	old_merchant.position=old_position;time(480)
	check("outside window purchase permitted",game.trade.reason(0,"campus_kiosk").is_empty())
	game.presentation.tick(0)
	check("vendor remains visible outside roof",game.items_view.merchant_visuals["campus_kiosk"].visible)
	game.map_camera.center_on(Vector2(2640,2200));game.map_camera.force_update_scroll()
	await shot("runtime-exterior")
	cover.hide();await shot("runtime-cutaway");cover.show()
	game.inventory.wallet=100
	game.shop_panel.open("campus_kiosk")
	check("buy panel opens at outside counter",game.shop_panel.panel.visible)
	check("eight product rows grouped with stock counts",game.shop_panel.offers.item_count==8 and game.shop_panel.offers.get_item_text(0).contains("余12"))
	var item: String=game.trade.merchants.campus_kiosk.stock[0]
	var price: int=int(game.inventory.definitions[game.inventory.instances[item].definition_id].sell_price)
	var purchased: Dictionary=game.trade.try_buy(0,"campus_kiosk",item)
	check("purchase goes into bag and charges exactly once",purchased.ok and game.inventory.bags[0].has(item) and game.inventory.wallet==100-price and not game.trade.merchants.campus_kiosk.stock.has(item))
	check("repeat purchase rejected",not game.trade.try_buy(0,"campus_kiosk",item).ok and game.inventory.wallet==100-price)
	game.shop_panel.refresh()
	check("purchased stock count refreshes",game.shop_panel.offers.get_item_text(0).contains("余11"))
	var next_item: String=game.trade.merchants.campus_kiosk.stock[0]
	game.inventory.wallet=0
	check("insufficient funds preserves stock",not game.trade.try_buy(0,"campus_kiosk",next_item).ok and game.trade.merchants.campus_kiosk.stock.has(next_item))
	game.inventory.wallet=100;game.get_node("HUD").show();game.fullscreen_ui.fps_badge.hide();await shot("runtime-shop");game.shop_panel.close();game.get_node("HUD").hide()
	player.position=Vector2(2640,1900);check("back approach rejected",not game.trade.reason(0,"campus_kiosk").is_empty())
	player.position=Vector2(2640,2470);time(1200)
	check("20:00 closes",not game.trade.is_open("campus_kiosk") and not game.trade.reason(0,"campus_kiosk").is_empty())
	check("closed purchase rejected",not game.trade.try_buy(0,"campus_kiosk",next_item).ok and game.inventory.wallet==100)
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.canvas.zoom=.75;editor.canvas.origin=editor.canvas.size/2-Vector2(2640,2200)*.75;editor.canvas.queue_redraw()
	await shot("editor")
	check("tests preserve map",stamp==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)
