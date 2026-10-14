"""Continuous editable pipe assemblies, using unchanged original PNG pixels."""
from pathlib import Path
import json, hashlib, tempfile, os, math

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs/art/equipment-pipes-v2'
ART = ROOT / 'art/props/equipment_pipes_v2'
TEXTURE = 'res://art/props/pipe_energy_court_v1/pipe-fittings.png'
SCALE = .24
SOURCE = ROOT / TEXTURE.removeprefix('res://')
BODY = {'red':[239,600,63,105], 'blue':[738,595,63,89]}
COLLAR = {'red':[220,711,102,43], 'blue':[715,684,110,44]}
ELBOW = {'red':([764,191,99,102],[824,260], [(-1,0),(0,-1)]),
         'blue':([1188,248,113,89],[1224,305], [(0,-1),(1,0)])}

def read(path): return json.loads(path.read_bytes())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path, value):
    path.parent.mkdir(parents=True,exist_ok=True)
    fd,tmp=tempfile.mkstemp(dir=path.parent,prefix=path.name+'.',suffix='.writing')
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as f:
            f.write(json.dumps(value,ensure_ascii=False,indent='\t')+'\n')
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)

def rotate(p,q):
    x,y=p
    for _ in range(q):x,y=-y,x
    return (x,y)

def patches(color,points):
    result=[]
    def patch(src,dst,role,q=0):
        result.append(dict(source=src,destination=dst,rotation_quarters=q,role=role))
    for i,(a,b) in enumerate(zip(points,points[1:])):
        x,y=a;bx,by=b;vertical=x==bx
        assert vertical or y==by, (a,b)
        length=abs(by-y) if vertical else abs(bx-x)
        start=min(y,by) if vertical else min(x,bx)
        # The curved fittings overlap each body by a few source pixels.
        trim_a=14 if i>0 else 0
        trim_b=14 if i<len(points)-2 else 0
        if (by-y if vertical else bx-x)<0:trim_a,trim_b=trim_b,trim_a
        start+=trim_a;length-=trim_a+trim_b
        assert length>0,(points,i)
        src=BODY[color];width=src[2]*SCALE;period=src[3]*SCALE
        cursor=0
        while cursor<length-1e-6:
            step=min(period,length-cursor)
            region=src[:];region[3]=step/SCALE
            dst=[x-width/2,start+cursor,width,step] if vertical else [start+cursor,y-width/2,step,width]
            patch(region,dst,'continuous_body',0 if vertical else 1)
            cursor+=step
        collar=COLLAR[color];cw,ch=collar[2]*SCALE,collar[3]*SCALE
        cursor=45
        while cursor<length-20:
            dst=[x-cw/2,start+cursor-ch/2,cw,ch] if vertical else [start+cursor-ch/2,y-cw/2,ch,cw]
            patch(collar,dst,'flanged_support',0 if vertical else 1)
            cursor+=125
    for i in range(1,len(points)-1):
        c=points[i];a=points[i-1];b=points[i+1]
        directions={(int(math.copysign(1,p[0]-c[0])) if p[0]!=c[0] else 0,
                     int(math.copysign(1,p[1]-c[1])) if p[1]!=c[1] else 0) for p in [a,b]}
        src,anchor,base=ELBOW[color]
        q=next(q for q in range(4) if {rotate(v,q) for v in base}==directions)
        corners=[rotate(((xx-anchor[0])*SCALE,(yy-anchor[1])*SCALE),q)
                 for xx in [src[0],src[0]+src[2]] for yy in [src[1],src[1]+src[3]]]
        xs,ys=zip(*corners)
        patch(src,[c[0]+min(xs),c[1]+min(ys),max(xs)-min(xs),max(ys)-min(ys)],'curved_elbow',q)
    return result

ROUTES = [
 ('west-riser','西墙泵组立管',3535, {'red':[(2354,2731),(2354,3649)],'blue':[(2380,2757),(2380,3675)]}),
 ('tank-header','储罐顶部连续回弯',2785, {'red':[(2354,2731),(2354,2715),(2750,2715),(2750,2731)],'blue':[(2380,2757),(2380,2741),(2724,2741),(2724,2757)]}),
 ('east-riser','东墙主管',3530, {'red':[(2750,2731),(2750,3459)],'blue':[(2724,2757),(2724,3485)]}),
 ('control-header','控制柜上方供回水主管',3569, {'red':[(2750,3459),(2750,3475),(3420,3475),(3420,3558)],'blue':[(2724,3485),(2724,3501),(3394,3501),(3394,3568)]}),
 ('pump-feed','泵组进出水连接',3745, {'red':[(2354,3649),(2354,3665),(2637,3665),(2637,3740)],'blue':[(2380,3675),(2380,3691),(2532,3691),(2532,3727)]}),
 ('tank-inlet','储罐顶部进水接口',2840, {'red':[(2480,2715),(2480,2800)]}),
 ('tank-return','储罐下部回水接口',3460, {'blue':[(2380,3430),(2452,3430)]}),
 ('wall-feed','架空主管穿墙接口',3100, {'red':[(2750,2908),(2805,2908)],'blue':[(2724,2925),(2805,2925)]}),
]

def run():
    DOC.mkdir(parents=True,exist_ok=True)
    path=ROOT/'data/rooms/r04.json';disk=sha(path);before=read(path)
    updating=bool(before.get('equipment_pipe_routing_version'))
    old=[f for f in before['fixtures'] if f.get('equipment_pipe_generated')] if updating else [
        f for f in before['fixtures'] if f.get('energy_court_generated') and not f.get('exterior_shell')
        and f.get('asset_id','').startswith('energy_pipe_')]
    assert len(old)==8 if updating else len(old)>40, len(old)
    assets=[];fixtures=[]
    for key,name,depth,routes in ROUTES:
        parts=[]
        for color,points in routes.items():
            for p in patches(color,points):p['circuit']=color;parts.append(p)
        x=min(p['destination'][0] for p in parts);y=min(p['destination'][1] for p in parts)
        r=max(p['destination'][0]+p['destination'][2] for p in parts)
        b=max(p['destination'][1]+p['destination'][3] for p in parts);w,h=r-x,b-y
        for p in parts:p['destination'][0]-=x;p['destination'][1]-=y
        id='equipment_pipe_'+key.replace('-','_')+'_v2'
        asset=dict(id=id,name='设备室管线 · '+name,texture=TEXTURE,texture_size=[1536,1024],region=[0,0,1536,1024],
            world_size=[w,h],render_size=[w,h],footprint_world_size=[w,h],ground_rect=[0,0,1536,1024],
            elevation_world=0,render_mode='projected_prop',proportion_locked=False,runtime_size_limit=1536,
            alpha_core_shader='res://art/props/exercise_yard_v54/clean_cutout.gdshader',blocking=False,
            interactive=False,editor_subcategory='furnishings',shadow_baked=True,
            assembly_patches=parts,source_kind='original-png-native-assembly',sha256=sha(SOURCE))
        assets.append(asset)
        fixtures.append(dict(id='equipment-pipes-'+key,asset_id=id,rect=[x,y,w,h],render_size=[w,h],
            draw_depth=depth,blocks_movement=False,blocks_sight=False,equipment_pipe_generated=True,
            show_in_room='equipment',pipe_routes=routes))
    write(ART/'manifest.json',dict(schema=2,version='equipment-pipes-v2',assets=assets))
    catalog=ROOT/'scripts/presentation/prop_catalog.gd';text=catalog.read_text(encoding='utf-8')
    entry='\t"res://art/props/equipment_pipes_v2/manifest.json",\n'
    if entry.strip() not in text:text=text.replace('\n]\n','\n'+entry+']\n',1);catalog.write_text(text,encoding='utf-8')
    after=json.loads(json.dumps(before));old_ids={f['id'] for f in old}
    after['fixtures']=[f for f in after['fixtures'] if f['id'] not in old_ids]+fixtures
    after['equipment_pipe_routing_version']='continuous-v2'
    # Other editors/tasks can save during asset preparation. Never overwrite them.
    assert sha(path)==disk,'Map changed concurrently; rerun against latest save.'
    if not updating:write(DOC/'before-map.json',before)
    original_removed=read(DOC/'registration.json')['removed_fixture_ids'] if updating else sorted(old_ids)
    write(DOC/'registration.json',dict(removed_fixture_ids=original_removed,added_fixture_ids=[f['id'] for f in fixtures],
        source_sha256=sha(SOURCE),routes=ROUTES,pipe_body_width=63*SCALE,minimum_clear_aisle=70,
        intent='Continuous paired pipes: pump, tank ports, wall feed, cabinet header. Original PNG unchanged.'))
    write(path,after);write(DOC/'after-map.json',after)
    print(json.dumps(dict(removed=len(old),added=len(fixtures),assets=len(assets),map_sha256=sha(path))))

if __name__=='__main__':run()
