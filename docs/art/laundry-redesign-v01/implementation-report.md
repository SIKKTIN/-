# 洗衣房概念图还原记录

日期：2026-10-13。用户批准 `concept-final.png` 后，已写入 `data/rooms/r04.json`。

北墙重排四台等尺寸滚筒洗衣机与四位供水管。西侧保留窄用品架并加入帆布脏衣车、两只蓝桶和窄分拣架；东北净衣架、东侧水池与排水盖保持可接近。南侧工作台换为金属台面、灰蓝底柜及周转箱，净衣车停在台侧。墙面复用灰蓝防水瓷砖，并补上排风格栅和笼罩壁灯。独立金属屋顶、采光带、屋面排风及落水管继续使用。

北门洞为 `[1000,3400,120,20]`，使用新单扇钢门；南门洞为 `[1520,3900,180,20]`。两处旧洞均填回实体墙，门上收口采用独立无碰撞门楣。西侧自由入口、东侧受控检修门、周围建筑交接节点保留。北门仍为12:00–14:00开放，东侧仍连接 `maintenance-entry`。为避免敞开门扇挡住文字，门牌最终放在南门左侧；概念图中关闭门时的右侧门牌未直接照搬。

翻找容器保留原有对象ID和 `linen` 配置。金属台向房内退让，避免南墙立面盖住台下格子；布草车避开南门敞开叶片。北门外补一段接近铺装和横向连接，不修改食堂现有门与铺装。

## 资源与生成

内置 imagegen 制作三份原始透明PNG，复制后字节哈希与源图一致：

- `art/props/laundry_v2/folding_table.png`：金属叠衣台。
- `art/props/laundry_v2/dirty_station.png`：脏衣收集与蓝桶分拣组合。
- `art/architecture/laundry_v2/north_door_states.png`：北侧单扇门的开、关状态。

提示词为 `production-table-prompt.txt`、`production-dirty-prompt.txt`、`production-north-door-prompt.txt`。来源、哈希与登记ID见 `production-assets.json`。洗衣机、管线、壁灯、排风格栅采用现有原图和原生资源元数据；没有修改现有PNG。南北门投影始终沿横墙，东侧检修门保持纵墙薄侧面。北门开关复用同一组门框像素。

登记清单为 `art/props/laundry_v2/manifest.json` 与 `art/architecture/laundry_v2/manifest.json`，通过 `scripts/presentation/prop_catalog.gd` 同时供游戏、地图编辑器使用。每个组合仍是独立可选择对象。新大图运行时限制为512像素，复用墙饰限制为256像素，不增加实时粒子、灯光或水面。

## 验证

`qa/laundry_redesign.gd` 完成实际运行与编辑器检查：无界面74项、原生窗口76项均通过，结果保存为 `checks-headless.json`、`checks-native.json`，失败列表为空。验证覆盖：

- 四台机器尺寸一致，地面占位不相交、工作位可寻路。
- 北门开放时段、开关整身碰撞、北进南出的连通。
- 两处旧门洞被实体墙封回，东西侧入口通行与检修关联保留。
- 布草容器翻找、揭示物品、拿到背包及移回工作台。
- 室内隐藏屋顶、室外完全不透明、门牌可见、侧门朝向。
- 新资源出现在编辑器，擦除、撤销、另存临时地图及重载一致。
- 其他摆设、门禁、房间遮挡、未选墙与共享交接节点保持一致，验证不会写回正式地图。

原生1280×900窗口、画布80%缩放、同一视野下各采样40帧平移：改造前中位20.514毫秒/帧、95分位23.427毫秒；改造后中位18.712毫秒/帧、95分位20.303毫秒，记录见 `editor-pan-performance.json`。这是局部对比，不代表全地图最低帧率；同时检查平移没有刷新建筑几何和门几何。

地图采用最新保存文件生成候选、检查输入哈希再写入。`last-input-map.json` / `map-before-save.json` 保存原地图，`last-output-map.json` 保存最终结果，`map-registration.json` 记录改动对象与墙索引映射。没有覆盖原先的用户 `.bak` 或关闭已有编辑器草稿。Godot MCP未发现连接会话，本次以原生项目文件登记和引擎运行验证完成。

实景图片：`runtime-interior.png`、`runtime-north-closed.png`、`runtime-roof.png`、`editor-layout.png`。`open-editor.gd` 可打开新的已保存地图预览窗口并定位洗衣房。
