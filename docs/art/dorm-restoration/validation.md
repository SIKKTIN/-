# 寝室装修验证

五间寝室接入五个独立透明素材，柜子保留原ID与私人用品配置。原生Godot画面已检查：横向双层床、柜子、独立马桶、洗漱台及矮凳均可见；矮凳不再被前墙挡住，柜面上的旧吊灯已移除。

原生渲染与无头回归均通过194项检查，涵盖原始PNG摘要、编辑器素材注册与放置撤销、家具碰撞及占地不重叠、角色出生点附近通路、完整身体通过侧门、到走廊与柜子的路径、柜子搜刮、物品拿取及放回、外出后屋顶恢复、其他地图结构与灯源保留。

- [实机画面](dorm-runtime-clear.png)
- [正常HUD画面](dorm-runtime.png)
- [外侧屋顶](dorm-exterior.png)
- [回归报告](regression/summary.json)

运行检查：`python tools/run_checks.py --godot <Godot控制台程序> --only dorm_restoration`

运行寝室试玩：`Godot --path <项目目录> --script res://docs/art/dorm-restoration/play-dorm.gd`。试玩使用独立设置文件，不修改地图或正常存档。

新增PNG保持内置图像生成工具的原始像素及透明通道。生成记录见 [generated-assets.json](generated-assets.json)，游戏资源见 `art/props/dorm_restoration/manifest.json`。
