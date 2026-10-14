# 宿舍宽口收纳移门 V2

五处宿舍入口共用墙内收纳式钢门，保留开关交互与夜间锁定。原内开两片门扇移除，门洞从 166.4 扩到 200 世界单位；两端各占 14，净开口 172。采用 100 高的人物全身碰撞时，可通行的脚部位置覆盖 72 世界单位，原门只有约 6.4。

蓝灰钢框、紧凑端部收纳盒、黄铜内嵌拉手。侧墙门沿墙体方向绘制，两侧共用同一套门框；开门中部导轨位于人物下层，门框和关闭门板位于屋顶下层。

## 素材

- 内置 imagegen 生成：[原始 RGBA 素材](../../../art/architecture/dorm_door_v1/pocket-components-v2.png)。保留原始像素与 alpha，仅通过原生区域采样、旋转和拼接使用。
- [最终提示词](prompt.txt)
- [源文件、SHA256 与区域记录](registration.json)
- [注册脚本](../../../tools/register_dorm_pocket_v2.py)
- 公共门资源 ID 保留；地图编辑器与游戏通过同一门洞几何和素材元数据加载，不改写 R04 草稿。

## 验证

原生实机 `qa/dorm_pocket_v2.gd`：225 项通过，包含五个入口、开口全域扫描、多位置双向键盘通行、斜向控制、摇杆、从房间地面连续走出、点击绕开家具、门框与门洞外封闭墙、关闭阻挡、守卫靠近下沿时从上半段通过以及屋顶层级。

`qa/dorm_door_interaction.gd`：90 项通过，包含实际 E 和移动端按钮、两侧操作、门口占用检查、夜间锁定和守卫钥匙。`qa/workshop_door_v2.gd`：48 项通过。

实机截图：[开门内侧](../../tests/dorm-pocket-v2/open-inside.png)、[开门外侧](../../tests/dorm-pocket-v2/open-outside.png)、[关闭](../../tests/dorm-pocket-v2/closed-inside.png)。

试走入口：`--script res://docs/tests/dorm-pocket-v2/play.gd`。角色置于房间内的有效地面，门已打开，保留真实移动、碰撞与游戏规则。
