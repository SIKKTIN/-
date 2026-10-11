"""Rebuild R04's cafeteria from independent 20-unit wall tiles, no bitmap edits."""
import copy, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def write(p, v): p.write_text(json.dumps(v, ensure_ascii=False, indent='\t')+'\n',encoding='utf-8')

manifest_path = ROOT/'art/architecture/v34/manifest.json'
manifest = read(manifest_path)
assets = {a['id']: a for a in manifest['assets']}
for base, ident, name, size, source in [
    ('wall_grid_h','wall_grid_h_short','横墙短块 · 1×6格',[20,120],[420,132,75,366]),
    ('wall_grid_v','wall_grid_v_short','纵墙短块 · 1×1格',[20,20],[712,382,114,48]),
    ('wall_grid_lintel','wall_grid_lintel_short','门楣短块 · 1×1格',[20,20],[400,132,58.5,84]),
]:
    a = copy.deepcopy(assets[base]); a.update(id=ident,name=name,world_size=size,render_size=size)
    a['assembly_patches']=[copy.deepcopy(a['assembly_patches'][0])]
    a['assembly_patches'][0].update(source=source,destination=[0,0,*size])
    a['grid_tile'].update(columns=size[0]//20, rows=size[1]//20)
    a['editor_icon']=f'res://art/editor/v14/icons/{ident}.tres'
    assets[ident]=a
for a in assets.values():
    w,h=a['render_size']
    a['collision_parts'] = [] if 'lintel' in a['id'] else [[0,h-20,w,20]] if a['id'] in ['wall_grid_h','wall_grid_h_short','wall_grid_t','wall_grid_l_left','wall_grid_l_right','wall_grid_jamb'] else [[0,0,w,h]]
manifest['assets']=list(assets.values());write(manifest_path,manifest)
paired_path=ROOT/'art/editor/v14/manifest.json'
paired=read(paired_path)
for ident in ['wall_grid_h_short','wall_grid_v_short','wall_grid_lintel_short']:
    if not any(x['id']==ident for x in paired['assets']):
        paired['assets'].append({'id':ident,'name':assets[ident]['name'],'editor_icon':assets[ident]['editor_icon'],'category':'furniture'})
write(paired_path,paired)

path=ROOT/'data/rooms/r04.json'
backup=OUT/'r04-before-grid-perimeter.json'
if not backup.exists(): backup.write_bytes(path.read_bytes())
original=read(backup); data=copy.deepcopy(original)
removed=set(range(7,14)); mapping={}
data['walls']=[]
for i,r in enumerate(original['walls']):
    if i not in removed: mapping[i]=len(data['walls']);data['walls'].append(r)
surfaces=[]
for s in original.get('architecture',{}).get('wall_surfaces',[]):
    if s['wall_index'] not in removed:
        s=copy.deepcopy(s);s['wall_index']=mapping[s['wall_index']];surfaces.append(s)
placed=[]
def tile(ident,x,y,bottom=False):
    a=assets[ident]; w,h=a['render_size']; i=len(data['walls'])
    data['walls'].append([x,y,w,h])
    s={'wall_index':i,'height':20,'grid_tile_asset':ident,'collision_parts':copy.deepcopy(a['collision_parts'])}
    if bottom:
        stem=0 if ident.endswith('left') else 20
        s['collision_parts'].append([stem,0,20,h]);s['grid_parameters']={'north_stem':True}
    surfaces.append(s);placed.append({'index':i,'asset':ident,'rect':[x,y,w,h]})
def horizontal(x,end,y):
    while x<end:
        ident='wall_grid_h' if end-x>=40 else 'wall_grid_h_short'
        tile(ident,x,y);x+=assets[ident]['render_size'][0]
def vertical(x,start,end):
    while start<end:
        ident='wall_grid_v' if end-start>=120 else 'wall_grid_v_short'
        tile(ident,x,start);start+=assets[ident]['render_size'][1]

tile('wall_grid_l_left',720,1140)
horizontal(760,900,1140);tile('wall_grid_jamb',900,1140)
tile('wall_grid_jamb',1100,1140);horizontal(1120,1260,1140)
tile('wall_grid_t',1260,1140);horizontal(1320,1880,1140)
tile('wall_grid_t',1880,1140);horizontal(1940,1980,1140)
tile('wall_grid_l_right',1980,1140)
for x in [920,1000]: tile('wall_grid_lintel',x,1140)
tile('wall_grid_lintel_short',1080,1140)
for x in [720,2000]: vertical(x,1260,2120)
tile('wall_grid_l_left',720,2120,bottom=True)
horizontal(760,1980,2120)
tile('wall_grid_l_right',1980,2120,bottom=True)
for x in [1280,1900]:
    tile('wall_grid_v',x,1260);tile('wall_grid_end',x,1380)
data['architecture']['wall_surfaces']=surfaces
for f in data['fixtures']:
    if f.get('id')=='cafeteria-reader': f['draw_depth']=1262
    if f.get('id')=='cafeteria-door-visual':
        f['rect']=[920,1240,180,20]
        for key in ['lintel_asset','lintel_height']:f.pop(key,None)
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
write(OUT/'perimeter-layout.json',{'grid':20,'count':len(placed),'tiles':placed,'old_outer_bounds':[720,1230,1304,1000],'new_visible_bounds':[720,1140,1300,1100],'original_backup':str(backup),'producer_feedback':'Await human visual approval'})
print(json.dumps({'tiles':len(placed),'walls_total':len(data['walls']),'path':str(path)},ensure_ascii=False))
