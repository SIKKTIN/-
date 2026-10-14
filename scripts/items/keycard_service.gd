extends RefCounted

# Rights belong to item instances and stable room IDs, never resident names.
const DATA := "res://data/access/keycards.json"
const Geometry := preload("res://scripts/presentation/doorway_geometry.gd")
var game
var config: Dictionary = {}
var room_by_id: Dictionary = {}
var player_rights: Dictionary = {}
var rights_key: Array = []

static func decorate(source: Dictionary) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if str(source.get("id","")) != str(data.map_id): return source
	var result: Dictionary = source.duplicate(true)
	result.keycards = data
	for spec in data.rooms:
		var found: Array = result.visibility_rooms.filter(func(r): return str(r.id)==str(spec.id))
		if found.is_empty(): continue
		var room: Dictionary = found[0]
		room.name = str(spec.name)
		for entry in result.get("dorm_doors",[]):
			if str(spec.id)=="dorm-%d" % int(entry.actor_id):
				entry.card_room = str(spec.id)
				entry.card_controlled = true
		for fixture in result.fixtures:
			if str(fixture.id) not in spec.get("fixtures",[]): continue
			var gate_id: String = str(fixture.get("access_id","fixture:"+str(fixture.id)))
			var matches: Array = result.access_doors.filter(func(g): return str(g.id)==gate_id)
			var gate: Dictionary
			if matches.is_empty():
				gate = fixture.duplicate(true)
				gate.merge({"id":gate_id,"kind":"card","manual_door":false,"initial_closed":str(spec.id) not in data.npc_public_rooms,"room_rect":room.rect.duplicate()},true)
				if str(spec.id).begins_with("dorm"):
					gate.asset_id="doorway_dorm_side_open_v1"
					gate.kind="dorm"
					gate.manual_door=true
				result.access_doors.append(gate)
			else: gate=matches[0]
			gate.card_room=str(spec.id)
			gate.card_controlled=true
			fixture.access_id=gate_id
			# Copy only authored visual properties; retain existing security rules.
			for key in ["asset_id","rotation_quarters","rotation_door_visual_rect","door_art_size"]:
				if fixture.has(key): gate[key]=fixture[key]
			if str(spec.id).begins_with("dorm"): gate.asset_id="doorway_dorm_side_open_v1"
			if gate_id not in room.door_ids: room.door_ids.append(gate_id)
		for gate in result.access_doors:
			if str(gate.id) in room.get("door_ids",[]):
				gate.card_room=str(spec.id)
				gate.card_controlled=true
		for fixture in result.fixtures:
			if data.loot.has(str(fixture.id)): fixture.keycard_loot=data.loot[str(fixture.id)].duplicate(true)
	return result

func _init(owner_game):
	game=owner_game

func reset():
	config=game.room_config.get("keycards",{})
	room_by_id.clear()
	player_rights.clear()
	rights_key.clear()
	for spec in config.get("rooms",[]):
		var room: Dictionary=spec.duplicate(true)
		for region in game.room_config.get("visibility_rooms",[]):
			if str(region.id)!=str(room.id): continue
			var r: Array=region.rect
			room.area=Rect2(r[0],r[1],r[2],r[3])
			room.areas=[]
			for part in region.get("room_parts",[]):
				room.areas.append(Rect2(room.area.position+Vector2(part[0],part[1])*room.area.size,Vector2(part[2],part[3])*room.area.size))
			if room.areas.is_empty(): room.areas.append(room.area)
		room_by_id[str(room.id)]=room
	for spec in config.get("starting",[]):
		var id: String=create(spec)
		game.inventory.instances[id].location="bag"
		game.inventory.instances[id].actor_id=0
		game.inventory.bags[0].append(id)
	game.inventory.metadata_revision+=1

func create(spec: Dictionary) -> String:
	var id: String=game.inventory.add_ground(str(spec.kind),Vector2.ZERO)
	if spec.has("room_id"):
		game.inventory.instances[id].card_rooms=[str(spec.room_id)]
		game.inventory.instances[id].card_label=str(room_by_id.get(str(spec.room_id),{}).get("number","?"))
	game.inventory.metadata_revision+=1
	return id

func is_card(id: String) -> bool:
	var entry: Dictionary=game.inventory.instances.get(id,{})
	return game.inventory.definitions.get(str(entry.get("definition_id","")),{}).get("keycard",false)

func item_name(id: String) -> String:
	var entry: Dictionary=game.inventory.instances.get(id,{})
	if str(entry.get("definition_id",""))=="dorm_card": return str(entry.get("card_label","未绑定"))+" 宿舍卡"
	return str(game.inventory.definitions.get(str(entry.get("definition_id","")),{}).get("name","物品"))

func permissions(id: String) -> Array:
	return game.inventory.instances.get(id,{}).get("card_rooms",[])

func description(id: String) -> String:
	var labels: Array=[]
	for room_id in permissions(id): labels.append("▸ "+str(room_by_id.get(str(room_id),{}).get("name",room_id)))
	return "可开启的房间\n"+"\n".join(labels)+"\n\n随身携带，靠近门时自动匹配。\n刷卡不消耗；对应房卡可在闭馆后开门。\n宿舍宵禁与劳动管制仍需看守放行。"

func matching(room_id: String, actor_id:=0) -> String:
	for id in game.inventory.items(actor_id):
		var entry: Dictionary=game.inventory.instances.get(id,{})
		if entry.get("location","")=="bag" and int(entry.get("actor_id",-1))==actor_id and is_card(str(id)) and room_id in permissions(str(id)): return str(id)
	return ""

func gate(id: String) -> Dictionary:
	for entry in game.world.access_doors+game.world.dorm_doors:
		if str(entry.get("id",""))==id: return entry
	return {}

func gates() -> Array:
	return (game.world.access_doors+game.world.dorm_doors).filter(func(g):return g.get("card_controlled",false))

func room_area(room_id: String) -> Rect2:
	return room_by_id.get(room_id,{}).get("area",Rect2())

func sync_rights():
	var ids: Array=game.inventory.bags.get(0,[])
	var key: Array=[ids,game.inventory.metadata_revision]
	if key==rights_key: return
	rights_key=key.duplicate(true)
	player_rights.clear()
	for id in ids:
		var entry: Dictionary=game.inventory.instances.get(id,{})
		if entry.get("location","")!="bag" or int(entry.get("actor_id",-1))!=0 or not is_card(str(id)): continue
		for room_id in permissions(str(id)): player_rights[str(room_id)]=str(id)

func inside_room(point: Vector2, room_id: String) -> bool:
	return room_by_id.get(room_id,{}).get("areas",[]).any(func(area):return area.has_point(point))

func inside(actor, entry: Dictionary) -> bool:
	return inside_room(actor.position,str(entry.get("card_room","")))

func nearby(actor, entry: Dictionary) -> bool:
	if actor.escaped or actor.confined: return false
	var r: Rect2=game.world.dorm_closure_rect(entry)
	var point: Vector2=actor.position.clamp(r.position,r.end)
	if actor.position.distance_to(point)>72: return false
	return game.world.line_clear(actor.position,point+(actor.position-point).normalized()*12)

func required(room_id: String) -> String:
	return str(room_by_id.get(room_id,{}).get("required","对应房卡"))

func security_reason(entry: Dictionary, actor) -> String:
	if str(entry.get("card_room","" )).begins_with("dorm") and (game.world.dorms_locked or (game.schedule and game.schedule.is_sleep_time())): return "夜间锁定，需要看守放行"
	if str(entry.get("kind",""))=="timed" and game.schedule:
		var hours: Array=entry.get("hours",[720,840])
		var minute: float=game.schedule.clock_minutes()
		if (minute<float(hours[0]) or minute>=float(hours[1])) and not authorized(actor,str(entry.get("card_room",""))): return "已闭馆，需要"+required(str(entry.get("card_room","")))
	if str(entry.get("kind",""))=="workshop" and entry.get("closed",false) and game.workshop and game.workshop.on_duty(): return "劳动期间由看守管理"
	return ""

func state(id: String, actor_id:=0) -> Dictionary:
	var entry: Dictionary=gate(id)
	var room_id: String=str(entry.get("card_room",""))
	var actor=game.actors[actor_id]
	var name: String=str(room_by_id.get(room_id,{}).get("name","房间"))
	var match_id: String=matching(room_id,actor_id)
	var reason: String=security_reason(entry,actor)
	if not reason.is_empty(): return {"name":name,"status":reason,"action":"门禁锁定","enabled":false}
	if not entry.get("closed",false): return {"name":name,"status":"已匹配："+item_name(match_id) if not match_id.is_empty() else "室内可自由离场" if inside(actor,entry) else "需要"+required(room_id),"action":"关门","enabled":inside(actor,entry) or not match_id.is_empty()}
	if match_id.is_empty(): return {"name":name,"status":"需要"+required(room_id),"action":"当前没有对应权限","enabled":false}
	return {"name":name,"status":"已匹配："+item_name(match_id),"action":"刷卡开门","enabled":true}

func toggle(actor_id: int, id: String) -> Dictionary:
	var entry: Dictionary=gate(id)
	if entry.is_empty() or not entry.get("card_controlled",false) or not game.actor_is_controllable(actor_id) or game.world_input_blocked(): return {"ok":false,"reason":"当前不能操作门禁。"}
	if not nearby(game.actors[actor_id],entry): return {"ok":false,"reason":"请靠近门把手。"}
	var status: Dictionary=state(id,actor_id)
	if not status.enabled: return {"ok":false,"reason":str(status.status)+"。"}
	var closing: bool=not entry.closed
	var master: String=str(entry.get("linked_to",id))
	var affected: Array=gates().filter(func(g):return str(g.get("id",""))==master or str(g.get("linked_to",""))==master)
	if affected.is_empty(): affected=[entry]
	if closing:
		for door in affected:
			var closure: Rect2=game.world.dorm_closure_rect(door)
			if game.room_access.dorm_occupants().any(func(a):return preload("res://scripts/core/actor_footprint.gd").body_at(a.position).intersects(closure)): return {"ok":false,"reason":"门口有人，请等通道清空后再关门。"}
	for door in affected:door.manual_closed=closing
	if entry in game.world.dorm_doors or str(entry.get("kind",""))=="dorm":
		entry.closed=closing
		game.world._changed(true)
	else: game.world.set_access_closed(id,closing)
	if game.room_visibility: game.room_visibility.doorways.tick(true)
	return {"ok":true,"reason":str(status.name)+("已关闭。" if closing else "已打开，刷卡不消耗。")}

func authorized(actor, room_id: String) -> bool:
	if actor==game.actors[0]:
		sync_rights()
		return player_rights.has(room_id)
	if actor not in game.actors: return true # Staff retain their existing AI/security rules.
	return room_id in config.get("npc_public_rooms",[]) or (str(room_id)=="dorm-%d" % int(actor.actor_id))

func movement_allowed(actor, point: Vector2) -> bool:
	for room_id in room_by_id:
		if not inside_room(point,room_id): continue
		if inside_room(actor.position,room_id) or authorized(actor,room_id): continue
		return false
	return true

func prepare_npc_route(actor, goal: Vector2):
	if actor==game.actors[0] or actor not in game.actors or actor.confined: return
	for entry in gates():
		if not entry.closed or str(entry.get("kind","")) in ["timed","workshop"]: continue
		var room_id: String=str(entry.card_room)
		if not authorized(actor,room_id) or not security_reason(entry,actor).is_empty(): continue
		if inside_room(actor.position,room_id)==inside_room(goal,room_id): continue
		entry.manual_closed=false
		if entry in game.world.dorm_doors or str(entry.get("kind",""))=="dorm":
			entry.closed=false
			game.world._changed(true)
		else: game.world.set_access_closed(str(entry.id),false)

func tick():
	if config.is_empty() or not game.room_access: return
	# AI owns its credentials; no player card is borrowed to move an NPC.
	var occupants: Array=game.room_access.dorm_occupants()
	for entry in gates():
		if not entry.closed or str(entry.get("kind","")) in ["timed","workshop"]: continue
		var room_id: String=str(entry.card_room)
		var r: Rect2=game.world.dorm_closure_rect(entry)
		for actor in occupants:
			if actor==game.actors[0] or actor.get("confined")==true: continue
			# NPCs route to the room before entering; opening nearby unblocks that route.
			if actor.position.distance_to(actor.position.clamp(r.position,r.end))>180: continue
			if not authorized(actor,room_id): continue
			if not security_reason(entry,actor).is_empty(): continue
			entry.manual_closed=false
			if entry in game.world.dorm_doors or str(entry.get("kind",""))=="dorm": entry.closed=false; game.world._changed(true)
			else: game.world.set_access_closed(str(entry.id),false)
			break
