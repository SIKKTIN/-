"""Register unchanged workshop sprites and patch the latest saved workshop only."""
from copy import deepcopy
import argparse, hashlib, json, shutil
from pathlib import Path
from PIL import Image
from compact_clinic import contains_wall
from register_clinic_architecture import door_parts

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT/'docs/art/workshop-one-restoration'
SHADER = 'res://art/architecture/v25/safe_edges_v25.gdshader'

def read(path): return json.loads(path.read_bytes())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')

def definitions():
    originals = {}; records = []; props = []
    for job in read(DOC/'generated-assets.json')['assets']:
        path = ROOT/job['path']; path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(job['source'], path)
        assert sha(path) == sha(Path(job['source']))
        with Image.open(path) as image:
            if job['key'] == 'floor':
                # The source contains a display border; registration uses only
                # the four-by-four tile surface. No PNG pixels are changed.
                region = job.get('region', [0,0,*image.size])
            else:
                assert image.mode == 'RGBA' and image.getchannel('A').getextrema()[0] == 0, job['key']
                x,y,r,b = image.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
                x=max(0,x-3); y=max(0,y-3); r=min(image.width,r+3); b=min(image.height,b+3)
                region=[x,y,r-x,b-y]
            original=dict(texture='res://'+job['path'],texture_size=list(image.size),region=region,
                sha256=sha(path),source_kind='built-in-imagegen-original-png',alpha_core_shader=SHADER)
        originals[job['key']] = original
        records.append(dict(key=job['key'],path=job['path'],sha256=sha(path),region=region))
        if job['folder'] != 'props': continue
        a=deepcopy(original); _,_,w,h=region; scale=job['width']/w; gh=h*job['ground']
        small=job['key'] in ['fitting_tools','motor_assembly','copper_winding','housings','bench_drill']
        wall=job['key'] in ['wall_toolboard','shift_board','room_sign']
        a.update(id='workshop_'+job['key']+'_v1',name='一号车间 · '+job['name'],render_mode='projected_prop',
            ground_rect=[0,h-gh,w,gh],render_size=[job['width'],h*scale],world_size=[job['width'],h*scale],
            footprint_world_size=[job['width'],gh*scale],elevation_world=(h-gh)*scale,
            blocking=not(small or wall),interactive=False,shadow_baked=False,proportion_locked=True,
            editor_subcategory='attachments' if wall else 'misc' if small else 'furnishings')
        props.append(a)
    # Reuse industrial equipment with the same source aspect and floor anchor.
    reuse=[('art/props/prison_v42/manifest.json','tool_locker_v42','locker','工具柜',66),
           ('art/props/factory_v44/manifest.json','drill_press_v44','drill','立式钻床',90),
           ('art/props/factory_v44/manifest.json','oil_drums_v44','drums','油桶',80),
           ('art/props/factory_v44/manifest.json','shipping_crates_v44','crates','物资箱',85),
           ('art/props/factory_v44/manifest.json','parcel_trolley_v44','trolley','运输推车',55)]
    for file,source,key,name,width in reuse:
        a=deepcopy(next(v for v in read(ROOT/file)['assets'] if v['id']==source))
        w,h=a['region'][2:]; scale=width/w; ground=a['ground_rect']
        a.update(id='workshop_'+key+'_v1',name='一号车间 · '+name,render_size=[width,h*scale],world_size=[width,h*scale],
            footprint_world_size=[ground[2]*scale,ground[3]*scale],elevation_world=(h-ground[3])*scale,
            proportion_locked=True,editor_subcategory='furnishings')
        a.pop('editor_icon',None); props.append(a)
    write(ROOT/'art/props/workshop_one_v1/manifest.json',dict(schema=2,version='workshop-one-v1',assets=props))
    floor=deepcopy(originals['floor']); floor.update(id='workshop_tiles_v1',name='一号车间工业小方砖')
    write(ROOT/'art/environment/workshop_one_v1/manifest.json',dict(schema=2,assets=[floor]))
    architecture=architecture_definitions(originals)
    write(ROOT/'art/architecture/workshop_one_v1/manifest.json',dict(schema=2,version='workshop-one-v1',assets=architecture))
    write(DOC/'asset-registration.json',dict(mode='built-in-imagegen',assets=records,definition_ids=[a['id'] for a in props+architecture]))
    return {a['id']:a for a in props+architecture}

def architecture_definitions(originals):
    wall=deepcopy(originals['wall']); wx,wy,ww,wh=wall['region']; cap_h=wh*.18
    legacy={a['id']:a for v in ['v36','v38'] for a in read(ROOT/f'art/architecture/{v}/manifest.json')['assets']}
    architecture=[]
    def patch(src,dest,**extra): return dict(source=src,destination=dest,role='complete_wall_body',**extra)
    def face(width,phase,y=0):
        result=[]; cursor=0
        while cursor<width:
            current=(phase+cursor)%320; length=min(width-cursor,320-current)
            result.append(patch([wx+current/320*ww,wy,length/320*ww,wh],[cursor,y,length,120])); cursor+=length
        return result
    def cap(width,height,x=0,y=0): return patch([wx+ww*.2,wy,height/320*ww,cap_h],[x,y,width,height],rotation_quarters=1)
    def register(identifier,base,patches):
        old=legacy[base]; a=deepcopy(wall)
        a.update(id=identifier,name='一号车间墙体 · '+identifier.removeprefix('workshop_'),render_mode=old['render_mode'],
            world_size=old['render_size'],render_size=old['render_size'],assembly_patches=patches,blocking=False,
            collision_parts=deepcopy(old['collision_parts']),connections=old['connections'],connection_tag='workshop/'+old['connection_tag'],
            authoring_set='workshop-one-v1',grid_tile={'cell':20,'columns':old['render_size'][0]/20,'rows':old['render_size'][1]/20,'parameterized_shader':False})
        architecture.append(a)
    for i in range(16): register(f'workshop_wall_h_{i:02d}','prison_h_c',face(40,i*20))
    register('workshop_wall_h_short','prison_h_short_c',face(20,40))
    register('workshop_wall_v_long','prison_v_long',[cap(20,120)])
    register('workshop_wall_v_short','prison_v_short',[cap(20,20)])
    for side,base,right,south in [('nw','prison_l_se',False,False),('ne','prison_l_sw',True,False),('sw','prison_l_ne',False,True),('se','prison_l_nw',True,True)]:
        x=20 if right else 0; patches=face(40,60 if right else 0,20 if south else 0)
        patches.append(cap(20,20 if south else 100,x,0 if south else 20))
        joint=cap(20,20,x,20 if south else 0)
        joint['clip_polygon']=([[0,0],[1,0],[1,1]] if south and right else [[0,0],[1,0],[0,1]] if south else [[1,0],[1,1],[0,1]] if right else [[0,0],[1,1],[0,1]])
        patches.append(joint); register('workshop_corner_'+side,base,patches)
    for length in [80,20]: register(f'workshop_lintel_{length}',f'prison_lintel_{length}',[patch([wx,wy,length/320*ww,cap_h],[0,0,length,20])])
    for state in ['open','closed']:
        key='door_'+state; a=deepcopy(originals[key]); x,y,w,h=a['region']
        a.update(id='doorway_workshop_'+state+'_v1',name='一号车间钢门 · '+('开启' if state=='open' else '关闭'),
            render_mode='embedded_door',world_size=[180,120],render_size=[180,120],footprint_world_size=[160,20],
            ground_rect=[0,0,w,h],blocking=False,grid_door={'cell':20},editor_subcategory='doors')
        parts=door_parts(ROOT/'art/architecture/workshop_one_v1/door-open.png',a['region'],180) if state=='open' else []
        ratio=120/(h/w*180)
        parts=[[p[0],p[1]*ratio,p[2],p[3]*ratio] for p in parts if p[1]*ratio>=12]
        a['door_presentation']={'raised_door':True,'door_art':'doorway_workshop_open_v1','door_art_closed':'doorway_workshop_closed_v1',
            'door_art_size':[180,120],'visual_solid_parts':parts,'closed_visual_solid_parts':[[0,12,180,108]],'body_profile':'human_silhouette'}
        architecture.append(a)
    return architecture

def restore_map(assets):
    path=ROOT/'data/rooms/r04.json'; before=path.read_bytes(); digest=sha(path); room=json.loads(before)
    area=next(v['rect'] for v in room['visibility_rooms'] if v['id']=='workshop'); x,y,w,h=area
    assert area==[820,1420,1360,720], 'Room boundary changed; recalibrate approved layout.'
    selected=[]
    for surface in room['architecture']['wall_surfaces']:
        rect=room['walls'][int(surface['wall_index'])]
        rx,ry,rw,rh=rect
        if not (x-20<=rx and y-140<=ry and rx+rw<=x+w+20 and ry+rh<=y+h+20): continue
        base=surface.get('workshop_base_asset',surface['grid_tile_asset'])
        # Shared campus T joints retain their neighbouring-wall material.
        if base.startswith('prison_t_'): continue
        if base.startswith('prison_h_short'): key='workshop_wall_h_short'
        elif base.startswith('prison_h_'): key=f'workshop_wall_h_{int((rect[0]-x+20)%320/20):02d}'
        else: key={'prison_l_se':'workshop_corner_nw','prison_l_sw':'workshop_corner_ne','prison_l_ne':'workshop_corner_sw','prison_l_nw':'workshop_corner_se','prison_v_long':'workshop_wall_v_long','prison_v_short':'workshop_wall_v_short','prison_lintel_80':'workshop_lintel_80','prison_lintel_20':'workshop_lintel_20'}[base]
        surface.update(grid_tile_asset=key,workshop_base_asset=base); selected.append(surface['wall_index'])
    floor=next(v for v in room['floor_regions'] if v['id']=='workshop')
    floor.update(asset_id='workshop_tiles_v1',manifest='res://art/environment/workshop_one_v1/manifest.json',tile_size=[160,160])
    next(v for v in room['zones'] if v['id']=='workshop')['hide_label']=True
    # Patch existing fixture IDs rather than removing saved container identities.
    room['fixtures']=[f for f in room['fixtures'] if not f.get('workshop_generated',False)]
    by_id={f['id']:f for f in room['fixtures']}; edited=[]
    def prop(identifier,key,px,py,loot=None,depth=None):
        a=assets['workshop_'+key+'_v1']; f=by_id.get(identifier)
        if f is None:
            f=dict(id=identifier,workshop_generated=True); room['fixtures'].append(f)
        else: edited.append(identifier)
        f.update(asset_id=a['id'],rect=[x+px,y+py,*a['footprint_world_size']],blocks_movement=a['blocking'],blocks_sight=False)
        f.pop('render_size',None)
        if loot: f.update(loot_profile=loot,loot_location='一号车间',loot_name=a['name'].split(' · ')[-1])
        if depth is not None: f['draw_depth']=depth
        return f
    variants=['fitting_tools','motor_assembly','copper_winding','housings']
    for index,(px,py) in enumerate([(200,220),(700,220),(200,450),(700,450)]):
        table=prop('bench_'+str(index),'workbench',px,py)
        prop('detail44-bench-tools-'+str(index),variants[index],px+60,py-20,depth=table['rect'][1]+table['rect'][3]+1)
    for i,px in enumerate([200,280,360]): prop('locker_'+str(i),'locker',px,55,'tools')
    prop('detail44-parts-0','parts_drawers',470,55,'industrial')
    prop('detail44-work-motor-shelf','north_parts_rack',620,55,'industrial')
    prop('workshop-low-cabinet-a','low_tool_cabinet',780,55,'tools')
    prop('workshop-low-cabinet-b','low_tool_cabinet',920,55,'tools')
    prop('workshop-north-drawers','parts_drawers',1070,55,'industrial')
    for i,px in enumerate([805,945]): prop('workshop-bench-drill-'+str(i),'bench_drill',px,-3,depth=y+90)
    prop('workshop-west-rack','west_parts_rack',25,170,'industrial')
    prop('workshop-electrical','electrical_cabinet',1220,55)
    prop('detail44-drill-0','drill',1160,170)
    prop('detail44-drill-1','drill',1160,420)
    prop('detail44-work-drum','drums',1250,310)
    prop('detail44-work-stock-0','crates',1250,530,'warehouse')
    prop('detail44-work-trolley','trolley',1160,530)
    prop('workshop-west-stock','crates',100,540,'warehouse')
    prop('workshop-toolboard','wall_toolboard',300,-75,depth=y+95)
    prop('expansion-0','shift_board',1090,-80,depth=y+95)
    prop('workshop-sign','room_sign',605,h-60,depth=y+h+20)
    # Relocate existing utilities without changing their saved identities.
    for identifier,px,py in [('expansion-1',470,-70),('expansion-2',1140,-70),('expansion-3',1260,-15),('expansion-4',25,55)]:
        if identifier in by_id:
            f=by_id[identifier]; f['rect'][0]=x+px; f['rect'][1]=y+py; edited.append(identifier)
    for gate_id,fixture_id in [('workshop-entry','workshop-entry-visual45'),('workshop-entry-east','workshop-entry-east-visual45')]:
        gate=next(g for g in room['access_doors'] if g['id']==gate_id)
        gate['asset_id']='doorway_workshop_open_v1'
        f=by_id[fixture_id]; f.update(asset_id='doorway_workshop_open_v1',open_asset='doorway_workshop_open_v1',closed_asset='doorway_workshop_closed_v1',render_size=[180,120]); edited.append(fixture_id)
    # Clear the east exit's straight approach without rebuilding the corridor.
    hall=by_id.get('activity-table-1')
    if hall:
        target=min(hall['rect'][0],x+800); dx=target-hall['rect'][0]
        for identifier in ['activity-table-1','detail44-hall-linen-1','detail44-hall-cups-1']:
            if identifier in by_id:
                by_id[identifier]['rect'][0]+=dx; edited.append(identifier)
    room['routine_points']['work']=[[x+350,y+390],[x+850,y+390],[x+350,y+580]]
    room['workshop']['overseer_start']=[x+610,y+400]
    room['workshop']['patrol']=[[x+610,y+400],[x+610,y+160],[x+1100,y+160],[x+1100,y+580],[x+610,y+580]]
    room['workshop_restoration_version']=1
    assert sha(path)==digest, 'Saved map changed; rerun against the latest save.'
    if not (DOC/'initial-input-map.json').exists():
        original=DOC/'last-input-map.json'
        (DOC/'initial-input-map.json').write_bytes(original.read_bytes() if original.exists() else before)
    (DOC/'last-input-map.json').write_bytes(before)
    write(path,room); (DOC/'last-output-map.json').write_bytes(path.read_bytes())
    write(DOC/'map-registration.json',dict(map_before_sha256=digest,map_after_sha256=sha(path),area=area,
        selected_walls=selected,edited_fixture_ids=edited))
    print('Restored workshop only; both original gates and labour rules preserved.')

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--definitions-only',action='store_true'); args=parser.parse_args()
    assets=definitions()
    if not args.definitions_only: restore_map(assets)
    print('Registered unchanged original workshop sources and reusable equipment.')
