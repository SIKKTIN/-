from pathlib import Path
p=Path('E:/Project/Godot/这次怎么逃/docs/art/architecture-v25/register-corner.py')
lines=p.read_text(encoding='utf-8').splitlines()
lines=["asset=json.loads((doc/'corner-interface.json').read_text(encoding='utf-8'))['asset']" if s.startswith('asset=json.loads(') else s for s in lines]
p.write_text('\n'.join(lines)+'\n',encoding='utf-8')
p=Path('E:/Project/Godot/这次怎么逃/docs/art/architecture-v25/connection-review-draft.md')
p.write_text(p.read_text(encoding='utf-8').replace('九块Atlas','十二块Atlas').replace('九块配准','十二块配准'),encoding='utf-8')