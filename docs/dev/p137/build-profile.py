"""Instrument current frame/service code in QA copies; leave production untouched."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'docs/dev/p137'
QA=ROOT/'qa'
def read(path):return (ROOT/path).read_text('utf-8')
def body(source,name):
    start=source.index('func '+name+'(')
    end=source.find('\nfunc ',start+1)
    return source[start:end if end>=0 else len(source)].rstrip()+'\n'
def checkpoint(label):return f'\tprofile_times["{label}"]=(Time.get_ticks_usec()-profile_mark)/1000.0\n\tprofile_mark=Time.get_ticks_usec()\n'
frame=read('scripts/core/game_frame.gd')
frame=frame.replace('static func tick(game, delta: float) -> void:\n','static func tick(game, delta: float) -> void:\n\tgame.profile_sections.clear()\n\tvar profile_mark:=Time.get_ticks_usec()\n')
for marker,label in [('\tgame.world.begin_ai_paths()','clock_routines_npc'),('\tgame.orders.tick(delta)','staff_input'),('\tgame.trade.tick(delta)','movement_orders'),('\tgame.guard.tick(delta)','skills_trade_dog'),('\tgame.world.end_ai_paths()','guard_work_alert'),('\tif game.map_camera:\n\t\tgame.map_camera.tick(delta)\n\tif game.phase','visibility_dialogue_loot_social'),('\tgame._update_ui(false)','camera_status'),('\tif game.presentation:\n\t\tgame.presentation.tick(delta)\n\tif not game.perspective_floor','hud_panels')]:
    assert frame.count(marker)==1,(marker,frame.count(marker))
    code=f'\tgame.profile_sections["{label}"]=(Time.get_ticks_usec()-profile_mark)/1000.0\n\tprofile_mark=Time.get_ticks_usec()\n'
    frame=frame.replace(marker,code+marker)
frame+='\tgame.profile_sections["presentation"]=(Time.get_ticks_usec()-profile_mark)/1000.0\n'
(QA/'p137_frame.gd').write_text(frame,'utf-8')
presentation_source=read('scripts/presentation/game_presentation.gd')
presentation=body(presentation_source,'tick')
presentation=presentation.replace('func tick(delta: float) -> void:\n','func tick(delta: float) -> void:\n\tprofile_times.clear()\n\tvar profile_mark:=Time.get_ticks_usec()\n')
for marker,label in [('\tif dog_visual:','actor_visuals'),('\t_tick_scene()','dog_visual'),('\tif game.items_view:','scenery_visibility'),('\tif lighting:','items_visual'),('\tif interaction:','lighting'),('\tvar now := _state()','interaction_prompt')]:
    assert presentation.count(marker)==1,marker
    presentation=presentation.replace(marker,checkpoint(label)+marker)
presentation+=checkpoint('audio_state')
(QA/'p137_presentation.gd').write_text('extends "res://scripts/presentation/game_presentation.gd"\nvar profile_times: Dictionary={}\n'+presentation,'utf-8')
bootstrap=read('scripts/core/game_bootstrap.gd').replace('game.presentation = game.Presentation.new()','game.presentation = preload("res://qa/p137_presentation.gd").new()')
(QA/'p137_bootstrap.gd').write_text(bootstrap,'utf-8')
(QA/'p137_profile_game.gd').write_text('extends "res://scripts/core/escape_game.gd"\nvar profile_sections: Dictionary={}\nfunc _ready() -> void:\n\tpreload("res://qa/p137_bootstrap.gd").configure(self)\nfunc _process(delta: float) -> void:\n\tpreload("res://qa/p137_frame.gd").tick(self,delta)\n','utf-8')
paths=['scripts/core/game_frame.gd','scripts/presentation/game_presentation.gd','scripts/core/game_bootstrap.gd']
(OUT/'source-snapshot.json').write_text(json.dumps({p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},indent=2)+'\n','utf-8')
print('QA instrumentation created from current production sources.')
