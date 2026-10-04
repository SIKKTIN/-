"""Copy original generated PNGs and calculate metadata; never alter image pixels."""
from pathlib import Path
from PIL import Image
import numpy as np,json,shutil,hashlib
ROOT=Path('E:/Project/Godot/这次怎么逃')
INPUTS=json.loads((ROOT/'docs/art/imagegen-inputs-v03.json').read_text(encoding='utf-8'))['inputs']
BY={a['id']:a for a in INPUTS}
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def copy(a):
    target=ROOT/a['folder']/(a['name']+'.png');source=Path(a['source'])
    if target.exists() and digest(target)!=digest(source):raise RuntimeError('Refuse differing asset '+str(target))
    if not target.exists():shutil.copyfile(source,target)
    return target
def bbox(mask):
    yy,xx=np.where(mask)
    return [int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]
def rgba_bounds(path):
    im=Image.open(path);assert im.mode=='RGBA'
    return im,np.asarray(im.getchannel('A'))
paths={a['id']:copy(a) for a in INPUTS}
def material(id,key,world,region=None,**extra):
    p=paths[key];im=Image.open(p)
    return dict(id=id,texture='res://'+p.relative_to(ROOT).as_posix(),texture_size=list(im.size),region=region or [0,0,*im.size],world_size=world,shadow_baked=False,source_kind='built-in imagegen original project asset; PNG pixels unmodified',source_png=BY[key]['source'],**extra)
top=Image.open(paths['stone_top'])
front=Image.open(paths['stone_front'])
env=[material('floor_handpaint_v03','floor',[512,512],tileable=True),material('stone_top_handpaint_v03','stone_top',[256,256],tileable=True),material('stone_front_handpaint_v03','stone_front',[256,18],region=[0,145,front.width,427],tileable_x=True,fixed_face_height=18,front_modulate=[.74,.74,.74,1],lighting_note='render front only as a shaded vertical plane; do not tint top'),material('block_top_handpaint_v03','stone_top',[130,110],region=[0,0,top.width,top.height//2],single_fit=True)]
im,alpha=rgba_bounds(paths['crate']);core=bbox(alpha>32)
region=[max(0,core[0]-6),max(0,core[1]-6),min(im.width,core[2]+6),min(im.height,core[3]+6)]
region=[region[0],region[1],region[2]-region[0],region[3]-region[1]]
# Visually inspected top/front junction at original source y900. The plane
# heights define footprint mapping, independent from transparent PNG margins.
junction=900;face=core[3]-junction;top_height=junction-core[1]
ground=[core[0]-region[0],core[1]-region[1]+face,core[2]-core[0],top_height]
crate=material('heavy_crate_handpaint_v03','crate',[region[2]/ground[2]*94,region[3]/ground[3]*92],region=region,ground_rect=ground,anchor=[ground[0]+ground[2]/2,ground[1]+ground[3]/2],footprint_world_size=[94,92],elevation_world=face/top_height*92,top_front_junction_source_y=junction,ground_rect_coordinates='local to extracted AtlasTexture region, not original PNG')
old_props=json.loads((ROOT/'art/props/manifest-v02.json').read_text())['assets']
props=[crate]+[a for a in old_props if a['id'].startswith('locked_door_')]
actors=[];metrics=[]
for actor_id,key,name,identity,height in [(0,'slender','inmate_01','slender',60),(1,'round','inmate_02','round',60),(2,'square','inmate_03','square',60),('guard','guard','guard_01','navy_guard',72)]:
    p=paths[key];im,alpha=rgba_bounds(p);assert im.width%3==0
    cell=im.width//3;frames={};anchors={};bounds={};heads={};rows=[]
    for i,state in enumerate(['idle','walk_a','walk_b']):
        a=alpha[:,i*cell:(i+1)*cell];x0,y0,x1,y1=bbox(a>32)
        left=max(0,x0-6);top_y=max(0,y0-6);right=min(cell,x1+6);bottom=min(im.height,y1+6)
        band_end=y0+round((y1-y0)*.30);headmask=a[y0:band_end+1]>128
        _,hx=np.where(headmask);head_x=float((hx.min()+hx.max())/2)
        frames[state]=[i*cell+left,top_y,right-left,bottom-top_y]
        anchors[state]=[round(head_x-left,2),y1-top_y]
        bounds[state]=[x0-left,y0-top_y,x1-x0,y1-y0]
        heads[state]=[round(head_x-left,2),y0-top_y]
        scale=height/(bottom-top_y)
        rows.append(dict(state=state,visible_world_height=round((y1-y0)*scale,4),foot_alpha_padding_world=round((bottom-y1)*scale,4),head_width_world=round((hx.max()-hx.min()+1)*scale,4),idle_width_world=round((x1-x0)*scale,4)))
    actor=dict(actor_id=actor_id,visual_id=name,identity=identity,texture='res://'+p.relative_to(ROOT).as_posix(),texture_size=list(im.size),frames=frames,anchor=anchors,opaque_bounds=bounds,head_registration=heads,world_height=height,initial_walk_frame_seconds=.32,scale_rule='world_height / frame region height; draw at -anchor * scale; mirror only body about local foot origin',skills_baked=False,shadow_baked=False,source_kind='built-in imagegen original project asset; PNG pixels unmodified',source_png=BY[key]['source'],sha256=digest(p))
    actors.append(actor);metrics.append(dict(actor_id=actor_id,frames=rows,height_spread=max(x['visible_world_height'] for x in rows)-min(x['visible_world_height'] for x in rows)))
for folder,data in [('environment',dict(schema=3,assets=env)),('props',dict(schema=3,assets=props)),('characters',dict(schema=1,actors=actors,selected_and_action_independent=True,state_boundary='actual displacement drives walk_a/walk_b; zero movement idle; pause/escape stop'))]:
    (ROOT/'art'/folder/'manifest-v03.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
provenance=dict(mode='built-in imagegen',original_pixel_files=True,reference='docs/art/r02-perspective-study-v01.png',prompts='docs/art/imagegen-prompts-v03.json',corrections='docs/art/imagegen-corrections-v03.json',license='Original project-generated assets; prior own characters used for identity; no third party game art copied',assets=[dict(id=k,source=BY[k]['source'],saved=paths[k].relative_to(ROOT).as_posix(),sha256=digest(paths[k])) for k in paths])
(ROOT/'docs/art/source-license-v03.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
files=[p.relative_to(ROOT).as_posix() for p in paths.values()]+['art/'+f+'/manifest-v03.json' for f in ['environment','props','characters']]+['docs/art/imagegen-prompts-v03.json','docs/art/imagegen-corrections-v03.json','docs/art/source-license-v03.json']
inventory=[dict(path=f,sha256=digest(ROOT/f),bytes=(ROOT/f).stat().st_size) for f in files]
version='art-v03-handpaint-20261004-'+hashlib.sha256(json.dumps(inventory,sort_keys=True).encode()).hexdigest()[:12]
delivery=dict(schema=3,version=version,base_asset_version='art-v02-perspective-20261004-54a7161c7820',files=inventory,assets=env+props,actors=actors,rendering=dict(floor_asset='floor_handpaint_v03',floor_tile_size=512,material_slots=dict(wall_top='stone_top_handpaint_v03',wall_front='stone_front_handpaint_v03',block_top='block_top_handpaint_v03',crate='heavy_crate_handpaint_v03',door_closed='locked_door_closed_v02',door_open='locked_door_open_v02'),block_top_tiled=False,wall_elevation=18,block_elevation=24,outline_width=1.4,outline_color='434941',soft_shadows=True,contact_alpha=.16,projection_offset=[11,8],projection_alpha=.10),frame_metrics=metrics,gameplay_unchanged=True)
(ROOT/'docs/art/delivery-v03.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2),encoding='utf-8')
old=[]
for v in ['v01','v02']:
    baseline=json.loads((ROOT/'docs/art'/('delivery-'+v+'.json')).read_text())
    old += [f['path'] for f in baseline['files'] if digest(ROOT/f['path'])!=f['sha256']]
source_match=all(digest(paths[k])==digest(Path(BY[k]['source'])) for k in paths)
qa=dict(version=version,png_pixels_modified=False,original_copy_hashes_match=source_match,prior_asset_mismatches=old,frame_metrics=metrics,crate_region=region,crate_ground_rect=ground,crate_elevation=crate['elevation_world'],passed=source_match and not old and all(m['height_spread']<.2 for m in metrics),scope='resource registration and hashes, not actual scene or gameplay validation')
(ROOT/'docs/art/qa-resources-v03.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(version=version,new_png=len(paths),inventory=len(inventory),passed=qa['passed'],frame_metrics=metrics,crate_ground=ground)))
