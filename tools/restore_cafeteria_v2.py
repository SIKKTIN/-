"""Restore approved cafeteria art at its saved location; preserve other buildings."""
from pathlib import Path
from copy import deepcopy
import json, hashlib
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs/art/cafeteria-redesign-v2'
ART = ROOT / 'art/architecture/cafeteria_v2'
MANIFEST = 'res://art/architecture/cafeteria_v2/manifest.json'
SHADER = 'res://art/architecture/v25/safe_edges_v25.gdshader'

def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p, v):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(v, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def register():
    original = read(ROOT/'art/architecture/cafeteria_v1/manifest.json')
    old = {a['id']: a for a in original['assets']}
    sources = {}
    records = []
    for spec in read(DOC/'production-assets.json')['assets']:
        p = ROOT/spec['path']
        assert sha(p) == sha(Path(spec['source']))
        im = Image.open(p)
        assert im.mode == 'RGBA' and im.getchannel('A').getextrema() == (0,255)
        x,y,r,b = im.getchannel('A').point(lambda v:255 if v>=180 else 0).getbbox()
        sources[spec['key']] = dict(texture='res://'+spec['path'], texture_size=list(im.size),
            region=[x,y,r-x,b-y], sha256=sha(p), source_kind='built-in-imagegen-original-png',
            alpha_core_shader=SHADER)
        records.append(dict(key=spec['key'], path=spec['path'], sha256=sha(p), size=list(im.size)))
    assets = []
    wall = deepcopy(sources['wall'])
    wall['region'][2] = round(wall['region'][3]*320/100)
    nr = wall['region']; previous = old['cafeteria_wall_h_00']['region']
    for id, template in old.items():
        if not template.get('grid_tile'): continue
        a = deepcopy(template)
        a.update(deepcopy(wall), id=id+'_v2', name=template['name']+' · 灰蓝瓷砖', authoring_set='cafeteria-v2')
        a['connection_tag'] = a['connection_tag'].replace('cafeteria/','cafeteria-v2/')
        a.pop('legacy_id',None)
        for patch in a.get('assembly_patches',[]):
            x,y,w,h = patch['source']
            patch['source'] = [nr[0]+(x-previous[0])/previous[2]*nr[2], nr[1]+(y-previous[1])/previous[3]*nr[3], w/previous[2]*nr[2], h/previous[3]*nr[3]]
        # Keep a full 100-high facade, including its 20-unit foot-line collider.
        if a['world_size'][1] in (120,140) and not id.startswith('cafeteria_wall_v_'):
            newheight = a['world_size'][1]-20
            a['world_size'][1]=newheight; a['render_size'][1]=newheight
            a['grid_tile']['rows']=newheight/20
            for patch in a['assembly_patches']:
                d=patch['destination']
                if d[3]>=100: d[3]-=20
                elif d[1]>=100: d[1]-=20
            for part in a['collision_parts']:
                if part[1]>=100: part[1]-=20
                if part[3]>=120: part[3]-=20
        assets.append(a)
    def prop(key,id,name,width,depth):
        a=deepcopy(sources[key]); w,h=a['region'][2:]; scale=width/w
        assert h*scale>=depth,(key,h*scale,depth)
        a.update(id=id,name=name,world_size=[width,h*scale],render_size=[width,h*scale],
            ground_rect=[0,h-depth/scale,w,depth/scale],footprint_world_size=[width,depth],
            elevation_world=h*scale-depth,render_mode='projected_prop',blocking=True,interactive=False,
            proportion_locked=True,shadow_baked=False,editor_subcategory='serving',authoring_set='cafeteria-v2')
        assets.append(a);return a
    prop('fridge','cafeteria_fridge_v2','食堂不锈钢储物柜',100,55)
    prop('cupboard','cafeteria_bowl_cupboard_v2','食堂玻璃餐具柜',70,50)
    prop('sink','cafeteria_sink_v2','食堂双槽洗池备餐柜',180,50)
    prop('rack','cafeteria_bowl_rack_v2','食堂开放餐具架',110,45)
    prop('bins','cafeteria_covered_bins_v2','食堂双带盖回收桶',60,28)
    table=deepcopy(old['cafeteria_table_vertical_v1'])
    for key in ['world_size','render_size','footprint_world_size']:table[key]=[v*.9 for v in table[key]]
    table['elevation_world']*=.9
    table.update(id='cafeteria_table_vertical_v2',name='食堂紧凑纵桌与双侧长凳',authoring_set='cafeteria-v2')
    assets.append(table)
    counter=deepcopy(old['cafeteria_counter_v1'])
    scale=670/counter['footprint_world_size'][0]
    for key in ['world_size','render_size','footprint_world_size']:counter[key]=[v*scale for v in counter[key]]
    counter['elevation_world']*=scale
    counter.update(id='cafeteria_counter_v2',name='食堂独立不锈钢取餐台',authoring_set='cafeteria-v2')
    assets.append(counter)
    # A stove is a source region, not a destructively edited copy of the old PNG.
    stove=deepcopy(old['cafeteria_backline_v1'])
    stove['region']=[360,282,425,213]
    width=135; w,h=stove['region'][2:]; scale=width/w; depth=50
    stove.update(id='cafeteria_stove_v2',name='食堂双锅炉台',world_size=[width,h*scale],render_size=[width,h*scale],
        ground_rect=[0,h-depth/scale,w,depth/scale],footprint_world_size=[width,depth],elevation_world=h*scale-depth,authoring_set='cafeteria-v2')
    assets.append(stove)
    for id in ['cafeteria_floor_v1','cafeteria_roof_surface']:
        assets.append(deepcopy(old[id]))
    # The frame is reused in both states; only the leaves change.
    door=sources['door']
    components=[('frame',[73,145,732,519]),('closed_leaves',[867,170,521,494]),('open_left',[1496,145,76,519]),('open_right',[1746,145,75,519])]
    for key,region in components:
        a=deepcopy(door);a.update(id='cafeteria_door_component_'+key,region=region,editor_hidden=True,runtime_size_limit=768);assets.append(a)
    def patch(key, rect):return dict(asset='cafeteria_door_component_'+key,source=[0,0,1,1],destination=rect)
    frame=patch('frame',[0,0,180,100])
    presentation=dict(raised_door=True,clear_wall_facade=True,body_depth_limited=True,door_art_size=[180,100],
        door_art='doorway_cafeteria_open_v2',door_art_closed='doorway_cafeteria_closed_v2',
        door_open_patches=[patch('open_left',[16,11,12,89]),patch('open_right',[152,11,12,89]),frame],
        door_closed_patches=[patch('closed_leaves',[16,11,148,89]),frame],
        visual_solid_parts=[[0,11,28,89],[152,11,28,89]],closed_visual_solid_parts=[[0,11,180,89]],
        body_profile='human_silhouette',states=['closed','fully-open'])
    for state in ['open','closed']:
        a=deepcopy(door);a.update(id='doorway_cafeteria_'+state+'_v2',name='食堂灰蓝钢门 · '+('全开' if state=='open' else '关闭'),
            region=components[0][1],render_mode='embedded_door',world_size=[180,100],render_size=[180,100],
            footprint_world_size=[160,20],ground_rect=[0,0,732,519],blocking=False,grid_door={'cell':20},
            editor_subcategory='doors',door_presentation=deepcopy(presentation),authoring_set='cafeteria-v2')
        assets.append(a)
    write(ART/'manifest.json',dict(schema=2,version='cafeteria-v2',assets=assets))
    write(DOC/'asset-registration.json',dict(mode='built-in image_gen',assets=records,definition_ids=[a['id'] for a in assets],shared_door_frame=frame))
    print('Registered',len(assets),'cafeteria definitions and',len(records),'original PNGs.')
    return {a['id']:a for a in assets},old

def restore(defs,old):
    path=ROOT/'data/rooms/r04.json'; raw=path.read_bytes(); start_sha=sha(path); m=read(path)
    assert m.get('cafeteria_restoration_version') != 2,'Already applied. Use refinement rather than replaying.'
    assert next(f for f in m['fixtures'] if f['id']=='dine-table-0')['rect'][1] == 2150,'Saved furniture moved; revise against new location.'
    area=[900,1940,1200,560]
    removed=set(); previous_styles={}
    for s in m['architecture']['wall_surfaces']:
        id=s.get('grid_tile_asset','')
        if not id.startswith('cafeteria_'):continue
        i=int(s['wall_index']); rect=m['walls'][i]
        if rect[1]==2940:
            # These are the shared north walls of laundry/equipment, not remnants to erase.
            previous_styles[i]=id
            s['grid_tile_asset']='prison_t_e' if id=='cafeteria_junction_e' else 'prison_t_s' if id=='cafeteria_junction_s' else old[id].get('legacy_id','prison_h_c')
        else:removed.add(i)
    mapping={};walls=[]
    for i,wall in enumerate(m['walls']):
        if i in removed:continue
        mapping[i]=len(walls);walls.append(wall)
    surfaces=[]
    for s in m['architecture']['wall_surfaces']:
        i=int(s['wall_index'])
        if i in removed:continue
        s['wall_index']=mapping[i];surfaces.append(s)
    m['walls']=walls;m['architecture']['wall_surfaces']=surfaces
    created=[]
    def wall(id,x,y):
        a=defs[id]; index=len(m['walls'])
        m['walls'].append([x,y,*a['world_size']])
        m['architecture']['wall_surfaces'].append(dict(wall_index=index,grid_tile_asset=id,height=20,collision_parts=deepcopy(a['collision_parts'])))
        created.append(index)
    def row(y,holes):
        for x in range(920,2080,40):
            if any(a<=x<b for a,b in holes):continue
            wall('cafeteria_wall_h_%02d_v2'%int(((x-920)//20)%16),x,y)
    wall('cafeteria_corner_nw_v2',880,1840);wall('cafeteria_corner_ne_v2',2080,1840)
    row(1840,[(1060,1220),(1920,2080)])
    wall('cafeteria_corner_sw_v2',880,2400);wall('cafeteria_corner_se_v2',2080,2400)
    row(2420,[(1460,1620)])
    for x in [880,2100]:
        for y in range(1940,2400,20):
            if x==880 and 2020<=y<2160:continue
            wall('cafeteria_wall_v_short_v2',x,y)
    gates={g['id']:g for g in m['access_doors']}
    for id,rect,evac in [('cafeteria-entry',[1060,1920,160,20],[1140,1780]),('cafeteria-entry-east',[1920,1920,160,20],[2000,1780])]:
        gates[id].update(rect=rect,room_rect=area.copy(),evacuation=evac,asset_id='doorway_cafeteria_closed_v2')
    south=deepcopy(gates['cafeteria-entry'])
    south.update(id='cafeteria-south',name='食堂南门',rect=[1460,2500,160,20],evacuation=[1540,2590])
    m['access_doors'].append(south);gates[south['id']]=south
    # The existing far rear door is already referenced by the laundry roof.
    # Keep its position, schedule and ID; fix its stale enclosing room only.
    laundry=next(r for r in m['visibility_rooms'] if r['id']=='laundry')
    gates['cafeteria-rear'].update(room_rect=deepcopy(laundry['rect']),evacuation=[1390,2990])
    changed=set()
    for f in m['fixtures']:
        if str(f['id']).startswith(('dine-','canteen-')) or f['id']=='detail44-planter-3':changed.add(f['id'])
        if f.get('access_id') in ['cafeteria-entry','cafeteria-entry-east']:
            changed.add(f['id']); f.update(rect=gates[f['access_id']]['rect'].copy(),asset_id='doorway_cafeteria_closed_v2',
                closed_asset='doorway_cafeteria_closed_v2',open_asset='doorway_cafeteria_open_v2',render_size=[180,100])
    retained=[f for f in m['fixtures'] if not (str(f['id']).startswith(('dine-','canteen-')) or f['id']=='detail44-planter-3')]
    m['fixtures']=retained
    def place(id,asset,x,y,size=None,**extra):
        a=defs.get(asset,old.get(asset,{})); dims=size or a['footprint_world_size']
        f=dict(id=id,asset_id=asset,rect=[x,y,*dims],blocks_movement=bool(a.get('blocking',True)),blocks_sight=False)
        f.update(extra);m['fixtures'].append(f);changed.add(id);return f
    place('canteen-fridge','cafeteria_fridge_v2',1225,1958)
    place('canteen-bowl-cupboard','cafeteria_bowl_cupboard_v2',1330,1958)
    place('canteen-sink','cafeteria_sink_v2',1405,1958)
    place('canteen-stove','cafeteria_stove_v2',1590,1958)
    place('canteen-bowl-rack','cafeteria_bowl_rack_v2',1735,1958)
    counter=place('canteen-counter','cafeteria_counter_v2',1180,2080,name='食堂取餐台',blocks_sight=True)
    counterdef=defs[counter['asset_id']]
    food_y=counter['rect'][1]+counter['rect'][3]-counterdef['world_size'][1]+29
    place('canteen-redesign-service-food','cafeteria_service_food_v1',1265,food_y,blocks_movement=False,draw_depth=counter['rect'][1]+counter['rect'][3]+1)
    place('canteen-redesign-water','cafeteria_water_urn_v1',930,1958)
    place('canteen-return','cafeteria_return_v1',1990,2380,name='餐具回收')
    tabledef=defs['cafeteria_table_vertical_v2']
    for i in range(5):
        tx=990+220*i;ty=2210
        desk=place('dine-table-'+str(i),'cafeteria_table_vertical_v2',tx,ty)
        top=ty+tabledef['footprint_world_size'][1]-tabledef['world_size'][1]
        place('dine-tray-'+str(i),'cafeteria_tray_v41',tx+42,top+100,[42,17.1214],blocks_movement=False,draw_depth=desk['rect'][1]+desk['rect'][3]+8)
        place('canteen-redesign-cup-'+str(i),'cafeteria_enamel_cup_v1',tx+57,top+69,blocks_movement=False,draw_depth=desk['rect'][1]+desk['rect'][3]+11)
    for i,tx in enumerate([1350,1680]):
        place('canteen-redesign-window-'+str(i),'cafeteria_window_v1',tx,1855,blocks_movement=False,draw_depth=1942)
    place('canteen-redesign-wall-light','cafeteria_light_v1',1520,1860,blocks_movement=False,draw_depth=1943)
    place('canteen-south-door-visual','doorway_cafeteria_closed_v2',1460,2500,[160,20],access_id='cafeteria-south',
        open_asset='doorway_cafeteria_open_v2',closed_asset='doorway_cafeteria_closed_v2',render_size=[180,100],blocks_movement=False)
    floor=next(f for f in m['floor_regions'] if f['id']=='canteen')
    floor.update(rect=[880,1920,1240,600],manifest=MANIFEST)
    m['floor_regions'].append(dict(id='canteen-laundry-connection',asset_id='common_floor_v46',rect=[1300,2520,320,520],tile_size=[320,320]))
    room=next(r for r in m['visibility_rooms'] if r['id']=='canteen')
    room.update(rect=area.copy(),door_ids=['cafeteria-entry','cafeteria-entry-east','cafeteria-south'],roof_style='cafeteria',retained_wall_edges=True)
    next(r for r in m['zones'] if r['id']=='canteen').update(rect=area.copy(),hide_label=True)
    m['cafeteria'].update(room_rect=area.copy(),entrance=gates['cafeteria-entry']['rect'].copy(),
        pickup_label=[1325,2180],return_label=[1950,2350],wall_sign=[1660,2440,110,38])
    m['routine_points']['meal']=[[1320,2170],[1450,2170],[1580,2170],[1710,2170],[1810,2170]]
    m['routine_points']['dine']=[[966+220*i,2310] for i in range(5)]
    cook=next(s for s in m['resident_staff'] if s['id']=='canteen-cook')
    cook.update(position=[1515,2050],room_id='canteen',patrol=[])
    for lamp in m.get('lamps',[]):
        lx,ly=lamp['position']
        if 900<=lx<=2100 and 1940<=ly<=2500:lamp['draw_fixture']=False
    m['cafeteria_restoration_version']=2
    assert sha(path)==start_sha,'Map changed during restore. Re-read latest saved map.'
    (DOC/'restoration-input.json').write_bytes(raw)
    write(path,m);write(DOC/'restoration-output.json',m)
    write(DOC/'layout-registration.json',dict(area=area,changed_fixture_ids=sorted(changed),removed_wall_indices=sorted(removed),
        appended_wall_indices=created,retained_shared_walls=previous_styles,before_sha256=start_sha,after_sha256=sha(path)))
    print('Restored compact cafeteria:',area,'new wall tiles:',len(created),'five aligned tables, kitchen modules, synchronized floor/roof/routines.')

if __name__=='__main__':
    definitions, previous=register()
    restore(definitions, previous)
