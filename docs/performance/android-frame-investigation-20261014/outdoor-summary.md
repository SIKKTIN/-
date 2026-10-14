# 室外持续帧率波动检查（2026-10-14）

用户反馈：即使不进房间，帧率也不能稳定在 60。此前手机为 iQOO Z9 Turbo，使用系统游戏侧栏观察；尚无本轮设备端逐帧采样。不能把电脑测试结果当成手机 FPS 改善。

## 本轮修改

- `fullscreen_hud.gd`：屏幕安全区按视口尺寸缓存，稳定状态最多每 500 ms 查询一次；恢复前台、获得焦点时失效，视口尺寸变化时立即刷新。相同视口下安全边距改变也会触发布局。Android 挖孔/系统栏与前后台恢复仍须真机复核。
- `npc_dialogue.gd` / `interaction_prompt.gd`：附近交互候选先按距离筛选，再计算社交名称和房间可见性。无位置参数的调用仍返回原来的完整候选列表。
- `bath_service.gd`：附近站点先判断距离，再判断屋顶与视线，避免对远处站点进行无用查询。
- 未修改画质、NPC 模拟频率或 Android 帧调度策略。

## 验证

`outdoor-checks.json`：127 个位置（含距离边界）的候选列表与修改前一致；安全区缓存复用、恢复失效、视口尺寸变化检查通过。Windows headless 交替执行的候选搜索平均耗时从 0.15807 ms 降到 0.06769 ms；这是该函数的局部 CPU 数据，不是整帧或 Android 数据。

`outdoor-regressions/summary.json`：交互提示 32 项通过。浴室 150 项中 8 项失败；以本轮修改前的四个脚本复跑得到完全相同的失败列表，详见 `outdoor-bath-baseline/checks.json`。失败涉及拾取、储物柜、水卡拖动和淋浴高亮镜像，属于本轮之前已存在的测试失败，尚未定位其根因，不能宣称全套回归通过。

基线复跑最初因测试输出目录与输入夹具目录未分开而读取失败；已修正后重新执行，最终上述报告使用原始输入夹具。

## 剩余问题与下一步

轻微的 FPS 读数波动不等同于可感知卡顿；持续 40～50 FPS 或反复顿挫仍未达到项目的稳定 60 FPS 目标。60 FPS 的单帧预算约 16.7 ms，应结合逐帧耗时与实际观感判断，不能只看侧栏平均值。

需要在同一设备、同一路线、同一刷新率和性能模式下记录：室外静止/移动、车间一、昼夜与前后台恢复；比较 CPU/渲染耗时、帧间隔分布以及热状态。Android 自动帧调度可能调整目标帧率，但本机是否发生尚未证实，不能据此归因。

参考：[Godot Android 帧调度设置](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-display-window-frame-pacing-android-swappy-mode)、[Android Frame Pacing](https://developer.android.com/games/sdk/frame-pacing/)。

本轮仅修改源码并验证，未重新导出 APK；既有 release-v3.apk 不包含本轮室外优化。
