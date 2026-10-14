"""Generate timing-only QA subclasses from current code, avoiding stale copies."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[2]
dest=Path(__file__).parent
paths=['scripts/core/game_frame.gd','scripts/core/game_bootstrap.gd','scripts/presentation/game_presentation.gd']
hashes={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths}
def instrument(source, target):
    result=[]; previous=None
    for line in source.splitlines():
        if line.startswith('\t') and not line.startswith('\t\t') and line.strip() and not line.strip().startswith(('#','elif','else')):
            if previous is None:
                result += ['\tvar qa_stamp: int=Time.get_ticks_usec()',f'\t{target}.clear()']
            else:
                result += [f'\t{target}[{json.dumps(previous)}]=(Time.get_ticks_usec()-qa_stamp)/1000.0','\tqa_stamp=Time.get_ticks_usec()']
            previous=line.strip()[:110]
        result.append(line)
    result += [f'\t{target}[{json.dumps(previous)}]=(Time.get_ticks_usec()-qa_stamp)/1000.0']
    return '\n'.join(result)+'\n'
frame=(root/paths[0]).read_text(encoding='utf-8')
(dest/'frame.gd').write_text(instrument(frame,'game.profile_sections'),encoding='utf-8')
pres=(root/paths[2]).read_text(encoding='utf-8')
tick=pres[pres.index('func tick(delta:'):pres.index('\nfunc _loop(')]
(dest/'presentation.gd').write_text('extends "res://scripts/presentation/game_presentation.gd"\nvar profile_times: Dictionary={}\n'+instrument(tick,'profile_times'),encoding='utf-8')
bootstrap=(root/paths[1]).read_text(encoding='utf-8').replace('game.Presentation.new()','preload("res://qa/android_performance_20261014/presentation.gd").new()')
(dest/'bootstrap.gd').write_text(bootstrap,encoding='utf-8')
(dest/'source-hashes.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
