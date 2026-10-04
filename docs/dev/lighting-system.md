# 光源与昼夜接口 · v0.6

运行入口：Godot 4.7.2，`res://scenes/main.tscn`。`N` 或右上按钮手动切换昼夜，默认白天；切换房间和重开保留已选择的昼夜。时段不自动推进，方便比较画面与重复验证关卡。

`scripts/presentation/lighting_system.gd` 建立 CanvasModulate 环境光、DirectionalLight2D 日光和带 PCF5 阴影的 PointLight2D 房间灯。渐变灯光由 GradientTexture2D 创建，不加工原手绘 PNG。`data/presentation/lighting.json` 集中配置颜色、强度以及每个房间灯的位置/半径。

照明消费 `world.solid_rects()` 和 `obstacle_revision`，同步 LightOccluder2D：固定墙与关闭的门、当前箱子。开门删除对应遮光体，移箱更新矩形，换房重建灯位；无重复的自建碰撞数据。遮光矩形使用真实占地，不把视觉高度加入碰撞。既有软接触阴影仍作为落地表现保留，点光源负责局部灯光遮挡。

新增 `GuardFlashlight` PointLight2D，程序生成向 +X 的 120° 扇形渐变纹理，跟随 guard.position/facing 与 guard.view_radius() 缩放。昼 210 / 夜 155，真实检测和轮廓共用同一半径；旧 110 固定基线在 v0.6 被替代。夜间强度 .65 / 白天 .26，避免洗白纹理。guard visual.light_mask=2，环境/日光 mask=3，手电 mask=1，狱警自身不会被手电洗白。

房间 `guard_zone` 定义监管区：R01 `[508,114,488,560]`，R02 `[670,114,326,560]`，左侧剩余区域为安全房间。`guard.movement_allowed` 约束整个人物半径，世界碰撞与 AStar 临时格子查询共同使用，友军不受影响。sees、接触抓回和追击释放均检查 zone，目标回房即解除追击。光源遮挡额外使用 mask=2 的四条监管边缘，只影响狱警手电，不阻挡房间灯；真实轮廓也裁到区域边界。

房间与人物接受照明；纸张背景独立为 unshaded CanvasItem，HUD 在独立 CanvasLayer，人物编号/选中/技能进度信息层也为 unshaded，夜间仍可识别与操作。白天灯具熄灭，夜晚点亮，灯具目前为程序生成的简洁占位造型。

`presentation.lighting.set_period("day" / "night")` 切换时段，`snapshot()` 提供灯源/环境光/遮光体版本供验证。切换不重置技能、移动命令、随机结果或计时；新的发现半径从下一个 guard.tick 即生效。夜晚缩短总视野，不按每个像素的明暗计算识别概率。

`interaction_prompt.gd` 对选中伙伴查询真实技能可用条件，靠近目标才出现 HUD CanvasLayer 中的世界位置图标；点图标或 E 调用原技能/移动命令。聊天/撬锁保留独立持续操作，图标可停止自己的操作；近箱按钮给力量伙伴下达短距离推箱命令，仍通过碰撞与原推箱预算。原远端全局技能按钮隐藏；远离、逃脱、追击阻止聊天、门已开或暂停时隐藏相应图标。

后续可以沿用该接口增加开关、断电/恢复和可移动光源。若将灯光强弱接入狱警检测，需要另立玩法任务，定义具体识别规则，并保留可读提示。

实现依据：[Godot 官方 2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)。
