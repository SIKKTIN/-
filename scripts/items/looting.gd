extends Node

const Packing=preload("res://scripts/items/grid_packing.gd")
var game
var panel
var containers: Dictionary={}
var tables: Dictionary={}
var current_id: String=""
var selected_id: String=""
var searching:=false
var revision:=0
var nearby_containers: Dictionary={}
const NEARBY_CELL:=128.0

func configure(owner_game):
	game=owner_game
	tables=JSON.parse_string(FileAccess.get_file_as_string("res://data/items/loot_tables.json"))
	panel=preload("res://scripts/ui/looting_panel.gd").new()
	add_child(panel)
	panel.configure(self)
	reset()

func reset():
	close()
	containers.clear()
	nearby_containers.clear()
	for fixture in game.world.fixtures:
		if fixture.has("loot_profile") and tables.profiles.has(str(fixture.loot_profile)):
			containers[str(fixture.id)]={"fixture":fixture,"generated":false,"ids":[],"revealed":{},"progress":{}}
			index_container(str(fixture.id),fixture.rect)
	revision+=1

# Static container candidates are indexed once; exact range and wall checks
# still run for candidates, so entering a room or opening a door is immediate.
func index_container(id: String, rect: Rect2):
	var reach:=rect.grow(72)
	var low:=Vector2i((reach.position/NEARBY_CELL).floor())
	var high:=Vector2i((reach.end/NEARBY_CELL).floor())
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell:=Vector2i(x,y)
			if not nearby_containers.has(cell):nearby_containers[cell]=[]
			nearby_containers[cell].append(id)

func nearby_ids(point: Vector2) -> Array:
	return nearby_containers.get(Vector2i((point/NEARBY_CELL).floor()),[])

func is_open() -> bool:
	return not current_id.is_empty()

func reason(id: String) -> String:
	if not containers.has(id) or not game.inventory.available(0) or game.actors[0].confined:return "现在不能翻找。"
	var rect: Rect2=containers[id].fixture.rect
	var actor=game.actors[0]
	var closest: Vector2=actor.position.clamp(rect.position,rect.end)
	if actor.position.distance_to(closest)>72:return "靠近容器后才能翻找。"
	if game.world.is_under_roof(rect.get_center()):return "进入房间后才能翻找。"
	var approach: Vector2=closest+(actor.position-closest).normalized()*3
	if not game.world.line_clear(actor.position,approach):return "隔着墙无法翻找这个容器。"
	return ""

func _generate(id: String):
	var state: Dictionary=containers[id]
	if state.generated:return
	var rng:=RandomNumberGenerator.new()
	rng.seed=game.deal_seed^id.hash()
	var profile: Dictionary=tables.profiles[str(state.fixture.loot_profile)]
	var entries: Array=[]
	var kinds: Array = profile.get("guaranteed",[]).duplicate()
	var card_specs: Array=state.fixture.get("keycard_loot",[])
	# Guaranteed cards are packed first so random bulky loot cannot erase them.
	var cards: Array=[]
	for spec in card_specs: cards.append(str(spec.kind))
	kinds=cards+kinds
	for i in range(rng.randi_range(3,5)):
		kinds.append(str(profile.items[rng.randi_range(0,profile.items.size()-1)]))
	var card_index:=0
	for kind in kinds:
		var shape: Vector2i=game.inventory.item_size(kind)
		var occupied:=Packing.pack(entries,Vector2i(4,4))
		var space:=Packing.first_space(occupied,Vector2i(4,4),shape)
		if space.x<0:continue
		var item: String
		if card_index<card_specs.size():
			item=game.keycards.create(card_specs[card_index])
			card_index+=1
		else: item=game.inventory.add_ground(kind,Vector2.ZERO)
		game.inventory.instances[item].location="container"
		game.inventory.instances[item]["container_id"]=id
		game.inventory.instances[item]["search_seconds"]=1.6+shape.x*shape.y*0.45
		state.ids.append(item)
		state.progress[item]=0.0
		entries.append({"id":item,"shape":shape})
	state["layout"]=Packing.pack(entries,Vector2i(4,4))
	state.generated=true
	revision+=1

func open(id: String) -> bool:
	if (game.world_input_blocked() and not is_open()) or not reason(id).is_empty():return false
	close()
	game.mobile_controls.cancel_input()
	game.orders.stop(0)
	game.skills.cancel(0)
	game.routines.take_control(0)
	game.shop_panel.close()
	game.dialogue.close()
	game.fullscreen_ui.bag_open=false
	current_id=id
	_generate(id)
	selected_id=""
	for item in containers[id].ids:
		if containers[id].revealed.get(item,false):selected_id=item;break
	searching=not pending_item().is_empty()
	panel.show_panel()
	game._update_ui()
	return true

func close():
	current_id=""
	selected_id=""
	searching=false
	if panel:panel.hide_panel()

func pending_item() -> String:
	if not is_open():return ""
	for id in containers[current_id].ids:
		if not containers[current_id].revealed.get(id,false):return str(id)
	return ""

func toggle_search():
	if not is_open():return
	searching=not searching and not pending_item().is_empty()
	panel.refresh()

func tick(delta: float):
	if not is_open():return
	if not reason(current_id).is_empty() or game.phase!="playing" or (game.tutorial and game.tutorial.speaking()):close();return
	if not searching or game.get_tree().paused:panel.refresh();return
	var remaining:=maxf(0,delta)
	while remaining>0:
		var id:=pending_item()
		if id.is_empty():searching=false;break
		var state: Dictionary=containers[current_id]
		var duration: float=game.inventory.instances[id].search_seconds
		var elapsed: float=state.progress[id]
		var step:=minf(remaining,duration-elapsed)
		state.progress[id]=elapsed+step
		remaining-=step
		if state.progress[id]>=duration-0.00001:
			state.revealed[id]=true
			if selected_id.is_empty():selected_id=id
			revision+=1
		else:break
	if pending_item().is_empty():searching=false
	panel.refresh()

func select(id: String):
	if not is_open() or not containers[current_id].ids.has(id):return
	selected_id=id
	panel.refresh()

func take_reason(id: String) -> String:
	if not is_open() or not reason(current_id).is_empty():return "已离开容器，不能拿取。"
	var state: Dictionary=containers[current_id]
	if not state.ids.has(id) or not state.revealed.get(id,false):return "先翻找出物品再拿取。"
	var inv=game.inventory
	if not inv.instances.has(id) or inv.instances[id].location!="container" or inv.instances[id].container_id!=current_id:return "物品已不在容器。"
	if inv.find_space(0,str(inv.instances[id].definition_id)).x<0:return "背包没有足够的连续空格。"
	return ""

func take(id: String, point:=Vector2i(-1,-1)) -> Dictionary:
	var error:=take_reason(id)
	if error.is_empty() and point.x>=0:error=game.inventory.placement_reason(0,id,point)
	if not error.is_empty():return {"ok":false,"reason":error}
	var state: Dictionary=containers[current_id]
	var inv=game.inventory
	# One synchronous ownership transfer; repeated clicks cannot duplicate it.
	state.ids.erase(id)
	state.layout.erase(id)
	inv.bags[0].append(id)
	inv.instances[id].location="bag"
	inv.instances[id].actor_id=0
	if point.x>=0:inv.place_item(0,id,point)
	if selected_id==id:selected_id=""
	for next in state.ids:
		if state.revealed.get(next,false):selected_id=next;break
	revision+=1
	game.inventory_panel.refresh()
	panel.refresh()
	return {"ok":true,"reason":"已放入背包。"}

# Both grids share the same atomic move/transfer validation.
func move_reason(id: String, origin: String, target: String, point: Vector2i) -> String:
	if not is_open() or not reason(current_id).is_empty():return "已离开容器，不能移动物品。"
	var state: Dictionary=containers[current_id]
	var inv=game.inventory
	if not inv.instances.has(id):return "物品已经不可操作。"
	if origin=="source":
		if not state.ids.has(id) or not state.revealed.get(id,false):return "先翻找出物品再移动。"
		if inv.instances[id].location!="container" or inv.instances[id].get("container_id","")!=current_id:return "物品已不在容器。"
	elif origin=="bag":
		if not inv.owns(0,id):return "物品已不在背包。"
	else:return "无效的移动来源。"
	if target=="bag":return inv.placement_reason(0,id,point,origin=="bag")
	if target!="source":return "请拖到柜子或背包的格子中。"
	var rect:=Rect2i(point,inv.item_size(str(inv.instances[id].definition_id)))
	if not Rect2i(0,0,4,4).encloses(rect):return "物品超出了柜子边界。"
	if not Packing.fits(state.layout,Vector2i(4,4),rect,id if origin=="source" else ""):return "这些格子已被其他物品占用。"
	return ""

func move_item(id: String, origin: String, target: String, point: Vector2i) -> Dictionary:
	var error:=move_reason(id,origin,target,point)
	if not error.is_empty():return {"ok":false,"reason":error}
	if origin=="source" and target=="bag":return take(id,point)
	var inv=game.inventory
	var state: Dictionary=containers[current_id]
	if target=="bag":return inv.move_item(0,id,point)
	if origin=="bag":
		inv.bags[0].erase(id)
		inv.forget_position(0,id)
		state.ids.append(id)
		inv.instances[id].location="container"
		inv.instances[id].actor_id=-1
		inv.instances[id]["container_id"]=current_id
		var duration: float=inv.instances[id].get("search_seconds",0.0)
		state.progress[id]=duration
		state.revealed[id]=true
	state.layout[id]=Rect2i(point,inv.item_size(str(inv.instances[id].definition_id)))
	selected_id=id
	revision+=1
	return {"ok":true,"reason":"已放回柜子。" if origin=="bag" else "已调整物品位置。"}

func take_all() -> Dictionary:
	if not is_open():return {"ok":false,"reason":"请先打开容器。"}
	var count:=0
	for id in containers[current_id].ids.duplicate():
		if containers[current_id].revealed.get(id,false) and take(str(id)).ok:count+=1
	return {"ok":count>0,"reason":"拿取%d件物品；未翻找或放不下的物品仍留在容器。"%count}

func snapshot() -> Dictionary:
	return {"open":current_id,"searching":searching,"containers":containers.size(),"states":containers.duplicate(true)}
