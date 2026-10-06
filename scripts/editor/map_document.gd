@tool
extends RefCounted

signal changed
const World = preload("res://scripts/world/prison_world.gd")
const RECT_KEYS := ["bounds","door","crate","exit","guard_zone"]
const GROUP_NAMES := {"walls":"墙","fixtures":"摆设","starts":"伙伴","patrol":"巡逻点","guard_start":"巡逻看守","gate_guards":"门岗","merchants":"商人","items":"物品","dormitories":"寝室范围","dorm_doors":"寝室门","zones":"区域","work":"工作点","meal":"取餐点","dine":"用餐点","free":"活动点","door":"主锁门","crate":"推箱","exit":"出口","guard_zone":"看守活动范围","bounds":"地图边界","access_doors":"管制门","confinement":"禁闭室范围"}
const ASSET_NAMES := {"access_reader":"门禁控制盒","prison_gate_closed":"铁门关闭外观","prison_gate_open":"铁门打开外观","solitary_bed":"薄单人床","solitary_door_closed":"禁闭门关闭外观","solitary_door_open":"禁闭门打开外观","prison_notice_board":"旧布告板","wall_vent":"通风口","caged_wall_lamp":"笼罩墙灯","pipe_valve":"管线阀门","wash_basin":"双位洗漱盆","fire_extinguisher":"灭火器","laundry_cart":"洗衣推车","bunk_bed":"双层床","cell_bars":"铁栏杆","toilet_sink":"洗手台与马桶","workbench":"工作台","tool_locker":"工具柜","communal_table":"长桌长凳","notice_board":"公告栏","cafeteria_counter":"食堂取餐台","cafeteria_return":"餐盘回收架","cafeteria_tray":"简陋餐盘","cafeteria_queue":"排队围栏","heavy_crate_handpaint_v03":"木箱摆设","locked_door_closed_v02":"锁门外观（摆设）","locked_door_open_v02":"开门外观（摆设）"}
var data: Dictionary = {}
var path := ""
var disk_hash := ""
var saved_text := ""
var history: Array[Dictionary] = []
var cursor := 0
var transaction: Dictionary = {}
var grid := 20.0
var last_error := ""

func text() -> String:
	return JSON.stringify(data,"\t")+"\n"

func dirty() -> bool:
	return text() != saved_text

func open_file(file_path: String) -> bool:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK or not json.data is Dictionary:
		last_error = "地图JSON无法读取："+json.get_error_message()
		return false
	if not json.data.has("id") or not json.data.has("starts") or not json.data.has("bounds"):
		last_error = "文件缺少地图id、bounds或starts。"
		return false
	var shape_error := check_shape(json.data)
	if shape_error != "":
		last_error = shape_error
		return false
	data = json.data.duplicate(true)
	# Embed room-specific associations in edited maps; old global config remains.
	if not data.has("dormitories"):
		var schedule: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/schedule.json"))
		var rooms: Array = schedule.get("room_dormitories",{}).get(str(data.id),[])
		if not rooms.is_empty():
			data.dormitories = rooms.duplicate(true)
	path = file_path
	disk_hash = FileAccess.get_sha256(path)
	saved_text = text()
	history.clear()
	cursor = 0
	transaction.clear()
	last_error = ""
	changed.emit()
	return true

static func check_shape(candidate: Dictionary) -> String:
	if not candidate.get("confinement",{}) is Dictionary: return "confinement必须是对象。"
	for key in RECT_KEYS+["guard_start"]:
		if candidate.has(key) and not valid_coords(candidate[key],2 if key == "guard_start" else 4):
			return key+"坐标格式错误。"
	for group in ["walls","fixtures","starts","patrol","gate_guards","merchants","items","dormitories","dorm_doors","zones","access_doors","confinement"]:
		var items = candidate.get("confinement",{}).get("cells",[]) if group == "confinement" else candidate.get(group,[])
		if not items is Array:
			return group+"必须是数组。"
		for item in items:
			var rectangle: bool = group in ["walls","fixtures","dormitories","dorm_doors","zones","access_doors","confinement"]
			var object: bool = group in ["fixtures","gate_guards","merchants","items","dorm_doors","zones","access_doors","confinement"]
			if object and not item is Dictionary:
				return group+"对象格式错误。"
			var coords = item.get("rect" if rectangle else "position",[]) if object else item
			if not valid_coords(coords,4 if rectangle else 2):
				return group+"坐标格式错误。"
			if group == "fixtures" and not item.has("asset_id"):
				return "摆设缺少asset_id。"
			if group == "access_doors":
				if str(item.get("id","")) == "" or item.get("kind","") not in ["timed","confinement"]: return "管制门缺少ID或有效kind。"
				if item.kind == "timed":
					if not valid_coords(item.get("hours",[]),2) or item.hours[0] < 0 or item.hours[1] > 1440 or item.hours[0] >= item.hours[1]: return "管制门开放分钟需在0–1440内，先开后关。"
					if not valid_coords(item.get("room_rect",[]),4) or not valid_coords(item.get("evacuation",[]),2): return "定时门缺少区域或疏散点。"
			if group == "confinement":
				if not valid_coords(item.get("spawn",[]),2) or not valid_coords(item.get("release",[]),2) or str(item.get("door_id","")) == "": return "禁闭室缺少关押点、释放点或关联门。"
	var points = candidate.get("routine_points",{})
	if not points is Dictionary:
		return "routine_points必须是对象。"
	for group in ["work","meal","dine","free"]:
		if not points.get(group,[]) is Array:
			return group+"活动点必须是数组。"
		for point in points.get(group,[]):
			if not valid_coords(point,2): return group+"活动点坐标格式错误。"
	return ""

static func valid_coords(value, count: int) -> bool:
	return value is Array and value.size() == count and value.all(func(n): return typeof(n) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(n)))

func begin() -> void:
	transaction = data.duplicate(true)

func commit() -> void:
	if transaction.is_empty():
		return
	if JSON.stringify(transaction) != JSON.stringify(data):
		history.resize(cursor)
		history.append({"before":transaction.duplicate(true),"after":data.duplicate(true)})
		if history.size() > 100:
			history.pop_front()
		cursor = history.size()
	transaction.clear()
	changed.emit()

func cancel_transaction() -> void:
	if not transaction.is_empty():
		data = transaction.duplicate(true)
		transaction.clear()
		changed.emit()

func undo() -> void:
	if cursor > 0:
		cursor -= 1
		data = history[cursor].before.duplicate(true)
		changed.emit()

func redo() -> void:
	if cursor < history.size():
		data = history[cursor].after.duplicate(true)
		cursor += 1
		changed.emit()

func collection(group: String) -> Array:
	if group == "confinement": return data.get("confinement",{}).get("cells",[])
	if group in ["work","meal","dine","free"]:
		return data.get("routine_points",{}).get(group,[])
	return data.get(group,[])

func entries() -> Array:
	var result: Array = []
	for group in RECT_KEYS:
		if data.has(group):
			result.append({"group":group,"index":-1})
	if data.has("guard_start"):
		result.append({"group":"guard_start","index":-1})
	for group in ["walls","fixtures","starts","patrol","gate_guards","merchants","items","dormitories","dorm_doors","zones","access_doors","confinement","work","meal","dine","free"]:
		for index in range(collection(group).size()):
			result.append({"group":group,"index":index})
	return result

func value(ref: Dictionary):
	return data.get(ref.group) if int(ref.index) < 0 else collection(ref.group)[ref.index]

func is_rect(ref: Dictionary) -> bool:
	return ref.group in RECT_KEYS or ref.group in ["walls","fixtures","dormitories","dorm_doors","zones","access_doors","confinement"]

func geometry(ref: Dictionary) -> Rect2:
	var item = value(ref)
	var coords: Array = item.rect if item is Dictionary and is_rect(ref) else item.position if item is Dictionary else item
	return Rect2(coords[0],coords[1],coords[2],coords[3]) if is_rect(ref) else Rect2(Vector2(coords[0],coords[1]),Vector2.ZERO)

func name_for(ref: Dictionary) -> String:
	var item = value(ref)
	var label: String = GROUP_NAMES.get(ref.group,ref.group)
	var suffix: String = str(item.get("name",item.get("id",item.get("asset_id",item.get("definition_id",""))))) if item is Dictionary else str(int(ref.index)+1) if int(ref.index) >= 0 else ""
	return label+(" · "+suffix if suffix != "" else "")

func set_geometry(ref: Dictionary, rect: Rect2) -> void:
	var coords: Array = [rect.position.x,rect.position.y,rect.size.x,rect.size.y] if is_rect(ref) else [rect.position.x,rect.position.y]
	var item = value(ref)
	if item is Dictionary:
		if ref.group == "fixtures" and item.has("draw_depth"):
			item.draw_depth += rect.position.y-float(item.rect[1])
		if ref.group == "merchants":
			var previous: Array = item.position
			for entry in item.get("routine",[]):
				if entry.get("position",[]) == previous:
					entry.position = [rect.position.x,rect.position.y]
		if ref.group == "access_doors":
			for fixture in data.get("fixtures",[]):
				if str(fixture.get("access_id","")) == str(item.id): fixture.rect = coords.duplicate()
			if str(data.get("cafeteria",{}).get("access_id","")) == str(item.id): data.cafeteria.entrance = coords.duplicate()
		item["rect" if is_rect(ref) else "position"] = coords
	elif int(ref.index) < 0:
		data[ref.group] = coords
	else:
		collection(ref.group)[ref.index] = coords
	changed.emit()

func snap_point(point: Vector2) -> Vector2:
	return point.snapped(Vector2(grid,grid)) if grid > 0 else point

func move(ref: Dictionary, point: Vector2) -> void:
	var rect := geometry(ref)
	rect.position = snap_point(point)
	set_geometry(ref,rect)

func set_property(ref: Dictionary, property: String, new_value) -> void:
	if ref not in entries(): return
	var item = value(ref)
	if item is Dictionary:
		begin()
		item[property] = new_value
		commit()

func add(group: String, point: Vector2, asset := "") -> Dictionary:
	begin()
	var item
	var p: Vector2 = snap_point(point)
	match group:
		"walls": item = [p.x,p.y,160,20]
		"fixtures":
			item = {"id":unique_id("prop"),"asset_id":asset,"rect":[p.x,p.y,120,100],"blocks_movement":true,"blocks_sight":false}
			var definition: Dictionary = load("res://scripts/presentation/prop_catalog.gd").assets().get(asset,{})
			if not definition.is_empty():
				var dims: Array = definition.get("footprint_world_size",definition.get("world_size",[120,100]))
				item.rect = [p.x,p.y,dims[0],dims[1]]
				item.blocks_movement = definition.get("blocking",true)
			for existing in data.get("fixtures",[]):
				if existing.asset_id == asset:
					item = existing.duplicate(true)
					item.id = unique_id("prop")
					if item.has("draw_depth"): item.draw_depth += p.y-float(item.rect[1])
					item.rect = [p.x,p.y,existing.rect[2],existing.rect[3]]
					break
		"zones": item = {"id":unique_id("zone"),"name":"新区域","rect":[p.x,p.y,320,240],"color":"#a5b19a"}
		"dormitories": item = [p.x,p.y,240,180]
		"dorm_doors": item = {"actor_id":mini(2,collection(group).size()),"rect":[p.x,p.y,120,12]}
		"gate_guards": item = {"id":unique_id("lookout"),"position":[p.x,p.y]}
		"items": item = {"id":unique_id("item"),"definition_id":asset if asset != "" else "scrap","position":[p.x,p.y]}
		"merchants": item = {"id":unique_id("merchant"),"name":"商人","position":[p.x,p.y],"stock":[{"definition_id":"door_key","count":1},{"definition_id":"lock_tool","count":2}]}
		_: item = [p.x,p.y]
	if group in ["work","meal","dine","free"]:
		if not data.has("routine_points"):
			data.routine_points = {}
		if not data.routine_points.has(group):
			data.routine_points[group] = []
	else:
		if not data.has(group):
			data[group] = []
	collection(group).append(item)
	var ref := {"group":group,"index":collection(group).size()-1}
	commit()
	return ref

func unique_id(prefix: String) -> String:
	var ids: Array = []
	for ref in entries():
		var item = value(ref)
		if item is Dictionary and item.has("id"):
			ids.append(str(item.id))
	var index := 1
	while prefix+"_"+str(index) in ids:
		index += 1
	return prefix+"_"+str(index)

func can_remove(ref: Dictionary) -> bool:
	return not ref.is_empty() and int(ref.index) >= 0 and not ref.group in ["starts","dormitories","confinement","access_doors"]

func remove(ref: Dictionary) -> void:
	if not can_remove(ref):
		return
	begin()
	collection(ref.group).remove_at(ref.index)
	commit()

func duplicate_entry(ref: Dictionary) -> Dictionary:
	if not can_remove(ref):
		return ref
	begin()
	var old = value(ref)
	var item = old.duplicate(true)
	if item is Dictionary and item.has("id"):
		item.id = unique_id(str(item.id))
	collection(ref.group).append(item)
	var next := {"group":ref.group,"index":collection(ref.group).size()-1}
	var rect := geometry(next)
	rect.position += Vector2(40,40)
	set_geometry(next,rect)
	commit()
	return next

func validate() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var shape_error := check_shape(data)
	if shape_error != "":
		return {"errors":[shape_error],"warnings":warnings}
	var regex := RegEx.new()
	regex.compile("^[a-z][a-z0-9_]{1,63}$")
	if regex.search(str(data.get("id",""))) == null:
		errors.append("地图ID需为小写字母、数字和下划线，至少2字符。")
	if data.get("starts",[]).size() != 3:
		errors.append("必须有3个伙伴出生点。")
	for ref in entries():
		var item = value(ref)
		var coords = item.get("rect" if is_rect(ref) else "position",[]) if item is Dictionary else item
		if not coords is Array or coords.size() != (4 if is_rect(ref) else 2) or coords.any(func(n): return not typeof(n) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n))):
			errors.append(name_for(ref)+"：坐标格式错误。")
		elif is_rect(ref) and (coords[2] <= 0 or coords[3] <= 0):
			errors.append(name_for(ref)+"：宽高必须大于0。")
	if not errors.is_empty():
		return {"errors":errors,"warnings":warnings}
	var bounds := geometry({"group":"bounds","index":-1})
	var world = World.new()
	world.configure(data,[])
	var ids: Dictionary = {}
	for ref in entries():
		var rect := geometry(ref)
		if ref.group != "bounds" and ref.group != "exit" and not (bounds.encloses(rect) if is_rect(ref) else bounds.has_point(rect.position)):
			errors.append(name_for(ref)+"：超出地图边界。")
		var item = value(ref)
		if item is Dictionary and item.has("id"):
			var key: String = ref.group+":"+str(item.id)
			if ids.has(key):
				errors.append(name_for(ref)+"：同类ID重复。")
			ids[key] = true
		if not is_rect(ref) and ref.group != "items" and not world.can_place_circle(rect.position,17,null,false):
			if ref.group in ["starts","guard_start","gate_guards"]:
				errors.append(name_for(ref)+"：出生点被墙、门或摆设挡住。")
			else:
				warnings.append(name_for(ref)+"：操作点有碰撞，请确认可抵达。")
		if ref.group == "dorm_doors" and (int(item.get("actor_id",-1)) < 0 or int(item.get("actor_id",-1)) > 2):
			errors.append("寝室门归属必须为伙伴1、2或3。")
	world.free()
	if data.has("dormitories") and data.dormitories.size() != 3:
		errors.append("寝室范围需要按伙伴1、2、3顺序设置3个。")
	if data.has("dormitories") and data.dormitories.size() == 3:
		for index in range(3):
			if not geometry({"group":"dormitories","index":index}).grow(-17).has_point(geometry({"group":"starts","index":index}).position):
				warnings.append("伙伴%d出生点不在自己的寝室内，请检查夜间归属。" % (index+1))
	if data.get("patrol",[]).size() < 2:
		warnings.append("巡逻路线少于2点，看守将主要原地停留。")
	if data.get("routine_points",{}).get("meal",[]).size() != data.get("routine_points",{}).get("dine",[]).size():
		warnings.append("取餐点与用餐点数量不同，请检查三位伙伴的就餐安排。")
	if not collection("confinement").is_empty():
		if collection("confinement").size() != 3: errors.append("禁闭室需为三位伙伴各提供一间。")
		var duration = data.confinement.get("duration_minutes",120)
		if not typeof(duration) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(duration)) or duration <= 0: errors.append("禁闭分钟需大于0。")
		var probe = World.new()
		probe.configure(data,[])
		for cell in collection("confinement"):
			var inside := Rect2(cell.rect[0],cell.rect[1],cell.rect[2],cell.rect[3]).grow(-17)
			var spawn := Vector2(cell.spawn[0],cell.spawn[1])
			if not inside.has_point(spawn) or not probe.can_place_circle(spawn,17,null,false): errors.append("禁闭关押点需在室内可站立处。")
			if not probe.can_place_circle(Vector2(cell.release[0],cell.release[1]),17,null,false): errors.append("禁闭释放点被障碍挡住。")
			if probe.access_by_id(str(cell.door_id)).get("kind","") != "confinement": errors.append("禁闭室关联门缺失。")
		probe.free()
	return {"errors":errors,"warnings":warnings}

func save_file(target: String, rename := false) -> bool:
	last_error = ""
	if not target.begins_with("res://data/rooms/") or target.get_base_dir() != "res://data/rooms" or target.get_extension() != "json":
		last_error = "项目地图只能保存到 res://data/rooms/*.json。"
		return false
	if target != path and FileAccess.file_exists(target):
		last_error = "另存目标已存在，请选择新文件，避免覆盖其他地图。"
		return false
	if target == path and FileAccess.file_exists(path) and FileAccess.get_sha256(path) != disk_hash:
		last_error = "磁盘地图已被外部修改。请重新打开或另存为，未覆盖原文件。"
		return false
	var previous_id: String = str(data.id)
	if rename:
		data.id = target.get_file().get_basename()
	var result := validate()
	if not result.errors.is_empty():
		data.id = previous_id
		last_error = "\n".join(result.errors)
		return false
	var tmp := target+".writing"
	var file := FileAccess.open(tmp,FileAccess.WRITE)
	if file == null:
		data.id = previous_id
		last_error = "无法写入地图："+error_string(FileAccess.get_open_error())
		return false
	file.store_string(text())
	file.close()
	var backup := target+".bak"
	if FileAccess.file_exists(target):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(target),ProjectSettings.globalize_path(backup)) != OK:
			data.id = previous_id
			last_error = "备份失败，原地图未覆盖。"
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
			return false
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),ProjectSettings.globalize_path(target))
	if error != OK:
		data.id = previous_id
		last_error = "保存替换失败："+error_string(error)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	path = target
	disk_hash = FileAccess.get_sha256(path)
	saved_text = text()
	if rename and previous_id != str(data.id):
		# Undo entries from the source map must not restore its ID into this file.
		history.clear()
		cursor = 0
	changed.emit()
	return true

func preview_file() -> String:
	var target := "user://map-editor-preview-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(target,FileAccess.WRITE)
	if file == null:
		last_error = "无法创建试玩副本。"
		return ""
	file.store_string(text())
	file.close()
	return ProjectSettings.globalize_path(target)
