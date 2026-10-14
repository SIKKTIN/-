# 项目导航

这些是查找入口，不是冻结的项目状态；使用时检查文件是否存在和内容是否仍适用。

## 身份与玩法

本机 Godot 主工程：`E:/Project/Godot/这次怎么逃`，产品名《监狱风云》。README 和历史文档可能仍称“这次怎么逃 / 黑工厂园区 Demo”。旧网页原型位于 `E:/Project/Taptap`，已按用户要求清理；该目录的残留交付记录不代表活跃网页产品。

截至 2026-10-14 的已知设计是：固定控制林川，在约 6000×4500 的 R04 连续园区活动；教程后进入七天逃脱期限，正常流速一天约 15 分钟。用当前 README、地图、日程和教程配置复核。R01–R03 主要保留兼容性和编辑器验证用途。

## 最有用的文件

| 目的 | 相对 Godot 工程根目录的入口 |
| --- | --- |
| 项目与导出 | `project.godot`、`export_presets.cfg`、`README.md` |
| 实际启动链 | `scenes/main_menu.tscn`、`scripts/ui/main_menu.gd`、`scripts/core/game_loading.gd`、`scenes/main.tscn` |
| 游戏初始化/逐帧调度 | `scripts/core/escape_game.gd`、`game_bootstrap.gd`、`game_frame.gd` |
| 地图、碰撞和寻路 | `data/rooms/r04.json`、`scripts/world/prison_world.gd`、`world_navigation.gd` |
| 日程与生活 | `data/schedule.json`、`scripts/core/prison_schedule.gd`、`daily_routine.gd`、`npc_life.gd`、`social_world.gd`、`tutorial_day.gd` |
| 门禁、物品与棋牌 | `scripts/items/keycard_service.gd`、`data/access/keycards.json`、`scripts/items/`、`scripts/minigames/` |
| 遮挡与绘制 | `scripts/core/room_visibility.gd`、`scripts/presentation/game_presentation.gd`、`world_volume.gd`、`scene_layers.gd`、`lighting_system.gd` |
| UI、输入、帧率 | `scripts/ui/fullscreen_hud.gd`、`scripts/core/mobile_controls.gd`、`frame_settings.gd` |
| 资源依赖与烘焙 | `scripts/presentation/prop_catalog.gd`、`presentation_resources.gd`、`runtime_texture_store.gd`、`scripts/tools/bake_runtime_textures.gd` |
| 测试入口 | `qa/regression_suite.json`、`tools/run_checks.py`、`tools/check_resources.py` |
| 原生编辑器 | `scripts/editor/`、`scenes/editor/`、`addons/escape_map_editor/` |

`art/runtime_textures/` 是桌面运行纹理，`art/runtime_textures_android/` 是手机运行纹理。2026-10-14 实现分别使用 BC7 和 ETC2 场景纹理，角色/UI 等保留无损；以索引和构建脚本为准。不要按素材版本号删除历史资源，旧 ID 和别名可能仍被地图引用。

## 构建与验证线索

本机曾使用 `E:/Godot/4.7/Godot_v4.7.2-stable_win64.exe` 及 `_console.exe`；Android SDK 位于 `C:/Users/gst20/AppData/Local/Android/Sdk`，JDK 位于 `C:/Program Files/Java/jdk-17`。路径只作查找线索，其他电脑应重新确认。PATH 中默认 Java 可能不是构建所需版本。

运行通常是打开 `project.godot` 后 F5。下面是命令形态，介绍时先核对预设、目录和工具路径；初始化过程中不执行：

```powershell
& '<Godot 路径>' --path '<项目路径>'
python tools/run_checks.py --godot '<Godot 路径>' --only <当前回归清单中的 ID>
& '<Godot 路径>' --headless --path . --script res://scripts/tools/bake_runtime_textures.gd -- --android
& '<Godot 路径>' --headless --path . --export-release 'Android ARM64' 'build/android/<测试版本>.apk'
```

Release 导出还需要本机已配置的签名；上述示例不是完整签名配置。不得把签名密码或私钥复制进简报。

优先查阅：

- `docs/dev/android-first-device-plan-20261014.md`：首台手机目标、测试路线和阶段记录。
- `docs/performance/resource-optimization-20261014/summary.json`：桌面资源优化证据。
- `docs/performance/android-first-build-20261014/`：首包资源、签名与包体检查。
- `docs/performance/android-frame-investigation-20261014/summary.json`、`workshop-summary.json`：帧率热点、修复和测量边界。
- 同目录 `release-v*-package.json`、`release-v*-upgrade-check.json`、`release-v*-source-hashes.json` 等：与实际 APK 配对检查；未列出的更新版本也应搜索。
- `docs/tests/current-regressions/` 及相关专项报告。老 QA 可能引用已删除的 `routine_panel` 等接口，不能直接以旧文件名或旧 PASS 推断当前通过。

## 用户上下文快照：2026-10-14

以下为该日交流记录。若有更新的用户反馈或文档，以更新证据为准：

- 首台手机为 iQOO Z9 Turbo；实际 RAM、当前系统版本尚需设备信息确认。此前暂时没有 USB，用户通过手工安装测试。
- 初始 Debug 包在园区频繁波动，进房间曾降到 30 多 FPS。Release v0.2 加入 CPU 热点修复后用户反馈提升，但一号车间进入后持续约 40 FPS，不会在静止几秒后恢复。
- 文件中已有 v0.3 车间阴影优化构建和验证记录；截至这份快照，没有确认该版本的真机测试结果。之后可能继续改了代码，需检查报告、源码与 APK 是否对应，不能仅凭版本号宣称所有改动都已打包。
- 用户认为约 600 MB 的包体精简暂不急，当前更关注运行稳定性。包体大小、纹理内存与进程 PSS 是不同指标。
- 用户另提出“夜晚玩法比较单薄，希望获得建议”；这是设计讨论诉求，不代表夜间玩法扩展已经实施，也不覆盖用户在新对话指定的任务。

`E:/Docs/这次怎么逃` 是另一个 GameCreator 文档工程。如果任务要求编辑那里，应读取该目录的 `README.md`、`GAMECREATOR_GUIDE.md` 和 `ai/README.md`；仅介绍 Godot 项目时无需进入凭证和远程提交流程。
