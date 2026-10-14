@tool
extends RefCounted

# Form callbacks read live editor state; they never copy document/refresh flags.
var editor

func _init(owner_editor) -> void:
	editor = owner_editor

func clear_inspector() -> void:
	var previous_refreshing = editor.refreshing
	editor.refreshing = true
	for child in editor.inspector.get_children():
		editor.inspector.remove_child(child)
		child.queue_free()
	editor.refreshing = previous_refreshing

func build_rotation_controls() -> void:
	editor.inspector.add_child(HSeparator.new())
	editor.label(editor.inspector,"旋转",15)
	var angle = editor.label(editor.inspector,"角度  %d°" % editor.canvas.selection_angle,13)
	angle.name = "SelectionAngle"
	var row := HBoxContainer.new()
	editor.inspector.add_child(row)
	editor.button(row,"↶ 左转90°",func(): editor.rotate_selected(-1),100).name = "RotateLeft"
	editor.button(row,"↻ 右转90°",func(): editor.rotate_selected(1),100).name = "RotateRight"
	editor.label(editor.inspector,"旋转中心：建筑中心" if not editor.canvas.group_refs.is_empty() else "旋转中心：物体中心",12)
	if editor.canvas.group_refs.is_empty() and editor.selection.get("group","")=="fixtures" and not preload("res://scripts/presentation/doorway_geometry.gd").managed_fixture(editor.document.value(editor.selection)):
		editor.build_mirror_controls()

func build_mirror_controls() -> void:
	editor.label(editor.inspector,"镜像",15)
	var row := HBoxContainer.new()
	editor.inspector.add_child(row)
	var item: Dictionary = editor.document.value(editor.selection)
	var odd: bool = posmod(int(item.get("rotation_quarters",0)),2)!=0
	var horizontal = editor.button(row,"↔ 左右镜像 X",func(): editor.mirror_selected(true),100)
	horizontal.name = "MirrorHorizontal"
	horizontal.toggle_mode = true
	horizontal.set_pressed_no_signal(bool(item.get("mirror_y" if odd else "mirror_x",false)))
	var vertical = editor.button(row,"↕ 上下镜像 Y",func(): editor.mirror_selected(false),100)
	vertical.name = "MirrorVertical"
	vertical.toggle_mode = true
	vertical.set_pressed_no_signal(bool(item.get("mirror_x" if odd else "mirror_y",false)))
	editor.label(editor.inspector,"床头换边使用左右镜像。再次点击可恢复。",12)

func build_group_inspector() -> void:
	editor.label(editor.inspector,"建筑组合",18)
	editor.label(editor.inspector,"已选 %d 个对象" % editor.canvas.group_refs.size(),13)
	var area: Rect2 = editor.canvas.group_bounds()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",6)
	editor.inspector.add_child(grid)
	for field in ["x","y","w","h"]:
		var row := HBoxContainer.new()
		grid.add_child(row)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		editor.label(row,{"x":"X","y":"Y","w":"宽","h":"高"}[field],12)
		var spin := SpinBox.new()
		spin.name = "Group_"+field
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.custom_minimum_size.x = 74
		spin.add_theme_font_size_override("font_size",12)
		spin.min_value = -10000
		spin.max_value = 20000
		spin.value = {"x":area.position.x,"y":area.position.y,"w":area.size.x,"h":area.size.y}[field]
		spin.editable = field in ["x","y"]
		spin.value_changed.connect(func(value):
			if editor.refreshing: return
			var bounds: Rect2 = editor.canvas.group_bounds()
			var delta := Vector2(value-bounds.position.x,0) if field=="x" else Vector2(0,value-bounds.position.y)
			delta = editor.document.snap_point(delta)
			bounds.position += delta
			if not editor.document.geometry({"group":"bounds","index":-1}).encloses(bounds):
				editor.show_status("移动后超出地图边界。")
				editor.refresh_inspector.call_deferred()
				return
			var snapshot: Dictionary = editor.canvas.Transform.capture(editor.document,editor.canvas.group_refs)
			editor.document.begin()
			editor.canvas.Transform.apply(editor.document,snapshot,0,delta)
			editor.document.commit())
		row.add_child(spin)
		if not spin.editable: spin.get_line_edit().focus_mode = Control.FOCUS_NONE
	editor.build_rotation_controls()
	editor.build_selection_scope()
	var note = editor.label(editor.inspector,"整体拖动和旋转，保持内部相对位置。\n地面与房间范围一起更新。",12)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func build_selection_scope() -> void:
	editor.inspector.add_child(HSeparator.new())
	editor.label(editor.inspector,"框选范围",15)
	for key in ["walls","fixtures","actors","items","routine"]:
		var check := CheckBox.new()
		check.name = "Scope_"+key
		check.text = {"walls":"墙体、门与房间范围","fixtures":"家具摆设","actors":"人物 / NPC","items":"可拾取物品","routine":"日常活动点"}[key]
		check.add_theme_font_size_override("font_size",12)
		check.button_pressed = bool(editor.canvas.selection_scope[key])
		check.toggled.connect(func(value): editor.canvas.selection_scope[key] = value)
		editor.inspector.add_child(check)

func refresh_inspector() -> void:
	if not editor.inspector:
		return
	editor.clear_inspector()
	if is_instance_valid(editor.selection_actions): editor.selection_actions.visible = not editor.selection.is_empty()
	if not editor.canvas.group_refs.is_empty():
		editor.build_group_inspector()
		return
	if editor.selection.is_empty():
		editor.label(editor.inspector,"对象属性",18)
		var help = editor.label(editor.inspector,"点击对象查看属性。\n\n框选建筑：左键拖出矩形，完整包住墙、门和家具。\n\n选中后可整体拖动，R 右转90°，Shift+R 左转。\n\n图层显隐与锁定请切换上方“图层”。",14)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		editor.build_selection_scope()
		return
	var ref = editor.selection.duplicate()
	var object_title = editor.label(editor.inspector,editor.document.name_for(ref),16)
	object_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rect: Rect2 = editor.document.geometry(ref)
	_build_geometry(ref,rect)
	var item = editor.document.value(ref)
	_build_appearance(ref,rect,item)
	_build_properties(ref,rect,item)
	if ref.group in ["starts","dormitories"]:
		editor.label(editor.inspector,"归属：伙伴%d" % (int(ref.index)+1))
	if ref.group == "patrol":
		editor.label(editor.inspector,"巡逻顺序：第%d点" % (int(ref.index)+1))
		editor.button(editor.inspector,"前移巡逻点",func(): editor.reorder_patrol(-1))
		editor.button(editor.inspector,"后移巡逻点",func(): editor.reorder_patrol(1))
	if ref.group == "merchants":
		var note = editor.label(editor.inspector,"移动营业位置时，原地营业与过渡点一起移动；工作和休息位置保留。",12)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.label(editor.inspector,"所有坐标都使用世界位置。",12)


func _build_geometry(ref: Dictionary, rect: Rect2) -> void:
	for field in ["x","y","w","h"] if editor.document.is_rect(ref) else ["x","y"]:
		var row := HBoxContainer.new()
		editor.inspector.add_child(row)
		editor.label(row,{"x":"X位置","y":"Y位置","w":"宽度","h":"高度"}[field])
		var spin := SpinBox.new()
		spin.name = "Geometry_"+field
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.min_value = 1 if field in ["w","h"] else -10000
		spin.max_value = 20000
		spin.step = 1
		var grid_wall: bool = ref.group == "walls" and editor.document.wall_surface(int(ref.index)).has("grid_tile_asset")
		var grid_door: bool = ref.group == "fixtures" and editor.document.asset_definition(str(editor.document.value(ref).get("asset_id",""))).has("grid_door")
		if grid_wall or grid_door:
			spin.step = 20
			if field in ["w","h"]:
				spin.min_value = 20
				spin.editable = false
		spin.value = {"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y}[field]
		if ref.group == "floor_regions" and not editor.document.can_remove(ref): spin.editable = false
		spin.value_changed.connect(func(value):
			if editor.refreshing or not editor.can_edit_selection(): return
			var changed_rect: Rect2 = editor.document.geometry(ref)
			match field:
				"x": changed_rect.position.x = value
				"y": changed_rect.position.y = value
				"w": changed_rect.size.x = value
				"h": changed_rect.size.y = value
			editor.document.begin()
			editor.document.set_geometry(ref,changed_rect)
			editor.document.commit())
		row.add_child(spin)
	if ref.group in ["fixtures","walls","door","access_doors","dorm_doors"]: editor.build_rotation_controls()

func _build_appearance(ref: Dictionary, rect: Rect2, item: Variant) -> void:
	if ref.group == "floor_regions":
		editor.label(editor.inspector,"地板材质",13)
		var materials = preload("res://scripts/editor/floor_catalog.gd").materials(editor.document.data)
		var material_picker := OptionButton.new()
		material_picker.name = "FloorMaterial"
		material_picker.fit_to_longest_item = false
		material_picker.clip_text = true
		material_picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		material_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		material_picker.add_theme_constant_override("icon_max_width",24)
		material_picker.get_popup().add_theme_constant_override("icon_max_width",24)
		var current = str(item.asset_id)+"@"+str(item.get("manifest",editor.document.data.get("terrain_manifest","res://art/environment/factory_v45/manifest.json")))
		for index in materials.size():
			material_picker.add_icon_item(preload("res://scripts/editor/floor_catalog.gd").thumbnail(materials[index]),str(materials[index].name))
			material_picker.set_item_tooltip(index,str(materials[index].name))
			if str(materials[index].id) == current: material_picker.select(index)
		material_picker.item_selected.connect(func(index):
			if editor.can_edit_selection(): editor.document.set_floor_material(ref,materials[index]))
		editor.inspector.add_child(material_picker)
		var floor_help = editor.label(editor.inspector,"G：地板选择；拖动移动，拖四角调整范围。\n材质会同步用于试玩与保存后的游戏。" if editor.document.can_remove(ref) else "这是整图基层，范围受保护；可更换材质。",12)
		floor_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ref.group in ["starts","guard_start","gate_guards","merchants","resident_staff"]:
		var library=preload("res://scripts/presentation/character_library.gd")
		editor.label(editor.inspector,"人物形象",13)
		var selector:=OptionButton.new()
		selector.name="CharacterAppearance"
		selector.add_item("默认形象")
		selector.add_theme_constant_override("icon_max_width",40)
		var ids: Array[String]=[""]
		for id in library.all():
			ids.append(id)
			selector.add_icon_item(library.idle(id),str(library.all()[id].name))
		selector.select(maxi(0,ids.find(editor.document.character_appearance(ref))))
		selector.item_selected.connect(func(index):editor.document.set_character_appearance(ref,ids[index]))
		editor.inspector.add_child(selector)
	if ref.group == "walls" and editor.document.wall_surface(int(ref.index)).has("grid_tile_asset"):
		var current = str(editor.document.wall_surface(int(ref.index)).grid_tile_asset)
		var choices: Array[String] = editor.catalog.compatible_wall_ids(current)
		editor.label(editor.inspector,"墙体款式",13)
		var appearance := OptionButton.new()
		appearance.name = "WallAppearance"
		for id in choices: appearance.add_item(editor.catalog.display_name(id))
		appearance.select(choices.find(current))
		appearance.item_selected.connect(func(index): editor.document.set_wall_asset(int(ref.index),choices[index]))
		editor.inspector.add_child(appearance)
	if ref.group == "walls" and not editor.document.wall_surface(int(ref.index)).has("grid_tile_asset"):
		editor.label(editor.inspector,"建筑显示高度",13)
		var height := SpinBox.new()
		height.name = "WallElevation"
		height.min_value = 18
		height.max_value = 200
		height.value = editor.document.wall_surface(int(ref.index)).get("height",24 if rect.size.x > 60 else 18)
		height.value_changed.connect(func(value):
			if editor.refreshing: return
			editor.document.set_wall_surface(int(ref.index),value))
		editor.inspector.add_child(height)
		var wall_material := OptionButton.new()
		wall_material.name = "WallMaterial"
		wall_material.add_theme_constant_override("icon_max_width",24)
		wall_material.add_icon_item(editor.catalog.icon({"id":"cafeteria_wall_front_v23","icon":editor.catalog.assets.get("cafeteria_wall_front_v23",{}).get("editor_icon","")}),"食堂 · 浅色高墙")
		wall_material.add_icon_item(editor.catalog.icon({"id":"solitary_wall_front_v23","icon":editor.catalog.assets.get("solitary_wall_front_v23",{}).get("editor_icon","")}),"禁闭 · 深灰厚墙")
		wall_material.select(1 if editor.document.wall_surface(int(ref.index)).get("front","") == "solitary_wall_front_v23" else 0)
		wall_material.item_selected.connect(func(index):
			editor.document.set_wall_surface(int(ref.index),height.value,"cafeteria_wall_front_v23" if index == 0 else "solitary_wall_front_v23","cafeteria_coping_v23" if index == 0 else "solitary_coping_v23"))
		editor.inspector.add_child(wall_material)

func _build_properties(ref: Dictionary, rect: Rect2, item: Variant) -> void:
	if item is Dictionary:
		for property in ["name","id"]:
			if item.has(property):
				editor.label(editor.inspector,"名称" if property == "name" else "对象ID")
				var input := LineEdit.new()
				input.name = "Property_"+property
				input.text = str(item[property])
				input.text_submitted.connect(func(value): editor.document.set_property(ref,property,value))
				input.focus_exited.connect(func():
					if not editor.refreshing: editor.document.set_property(ref,property,input.text))
				editor.inspector.add_child(input)
		if ref.group == "visibility_rooms":
			_build_visibility_rooms(ref,item)
		if ref.group == "access_doors":
			_build_access_doors(ref,item)
		if ref.group == "confinement":
			_build_confinement(ref,rect,item)
		if ref.group == "fixtures":
			_build_fixtures(ref,item)
		if ref.group == "dorm_doors":
			_build_dorm_doors(ref,item)
		if ref.group == "items":
			_build_items(ref,item)

func _build_items(ref: Dictionary, item: Dictionary) -> void:
	var item_type := OptionButton.new()
	var definitions: Dictionary = editor.catalog.item_catalog.definitions
	var ids: Array = definitions.keys()
	for id in ids: item_type.add_item(str(definitions[id].name))
	item_type.select(maxi(0,ids.find(str(item.definition_id))))
	item_type.item_selected.connect(func(id): editor.document.set_property(ref,"definition_id",ids[id]))
	editor.inspector.add_child(item_type)

func _build_dorm_doors(ref: Dictionary, item: Dictionary) -> void:
	editor.label(editor.inspector,"寝室门归属")
	var owner := OptionButton.new()
	for id in range(3): owner.add_item("伙伴%d" % (id+1))
	owner.select(int(item.get("actor_id",0)))
	owner.item_selected.connect(func(id): editor.document.set_property(ref,"actor_id",id))
	editor.inspector.add_child(owner)

func _build_fixtures(ref: Dictionary, item: Dictionary) -> void:
	editor.label(editor.inspector,"摆设样式")
	var appearance := OptionButton.new()
	appearance.name = "FixtureAppearance"
	var choices: Array[String] = editor.catalog.appearance_ids(str(item.asset_id))
	for asset in choices:
		var legacy = "（旧地图引用）" if not editor.catalog.is_placeable(asset) else ""
		appearance.add_item(editor.catalog.display_name(asset)+legacy)
	appearance.select(choices.find(str(item.asset_id)))
	appearance.item_selected.connect(func(index): editor.document.set_property(ref,"asset_id",choices[index]); editor.canvas.queue_redraw())
	editor.inspector.add_child(appearance)
	for property in ["blocks_movement","blocks_sight"]:
		var toggle := CheckButton.new()
		toggle.name = property
		toggle.text = "阻挡移动" if property == "blocks_movement" else "阻挡视线"
		toggle.button_pressed = item.get(property,true if property == "blocks_movement" else false)
		toggle.toggled.connect(func(on): editor.document.set_property(ref,property,on))
		editor.inspector.add_child(toggle)

func _build_confinement(ref: Dictionary, rect: Rect2, item: Dictionary) -> void:
	var roofed := CheckButton.new()
	roofed.name = "RoofedCell"
	roofed.add_theme_constant_override("icon_max_width",24)
	roofed.text = "完整封顶 · 遮住内部"
	roofed.icon = editor.catalog.icon({"id":"solitary_roof_v23","icon":editor.catalog.assets.get("solitary_roof_v23",{}).get("editor_icon","")})
	roofed.button_pressed = item.get("building",{}).get("roofed",false)
	roofed.toggled.connect(func(on):
		var building: Dictionary = item.get("building",{}).duplicate(true)
		building.roofed = on
		editor.document.set_property(ref,"building",building))
	editor.inspector.add_child(roofed)
	editor.label(editor.inspector,"建筑立面高度",13)
	var building_height := SpinBox.new()
	building_height.name = "BuildingHeight"
	building_height.min_value = 18
	building_height.max_value = minf(200,rect.size.y-24)
	building_height.value = item.get("building",{}).get("height",110)
	building_height.value_changed.connect(func(value):
		if editor.refreshing: return
		var building: Dictionary = item.get("building",{}).duplicate(true)
		building.height = value
		editor.document.set_property(ref,"building",building))
	editor.inspector.add_child(building_height)
	editor.label(editor.inspector,"关联禁闭门："+str(item.get("door_id","")),13)
	editor.label(editor.inspector,"关押分钟（所有禁闭室）",13)
	var duration := SpinBox.new()
	duration.name = "ConfinementMinutes"
	duration.min_value = 1
	duration.max_value = 1440
	duration.value = editor.document.data.confinement.get("duration_minutes",120)
	duration.value_changed.connect(func(value):
		if editor.refreshing: return
		editor.document.begin()
		editor.document.data.confinement.duration_minutes = value
		editor.document.commit())
	editor.inspector.add_child(duration)
	for property in ["spawn","release"]:
		for axis in range(2):
			editor.label(editor.inspector,("关押点" if property == "spawn" else "释放点")+(" X" if axis == 0 else " Y"),13)
			var spin := SpinBox.new()
			spin.name = "Cell_"+property+str(axis)
			spin.min_value = -10000
			spin.max_value = 10000
			spin.value = item[property][axis]
			spin.value_changed.connect(func(value):
				if editor.refreshing: return
				var point: Array = item[property].duplicate()
				point[axis] = value
				editor.document.set_property(ref,property,point))
			editor.inspector.add_child(spin)

func _build_access_doors(ref: Dictionary, item: Dictionary) -> void:
	editor.label(editor.inspector,"劳动门禁 · 09–12 / 14–17锁门" if item.get("kind","") == "workshop" else "定时门" if item.get("kind","") == "timed" else "禁闭门 · 捕获后锁定")
	if item.get("kind","") == "timed":
		for index in range(2):
			editor.label(editor.inspector,"开放 / 关闭分钟（12:00 = 720）" if index == 0 else "关闭分钟（14:00 = 840）",13)
			var spin := SpinBox.new()
			spin.name = "DoorMinute%d" % index
			spin.min_value = 0
			spin.max_value = 1440
			spin.value = item.get("hours",[720,840])[index]
			spin.value_changed.connect(func(value):
				if editor.refreshing: return
				var hours: Array = item.get("hours",[720,840]).duplicate()
				hours[index] = value
				editor.document.set_property(ref,"hours",hours))
			editor.inspector.add_child(spin)

func _build_visibility_rooms(ref: Dictionary, item: Dictionary) -> void:
	editor.label(editor.inspector,"屋顶样式",13)
	var roofs := OptionButton.new()
	roofs.name = "RoofStyle"
	roofs.add_theme_constant_override("icon_max_width",24)
	roofs.add_item("按建筑自动选择")
	var roof_ids := ["concrete","dark_concrete","metal_green","metal_light"]
	var roof_names := ["寝室 · 混凝土","禁闭室 · 深灰平顶","车间 / 仓库 · 灰绿金属","食堂 · 浅灰金属"]
	var roof_assets := ["roof_concrete_warm","roof_concrete_dark","roof_metal_green","roof_metal_light"]
	for index in range(roof_ids.size()):
		roofs.add_icon_item(load("res://art/editor/room_roofs_v47/"+roof_assets[index]+".tres"),roof_names[index])
	roof_ids.append("clinic")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().clinic_roof_surface),"医务室 · 灰绿防水平顶")
	roof_ids.append("bath")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().bath_roof_surface),"公共浴室 · 灰蓝防水平顶")
	roof_ids.append("monitor")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().monitor_roof_surface),"监控室 · 灰蓝机房平顶")
	roof_ids.append("laundry")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().laundry_roof_surface),"洗衣房 · 蓝灰咬边金属屋顶")
	roofs.get_popup().set("theme_override_constants/icon_max_width",24)
	roof_ids.append("workshop_two")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().laundry_roof_surface),"二号车间 · 蓝灰机加工屋顶")
	roof_ids.append("tool_room")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().toolroom_roof_surface),"工具房 · 深灰防水平顶")
	roof_ids.append("warehouse")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().laundry_roof_surface),"仓库 · 蓝灰金属与采光带")
	roof_ids.append("kiosk")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().kiosk_roof_v1),"小卖铺 · 旧绿铁皮屋顶")
	roof_ids.append("reading")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().roof_reading),"阅览室 · 旧砖红瓦屋顶")
	roof_ids.append("chess")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().roof_chess),"棋牌室 · 旧灰瓦屋顶")
	roof_ids.append("office")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().roof_office),"办公室 · 灰瓦与金属屋脊")
	roof_ids.append("duty")
	roofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().roof_duty),"值班室 · 蓝灰咬边金属屋顶")
	roofs.select(roof_ids.find(str(item.get("roof_style","")))+1)
	roofs.item_selected.connect(func(index): editor.document.set_property(ref,"roof_style","auto" if index==0 else roof_ids[index-1]))
	editor.inspector.add_child(roofs)
	editor.label(editor.inspector,"关联门（多扇门用英文逗号分隔）",13)
	var doors := LineEdit.new()
	doors.name = "VisibilityDoors"
	doors.text = ",".join(item.get("door_ids",[]))
	doors.focus_exited.connect(func():
		if editor.refreshing: return
		var values: Array = []
		for value in doors.text.split(",",false): values.append(value.strip_edges())
		editor.document.set_property(ref,"door_ids",values))
	editor.inspector.add_child(doors)
	editor.label(editor.inspector,"试跑时：主角进入揭顶，离开重盖；编辑视图完整显示。",13)
