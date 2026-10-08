# P77 连通建筑分区屋顶

按已确认概念替换当前遮挡效果，保留当前 R04 地图、四向门、开放走廊和共墙布局。主角进房只揭开当前房间；离开后重盖，沿用 0.2 秒过渡与门槛缓冲。

## 交付

- 11 个独立屋顶：三寝室、三禁闭室、车间、食堂、仓库、洗衣房、设备间。
- 四套屋面：灰绿金属、浅灰金属、暖灰混凝土、深灰混凝土；配通风罩、厨房排烟、排风扇和通气帽。
- 屋顶根据现有墙体碰撞条带和视觉门头生成，凹入口保留北/南/东/西门，缺墙通道也留出缺口。旧禁闭室固定南向预制壳停用。
- 可见范围编辑器新增屋顶样式选项，带对应图标。自动按建筑选择，也可逐房指定。编辑视图保持室内可见，试跑应用遮挡。
- 静态重复 UV 面板缓存，主角移动和 AI 更新不重建网格；材料 mipmap 在区域裁取后生成，避免图集串色。

## 验证

124 项检查（52 无窗口运行、52 原生画面、10 无窗口编辑器、10 原生编辑器）全部通过。覆盖全部房间独立揭顶、邻室隐藏、四向门洞、无门通路、人物与聊天信息过滤、侧门保留和编辑器保存/撤销/重做/重载。200 个碰撞点切换前后一致。运行日志无脚本错误。

同地图、1200×720、RTX 4050、关闭垂直同步，最终三场景 FPS 为 70.57、71.48、73.68。后台编辑器与负载影响帧率，不将测量增幅解释为单一改动的收益。

当前地图 SHA256：437b86cdc6e05cdb26f11a7b2dd633af90e0b8d425f0b64a0ea665dde5c04298（本任务未写地图）。现有其它美术、地图、程序和编辑器未提交修改保留。

## 美术与入口

使用内置 image_gen 工具，提示词记录在 art-prompts.json。批准概念与原图保留；项目消费的是工程内文件：

- art/architecture/room_roofs_v47/materials.png
- art/architecture/room_roofs_v47/attachments.png
- art/architecture/room_roofs_v47/concept.png
- art/architecture/room_roofs_v47/manifest.json
- art/editor/room_roofs_v47/manifest.json 与 8 个图标 .tres

启动 res://scenes/main.tscn；原生截图 docs/tests/p77-compound-covered.png、p77-compound-cafeteria-revealed.png、p77-editor-roof-picker.png。

屋顶采用参数化边界与材质，门和墙仍由原地图渲染；后续更改墙体后重开/试跑会自动重算。不增加角色传送或改动 NPC 日程。
