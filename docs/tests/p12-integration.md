# v0.3 轻斜俯视集成交付

2026-10-04，制作人 P12；A03资源已独立验收。
资源：art-v02-perspective-20261004-54a7161c7820；原资源 art-v01-20261004-a8676014f0d4 保留。

默认profile=v02。角色55/62、原帧/锚点/左右镜像；墙/障碍低立面18/24、门箱20；淡地板128重复。只消费视觉高度，不改变地图、碰撞、寻路、警戒、技能或RTS规则。身体参与前后遮挡，编号/选中/技能/方向在独立上层，视野在地面，短阴影仅程序画一次。

已验证实际Godot 4.7.2 D3D12窗口1280×720、960×540，每窗口2关×5状态：start、chat-ready、occlusion-closed、lock-progress、open-pushed，共20图；对应p12-perspective-尺寸.json 24项检查通过。查看图片可见足部被障碍适度遮挡而人物头部与编号可读；门打开透明，推箱后立面/短影随真实rect移动，技能徽章/进度条间距清楚，长聊天解释与固定操作提示完整。

主美初次复核发现进度条压人物、长说明挤操作提示；已将条移到徽章上方并固定ControlHint，重新生成全部图。保留主美初次记录，终版复核另行保存。

回归：p12-rts.json 20项；p12-guard/skills/environment.json；p12-r01-routes.json及p12-r02-routes.json；p12-patrol-after.json 2关×30/60/110fps×120秒；p12-patrol-dynamic.json 挡巡逻点仍可继续；均通过。
原生两窗口p12-尺寸.json各21项表现检查通过，包含可见头部点选、缩放输入、实际位移动画、锚点、独立技能/音频、暂停/捕获/逃脱与UI边界。
原生持续运行实际RTS指令通关：p12-live-r01-lock.json，17.33秒0抓回；p12-live-r02.json，15.80秒0抓回。自动路线测试不作为真人完整试玩或趣味性结论。

回滚启动ESCAPE_ART_PROFILE=v01，p12-rollback-960x540.json实际profile/asset_version为v01、21项通过；未改变默认v02配置。
独立哈希和数值锚点核查：p12-resource-review.json。地图/skills/move_orders等保留P11哈希，完整源码清单p12-build.json。

首次原生渲染检查发现新PNG尚未import，不能以仅逻辑断言passed视为视觉通过。完成Godot编辑器资源导入，增加all_scene_textures_loaded断言并重跑两窗口；最终图与报告全部来自已导入纹理的运行。初次短脚本退出有2对象泄漏提示，增加帧后清理等待，最终两窗口无该提示。

启动：Godot打开项目F5，或docs/tests/start-playtest.cmd。左键选人/卡片，右键地面持续移动，1/2/3切换，E技能，S只停当前人，R重抽。右键出口箭头撤离。人物脚底是逻辑坐标；贴图的立面高度与阴影不阻挡运动。
