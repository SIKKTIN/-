"""Register original cafeteria sprites and apply the approved layout to the latest saved R04 only."""
from copy import deepcopy
from pathlib import Path
import hashlib,json,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/cafeteria-redesign-v1'
ART=ROOT/'art/architecture/cafeteria_v1'
MANIFEST='res://art/architecture/cafeteria_v1/manifest.json'
SHADER='res://art/architecture/v25/safe_edges_v25.gdshader'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    generated=read(DOC/'production-assets.json'); originals={};records=[]
    for entry in generated['assets']:
        dest=ROOT/entry['path'];dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(entry['source'],dest)
        assert sha(dest)==sha(Path(entry['source']))
        im=Image.open(dest)
        a=dict(texture='res://'+entry['path'],texture_size=list(im.size),sha256=sha(dest),source_kind='built-in-imagegen-original-png')
        if entry['transparent']:
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
            x,y,r,b=im.getchannel('A').point(lambda v:255 if v>=180 else 0).getbbox()
            a['region']=[x,y,r-x,b-y]
        else:a['opaque']=True
        originals[entry['key']]=a
        records.append(dict(key=entry['key'],path=entry['path'],sha256=sha(dest),size=list(im.size)))
    assets=[]
    wall=originals['wall']
    rx,ry,rw,rh=wall['region']
    # A 320-world-unit repeat samples an equally proportioned slice; never
    # squeeze the entire wide source strip into a short section.
    wall['region']=[rx,ry,min(rw,round(rh*320/120)),rh]
    nr=wall['region']
    templates={a['id']:a for a in read(ROOT/'art/architecture/clinic_v1/manifest.json')['assets']}
    old=templates['clinic_wall_h_00']['region']
    for id,t in templates.items():
        if not t.get('grid_tile') or not id.startswith(('clinic_wall_','clinic_corner_','clinic_lintel_')):continue
        a=deepcopy(t);a.update(deepcopy(wall))
        a.update(id=id.replace('clinic_','cafeteria_',1),name=t['name'].replace('医务室','食堂'),authoring_set='cafeteria-v1',connection_tag=t['connection_tag'].replace('clinic/','cafeteria/'))
        for part in a['assembly_patches']:
            x,y,w,h=part['source']
            part['source']=[nr[0]+(x-old[0])/old[2]*nr[2],nr[1]+(y-old[1])/old[3]*nr[3],w/old[2]*nr[2],h/old[3]*nr[3]]
            if h<=98:
                part['source'][1]=nr[1]+2
                part['source'][3]=max(1,rh*.095)
        assets.append(a)
    defs={a['id']:a for a in assets}
    t=deepcopy(defs['cafeteria_corner_nw'])
    t.update(id='cafeteria_junction_e',name='食堂三向连接 · 向右分叉',connections=['north','south','east'],connection_tag='cafeteria/east,north,south/40x120',editor_subcategory='tiles_junction')
    cap=deepcopy(defs['cafeteria_wall_v_long']['assembly_patches'][0])
    cap['destination']=[0,0,20,120]
    t['assembly_patches']=[t['assembly_patches'][0],cap]
    t['collision_parts']=[[0,100,40,20],[0,0,20,120]]
    assets.append(t)
    junction=deepcopy(defs['cafeteria_wall_h_00'])
    junction.update(id='cafeteria_junction_s',name='食堂三向连接 · 向下分叉',world_size=[60,120],render_size=[60,120],connections=['west','east','south'],connection_tag='cafeteria/east,south,west/60x120',editor_subcategory='tiles_junction',grid_tile={'cell':20,'columns':3,'rows':6,'parameterized_shader':False},collision_parts=[[0,100,60,20]])
    junction['assembly_patches'][0]['destination']=[0,0,60,120]
    junction['assembly_patches'][0]['source'][2]*=1.5
    stem=deepcopy(cap);stem['destination']=[20,100,20,20]
    stem['source'][2]/=6
    junction['assembly_patches'].append(stem);assets.append(junction)
    def prop(key,id,name,width,depth,blocking=True,subcategory='furnishings'):
        a=deepcopy(originals[key]);_,_,w,h=a['region'];scale=width/w
        assert 0<depth<=h*scale,(key,depth,h*scale)
        a.update(id=id,name=name,world_size=[width,h*scale],render_size=[width,h*scale],ground_rect=[0,h-depth/scale,w,depth/scale],footprint_world_size=[width,depth],elevation_world=h*scale-depth,render_mode='projected_prop',blocking=blocking,interactive=False,proportion_locked=True,shadow_baked=False,alpha_core_shader=SHADER,editor_subcategory=subcategory,authoring_set='cafeteria-v1')
        assets.append(a);return a
    table=prop('table','cafeteria_table_vertical_v1','食堂纵向长桌与双侧长凳',140,210)
    prop('backline','cafeteria_backline_v1','食堂连续后厨设备',830,64,subcategory='serving')
    counter=prop('counter','cafeteria_counter_v1','食堂空配餐台',720,35,subcategory='serving')
    food=prop('food','cafeteria_service_food_v1','食堂朴素配餐盆与汤锅',500,20,False,'tableware')
    prop('water','cafeteria_water_urn_v1','食堂饮水桶与杯架',48,36,subcategory='serving')
    cup=deepcopy(next(a for a in read(ROOT/'art/props/duty_room_v1/manifest.json')['assets'] if a['id']=='duty_mug_v1'))
    cup.update(id='cafeteria_enamel_cup_v1',name='食堂搪瓷杯',editor_subcategory='tableware',authoring_set='cafeteria-v1');assets.append(cup)
    returned=deepcopy(next(a for a in read(ROOT/'art/props/prison_v42/manifest.json')['assets'] if a['id']=='cafeteria_return_v42'))
    scale=70/returned['footprint_world_size'][0]
    for key in ['world_size','render_size','footprint_world_size']:returned[key]=[v*scale for v in returned[key]]
    returned['elevation_world']*=scale
    returned.update(id='cafeteria_return_v1',name='食堂紧凑餐盘回收架',proportion_locked=True,authoring_set='cafeteria-v1')
    returned.pop('editor_icon',None);assets.append(returned)
    for oldid,newid,name in [('clinic_frosted_window','cafeteria_window_v1','食堂高位窗'),('clinic_wall_light','cafeteria_light_v1','食堂壁灯')]:
        a=deepcopy(templates[oldid]);a.update(id=newid,name=name,authoring_set='cafeteria-v1');assets.append(a)
    for key,id,name in [('floor','cafeteria_floor_v1','食堂暖灰防滑砖'),('roof','cafeteria_roof_surface','食堂暗灰金属屋面')]:
        a=deepcopy(originals[key]);a.update(id=id,name=name,world_size=[240,240] if key=='floor' else [320,320],render_mode='architecture_material',blocking=False,authoring_set='cafeteria-v1');assets.append(a)
    write(ART/'manifest.json',dict(schema=2,version='cafeteria-v1',assets=assets))
    defs={a['id']:a for a in assets}
    path=ROOT/'data/rooms/r04.json';before=path.read_bytes();before_hash=sha(path);m=read(path)
    area=next(r['rect'] for r in m['visibility_rooms'] if r['id']=='canteen')
    assert area==[820,2520,1360,560],'Saved room dimensions changed; revise on latest map.'
    selected=[]
    for s in m['architecture']['wall_surfaces']:
        i=int(s['wall_index']);x,y,w,h=m['walls'][i]
        boundary=((y in [2400,3000] and 800<=x<2200 and x+w<=2200) or (x in [800,2180] and 2520<=y<3000 and y+h<=3000))
        if not boundary:continue
        base=s.get('grid_tile_asset','')
        if base.startswith('cafeteria_'):continue
        if base.startswith('prison_h_short'):new='cafeteria_wall_h_short'
        elif base.startswith('prison_h_'):new=f'cafeteria_wall_h_{int((x-800)%320/20):02d}'
        elif base=='prison_v_long':new='cafeteria_wall_v_long'
        elif base=='prison_v_short':new='cafeteria_wall_v_short'
        elif base=='prison_t_e':new='cafeteria_junction_e'
        elif base=='prison_t_s':new='cafeteria_junction_s'
        elif base.startswith('prison_lintel_'):new=base.replace('prison_','cafeteria_',1)
        else:raise ValueError((i,base))
        assert new in defs
        selected.append(i);s['grid_tile_asset']=new
    # Keep all wall geometry and actual gate IDs/positions/states intact.
    changed={'canteen-counter','canteen-kitchen-collision','canteen-queue','canteen-return','detail44-canteen-cart','detail44-canteen-linen'}
    changed.update(f['id'] for f in m['fixtures'] if str(f['id']).startswith(('dine-table-','dine-tray-','canteen-redesign-')))
    changed.add('detail44-planter-3')
    oldfixtures={f['id']:deepcopy(f) for f in m['fixtures'] if f['id'] in changed}
    m['fixtures']=[f for f in m['fixtures'] if f['id'] not in changed]
    def place(id,asset,x,y,depth=None,**extra):
        a=defs.get(asset)
        if depth is None:
            assert a
            dims=a['footprint_world_size']
        else:dims=depth
        f=dict(id=id,asset_id=asset,rect=[x,y,*dims],blocks_movement=bool(a.get('blocking',False)) if a else True,blocks_sight=False)
        f.update(extra);m['fixtures'].append(f);return f
    place('canteen-kitchen-collision','cafeteria_backline_v1',1170,2520,blocks_sight=True,name='食堂连续后厨设备')
    front=place('canteen-counter','cafeteria_counter_v1',1220,2638,blocks_sight=True,name='食堂取餐台')
    # Counter items are real independent props at its measured top surface,
    # with painter depth above desk, not furniture merged into a backdrop.
    food_y=front['rect'][1]+front['rect'][3]-counter['world_size'][1]+29
    place('canteen-redesign-service-food','cafeteria_service_food_v1',1320,food_y,draw_depth=front['rect'][1]+front['rect'][3]+1,blocks_movement=False)
    place('canteen-redesign-water','cafeteria_water_urn_v1',850,2538)
    oldreturn=oldfixtures.get('canteen-return',{})
    place('canteen-return','cafeteria_return_v1',2100,2880,blocks_movement=True,name='餐盘回收架')
    planter=oldfixtures.get('detail44-planter-3')
    if planter:
        planter['rect']=[850,2924,58,50.75];m['fixtures'].append(planter)
    for i in range(5):
        tx=920+245*i;ty=2730
        desk=place(f'dine-table-{i}','cafeteria_table_vertical_v1',tx,ty)
        display_top=ty+table['footprint_world_size'][1]-table['world_size'][1]
        place(f'dine-tray-{i}','cafeteria_tray_v41',tx+49,display_top+112,[42,17.1214],blocks_movement=False,draw_depth=desk['rect'][1]+desk['rect'][3]+8)
        place(f'canteen-redesign-cup-{i}','cafeteria_enamel_cup_v1',tx+64,display_top+78,blocks_movement=False,draw_depth=desk['rect'][1]+desk['rect'][3]+11)
    for i,tx in enumerate([1220,1740]):
        place(f'canteen-redesign-window-{i}','cafeteria_window_v1',tx,2430,blocks_movement=False,draw_depth=2532)
    place('canteen-redesign-wall-light','cafeteria_light_v1',1515,2430,blocks_movement=False,draw_depth=2533)
    floor=next(f for f in m['floor_regions'] if f['id']=='canteen')
    floor.update(asset_id='cafeteria_floor_v1',manifest=MANIFEST,tile_size=[240,240])
    r=next(r for r in m['visibility_rooms'] if r['id']=='canteen');r['roof_style']='cafeteria'
    next(r for r in m['zones'] if r['id']=='canteen')['hide_label']=True
    m['cafeteria'].update(hide_discipline_sign=True,pickup_label=[1200,2700],return_label=[2045,2870],wall_sign=[1505,2443,110,38],discipline_sign=[852,2810,104,64])
    m['routine_points']['meal']=[[1350,2710],[1590,2710],[1840,2710],[1440,2710],[1760,2710]]
    # One accessible standing seat per table; the first three are used by
    # the current party, all five remain authorable in the editor.
    m['routine_points']['dine']=[[895+245*i,2890] for i in range(5)]
    m['resident_staff']=[s for s in m.get('resident_staff',[]) if s['id']!='canteen-cook']
    m['resident_staff'].append(dict(id='canteen-cook',name='食堂师傅',appearance_id='canteen_cook',position=[1900,2608],patrol=[],speed=0,wait_seconds=7,work_start=660,work_end=840,room_id='canteen',service_role='meal'))
    # Remove just the former kitchen drains, retain all other map decoration.
    m['ground_details']=[d for d in m.get('ground_details',[]) if not (d.get('kind')=='drain' and d.get('rect') in [[1508.34,2609.6,125.15,10.08],[1883.8,2609.6,104.29,10.08]])]
    for lamp in m.get('lamps',[]):
        lx,ly=lamp['position']
        if 820<=lx<=2180 and 2520<=ly<=3000:lamp['draw_fixture']=False
    m['cafeteria_restoration_version']=1
    assert sha(path)==before_hash,'Map changed during registration; retry against latest saved data.'
    (DOC/'registration-input.json').write_bytes(before);write(path,m);write(DOC/'registration-output.json',m)
    write(DOC/'asset-registration.json',dict(mode=generated['mode'],assets=records,definition_ids=list(defs),wall_indices=selected,changed_fixture_ids=sorted(changed),map_before_sha256=before_hash,map_after_sha256=sha(path),area=area))
    print(f'Registered {len(assets)} assets; {len(selected)} wall faces; five vertical tables; original gates retained.')
if __name__=='__main__':main()
