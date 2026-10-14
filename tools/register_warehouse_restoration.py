"""Register original warehouse sprites and selectively restore the saved R04 warehouse."""
from copy import deepcopy
from pathlib import Path
import argparse, hashlib, json, shutil, os, tempfile
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/warehouse-redesign-v01'
SHADER='res://art/architecture/v25/safe_edges_v25.gdshader'
def read(p):return json.loads(p.read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    # Godot may read the saved map while importing new art; replace a complete
    # sibling file rather than truncating a file being watched/read.
    with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=p.parent,prefix=p.name+'.',suffix='.tmp',delete=False) as out:
        out.write(json.dumps(v,ensure_ascii=False,indent='\t')+'\n');temp=Path(out.name)
    os.replace(temp,p)

def definitions():
    assets=[];records=[]
    for item in read(DOC/'generated-assets.json')['assets']:
        p=ROOT/item['path'];p.parent.mkdir(parents=True,exist_ok=True)
        if not p.exists() or sha(p)!=sha(Path(item['source'])):shutil.copyfile(item['source'],p)
        with Image.open(p) as im:
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
            x,y,r,b=im.getchannel('A').point(lambda v:255 if v>=180 else 0).getbbox()
            x=max(0,x-3);y=max(0,y-3);r=min(im.width,r+3);b=min(im.height,b+3)
            region=[x,y,r-x,b-y];size=list(im.size)
        key=item['key'];w,h=region[2:]
        width=140 if key in ['rack_parts','rack_goods'] else item['width']
        target_ground=830 if key=='rack_parts' else 800 if key=='rack_goods' else item['ground']
        scale=width/w;visible=h*scale
        ground=min(target_ground,visible-5)
        wall=key=='sign'
        a=dict(id='warehouse_'+key+'_v1',name='仓库 · '+item['name'],texture='res://'+item['path'],texture_size=size,region=region,
            ground_rect=[0,h-ground/scale,w,ground/scale],footprint_world_size=[width,ground],world_size=[width,visible],render_size=[width,visible],
            elevation_world=visible-ground,render_mode='wall_attachment' if wall else 'projected_prop',blocking=not wall,interactive=False,
            shadow_baked=False,proportion_locked=True,runtime_size_limit=item['limit'],alpha_core_shader=SHADER,
            editor_subcategory='attachments' if wall else 'furnishings',source_kind='built-in-imagegen-original-png',sha256=sha(p))
        if wall:a.update(ground_rect=[0,h+19/scale,w,1/scale],footprint_world_size=[item['width'],1],elevation_world=visible+19)
        assets.append(a);records.append(dict(key=key,path=item['path'],sha256=sha(p),region=region))
    # Reuse already calibrated packaging and the existing hand pallet truck.
    old={a['id']:a for m in ['art/props/factory_v44/manifest.json','art/props/workshop_one_v2/manifest.json','art/props/prison_v17/manifest.json']for a in read(ROOT/m)['assets']}
    for source,key,name,width,ground in [('shipping_crates_v44','crate','待运木箱',75,60),('sack_pallet_v44','packages','捆装物资',75,60),
        ('oil_drums_v44','drums','油桶',75,45),('pallet_jack_v44','jack','手动托盘车',65,139),
        ('workshop2_high_cabinet_b','cabinet','工具立柜',65,32),('caged_wall_lamp','lamp','仓库壁灯',24,1)]:
        a=deepcopy(old[source]);w,h=a['region'][2:];scale=width/w
        a.update(id='warehouse_'+key+'_v1',name='仓库 · '+name,world_size=[width,h*scale],render_size=[width,h*scale],
            ground_rect=[0,h-ground/scale,w,ground/scale],footprint_world_size=[width,ground],elevation_world=max(0,h*scale-ground),
            blocking=key!='lamp',proportion_locked=True,runtime_size_limit=256 if key=='lamp' else 512,reused_from=source,editor_subcategory='attachments' if key=='lamp' else 'furnishings')
        a.pop('editor_icon',None);assets.append(a)
    write(ROOT/'art/props/warehouse_v1/manifest.json',dict(schema=2,version='warehouse-v1',assets=assets))
    write(DOC/'asset-registration.json',dict(mode='built-in imagegen',assets=records,definition_ids=[a['id']for a in assets],
        reused=[dict(id=a['id'],source=a['reused_from'],texture=a['texture'])for a in assets if a.get('reused_from')],
        door='res://art/architecture/workshop_door_v2/manifest.json',wall='res://art/architecture/workshop_one_v1/manifest.json'))
    return {a['id']:a for a in assets}

def restore(assets):
    path=ROOT/'data/rooms/r04.json';before=path.read_bytes();digest=sha(path);d=json.loads(before);original=deepcopy(d)
    room=next(v for v in d['visibility_rooms']if v['id']=='warehouse')
    assert room['rect'][1:]==[1060,760,2160] or room['rect']==[4280,1060,840,2160], 'Warehouse bounds changed; recalibrate.'
    # Existing physical west wall/door is at 4260, not the old visible-region x=4360.
    room.update(rect=[4280,1060,840,2160],roof_style='warehouse',retained_wall_edges=True)
    for v in d.get('zones',[]):
        if v['id']=='warehouse':v.update(rect=room['rect'].copy(),hide_label=True)
    floor=next(v for v in d['floor_regions']if v['id']=='campus-warehouse')
    floor.update(rect=[4280,1040,860,2220],asset_id='workshop_tiles_v1',manifest='res://art/environment/workshop_one_v1/manifest.json',tile_size=[160,160])
    # Repair the authored southwest step: the last west tile was 80px inside
    # the rest of that wall, leaving a bypass gap beside the old corner.
    repairs={}
    for old_rect,rect,base,parts in [([4340,3000,20,120],[4260,3000,20,120],'prison_v_long',[[0,0,20,120]]),
        ([4260,3140,40,120],[4260,3120,40,140],'prison_l_ne',[[0,120,40,20],[0,0,20,140]]),
        ([4320,3140,40,120],[4320,3140,20,120],'prison_h_short',[[0,100,20,20]]),
        ([4340,3120,40,140],[4340,3140,40,120],'prison_h_e',[[0,100,40,20]])]:
        expected=rect if d.get('warehouse_boundary_repair_version') else old_rect
        assert expected in d['walls'], 'Warehouse corner geometry changed; recalibrate.'
        repairs[d['walls'].index(expected)]=(rect,base,parts)
    for index,(rect,base,parts)in repairs.items():
        d['walls'][index]=rect
        s=next(v for v in d['architecture']['wall_surfaces']if int(v['wall_index'])==index)
        s.update(warehouse_base_asset=base,collision_parts=parts)
    d['warehouse_boundary_repair_version']=1
    selected=[]
    for s in d['architecture']['wall_surfaces']:
        rx,ry,rw,rh=d['walls'][int(s['wall_index'])]
        if not (int(s['wall_index']) in repairs or (4340<=rx and rx+rw<=5140 and (ry==940 or 3120<=ry<=3140)) or (rx in [4260,4340,5120]and 1060<=ry<3120 and rw<=20)):continue
        base=s.get('warehouse_base_asset',s['grid_tile_asset'])
        if base.startswith('prison_h_short'):key='workshop_wall_h_short'
        elif base.startswith('prison_h_'):key=f'workshop_wall_h_{int((rx-4340)%320/20):02d}'
        else:key={'prison_v_long':'workshop_wall_v_long','prison_v_short':'workshop_wall_v_short',
            'prison_l_se':'workshop_corner_nw','prison_l_sw':'workshop_corner_ne','prison_l_ne':'workshop_corner_sw',
            'prison_l_nw':'workshop_corner_se','prison_lintel_80':'workshop_lintel_80','prison_lintel_20':'workshop_lintel_20'}.get(base)
        if key:s.update(grid_tile_asset=key,warehouse_base_asset=base);selected.append(int(s['wall_index']))
    doors=[f['id']for f in d['fixtures']if f['id'].startswith('campus-warehouse-')and 'doorway' in f['asset_id']]
    old=[f for f in d['fixtures']if 'warehouse' in f['id']and f['id']not in doors]
    old_by={f['id']:f for f in old};old_ids=list(old_by)
    legacy=read(DOC/'initial-input-map.json') if (DOC/'initial-input-map.json').exists() else original
    legacy_by={f['id']:f for f in legacy['fixtures']}
    d['fixtures']=[f for f in d['fixtures']if f['id']not in old_ids and not f.get('warehouse_generated',False)]
    def prop(identifier,key,px,py,loot='warehouse',depth=None):
        a=assets['warehouse_'+key+'_v1'];f=deepcopy(old_by.get(identifier,{}))
        f.update(id=identifier,asset_id=a['id'],rect=[px,py,*a['footprint_world_size']],blocks_movement=a['blocking'],blocks_sight=False,warehouse_generated=True)
        if loot:f.update(loot_profile=legacy_by.get(identifier,{}).get('loot_profile',f.get('loot_profile',loot)),loot_location='仓库',loot_name=a['name'].split(' · ')[-1])
        else:
            for k in ['loot_profile','loot_location','loot_name']:f.pop(k,None)
        if depth is not None:f['draw_depth']=depth
        d['fixtures'].append(f);return f
    # Four coherent central rack runs; the other existing rack IDs become peripheral shelves.
    for identifier,key,x,y in [('warehouse-rack-0','rack_parts',4490,1240),('warehouse-rack-1','rack_parts',4770,1240),
                              ('warehouse-rack-3','rack_goods',4490,2300),('warehouse-rack-4','rack_goods',4770,2300)]:prop(identifier,key,x,y)
    remaining=['warehouse-rack-2','warehouse-rack-5','warehouse-rack-6','warehouse-rack-7','campus-warehouse-extra-0','campus-warehouse-extra-1','campus-warehouse-extra-2']
    positions=[(4300,1120),(4300,1470),(4300,1820),(4300,2450),(4300,2800),(5040,1550),(5040,1920)]
    for identifier,(x,y)in zip(remaining,positions):prop(identifier,'wall_rack',x,y)
    for identifier,x in [('detail44-warehouse-crates-0',4380),('detail44-warehouse-crates-1',4540),('detail44-warehouse-crates-2',4700),('detail44-warehouse-motor-shelf',4860)]:prop(identifier,'north_shelf',x,1090)
    prop('warehouse-high-cabinet','cabinet',5020,1110,'tools')
    prop('detail44-warehouse-parts','registration_desk',4330,2150,'industrial')
    prop('detail44-warehouse-crates-3','crate',4380,3000)
    prop('detail44-warehouse-crates-4','crate',5000,1210)
    prop('detail44-warehouse-crates-5','crate',5000,2250)
    prop('detail44-warehouse-crates-6','crate',4935,3020)
    prop('detail44-warehouse-packages','packages',5000,2330)
    prop('detail44-warehouse-drums-0','drums',5040,3030,None)
    prop('detail44-warehouse-drums-1','drums',5000,1290,None)
    prop('detail44-warehouse-jack','jack',5000,2460,None)
    prop('warehouse-nameplate','sign',4800,3262,None,depth=3270)
    prop('warehouse-wall-lamp-0','lamp',4640,1005,None,depth=1130)
    prop('warehouse-wall-lamp-1','lamp',4930,1005,None,depth=1130)
    for f in d['fixtures']:
        if f['id']not in doors:continue
        f.update(asset_id='doorway_workshop_open_v2',open_asset='doorway_workshop_open_v2',closed_asset='doorway_workshop_closed_v2',render_size=[180,120])
        if f['id']!='campus-warehouse-south':
            gx,gy,gw,gh=f['rect'];west=f['id'].endswith('west')
            f.update(rotation_quarters=3 if west else 1,rotation_door_visual_rect=[gx if west else gx+gw-120,gy+gh/2-90,120,180])
    retained=set(f['id']for f in d['fixtures']);assert all(f['id']in retained for f in old if f.get('loot_profile'))
    removed_details=[];kept=[]
    for i,v in enumerate(d.get('ground_details',[])):
        p=v.get('position',v.get('from',[-1,-1]))
        if v.get('warehouse_generated') or 4280<=p[0]<5120 and 1060<=p[1]<3220:removed_details.append(i)
        else:kept.append(v)
    d['ground_details']=kept
    for fx,fy,fw,fh in [(4975,2430,120,190),(4975,2225,120,160)]:
        for start,end in [([fx,fy],[fx+fw,fy]),([fx+fw,fy],[fx+fw,fy+fh]),([fx+fw,fy+fh],[fx,fy+fh]),([fx,fy+fh],[fx,fy])]:
            d['ground_details'].append(dict(kind='line',**{'from':start,'to':end},width=3,color='#b6a056',opacity=.6,warehouse_generated=True))
    d['warehouse_restoration_version']=1
    d['crate']=[4500,2160,95,77]
    moved_items=[]
    for i,v in enumerate(d.get('items',[])):
        px,py=v['position']
        if 4280<=px<5120 and 1060<=py<3220:
            if v['definition_id']=='lock_tool':v['position']=[4690,1480 if py<2000 else 2180]
            elif v['definition_id']=='door_key':v['position']=[4970,2760]
            if v!=original['items'][i]:moved_items.append(i)
    assert all(v==original['walls'][i]for i,v in enumerate(d['walls'])if i not in repairs)and d['access_doors']==original['access_doors']
    assert sha(path)==digest, 'Saved map changed; rerun against current disk map.'
    if not(DOC/'initial-input-map.json').exists():(DOC/'initial-input-map.json').write_bytes(before)
    (DOC/'last-input-map.json').write_bytes(before);write(path,d);(DOC/'last-output-map.json').write_bytes(path.read_bytes())
    write(DOC/'map-registration.json',dict(input_sha256=digest,output_sha256=sha(path),selected_walls=selected,replaced_fixture_ids=old_ids,
        door_fixture_ids=doors,removed_ground_details=removed_details,modified_wall_indices=list(repairs),moved_item_indices=moved_items,
        old_area=original['visibility_rooms'][[v['id']for v in original['visibility_rooms']].index('warehouse')]['rect'],area=room['rect']))
    print('Warehouse restored: four central racks, seven peripheral racks, existing container IDs and four doors retained.')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--definitions-only',action='store_true');args=parser.parse_args()
    assets=definitions()
    if not args.definitions_only:restore(assets)
