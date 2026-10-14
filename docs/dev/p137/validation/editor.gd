extends SceneTree
const OUT="res://docs/dev/p137/validation/"
var editor
var checks: Dictionary={}
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func check(label: String, passed: bool) -> void:checks[label]=passed
func run() -> void:
	root.size=Vector2i(1200,760)
	root.content_scale_size=root.size
	editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	for connection in root.get_signal_connection_list("focus_exited"):root.disconnect("focus_exited",connection.callable)
	await frame()
	await frame()
	var document=editor.document
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	check("editor loads current saved geometry",document.data==expected)
	check("map validates",document.validate().errors.is_empty())
	check("continuous exterior grass under region",document.data.floor_regions.any(func(r):return r.id=="exterior-base" and r.asset_id=="grass_base_v46"))
	check("no gravel rectangle remains",not document.data.floor_regions.any(func(r):return r.get("id","")=="southwest-maintenance-yard"))
	var fixture_index:=0
	for i in range(document.data.fixtures.size()):
		if editor.catalog.assets.get(str(document.data.fixtures[i].asset_id),{}).get("render_mode","")=="projected_prop":fixture_index=i;break
	var ref: Dictionary={"group":"fixtures","index":fixture_index}
	var original: Rect2=document.geometry(ref)
	editor.canvas.choose(ref)
	editor.canvas.drag_ref=ref.duplicate()
	document.begin()
	var node=editor.canvas.architecture_preview.nodes["fixture:%d" % fixture_index]
	var preview=editor.canvas.architecture_preview
	var builds: int=preview.full_refreshes
	var object_count: int=editor.objects.item_count
	document.move(ref,original.position+Vector2(40,0))
	await frame()
	check("drag updates retained painter geometry",node.footprint==document.geometry(ref))
	check("drag does not rebuild all rooms",preview.full_refreshes==builds and preview.moving_fixture_refreshes>0)
	check("drag keeps object list stable",editor.objects.item_count==object_count and editor.gesture_refresh_pending)
	editor.canvas.finish_gesture()
	await frame()
	check("release refreshes list and inspector",not editor.gesture_refresh_pending and not editor.inspector.get_children().is_empty())
	document.undo()
	await frame()
	check("undo restores original geometry",document.geometry(ref)==original and node.footprint==original)
	document.redo()
	await frame()
	check("redo restores moved painter",node.footprint==document.geometry(ref) and node.footprint.position!=original.position)
	document.undo()
	await frame()
	editor.canvas.drag_ref=ref.duplicate()
	document.begin()
	document.move(ref,original.position+Vector2(60,0))
	await frame()
	editor.canvas.finish_gesture(true)
	await frame()
	check("cancel refreshes dirty status and geometry",not editor.gesture_refresh_pending and not document.dirty() and node.footprint==original)
	var wall: Dictionary={"group":"walls","index":0}
	var first_surface: Dictionary=document.wall_surface(0).duplicate(true)
	document.remove(wall)
	await frame()
	check("wall cache follows removed indexes",document.wall_surface(0).wall_index==0)
	document.undo()
	await frame()
	check("wall cache follows undo",document.wall_surface(0)==first_surface)
	var copy: Dictionary=document.duplicate_entry(wall)
	await frame()
	check("duplicated wall retains material",document.wall_surface(int(copy.index)).grid_tile_asset==first_surface.grid_tile_asset)
	document.undo()
	await frame()
	editor.layers.set_visible("fixtures",false)
	await frame()
	check("fixture layer hides retained painter",not node.visible)
	editor.layers.set_visible("fixtures",true)
	await frame()
	check("fixture layer restores retained painter",node.visible)
	editor.canvas.show_collision=true
	editor.canvas.zoom=3
	editor.canvas.origin=editor.canvas.size/2-Vector2(700,3700)*3
	editor.canvas.queue_redraw()
	await frame()
	check("collision view loads after dragging",editor.canvas.show_collision and not preview.boundary_clips.is_empty())
	check("offscreen grid lines culled",editor.canvas.grid_line_count<180)
	editor.canvas.show_collision=false
	editor.canvas.choose({})
	builds=preview.full_refreshes
	for i in range(5):editor.canvas.origin+=Vector2(10,0);editor.canvas.queue_redraw();await frame()
	check("pan preserves cached architecture",preview.full_refreshes==builds)
	editor.canvas.zoom=0.52
	editor.canvas.origin=editor.canvas.size/2-Vector2(475,3740)*0.52
	editor.canvas.queue_redraw()
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+"grass-editor.png")
	check("editing tests leave map file unchanged",JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json"))==expected)
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"editor-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	await frame()
	quit(0 if failed.is_empty() else 1)
