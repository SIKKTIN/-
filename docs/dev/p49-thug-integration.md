# P49 · 混混看守主干接入

2026-10-06。主美任务 `a17-thug-lookout-20261006` 制作素材，制作人任务 `p49-thug-mainline-integration-20261006` 接入与验收。A17实际先制作，GC曾因当前编辑器未保存而拒绝待验收记录；用户回复“已保存”后主美以相同请求成功提交，制作人再验收资源。P49的代码准备及初步QA发生在用户明确授权制作、GC暂时拒绝记录期间；随后已按真实情况补登记程序接入与整体验收，不倒写时间。

`data/presentation/active.json` 增加 `guard_appearance`，指向A17完整定义。`game_presentation.gd` 在旧行走定义应用后，仅替换guard逻辑角色完整美术定义；因此不会把v09旧警服行走重新覆盖新形象。内部角色身份和技能逻辑保留。

巡逻看守使用便服短发、深灰背心、棕裤、工作靴与木棍形象，取消警服/警帽/徽章。现有门岗与缺员增援通过 `gate_watch.attach_visual` 继承主巡逻的完整definition，自动统一站立与八帧12fps行走，原有警戒灯光、视线、寻路、聊天和抓回规则继续使用。

主角、商人、看门犬及环境资源未改。原A17 PNG不做图像处理或二次缩放；共享帧缩放60/385，每帧使用独立裁框与脚锚点，不按各帧高度拉伸。

## 证据

- A17 `docs/art/a17-resource-qa.json`：原PNG RGBA1254×1254，透明像素62.23%，9独立姿势，源与交付哈希一致；完整帧裁框、透明和脚底注册检查。资源原生联系表由主美查看，制作人查看原PNG与主游戏画面，资源单独验收。
- `qa/p49_thug_integration.gd`：1200 headless、1200原生、960原生各27项，共81项通过。实际生产配置/四地图巡逻、R04两个门岗、实际午夜缺员触发两名增援/全部五个看守统一、主角旧资源、八个行走帧/12fps/体型稳定/左右翻转/暂停/停止、白天不抓人、重开删除增援且保留新形象。
- P48最终365项回归使用新资源，整体共446项通过。测试使用独立布局/开发设置路径；原生测试不等于手机硬件或真人画面手感测试。
- 制作人实际查看 `p49-thug-1200-hud.png`、`p49-thug-960-gate.png`、`p49-thug-1200-reinforcements.png`，人物栏位置正确，门岗及搜查单位都显示新便服形象。

CLI：

```powershell
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path . --script qa/p49_thug_integration.gd -- 1200
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path . --script qa/p49_thug_integration.gd -- 960
```

新PNG初次导入前运行headless得到资源加载错误，已完成Godot导入并重跑最终证据，不能把首次的逻辑passed视为素材加载通过。最终报告检查非空实际Texture2D与八个纹理帧；启动和回归日志无加载错误。用户 `project.godot` 差异保留，其SHA256仍为 `C92BE6253B1D9417C3DD019A12ABF986C1D992808EB9313E5D0B14AC87682B7E`。
