extends Node

var game
var panel: Panel
var blocker: ColorRect
var title: Label
var note: Label
var selectors: Array = []
var apply_button: Button
var restore_button: Button
var loaded_day := -1

func configure(owner_game) -> void:
	game = owner_game
	blocker = game.schedule._blocker("RoutineBlocker",Rect2(),130)
	panel = game.schedule._paper_panel("DailyRoutine",Vector2.ZERO,Vector2(620,468),131)
	title = game.schedule._label(panel,Vector2(22,15),"",22)
	game.schedule._label(panel,Vector2(22,52),"为三位伙伴安排今天；手动行动可接管当前时段。",15)
	game.schedule._label(panel,Vector2(22,83),"时段",16)
	for id in range(3):
		game.schedule._label(panel,Vector2(173+id*147,83),"伙伴 %d" % (id+1),16)
	for index in range(game.routines.SLOTS.size()):
		game.schedule._label(panel,Vector2(22,122+index*48),game.routines.SLOTS[index].label,16)
		var row := []
		for id in range(3):
			var choice := OptionButton.new()
			choice.name = "Routine_%d_%d" % [id,index]
			choice.position = Vector2(150+id*147,111+index*48)
			choice.size = Vector2(138,48)
			choice.focus_mode = Control.FOCUS_NONE
			for kind in ["idle","work","rest","free"]:
				choice.add_item(game.routines.NAMES[kind])
				choice.set_item_metadata(choice.item_count-1,kind)
			choice.get_popup().add_theme_constant_override("v_separation",14)
			panel.add_child(choice)
			row.append(choice)
		selectors.append(row)
	note = game.schedule._label(panel,Vector2(22,364),"",14)
	apply_button = game.schedule._button(panel,Vector2(22,402),"应用今日安排",apply)
	apply_button.size = Vector2(172,48)
	restore_button = game.schedule._button(panel,Vector2(208,402),"恢复选中伙伴",restore)
	restore_button.size = Vector2(178,48)
	var b: Button = game.schedule._button(panel,Vector2(446,402),"关闭",close)
	b.size = Vector2(152,48)
	close()

func reload() -> void:
	loaded_day = game.routines.day
	for index in range(selectors.size()):
		for id in range(3):
			var choice: OptionButton = selectors[index][id]
			for option in range(choice.item_count):
				choice.set_item_disabled(option,not game.routines.allowed(index,choice.get_item_metadata(option)))
				if choice.get_item_metadata(option) == game.routines.plans[id][index]:
					choice.select(option)
	refresh()

func refresh() -> void:
	if not panel.visible:
		return
	if loaded_day != game.routines.day:
		reload()
	title.text = "第%d天 · 人员日常表" % game.routines.day
	var minute: float = game.schedule.clock_minutes()
	for index in range(selectors.size()):
		for id in range(3):
			selectors[index][id].disabled = game.actors[id].escaped or game.schedule.is_sleep_time() or minute >= game.routines.SLOTS[index].end
	apply_button.disabled = game.schedule.is_sleep_time() or game.phase != "playing"
	restore_button.disabled = game.schedule.is_sleep_time() or game.actors[game.selected_actor_id].escaped
	note.text = "午夜按锁寝规则休息；早晨08:00可安排新一天。" if game.schedule.is_sleep_time() else "本关未设工作岗位，可安排休息与自由活动。" if game.room_config.get("routine_points",{}).get("work",[]).is_empty() else "工作限劳动时段；20点后自由活动留在寝室区。"

func apply() -> void:
	if loaded_day != game.routines.day:
		reload()
		game.show_status("已进入新一天，请重新安排今天的活动。")
		return
	var value := [[],[],[]]
	for index in range(selectors.size()):
		for id in range(3):
			var c: OptionButton = selectors[index][id]
			value[id].append(c.get_item_metadata(c.selected))
	if game.routines.apply_today(value):
		close()

func restore() -> void:
	game.routines.resume(game.selected_actor_id)
	game.show_status("伙伴%d恢复当前时段安排。" % (game.selected_actor_id+1))
	close()

func toggle() -> void:
	if game.phase != "playing":
		return
	if panel.visible:
		close()
	else:
		game.shop_panel.close()
		game.schedule.close()
		game.developer_settings.close()
		panel.show()
		blocker.show()
		reload()
		game.presentation.interaction.refresh()

func close() -> void:
	if panel:
		panel.hide()
	if blocker:
		blocker.hide()
