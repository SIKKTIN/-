"""Register original sliding door art and bind the clinic to a timed entrance."""
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/clinic-restoration'
ART=ROOT/'art/architecture/clinic_sliding_v2'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def main():
    source=json.loads((DOC/'sliding-door-assets.json').read_text(encoding='utf-8'))
    assets=[];records=[]
    for entry in source['assets']:
        path=ROOT/entry['path'];path.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(entry['source'],path)
        assert sha(path)==sha(Path(entry['source']))
        im=Image.open(path)
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
        x,y,r,b=im.getchannel('A').point(lambda v:255 if v>=180 else 0).getbbox()
        x=max(0,x-3);y=max(0,y-3);r=min(im.width,r+3);b=min(im.height,b+3)
        leaf=entry['key']=='sliding_leaf';dims=[90,116] if leaf else [368,16]
        assets.append(dict(id='clinic_'+entry['key']+'_v2',name='医务室侧滑门扇' if leaf else '医务室侧滑门轨道',
            texture='res://'+entry['path'],texture_size=list(im.size),region=[x,y,r-x,b-y],
            world_size=dims,render_size=dims,ground_rect=[0,0,r-x,b-y],footprint_world_size=dims,
            render_mode='wall_attachment',blocking=False,editor_subcategory='attachments'))
        records.append(dict(key=entry['key'],path=entry['path'],sha256=sha(path)))
    door=assets[0].copy()
    door.update(id='doorway_clinic_sliding_v2',name='医务室双扇侧滑门 · 日间开放',render_mode='embedded_door',
        world_size=[180,120],render_size=[180,120],footprint_world_size=[180,20],grid_door={'cell':20},editor_subcategory='doors')
    door['door_presentation']={'door_art_size':[180,120],'sliding_door':{
        'leaf':'clinic_sliding_leaf_v2','track':'clinic_sliding_track_v2','leaf_rect':[0,4,90,116],
        'track_rect':[-94,0,368,16],'solid_rect':[0,12,90,108],'seconds':0.65},'body_profile':'human_silhouette'}
    assets.append(door)
    write(ART/'manifest.json',dict(schema=2,version='clinic-sliding-v2',assets=assets))
    path=ROOT/'data/rooms/r04.json';before=path.read_bytes();digest=sha(path);room=json.loads(before)
    fixture=next(f for f in room['fixtures'] if f['id']=='campus-clinic')
    fixture.update(asset_id=door['id'],access_id='clinic-entry')
    area=next(r['rect'] for r in room['visibility_rooms'] if r['id']=='clinic')
    rect=fixture['rect'];gate=dict(id='clinic-entry',name='医务室',kind='timed',asset_id=door['id'],rect=rect.copy(),
        hours=[480,1200],room_rect=area.copy(),evacuation=[rect[0]+rect[2]/2,rect[1]+rect[3]+110],closed=False,blocks_sight=True)
    previous=next((g for g in room['access_doors'] if g['id']=='clinic-entry'),None)
    if previous is None:room['access_doors'].append(gate)
    else:previous.update(gate)
    assert sha(path)==digest,'Saved map changed; rerun on the latest saved map.'
    (DOC/'sliding-last-input-map.json').write_bytes(before)
    write(path,room)
    (DOC/'sliding-last-output-map.json').write_bytes(path.read_bytes())
    write(DOC/'sliding-door-registration.json',dict(mode=source['mode'],assets=records,map_before_sha256=digest,map_after_sha256=sha(path)))
    print('Registered 2 original PNGs, 3 definitions and clinic timed entrance on latest saved layout.')
if __name__=='__main__':main()
