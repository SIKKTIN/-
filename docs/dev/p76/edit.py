from pathlib import Path
import json,subprocess

OPS=Path('docs/dev/p76/edits.json')
def edit(p,old,new):
    done=json.loads(OPS.read_text(encoding='utf-8')) if OPS.exists() else []
    if [p,old,new] in done: return
    path=Path(p); s=path.read_text(encoding='utf-8-sig'); assert old in s,(p,old)
    baseline=Path('docs/dev/p76/baseline')/p
    if not baseline.exists():
        baseline.parent.mkdir(parents=True,exist_ok=True); baseline.write_bytes(path.read_bytes())
    path.write_bytes(s.replace(old,new).encode())
    ops=json.loads(OPS.read_text(encoding='utf-8')) if OPS.exists() else []
    ops.append([p,old,new]); OPS.write_bytes(json.dumps(ops,ensure_ascii=False,indent=2).encode())
