"""Native source registration, independent palette entries and R04 migration."""
from pathlib import Path
from PIL import Image
import json,hashlib
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
assets=[]
specs=[
 ('cafeteria_counter_v42','食堂取餐台 · 斜俯视',600,20,'cafeteria','serving'),
 ('cafeteria_backline_v42','食堂后排设备 · 斜俯视',580,60,'cafeteria','serving'),
 ('cafeteria_return_v42','餐盘回收架 · 斜俯视',110,70,'cafeteria','serving'),
 ('workbench_v42','工作台 · 斜俯视',180,70,'furniture','furnishings'),
 ('tool_locker_v42','工具柜 · 斜俯视',90,40,'furniture','furnishings'),
 ('laundry_cart_v42','洗衣推车 · 斜俯视',68,48,'furniture','furnishings'),
 ('wash_basin_v42','双位洗手池 · 斜俯视',160,67.2,'furniture','furnishings'),
 ('bunk_bed_v42','双层床 · 斜俯视',110,150,'furniture','furnishings'),
 ('toilet_sink_v42','马桶洗手池 · 斜俯视',50,55,'furniture','furnishings'),
 ('communal_table_v42','活动餐桌 · 斜俯视',190,100,'furniture','furnishings')]
palette=[]
for ident,name,width,depth,category,subcategory in specs:
    relative='art/props/prison_v42/'+ident+'.png'
    if ident=='communal_table_v42':relative='art/props/cafeteria_v41/communal_table_v41.png'
    p=root/relative;im=Image.open(p)
    l,t,r,b=im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    l=max(0,l-2);t=max(0,t-2);r=min(im.width,r+2);b=min(im.height,b+2)
    w,h=r-l,b-t;k=width/w
    a=dict(id=ident,name=name,texture='res://'+relative,texture_size=list(im.size),region=[l,t,w,h],
        ground_rect=[0,h-depth/k,w,depth/k],footprint_world_size=[width,depth],
        world_size=[width,h*k],render_size=[width,h*k],elevation_world=h*k-depth,
        render_mode='projected_prop',blocking=True,interactive=False,shadow_baked=False,
        authoring_set='prison-perspective-v42',editor_subcategory=subcategory,
        alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
        editor_icon=f'res://art/editor/v20/icons/{ident}.tres',source_kind='built-in-imagegen-original-png',
        sha256=hashlib.sha256(p.read_bytes()).hexdigest(),
        registration_note='Original source PNG untouched; uniform width-based sprite registration; logical footprints retained.')
    assets.append(a);palette.append(dict(id=ident,name=name,editor_icon=a['editor_icon'],category=category))
(root/'art/props/prison_v42/manifest.json').write_text(json.dumps(dict(schema=2,version='prison-perspective-v42',assets=assets),ensure_ascii=False,indent=2)+'\n','utf-8')
(root/'art/editor/v20/manifest.json').write_text(json.dumps(dict(schema=1,assets=palette,tools=[]),ensure_ascii=False,indent=2)+'\n','utf-8')
for file,old,new in [
 ('scripts/presentation/prop_catalog.gd','res://art/props/cafeteria_v41/manifest.json','res://art/props/prison_v42/manifest.json'),
 ('scripts/editor/editor_catalog.gd','res://art/editor/v19/manifest.json','res://art/editor/v20/manifest.json')]:
    p=root/file;s=p.read_text('utf-8')
    if new not in s:
        s=s.replace(f'"{old}"]:',f'"{old}","{new}"]:')
        assert new in s
        p.write_text(s,'utf-8')
mapping={
 'cafeteria_counter_front_v40':'cafeteria_counter_v42','cafeteria_backline_v40':'cafeteria_backline_v42',
 'cafeteria_return':'cafeteria_return_v42','communal_table':'communal_table_v42',
 'workbench':'workbench_v42','tool_locker':'tool_locker_v42','laundry_cart':'laundry_cart_v42',
 'wash_basin':'wash_basin_v42','bunk_bed':'bunk_bed_v42','toilet_sink':'toilet_sink_v42'}
definitions={a['id']:a for a in assets}
path=root/'data/rooms/r04.json';before=json.loads((out/'r04-before-props.json').read_bytes());d=json.loads(path.read_bytes())
working_before=json.loads(path.read_bytes())
changed=[]
for f in d['fixtures']:
    current=f['asset_id']
    if current not in mapping and current not in definitions:continue
    ident=mapping.get(current,current);a=definitions[ident];f['asset_id']=ident
    width=f['rect'][2]
    # Width fixes the entire sprite's scale even where old map depth ratios differ.
    f['render_size']=[width,width*a['region'][3]/a['region'][2]]
    if f['id']=='canteen-counter':f['name']='食堂取餐台'
    if f['id']=='canteen-kitchen-collision':f['name']='食堂靠墙设备'
    changed.append(f['id'])
assert {k:v for k,v in d.items() if k!='fixtures'}=={k:v for k,v in working_before.items() if k!='fixtures'}
assert len(d['fixtures'])==len(working_before['fixtures'])
for f,g in zip(d['fixtures'],working_before['fixtures']):
    assert f['id']==g['id'] and f['rect']==g['rect']
    assert f['blocks_movement']==g['blocks_movement'] and f['blocks_sight']==g['blocks_sight']
    if f['id'] not in changed:assert f==g
path.write_text(json.dumps(d,ensure_ascii=False,indent='\t')+'\n','utf-8')
(out/'integration.json').write_text(json.dumps(dict(changed_fixture_ids=changed,mapping=mapping,
    unchanged=['architecture','all logical rectangles and collisions','routine points','doors','V41 dining sets and trays','wall attachments','queue barrier','crate','roof-hidden single beds'],
    assets=[dict(id=a['id'],region=a['region'],render_size=a['render_size']) for a in assets]),ensure_ascii=False,indent=2)+'\n','utf-8')
print(json.dumps(dict(asset_count=len(assets),changed_fixture_count=len(changed),render_sizes={a['id']:a['render_size'] for a in assets})))
