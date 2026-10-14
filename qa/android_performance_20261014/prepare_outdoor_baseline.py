"""Replay the current bath test with pre-change HUD/dialogue/interaction/bath code."""
from pathlib import Path
root=Path(__file__).resolve().parents[2]
qa=Path(__file__).parent
before='res://docs/performance/android-frame-investigation-20261014/outdoor-baseline/'
presentation=(root/'scripts/presentation/game_presentation.gd').read_text(encoding='utf8').replace('res://scripts/presentation/interaction_prompt.gd',before+'interaction_prompt.gd')
(qa/'outdoor_before_presentation.gd').write_text(presentation,encoding='utf8')
bootstrap=(root/'scripts/core/game_bootstrap.gd').read_text(encoding='utf8')
for a,b in [('game.Presentation.new()','preload("res://qa/android_performance_20261014/outdoor_before_presentation.gd").new()'),('game.FullscreenHUD.new()',f'preload("{before}fullscreen_hud.gd").new()'),('game.NpcDialogue.new()',f'preload("{before}npc_dialogue.gd").new()'),('res://scripts/items/bath_service.gd',before+'bath_service.gd')]:
    bootstrap=bootstrap.replace(a,b)
(qa/'outdoor_before_bootstrap.gd').write_text(bootstrap,encoding='utf8')
(qa/'outdoor_before_game.gd').write_text('extends "res://scripts/core/escape_game.gd"\nfunc _init():room_id="r04"\nfunc _ready():preload("res://qa/android_performance_20261014/outdoor_before_bootstrap.gd").configure(self)\n',encoding='utf8')
test=(root/'qa/bath_watercard.gd').read_text(encoding='utf8').replace('load("res://scenes/main.tscn").instantiate()','load("res://qa/android_performance_20261014/outdoor_before_game.gd").new()')
test=test.replace('save_png(OUT+', 'save_png(REPORT+').replace('FileAccess.open(OUT+"checks.json"', 'FileAccess.open(REPORT+"checks.json"')
test=test.replace('const OUT=', 'const REPORT="res://docs/performance/android-frame-investigation-20261014/outdoor-bath-baseline/"\nconst OUT=')
(root/'docs/performance/android-frame-investigation-20261014/outdoor-bath-baseline').mkdir(exist_ok=True)
(qa/'outdoor_before_bath_test.gd').write_text(test,encoding='utf8')
