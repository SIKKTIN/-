"""Copy unmodified ImageGen outputs and calculate source regions/pivots only."""
from pathlib import Path
from PIL import Image
import shutil,json,hashlib
R=Path('E:/Project/Godot/这次怎么逃');OUT=R/'art/characters';OUT.mkdir(parents=True,exist_ok=True)
G=Path('C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0')
specs=[
 (0,'inmate_01','slender',G/'exec-62dd9ae7-2cb6-42e8-b999-5846d17dc653.png',42),
 (1,'inmate_02','round',Path('E:/Docs/这次怎么逃/assets/art-direction/walk-test-v01.png'),42),
 (2,'inmate_03','square',G/'exec-71ba91a3-4f75-41f8-beb1-be0b9d2a7a86.png',42),
 ('guard','guard_01','navy_guard',G/'exec-5a280ae2-ccd7-4342-9e47-a22b6e1c3e85.png',48)]
actors=[]
for actor_id,name,identity,source,world_height in specs:
 dest=OUT/(name+'_v01.png')
 if dest.exists():raise RuntimeError('Existing asset '+str(dest))
 im=Image.open(source);assert im.mode=='RGBA' and im.width%3==0
 alpha=im.getchannel('A');pix=alpha.load();cell=im.width//3
 frames={};anchors={};bounds={};heads={}
 for i,state in enumerate(['idle','walk_a','walk_b']):
  points=[(x,y) for y in range(im.height) for x in range(i*cell,(i+1)*cell) if pix[x,y]>8]
  x0=min(p[0] for p in points);x1=max(p[0] for p in points);y0=min(p[1] for p in points);y1=max(p[1] for p in points)
  left=max(i*cell,x0-4);top=max(0,y0-4);right=min((i+1)*cell,x1+5);bottom=min(im.height,y1+5)
  band_end=y0+round((y1-y0)*.30)
  xs=[x for x,y in points if y<=band_end and pix[x,y]>128]
  head_x=(min(xs)+max(xs))/2
  frames[state]=[left,top,right-left,bottom-top]
  anchors[state]=[round(head_x-left,2),y1+1-top]
  bounds[state]=[x0-left,y0-top,x1-x0+1,y1-y0+1]
  heads[state]=[round(head_x-left,2),y0-top]
 shutil.copyfile(source,dest)
 actors.append({'actor_id':actor_id,'visual_id':name,'identity':identity,'texture':'res://art/characters/'+dest.name,'texture_size':list(im.size),'frames':frames,'anchor':anchors,'world_height':world_height,'scale_rule':'world_height / current frame region height; draw at -anchor * scale','opaque_bounds':bounds,'head_registration':heads,'initial_walk_frame_seconds':.32,'facing':'consume actual logic-facing marker; fixed artwork view is not facing','skills_baked':False,'source_kind':'built-in ImageGen original project asset; output pixels unmodified','source_reference':'E:/Docs/这次怎么逃/assets/art-direction/art-direction-v01.png','source_png':str(source),'license_record':'docs/art/source-license-v01.json','sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
manifest={'schema':1,'actors':actors,'state_boundary':'idle when actual displacement is zero; walk_a/walk_b only with actual movement; pause/escape stops animation','selected_and_action_independent':True,'implementation':'producer loads Texture2D and draw_texture_rect_region; no shared scripts changed by art director'}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'actors':len(actors),'poses':12,'png_pixels_modified':False,'paths':[a['texture'] for a in actors]}))
