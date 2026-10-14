"""Build the approved pipe-energy court on the latest saved R04.

Generated PNGs stay byte-identical. Source regions, independent native props,
compound visibility and real wall/door geometry remain editable in the map.
"""
from copy import deepcopy
from pathlib import Path
from PIL import Image
import argparse, hashlib, json, os, tempfile, shutil

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT/'docs/art/pipe-energy-court-v1'
ART = ROOT/'art/props/pipe_energy_court_v1'
ENV = ROOT/'art/environment/pipe_energy_court_v1'
SHADER = 'res://art/props/exercise_yard_v54/clean_cutout.gdshader'
PREFIX = 'energy-court-'

def read(p): return json.loads(p.read_bytes())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=p.name+'.', suffix='.writing', dir=p.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(json.dumps(value, ensure_ascii=False, indent='\t')+'\n')
        os.replace(name, p)
    finally:
        if os.path.exists(name): os.unlink(name)

def region(key, box=None):
    im=Image.open(ART/(key+'.png')); alpha=im.getchannel('A')
    if box: alpha=alpha.crop(box)
    x,y,right,bottom=alpha.point(lambda a:255 if a>=220 else 0).getbbox()
    ox,oy=box[:2] if box else (0,0)
    x=max(0,ox+x-3);y=max(0,oy+y-3)
    return [x,y,min(im.width,ox+right+3)-x,min(im.height,oy+bottom+3)-y]

def assets():
    records=[]
    inputs=read(DOC/'production-inputs.json')['pngs']
    if (DOC/'supplemental-inputs.json').exists():
        for p in read(DOC/'supplemental-inputs.json')['pngs']:
            dst=ART/(p['key']+'.png')
            if not dst.exists(): shutil.copyfile(p['source'],dst)
            inputs.append(p)
    for p in inputs:
        dst=ART/(p['key']+'.png'); assert sha(dst)==sha(Path(p['source']))
        im=Image.open(dst)
        if p['key']!='concrete-tile':
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
            assert im.getchannel('A').getextrema()[1]>=250
        records.append(dict(key=p['key'],source=p['source'],path=dst.relative_to(ROOT).as_posix(),sha256=sha(dst),size=list(im.size)))
    props=[]
    def sprite(key,name,file,width,depth=None,crop=None,**extra):
        im=Image.open(ART/(file+'.png')); crop=crop or region(file)
        x,y,w,h=crop; scale=width/w; height=h*scale
        if depth is None: depth=height
        assert 0<depth<=height
        a=dict(id='energy_'+key+'_v1',name='能源庭院 · '+name,texture='res://art/props/pipe_energy_court_v1/'+file+'.png',
               texture_size=list(im.size),region=crop,world_size=[width,height],render_size=[width,height],
               footprint_world_size=[width,depth],ground_rect=[0,h-depth/scale,w,depth/scale],elevation_world=height-depth,
               render_mode='projected_prop',proportion_locked=True,runtime_size_limit=1024,alpha_core_shader=SHADER,
               blocking=True,interactive=False,shadow_baked=True,editor_subcategory='furnishings',
               source_kind='built-in-imagegen-original-png',sha256=sha(ART/(file+'.png')))
        a.update(extra);props.append(a);return a
    sprite('tank','纵向长压力储罐','pressure-tank',205,680)
    sprite('platform','八角阀门检修平台','valve-platform',500,440,
           solid_parts=[[.22,0,.56,.18],[.08,.18,.84,.16],[0,.34,1,.32],[.08,.66,.84,.16],[.22,.82,.56,.18]])
    # Reuse original pixels as an assembly: repeat equal-size X-brace sections
    # to give a true overhead clearance without distorting the painted pipes.
    gantry=sprite('gantry','红蓝架空管架单跨','pipe-gantry-span',288,26)
    beam_height=203*288/1300
    gantry_height=beam_height+5*24.4+24.405
    gantry.update(world_size=[288,gantry_height],render_size=[288,gantry_height],footprint_world_size=[288,26],
                   proportion_locked=False,render_mode='architecture_overhead_gantry',editor_placeable=True,ground_rect=[0,0,288,26],elevation_world=gantry_height-26,
                   solid_parts=[[.455,0,.09,1]],collision_note='Only the center support foot blocks movement; the beam is overhead.')
    gantry['assembly_patches']=[dict(source=[400,81,1300,203],destination=[0,0,288,beam_height],role='unchanged_pipe_pair')]
    for i in range(5):
        gantry['assembly_patches'].append(dict(source=[1008,293,170,180],destination=[132.5,beam_height+i*24.4,23,24.4],role='repeated_equal_scale_brace'))
    gantry['assembly_patches'].append(dict(source=[996,478,190,180],destination=[131.12,beam_height+122,25.76,24.405],role='support_foot'))
    im=Image.open(ART/'pipe-fittings.png')
    for key,name,width,col,row in [
        ('pipe_pair','横向红蓝双管',72,0,0),('pipe_elbow_up','红蓝双管左接上弯',78,1,0),
        ('pipe_elbow_right','红蓝双管上接右弯',78,2,0),('pipe_red','红色直管',18,0,1),
        ('pipe_blue','蓝色直管',18,1,1),('pipe_tee','平台红管三通',70,2,1)]:
        box=(col*im.width//3,row*im.height//2,(col+1)*im.width//3,(row+1)*im.height//2)
        sprite(key,name,'pipe-fittings',width,crop=region('pipe-fittings',box),blocking=False)
    sprite('sign','设备间搪瓷标牌','equipment-sign',190,1,blocking=False,editor_subcategory='attachments')
    if (ART/'parts-canopy.png').exists():
        sprite('canopy','橄榄帆布备件棚','parts-canopy',185,170,
               solid_parts=[[.06,.85,.06,.15],[.86,.85,.06,.15],[.17,.3,.65,.62]])
        sprite('control_bank','三联灰钢仪表控制柜','control-bank',240,65)
    all_defs={}
    for p in ['art/props/factory_v43/manifest.json','art/props/factory_v44/manifest.json','art/props/workshop_one_v2/manifest.json',
              'art/props/campus_v47/manifest.json','art/props/exercise_yard_v55/manifest.json','art/props/warehouse_v1/manifest.json',
              'art/architecture/workshop_door_v2/manifest.json']:
        all_defs.update({a['id']:a for a in read(ROOT/p)['assets']})
    for old,key,name,width,blocking in [
        ('equipment_pump_v43','pump','蓝钢循环泵组',280,True),('electrical_cabinet_v43','control','电气控制柜',75,True),
        ('workshop2_workbench','worktable','南墙检修台',180,True),('warehouse_drums_v1','drums','蓝色检修桶',58,True),
        ('warehouse_north_shelf_v1','parts','室外备件工作台',155,True),('cargo_pallet_v43','pallet','周转木托盘',125,True),
        ('warehouse_jack_v1','jack','后勤手推托盘车',55,True),('warehouse_cabinet_v1','shelf','院角备件柜',75,True),
        ('park_bench_v47','bench','上院木长椅',180,True),('yard_lamp_v47','lamp','旧式院灯',46,True),
        ('yard_ground_shrubs_a_v55','shrubs_a','地栽灌木 A',150,False),('yard_ground_shrubs_b_v55','shrubs_b','地栽灌木 B',115,False)]:
        a=deepcopy(all_defs[old]);w,h=a['region'][2:];scale=width/w;ground=a['ground_rect'];depth=ground[3]*scale
        a.update(id='energy_'+key+'_v1',name='能源庭院 · '+name,world_size=[width,h*scale],render_size=[width,h*scale],
                 footprint_world_size=[ground[2]*scale,depth],elevation_world=h*scale-depth,proportion_locked=True,
                 runtime_size_limit=512,blocking=blocking,reused_from=old,editor_subcategory='furnishings')
        a.pop('editor_icon',None); props.append(a)
    for state in ['open','closed']:
        a=deepcopy(all_defs['doorway_workshop_'+state+'_v2'])
        a.update(id='doorway_energy_'+state+'_v1',name='能源庭院 · 设备间钢门 · '+('开启' if state=='open' else '关闭'),reused_from='doorway_workshop_'+state+'_v2')
        a['door_presentation'].update(door_art='doorway_energy_open_v1',door_art_closed='doorway_energy_closed_v1')
        props.append(a)
    write(ART/'manifest.json',dict(schema=2,version='pipe-energy-court-v1',assets=props))
    im=Image.open(ART/'concrete-tile.png')
    tile=dict(id='energy_concrete_v1',name='能源庭院旧混凝土',texture='res://art/props/pipe_energy_court_v1/concrete-tile.png',
              texture_size=list(im.size),region=[0,0,*im.size],world_size=[240,240],runtime_size_limit=512,
              sha256=sha(ART/'concrete-tile.png'),source_kind='built-in-imagegen-original-png')
    write(ENV/'manifest.json',dict(schema=2,assets=[tile]))
    write(DOC/'production-assets.json',dict(mode='built-in imagegen',pngs=records,definition_ids=[a['id'] for a in props],
          ground_manifest='res://art/environment/pipe_energy_court_v1/manifest.json',assembly='Pipe/post layout uses original native source patches; PNGs never re-exported.'))
    catalog=ROOT/'scripts/presentation/prop_catalog.gd';text=catalog.read_text(encoding='utf-8')
    line='\t"res://art/props/pipe_energy_court_v1/manifest.json",\n'
    if line not in text:
        anchor='\t"res://art/props/drying_yard_v1/manifest.json",\n'; assert text.count(anchor)==1
        candidate=text.replace(anchor,anchor+line)
        fd,tmp=tempfile.mkstemp(prefix='prop_catalog.',suffix='.writing',dir=catalog.parent)
        with os.fdopen(fd,'w',encoding='utf-8') as f:f.write(candidate)
        os.replace(tmp,catalog)
    return {a['id']:a for a in props}

def prepare():
    path=ROOT/'data/rooms/r04.json';before=read(path);d=deepcopy(before);initial=sha(path)
    assert not d.get('pipe_energy_court_version'), 'Already installed; refine own objects against current map.'
    assert next(r['rect'] for r in d['visibility_rooms'] if r['id']=='warehouse')==[4280,1060,840,2160]
    assert next(r['rect'] for r in d['visibility_rooms'] if r['id']=='campus-kiosk')==[2320,2016,560,380]
    assert not any(2100<r[0]<4260 and 2700<r[1]<4000 for r in d['walls']), 'New construction area has occupied walls.'
    defs={a['id']:a for a in read(ART/'manifest.json')['assets']}
    fixture_ids=[]
    def prop(key,asset,x,y,**extra):
        a=defs['energy_'+asset+'_v1']; f=dict(id=PREFIX+key,asset_id=a['id'],rect=[x,y,*a['footprint_world_size']],
             blocks_movement=a['blocking'],blocks_sight=False,energy_court_generated=True)
        if a.get('solid_parts'):f['solid_parts']=deepcopy(a['solid_parts'])
        f.update(extra);d['fixtures'].append(f);fixture_ids.append(f['id']);return f
    exterior=dict(exterior_shell=True)
    prop('tank','tank',2410,2780)
    prop('pump','pump',2740,3730)
    for i in range(3):prop('control-'+str(i),'control',3160+80*i,3600)
    prop('south-worktable','worktable',2370,3820)
    prop('indoor-drums','drums',3430,3860)
    prop('valve-platform','platform',3680,3240,**exterior)
    for i in range(5):prop('gantry-'+str(i),'gantry',2800+i*288,3060,render_size=[288,175],draw_depth=3110,**exterior)
    def pipe(key,asset,x,y,width=None,height=None,**extra):
        f=prop(key,asset,x,y,**extra)
        if width or height:
            a=defs[f['asset_id']]
            # Long straight pipe runs are repeatable native source patches.
            if width:
                f['rect'][2]=width; f['render_size']=[width,f['rect'][3]]
            if height:
                f['rect'][3]=height; f['render_size']=[f['rect'][2],height]
            # Nonblocking wall/overhead tubes may stretch length only.
            f['pipe_run_size']=f['rect'][2:]
        return f
    # Fittings are independent sprites, making pipe routes easy to adjust.
    for i in range(10):
        pipe('west-red-'+str(i),'pipe_red',2346,2770+i*67)
        pipe('west-blue-'+str(i),'pipe_blue',2372,2770+i*72)
    for i in range(4):pipe('tank-header-'+str(i),'pipe_pair',2418+i*68,2750)
    pipe('tank-return-elbow','pipe_elbow_up',2665,2715)
    for i in range(10):
        pipe('return-red-'+str(i),'pipe_red',2710,2790+i*70)
        pipe('return-blue-'+str(i),'pipe_blue',2736,2790+i*75)
    pipe('pump-elbow','pipe_elbow_right',2700,3670)
    for i in range(8):pipe('south-header-'+str(i),'pipe_pair',2870+i*68,3520)
    pipe('warehouse-elbow','pipe_elbow_up',4210,2840,draw_depth=3110,**exterior)
    for i in range(3):
        pipe('warehouse-red-'+str(i),'pipe_red',4250,2640+i*68,draw_depth=3110,**exterior)
        pipe('warehouse-blue-'+str(i),'pipe_blue',4276,2640+i*75,draw_depth=3110,**exterior)
    pipe('platform-tee','pipe_tee',3895,2917,draw_depth=3115,**exterior)
    for i in range(4):pipe('platform-red-feed-'+str(i),'pipe_red',3920,2950+i*65,draw_depth=3500,**exterior)
    prop('nameplate','sign',2915,3873,draw_depth=3990,in_front_of_wall_trim=True,**exterior)
    prop('exterior-pallet','pallet',4570,3790,**exterior)
    prop('exterior-jack','jack',4450,3880,**exterior)
    prop('exterior-parts-table','parts',4820,3890,**exterior)
    prop('exterior-parts-cabinet','shelf',4960,3700,**exterior)
    for key,x,y in [('north-left',2640,2550),('north-right',3980,2750),('south-left',2250,4050),('south-right',4970,4050)]:
        prop('lamp-'+key,'lamp',x,y,**exterior)
    for i,(x,y) in enumerate([(2230,2700),(2250,2910),(2230,3170),(2240,3420),(2230,3690),(2230,3910),
          (2810,2790),(3030,2780),(3330,2800),(3510,3070),(3600,3380),(3590,3640),(3560,3850),
          (4190,3120),(4200,3370),(4200,3620),(4330,3410),(4550,3450),(4830,3460),(4530,3980)]):
        prop('shrub-'+str(i),'shrubs_a' if i%2==0 else 'shrubs_b',x,y,**exterior)
    changed_fixtures=[]
    for f in d['fixtures']:
        if f['id']=='courtyard-bench-west':f['rect']=[2720,2650,160,54.7367];changed_fixtures.append(f['id'])
        if f['id']=='courtyard-bench-east':f['rect']=[3845,2760,160,54.7367];changed_fixtures.append(f['id'])
    # Physical walls are appended; all existing indices and surfaces stay intact.
    wall_ids=[]
    def wall(asset,x,y,w,h,parts):
        index=len(d['walls']); d['walls'].append([x,y,w,h]);wall_ids.append(index)
        d['architecture']['wall_surfaces'].append(dict(wall_index=index,height=20,grid_tile_asset=asset,
             collision_parts=parts,energy_court_generated=True))
    def row(x0,x1,y,door=None):
        x=x0
        while x<x1:
            lintel=door and door[0]<=x<door[1]
            stop=door[1] if lintel else door[0] if door and x<door[0] else x1
            w=min(80 if lintel else 40,stop-x)
            if lintel and w==40:w=20
            asset='workshop_lintel_'+str(w) if lintel else 'workshop_wall_h_short' if w==20 else 'workshop_wall_h_'+f'{int((x-x0)%320/20):02d}'
            wall(asset,x,y,w,20 if lintel else 120,[] if lintel else [[0,100,w,20]])
            x+=w
    def column(x,y0,y1):
        y=y0
        while y<y1:
            h=min(120,y1-y);wall('workshop_wall_v_long' if h==120 else 'workshop_wall_v_short',x,y,20,h,[[0,0,20,h]]);y+=h
    wall('workshop_corner_nw',2300,2620,40,120,[[0,100,40,20]])
    wall('workshop_corner_ne',2760,2620,40,120,[[0,100,40,20]])
    row(2340,2760,2620)
    column(2300,2740,3820)
    column(2780,2740,3500)
    row(2800,3520,3400,[2900,3080])
    wall('workshop_corner_ne',3520,3400,40,120,[[0,100,40,20]])
    column(3540,3520,3820)
    wall('workshop_corner_sw',2300,3820,40,140,[[0,120,40,20],[0,0,20,140]])
    wall('workshop_corner_se',3520,3820,40,140,[[0,120,40,20],[20,0,20,140]])
    row(2340,3520,3840,[2900,3080])
    for key,y in [('energy-entry',3940),('energy-court-entry',3500)]:
        gate=dict(id=key,name='设备间南门' if key=='energy-entry' else '设备间院门',kind='latch',initial_closed=True,
                  rect=[2900,y,180,20],asset_id='doorway_energy_closed_v1',blocks_sight=False,energy_court_generated=True)
        d['access_doors'].append(gate)
        f=dict(id=PREFIX+key,asset_id='doorway_energy_closed_v1',open_asset='doorway_energy_open_v1',closed_asset='doorway_energy_closed_v1',
               access_id=key,rect=gate['rect'].copy(),render_size=[180,120],blocks_movement=False,blocks_sight=False,
               exterior_shell=True,energy_court_generated=True)
        d['fixtures'].append(f);fixture_ids.append(f['id'])
    # Replace the obsolete empty service-room masks, not any living building.
    d['visibility_rooms']=[r for r in d['visibility_rooms'] if r['id'] not in ['equipment','repair','waste']]
    d['visibility_rooms'].append(dict(id='equipment',name='能源设备间',kind='room',rect=[2320,2740,1220,1200],
         room_parts=[[0,0,460/1220,1],[460/1220,780/1200,760/1220,420/1200]],
         door_ids=['energy-entry','energy-court-entry'],roof_style='metal_green',retained_wall_edges=True,roof_exit_by_feet=True,
         roof_rect=[2300,2620,1260,1220],roof_cutouts=[[500/1260,0,760/1260,780/1220]],
         roof_outline=[[0,0],[500/1260,0],[500/1260,780/1220],[1,780/1220],[1,1],[0,1]],energy_court_generated=True))
    d['zones']=[r for r in d['zones'] if r['id'] not in ['equipment','repair','waste','garden']]
    for key,r in [('equipment',[2320,2740,460,1200]),('equipment-south-wing',[2780,3520,760,420])]:
        d['zones'].append(dict(id=key,name='设备间',rect=r,color='#b2b1a0',hide_label=True,energy_court_generated=True))
    env='res://art/environment/pipe_energy_court_v1/manifest.json'
    def floor(key,rect,asset='energy_concrete_v1',polygon=None,**extra):
        f=dict(id=PREFIX+key,rect=rect,asset_id=asset,tile_size=[240,240],tile_origin=[0,0],energy_court_generated=True)
        if asset=='energy_concrete_v1':f['manifest']=env
        if polygon:f['polygon']=polygon
        f.update(extra);d['floor_regions'].append(f)
    floor('concrete-yard',[2140,2420,2120,1680])
    floor('warehouse-apron',[4280,3260,840,840])
    floor('south-through-road',[2100,3980,3020,120])
    floor('north-grass',[2180,2420,1160,520],'grass_base_v46',[[0,0],[1,0],[1,.35],[.86,.75],[.67,1],[.18,1],[.18,.65],[0,.4]],natural_ground=True,tile_size=[470,470])
    floor('tree-green-edge',[2960,1900,1300,980],'grass_base_v46',[[0,0],[1,0],[1,.7],[.96,1],[.75,.98],[.73,.85],[.18,.85],[.12,1],[0,.8]],natural_ground=True,tile_size=[470,470])
    # This path turns around the existing tree footprint and heads to the valve.
    floor('tree-west-walk',[3190,2010,270,850],'common_floor_v46',[[.18,0],[1,0],[.86,.12],[.66,.25],[.55,.42],[.55,.77],[.85,1],[.28,1],[0,.82],[0,.38],[.15,.20]],tile_size=[320,320])
    floor('tree-east-walk',[3830,2070,240,750],'common_floor_v46',[[0,0],[.65,0],[1,.2],[1,.75],[.70,1],[0,1],[.48,.72],[.45,.25]],tile_size=[320,320])
    octagon=[[.25,0],[.75,0],[1,.25],[1,.75],[.75,1],[.25,1],[0,.75],[0,.25]]
    floor('platform-ring-road',[3560,3030,720,900],'common_floor_v46',octagon,tile_size=[320,320])
    floor('platform-green-edge',[3615,3190,620,585],'grass_base_v46',octagon,natural_ground=True,tile_size=[470,470])
    floor('east-service-green',[4440,3500,600,510],'grass_base_v46',[[0,0],[.8,0],[1,.2],[1,1],[0,1]],natural_ground=True,tile_size=[470,470])
    floor('equipment-west-floor',[2320,2740,460,1200])
    floor('equipment-south-floor',[2780,3520,760,420])
    details=d['ground_details']; removed_details=[]
    for item in details[:]:
        if item.get('kind')=='line' and item.get('from') in [[3549.17,3112.35],[3261.39,3272.94]]:
            details.remove(item);removed_details.append(item)
    def line(a,b,width=4,opacity=.55):details.append(dict(kind='line',**{'from':a,'to':b},width=width,color='#bf9d4f',opacity=opacity,energy_court_generated=True))
    def outline(rect):
        x,y,w,h=rect
        for a,b in [([x,y],[x+w,y]),([x+w,y],[x+w,y+h]),([x+w,y+h],[x,y+h]),([x,y+h],[x,y])]:line(a,b,3,.5)
    outline([2380,2760,285,760]);outline([2715,3680,330,220])
    for i in range(3):outline([3148+80*i,3515,75,180])
    points=[[3560+x*720,3030+y*900] for x,y in octagon]
    for i,a in enumerate(points):line(a,points[(i+1)%8],4,.5)
    for x,y,w,h in [(2840,3190,64,55),(3440,3810,60,42),(3725,4020,65,50),(2340,4025,65,40)]:
        details.append(dict(kind='drain',rect=[x,y,w,h],energy_court_generated=True))
    changed_lamps=[]
    for i,l in enumerate(d['lamps']):
        if l['position']==[2481.44,3710]:l.update(position=[2663,2550],draw_fixture=False);changed_lamps.append(i)
        elif l['position']==[3100,3750]:l.update(position=[2273,4050],draw_fixture=False);changed_lamps.append(i)
        elif l['position']==[3990,3850]:l.update(position=[4993,4050],draw_fixture=False);changed_lamps.append(i)
    d['lamps'].append(dict(id=PREFIX+'east-light',position=[4003,2750],radius=280,color='#ffe2b7',energy=.5,draw_fixture=False))
    moved_points=[]
    for p in d['routine_points']['free']:
        if p==[2440,2680]:p[:]=[2870,2660];moved_points.append([2440,2680])
        elif p==[3100,3520]:p[:]=[3600,3840];moved_points.append([3100,3520])
    for item in d['items']:
        if item['position']==[2900,3950]:item['position']=[3160,3860]
    cp=d['concept_plan']
    for key in ['horizontal','vertical']:
        cp[key]=[s for s in cp[key] if not s['id'].startswith(('equipment-','repair-','waste-'))]
    cp['pipe_energy_court_revision']=dict(reference='docs/art/pipe-energy-court-v1/approved-concept.png',
          equipment_parts=[[2320,2740,460,1200],[2780,3520,760,420]],gantry_span_count=5,
          main_features=['L-shaped equipment room','north-south pressure vessel','red-blue overhead gantry','octagonal valve platform','curving stone paths'],
          south_road=[2100,3980,3020,120],open_air_courtyard=True)
    d['pipe_energy_court_version']=1
    write(DOC/'before-map.json',before);write(DOC/'candidate-map.json',d)
    write(DOC/'map-registration.json',dict(input_sha256=initial,new_fixture_ids=fixture_ids,changed_fixture_ids=changed_fixtures,
          appended_wall_indices=wall_ids,removed_visibility_ids=['equipment','repair','waste'],changed_lamp_indices=changed_lamps,
          moved_activity_points=moved_points,removed_ground_details=removed_details,new_gate_ids=['energy-entry','energy-court-entry']))
    print('Prepared equipment L, five overhead bays, octagonal platform and curved grounds on latest saved map.')

def apply():
    path=ROOT/'data/rooms/r04.json';r=read(DOC/'map-registration.json')
    assert sha(path)==r['input_sha256'],'Saved map changed; prepare again from latest before applying.'
    write(path,read(DOC/'candidate-map.json'));write(DOC/'after-map.json',read(path))
    r['output_sha256']=sha(path);write(DOC/'map-registration.json',r)
    print('Saved approved pipe-energy courtyard with hash guard and full snapshots.')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('command',choices=['assets','prepare','apply']);cmd=p.parse_args().command
    {'assets':assets,'prepare':prepare,'apply':apply}[cmd]()
