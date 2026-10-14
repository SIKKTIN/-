"""Register untouched generated PNGs and update only bathroom service fixtures."""
from pathlib import Path
from copy import deepcopy
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/bath-watercard-v1'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def bounds(im):
    box=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
    x,y,r,b=box
    return [max(0,x-3),max(0,y-3),min(im.width,r+3)-max(0,x-3),min(im.height,b+3)-max(0,y-3)]
def main():
    records=read(DOC/'generated-assets-v1.json');assets={}
    for record in records['assets']:
        p=ROOT/record['path'];im=Image.open(p)
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
        assert p.read_bytes()==Path(record['source']).read_bytes()
        assets[record['key']]=dict(texture='res://'+record['path'],region=bounds(im),texture_size=list(im.size),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),source_kind='built-in-imagegen-original-png')
    sheet=Image.open(ROOT/'art/characters/bath_cashier_v1/cashier_poses.png')
    frames={}
    for i,key in enumerate(['idle','counting','handover']):
        x=i*sheet.width//3;end=(i+1)*sheet.width//3
        local=sheet.crop((x,0,end,sheet.height));r=bounds(local);r[0]+=x
        core=local.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
        feet=local.getchannel('A').crop((0,core[3]-80,local.width,core[3])).point(lambda a:255 if a>=180 else 0).getbbox()
        anchor=[x+(feet[0]+feet[2])/2-r[0],core[3]-r[1]-2]
        frames[key]=dict(region=r,anchor=anchor)
    idle=frames['idle']
    character=dict(id='bath_cashier',name='浴室收费员',texture=assets['cashier']['texture'],texture_size=list(sheet.size),world_height=60,scale_height=710,frames={'idle':idle['region']},anchor={'idle':idle['anchor']},portrait_region=[185,85,315,300],service_frames={k:v for k,v in frames.items() if k!='idle'},walk_animation=dict(texture=assets['cashier']['texture'],fps=1,frames=[deepcopy(idle)]),shadow_baked=False,sha256=assets['cashier']['sha256'])
    write(ROOT/'art/characters/bath_cashier_v1/manifest.json',dict(schema=1,version='bath-cashier-v1',characters=[character]))
    p=ROOT/'data/presentation/character_libraries.json';catalog=read(p);entry='res://art/characters/bath_cashier_v1/manifest.json'
    if entry not in catalog['libraries']:catalog['libraries'].append(entry)
    write(p,catalog)
    prop=deepcopy(assets['counter']);_,_,w,h=prop['region'];width=116;depth=36;ratio=width/w
    prop.update(id='bath_recharge_counter',name='水卡充值柜台',render_mode='projected_prop',world_size=[width,h*ratio],render_size=[width,h*ratio],ground_rect=[0,h-depth/ratio,w,depth/ratio],footprint_world_size=[width,depth],elevation_world=h*ratio-depth,proportion_locked=True,blocking=True,shadow_baked=False,alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',editor_subcategory='furnishings')
    write(ROOT/'art/props/bath_watercard_v1/manifest.json',dict(schema=1,assets=[prop]))
    p=ROOT/'data/presentation/inventory-assets-v07.json';inv_art=read(p);card=deepcopy(assets['water_card']);card.update(world_size=[32,32*card['region'][3]/card['region'][2]],hud_size=[48,48*card['region'][3]/card['region'][2]]);inv_art['items']['water_card']=card;write(p,inv_art)
    p=ROOT/'data/items/library.json';library=read(p)
    spec=dict(id='water_card',name='水卡',short='水卡',description='公共浴室储值卡。找浴室收费员充值，使用花洒时自动检测并扣费。余额随这张卡保留，洗澡不会消耗水卡本身。',grid_size=[1,1],category='document',buy_price=0,sell_price=0,use_action='查看余额',consumable=False,initial_state={'water_balance':0},acquisition_sources=['公共浴室 · 收费员充值领卡'],implementation_status='已接入：人工充值 / 花洒扣费 / 独立余额')
    library['items']=[v for v in library['items'] if v['id']!='water_card']+[spec];write(p,library)
    path=ROOT/'data/rooms/r04.json';before=path.read_bytes();room=read(path)
    if not (DOC/'baseline-r04.json').exists():(DOC/'baseline-r04.json').write_bytes(before)
    bath=next(r for r in room['visibility_rooms'] if r['id']=='bath');x,y,w,h=bath['rect']
    room['fixtures']=[f for f in room['fixtures'] if f['id'] not in ['campus-bath-locker-1','campus-bath-recharge-counter']]
    counter=dict(id='campus-bath-recharge-counter',asset_id='bath_recharge_counter',rect=[x+w-160,y+416,116,36],blocks_movement=True,blocks_sight=False)
    room['fixtures'].append(counter)
    for f in room['fixtures']:
        if f['asset_id']=='bath_shower_single':f['interaction_kind']='paid_shower'
        if f['id']=='campus-bath-basket':f['rect']=[x+w-38,y+420,30,30*37.3333/48]
    room['resident_staff']=[f for f in room.get('resident_staff',[]) if f['id']!='bath-cashier']
    staff=dict(id='bath-cashier',name='浴室收费员',appearance_id='bath_cashier',position=[counter['rect'][0]+58,counter['rect'][1]-38],patrol=[],speed=0,wait_seconds=7,work_start=480,work_end=1200,room_id='bath',service_role='water_recharge')
    room['resident_staff'].append(staff)
    room['bath_service']=dict(enabled=True,cashier_id='bath-cashier',counter_id=counter['id'],shower_cost=2,duration_seconds=6,restore_stamina=20,recharge_amounts=[5,10,20])
    assert path.read_bytes()==before,'Map changed during registration; retry from latest.'
    write(path,room);write(DOC/'registration-input.json',json.loads(before));write(DOC/'registration-output.json',room)
    write(DOC/'asset-registration.json',dict(mode=records['mode'],assets=assets,character_frames=frames,counter=counter,staff=staff,service=room['bath_service']))
    print('Registered cashier poses, water-card item/icon and recharge counter. Six existing showers share the paid service.')
if __name__=='__main__':main()
