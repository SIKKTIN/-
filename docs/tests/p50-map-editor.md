# P50 · 关卡编辑器验收

2026-10-06，Godot4.7.2，Windows原生D3D12及headless，制作人自审。最终报告共365项检查通过，以下为不同入口与配置的累计检查数，不代表365个独立玩法用例。

| 检查 | 配置 | 数量 |
| --- | --- | --- |
| 实际编辑界面鼠标操作、数据保存与草稿试玩 | headless1280、原生1280×800、原生960×640 | 43+48+48 |
| 真实main场景通过CLI加载编辑草稿、日常表暂停、移动与F10退出 | headless1200、原生1200×720、原生960×540 | 12×3 |
| Godot编辑器实际加载启用的主屏插件、Ctrl+Z/Y、关闭/保存回调与原生试玩返回 | 原生编辑器 | 19 |
| 原游戏触控/键盘移动、碰撞、技能、物品和模态面板 | headless1200、原生1200×720 | 59+62 |
| 原游戏寝室归属、缺员警戒、两名增援寻路/捕获/重开 | headless | 50 |

编辑测试使用真实 `Input.parse_input_event` 鼠标路由选中、拖动、墙体绘制和碰撞勾选，并校验一整次拖动只有一次撤销记录。实际检查摆设绘制深度随移动更新、餐盘非阻挡模板、巡逻顺序、商人营业及过渡点同步、三位伙伴出生点保护。

保存测试仅使用临时 `data/rooms/p50_qa.json` 或 `p50_plugin_qa.json`，覆盖新文件重读、未知字段保留、备份、外部修改拒绝、非法坐标拒绝、另存ID及原地图历史隔离；结束后清理这些指定文件。每次校验R04原文件SHA256未改变。原R01–R04地图文件未改写。

独立编辑器和真正的Godot主屏页都启动了真实main游戏进程，使用未保存快照。此部分QA只关闭自己创建的子进程，确认返回后草稿/历史仍保留，临时文件删除。运行时QA另行注入F10并以退出码0确认实际返回输入有效。首次晨间日常表仍暂停、覆盖返回按钮；关闭日常表后按钮显示，真实D键能移动编辑后的角色。

制作人查看原生编辑布局1280/960、寝室属性页、Godot主屏插件和试玩960画面；未见裁切工具栏或浮层覆盖日常表。编辑器显示布局和规则点，不承诺与正式游戏灯光、地面透视完全相同。

开发中捕获并修复：试玩返回按钮首帧覆盖模态、Godot退出时对已离树控件调用焦点接口、另存后旧地图ID可被撤销恢复、摆设默认碰撞及桌面绘制深度。QA曾遇到模拟外部保存未关闭文件导致读取半份JSON，改为显式关闭；15%缩放输入的半格舍入边界改为实际拖到网格中心，仍严格检查最终坐标。最终报告与CLI退出码全部通过，最终无相关脚本解析/运行错误。

Godot导入保留已有嵌套美术QA工程提示；多开编辑器会显示既有语言服务端口占用和MCP连接退出信息，不属于地图工具错误。所有相关验证通过CLI，未调用MCP写场景。没有手机硬件或真人通关体验测试。

## 复现

```powershell
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:/Project/Godot/这次怎么逃' --script qa/p50_map_editor.gd -- 1280
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/Project/Godot/这次怎么逃' --script qa/p50_map_editor.gd -- 1280
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/Project/Godot/这次怎么逃' --script qa/p50_map_editor.gd -- 960
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/Project/Godot/这次怎么逃' --script qa/p50_preview_runtime.gd -- 1200 --editor-room user://p50-preview-runtime.json
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/Project/Godot/这次怎么逃' --script qa/p50_preview_runtime.gd -- 960 --editor-room user://p50-preview-runtime.json
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/Project/Godot/这次怎么逃' --editor -- --map-editor-qa
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:/Project/Godot/这次怎么逃' --script qa/p50_rollcall_regression.gd
```

同名编辑器QA会写同一临时文件，请顺序执行。项目设置仅提交新增插件enabled行；用户原有移除输入设备配置的差异保留。
