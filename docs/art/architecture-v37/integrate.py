from pathlib import Path
import json
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
p=root/'scripts/editor/editor_catalog.gd'
s=p.read_text('utf-8')
s=s.replace('"res://art/editor/v13/manifest.json",CURRENT_EDITOR_MANIFEST', '"res://art/editor/v13/manifest.json","res://art/editor/v15/manifest.json",CURRENT_EDITOR_MANIFEST')
s=s.replace('"tiles_corner":"建筑瓦片 · 转角"', '"tiles_corner":"建筑瓦片 · L型 / 圆弧转角"')
p.write_text(s,'utf-8')
path=root/'data/rooms/r04.json'
before=path.read_bytes()
backup=out/'r04-before-l-gate.json'
if not backup.exists(): backup.write_bytes(before)
d=json.loads(before)
swaps=[]
for s in d['architecture']['wall_surfaces']:
    ident=s.get('grid_tile_asset','')
    if ident.startswith('prison_corner_'):
        s['grid_tile_asset']=ident.replace('prison_corner_', 'prison_l_')
        swaps.append(dict(wall_index=s['wall_index'],rect=d['walls'][s['wall_index']],asset=s['grid_tile_asset']))
f=next(f for f in d['fixtures'] if f['id']=='cafeteria-door-visual')
f.update(asset_id='prison_gate_closed_v37',closed_asset='prison_gate_closed_v37',open_asset='prison_gate_open_v37',render_size=[180,100])
f['rect']=[920,1240,180,20]
door=next(a for a in d['access_doors'] if a['id']=='cafeteria-entry')
door['rect']=f['rect'].copy()
d['cafeteria']['entrance']=f['rect'].copy()
path.write_text(json.dumps(d,ensure_ascii=False,indent='\t')+'\n','utf-8')
(out/'integration.json').write_text(json.dumps(dict(corners=swaps,gate_display=[920,1160,180,100],gate_footprint=f['rect']),ensure_ascii=False,indent=2)+'\n','utf-8')
print(json.dumps(dict(corners=len(swaps),gate_display=[920,1160,180,100])))
