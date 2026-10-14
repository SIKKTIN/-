# 食堂概念还原

已把确认的 concept-final-v1.png 接入当前 R04：北侧连续后厨与配餐区、五组南北向桌凳、独立餐盘和搪瓷杯、饮水桶、回收架、食堂师傅、新墙面和暗灰屋顶均已完成。

## 素材与注册

使用内置 imagegen 制作 8 张正式 PNG，原图字节完整保留。通过裁切元数据、脚印、锚点和等比尺寸注册，没有用脚本重绘或压扁素材。

| 原始 PNG | 保存位置 |
| --- | --- |
| 纵向空桌凳 | art/props/cafeteria_redesign_v1/table_vertical.png |
| 空配餐台 | art/props/cafeteria_redesign_v1/counter.png |
| 连续后厨 | art/props/cafeteria_redesign_v1/backline.png |
| 独立配餐盆、饭锅和汤锅 | art/props/cafeteria_redesign_v1/service_food.png |
| 饮水桶与杯架 | art/props/cafeteria_redesign_v1/water_urn.png |
| 墙面材料 | art/architecture/cafeteria_v1/wall.png |
| 防滑地砖 | art/architecture/cafeteria_v1/floor.png |
| 暗灰金属屋面 | art/architecture/cafeteria_v1/roof.png |

[完整生成提示词及源文件](production-assets.json)，[原图 SHA 与注册记录](asset-registration.json)。完整资源定义在 art/architecture/cafeteria_v1/manifest.json，共 38 项，包括墙片、四向转角、三向接头、窗、壁灯、家具和材料。

餐盘复用 cafeteria_tray_v41，杯子复用搪瓷杯原图，回收架复用现有原图并注册紧凑比例；厨师复用 canteen_cook，保持当前 1.4 倍人物比例。旧定义与旧 PNG 保留。

## 最终布局和流程

食堂室内范围保持 1360×560。五组桌凳脚印最终校准为 140×210；配餐台 720×35，后厨 830×64。桌间、配餐台前和南侧通路经过实际寻路检查。回收架放在东侧墙边，避开设备间门前的站位。

墙面采用暖白灰泥、灰橄榄瓷砖与薄金属收边；76 个既有墙片替换视觉材质，保留全部原墙体坐标和碰撞参数。新屋顶使用独立材料和食堂排烟管、风扇，继续由现有房间可见性系统切换。

四个原门禁 ID、开闭规则及坐标保留。原北侧两入口、南侧洗衣房后门、设备间检修门均可通行。午餐继续沿用 12:00–14:00 规则；靠近配餐点按 E 领取后，角色前往自己的用餐位置，不新增价格或饱食数值。

厨师站在后厨与前台之间的工作通道，值班时间为 11:00–14:00。原照明覆盖保留，食堂内悬浮在桌面上的旧灯具图标隐藏，墙上使用新的壁灯外观。

## 编辑与代码

新资源已加入 PropCatalog 和编辑器真实预览，可分别移动桌凳、配餐台、饭菜盆、杯盘、饮水桶和厨师岗位。常驻角色统一标为“常驻人员”，避免把厨师显示成医护。

主要入口：
- tools/register_cafeteria_redesign.py：素材注册与食堂范围内地图布局接入。
- scripts/presentation/room_cover.gd：增加 cafeteria 屋顶材料与食堂附属设施，保留其他房间样式。
- scripts/presentation/scene_layers.gd：支持隐藏旧纪律牌，保留用餐标签与真实食堂标识。
- qa/cafeteria_redesign.gd：原生窗口实机、寻路、用餐和编辑器检查。

## 验证与预览

177 项食堂检查全部通过，覆盖原 PNG、编辑器验证、墙体碰撞保留、其他房间数据保留、五组桌凳、所有用餐点、桌间走道、四个门口、实际取餐到就餐、桌面物品排序、屋顶切换和闲置时屋顶几何缓存。7 组相关回归全部通过，共 247 项：编辑器、渲染缓存、人物遮挡、手动控制、互动提示、水卡流程、旧地图。

[食堂检查报告](checks.json)，[相关回归报告](regression/results.json)。浴室回归的柜子站位已改为读取当前设施位置，140 项水卡检查通过。

实机与编辑器截图：
- [室内](runtime-interior.png)
- [独立屋顶](runtime-roof.png)
- [地图编辑器](editor-cafeteria.png)

open-editor.gd 打开新窗口并定位到食堂；play-cafeteria.gd 提供固定 12:30 的独立试玩，时间设置只存在试玩进程，不修改正式地图。
