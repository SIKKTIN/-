"""Register original reading-room art and furnish only R04's north alcove."""
import json,hashlib,shutil
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/reading-room-restoration'
ART=ROOT/'art/props/reading_room_v1'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8',newline='\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rows=read(DOC/'generated-assets.json')['assets']
specs={'bookcase':('阅览室 · 木书架',160,30),'table':('阅览室 · 四人阅读桌椅',230,120),'newspaper':('阅览室 · 报刊架',40,30),'return':('阅览室 · 还书柜',72,32),'notice':('阅览室 · 门牌时钟与告示栏',130,None),'plant':('阅览室 · 圆盆绿植',40,22),'lamp':('阅览室 · 暖光笼罩壁灯',20,None)}
assets=[];ART.mkdir(parents=True,exist_ok=True)
for r in rows:
 dest=ART/(r['key']+'.png');shutil.copyfile(r['source'],dest)
 assert sha(dest)==sha(Path(r['source']))
 im=Image.open(dest);assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
 x,y,right,bottom=im.getchannel('A').point(lambda v:255 if v>=16 else 0).getbbox()
 x=max(0,x-3);y=max(0,y-3);right=min(im.width,right+3);bottom=min(im.height,bottom+3)
 w,h=right-x,bottom-y;name,width,depth=specs[r['key']];scale=width/w
 height=h*scale
 if depth is None:depth=height
 ground_h=depth/scale
 a=dict(id='reading_'+r['key']+'_v1',name=name,texture='res://'+dest.relative_to(ROOT).as_posix(),texture_size=list(im.size),region=[x,y,w,h],ground_rect=[0,h-ground_h,w,ground_h],world_size=[width,height],render_size=[width,height],footprint_world_size=[width,depth],elevation_world=height-depth,render_mode='wall_attachment' if r['key'] in ['notice','lamp'] else 'projected_prop',proportion_locked=True,blocking=r['key'] not in ['notice','lamp'],interactive=False,shadow_baked=True,editor_subcategory='attachments' if r['key'] in ['notice','lamp'] else 'furnishings',alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',source_kind='built-in-imagegen-original-png',sha256=sha(dest))
 assets.append(a);r.update(path=dest.relative_to(ROOT).as_posix(),sha256=sha(dest))
write(ART/'manifest.json',dict(schema=2,assets=assets))
path=ROOT/'data/rooms/r04.json';raw=path.read_bytes();m=json.loads(raw)
assert any(r['id']=='dorm-north' for r in m['visibility_rooms']), 'Expected existing north dorm; refuse a repeated conversion.'
(DOC/'before.json').write_bytes(raw)
room=next(r for r in m['visibility_rooms'] if r['id']=='dorm-north');assert room['rect']==[120,220,560,300]
room.update(id='reading-room',name='阅览室')
for z in m['zones']:
 if z['id']=='dorm-north':z.update(id='reading-room',name='阅览室',hide_label=True)
old=[f['id'] for f in m['fixtures'] if f['id'].startswith('dorm-north-') and f['id']!='dorm-north-entry']
m['fixtures']=[f for f in m['fixtures'] if f['id'] not in old]
# Keep the already tested side entrance and structural boundaries.
entry=next(f for f in m['fixtures'] if f['id']=='dorm-north-entry');entry['id']='reading-room-entry'
new=[]
def prop(identifier,key,x,y,loot=False):
 a=next(a for a in assets if a['id']=='reading_'+key+'_v1')
 f=dict(id=identifier,asset_id=a['id'],rect=[x,y,*a['footprint_world_size']],blocks_movement=a['blocking'],blocks_sight=False)
 if loot:f.update(loot_profile='reading_room',loot_name='还书柜' if key=='return' else '阅览室书架',loot_location='阅览室')
 if key in ['notice','lamp']:f['draw_depth']=270
 m['fixtures'].append(f);new.append(identifier)
prop('reading-bookcase-left','bookcase',174,230,True)
prop('reading-bookcase-right','bookcase',338,230,True)
prop('reading-table','table',275,355)
prop('reading-newspapers','newspaper',132,355)
prop('reading-return','return',588,326,True)
prop('reading-notice','notice',532,145)
prop('reading-plant','plant',132,452)
prop('reading-wall-lamp','lamp',589,122)
for lamp in m['lamps']:
 if lamp.get('dorm_decor_room_id')=='dorm-north':
  lamp.pop('dorm_decor_room_id');lamp.update(room_id='reading-room',position=[600,235],radius=300,draw_fixture=False)
for floor in m['floor_regions']:
 if floor['id']=='north-life-alcove':floor['tile_size']=[160,160]
assert path.read_bytes()==raw,'Map changed while preparing conversion.'
write(path,m);(DOC/'after.json').write_bytes(path.read_bytes())
loot=ROOT/'data/items/loot_tables.json';tables=read(loot)
(DOC/'loot-before.json').write_bytes(loot.read_bytes())
tables['profiles']['reading_room']=dict(label='阅览室书架',items=['secret_note','factory_map','duty_roster','delivery_note'])
write(loot,tables)
write(DOC/'registration.json',dict(mode='built-in imagegen',assets=rows,removed_fixture_ids=old,new_fixture_ids=new,map_before_sha256=sha(DOC/'before.json'),map_after_sha256=sha(path)))
print('Registered 7 original transparent assets and converted north dorm to reading room.')