"""Register approved item concepts without modifying any room or player save."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPECS = [{"id":"biscuits","name":"饼干","short":"饼干","group":"life","grid_size":[1,1]},{"id":"canned_meat","name":"肉罐头","short":"罐头","group":"life","grid_size":[1,1]},{"id":"instant_coffee","name":"速溶咖啡","short":"咖啡","group":"life","grid_size":[1,1]},{"id":"cigarettes","name":"香烟","short":"香烟","group":"life","grid_size":[1,1]},{"id":"painkillers","name":"止痛药","short":"药片","group":"life","grid_size":[1,1]},{"id":"antiseptic","name":"消毒药水","short":"消毒液","group":"life","grid_size":[1,1]},{"id":"duct_tape","name":"胶带","short":"胶带","group":"tools","grid_size":[1,1]},{"id":"screw_box","name":"螺丝盒","short":"螺丝","group":"tools","grid_size":[1,1]},{"id":"work_gloves","name":"工作手套","short":"手套","group":"tools","grid_size":[2,1]},{"id":"pliers","name":"钳子","short":"钳子","group":"tools","grid_size":[1,2]},{"id":"repair_kit","name":"维修包","short":"维修包","group":"tools","grid_size":[2,2]},{"id":"canvas_pouch","name":"帆布扩容袋","short":"扩容袋","group":"tools","grid_size":[2,2]},{"id":"duty_roster","name":"值班表","short":"班表","group":"documents","grid_size":[2,1]},{"id":"delivery_note","name":"送货单","short":"货单","group":"documents","grid_size":[2,1]},{"id":"work_id","name":"工作证","short":"工证","group":"documents","grid_size":[1,1]},{"id":"temporary_pass","name":"临时通行证","short":"通行证","group":"documents","grid_size":[1,1]},{"id":"work_clothes","name":"工作服","short":"工作服","group":"documents","grid_size":[2,2]},{"id":"secret_note","name":"秘密便条","short":"便条","group":"documents","grid_size":[1,1]}]

def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8-sig'))

def write(path, value):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def register():
    library = read('data/items/library.json')
    existing = {item['id']: item for item in library['items']}
    legacy_categories = dict(scrap='material', door_key='tool', lock_tool='tool', copper_wire='material', wrench='tool', cloth='material', bandage='medical', bread='food', factory_map='document', gear='material')
    for item in library['items']:
        item.setdefault('category', legacy_categories.get(item['id'], 'misc'))
    info = {
        'biscuits': ('food', '使用后恢复15点饱腹，吃饱时不会消耗。', 4, {'use_action':'食用', 'consumable':True, 'restore':{'stat':'fullness','amount':15}}),
        'canned_meat': ('food', '使用后恢复40点饱腹，吃饱时不会消耗。', 9, {'use_action':'食用', 'consumable':True, 'restore':{'stat':'fullness','amount':40}}),
        'instant_coffee': ('food', '使用后恢复20点体力，体力已满时不会消耗。', 7, {'use_action':'饮用', 'consumable':True, 'restore':{'stat':'stamina','amount':20}}),
        'cigarettes': ('social', '靠近一位空闲工友后赠送，提高好感与信任；成功送出才消耗。', 10, {'use_action':'赠送工友', 'consumable':True}),
        'painkillers': ('medical', '使用后恢复30点体力，体力已满时不会消耗。', 10, {'use_action':'使用', 'consumable':True, 'restore':{'stat':'stamina','amount':30}}),
        'antiseptic': ('medical', '使用后恢复15点体力，体力已满时不会消耗。', 5, {'use_action':'处理擦伤', 'consumable':True, 'restore':{'stat':'stamina','amount':15}}),
        'duct_tape': ('material', '维修用胶带，可搜刮、携带和整理；制作材料。', 4, {}),
        'screw_box': ('material', '装有螺丝和螺帽的小铁盒；制作材料。', 5, {}),
        'work_gloves': ('equipment', '旧皮革工作手套，可搜刮和携带。', 12, {'implementation_status':'可搜刮 / 可整理（穿戴待接入）'}),
        'pliers': ('tool', '车间钳子，占两格，可搜刮和携带。', 14, {'implementation_status':'可搜刮 / 可整理（工具操作待接入）'}),
        'repair_kit': ('tool', '装有维修工具的帆布包，占四格，可搜刮和携带。', 20, {'implementation_status':'可搜刮 / 可整理（维修操作待接入）'}),
        'canvas_pouch': ('equipment', '安装后本轮背包扩充到30格；已达30格时不会消耗。', 24, {'use_action':'安装扩容袋','consumable':True}),
        'duty_roster': ('document', '记录园区作息与劳动时间，阅读不会消耗。', 6, {'use_action':'阅读','read_text':'园区日常安排\n\n08:00 起床准备\n09:00–12:00 上午劳动\n12:00–14:00 午间休息\n14:00–17:00 下午劳动\n17:00 后可自由活动\n\n留意看守巡逻的位置，工作与休息期间的路线有所不同。'}),
        'delivery_note': ('document', '仓库的送货凭单，记录物流出口与装卸场的位置。', 8, {'use_action':'阅读','read_text':'货物交接单\n\n物资由仓库转送到东侧装卸场。\n物流出口位于园区东北角。\n\n搬运过程中需要经过仓库和装卸场的门口。\n观察物流通道，与正门、后勤通道比较路线。'}),
        'work_id': ('document', '车间工作证，记录工厂身份，可查看证件。', 12, {'use_action':'查看证件','read_text':'园区车间工作证\n\n所属区域：生产车间\n身份：工厂工作人员\n\n证件注明：仅限工作区域使用，通行须经门岗检查。','implementation_status':'可搜刮 / 可阅读（身份验证待接入）'}),
        'temporary_pass': ('document', '临时通行证，可查看上面的通行记录。', 18, {'use_action':'查看证件','read_text':'园区临时通行证\n\n登记区域：物流与后勤通道\n\n证件注明：出入须配合门岗检查。\n不要把一张证件当成已经打开的门。','implementation_status':'可搜刮 / 可阅读（门岗验证待接入）'}),
        'work_clothes': ('equipment', '折叠的灰蓝工作服，占四格，可搜刮和携带。', 16, {'implementation_status':'可搜刮 / 可整理（穿戴与伪装待接入）'}),
        'secret_note': ('document', '夹在角落里的纸条，记录后勤路线的线索。', 5, {'use_action':'阅读','read_text':'有人留下的便条\n\n洗衣房后面连着设备间。\n南侧后勤通道沿围墙通往东南出口。\n\n先看清道路和门的位置，再准备需要的工具。\n空闲时找工友聊聊，也许能问到更多消息。'}),
    }
    assets = read('data/presentation/inventory-assets-v07.json')
    for source in SPECS:
        item = {key:value for key,value in source.items() if key != 'group'}
        category, description, price, extras = info[item['id']]
        item.update(category=category, description=description, buy_price=price//2, sell_price=price, implementation_status='可搜刮 / 可使用' if extras.get('use_action') else '可搜刮 / 可整理（制作待接入）')
        item.update(extras)
        if item['id'] in existing: existing[item['id']].update(item)
        else: library['items'].append(item)
        assets['items'][item['id']] = {'texture':'res://art/items/expansion_v01/'+item['id']+'.png', 'trim_transparent':True, 'world_size':[26,26], 'hud_size':[48,48]}
    additions = {
        'personal':['biscuits','instant_coffee','cigarettes','secret_note'],
        'industrial':['duct_tape','screw_box','work_gloves','pliers','repair_kit'],
        'tools':['duct_tape','screw_box','pliers','work_gloves','repair_kit'],
        'medical':['painkillers','antiseptic'],
        'office':['duty_roster','delivery_note','work_id','temporary_pass','secret_note'],
        'warehouse':['canned_meat','biscuits','instant_coffee','canvas_pouch','delivery_note','temporary_pass'],
        'linen':['work_gloves','work_clothes','canvas_pouch'],
    }
    loot = read('data/items/loot_tables.json')
    for profile, kinds in additions.items():
        for kind in kinds:
            if kind not in loot['profiles'][profile]['items']: loot['profiles'][profile]['items'].append(kind)
    write('data/items/library.json',library)
    write('data/presentation/inventory-assets-v07.json',assets)
    write('data/items/loot_tables.json',loot)
    print(f'Registered {len(SPECS)} new items; library now {len(library["items"])} items. Rooms unchanged.')

if __name__ == '__main__': register()
