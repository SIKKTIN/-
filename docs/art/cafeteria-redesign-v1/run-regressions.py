from pathlib import Path
import json,subprocess
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent/'regression'
OUT.mkdir(exist_ok=True)
wanted=['editor','render_cache','head_layer','player','interaction_hint','bath_watercard','legacy_maps']
suite=json.loads((ROOT/'qa/regression_suite.json').read_text(encoding='utf-8'))['checks']
results=[]
for id in wanted:
    t=next(t for t in suite if t['id']==id)
    with (OUT/(id+'.log')).open('w',encoding='utf-8') as log:
        try:
            process=subprocess.run(['E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe','--headless','--path',str(ROOT),'--script',t['script']],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=max(120,t.get('timeout',90)))
            code=process.returncode
        except subprocess.TimeoutExpired:code=124
    path=ROOT/t['report']
    report=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}
    checks=report.get('checks',{})
    failed=report.get('failed',[]) if isinstance(report,dict) else []
    if not failed and isinstance(checks,dict):failed=[k for k,v in checks.items() if v is False]
    item=dict(id=id,exit_code=code,checks=len(checks) if isinstance(checks,dict) else checks,failed=failed)
    results.append(item)
    (OUT/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(item),flush=True)
raise SystemExit(0 if all(r['exit_code']==0 and not r['failed'] for r in results) else 1)
