# R04统一斜俯视物件

以批准的docs/art/cafeteria-tables-v41/concept-overhead-v4.png为视角基准，补齐上一轮未替换的后排厨具和取餐台，并检查R04全部物件。俯视顶面与可读正面并存，长方体边缘与地面横竖网格平行，减少梯形收缩和倾斜侧面；保留手绘材质。

内置image_gen生成九张透明原图，正式文件位于art/props/prison_v42，原始PNG完整复制，未改像素。完整提示词与原始输出文件对应见generation-prompts.json；manifest.json含SHA256、原生裁切区域及等比落地注册。

新物件：

- cafeteria_counter_v42.png：取餐台、食物盘、锅与餐盘堆。
- cafeteria_backline_v42.png：靠墙后排、冰箱、柜、操作架与水槽。
- cafeteria_return_v42.png：餐盘回收架。
- workbench_v42.png：木制工作台与台钳。
- tool_locker_v42.png：工具柜，修正顶盖梯形。
- laundry_cart_v42.png：推车，去掉斜侧面，顶口对齐网格。
- wash_basin_v42.png：双位洗手池。
- bunk_bed_v42.png：双层床。
- toilet_sink_v42.png：马桶与洗手池组合。

活动走廊两组餐桌复用已批准的V41餐桌原图，用communal_table_v42定义按原190×100占地等比注册。食堂V41餐桌和餐盘保持原样。共10个新版放置素材，R04共23个原有摆设更新图片引用。

已核对并保留：墙体/门/禁闭室建筑、栅栏、壁灯、告示牌、门禁读卡器、通风口、阀门、灭火器、排队围栏及木箱，现有投影适合场景；封闭禁闭室内的单人床不显示在外，保留旧图。没有修改建筑材质、构造、碰撞或机关规则。

所有原有摆设rect、阻挡移动/视线字段保持原值。更新的图片按实际摆设宽度等比缩放，再按原占地底边落地，避免原摆设不同深宽比拉扁图片。后排仍贴墙，工作通道和取餐台入口保持畅通。旧PNG与定义保留；旧版家具从新放置列表隐藏，正式“家具/设施→家具摆设”“食堂设施→取餐/回收”提供当前版本，支持独立放置、选择、复制、移动。

验证：

- checks.json：72项原生编辑器与运行场景检查通过，含10件素材/图标、源文件SHA、透明背景、等比缩放、独立放置、原碰撞和餐桌保留、后厨靠墙与工作通道寻路、运行时加载。
- single-player-checks.json：当前P68单主角规则49项通过，覆盖工作、就餐、归寝、禁闭释放、主角撬锁和逃脱。
- day-cycle-checks.json：当前P68自然日程6项通过。
- legacy-access-checks.json：旧P66三人操控用例不适用于当前单主角规则，失败原因记录保留，未放宽或更改游戏逻辑来满足旧测试。旧图wash_basin硬编码加载断言也已被新版运行时加载检查替代。

本次期间项目另有修改在R04加入工厂定时门。首次原生检查后产生的独立地图变更已保留，见external-map-changes.json。r04-before-props.json是本次开始的备份，r04-review-baseline.json是最终检查采用的当前地图快照；所有原有摆设占地在两个状态均未改变。integrate.py重新执行时基于当前文件合并，避免回退独立地图变化。

r04-kitchen-editor.png、r04-workshop-editor.png、r04-cells-editor.png、r04-full.png、r04-kitchen-runtime.png均为实际渲染截图，r04-editor-open.png为当前编辑器。尚未提交、发布或反馈制作人，待实际效果审评。
