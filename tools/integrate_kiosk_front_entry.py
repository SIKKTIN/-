"""Restore the approved front-entry kiosk using the latest saved map."""
from pathlib import Path
from copy import deepcopy
import json,hashlib,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];DOC=ROOT/'docs/art/campus-kiosk-front-entry'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 rec=read(DOC/'generation.json');png=ROOT/rec['output'];shutil.copyfile(rec['source'],png)
 im=Image.open(png);alpha=im.getchannel('A');assert im.mode=='RGBA';x,y,r,b=alpha.point(lambda a:255 if a>=180 else 0).getbbox();w,h=r-x,b-y
 manifest=ROOT/'art/architecture/kiosk_v2/manifest.json';manifest_raw=manifest.read_bytes();c=read(manifest)
 def asset(id):return deepcopy(next(a for a in c['assets'] if a['id']==id))
 facade=asset('kiosk_side_entry_v2');facade.update(id='kiosk_front_facade_v5',name='小卖铺 · 正门与售货窗口',texture='res://'+rec['output'],texture_size=list(im.size),region=[x,y,w,h],sha256=sha(png),authoring_set='kiosk-front-entry',world_size=[640,160],render_size=[640,160],footprint_world_size=[640,160],ground_rect=[0,0,w,h],blocking=True)
 # Clearance registers to the narrowest original-alpha aperture, not an
 # assumed door rectangle. Keep the original PNG unmodified.
 left=(310-x)/w*640;right=(607-x)/w*640
 shell=asset('kiosk_shell_v2');shell.update(id='kiosk_closed_side_shell_v5',name='小卖铺 · 连续侧墙外壳')
 shell['assembly_patches']=[dict(source=s,destination=d) for s,d in [([56,95,1621,291],[0,0,640,116]),([1560,386,117,437],[600,116,40,224]),([56,386,120,172],[0,116,40,224])]]
 island=asset('kiosk_goods_shelf_v2');height=190*island['region'][3]/island['region'][2];d=island['region'][3]*36/height
 island.update(id='kiosk_goods_island_v5',name='小卖铺 · 中央商品架',world_size=[190,height],render_size=[190,height],footprint_world_size=[190,36],ground_rect=[0,island['region'][3]-d,island['region'][2],d],elevation_world=height-36)
 canopy=asset('kiosk_front_canopy_v2');canopy.update(id='kiosk_front_canopy_clean_v5',name='小卖铺 · 正门雨棚与招牌',region=[212,435,1113,215],world_size=[640,124],render_size=[640,124],footprint_world_size=[640,30],ground_rect=[0,215-215*30/124,1113,215*30/124],elevation_world=94,assembly_patches=[dict(source=[212,435,1113,136],destination=[0,0,640,78.2]),dict(source=[545,550,440,100],destination=[191.5,66.1,253,57.5])])
 new=[facade,shell,island,canopy];c['assets']=[a for a in c['assets'] if a['id'] not in [a['id'] for a in new]]+new
 p=ROOT/'data/rooms/r04.json';raw=p.read_bytes();m=read(p);room=next(r for r in m['visibility_rooms'] if r['id']=='campus-kiosk');ox,oy,rw,rh=room['roof_rect'];assert [rw,rh]==[640,340]
 m['fixtures']=[f for f in m['fixtures'] if f['id'] not in ['kiosk-side-entry','kiosk-entry-north-return','kiosk-goods-island']]
 body=next(f for f in m['fixtures'] if f['id']=='kiosk-shell');body.update(asset_id=shell['id'],solid_parts=[[0,0,1,116/340],[0,116/340,40/640,224/340],[600/640,116/340,40/640,224/340]])
 front=next(f for f in m['fixtures'] if f['id']=='kiosk-front-counter');front.update(asset_id=facade['id'],rect=[ox,oy+340,640,160],render_size=[640,160],solid_parts=[[0,0,left/640,1],[right/640,0,(640-right)/640,1]])
 awning=next(f for f in m['fixtures'] if f['id']=='kiosk-front-canopy');awning.update(asset_id=canopy['id'],rect=[ox,oy+310,640,30],render_size=canopy['render_size'])
 shelf=next(f for f in m['fixtures'] if f['id']=='kiosk-back-shelf');shelf['rect'][0]=ox+150;shelf.pop('exterior_shell',None)
 m['fixtures'].append(dict(id='kiosk-goods-island',asset_id=island['id'],rect=[ox+270,oy+280,190,36],render_size=island['render_size'],blocks_movement=True,blocks_sight=False))
 room.update(rect=[ox+40,oy+116,560,380],roof_cutouts=[],roof_depth_offset=26,roof_exit_by_feet=True)
 m['floor_regions']=[f for f in m['floor_regions'] if f['id']!='kiosk-entry-shade'];floor=next(f for f in m['floor_regions'] if f['id']=='kiosk-floor');floor['rect'][3]=500
 zone=next(z for z in m['zones'] if z['id']=='campus-kiosk');zone['rect']=[ox,oy,640,500]
 merchant=next(n for n in m['merchants'] if n['id']=='campus_kiosk');merchant.update(position=[ox+420,oy+455],service_offset=[0,65],exterior_service=True)
 for activity in merchant['routine']:activity['position']=merchant['position'].copy()
 assert p.read_bytes()==raw and manifest.read_bytes()==manifest_raw,'Concurrent change; retry latest.'
 (DOC/'before.json').write_bytes(raw);(DOC/'manifest-before.json').write_bytes(manifest_raw)
 write(manifest,c);write(p,m);write(DOC/'after.json',m)
 write(DOC/'registration.json',dict(assets=[dict(key='front-facade',path=rec['output'],sha256=sha(png))],definition_ids=[a['id'] for a in new],origin=[ox,oy],door_clearance=[ox+left,ox+right],door_center=ox+(left+right)/2,service_point=[ox+420,oy+520],map_before_sha256=hashlib.sha256(raw).hexdigest(),map_after_sha256=sha(p)))
 print(json.dumps(dict(door_clearance=[ox+left,ox+right],door_center=ox+(left+right)/2,service_point=[ox+420,oy+520]),ensure_ascii=True))
if __name__=='__main__':run()
