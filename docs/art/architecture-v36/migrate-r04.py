import json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[3];out=Path(__file__).resolve().parent
path=root/'data/rooms/r04.json';raw=path.read_bytes();data=json.loads(raw)
backup=out/'r04-before-universal.json'
if not backup.exists():backup.write_bytes(raw)
assets={a['id']:a for a in json.loads((root/'art/architecture/v36/manifest.json').read_text(encoding='utf-8'))['assets']}
pool=['prison_h_a']*3+['prison_h_b']*3+['prison_h_c']*3+['prison_h_d','prison_h_e']
shorts=['prison_h_short_a','prison_h_short_b','prison_h_short_c']
def variant(family,point,pool):
    s=f"{data['id']}/{family}/{round(point[0]/20)}/{round(point[1]/20)}"
    return pool[int(hashlib.sha256(s.encode()).hexdigest()[:8],16)%len(pool)]
converted=[]
for s in data.get('architecture',{}).get('wall_surfaces',[]):
    old=s.get('grid_tile_asset','');i=s['wall_index'];rect=data['walls'][i]
    ident=''
    if old=='wall_grid_h':ident=variant('horizontal',rect,sorted(pool))
    elif old=='wall_grid_h_short':ident=variant('horizontal_short',rect,shorts)
    elif old=='wall_grid_t':ident='prison_t_s'
    elif old=='wall_grid_l_left':ident='prison_corner_ne' if s.get('grid_parameters',{}).get('north_stem') else 'prison_corner_se'
    elif old=='wall_grid_l_right':ident='prison_corner_nw' if s.get('grid_parameters',{}).get('north_stem') else 'prison_corner_sw'
    elif old=='wall_grid_v':ident='prison_v_long'
    elif old=='wall_grid_v_short':ident='prison_v_short'
    elif old=='wall_grid_end':ident='prison_end_s'
    elif old=='wall_grid_jamb':ident='prison_jamb'
    elif old=='wall_grid_lintel':ident='prison_lintel_80'
    elif old=='wall_grid_lintel_short':ident='prison_lintel_20'
    if not ident:continue
    assert rect[2:]==assets[ident]['render_size'],(old,ident,rect)
    s['grid_tile_asset']=ident;s.pop('grid_parameters',None)
    # Keep the already verified map collision rectangles: this is an art/library migration.
    converted.append({'index':i,'before':old,'after':ident})
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(out/'migration-report.json').write_text(json.dumps({'converted':converted,'count':len(converted),'current_map_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'baseline_sha256':hashlib.sha256(backup.read_bytes()).hexdigest(),'preserved':'wall geometry, collision parts, entrances, fixtures, gameplay rules','producer_feedback':'await human visual approval'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Converted independent wall tiles:',len(converted))
