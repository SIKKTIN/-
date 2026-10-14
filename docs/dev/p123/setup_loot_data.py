import json
from pathlib import Path
from collections import Counter
from PIL import Image

ROOT=Path(__file__).resolve().parents[3]
def read(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def save(path,data):(ROOT/path).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
library=read('data/items/library.json')
old={item['id']:item for item in library['items']}
old['scrap'].update(description='旧零件，可以收集、携带或带出。',grid_size=[1,1])
old['door_key']['grid_size']=[1,1]
old['lock_tool']['grid_size']=[2,1]
specs=[
 ('copper_wire','铜线',[2,1],'工具材料，可收集、携带或带出。'),
 ('wrench','扳手',[1,3],'车间工具，可收集、携带或带出。'),
 ('cloth','布料',[2,1],'生活材料，可收集、携带或带出。'),
 ('bandage','绷带',[1,1],'使用后恢复20点体力，状态已满时不会消耗。'),
 ('bread','馒头',[1,1],'使用后恢复25点饱腹，吃饱时不会消耗。'),
 ('gear','齿轮',[1,1],'机械零件，可收集、携带或带出。')]
for kind,name,shape,description in specs:
    old[kind]=dict(id=kind,name=name,short=name,grid_size=shape,description=description,buy_price=0,sell_price=0)
library['items']=list(old.values())
save('data/items/library.json',library)
profiles={
 'personal':dict(label='私人物品柜',items=['cloth','bread','cloth','bandage','scrap','door_key']),
 'industrial':dict(label='零件柜',items=['copper_wire','gear','scrap','copper_wire','wrench','lock_tool']),
 'tools':dict(label='工具柜',items=['wrench','scrap','gear','copper_wire','lock_tool']),
 'medical':dict(label='医务柜',items=['bandage','bandage','cloth','bread']),
 'office':dict(label='文件柜',items=['cloth','scrap','copper_wire','door_key']),
 'warehouse':dict(label='物资箱',items=['cloth','copper_wire','gear','scrap','bread','bandage']),
 'linen':dict(label='衣物柜',items=['cloth','cloth','bandage','bread'])}
save('data/items/loot_tables.json',dict(schema=1,profiles=profiles))
mapping={'bedside_cabinet_v44':'personal','parts_cabinet_v44':'industrial','tool_locker_v42':'tools',
         'medical_cabinet_v47':'medical','filing_cabinet_v47':'office','office_desk_v47':'office',
         'changing_lockers_v47':'linen','metal_shelf_v44':'industrial','warehouse_rack_v43':'warehouse',
         'shipping_crates_v44':'warehouse','cargo_pallet_v43':'warehouse','sack_pallet_v44':'warehouse'}
room=read('data/rooms/r04.json')
count=Counter()
for f in room['fixtures']:
    profile=mapping.get(f['asset_id'])
    if not profile:continue
    f['loot_profile']=profile
    f['loot_name']=profiles[profile]['label']
    x,y,w,h=f['rect']; cx,cy=x+w/2,y+h/2
    f['loot_location']=next((r['name'] for r in room['visibility_rooms'] if r['rect'][0]<=cx<=r['rect'][0]+r['rect'][2] and r['rect'][1]<=cy<=r['rect'][1]+r['rect'][3]),'园区')
    count[profile]+=1
save('data/rooms/r04.json',room)
skills=read('data/skills/library.json')
next(s for s in skills['skills'] if s['id']=='backpack').update(capacity=30,description='被动能力：背包扩展到30格，普通背包20格；大物品占多个格子。')
save('data/skills/library.json',skills)
assets=read('data/presentation/inventory-assets-v07.json')
with Image.open(ROOT/'art/ui/looting_v01/items.png') as im:
    cell=(im.width//3,im.height//2)
    for i,(kind,*_) in enumerate(specs):
        x,y,r,b=[(0,0,580,570),(600,0,1024,570),(1024,0,1536,570),(0,570,512,1024),(512,570,1024,1024),(1024,570,1536,1024)][i]
        local=im.getchannel('A').crop((x,y,r,b))
        bounds=local.point(lambda a:255 if a>=220 else 0).getbbox()
        if bounds is None:raise RuntimeError('Icon missing: '+kind)
        l,t,r,b=bounds
        assets['items'][kind]=dict(texture='res://art/ui/looting_v01/items.png',region=[x+l,y+t,r-l,b-t],world_size=[26,26],hud_size=[28,28])
save('data/presentation/inventory-assets-v07.json',assets)
save('docs/dev/p123/containers.json',dict(total=sum(count.values()),profiles=dict(count)))
print(dict(total=sum(count.values()),profiles=dict(count)))
