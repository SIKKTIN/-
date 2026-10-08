extends "res://scripts/ui/mini_map.gd"

func _draw() -> void:
	if not game:
		return
	draw_style_box(game.presentation.mute_button.theme.get_stylebox("normal","Button"),Rect2(Vector2.ZERO,size))
	if not game.fullscreen_ui:
		draw_string(game.presentation.font,Vector2(10,22),"小地图 · 点击 / 拖动",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("303b46"))
	draw_rect(map_area(),Color("465557"))
	var rect := map_rect()
	var scale_factor: Vector2 = rect.size/game.world.bounds.size
	_paint_transform = Transform2D(Vector2(scale_factor.x,0),Vector2(0,scale_factor.y),rect.position-game.world.bounds.position*scale_factor)
	_painting = true
	draw_rect(rect,Color("91a190"))
	draw_world_rect(game.world.guard_zone.intersection(game.world.bounds),Color("adab89"))
	for zone in game.room_config.get("zones",[]):
		var values: Array = zone.rect
		draw_world_rect(Rect2(values[0],values[1],values[2],values[3]),Color(zone.color))
	for wall in game.world.walls:
		draw_world_rect(wall,Color("465557"))
	_sync_room_cache()
	for fixture in _visible_fixtures:
		draw_world_rect(fixture.rect,Color("526566") if fixture.get("blocks_sight",false) else Color("897b5d"))
	if not game.world.is_under_roof(game.world.crate.get_center()): draw_world_rect(game.world.crate,Color("926d3a"))
	if not game.world.door_open:
		draw_world_rect(game.world.door,Color("775b8b"))
	for gate in game.world.access_doors:
		draw_world_rect(gate.rect,Color("b36e59") if gate.closed else Color("36ab92"))
	draw_world_rect(game.world.exit_area.intersection(game.world.bounds),Color("36ab92"))
	for route in game.world.get("escape_routes") if game.world.get("escape_routes")!=null else []:
		draw_world_rect(route.rect.intersection(game.world.bounds),Color("36ab92") if game.world.escape_route_open(route) else Color("b8835d"))
	if game.room_visibility:
		for room in game.room_visibility.rooms:
			if str(room.id) != game.room_visibility.active_id: draw_world_rect(room.area,Color("697365") if game.room_visibility.visited.has(str(room.id)) else Color("566052"))
	for merchant in game.trade.merchants.values():
		if game.world.is_under_roof(game.trade.actors[merchant.id].position): continue
		var coords: Array = merchant.position
		draw_circle(to_map(Vector2(coords[0],coords[1])),3,Color("ebcb75") if game.trade.is_open(merchant.id) else Color("a79768"))
	for item in game.inventory.instances.values():
		if item.location == "ground":
			var coords: Array = item.position
			if game.world.is_under_roof(Vector2(coords[0],coords[1])): continue
			draw_circle(to_map(Vector2(coords[0],coords[1])),2,Color("e6c691"))
	if not game.world.is_under_roof(game.guard.position): draw_circle(to_map(game.guard.position),4,Color("c65b4b"))
	if game.workshop and is_instance_valid(game.workshop.overseer) and not game.workshop.overseer.escaped and not game.world.is_under_roof(game.workshop.overseer.position):
		draw_circle(to_map(game.workshop.overseer.position),4,Color("c65b4b"))
	if game.prison_alert:
		for officer in game.prison_alert.reinforcements:
			if officer.escaped or game.world.is_under_roof(officer.position): continue
			draw_circle(to_map(officer.position),4,Color("c65b4b"))
	if game.gate_watch:
		for guard in game.gate_watch.guards:
			if not guard.escaped and guard.on_duty() and not game.world.is_under_roof(guard.position):
				draw_circle(to_map(guard.position),3.5,Color("328b82") if guard.state == "talking" else Color("c65b4b"))
	if game.dog and not game.world.is_under_roof(game.dog.position):
		var dog_point := to_map(game.dog.position)
		draw_rect(Rect2(dog_point-Vector2(3,3),Vector2(6,6)),Color("715037") if game.dog.state == "resting" else Color("df8c39"))
	for actor in game.actors:
		if not actor.escaped and (actor.actor_id==game.PLAYER_ACTOR_ID or not game.world.is_under_roof(actor.position)):
			var point := to_map(actor.position)
			if actor.actor_id == game.selected_actor_id:
				draw_arc(point,6,0,TAU,20,Color("ffffff"),1.5)
			draw_circle(point,3.5,Color("248a82"))
	draw_rect(frame_rect(),Color("ffffff"),false,2)
	draw_rect(rect,Color("536052"),false,1)
	_painting = false
