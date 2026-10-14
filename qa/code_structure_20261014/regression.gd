extends SceneTree

const OUT := "res://docs/dev/code-structure-2026-10-14/"
const Resources = preload("res://scripts/presentation/presentation_resources.gd")
const Textures = preload("res://scripts/presentation/world_texture.gd")
var checks: Dictionary = {}
var failed_details: Dictionary = {}

func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(124))
	call_deferred("run")

func check(name: String, actual: Variant, expected: Variant = true) -> void:
	checks[name] = actual==expected
	if not checks[name]: failed_details[name] = {"actual":actual,"expected":expected}

func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://structure-regression.cfg")
	root.size = Vector2i(1200,760)
	root.content_scale_size = root.size
	var disk := FileAccess.get_sha256("res://data/rooms/r04.json")
	check_resources()
	var before: Array = lifecycle(OUT+"escape_game.gd")
	var after: Array = lifecycle("res://scripts/core/escape_game.gd")
	check("lifecycle matches pre-refactor across reset/capture/escape/reload",after,before)
	var legacy_forms: Dictionary = inspector_forms(OUT+"map_editor.gd")
	var new_forms: Dictionary = inspector_forms("res://scripts/editor/map_editor.gd")
	for group in legacy_forms: check("inspector controls and values "+group,new_forms[group],legacy_forms[group])
	check("source map untouched",FileAccess.get_sha256("res://data/rooms/r04.json"),disk)
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report: Dictionary = {"checks":checks,"failed":failed,"details":failed_details,"lifecycle_states":after.size(),"inspector_groups":new_forms.keys()}
	FileAccess.open(OUT+"regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STRUCTURE_REGRESSION "+JSON.stringify({"checks":checks.size(),"failed":failed,"lifecycle_states":after.size(),"inspector_groups":new_forms.size()}))
	quit(0 if failed.is_empty() else 1)

func check_resources() -> void:
	var saved: String = OS.get_environment("ESCAPE_ART_PROFILE")
	for id in ["v01","v02","v03","unknown"]:
		OS.set_environment("ESCAPE_ART_PROFILE",id)
		var old_loader = load(OUT+"game_loading.gd").new()
		var new_loader = load("res://scripts/core/game_loading.gd").new()
		var old_keys: Array = old_loader._requests().map(func(a): return Textures.RuntimeStore.key(a))
		var new_keys: Array = new_loader._requests().map(func(a): return Textures.RuntimeStore.key(a))
		check("prewarm dependencies/order "+id,new_keys,old_keys)
		var config: Dictionary = Resources.configuration()
		var expected: Dictionary = {}
		for field in ["environment","props"]:
			for asset in Resources.read_dictionary(config.profile[field]).assets: expected[str(asset.id)]=asset
		expected.merge(preload("res://scripts/presentation/prop_catalog.gd").assets(),true)
		check("render catalog override order "+id,Resources.definitions(config.profile),expected)
		old_loader.free(); new_loader.free()
	OS.set_environment("ESCAPE_ART_PROFILE",saved)

func lifecycle(path: String) -> Array:
	var label := "before" if path.begins_with(OUT) else "after"
	var game = load(path).new()
	game.room_id="r04"
	root.add_child(game)
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	var states: Array = []
	game.reset_round(["chat","lockpick","backpack"],909)
	states.append(state(game))
	game.capture_actor(-1);game.capture_actor(9)
	states.append(state(game))
	game.capture_actor(1)
	states.append(state(game))
	game.reset_round(["chat","lockpick","backpack"],909)
	game.actors[1].escaped=true;game.on_actor_escaped(1)
	states.append(state(game))
	game.actors[0].escaped=true;game.on_actor_escaped(0)
	states.append(state(game))
	game.reset_round(["chat","lockpick","backpack"],909)
	game.finish_failure("QA timeout")
	states.append(state(game))
	game.reset_round(["backpack","chat","lockpick"],910)
	for room in ["r01","r02","r03","r04"]:
		check("load room "+room+" "+label,game.load_room(room,["chat","chat","backpack"],911))
		states.append(state(game))
	check("unknown map rejected "+label,game.load_room("does-not-exist"),false)
	states.append(state(game))
	game.free()
	return states

func state(game) -> Dictionary:
	return {"room":game.room_id,"phase":game.phase,"captures":game.captures,"counts":game.confinement_counts.duplicate(),"failure":game.failure_reason,"seed":game.deal_seed,"deal":game.deal_number,"elapsed":game.elapsed,"wallet":game.inventory.wallet,"selected":game.selected_actor_id,"door":game.world.door_open,"skills":game.actors.map(func(a):return a.skill_id),"positions":game.actors.map(func(a):return str(a.position)),"home":game.actors.map(func(a):return str(a.home)),"escaped":game.actors.map(func(a):return a.escaped),"manual_player":game.routines.manual.has(0),"held":game.room_access.held.duplicate(true),"menu":game.fullscreen_ui.menu.visible,"bag":game.fullscreen_ui.bag_open}

func inspector_forms(path: String) -> Dictionary:
	var label := "before" if path.begins_with(OUT) else "after"
	var editor = load(path).new()
	root.add_child(editor)
	var result: Dictionary = {}
	for group in ["floor_regions","fixtures","walls","starts","guard_start","patrol","gate_guards","merchants","resident_staff","visibility_rooms","access_doors","confinement","dorm_doors","items"]:
		if group!="guard_start" and editor.document.collection(group).is_empty(): continue
		editor.select_object({"group":group,"index":-1 if group=="guard_start" else 0})
		result[group] = controls(editor.inspector)
		editor.select_object({"group":"fixtures","index":0})
	var old: Rect2 = editor.document.geometry(editor.selection)
	var x: SpinBox = editor.inspector.find_child("Geometry_x",true,false)
	x.value = old.position.x+20
	check("inspector edits live document "+label,editor.document.geometry(editor.selection).position.x,old.position.x+20)
	editor.document.undo()
	check("inspector callback undo "+label,editor.document.geometry(editor.selection),old)
	for i in range(editor.document.data.fixtures.size()):
		if str(editor.document.data.fixtures[i].get("id",""))!="campus-clinic-bed-0": continue
		editor.select_object({"group":"fixtures","index":i})
		var prior: Dictionary = editor.document.value(editor.selection).duplicate(true)
		var mirror: Button = editor.inspector.find_child("MirrorHorizontal",true,false)
		check("bed mirror control exists "+label,mirror!=null)
		if mirror:
			mirror.pressed.emit()
			var axis := "mirror_y" if posmod(int(prior.get("rotation_quarters",0)),2)!=0 else "mirror_x"
			check("mirror signal edits live selected bed "+label,editor.document.value(editor.selection).get(axis,false),not prior.get(axis,false))
			editor.document.undo()
			check("mirror callback undo "+label,editor.document.value(editor.selection),prior)
		break
	editor.canvas.group_refs.assign([{ "group":"fixtures","index":0},{ "group":"fixtures","index":1}])
	editor.refresh_inspector()
	result.group = controls(editor.inspector)
	editor.free()
	return result

func controls(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		var item: Dictionary = {"class":child.get_class(),"children":controls(child)}
		if child is Label or child is Button or child is LineEdit: item.text=child.text
		if child is SpinBox: item.merge({"value":child.value,"min":child.min_value,"max":child.max_value,"step":child.step,"editable":child.editable})
		if child is OptionButton: item.merge({"selected":child.selected,"items":range(child.item_count).map(func(i):return child.get_item_text(i))})
		if child is BaseButton: item.pressed=child.button_pressed
		result.append(item)
	return result
