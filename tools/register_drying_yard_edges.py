"""Decorative grass/paving transitions, with original imagegen pixels intact.

Ground patches render in the shared editor/runtime terrain layer. They do not
add furniture, obstacles or roof regions. Always merge into the latest R04.
"""
from copy import deepcopy
from pathlib import Path
import hashlib,json,shutil
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/drying-yard-edges-v1'
ART=ROOT/'art/environment/drying_yard_edges_v1'
SOURCE=Path('C:/Users/gst20/.codex/generated_images/01a12f0d-4fc4-7dd2-b6a0-d189a674ef6e/exec-8220363a-3961-4f11-a45b-45b76b0e3a2e.png')
MANIFEST='res://art/environment/drying_yard_edges_v1/manifest.json'
PREFIX='drying-yard-stone-edge-'
def read(p):return json.loads(p.read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def register():
    ART.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
    target=ART/'pebble-strips.png';shutil.copyfile(SOURCE,target)
    assert sha(SOURCE)==sha(target)
    im=Image.open(target);alpha=im.getchannel('A')
    assert im.mode=='RGBA' and alpha.getextrema()[0]==0 and alpha.getextrema()[1]>=250
    definitions=[]
    for i,(top,bottom) in enumerate([(0,im.height//2),(im.height//2,im.height)]):
        x,y,right,lower=alpha.crop((0,top,im.width,bottom)).point(lambda a:255 if a>=80 else 0).getbbox()
        x=max(0,x-4);y=max(0,y+top-4)
        region=[x,y,min(im.width,right+4)-x,min(im.height,lower+top+4)-y]
        width=360; height=width*region[3]/region[2]
        definitions.append(dict(id='drying_pebble_edge_'+str(i+1)+'_v1',name='晾晒区碎石与泥土过渡 '+str(i+1),
            texture='res://art/environment/drying_yard_edges_v1/pebble-strips.png',texture_size=list(im.size),region=region,
            world_size=[width,height],render_size=[width,height],preserve_aspect=False,fixed_orientation=False,
            render_mode='natural_ground_patch',blocking=False,interactive=False,shadow_baked=True,runtime_size_limit=1024,
            source_kind='built-in-imagegen-original-png',sha256=sha(target),registration_note='Dimensions are swapped for quarter-turned vertical patches, preserving source aspect; tail pieces are clipped, not stretched.'))
    write(ART/'manifest.json',dict(schema=2,version='drying-yard-edges-v1',assets=definitions))
    path=ROOT/'data/rooms/r04.json';raw=path.read_bytes();room=json.loads(raw);before=deepcopy(room)
    grass={v['id']:v for v in room['floor_regions'] if v['id'].startswith('drying-yard-')}
    assert grass['drying-yard-west-grass']['rect']==[880,2520,420,660]
    assert grass['drying-yard-east-grass']['rect']==[1620,2520,500,660]
    assert not any(v.get('id','').startswith(PREFIX) for v in room.get('terrain_patches',[])), 'Edges already applied; refine only these IDs instead of replaying.'
    runs=[
        ('west-outer',[880,2540],[880,3180],1),
        ('west-inner',[1300,2540],[1300,3180],3),
        ('west-south',[880,3180],[1300,3180],0),
        ('east-inner',[1620,2540],[1620,3180],1),
        ('east-outer',[2120,2540],[2120,3060],3),
        ('east-step',[2120,3060],[2200,3060],2),
        ('east-step-outer',[2200,3060],[2200,3180],3),
        ('east-south',[1620,3180],[2200,3180],0),
    ]
    patches=[]
    for run_index,(name,start,end,rotation) in enumerate(runs):
        vertical=start[0]==end[0];length=end[1]-start[1] if vertical else end[0]-start[0]
        count=max(1,int((length+343)//344))
        for i in range(count):
            a=definitions[(i+run_index)%2];width,height=a['world_size']
            delta=i*(width-16)
            if delta>=length:break
            rect=[start[0]-height/2,start[1]+delta,height,width] if vertical else [start[0]+delta,start[1]-height/2,width,height]
            clip=[start[0]-height/2,start[1]-height/2,height,length+height] if vertical else [start[0]-height/2,start[1]-height/2,length+height,height]
            patches.append(dict(id=PREFIX+name+'-'+str(i),asset_id=a['id'],manifest=MANIFEST,rect=rect,clip_rect=clip,
                rotation_quarters=rotation,opacity=1.0,blocks_movement=False,blocks_sight=False,
                drying_yard_edge_generated=True,ground_only=True))
    room.setdefault('terrain_patches',[]).extend(patches)
    room['concept_plan']['drying_yard_edge_revision']=dict(version=1,reference='docs/art/drying-yard-edges-v1/reference.png',
        design='低碎石、泥土和草芽过渡；顺着草坪边缘和右侧台阶边界收口',ground_only=True,
        central_path=[1300,2520,320,660],runs=runs)
    assert path.read_bytes()==raw,'Saved map changed during preparation; register again from latest.'
    (DOC/'before-map.json').write_bytes(raw)
    write(DOC/'candidate-map.json',room)
    write(DOC/'registration.json',dict(source=str(SOURCE),png=target.relative_to(ROOT).as_posix(),png_sha256=sha(target),
        mode='built-in imagegen',manifest=MANIFEST,definitions=[a['id'] for a in definitions],input_map_sha256=sha(path),
        new_patch_ids=[v['id'] for v in patches],runs=runs,source_pixels_unchanged=True,collision_changed=False))
    print('Prepared',len(patches),'ground-only stone transition patches; project map not saved yet.')
def apply():
    path=ROOT/'data/rooms/r04.json';r=read(DOC/'registration.json')
    assert sha(path)==r['input_map_sha256'],'Saved map changed; rebuild candidate on latest map.'
    raw=path.read_bytes();staged=path.with_name('r04.drying-yard-edges-v1.writing')
    staged.write_bytes((DOC/'candidate-map.json').read_bytes())
    assert path.read_bytes()==raw
    staged.replace(path)
    (DOC/'after-map.json').write_bytes(path.read_bytes())
    r.update(output_map_sha256=sha(path));write(DOC/'registration.json',r)
    print('Applied grass/pebble transitions; floors, props, gates, roofs and collisions preserved.')
if __name__=='__main__':
    import sys
    {'register':register,'apply':apply}[sys.argv[1]]()
