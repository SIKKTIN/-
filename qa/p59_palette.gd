extends SceneTree

var checks := {}
var width := 1200
func _initialize() -> void: call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func shot(label: String) -> void:
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p59-%d-%s.png" % [width,label])

func choose(editor, id: String) -> void:
	var index: int = editor.subcategory_ids.find(id)
	editor.subcategory_picker.select(index)
	editor.subcategory_picker.item_selected.emit(index)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): width = int(args[0])
	root.size = Vector2i(width,720 if width == 1200 else 640)
	root.content_scale_size = root.size
	var before := FileAccess.get_sha256("res://data/rooms/r04.json")
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	checks.default_furniture_has_no_tiles = editor.palette_entries.size() > 0 and editor.palette_entries.all(func(e): return e.subcategory == "furnishings")
	await shot("furniture")
	choose(editor,"tiles_corner")
	checks.all_dedicated_turns_findable = ["cafeteria_turn_l_v28","cafeteria_turn_r_v28","cafeteria_turn_l_20_v28","cafeteria_turn_r_20_v28"].all(func(id): return editor.palette_entries.any(func(e): return e.id == id))
	checks.no_furniture_in_turns = editor.palette_entries.all(func(e): return e.subcategory == "tiles_corner")
	await shot("corners")
	editor.resource_search.text = "v28"
	editor.resource_search.text_changed.emit("v28")
	checks.id_search_finds_four = editor.palette_entries.size() == 4
	await shot("search")
	# Real input selects a card, then the map uses its matching asset ID.
	var index: int = editor.palette_entries.find(editor.palette_entries.filter(func(e): return e.id == "cafeteria_turn_l_v28")[0])
	var card: Vector2 = editor.palette.global_position+editor.palette.get_item_rect(index).get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = root.get_final_transform()*card
		event.pressed = down
		Input.parse_input_event(event)
		await frame()
	checks.filtered_card_keeps_asset_identity = editor.placement.get("asset_id","") == "cafeteria_turn_l_v28"
	var count: int = editor.document.collection("fixtures").size()
	editor.place_object("fixtures",Vector2(1500,1700))
	checks.selected_resource_places_correct_asset = editor.document.collection("fixtures").size() == count+1 and editor.document.collection("fixtures")[-1].asset_id == "cafeteria_turn_l_v28"
	editor.document.undo()
	editor.category_picker.select(1)
	editor.category_picker.item_selected.emit(1)
	editor.category_picker.select(0)
	editor.category_picker.item_selected.emit(0)
	checks.secondary_choice_remembered = editor.subcategory_ids[editor.subcategory_picker.selected] == "tiles_corner"
	editor.resource_search.text = "does-not-exist"
	editor.resource_search.text_changed.emit(editor.resource_search.text)
	checks.empty_result_is_explained = editor.palette.item_count == 0 and editor.resource_count.text.begins_with("没有匹配")
	editor.resource_search.text = ""
	editor.resource_search.text_changed.emit("")
	editor.layers.set_locked("fixtures",true)
	checks.locked_cards_stay_disabled = editor.palette.item_count > 0 and editor.palette.is_item_disabled(0)
	checks.original_map_untouched = FileAccess.get_sha256("res://data/rooms/r04.json") == before
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed}
	FileAccess.open("res://docs/tests/p59-%d-native.json" % width,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
