extends SceneTree
var checks := {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.size=Vector2i(1200,720)
 root.content_scale_size=root.size
 var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
 root.add_child(editor)
 await process_frame
 editor.document.open_file("res://data/rooms/r04.json")
 var preview=editor.canvas.architecture_preview
 preview.refresh()
 await process_frame
 var views=preview.doorways
 checks.editor_red_frame_has_collision=preview.boundary_clips.values().any(func(parts):return parts.any(func(r):return r.has_point(Vector2(500,450))))
 checks.editor_door_gap_has_no_fixed_wall=preview.boundary_clips.values().all(func(parts):return parts.all(func(r):return not r.has_point(Vector2(690,420))))
 editor.canvas.show_collision=true
 checks.editor_collision_door_matches_render=editor.canvas.collision_geometry({"group":"dorm_doors","index":2},Rect2(680,1080,20,120))==Rect2(680,1080,20,60)
 checks.editor_side_span=views.by_id("dorm-2").visual_rect==Rect2(680,1080,20,60)
 checks.editor_threshold=views.by_id("dorm-2").floor_asset=="loading_floor_v46" and views.by_id("dorm-2").floor_texture!=null
 checks.three_editor_styles=["free","grille","locked"].all(func(s):return views.doors.any(func(d):return d.style==s))
 checks.editor_cafeteria_cap=views.by_id("cafeteria-entry").visual_rect==Rect2(980,1300,160,24)
 checks.editor_uses_initial_door_state=views.by_id("cafeteria-entry").closed and not views.by_id("workshop-entry").closed
 checks.editor_free_entries_not_barred=views.doors.filter(func(d):return d.style=="free").all(func(d):return not d.closed)
 checks.editor_hides_old_fixture_doors=preview.nodes.values().filter(func(n):return n.get("kind")=="fixture" and views.Geometry.managed_fixture(preview.world.fixtures[n.wall_index])).all(func(n):return not n.visible)
 var index: int=range(preview.world.fixtures.size()).filter(func(i):return preview.world.fixtures[i].get("access_id","")=="cafeteria-entry")[0]
 checks.select_new_thin_door=preview.visual_hit({"group":"fixtures","index":index},Vector2(1060,1312))
 checks.old_tall_facade_not_selectable=not preview.visual_hit({"group":"fixtures","index":index},Vector2(1060,1390))
 var before: Array=editor.document.data.fixtures[index].rect.duplicate()
 editor.document.data.fixtures[index].rect[0]+=40
 # Fixtures are the artist's display references; authoritative gate projection
 # continues to follow the access-door data when the display reference moves.
 preview.refresh()
 checks.preview_does_not_move_authoritative_access_gate=preview.doorways.by_id("cafeteria-entry").visual_rect.position.x==980
 editor.document.data.fixtures[index].rect=before
 preview.refresh()
 checks.preview_rebuild_is_single_layer=preview.get_children().filter(func(n):return n.name=="RetainedDoorways").size()==1
 await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/tests/p83-editor-editor-preview.png")
 var failed: Array=checks.keys().filter(func(k):return not checks[k])
 var tag:="headless" if DisplayServer.get_name()=="headless" else "native"
 FileAccess.open("res://docs/tests/p83-editor-editor-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"total":checks.size()},"\t"))
 print(JSON.stringify({"checks":checks,"failed":failed}))
 quit(0 if failed.is_empty() else 1)
