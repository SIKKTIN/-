"""Register original generated PNGs using metadata; never edit image pixels."""
from pathlib import Path
from PIL import Image
import json,hashlib
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
folder=root/'art/props/cafeteria_v41'
assets=[]
for ident,name,file,width,depth,blocking,subcategory in [
    ('cafeteria_table_v41','食堂餐桌 · 斜俯视','communal_table_v41.png',210,105,True,'furnishings'),
    ('cafeteria_tray_v41','就餐餐盘 · 斜俯视','food_tray_v41.png',60,None,False,'tableware')]:
    p=folder/file; im=Image.open(p)
    l,t,r,b=im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    l=max(0,l-2);t=max(0,t-2);r=min(im.width,r+2);b=min(im.height,b+2)
    w,h=r-l,b-t;k=width/w
    if depth is None:depth=h*k
    assets.append(dict(id=ident,name=name,texture='res://art/props/cafeteria_v41/'+file,
        texture_size=list(im.size),region=[l,t,w,h],ground_rect=[0,h-depth/k,w,depth/k],
        footprint_world_size=[width,depth],world_size=[width,h*k],render_size=[width,h*k],
        elevation_world=h*k-depth,render_mode='projected_prop',blocking=blocking,interactive=False,
        shadow_baked=False,authoring_set='cafeteria-v41',editor_subcategory=subcategory,
        alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
        editor_icon=f'res://art/editor/v19/icons/{ident}.tres',source_kind='built-in-imagegen-original-png',
        sha256=hashlib.sha256(p.read_bytes()).hexdigest(),
        registration_note='Uniform native source scaling; PNG pixels untouched. Tray independent of table.'))
(folder/'manifest.json').write_text(json.dumps(dict(schema=2,version='cafeteria-tables-v41',assets=assets),ensure_ascii=False,indent=2)+'\n','utf-8')
(root/'art/editor/v19/manifest.json').write_text(json.dumps(dict(schema=1,assets=[dict(id=a['id'],name=a['name'],editor_icon=a['editor_icon'],category='cafeteria') for a in assets],tools=[]),ensure_ascii=False,indent=2)+'\n','utf-8')
catalog=root/'scripts/presentation/prop_catalog.gd';s=catalog.read_text('utf-8')
if 'res://art/props/cafeteria_v41/manifest.json' not in s:
    s=s.replace('"res://art/props/cafeteria_v40/manifest.json"]:', '"res://art/props/cafeteria_v40/manifest.json","res://art/props/cafeteria_v41/manifest.json"]:')
    assert 'res://art/props/cafeteria_v41/manifest.json' in s
    catalog.write_text(s,'utf-8')
catalog=root/'scripts/editor/editor_catalog.gd';s=catalog.read_text('utf-8')
if 'res://art/editor/v19/manifest.json' not in s:
    s=s.replace('"res://art/editor/v18/manifest.json"]:', '"res://art/editor/v18/manifest.json","res://art/editor/v19/manifest.json"]:')
    assert 'res://art/editor/v19/manifest.json' in s
    catalog.write_text(s,'utf-8')
path=root/'data/rooms/r04.json';backup=out/'r04-before-tables.json'
if not backup.exists():backup.write_bytes(path.read_bytes())
d=json.loads(path.read_bytes());before=json.loads(backup.read_bytes())
table, tray=assets
allowed=set()
for i in range(4):
    f=next(f for f in d['fixtures'] if f['id']==f'dine-table-{i}')
    f['asset_id']=table['id'];f.pop('render_size',None)
    t=next(f for f in d['fixtures'] if f['id']==f'dine-tray-{i}')
    # Native table top center source y425; derive tabletop height without deforming sprite.
    scale=f['rect'][2]/table['region'][2]
    display_top=f['rect'][1]+f['rect'][3]-table['region'][3]*scale
    top_center=display_top+(425-table['region'][1])*scale
    t['asset_id']=tray['id'];t.pop('render_size',None)
    t['rect']=[f['rect'][0]+(f['rect'][2]-tray['world_size'][0])/2,top_center-tray['world_size'][1]/2,tray['world_size'][0],tray['world_size'][1]]
    t['draw_depth']=f['rect'][1]+f['rect'][3]+1
    allowed.update([f['id'],t['id']])
assert {k:v for k,v in d.items() if k!='fixtures'}=={k:v for k,v in before.items() if k!='fixtures'}
assert [f for f in d['fixtures'] if f['id'] not in allowed]==[f for f in before['fixtures'] if f['id'] not in allowed]
assert [f['rect'] for f in d['fixtures'] if f['id'].startswith('dine-table-')]==[f['rect'] for f in before['fixtures'] if f['id'].startswith('dine-table-')]
path.write_text(json.dumps(d,ensure_ascii=False,indent='\t')+'\n','utf-8')
(out/'integration.json').write_text(json.dumps(dict(changed_fixtures=[f for f in d['fixtures'] if f['id'] in allowed],architecture_unchanged=True,collision_unchanged=True,routines_unchanged=True,scope='Four R04 dining tables and four independent trays; kitchen and other tables retained.'),ensure_ascii=False,indent=2)+'\n','utf-8')
print(json.dumps([dict(id=a['id'],region=a['region'],world_size=a['world_size']) for a in assets]))
