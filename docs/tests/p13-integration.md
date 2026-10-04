# v0.4 手绘资源集成交付

2026-10-04，制作人P13；A04资源最终版本art-v03-handpaint-20261004-05ac759ba4ad已独立accepted。

默认profile=v03。8张imagegen原PNG未改像素，Atlas/角色按原图region直接取帧；友军60/狱警72。原12帧注册、站立/两帧迈步、真实位移和水平镜像保留；独立Godot原图alpha>32边界测量，脚底误差<0.05世界单位，可见高度差<0.011。

实际对照概念后选择地板重复384（512对比图保留）；墙顶256重复、宽障碍原图上半单张适配；南front只取石材中整排，0.74背光。窄纵墙顶面最右4世界单位0.68暗侧面及1.1过渡，全部在原rect内。门复用v02，箱按局部ground_rect[6,124,793,684]映射94×92，立面约15.87；不沿用旧20padding。柔和接触影与统一右下短投影仅画一次，清单shadow_baked=false。
最终配色冻结序号FINAL-WARM-01：wall_top/block_top统一[1.18,1.14,1.08,1]受光调制，使暖浅墙顶与灰绿地板分离。1.12中性候选仅保留比较图，不是当前配置；原PNG未改。

R01/R02、1280×720/960×540、start/chat-ready/occlusion-closed/lock-progress/open-pushed共20张实际Godot图，p13-perspective-尺寸.json各24项通过。报告snapshot.render_settings记录真实floor384/side4/.68/front.74与soft_shadows；实际图检查材质、人物轮廓、低立面、注册、遮挡/选中/技能进度及长说明可读性。
两窗口p13-尺寸.json各21表现检查通过，包含可见头部点选、真实位移动画、注册/镜像、独立技能音频、暂停/抓回/逃脱/UI边界。
RTS20项、两关稳定巡逻6组120秒（30/60/110fps）、移动箱挡巡逻点、R01开门/推箱与R02聊天掩护/推箱/无掩护抓回对照均通过。
持续运行的真实RTS通关指令报告p13-live-r01-lock.json、p13-live-r02.json；FINAL-WARM-01再次运行，R01约17.330秒、R02约15.796秒，两关零抓回、phase=complete、实际v03。

主美对照概念复核通过，结论见docs/art/p13-visual-review-final-v03.txt/.json；20图哈希逐一匹配。手绘材质、紧凑人物、暖浅墙顶/暗面及柔和接触影改善明确；保留模块化重复与较克制投影这一画面边界，未宣称逐像素复刻或真人完整试玩。
最终暖浅20图重拍时短脚本退出偶发2个ObjectDB清理提示；测试清理等待由0.06增加到0.2秒，最终两窗口未再出现该提示，场景与表现检查均通过。

14个非presentation配置/场景/逻辑文件与P12哈希完全一致，证明地图/碰撞/AI/技能/输入未改；p13-logic-baseline.json。所有源文件版本清单p13-build.json。v01/v02资源及旧证据保留，单次ESCAPE_ART_PROFILE=v01/v02回退，p13-rollback-v01/v02.json各21项原生检查通过。

初次独立alpha测量用了>=32，包括两个阈值边缘像素；回读资源脚本使用>32，调整为round(a*255)>32后完全吻合。原失败p13-frames-alpha-inclusive.json保留，最终p13-frames.json说明修正原因；未放宽脚底阈值或修改资源。

Godot编辑器F5或docs/tests/start-playtest.cmd可运行。操作保持左键选人/卡片、右键移动、1/2/3切换、E技能、S停止当前人、R重抽。旧版可回滚；自动路线和画面检查不等于真人完整试玩或趣味性结论，P09仍待真人尝试。
