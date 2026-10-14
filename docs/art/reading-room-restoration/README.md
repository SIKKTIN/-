# 阅览室概念还原

已将 R04 北侧新增宿舍改为阅览室。保持原右侧入口、建筑范围和墙体碰撞，沿用现有混凝土屋顶。原宿舍床、柜、马桶、洗漱台与矮凳已替换。

## 美术

使用内置 imagegen，依据 ../reading-room-concept/concept-v1.png 制作 7 张独立透明 PNG：书架、四人阅读桌椅、报刊架、还书柜、门牌时钟告示栏、圆盆绿植、暖光壁灯。原图完整保存在 art/props/reading_room_v1/，仅用 region/ground_rect 元数据校准尺寸，未修改生成像素。完整提示词及源路径见 generated-assets.json；SHA256、注册路径及地图摘要见 registration.json。

游戏和编辑器统一通过 scripts/presentation/prop_catalog.gd 读取 manifest.json。编辑器可搜索“阅览室”，桌椅作为一组完整家具移动。

## 布局与交互

房间 reading-room：[120,220,560,300]。右侧入口沿用 [680,380,20,140]。
北侧双书架、中央四人桌椅、左侧报刊架及绿植、东北告示栏与壁灯、东侧还书柜。房间地砖缩为 40 单位格线，以贴合概念图。
两组书架和还书柜沿用游戏翻找系统，使用 reading_room 掉落表，只出现纸条、地图、值班表、送货单等现有线索物品。本轮完成场景还原和翻找接入，未新增阅读成长或借阅系统。

## 检查与预览

qa/reading_room_restoration.gd 原生运行完成 126 项检查，failed=[]。检查包括原 PNG 完整性、透明边缘、素材注册、地图校验、物理家具分离、入口和桌边路径、书架及还书柜搜索、屋顶进出切换、测试期间不改地图。

- runtime-interior.png：白天实机
- runtime-night.png：夜间实机
- runtime-exterior.png：外部屋顶
- editor.png：地图编辑器
- checks.json：检查结果
- native.log：原生运行日志

before.json 为改造输入，after.json 为最终场景快照。素材制作期间另一个编辑流程移动了 workshop-two-corner-crate；该修改已保留，见 registration.json 的 concurrent_fixture_changes。polish-before/after.json 保存最后灯光位置修正的前后快照。

## 启动

Godot --path <项目目录> --script res://docs/art/reading-room-restoration/open-editor.gd

生产注册脚本 tools/register_reading_room.py 只允许将未改造的 dorm-north 转换一次，防止重复覆盖后续手工调整。