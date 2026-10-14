"""Restore the actual second workshop, reusing Workshop One's current steel door.

Unlike register_workshop_two.py (Workshop One revision 2), this script targets
the workshop-two room. It updates only its art, furniture and doorway visuals.
"""
from copy import deepcopy
from pathlib import Path
import argparse, hashlib, json, shutil
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/workshop-two-redesign-v01'
SHADER='res://art/architecture/v25/safe_edges_v25.gdshader'
def read(p):return json.loads(p.read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')

def definitions():
    props=[];records=[]
    for item in read(DOC/'generated-assets.json')['assets']:
        p=ROOT/item['path'];p.parent.mkdir(parents=True,exist_ok=True)
        if not p.exists() or sha(p)!=sha(Path(item['source'])):shutil.copyfile(item['source'],p)
        assert sha(p)==sha(Path(item['source']))
        with Image.open(p) as im:
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0,item['key']
            x,y,r,b=im.getchannel('A').point(lambda v:255 if v>=180 else 0).getbbox()
            x=max(0,x-3);y=max(0,y-3);r=min(im.width,r+3);b=min(im.height,b+3)
            region=[x,y,r-x,b-y];size=list(im.size)
        key=item['key'];w,h=region[2:];scale=item['width']/w;height=h*scale
        ground=height-10 if key=='stock_rack' else min(item['ground'],height*.96)
        wall=key=='sign'
        a=dict(id='workshop_two_'+key+'_v1',name='二号车间 · '+item['name'],texture='res://'+item['path'],texture_size=size,
            region=region,ground_rect=[0,h-ground/scale,w,ground/scale],world_size=[item['width'],height],render_size=[item['width'],height],
            footprint_world_size=[item['width'],ground],elevation_world=height-ground,proportion_locked=True,
            render_mode='wall_attachment' if wall else 'projected_prop',blocking=not wall,interactive=False,shadow_baked=False,
            runtime_size_limit=256 if wall else 768,alpha_core_shader=SHADER,editor_subcategory='attachments' if wall else 'furnishings',
            source_kind='built-in-imagegen-original-png',sha256=sha(p))
        if wall:
            # Outside registration keeps the name visible when the roof closes.
            a.update(ground_rect=[0,h+19/scale,w,1/scale],footprint_world_size=[item['width'],1],elevation_world=height+19)
        props.append(a);records.append(dict(key=key,path=item['path'],sha256=sha(p),region=region))
    old={a['id']:a for a in read(ROOT/'art/props/workshop_one_v2/manifest.json')['assets']}
    reuse=[('drawers','parts_drawers','零件抽屉柜',100,32),('open_parts','parts_shelf','开放零件架',120,40),
           ('double_cabinet','tool_cabinet','双门工具柜',100,32),('high_cabinet_b','tall_cabinet','工具立柜',68,32),
           ('tool_station','tool_station','沿墙工具台',100,38),('electrical','electrical','电控柜',60,35),
           ('east_bits','bits','刀具架',85,38),('wood_crate','crate','物资木箱',80,55),('drums','drums','油桶',75,45)]
    for source,key,name,width,ground in reuse:
        a=deepcopy(old['workshop2_'+source]);w,h=a['region'][2:];scale=width/w
        a.update(id='workshop_two_'+key+'_v1',name='二号车间 · '+name,world_size=[width,h*scale],render_size=[width,h*scale],
            ground_rect=[0,h-ground/scale,w,ground/scale],footprint_world_size=[width,ground],elevation_world=h*scale-ground,
            blocking=True,proportion_locked=True,runtime_size_limit=512,editor_subcategory='furnishings',reused_from='workshop2_'+source)
        a.pop('editor_icon',None);props.append(a)
    old={a['id']:a for a in read(ROOT/'art/props/prison_v17/manifest.json')['assets']}
    for source,key,name in [('caged_wall_lamp','wall_lamp','笼罩壁灯'),('pipe_valve','pipe','墙面管线')]:
        a=deepcopy(old[source]);a.update(id='workshop_two_'+key+'_v1',name='二号车间 · '+name,runtime_size_limit=256,
            editor_subcategory='attachments',proportion_locked=True,reused_from=source)
        a.pop('editor_icon',None);props.append(a)
    write(ROOT/'art/props/workshop_two_v1/manifest.json',dict(schema=2,version='workshop-two-v1',assets=props))
    write(DOC/'asset-registration.json',dict(mode='built-in imagegen',assets=records,definition_ids=[a['id'] for a in props],
        reused=[dict(id=a['id'],source=a['reused_from'],texture=a['texture'])for a in props if a.get('reused_from')],
        door='res://art/architecture/workshop_door_v2/manifest.json',wall='res://art/architecture/workshop_one_v1/manifest.json'))
    return {a['id']:a for a in props}

def restore(assets):
    path=ROOT/'data/rooms/r04.json';before=path.read_bytes();digest=sha(path);d=json.loads(before)
    vis=next(v for v in d['visibility_rooms'] if v['id']=='workshop-two');x,y,w,h=vis['rect']
    assert [w,h]==[1460,720], 'Second workshop footprint changed: recalibrate before applying.'
    surfaces=[]
    for s in d['architecture']['wall_surfaces']:
        rx,ry,rw,rh=d['walls'][int(s['wall_index'])]
        if not (x-20<=rx and y-140<=ry and rx+rw<=x+w+20 and ry+rh<=y+h+40):continue
        base=s.get('workshop_two_base_asset',s['grid_tile_asset'])
        if base.startswith('prison_h_short'):key='workshop_wall_h_short'
        elif base.startswith('prison_h_'):key=f'workshop_wall_h_{int((rx-x+20)%320/20):02d}'
        else:key={'prison_v_long':'workshop_wall_v_long','prison_v_short':'workshop_wall_v_short',
            'prison_l_se':'workshop_corner_nw','prison_l_sw':'workshop_corner_ne','prison_l_ne':'workshop_corner_sw',
            'prison_l_nw':'workshop_corner_se','prison_lintel_80':'workshop_lintel_80','prison_lintel_20':'workshop_lintel_20'}[base]
        s.update(grid_tile_asset=key,workshop_two_base_asset=base);surfaces.append(int(s['wall_index']))
    floor=next(v for v in d['floor_regions'] if v['id']=='campus-workshop-two')
    floor.update(asset_id='workshop_tiles_v1',manifest='res://art/environment/workshop_one_v1/manifest.json',tile_size=[160,160])
    vis.update(roof_style='workshop_two',retained_wall_edges=True)
    for v in d.get('zones',[]):
        if v['id']=='workshop-two':v['hide_label']=True
    old_ids=[f['id'] for f in d['fixtures'] if f['id'].startswith('campus-work-two-')]
    d['fixtures']=[f for f in d['fixtures'] if f['id'] not in old_ids and not f.get('workshop_two_generated',False)]
    def prop(identifier,key,px,py,loot=None,depth=None):
        a=assets['workshop_two_'+key+'_v1'];f=dict(id=identifier,asset_id=a['id'],rect=[x+px,y+py,*a['footprint_world_size']],
            blocks_movement=a['blocking'],blocks_sight=False,workshop_two_generated=True)
        if loot:f.update(loot_profile=loot,loot_location='二号车间',loot_name=a['name'].split(' · ')[-1])
        if depth is not None:f['draw_depth']=depth
        d['fixtures'].append(f);return f
    machines=[]
    for identifier,key,px,py in [('campus-work-two-bench-0','lathe',210,180),('campus-work-two-bench-1','vertical_mill',1000,180),
                                ('campus-work-two-bench-2','lathe',210,430),('campus-work-two-bench-3','precision_lathe',920,430)]:
        machines.append(prop(identifier,key,px,py))
    # Original container identities survive; their saved loot remains associated.
    north=[('parts_shelf',110),('parts_drawers',245),('tall_cabinet',365),('tool_cabinet',455),('parts_shelf',575),('tall_cabinet',710),
           ('parts_drawers',1030),('parts_shelf',1150),('electrical',1330)]
    for i,(key,px) in enumerate(north):
        identifier='campus-work-two-parts' if i==1 else 'campus-work-two-locker' if i==3 else f'workshop-two-north-{i}'
        prop(identifier,key,px,25,'industrial' if key in ['parts_shelf','parts_drawers'] else 'tools' if key in ['tall_cabinet','tool_cabinet'] else None)
    prop('workshop-two-stock-rack','stock_rack',20,105,'industrial')
    prop('workshop-two-east-tool-station','tool_station',1340,160,'tools')
    prop('workshop-two-east-bits','bits',1345,270,'tools')
    prop('workshop-two-corner-crate','crate',1290,350,'warehouse')
    prop('workshop-two-corner-drums','drums',1380,570)
    prop('workshop-two-sign','sign',680,h+4,depth=y+h+42)
    prop('workshop-two-north-lamp','wall_lamp',460,-48,depth=y+75)
    prop('workshop-two-north-pipe','pipe',1300,-10,depth=y+75)
    door_ids=[]
    for side in ['north','south','east']:
        f=next(v for v in d['fixtures'] if v['id']=='campus-workshop-two-'+side)
        f.update(asset_id='doorway_workshop_open_v2',open_asset='doorway_workshop_open_v2',closed_asset='doorway_workshop_closed_v2',render_size=[180,120])
        # Use the editor's existing rotated-door rectangle convention, so the
        # east-facing frame, leaf pixels and full-body collision agree exactly.
        if side=='east':
            gx,gy,gw,gh=f['rect'];f.update(rotation_quarters=1,rotation_door_visual_rect=[gx+gw-120,gy+gh/2-90,120,180])
        door_ids.append(f['id'])
    moved=[]
    lamp=next((f for f in d['fixtures'] if f['id']=='campus-yard-lamp-1'),None)
    gate=next(f for f in d['fixtures'] if f['id']=='campus-workshop-two-north')
    if lamp and gate['rect'][0]<=lamp['rect'][0]+lamp['rect'][2]/2<=gate['rect'][0]+gate['rect'][2]:
        lamp['rect'][0]=gate['rect'][0]-110;moved.append(lamp['id'])
    d['ground_details']=[v for v in d.get('ground_details',[]) if not v.get('workshop_two_generated',False)]
    for f in machines:
        rx,ry,rw,rh=f['rect'];pad=10;length=16
        for cx,cy,dx,dy in [(rx-pad,ry-pad,1,1),(rx+rw+pad,ry-pad,-1,1),(rx-pad,ry+rh+pad,1,-1),(rx+rw+pad,ry+rh+pad,-1,-1)]:
            for end in [[cx+dx*length,cy],[cx,cy+dy*length]]:
                d['ground_details'].append(dict(kind='line',**{'from':[cx,cy],'to':end},width=3,color='#c8a74d',opacity=.58,workshop_two_generated=True))
    d['workshop_two_restoration_version']=1
    original=json.loads(before)
    assert d['walls']==original['walls'] and d['access_doors']==original['access_doors']
    assert sha(path)==digest,'Saved map changed; rerun against latest disk version.'
    if not (DOC/'initial-input-map.json').exists():(DOC/'initial-input-map.json').write_bytes(before)
    (DOC/'last-input-map.json').write_bytes(before);write(path,d);(DOC/'last-output-map.json').write_bytes(path.read_bytes())
    write(DOC/'map-registration.json',dict(input_sha256=digest,output_sha256=sha(path),area=vis['rect'],selected_walls=surfaces,
        replaced_fixture_ids=old_ids,door_fixture_ids=door_ids,moved_fixture_ids=moved,door_asset='doorway_workshop_open_v2'))
    print(f'Restored second workshop: {len(machines)} machines, {len(surfaces)} wall tiles; all three doors reuse Workshop One v2.')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--definitions-only',action='store_true');args=parser.parse_args()
    assets=definitions()
    if not args.definitions_only:restore(assets)
