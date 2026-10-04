# 光源与昼夜接口 · v0.5

运行入口：Godot 4.7.2，`res://scenes/main.tscn`。`N` 或右上按钮手动切换昼夜，默认白天；切换房间和重开保留已选择的昼夜。时段不自动推进，方便比较画面与重复验证关卡。

`scripts/presentation/lighting_system.gd` 建立 CanvasModulate 环境光、DirectionalLight2D 日光和带 PCF5 阴影的 PointLight2D 房间灯。渐变灯光由 GradientTexture2D 创建，不加工原手绘 PNG。`data/presentation/lighting.json` 集中配置颜色、强度以及每个房间灯的位置/半径。

照明消费 `world.solid_rects()` 和 `obstacle_revision`，同步 LightOccluder2D：固定墙与关闭的门、当前箱子。开门删除对应遮光体，移箱更新矩形，换房重建灯位；无重复的自建碰撞数据。遮光矩形使用真实占地，不把视觉高度加入碰撞。既有软接触阴影仍作为落地表现保留，点光源负责局部灯光遮挡。

房间与人物接受照明；纸张背景独立为 unshaded CanvasItem，HUD 在独立 CanvasLayer，人物编号/选中/技能进度信息层也为 unshaded，夜间仍可识别与操作。白天灯具熄灭，夜晚点亮，灯具目前为程序生成的简洁占位造型。

`presentation.lighting.set_period("day" / "night")` 切换视觉时段，`snapshot()` 提供灯源/环境光/遮光体版本供验证。切换时不修改技能、移动命令、随机结果、计时或狱警状态；暗处目前不会降低被发现概率。

后续可以沿用该接口增加开关、断电/恢复、可移动光源和狱警手电。若将亮度接入狱警检测，需要另立玩法任务，先定义暗处识别距离、聊天与灯光的关系，并保留可读的警戒提示。

实现依据：[Godot 官方 2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)。
