import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[3]
out=root/'docs/dev/p137'
def read(path):return json.loads((root/path).read_text('utf-8-sig'))
def stdout_report(path):
    for line in reversed((root/path).read_text('utf-8-sig').splitlines()):
        if line.startswith('{'):
            return json.loads(line)
    raise ValueError(path)
reports={}
for label,file in [('structure','structure'),('npc','npc'),('staff','staff'),('legacy','legacy'),('quick','quick'),('editor','editor-checks'),('looting_native','looting-check'),('tutorial','tutorial-headless')]:
    reports[label]=read('docs/dev/p137/validation/'+file+'.json')
for label in ['player','chase']:
    reports[label]=stdout_report('docs/dev/p137/validation/'+label+'.out')
for label,file in [('navigation','navigation-check'),('dynamic_navigation','dynamic-navigation'),('day_render','render-check'),('night_render','night-render-check'),('seven_day_state','seven-days')]:
    reports[label]=read('docs/dev/p137/'+file+'.json')
summary={}
for label,report in reports.items():
    checks=report.get('checks',{})
    summary[label]={'checks':len(checks) or report.get('total',0),'failed':report.get('failed',[k for k,v in checks.items() if not v])}
for label in ['structure','npc','staff','legacy','quick','editor','looting_native','tutorial','player','chase','navigation','dynamic_navigation','day_render','night_render','seven_day_state']:
    assert not summary[label]['failed'],(label,summary[label])
if (out/'full-day-final.json').exists():
    report=read('docs/dev/p137/full-day-final.json')
    summary['final_normal_day']={'checks':len(report['checks']),'failed':report['failed']}
if (out/'seven-days-final.json').exists():
    report=read('docs/dev/p137/seven-days-final.json')
    summary['seven_day_state']={'checks':len(report['checks']),'failed':report['failed'],'source':'seven-days-final.json'}
paths=['scripts/world/world_navigation.gd','scripts/world/navigation_connectivity.gd','scripts/world/prison_world.gd','scripts/core/prison_schedule.gd','scripts/core/game_frame.gd','scripts/presentation/asset_dependencies.gd','scripts/presentation/game_presentation.gd','scripts/presentation/region_terrain.gd','scripts/presentation/static_ground.gd','scripts/presentation/soft_shadow.gd','scripts/editor/map_canvas.gd','scripts/editor/architecture_preview.gd','data/rooms/r04.json']
hashes={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths}
(out/'final-source-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n','utf-8')
result={'categories':summary,'total_checks':sum(v['checks'] for v in summary.values()),'initial_runner':'validation/results.json','reruns':{'looting':'looting-native.out / validation/looting-check.json','tutorial':'tutorial-final.out / validation/tutorial-headless.json'},'compiled_production_scripts':reports['structure']['compiled_script_count'],'catalog_entries':reports['structure']['asset_count']}
(out/'final-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n','utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
