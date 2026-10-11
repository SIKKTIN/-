# R04 黑工厂细节补充 · V44

已保存到 `data/rooms/r04.json`，在扩建版布局上增加 143 个可单独选取、移动或删除的摆设，总摆设数由 92 增至 235。另加 102 条地面绘制记录，包括货架编号、储货框、车位、装卸引导线、安全斜纹及排水沟。原有墙体瓦片、门禁、拾取物、日常岗位与三个逃脱出口保持不变。

车间增加两类台面工具、钻床、零件柜和备用电机；仓库与装卸场混用木箱、麻袋托盘、油桶、料架和搬运设备；寝室补私人物品柜与布草；后勤补待洗衣物、检修工具和阀门管线；厂区边缘补废缆、轮胎、灌木、杂草与碎石，绿化使用不同素材和不等间距。

## 素材

使用内置 imagegen 生成两张透明原图，共 20 种通用资产。原始 PNG 字节未修改，通过区域元数据注册，全部在“家具 / 设施 → 家具摆设”中可找到，配套 20 个原生编辑器图标。

- [资产定义](../../../art/props/factory_v44/manifest.json)
- [工业小件原图](../../../art/props/factory_v44/detail_atlas.png)
- [生活、货物与环境变化原图](../../../art/props/factory_v44/variation_atlas.png)
- [工业小件生成提示词](generation-prompt.txt)
- [变化素材生成提示词](variation-prompt.txt)
- [原图哈希及裁切区域](art-registration.json)

地面标线由 `scripts/presentation/site_details.gd` 统一绘制，编辑器与游戏读取同一份世界坐标记录。标线没有碰撞，摆设依照物件性质配置碰撞和视线遮挡。布局脚本预留日常点、拾取点、看守岗位、门前后落脚点及内侧开门点；原有内容不是从历史地图恢复覆盖。

## 验证与审评

- [92 项检查](checks.json)：地图原生验证无错误、无警告，20 个素材原图哈希与图标匹配，原有摆设和建筑几何保留；日常回路、仓库拾取、钥匙检修门、后勤开路、物流时间窗与看守步行交接均通过。
- [实际地图总览](r04-detail-overview.png)：Godot 原生编辑器画布渲染。
- [实际编辑器](r04-detailed-editor.png)
- [车间近景](workshop-editor.png)
- [仓库与装卸场近景](warehouse-loading-editor.png)
- [洗衣房与设备间近景](laundry-equipment-editor.png)
- [装卸场游戏画面](loading-runtime.png)：仓库屋顶按当前房间可见规则显示。
- [运行采样](performance.json)：本机 1600×1000、正常 NPC 更新，预热后采样最低 63 FPS，平均约 77.5 FPS。

这次未向制作人反馈、未提交 Git；保留在工作区供审评。
