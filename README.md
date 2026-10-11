# 这次怎么逃 · 黑工厂园区 Demo

当前 Demo 在一张约 6000 × 4500 的连续地图中游玩。第一天是由陈教官、监工和商人演出的入监教程；教程结束后进入七天正式逃脱期限。玩家固定控制林川，其他囚徒和工作人员各自行动。

## 运行与操作

使用 Godot 4.7.2 打开根目录 `project.godot`，等待素材导入后按 F5。主场景 `scenes/main.tscn` 默认加载 R04 园区，无需 GameCreator 凭证即可运行。

- 左下摇杆、WASD 或方向键移动；右下按钮执行附近互动、使用能力、打开背包。
- E 执行附近互动，F 定位主角，R 重开。ESC 关闭当前弹窗或打开暂停菜单。
- 拖动主图查看远处；右上「地图」展开小地图，定位按钮恢复镜头跟随。
- 背包支持选择、使用、丢弃物品；商人交易共用同一份物品选择状态。
- 玩家自己决定工作、吃饭、休息和归寝。站在工位不会自动开始工作；NPC 按需求、情绪和性格独立选择生活行为。

## 当前玩法

1× 流速下一天约 15 分钟，08:00 起床，09:00–12:00 与 14:00–17:00 劳动，其余时段可以体验用餐、社交、探索和夜间行动。暂停菜单冻结模拟；开发设置可以调整时钟流速和逃脱期限。

已接入工作计时与工资、真实取餐和就座、体力与饱腹、具名 NPC、心情和关系、帮助与送礼、看守监管和追捕、禁闭、物品与交易、门锁、搬箱、警犬、教程演出及世界路线和按钮引导。劳动中被发现偷懒后有 3 秒警告，恢复工作会逐渐降低警戒，反复停工不能瞬间清零。

正门、物流出口、后勤出口均在同一张地图上。地图的门、墙和花坛具有实际通行规则；身体通过门洞与脚部地面碰撞分别判定。R01–R03 保留供编辑器及兼容性回归，当前 Demo 菜单不提供分关卡切换。

## 代码职责

- `scripts/core/escape_game.gd`：游戏状态、每帧调度、手动输入、重开和结算。
- `scripts/core/game_bootstrap.gd`：加载地图及按依赖顺序创建系统；`scripts/ui/hud_shell.gd` 创建 HUD 公共节点。
- `scripts/world/prison_world.gd`：世界碰撞、门、箱子与出口；`world_navigation.gd`：缓存网格、路径规划和 AI 寻路预算。
- `scripts/core/prison_schedule.gd`：世界时钟与作息；`daily_routine.gd`：实际工作/用餐状态和收益；`npc_life.gd`：NPC 独立生活；`social_world.gd`：情绪、关系、记忆和行为评分。
- `scripts/ui/fullscreen_hud.gd`：当前单角色 HUD；`inventory_panel.gd`：背包选择和操作；`inventory_drawer.gd`：背包布局及显示。
- `scripts/presentation/prop_catalog.gd`：游戏和编辑器共用的有序素材目录。历史资源 ID 的别名仍被地图使用，不能按版本号直接删除。
- `scripts/editor/`、`scenes/editor/`：原生地图编辑器与试玩返回入口。
- `data/`、`art/`、`audio/`：配置与运行资源；`docs/`：概念图、开发记录和验证证据。

废弃的日常安排面板、日程表绘制脚本和旧纸页背景已移除。角色选择旧 UI、隐藏技能按钮及旧背包交接按钮也不再创建。

## 验证

当前回归入口由 `qa/regression_suite.json` 明确列出，覆盖脚本编译和素材目录一致性、地图通行、背包、手动角色、社交、NPC 跨日生活、教程、追捕以及旧地图兼容性。

```powershell
python tools/check_resources.py
python tools/run_checks.py --godot "你的 Godot 可执行文件路径"
python tools/run_checks.py --godot "你的 Godot 可执行文件路径" --only map inventory chase
```

报告默认写入 `docs/tests/current-regressions/`。检查器验证退出码、引擎错误和本次生成的报告，旧的通过报告不会被当成本次成功。更早的阶段 QA 脚本保留为开发证据，使用当前回归清单验证现有版本。

`.godot`、本地凭证与同步备份不提交。普通运行不依赖 MCP 连接；工程附带的 Godot AI 和地图编辑插件用于开发。美术来源、字体及插件许可证见相应资源目录和 `docs/art/`。
