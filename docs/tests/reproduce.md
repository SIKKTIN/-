# 双关配置复现

Godot 4.7.2，主场景 `res://scenes/main.tscn`，运行 F5。拖动单人移动，1/2/3 或人物卡选人，E 启停当前人物技能，R 重抽。切换人物不会取消已有操作。三人到达东侧出口完成。

`p07-configuration-matrix.json` 记录两个房间各27种有序配置的实际随机种子。种子对应 Godot 4.7.2 的 RNG；固定技能数组可跨种子明确复现。

调试器或 Godot MCP `game_eval` 的运行对象 `g=get_tree().current_scene` 支持：

```gdscript
g.load_room("r02", ["chat", "lockpick", "strong"], 33)
g.load_room("r01", ["lockpick", "lockpick", "lockpick"], 11)
g.load_room("r01", ["strong", "strong", "strong"], 22)
g.load_room("r02", ["strong", "strong", "strong"], 44)
g.load_room("r02", [], 选定种子)
return g.snapshot()
```

以下独立 headless 脚本运行完整实际规则，无自动保底、无关闭狱警：

- `tests/configuration_matrix.gd`：54次初始化和种子复现，不等同通关。
- `tests/skills_check.gd`：单/多人开锁、切换保留、移动中断、聊天朝向和发现打断、真实接触推箱。
- `tests/guard_check.gd`：固定视野、即时追击、墙门箱遮挡和抓回保留。
- `tests/route_check.gd`：R01两路线完整三人逃脱。
- `tests/r02_check.gd`：R02聊天掩护、全力量绕行和无掩护对照。

命令：`Godot_v4.7.2-stable_win64_console.exe --headless --path 项目目录 --script res://tests/脚本.gd`。非零退出码表示失败。

当前只把四个完整路线配置标为已实测可解；两关全聊天标为规则无解，其余48项保留尚未证明。自动运行证据用于技术正确性，真人决策和乐趣另由P09记录。
