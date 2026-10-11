"""Small, asserted source transformations from the saved working copy."""
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]

def read(file): return (ROOT/file).read_text(encoding='utf-8-sig')
def save(file,s): (ROOT/file).write_text(s,encoding='utf-8')
def replace(s,before,after):
    assert before in s, before
    return s.replace(before,after)
def cut_func(s,name):
    pattern=r'^func '+re.escape(name)+r'\([^\n]*\n.*?(?=^func |\Z)'
    m=re.search(pattern,s,re.M|re.S)
    assert m,name
    return s[:m.start()]+s[m.end():],m.group()

# Remove every production dependency on the retired daily planner.
for p in (ROOT/'scripts').rglob('*.gd'):
    if p.name in ['routine_panel.gd','routine_board.gd']: continue
    s=p.read_text(encoding='utf-8-sig')
    s=re.sub(r'^\t*if game\.(?:get\("routine_panel"\)|routine_panel):\n\t+game\.routine_panel\.close\(\)\n','',s,flags=re.M)
    s=re.sub(r'^\t*if game.get\("routine_panel"\):\n\t+game\.routine_panel\.close\(\)\n','',s,flags=re.M)
    s=re.sub(r'^\t+game\.routine_panel\.close\(\)\n','',s,flags=re.M)
    s=s.replace(' or game.routine_panel.panel.visible','').replace(' and not game.routine_panel.panel.visible','')
    s=s.replace('game.routines and game.routine_panel and game.fullscreen_ui','game.routines and game.fullscreen_ui')
    if s!=p.read_text(encoding='utf-8-sig'):p.write_text(s,encoding='utf-8')

s=read('scripts/core/daily_routine.gd')
for name in ['apply_today','offer_morning']: s,_=cut_func(s,name)
s=re.sub(r'^\t*morning_pending = .*\n','',s,flags=re.M)
s=s.replace('var morning_pending := true\n','').replace('\toffer_morning()\n','')
save('scripts/core/daily_routine.gd',s)
s=read('scripts/core/tutorial_day.gd').replace('\tgame.routines.morning_pending = false\n','')
save('scripts/core/tutorial_day.gd',s)

s=read('scripts/core/escape_game.gd')
s=s.replace('const RoutinePanel = preload("res://scripts/ui/routine_panel.gd")\n','').replace('var routine_panel\n','')
s=s.replace('\troutine_panel = RoutinePanel.new()\n\tadd_child(routine_panel)\n\troutine_panel.configure(self)\n','').replace('\troutines.offer_morning()\n','')
s=s.replace('\tif routine_panel and routine_panel.panel.visible:\n\t\troutine_panel.reload()\n','').replace('\tif routine_panel:\n\t\troutine_panel.refresh()\n','')
s=s.replace(' or (routine_panel != null and routine_panel.panel.visible)','')
s=s.replace('var skill_button: Button\n','').replace('var hint_label: Label\n','')
s,_=cut_func(s,'_floor_style')
s,old_update=cut_func(s,'_update_ui')
update='''func _update_ui(refresh_hud := true) -> void:
	if status_label:
		status_label.text = status_text
	if inventory_panel:
		inventory_panel.refresh()
	if shop_panel:
		shop_panel.refresh()
	if fullscreen_ui and refresh_hud:
		fullscreen_ui.refresh()
	if items_view:
		items_view.queue_redraw()

'''
s=s.replace('func paint_floor(',update+'func paint_floor(')

# Bootstrap owns construction/order, the game script owns play/reset/input.
globals=set(re.findall(r'^(?:const|var)\s+(\w+)',s,re.M))|set(re.findall(r'^func\s+(\w+)',s,re.M))|{'texture_filter','add_child','get_tree','get_node'}
tokens=re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*|\b[A-Za-z_]\w*\b')
def qualify(body):
    def transform(m):
        t=m.group()
        if t=='self':return 'game'
        if t in globals and (m.start()==0 or body[m.start()-1]!='.'):
            return 'game.'+t
        return t
    return tokens.sub(transform,body)
s,ready=cut_func(s,'_ready')
body=ready[ready.index('\n')+1:].rstrip()+'\n'
load_end=body.index('\tfor index in range(3):')
services_start=body.index('\tpresentation = Presentation.new()')
loader=qualify(body[:load_end])
loader=loader.replace('\t\treturn\n','\t\treturn {}\n')+'\treturn config\n'
world=qualify(body[load_end:services_start])
services=qualify(body[services_start:])
bootstrap='''extends RefCounted

# Keep startup dependency order explicit. Components retain the game facade;
# game lifetime/reset/input remain in escape_game.gd.
static func configure(game) -> void:
	var config: Dictionary = _load_room(game)
	if config.is_empty(): return
	_create_world(game,config)
	_create_services(game)

static func _load_room(game) -> Dictionary:
'''+loader+'\nstatic func _create_world(game, config: Dictionary) -> void:\n'+world+'\nstatic func _create_services(game) -> void:\n'+services
save('scripts/core/game_bootstrap.gd',bootstrap)
s=s.replace('func _build_ui()', 'func _ready() -> void:\n\tpreload("res://scripts/core/game_bootstrap.gd").configure(self)\n\nfunc _build_ui()',1)
s,ui=cut_func(s,'_build_ui')
body=ui[ui.index('\n')+1:]
start=body.index('\tvar title :='); end=body.index('\troom_selector =')
body=body[:start]+body[end:]
body=body.replace('\tfor index in range(3):','\tfor index in range(1):')
start=body.index('\tskill_button ='); body=body[:start]
save('scripts/ui/hud_shell.gd','extends RefCounted\n\n# Shared HUD nodes needed before the final fullscreen skin is constructed.\nstatic func configure(game) -> void:\n'+qualify(body))
s=s.replace('func _process(', 'func _build_ui() -> void:\n\tpreload("res://scripts/ui/hud_shell.gd").configure(self)\n\nfunc _process(',1)
save('scripts/core/escape_game.gd',s)

# The final HUD now owns its ability state; no invisible legacy button.
s=read('scripts/ui/fullscreen_hud.gd')
s=s.replace('var routine_button: Button\n','')
s=s.replace('\t# Retain a hidden handle for older HUD consumers, without a menu entry.\n\troutine_button = _button("",Callable())\n\troutine_button.hide()\n\troutine_button.disabled = true\n','')
s=s.replace('\troutine_button.position = safe.position+Vector2(308,0)\n\troutine_button.size = Vector2(124,48)\n','').replace('\troutine_button.hide()\n','')
s=s.replace('for index in range(3):','for index in range(game.cards.size()):')
s=s.replace(',game.routine_panel.blocker','').replace(',game.routine_panel.panel','').replace('\tgame.routine_panel.layout(safe)\n','')
s=s.replace('\tvar planning: bool = game.routine_panel.panel.visible\n','')
s=s.replace('\t# z_index alone does not determine Control input order; hide the covered\n\t# global entry as well, so the last HUD child cannot intercept planner taps.\n\tmenu_button.z_index = 120 if planning else 240\n','')
s=s.replace('game.get_tree().paused = game.routine_panel != null and game.routine_panel.panel.visible','game.get_tree().paused = false')
start=s.index('\t\telif game.routine_panel.panel.visible:');end=s.index('\t\telif game.shop_panel.panel.visible:',start)
s=s[:start]+s[end:]
s=s.replace('\tability_button.text = "停止" if game.skill_button.text.begins_with("停止") else "能力"\n\tability_button.tooltip_text = game.skill_button.text\n','\tvar ability: Dictionary = game.skills.button_state(actor)\n\tability_button.text = "停止" if ability.active else "能力"\n\tability_button.tooltip_text = ability.label\n')
s=s.replace('not active or game.skill_button.disabled','not active or ability.disabled').replace('\tgame.skill_button.hide()\n','')
s=s.replace('and running when the daily planner or pause menu stops gameplay.','and running while the pause menu stops gameplay.')
save('scripts/ui/fullscreen_hud.gd',s)

# Presentation handles world/audio, HUD owns status cards and their styling.
s=read('scripts/presentation/game_presentation.gd')
start=s.index('\tfor index in range(game.cards.size()):',s.index('func _make_ui'))
end=s.index('\tmute_button = Button.new()',start)
s=s[:start]+s[end:]
s,_=cut_func(s,'update_cards')
s=s.replace('var card_symbols: Array[TextureRect] = []\n','').replace('\tupdate_cards()\n','')
save('scripts/presentation/game_presentation.gd',s)

# Update current regression entry points and their reusable test bases.
for file in ['qa/p101_npc_responses.gd','qa/p102_npc_responses.gd','qa/p104_tutorial_regression.gd','qa/p104_npc_two_day_cycle.gd','qa/p90_warning_recovery.gd','qa/p94_single_player_ui.gd']:
    s=read(file)
    s=re.sub(r'^\t+game\.routine_panel\.close\(\)\n','',s,flags=re.M)
    s=s.replace('\t\tif paused: game.routine_panel.close()\n','')
    s=s.replace('not game.routine_panel.panel.visible and not paused','game.get("routine_panel")==null and not paused')
    s=s.replace('game.cards[0].visible and not game.cards[1].visible and not game.cards[2].visible','game.cards.size()==1 and game.cards[0].visible')
    s=s.replace('not ui.routine_button.visible and not game.routine_panel.panel.visible','ui.get("routine_button")==null and game.get("routine_panel")==null')
    s=s.replace('inv.transfer_buttons.all(func(button):return not button.visible)','inv.get("transfer_buttons")==null')
    save(file,s)
print('Removed retired planner dependencies; split bootstrap/HUD; single-player HUD cleanup applied.')
