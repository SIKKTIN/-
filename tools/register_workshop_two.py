"""Compact Workshop One at its latest authored position and install revision 2."""
from copy import deepcopy
from pathlib import Path
import argparse, hashlib, json
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/workshop-one-restoration'
def read(p): return json.loads(p.read_bytes())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,data):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(data,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')

def definitions():
    result=[]; records=[]
    for job in read(DOC/'generated-assets-v2.json')['assets']:
        p=ROOT/job['path']
        assert sha(p)==sha(Path(job['source']))
        with Image.open(p) as im:
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
            x,y,r,b=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
            # Select the complete opaque furniture without editing source pixels.
            x=max(0,x-3);y=max(0,y-3);r=min(im.width,r+3);b=min(im.height,b+3)
            region=[x,y,r-x,b-y]; size=list(im.size)
        width=82 if job['key'].startswith('west_') else job['width']
        w,h=region[2:]; height=width*h/w
        ground=height if job['key']=='final_assembly' else 70 if job['key'].startswith('west_') else 90 if job['key']=='workbench' else 63 if job['key']=='wood_crate' else 34 if job['key']=='east_bits' else 30
        assert ground<=height
        a=dict(id='workshop2_'+job['key'],name='一号车间二版 · '+job['name'],texture='res://'+job['path'],texture_size=size,
            region=region,ground_rect=[0,h-ground/width*w,w,ground/width*w],render_size=[width,height],world_size=[width,height],
            footprint_world_size=[width,ground],elevation_world=height-ground,render_mode='projected_prop',
            blocking=job['key']!='final_assembly',interactive=False,shadow_baked=False,proportion_locked=True,editor_subcategory='misc' if job['key']=='final_assembly' else 'furnishings',
            source_kind='built-in-imagegen-original-png',alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',sha256=sha(p))
        result.append(a);records.append(dict(key=job['key'],path=job['path'],sha256=sha(p),region=region,render_size=a['render_size'],footprint=a['footprint_world_size']))
    legacy={a['id']:a for a in read(ROOT/'art/props/workshop_one_v1/manifest.json')['assets']}
    for key in ['fitting_tools','motor_assembly','copper_winding','housings']:
        a=deepcopy(legacy['workshop_'+key+'_v1']);w,h=a['region'][2:];scale=250/w;height=h*scale
        a.update(id='workshop2_'+key,name='一号车间二版 · '+a['name'].split(' · ')[-1],render_size=[250,height],world_size=[250,height],
            footprint_world_size=[250,height],ground_rect=[0,0,w,h],elevation_world=0,blocking=False)
        result.append(a)
    for source,key,width,ground in [('north_parts_rack','open_parts',78,34),('parts_drawers','drawers',88,30),('electrical_cabinet','electrical',50,30),('drill','floor_drill',96,85),('drums','drums',70,45),('crates','crates',65,53)]:
        a=deepcopy(legacy['workshop_'+source+'_v1']);oldw=a['render_size'][0];height=a['render_size'][1]*width/oldw;w,h=a['region'][2:]
        a.update(id='workshop2_'+key,name='一号车间二版 · '+a['name'].split(' · ')[-1],render_size=[width,height],world_size=[width,height],
            footprint_world_size=[width,ground],ground_rect=[0,h-ground/width*w,w,ground/width*w],elevation_world=height-ground)
        result.append(a)
    write(ROOT/'art/props/workshop_one_v2/manifest.json',dict(schema=2,version='workshop-one-v2',assets=result))
    write(DOC/'asset-registration-v2.json',dict(mode='built-in-imagegen',assets=records))
    return {a['id']:a for a in result}

def compact(room):
    previous=next(v['rect'] for v in room['visibility_rooms'] if v['id']=='workshop')
    x,y,oldw,oldh=previous; w,h=1200,600
    assert oldw>=w and oldh>=h and x%20==0 and y%20==0, previous
    surfaces={int(v['wall_index']):v for v in room['architecture']['wall_surfaces']}
    selected={i for i,s in surfaces.items() if s.get('grid_tile_asset','').startswith('workshop_')}
    for i,s in surfaces.items():
        rx,ry,rw,rh=room['walls'][i]
        if s.get('grid_tile_asset') in ['prison_t_e','prison_t_w'] and ry==y+oldh-100 and rx in [x-20,x+oldw-20]:selected.add(i)
    assert selected
    # Preserve every other wall and its complete surface record, remapping indices.
    walls=[]; saved=[]; remap={}
    for i,r in enumerate(room['walls']):
        if i not in selected:remap[i]=len(walls);walls.append(r)
    for s in room['architecture']['wall_surfaces']:
        if int(s['wall_index']) in remap:
            s=deepcopy(s);s['wall_index']=remap[int(s['wall_index'])];saved.append(s)
    architecture={a['id']:a for a in read(ROOT/'art/architecture/workshop_one_v1/manifest.json')['assets']}
    owned=[]
    def tile(key,rx,ry,rw,rh):
        a=architecture[key];idx=len(walls);walls.append([rx,ry,rw,rh]);owned.append(idx)
        saved.append(dict(wall_index=idx,grid_tile_asset=key,height=20,collision_parts=deepcopy(a['collision_parts'])))
    def horizontal(lo,hi,ry,gaps=()):
        cursor=lo
        while cursor<hi:
            skip=next((b for a,b in gaps if a<=cursor<b),None)
            if skip is not None:cursor=skip;continue
            end=min([hi]+[a for a,b in gaps if a>cursor]);length=min(40,end-cursor)
            tile('workshop_wall_h_short' if length==20 else f'workshop_wall_h_{int((cursor-x+20)%320/20):02d}',cursor,ry,length,120);cursor+=length
    tile('workshop_corner_nw',x-20,y-140,40,120)
    horizontal(x+20,x+w-20,y-140)
    tile('workshop_corner_ne',x+w-20,y-140,40,120)
    bottom=y+h-100
    gaps=[[x+380,x+540],[x+840,x+1000]]
    tile('workshop_corner_sw',x-20,bottom-20,40,140)
    horizontal(x+20,x+w-20,bottom,gaps)
    tile('workshop_corner_se',x+w-20,bottom-20,40,140)
    for lo,hi in gaps:
        for px in [lo,lo+80]:tile('workshop_lintel_80',px,bottom,80,20)
    for px in [x-20,x+w]:
        cursor=y-20
        while cursor<bottom-20:
            length=min(120,bottom-20-cursor)
            tile('workshop_wall_v_long' if length==120 else 'workshop_wall_v_short',px,cursor,20,length);cursor+=length
    room['walls']=walls;room['architecture']['wall_surfaces']=saved
    for key in ['zones','visibility_rooms']:
        next(v for v in room[key] if v['id']=='workshop')['rect']=[x,y,w,h]
    room['workshop']['room_rect']=[x,y,w,h]
    next(v for v in room['zones'] if v['id']=='workshop')['hide_label']=True
    floor=next(v for v in room['floor_regions'] if v['id']=='workshop')
    floor['rect']=[x-20,y-20,w+40,h+40]
    # Released floor is exterior factory paving, with separate regions.
    room['floor_regions']=[v for v in room['floor_regions'] if v['id'] not in ['workshop-south-apron-v2','workshop-east-apron-v2']]
    if oldh>h:room['floor_regions'].append(dict(id='workshop-south-apron-v2',asset_id='common_floor_v46',rect=[x-20,y+h,w+40,oldh-h+40],tile_size=[320,320]))
    if oldw>w:room['floor_regions'].append(dict(id='workshop-east-apron-v2',asset_id='common_floor_v46',rect=[x+w,y-20,oldw-w+20,oldh+40],tile_size=[320,320]))
    gate_ids=['workshop-entry','workshop-entry-east']
    for identifier,gap in zip(gate_ids,gaps):
        next(v for v in room['access_doors'] if v['id']==identifier)['rect']=[gap[0],y+h,160,20]
    for v in room['concept_plan']['horizontal']:
        if v['id']=='workshop-north':v.update(x0=x-20,x1=x+w+20,y=y-20)
        if v['id']=='workshop-hall-divider':v.update(x0=x-20,x1=x+w+20,y=y+h,gaps=gaps)
    return [x,y,w,h],dict(previous_area=previous,removed_wall_indices=sorted(selected),new_wall_indices=owned,retained_wall_remap=remap)

def restore(assets):
    p=ROOT/'data/rooms/r04.json'; raw=p.read_bytes(); digest=sha(p); room=json.loads(raw)
    if room.get('workshop_restoration_version')==2:
        raise RuntimeError('Revision 2 already installed; use --definitions-only to recalibrate assets without reapplying map.')
    area,geometry=compact(room);x,y,w,h=area
    edited=[];removed=[]; north=[];west=[]
    by_id={v['id']:v for v in room['fixtures']}
    def prop(identifier,key,px,py,loot=None,group=None):
        a=assets['workshop2_'+key];f=by_id.get(identifier)
        if f is None:f=dict(id=identifier,workshop_generated=True);room['fixtures'].append(f)
        else:edited.append(identifier)
        f.update(asset_id=a['id'],rect=[x+px,y+py,*a['footprint_world_size']],blocks_movement=True,blocks_sight=False)
        for k in ['render_size','draw_depth','solid_parts']:f.pop(k,None)
        if loot:f.update(loot_profile=loot,loot_location='一号车间',loot_name=a['name'].split(' · ')[-1])
        if group is not None:group.append(identifier)
        return f
    band=[('workshop-north-buckets-v2','bucket_rack','industrial'),('locker_0','high_cabinet_a','tools'),('locker_1','high_cabinet_b','tools'),('locker_2','high_cabinet_c','tools'),
        ('detail44-work-motor-shelf','open_parts','industrial'),('expansion-4','industrial_station',None),('workshop-low-cabinet-a','double_cabinet','tools'),('expansion-0','drawing_cabinet','tools'),
        ('workshop-bench-drill-0','bench_drill',None),('workshop-bench-drill-1','bench_drill',None),('workshop-narrow-machine-v2','slim_machine',None),
        ('workshop-low-cabinet-b','tool_station','tools'),('detail44-parts-0','drawers','industrial'),('workshop-north-drawers','high_cabinet_c','industrial'),('workshop-electrical','electrical',None)]
    cursor=12
    for identifier,key,loot in band:
        f=prop(identifier,key,cursor,65,loot,north);cursor+=f['rect'][2]+4
    assert cursor<=1120,cursor
    for i,(px,py) in enumerate([(170,150),(630,150),(170,345),(630,345)]):
        table=prop('bench_'+str(i),'workbench',px,py)
        overlay=by_id['detail44-bench-tools-'+str(i)];edited.append(overlay['id'])
        # Each loose-object composition covers the usable tabletop more fully.
        attachment=assets['workshop2_'+['fitting_tools','motor_assembly','copper_winding','final_assembly'][i]]
        overlay.update(asset_id=attachment['id'],rect=[x+px+55,y+py+90-assets['workshop2_workbench']['render_size'][1]+8,*attachment['footprint_world_size']],
            draw_depth=table['rect'][1]+table['rect'][3]+1,blocks_movement=False)
        overlay.pop('render_size',None)
    for identifier,key,py in [('workshop-west-drill-v2','west_drill',125),('workshop-west-rack','west_tools',195),('workshop-west-bits-v2','west_bits',280),('workshop-west-assembly-v2','west_assembly',365)]:
        prop(identifier,key,12,py,'industrial',west)
    prop('workshop-west-stock','wood_crate',12,435,'warehouse')
    prop('detail44-drill-0','floor_drill',1050,165)
    prop('detail44-drill-1','floor_drill',1050,335)
    prop('workshop-east-bits-v2','east_bits',1030,270,'industrial')
    prop('detail44-work-drum','drums',1125,262)
    prop('detail44-work-stock-0','crates',1130,433,'warehouse')
    prop('workshop-east-crate-v2','wood_crate',1030,433,'warehouse')
    # Keep the existing trolley asset available, move the authored trolley into
    # the newly exposed east exterior strip rather than delete its identity.
    trolley=by_id['detail44-work-trolley'];trolley['rect'][:2]=[x+w+35,y+410];edited.append(trolley['id'])
    # Existing toolboard is incorporated into the full new tool station.
    removed.append('workshop-toolboard');room['fixtures']=[v for v in room['fixtures'] if v['id'] not in removed]
    sign=by_id['workshop-sign'];sign['rect'][:2]=[x+580,y+h-60];sign['draw_depth']=y+h+20;edited.append(sign['id'])
    for identifier,px,py in [('expansion-1',720,-60),('expansion-2',1050,-45),('expansion-3',1110,-15),('expansion-5',w+25,h-70)]:
        f=by_id[identifier];f['rect'][:2]=[x+px,y+py];edited.append(identifier)
    for gate_id,fid in [('workshop-entry','workshop-entry-visual45'),('workshop-entry-east','workshop-entry-east-visual45')]:
        f=by_id[fid];f['rect']=deepcopy(next(v for v in room['access_doors'] if v['id']==gate_id)['rect']);edited.append(fid)
    points=[[x+350,y+260],[x+810,y+260],[x+350,y+455]]
    room['routine_points']['work']=points
    room['workshop']['overseer_start']=[x+580,y+290]
    room['workshop']['patrol']=[[x+580,y+290],[x+580,y+125],[x+1010,y+125],[x+1010,y+470],[x+580,y+470]]
    # Replace exactly the yellow machine rectangle moved with the room.
    old_area=geometry['previous_area']; ox,oy,ow,oh=old_area
    ground=room['ground_details']; selected=[]
    for i,d in enumerate(ground):
        if d.get('kind')=='line' and d.get('color')=='#b4a368' and all(d.get(k) and ox+ow-270<=d[k][0]<=ox+ow+5 and oy<=d[k][1]<=oy+oh for k in ['from','to']):selected.append(i)
    assert len(selected)==4,selected
    room['ground_details']=[d for i,d in enumerate(ground) if i not in selected]
    corners=[[x+1018,y+125],[x+1190,y+125],[x+1190,y+490],[x+1018,y+490]]
    for i in range(4):room['ground_details'].append(dict(kind='line',color='#b4a368',opacity=.56,width=3,**{'from':corners[i],'to':corners[(i+1)%4]}))
    room['workshop_restoration_version']=2
    room['concept_plan']['workshop_revision_v2']=dict(room_rect=area,north_modules=north,west_modules=west,reference='docs/art/workshop-one-restoration/references/revision2-concept.png')
    assert sha(p)==digest,'Saved map changed during registration; rerun on latest save.'
    (DOC/'revision2-input-map.json').write_bytes(raw)
    write(p,room);(DOC/'revision2-output-map.json').write_bytes(p.read_bytes())
    write(DOC/'map-registration-v2.json',dict(area=area,geometry=geometry,edited_fixture_ids=edited,removed_fixture_ids=removed,
        north_modules=north,west_modules=west,edited_ground_indices=selected,map_before_sha256=digest,map_after_sha256=sha(p)))
    print('Workshop compacted at latest saved position:',area,'north modules:',len(north),'west modules:',len(west))

def refine(assets):
    p=ROOT/'data/rooms/r04.json';digest=sha(p);room=read(p)
    assert room.get('workshop_restoration_version')==2
    x,y,w,h=room['workshop']['room_rect'];by_id={v['id']:v for v in room['fixtures']}
    for i in range(4):
        table=by_id['bench_'+str(i)];table['rect'][2:]=assets['workshop2_workbench']['footprint_world_size']
        key=['fitting_tools','motor_assembly','copper_winding','final_assembly'][i];a=assets['workshop2_'+key]
        f=by_id['detail44-bench-tools-'+str(i)];px,py=table['rect'][:2]
        f.update(asset_id=a['id'],rect=[px+55,py+90-assets['workshop2_workbench']['render_size'][1]+8,*a['footprint_world_size']],draw_depth=py+90+1)
        f.pop('render_size',None)
    for identifier,py in [('workshop-west-drill-v2',125),('workshop-west-rack',195),('workshop-west-bits-v2',280),('workshop-west-assembly-v2',365),('workshop-west-stock',435),('workshop-east-bits-v2',270),('detail44-work-drum',262)]:
        by_id[identifier]['rect'][1]=y+py
    for identifier,profile in [('workshop-north-buckets-v2','industrial'),('expansion-0','tools'),('workshop-west-drill-v2','industrial'),('workshop-west-bits-v2','industrial'),('workshop-west-assembly-v2','industrial'),('workshop-east-bits-v2','industrial'),('workshop-east-crate-v2','warehouse')]:
        f=by_id[identifier];f.update(loot_profile=profile,loot_location='一号车间',loot_name=assets[f['asset_id']]['name'].split(' · ')[-1])
    for identifier,px,py in [('expansion-1',720,-60),('expansion-2',1050,-45),('expansion-3',1110,-15)]:
        by_id[identifier]['rect'][:2]=[x+px,y+py]
    architecture={a['id']:a for a in read(ROOT/'art/architecture/workshop_one_v1/manifest.json')['assets']}
    for surface in room['architecture']['wall_surfaces']:
        idx=int(surface['wall_index']);r=room['walls'][idx];key=surface.get('grid_tile_asset','')
        if key.startswith('workshop2_back_'):
            key=key.replace('workshop2_back_','workshop_',1);surface['grid_tile_asset']=key
            r[1]=y-140;r[3]=120
            surface['collision_parts']=deepcopy(architecture[key]['collision_parts'])
    assert sha(p)==digest,'Map changed during refinement.'
    write(p,room);(DOC/'revision2-output-map.json').write_bytes(p.read_bytes())
    record=read(DOC/'map-registration-v2.json');record['map_after_sha256']=sha(p);write(DOC/'map-registration-v2.json',record)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--definitions-only',action='store_true');parser.add_argument('--refine',action='store_true');args=parser.parse_args()
    assets=definitions()
    if args.refine:refine(assets)
    elif not args.definitions_only:
        restore(assets);refine(assets)
