extends Node

const Round = preload("res://scripts/minigames/nine_point_round.gd")
const PanelUI = preload("res://scripts/ui/nine_point_scene_panel.gd")
const NAMES := ["林川", "周大勇", "许文斌", "老陆"]
var game
var panel
var round_model
var npc_banks: Array = [200, 200, 200]
var player_count := 4
var amount := 5
var rounds_played := 0
var committed := false
var current_table := ""
var world_view
var table_area := Rect2()
var camera_before := {}
var hidden_fixtures: Array[String] = []
var _tables_revision := -1
var _tables: Array = []

func configure(owner_game):
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	round_model = Round.new()
	panel = PanelUI.new()
	panel.controller = self
	add_child(panel)
	world_view = preload("res://scripts/ui/nine_point_world.gd").new()
	world_view.name = "NinePointSeatedWorld"
	game.add_child(world_view)
	world_view.hide()

func is_open() -> bool:
	return panel != null and panel.opened

func tables() -> Array:
	# Map load/editor rebuild increments the fixture revision; door states and
	# actor movement do not change which fixtures are tables.
	if _tables_revision != game.world.fixtures_revision:
		_tables = game.world.fixtures.filter(func(f): return str(f.get("asset_id", "")) == "chess_card_table_v1")
		_tables_revision = game.world.fixtures_revision
	return _tables.duplicate()

func reason(id: String) -> String:
	if game.phase != "playing" or game.world_input_blocked(): return "当前不能打牌。"
	var player = game.actors[game.PLAYER_ACTOR_ID]
	if player.escaped or player.confined: return "当前不能入座。"
	for fixture in tables():
		if str(fixture.id) != id: continue
		var area: Rect2 = fixture.rect
		var nearest: Vector2 = player.position.clamp(area.position, area.end)
		if player.position.distance_to(nearest) > 78: return "请靠近牌桌。"
		if game.world.is_under_roof(area.get_center()): return "请先进入棋牌室。"
		if not game.world.line_clear(player.position, nearest): return "请走到牌桌旁。"
		return ""
	return "牌桌不存在。"

func open_table(id: String) -> bool:
	var message := reason(id)
	if not message.is_empty():
		game.show_status(message)
		return false
	current_table = id
	for fixture in tables():
		if str(fixture.id) == id: table_area = fixture.rect
	game.stop_selected()
	if game.dialogue: game.dialogue.close()
	prepare()
	var camera = game.map_camera
	camera_before = {"zoom":camera.zoom,"position":camera.position,"following":camera.following}
	hidden_fixtures.clear()
	hidden_fixtures.append(id)
	for fixture in game.world.fixtures:
		if str(fixture.asset_id) == "chess_stool_v1" and table_area.grow(75).has_point(fixture.rect.get_center()): hidden_fixtures.append(str(fixture.id))
	panel.show_table()
	world_view.setup(self,table_area)
	world_view.show()
	sync_fixture_visibility()
	game.show_status("已入座：时间和巡逻仍在继续。",4)
	return true

func frame_table():
	if not is_open(): return
	var camera = game.map_camera
	var span: Vector2 = game.get_viewport().get_visible_rect().size
	camera.zoom = Vector2.ONE*minf(span.x/1200.0,span.y/720.0)*0.85
	camera.following = false
	camera.position = table_area.get_center()-Vector2(span.x*0.43,span.y*0.36)/camera.zoom
	camera.pan_by(Vector2.ZERO)

func is_seated_actor(id: int) -> bool:
	return is_open() and id == game.PLAYER_ACTOR_ID

func hides_fixture(id: String) -> bool:
	return is_open() and id in hidden_fixtures

func sync_fixture_visibility():
	if not game.presentation: return
	for volume in game.presentation.volumes:
		if volume.kind == "fixture": volume._sync_visibility()

func _process(_delta: float):
	if not is_open(): return
	var player = game.actors[game.PLAYER_ACTOR_ID]
	if game.phase != "playing" or player.confined or player.escaped or not table_area.grow(120).has_point(player.position):
		close()
	elif game.schedule.is_sleep_time():
		close()
		game.show_status("熄灯了，牌局结束，请回寝室。",5)

func prepare():
	round_model = Round.new()
	committed = false
	if panel: panel.refresh()

func selected_names() -> Array:
	return NAMES.slice(0, player_count)

func balances() -> Array:
	var values: Array = [game.inventory.wallet]
	for i in player_count-1: values.append(npc_banks[i])
	return values

func bet_reason() -> String:
	for i in balances().size():
		if int(balances()[i]) < amount: return "%s余额不足；可降低注额或选择练习。" % NAMES[i]
	return ""

func confirm_bet() -> bool:
	if not is_open() or panel.busy or round_model.state != "betting": return false
	var message: String = round_model.start(selected_names(), amount, balances())
	if not message.is_empty():
		panel.notice = message
		panel.refresh()
		return false
	game.inventory.wallet = int(round_model.bank_after[0])
	for i in player_count-1: npc_banks[i] = round_model.bank_after[i+1]
	panel.notice = "第一张已发出。保留点数，还是摸第二张？"
	panel.animate_deal()
	game._update_ui()
	return true

func decide(draw_second: bool) -> bool:
	if not is_open() or panel.busy or panel.scratch_index >= 0 or panel.known_cards == 0: return false
	if draw_second:
		if not round_model.draw_for_reveal(): return false
		panel.begin_scratch(1)
		return true
	if not round_model.decide(false): return false
	commit_result()
	rounds_played += 1
	panel.animate_reveal(draw_second)
	return true

func finish_reveal():
	if not is_open() or panel.known_cards != 2 or not round_model.finish_reveal(): return
	commit_result()
	rounds_played += 1
	panel.animate_reveal(true)

func commit_result():
	if committed or round_model.state != "result": return
	committed = true
	# Only this transaction owns the pot: never credit again on redraw/exit.
	game.inventory.wallet += int(round_model.payouts[0])
	for i in range(1,round_model.payouts.size()): npc_banks[i-1] += round_model.payouts[i]
	game._update_ui()

func request_close():
	if round_model.state in ["decision","revealing"]:
		panel.show_forfeit()
	else: close()

func close():
	if not is_open(): return
	if round_model.forfeit(): commit_result()
	panel.hide_table()
	world_view.hide()
	world_view.queue_redraw()
	current_table = ""
	hidden_fixtures.clear()
	sync_fixture_visibility()
	if not camera_before.is_empty():
		game.map_camera.zoom = camera_before.zoom
		game.map_camera.position = camera_before.position
		game.map_camera.following = camera_before.following
		game.map_camera.pan_by(Vector2.ZERO)
		camera_before.clear()
	if game.mobile_controls: game.mobile_controls.cancel_input()
	if game.presentation: game.presentation.interaction.refresh()
	game._update_ui()

func reset():
	close()
	npc_banks = [200, 200, 200]
	rounds_played = 0
	prepare()

func _exit_tree():
	if is_instance_valid(world_view): world_view.queue_free()
