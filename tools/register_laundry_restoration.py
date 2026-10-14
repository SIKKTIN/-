"""Register original laundry sprites and restyle only the latest saved laundry.

PNG files remain unchanged. Crops, shared door-frame patches and wall assembly
are authoring metadata; the map keeps all existing passages and gate rules.
"""
from copy import deepcopy
import argparse, hashlib, json, shutil
from pathlib import Path
from PIL import Image
from compact_clinic import contains_wall
from register_clinic_architecture import door_parts

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT/'docs/art/laundry-restoration'
SHADER = 'res://art/architecture/v25/safe_edges_v25.gdshader'
def read(p): return json.loads(p.read_bytes())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(value, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')

def definitions():
    originals = {}; records = []
    sources=read(DOC/'generated-assets.json')['assets']+read(DOC/'pipe-assets.json')['assets']
    for item in sources:
        p = ROOT/item['path']; p.parent.mkdir(parents=True, exist_ok=True)
        if not p.exists() or sha(p)!=sha(Path(item['source'])):
            shutil.copyfile(item['source'], p)
        assert sha(p)==sha(Path(item['source']))
        im = Image.open(p)
        if item['transparent']:
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0, item['key']
            x,y,r,b = im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
            x=max(0,x-3); y=max(0,y-3); r=min(im.width,r+3); b=min(im.height,b+3)
        else: x,y,r,b = 0,0,*im.size
        originals[item['key']] = dict(texture='res://'+item['path'],texture_size=list(im.size),region=[x,y,r-x,b-y],
            runtime_size_limit=512,sha256=sha(p),source_kind='built-in-imagegen-original-png',alpha_core_shader=SHADER)
        records.append(dict(key=item['key'],path=item['path'],sha256=sha(p),region=[x,y,r-x,b-y]))
    props=[]
    # Separate ground dimensions from visible sprite height. No global rescaling.
    specs=[('washer','滚筒洗衣机',72,60),('shelf_vertical','窄布草用品架',60,150),
           ('shelf_horizontal','净衣补给架',190,44),('folding_table','布草叠衣台',320,65),
           ('dirty_station','脏衣分拣台',180,65),('sign','洗衣房名称牌',95,1),
           ('supply_pipe','四位供水管',310,1),('downpipe','屋面落水管',20,1)]
    for key,name,width,ground_depth in specs:
        if key not in originals: continue
        a=deepcopy(originals[key]); _,_,w,h=a['region']; scale=width/w; height=h*scale
        main=key not in ['sign','supply_pipe','downpipe']
        a.update(id='laundry_'+key+'_v1',name='洗衣房 · '+name,render_mode='projected_prop' if main else 'wall_attachment',
            world_size=[width,height],render_size=[width,height],footprint_world_size=[width,ground_depth],
            ground_rect=[0,h-ground_depth/scale,w,ground_depth/scale],elevation_world=height-ground_depth,
            blocking=main,interactive=False,shadow_baked=not main,proportion_locked=True,
            editor_subcategory='furnishings' if main else 'attachments')
        if key=='sign':
            # Register outside the room while keeping the plaque on its facade.
            # Otherwise room concealment hides the name whenever the roof closes.
            a.update(ground_rect=[0,h+45/scale,w,1/scale],elevation_world=height+45)
        props.append(a)
    for source,identifier,name in [('wash_basin_v42','laundry_basin_v1','双位搪瓷水池'),('laundry_cart_v42','laundry_cart_v1','帆布布草车')]:
        a=deepcopy(next(v for v in read(ROOT/'art/props/prison_v42/manifest.json')['assets'] if v['id']==source))
        width=150 if source=='wash_basin_v42' else 65; _,_,w,h=a['region']; scale=width/w; g=a['ground_rect']
        a.update(id=identifier,name='洗衣房 · '+name,world_size=[width,h*scale],render_size=[width,h*scale],
            footprint_world_size=[width,g[3]*scale],elevation_world=(h-g[3])*scale,
            proportion_locked=True,editor_subcategory='furnishings',runtime_size_limit=512)
        a.pop('editor_icon',None);props.append(a)
    write(ROOT/'art/props/laundry_v1/manifest.json',dict(schema=2,version='laundry-v1',assets=props))
    floor=deepcopy(originals['floor']);floor.update(id='laundry_tiles_v1',name='洗衣房灰绿防滑方砖',runtime_size_limit=512)
    write(ROOT/'art/environment/laundry_v1/manifest.json',dict(schema=2,assets=[floor]))
    wall=deepcopy(originals['wall']);wx,wy,ww,wh=wall['region']; cap_h=wh*.15
    wall['runtime_size_limit']=1024
    legacy={a['id']:a for version in ['v36','v38'] for a in read(ROOT/f'art/architecture/{version}/manifest.json')['assets']}
    architecture=[]
    def patch(src,dest,**extra):return dict(source=src,destination=dest,role='complete_wall_body',**extra)
    def face(width,phase,y=0):
        result=[];cursor=0
        while cursor<width:
            current=(phase+cursor)%320;length=min(width-cursor,320-current)
            result.append(patch([wx+current/320*ww,wy,length/320*ww,wh],[cursor,y,length,120]));cursor+=length
        return result
    def cap(width,height,x=0,y=0):return patch([wx+ww*.2,wy,height/320*ww,cap_h],[x,y,width,height],rotation_quarters=1)
    def register(identifier,base,patches):
        old=legacy[base];a=deepcopy(wall)
        a.update(id=identifier,name='洗衣房墙体 · '+identifier.removeprefix('laundry_'),render_mode=old['render_mode'],
            world_size=old['render_size'],render_size=old['render_size'],assembly_patches=patches,blocking=False,
            collision_parts=deepcopy(old['collision_parts']),connections=old['connections'],connection_tag='laundry/'+old['connection_tag'],
            authoring_set='laundry-v1',grid_tile={'cell':20,'columns':old['render_size'][0]/20,'rows':old['render_size'][1]/20,'parameterized_shader':False})
        architecture.append(a)
    for i in range(16):register(f'laundry_wall_h_{i:02d}','prison_h_c',face(40,i*20))
    register('laundry_wall_h_short','prison_h_short_c',face(20,40))
    register('laundry_wall_v_long','prison_v_long',[cap(20,120)])
    register('laundry_wall_v_short','prison_v_short',[cap(20,20)])
    for side,base,right,south in [('nw','prison_l_se',False,False),('ne','prison_l_sw',True,False),('sw','prison_l_ne',False,True),('se','prison_l_nw',True,True)]:
        x=20 if right else 0;patches=face(40,60 if right else 0,20 if south else 0)
        patches.append(cap(20,20 if south else 100,x,0 if south else 20))
        joint=cap(20,20,x,20 if south else 0)
        joint['clip_polygon']=([[0,0],[1,0],[1,1]] if south and right else [[0,0],[1,0],[0,1]] if south else [[1,0],[1,1],[0,1]] if right else [[0,0],[1,1],[0,1]])
        patches.append(joint);register('laundry_corner_'+side,base,patches)
    register('laundry_t_e','prison_t_e',face(40,0)+[cap(20,120)])
    for length in [80,20]:register(f'laundry_lintel_{length}',f'prison_lintel_{length}',[patch([wx,wy,length/320*ww,cap_h],[0,0,length,20])])
    # Both states reuse exactly the same open-source header and jamb pixels.
    # Only the two leaves change. Metadata draws from original PNGs unchanged.
    ow,oh=originals['door_open']['region'][2:];ox,oy=originals['door_open']['region'][:2]
    sx,sy=308/ow,150/oh
    def door_patch(asset,absolute,dest=None):
        ax,ay,aw,ah=originals[asset]['region'];px,py,pw,ph=absolute
        return dict(asset='doorway_laundry_'+asset.removeprefix('door_')+'_v1',source=[(px-ax)/aw,(py-ay)/ah,pw/aw,ph/ah],
                    destination=dest if dest is not None else [(px-ox)*sx,(py-oy)*sy,pw*sx,ph*sy])
    frame=[door_patch('door_open',[325,84,1035,62]),door_patch('door_open',[425,146,25,572]),door_patch('door_open',[1235,146,25,572])]
    leaf=door_patch('door_closed',[433,140,815,704],[(450-ox)*sx,(146-oy)*sy,785*sx,572*sy])
    for state in ['open','closed']:
        key='door_'+state;a=deepcopy(originals[key]);_,_,w,h=a['region']
        parts=door_parts(ROOT/'art/architecture/laundry_v1/door_open.png',originals['door_open']['region'],308)
        ratio=150/(oh/ow*308);parts=[[p[0],p[1]*ratio,p[2],p[3]*ratio] for p in parts if p[1]*ratio>=12]
        a.update(id='doorway_laundry_'+state+'_v1',name='洗衣房双扇钢门 · '+('开启' if state=='open' else '关闭'),
            render_mode='embedded_door',world_size=[308,150],render_size=[308,150],footprint_world_size=[180,20],
            ground_rect=[0,0,w,h],blocking=state=='closed',grid_door={'cell':20},editor_subcategory='doors')
        a['door_presentation']=dict(door_art='doorway_laundry_open_v1',door_art_closed='doorway_laundry_closed_v1',
            door_art_size=[308,150],door_closed_patches=[leaf]+frame,visual_solid_parts=parts,
            closed_visual_solid_parts=[leaf['destination']],body_profile='human_silhouette',raised_door=True)
        architecture.append(a)
    write(ROOT/'art/architecture/laundry_v1/manifest.json',dict(schema=2,version='laundry-v1',assets=architecture))
    roof=deepcopy(originals['roof']);roof.update(id='laundry_roof_surface',name='洗衣房蓝灰咬边金属屋面',
        world_size=[900,500],render_mode='architecture_material',opaque=True,blocking=False,fit_roof=True,runtime_size_limit=1024)
    sky=deepcopy(originals['skylight']);sky.update(id='laundry_roof_skylight',name='洗衣房磨砂采光带',
        world_size=[24,108],render_mode='architecture_roof_detail',blocking=False,runtime_size_limit=256)
    write(ROOT/'art/architecture/laundry_v1/roof-manifest.json',dict(schema=2,assets=[roof,sky]))
    write(DOC/'asset-registration.json',dict(mode='built-in imagegen',assets=records,definition_ids=[a['id'] for a in props+architecture]))
    return {a['id']:a for a in props+architecture}

def restore_map(assets):
    path=ROOT/'data/rooms/r04.json';before=path.read_bytes();digest=sha(path);room=json.loads(before)
    area=next(v['rect'] for v in room['visibility_rooms'] if v['id']=='laundry');x,y,w,h=area
    assert [w,h]==[900,480],'Laundry footprint changed; adapt layout before applying.'
    selected=[]
    for s in room['architecture']['wall_surfaces']:
        rect=room['walls'][int(s['wall_index'])]
        if not contains_wall(area,rect):continue
        base=s.get('laundry_base_asset',s['grid_tile_asset'])
        # The latest cafeteria redesign owns this shared north facade. Its
        # connection is explicitly deferred; preserve it and its door art.
        if rect[1]<y and str(base).startswith('cafeteria_'):continue
        if base.startswith('prison_h_short'):identifier='laundry_wall_h_short'
        elif base.startswith('prison_h_'):identifier=f'laundry_wall_h_{int((rect[0]-x+20)%320/20):02d}'
        elif base.startswith('prison_v_'):identifier='laundry_wall_v_short' if rect[3]<=40 else 'laundry_wall_v_long'
        else:identifier={'prison_l_se':'laundry_corner_nw','prison_l_sw':'laundry_corner_ne','prison_l_ne':'laundry_corner_sw',
            'prison_l_nw':'laundry_corner_se','prison_lintel_80':'laundry_lintel_80','prison_lintel_20':'laundry_lintel_20','prison_t_e':'laundry_t_e'}[base]
        assert identifier in assets
        s.update(grid_tile_asset=identifier,laundry_base_asset=base);selected.append(s['wall_index'])
    floor=next(v for v in room['floor_regions'] if v['id']=='laundry')
    floor.update(asset_id='laundry_tiles_v1',manifest='res://art/environment/laundry_v1/manifest.json',tile_size=[250,250])
    vis=next(v for v in room['visibility_rooms'] if v['id']=='laundry');vis.update(roof_style='laundry',retained_wall_edges=True)
    old_ids=['laundry-washer-0','laundry-washer-1','laundry-washer-2','laundry-dryer-0','laundry-dryer-1','laundry-cart',
             'laundry-wash-basin','detail44-wash-linen','detail44-washer-supplies','detail44-wash-dirty-basket']
    room['fixtures']=[v for v in room['fixtures'] if v['id'] not in old_ids and not v.get('laundry_generated',False)]
    door=next(v for v in room['fixtures'] if v['id']=='campus-laundry-south')
    door.update(asset_id='doorway_laundry_open_v1',render_size=[308,150])
    def prop(identifier,key,px,py,loot=None,depth=None):
        asset='laundry_'+key+'_v1';a=assets[asset];f=dict(id=identifier,asset_id=asset,rect=[x+px,y+py,*a['footprint_world_size']],
            blocks_movement=a.get('blocking',True),blocks_sight=False,laundry_generated=True)
        if loot:f.update(loot_profile=loot,loot_location='洗衣房',loot_name=a['name'].split(' · ')[-1])
        if depth is not None:f['draw_depth']=y+depth
        room['fixtures'].append(f);return f
    for i in range(4):prop(f'laundry-washer-{i}','washer',84+i*80,35)
    prop('laundry-cleaning-rack','shelf_vertical',10,10,'linen')
    prop('laundry-clean-linen-shelf','shelf_horizontal',630,10,'linen')
    prop('laundry-wash-basin','basin',670,140)
    prop('laundry-dirty-sorting','dirty_station',20,255,'linen')
    prop('laundry-folding-table','folding_table',430,260,'linen')
    prop('laundry-cart','cart',790,285,'linen')
    prop('laundry-sign','sign',465,h+2,None,501)
    prop('laundry-supply-pipe','supply_pipe',85,-36,None,96)
    if 'laundry_downpipe_v1' in assets:prop('laundry-downpipe','downpipe',w+1,436,None,501)
    # Reuse the existing flat grates; they never become furniture colliders.
    grates=[v for v in room.get('ground_details',[]) if v.get('rect') and x<=v['rect'][0]<x+w and y<=v['rect'][1]<y+h]
    for grate,rect in zip(grates,[[x+174,y+120,142,20],[x+695,y+222,142,20]]):grate['rect']=rect
    room['laundry_restoration_version']=2
    assert room['access_doors']==json.loads(before)['access_doors']
    assert room['walls']==json.loads(before)['walls']
    assert sha(path)==digest,'Saved map changed; rerun with the latest saved draft.'
    (DOC/'last-input-map.json').write_bytes(before);write(path,room);(DOC/'last-output-map.json').write_bytes(path.read_bytes())
    write(DOC/'map-registration.json',dict(map_before_sha256=digest,map_after_sha256=sha(path),area=area,selected_walls=selected,removed_fixture_ids=old_ids))
    print(f'Restored laundry {area}; preserved all gate rules and wall geometry. Restyled {len(selected)} walls.')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--definitions-only',action='store_true');args=parser.parse_args()
    assets=definitions()
    if not args.definitions_only:restore_map(assets)
    print('Registered original laundry PNGs, modular walls, shared door frame and roof.')
