"""Install approved roof originals and patch only the current two room styles/sign."""
from pathlib import Path
from copy import deepcopy
import json,hashlib,shutil,os,tempfile
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/reading-chess-roofs-v1'
ART=ROOT/'art/architecture/reading_chess_roofs_v1'
SOURCE=Path('C:/Users/gst20/.codex/generated_images/01a12de1-9940-7ee0-a361-bbf0f88d4681')
SOURCES=['exec-922c0410-ad75-4caa-9ab8-e4ad52ca366e.png','exec-c2fc8e40-a740-49fa-9f46-b43fa6965859.png','exec-b9ef197f-19ec-4381-830b-b619f60a9fbc.png']
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
    ART.mkdir(parents=True,exist_ok=True);assets=[];provenance=[]
    names=['reading-roof.png','chess-roof.png','reading-sign.png']
    ids=['roof_reading','roof_chess','reading_enamel_sign_v1']
    labels=['阅览室 · 旧砖红瓦屋顶','棋牌室 · 旧灰瓦屋顶','阅览室 · 入口搪瓷门牌']
    for i,(src,name,id,label) in enumerate(zip(SOURCES,names,ids,labels)):
        p=ART/name;shutil.copyfile(SOURCE/src,p);assert sha(p)==sha(SOURCE/src)
        im=Image.open(p);w,h=im.size
        a=dict(id=id,name=label,texture='res://'+p.relative_to(ROOT).as_posix(),texture_size=[w,h],sha256=sha(p),source_kind='built-in-imagegen-original-png',blocking=False,runtime_size_limit=512,alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader')
        if i<2:
            assert im.convert('RGBA').getchannel('A').getextrema()==(255,255)
            a.update(region=[0,0,w,h],world_size=[600,400 if i==0 else 680],render_mode='architecture_material',fit_roof=True,opaque=True,editor_hidden=True)
        else:
            assert im.mode=='RGBA' and im.getpixel((0,0))[3]==0
            box=im.getchannel('A').point(lambda v:255 if v>3 else 0).getbbox();x,y,x2,y2=box;rw,rh=x2-x,y2-y
            height=115*rh/rw
            a.update(region=[x,y,rw,rh],world_size=[115,height],render_size=[115,height],footprint_world_size=[115,height],ground_rect=[0,0,rw,rh],elevation_world=0,render_mode='wall_attachment',editor_subcategory='attachments',proportion_locked=True)
        assets.append(a);provenance.append(dict(id=id,original=str(SOURCE/src),project=str(p),sha256=sha(p)))
    write(ART/'manifest.json',dict(schema=2,version='reading-chess-roofs-v1',assets=assets))
    path=ROOT/'data/rooms/r04.json';digest=sha(path);before=read(path);after=deepcopy(before)
    for id,style in [('reading-room','reading'),('chess-room','chess')]:
        room=next(r for r in after['visibility_rooms'] if r['id']==id);room['roof_style']=style
    entry=next(f for f in after['fixtures'] if f['id']=='reading-room-entry');x,y,w,h=entry['rect']
    assert w<h,'Recalibrate the sign for a changed entrance orientation.'
    sign=dict(id='reading-exterior-sign',asset_id=ids[2],rect=[x+10,y-45,*assets[2]['world_size']],blocks_movement=False,blocks_sight=False,exterior_shell=True,in_front_of_wall_trim=True)
    after['fixtures']=[f for f in after['fixtures'] if f['id']!=sign['id']];after['fixtures'].append(sign)
    assert sha(path)==digest,'Map changed during registration; retry on current saved layout.'
    write(DOC/'before.json',before);write(DOC/'after.json',after);write(path,after)
    write(DOC/'registration.json',dict(mode='built-in imagegen',assets=provenance,definition_ids=ids,input_sha256=digest,output_sha256=sha(path),new_fixture_id=sign['id'],changed_room_ids=['reading-room','chess-room']))
    print('Registered two original roof surfaces and transparent sign; latest room layout preserved.')
if __name__=='__main__':main()
