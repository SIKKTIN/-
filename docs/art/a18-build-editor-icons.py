"""Create editor-only AtlasTexture and original SVG resources. Source PNGs read-only."""
import json,hashlib
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/editor/v01';ICONS=OUT/'icons';ICONS.mkdir(parents=True,exist_ok=True)
names={'bunk_bed':'双层床','cell_bars':'铁栏杆','toilet_sink':'洗手台与马桶','workbench':'工作台','tool_locker':'工具柜','communal_table':'长桌长凳','notice_board':'公告栏','cafeteria_counter':'食堂取餐台','cafeteria_return':'餐盘回收架','cafeteria_tray':'朴素餐盘','cafeteria_queue':'排队围栏','heavy_crate_handpaint_v03':'木箱摆设','locked_door_closed_v02':'锁门外观','locked_door_open_v02':'开门外观'}
assets=[];sources=[]
for manifest in ['art/props/prison_v08/manifest.json','art/props/cafeteria_v14/manifest.json','art/props/manifest-v03.json']:
 for spec in json.loads((ROOT/manifest).read_text(encoding='utf-8-sig'))['assets']:
  id=spec['id'];src=ROOT/spec['texture'].removeprefix('res://');im=Image.open(src);a=np.asarray(im)
  assert im.mode=='RGBA'
  requested=spec.get('region',[0,0,im.width,im.height])
  if id.startswith('locked_door_'): requested=[0,100,44,78]
  x,y,w,h=requested;alpha=a[y:y+h,x:x+w,3]>32
  yy,xx=np.where(alpha);assert len(xx)>0
  rx=x+max(0,int(xx.min())-3);ry=y+max(0,int(yy.min())-3)
  rr=x+min(w,int(xx.max())+4);rb=y+min(h,int(yy.max())+4)
  w=rr-rx;h=rb-ry;side=int(np.ceil(max(w,h)*1.12));mx=(side-w)/2;my=(side-h)/2
  text=f'''[gd_resource type="AtlasTexture" load_steps=2 format=3]

[ext_resource type="Texture2D" path="{spec['texture']}" id="1_atlas"]

[resource]
atlas = ExtResource("1_atlas")
region = Rect2({rx}, {ry}, {w}, {h})
margin = Rect2({mx}, {my}, {side-w}, {side-h})
filter_clip = true
'''
  (ICONS/(id+'.tres')).write_text(text,encoding='utf-8')
  category='cafeteria' if id.startswith('cafeteria_') else 'furniture' if manifest.endswith('prison_v08/manifest.json') else 'props'
  assets.append({'id':id,'name':names[id],'category':category,'editor_icon':'res://art/editor/v01/icons/'+id+'.tres'})
  sources.append({'id':id,'source_manifest':manifest,'texture':spec['texture'],'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'editor_crop':[rx,ry,w,h],'virtual_square_size':side,'margin':[mx,my,side-w,side-h],'source_png_unmodified':True})

# Transparent 64-square line symbols. No background, text, internal IDs or police insignia.
symbols={
 'select':('选择','<path d="M15 10v40l10-12 12 17 8-6-12-16 18-4z" fill="#f2ebdd"/><path d="m25 38 6-7" stroke="#328b82"/>'),
 'pan':('平移','<path d="M32 8v48M8 32h48m-30-18 6-6 6 6M26 50l6 6 6-6M14 26l-6 6 6 6M50 26l6 6-6 6"/><circle cx="32" cy="32" r="7" fill="#328b82"/>'),
 'walls':('绘墙','<path d="M9 17h46v34H9zM9 28h46M9 40h46M24 17v11M41 28v12M24 40v11"/><path d="m47 7 10 10-7 7-10-10z" fill="#328b82"/>'),
 'gate_guards':('门岗','<circle cx="29" cy="17" r="8" fill="#f2ebdd"/><path d="M15 49v-7c0-14 28-14 28 0v7z" fill="#328b82"/><path d="m47 27 6 25" stroke="#b18a57" stroke-width="5"/>'),
 'merchants':('商人','<circle cx="23" cy="17" r="8"/><path d="M9 48v-6c0-13 27-13 27 0v6"/><rect x="36" y="31" width="20" height="22" rx="3" fill="#f2ebdd"/><path d="M40 31v-6c0-8 12-8 12 0v6"/><circle cx="46" cy="42" r="3" fill="#c69c5e" stroke="none"/>'),
 'items':('物品放置','<path d="m10 23 22-12 22 12v26L32 59 10 49zM10 23l22 12 22-12M32 35v24"/><path d="M42 8v12m-6-6h12" stroke="#328b82"/>'),
 'work':('工作点','<path d="m14 45 24-25 9 9-24 25z" fill="#b18a57"/><path d="m31 16 8-9 17 16-8 9z" fill="#328b82"/>'),
 'meal':('取餐点','<path d="M10 41h44v12H10zM14 41c0-22 36-22 36 0M32 19v-6"/><path d="M8 33v15M4 41h8" stroke="#328b82"/>'),
 'dine':('用餐点','<circle cx="32" cy="34" r="16"/><circle cx="32" cy="34" r="10" stroke="#328b82"/><path d="M10 13v18m-4-18v11c0 9 8 9 8 0V13M10 31v22M54 13c-8 6-8 19 0 19v21V13"/>'),
 'free':('活动点','<circle cx="30" cy="13" r="6"/><path d="m16 32 14-10 15 5 6 9M30 23l-3 15-11 17M27 38l14 8 5 10" stroke="#328b82"/>'),
 'zones':('区域','<path d="M10 23V10h13M41 10h13v13M54 41v13H41M23 54H10V41"/><rect x="21" y="21" width="22" height="22" rx="2" fill="#328b82" fill-opacity=".2" stroke-dasharray="4 5"/>'),
 'dorm_doors':('寝室门','<path d="M13 55V9h34v46M20 55V16h20v39M33 34h2"/><path d="M28 22c-7 8 2 14 7 8-7 1-9-4-7-8z" fill="#c69c5e" stroke-width="2"/>'),
 'eye':('显示','<path d="M6 32c14-22 38-22 52 0-14 22-38 22-52 0z"/><circle cx="32" cy="32" r="10" fill="#328b82"/><circle cx="32" cy="32" r="3" fill="#f2ebdd" stroke="none"/>'),
 'lock':('锁定','<rect x="15" y="28" width="34" height="27" rx="4" fill="#f2ebdd"/><path d="M22 28V18c0-16 20-16 20 0v10"/><circle cx="32" cy="39" r="3" fill="#328b82" stroke="none"/><path d="M32 40v6" stroke="#328b82"/>'),
 'door_key':('钥匙','<circle cx="19" cy="20" r="11" fill="#c69c5e"/><circle cx="19" cy="20" r="4"/><path d="m27 28 26 26 5-5-7-7 5-5-6-6-5 5-10-10z" fill="#c69c5e"/>'),
 'lock_tool':('撬锁工具','<path d="m13 53 25-30 12-4 5 5-14 6-22 29z" fill="#a5b0a8"/><path d="m9 49 7 6" stroke="#328b82"/>'),
 'scrap':('零件','<path d="m27 10 10 1 2 8 7 4 8-2 4 9-6 6-1 8 3 7-8 5-6-5-8-1-7 4-7-7 4-7-1-8-5-6 5-8 8 2 5-5z" fill="#b18a57"/><circle cx="32" cy="34" r="9" fill="#f2ebdd"/>'),
 'starts':('伙伴起点','<circle cx="32" cy="18" r="8" fill="#c69c5e"/><path d="M17 52V40c0-14 30-14 30 0v12z" fill="#f2ebdd"/><path d="m24 43 6 6 12-13" stroke="#328b82"/>'),
 'patrol':('巡逻点','<path d="M14 15h30v20H20v15" stroke-dasharray="5 5"/><circle cx="14" cy="15" r="5" fill="#328b82"/><circle cx="44" cy="35" r="5" fill="#f2ebdd"/><circle cx="20" cy="50" r="5" fill="#c69c5e"/>'),
 'dormitories':('寝室范围','<rect x="6" y="8" width="52" height="48" rx="4" stroke-dasharray="5 5"/><path d="M15 42V23h11v8h21v11M15 35h32M15 42v7M47 42v7" stroke="#328b82"/>'),
 'door':('主锁门','<path d="M9 56V8h46v48M16 56V15h32v41"/><rect x="25" y="29" width="17" height="18" rx="2" fill="#c69c5e"/><path d="M29 29v-4c0-8 9-8 9 0v4"/>'),
 'crate':('推箱','<rect x="10" y="17" width="33" height="34" rx="2" fill="#b18a57"/><path d="m14 21 25 26M42 35h15m-5-6 6 6-6 6" stroke="#328b82"/>'),
 'exit':('出口','<path d="M15 11H8v42h7M26 11h9v12m0 18v12h-9"/><path d="M20 32h36m-12-10 12 10-12 10" stroke="#328b82" stroke-width="5"/>'),
 'guard_zone':('看守搜查范围','<path d="m12 32 42-20v40z" fill="#c69c5e" fill-opacity=".22"/><path d="M9 32c8-12 20-12 28 0-8 12-20 12-28 0z"/><circle cx="23" cy="32" r="4" fill="#328b82"/>'),
 'bounds':('地图边界','<path d="M8 23V8h15M41 8h15v15M56 41v15H41M23 56H8V41"/><path d="M23 20h18v24H23z" stroke="#328b82" stroke-width="2"/>')}
tools=[]
for id,(name,paths) in symbols.items():
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g fill="none" stroke="#303b46" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">{paths}</g></svg>\n'
 (ICONS/(id+'.svg')).write_text(svg,encoding='utf-8')
 tools.append({'id':id,'name':name,'icon':'res://art/editor/v01/icons/'+id+'.svg'})
tools.append({'id':'guard_start','name':'巡逻看守','icon':'res://art/editor/v01/icons/gate_guards.svg'})
assert len(assets)==14 and len(set(a['id']for a in assets))==14
(OUT/'manifest.json').write_text(json.dumps({'schema':1,'assets':assets,'tools':tools},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(ROOT/'docs/art/a18-icon-sources.json').write_text(json.dumps({'schema':1,'source_pixels_modified':False,'assets':sources,'tools':'Project-owned SVG code, transparent64-square, deep ink/teal/ochre, no imagegen needed for native icon system','display_frames':[48,64]},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'assets':len(assets),'tools':len(tools),'manifest':str(OUT/'manifest.json')},ensure_ascii=False))
