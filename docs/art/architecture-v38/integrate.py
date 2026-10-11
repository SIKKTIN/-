from pathlib import Path
import copy, json
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
p=root/'scripts/editor/editor_catalog.gd'
s=p.read_text('utf-8').replace('"res://art/editor/v15/manifest.json",CURRENT_EDITOR_MANIFEST', '"res://art/editor/v15/manifest.json",CURRENT_EDITOR_MANIFEST,"res://art/editor/v17/manifest.json"')
p.write_text(s,'utf-8')
path=root/'data/rooms/r04.json'
backup=out/'r04-before-continuous-corners.json'
if not backup.exists():backup.write_bytes(path.read_bytes())
before=json.loads(backup.read_bytes())
d=json.loads(path.read_bytes())
assets=json.loads((root/'art/architecture/v38/manifest.json').read_text('utf-8'))['assets']
defs={a['id']:a for a in assets}
remove=[]
surfaces=d['architecture']['wall_surfaces']
for corner in list(surfaces):
    ident=corner.get('grid_tile_asset','')
    if ident not in ['prison_l_ne','prison_l_nw']:continue
    wall=d['walls'][corner['wall_index']]
    if wall[3]==140:continue
    sx=wall[0]+defs[ident]['grid_tile']['stem_x']
    short=next(s for s in surfaces if s.get('grid_tile_asset')=='prison_v_short' and d['walls'][s['wall_index']]==[sx,wall[1]-20,20,20])
    remove.append(short['wall_index'])
    wall[1]-=20;wall[3]+=20
    corner['collision_parts']=defs[ident]['collision_parts']
for index in sorted(remove,reverse=True):
    d['walls'].pop(index)
    surfaces[:]=[s for s in surfaces if s['wall_index']!=index]
    for s in surfaces:
        if s['wall_index']>index:s['wall_index']-=1
# Compare exact occupied 20-unit collision cells, not just asset dimensions.
def cells(data):
    result=set()
    for s in data['architecture']['wall_surfaces']:
        w=data['walls'][s['wall_index']]
        for x,y,width,height in s['collision_parts']:
            for cx in range(int(w[0]+x),int(w[0]+x+width),20):
                for cy in range(int(w[1]+y),int(w[1]+y+height),20):result.add((cx,cy))
    return result
assert cells(d)==cells(before),'Collision union changed'
assert d['fixtures']==before['fixtures'] and d['access_doors']==before['access_doors']
path.write_text(json.dumps(d,ensure_ascii=False,indent='\t')+'\n','utf-8')
(out/'integration.json').write_text(json.dumps(dict(merged_vertical_cells=remove,collision_cells_unchanged=True,collision_cell_count=len(cells(d)),corner_rects=[dict(asset=s['grid_tile_asset'],rect=d['walls'][s['wall_index']]) for s in surfaces if s.get('grid_tile_asset','').startswith('prison_l_')]),indent=2)+'\n','utf-8')
print('Lower arcs use 2x7 cells, including the preceding vertical cell; collision union unchanged.')
