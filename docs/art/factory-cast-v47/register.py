import json,shutil,hashlib
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
ART=ROOT/'art/characters/factory_cast_v47'
SRC=Path('C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0')
ROLES=[
 ('young_worker','年轻工人','211d33a4-7474-4bea-b827-b6db02a60ce8',60),
 ('stocky_worker','壮实工人','bc65f620-bcca-4d94-b6d6-2d6a2aab3e06',62),
 ('older_worker','年长工人','e344f3ff-53d2-44ee-bb23-3f2d48c83a9b',58),
 ('female_worker','女工','b912624a-99ed-4383-81a6-758cd08dd77a',60),
 ('porter','搬运工','3a125a06-a21d-4558-a5a1-ed0c44dc3c7b',62),
 ('patrol_guard','巡逻看守','ea6e3f6a-d458-442e-899c-5a92249bbd27',62),
 ('overseer','车间监工','a18797df-abb8-4f98-93a1-86653082df51',62),
 ('attendant','后勤人员','d01e23d5-d621-41e7-a59a-270fd86008d8',60)]
ART.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
baseline=OUT/'baseline';baseline.mkdir(exist_ok=True)
if not (baseline/'r04.json').exists():shutil.copy2(ROOT/'data/rooms/r04.json',baseline/'r04.json')
shutil.copy2(SRC/'exec-9b7567dc-cabc-404a-9fa5-dd3a5154373d.png',OUT/'approved-concept.png')
characters=[];records=[]
for id,name,source_id,height in ROLES:
    source=SRC/('exec-'+source_id+'.png')
    target=ART/(id+'_idle_walk8.png')
    shutil.copy2(source,target)
    im=Image.open(source)
    assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
    mask=im.getchannel('A').point(lambda a:255 if a>=24 else 0)
    def separators(axis):
        length=im.height if axis=='row' else im.width
        gaps=[];start=None
        for n in range(length):
            empty=mask.crop((0,n,im.width,n+1) if axis=='row' else (n,0,n+1,im.height)).getbbox() is None
            if empty and start is None:start=n
            if not empty and start is not None:
                if n-start>=3:gaps.append((start,n))
                start=None
        cuts=[0]
        for j in [1,2]:
            goal=length*j/3
            candidates=[g for g in gaps if abs((g[0]+g[1])/2-goal)<length*.14]
            assert candidates,(id,axis,goal)
            gap=min(candidates,key=lambda g:abs((g[0]+g[1])/2-goal))
            cuts.append(round((gap[0]+gap[1])/2))
        return cuts+[length]
    rows=separators('row');cols=separators('col')
    frames=[];statistics=[]
    for i in range(9):
        col,row=i%3,i//3
        cell=(cols[col],rows[row],cols[col+1],rows[row+1])
        box=mask.crop(cell).getbbox();assert box,(id,i)
        x0,y0,x1,y1=box
        # Head center, rather than changing arm/leg extents, anchors each pose.
        head=mask.crop((cell[0]+x0,cell[1]+y0+round((y1-y0)*.08),cell[0]+x1,cell[1]+y0+round((y1-y0)*.30))).getbbox()
        axis=cell[0]+x0+(head[0]+head[2])/2
        x=max(cell[0],cell[0]+x0-3);y=max(cell[1],cell[1]+y0-3)
        right=min(cell[2],cell[0]+x1+3);bottom=min(cell[3],cell[1]+y1+3)
        region=[x,y,right-x,bottom-y]
        frames.append(dict(id='idle' if i==0 else 'walk_'+str(i-1),region=region,anchor=[round(axis-x,3),cell[1]+y1-y]))
        statistics.append(dict(body_height=y1-y0,body_width=x1-x0,cell=list(cell),head_axis=axis))
    idle=frames[0];walk=frames[1:]
    scale_height=idle['region'][3]
    asset=dict(id=id,name=name,texture='res://art/characters/factory_cast_v47/'+target.name,texture_size=list(im.size),world_height=height,scale_height=scale_height,
        frames={'idle':idle['region'],'walk_a':walk[0]['region'],'walk_b':walk[4]['region']},anchor={'idle':idle['anchor'],'walk_a':walk[0]['anchor'],'walk_b':walk[4]['anchor']},
        portrait_region=[idle['region'][0],idle['region'][1],idle['region'][2],round(idle['region'][3]*.55)],
        initial_walk_frame_seconds=.15,shadow_baked=False,
        walk_animation=dict(texture='res://art/characters/factory_cast_v47/'+target.name,fps=12,scale_height=scale_height,frames=walk),
        source_kind='built-in-imagegen-original-png',sha256=hashlib.sha256(source.read_bytes()).hexdigest())
    characters.append(asset)
    records.append(dict(id=id,name=name,original=str(source),project=str(target),sha256=asset['sha256'],size=list(im.size),frames=statistics))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
save(ART/'manifest.json',dict(schema=1,version='factory-cast-v47',characters=characters))
save(OUT/'registration.json',dict(originals=records,characters=characters,policy='Original PNG bytes unchanged; transparent cell regions, head axis, foot anchor and shared idle/walk scale registered as metadata.'))
print(json.dumps(dict(characters=len(characters),idle_frames=len(characters),walk_frames=8*len(characters),map_data_unchanged=True)))
