"""Replace only the latest saved bath entrance with compact pocket-door art."""
from pathlib import Path
from copy import deepcopy
import hashlib, json, os, shutil, tempfile

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/bath-pocket-door-v1'
SRC=Path('C:/Users/gst20/.codex/generated_images/01a12de1-9940-7ee0-a361-bbf0f88d4681/exec-c4431503-151c-46fd-b9cd-3190f165d494.png')
ASSET=ROOT/'art/architecture/bath_pocket_v1/door_states.png'
def read(p):return json.loads(p.read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):
    p.parent.mkdir(parents=True,exist_ok=True)
    fd,tmp=tempfile.mkstemp(prefix=p.name+'.',suffix='.tmp',dir=p.parent)
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent='\t')+'\n')
        os.replace(tmp,p)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)
def main():
    from PIL import Image
    ASSET.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(SRC,ASSET)
    assert sha(ASSET)==sha(SRC)
    im=Image.open(ASSET);assert im.mode=='RGBA' and im.getpixel((1400,400))[3]==0
    open_id='doorway_bath_pocket_open_v1';closed_id='doorway_bath_pocket_closed_v1'
    # Preserve the original atlas; source rectangles and immutable shared
    # header/jamb patches align the two states in the retained Godot painter.
    regions={'open':[1039,126,720,584],'closed':[165,125,721,585]}
    def patch(asset,source,destination):return dict(asset=asset,source=source,destination=destination)
    frame=[patch(open_id,[0,0,1,51/584],[0,0,140,10.48]),
           patch(open_id,[0,51/584,77/720,533/584],[0,10.48,14.97,109.52]),
           patch(open_id,[646/720,51/584,74/720,533/584],[125.61,10.48,14.39,109.52])]
    leaf=patch(closed_id,[(222-165)/721,(176-125)/585,610/721,528/585],[14.97,10.48,110.64,109.52])
    assets=[]
    for state in ['open','closed']:
        region=regions[state]
        assets.append(dict(id=open_id if state=='open' else closed_id,name='浴室北入口 · 磨砂双扇推拉门 · '+('打开' if state=='open' else '关闭'),
            texture='res://art/architecture/bath_pocket_v1/door_states.png',texture_size=list(im.size),region=region,
            runtime_size_limit=512,sha256=sha(ASSET),source_kind='built-in-imagegen-original-png',
            alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
            render_mode='embedded_door',world_size=[140,120],render_size=[140,120],footprint_world_size=[120,20],
            ground_rect=[0,0,region[2],region[3]],blocking=state=='closed',grid_door={'cell':20},editor_subcategory='doors',
            door_presentation=dict(door_art=open_id,door_art_closed=closed_id,door_art_size=[140,120],
                door_open_patches=frame,door_closed_patches=[leaf]+frame,
                visual_solid_parts=[[0,10.48,14.97,109.52],[125.61,10.48,14.39,109.52]],
                closed_visual_solid_parts=[leaf['destination']],body_profile='human_silhouette',raised_door=True,clear_wall_facade=True)))
    write(ROOT/'art/architecture/bath_pocket_v1/manifest.json',dict(schema=2,version='bath-pocket-v1',assets=assets))
    path=ROOT/'data/rooms/r04.json';initial=sha(path);before=read(path);data=deepcopy(before)
    fixture=next(f for f in data['fixtures'] if f['id']=='campus-bath')
    x,y,w,h=fixture['rect'];assert w==120 and h==20,'Door opening changed; rebase its art calibration.'
    # Locate its current wall header, respecting the user's building moves.
    walls=[]
    for s in data['architecture']['wall_surfaces']:
        r=data['walls'][int(s['wall_index'])]
        if s.get('grid_tile_asset','').startswith('bath_') and r[3]>=100 and abs(r[1]+r[3]-y-h)<4:
            gap=min(abs(r[0]+r[2]-x),abs(r[0]-x-w))
            if gap<=40:walls.append((gap,r[1]))
    assert walls,'Cannot locate bath facade.'
    top=min(walls)[1]
    fixture.update(asset_id=open_id,open_asset=open_id,closed_asset=closed_id,render_size=[140,120],frame_only=False,
                   rotation_door_visual_rect=[x+w/2-70,top,140,120])
    assert sha(path)==initial,'R04 changed; retry on latest saved map.'
    write(DOC/'input-map.json',before);write(DOC/'candidate-map.json',data)
    write(path,data);write(DOC/'output-map.json',data)
    write(DOC/'registration.json',dict(mode='built-in imagegen',source_png=str(SRC),project_png=str(ASSET),image_sha256=sha(ASSET),
        changed_fixture_ids=['campus-bath'],input_sha256=initial,output_sha256=sha(path),visual_rect=fixture['rotation_door_visual_rect'],
        definition_ids=[open_id,closed_id],opening=[x,y,w,h]))
    print('Replaced only bath north door; current furniture, walls, services and room layout preserved.')
if __name__=='__main__':main()
