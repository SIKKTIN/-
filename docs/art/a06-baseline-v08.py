import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=root/'docs/art/a06-old-asset-baseline-v08.json'
if out.exists():raise RuntimeError('Baseline already recorded; do not recapture')
paths=[p for p in (root/'art').rglob('*')if p.is_file()and p.suffix.lower()in ['.png','.svg','.json']and 'prison_v08'not in p.parts]
rows=[{'path':p.relative_to(root).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}for p in sorted(paths)]
out.write_text(json.dumps({'scope':'all prior art PNG/SVG/JSON before A06 copy; excludes imports/generated directories','files':rows},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'recorded_old_files':len(rows)}))
