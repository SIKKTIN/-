# P66 完整同源墙体接入

用户批准左右开放的完整母图后，补充T两边过长、应缩短并靠直墙块拼接。本轮A33/P66保留原批准图PNG，仅Atlas/UV组装；T20/24=68/72×121.5，左右短臂24，stemx24。早先132/136默认方案保留为历史，geometry-contract-update.json记录人类补充。

厨房H7/8/11、全高度短T和邻接片整体替換墙顶、灰米墙身、深灰墙脚；不保留旧V24墙身再叠新顶。门柱、楣、外L、V9/10/12/13及端面均用V33原母图。T矩形全121.5高切走原H底层，不使用cap-only cutouts/reuse_cap。H直墙76×121.5重复接长；T左右直接邻接片连续取源，右T靠外L一段邻接片仅有22world空间，通过clip裁掉16world保持原38宽UV尺度。

完整H原点1140、底1261.5；物理root1270/1910不变。V原点1222.751351、clip1261.5时sourceY500与T下口一致，周期94.57297297，两期tile189.14594595；20只压缩截面，左右不反转Y。末端90高同源取source[710,670,120,301]，不再旧V27端面。源PNG无人工涂改/重采样，生产源哈希ffd4bb98964a2f4197b10e2b7f3706efb9e921bd0abbfe36f8a58f7c9cf19840。

现有食堂牌本来由scene_layers独立绘制，并非V24源PNG烘焙，保持现有cafeteria.wall_sign。门开闭旧铁栏图仍独立fixture，仅lintel换同源V33。地图除architecture和门lintel外逐值与baseline一致；没有改物理墙、NPC、日程或门禁。

新建建筑只有V33的16件和仍使用的两个禁闭室壳，共18件；旧ID保留载入/属性兼容。新件配16真实MeshTexture图标，新增render_mode分类适配新L和端面。所有建筑新放置都显式render_size，解决H/V额外默认20高；全H可见bounds与121.5图像一致，支持实际选取拖动撤销。

world_volume增加单patch clip；world_view_rect按viewport/zoom算实际视区，避免概览0.75zoom下地板未绘制部分（默认游戏zoom1行为保持）。原生135检查通过：全墙24×2、palette24×2含真实H/V/T卡点击选放精确尺寸、独立短T墙身/墙脚+四V24、共享editor15；规则73通过。真实下口对V连续参考两侧RGB差0；旧21个建筑PNG/JSON SHA未改。所有最终日志无ERROR。首轮QA两个Array数字类型判定和牌覆盖采样点修正，调色素材未改；palette等待布局后再输入。

最终实际游戏1200/960左右整墙、完整厨房overview闭/开门与编辑器图在docs/tests/p66-*；入口res://scenes/editor/map_editor.tscn。艺术评估由主美对批准母图完整对照，技术通过不代替人类审美批准。project.godot的既有用户改动保留未纳入。
