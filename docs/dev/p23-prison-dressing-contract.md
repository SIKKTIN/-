# P23 / A06 监狱摆设接入契约

2026-10-05用户要求监狱主题地图摆设。沿art-v03 / FINAL-WARM-01，新增七种可复用摆设，并制作R04监区生活层，包含牢房、劳动改造车间和活动大厅；保留R01/R02/R03与手机小地图。

## 资产接口

主美仅新增art/props/prison_v08/及docs/art/a06-*，不修改共享代码、房间、旧素材与既有manifest，不提交Git。制作人负责实际主干接入。七种asset id：bunk_bed、cell_bars、toilet_sink、workbench、tool_locker、communal_table、notice_board。首批无新动画。

分别使用内置imagegen生成透明RGBA原PNG，视角为固定水平/垂直轴线的轻度斜俯视，与现有石材、人物一致；不要45度等距转角、人物、地面、文字、烘焙投影。每种一张完整独立物件。原PNG字节不改；用AtlasTexture region与ground_rect注册透明边缘及抬高立面，不程序处理像素。

输出art/props/prison_v08/manifest.json，schema=1、assets数组。每项id、texture=res://...png、texture_size=[w,h]、region=[x,y,w,h]、ground_rect=[x,y,w,h]（相对AtlasTexture区域，地面投影占地）、footprint_world_size、elevation_world、shadow_baked=false、source_kind及sha256。地面占地必须清楚、底部接地，素材不能直接按PNG透明画布拉伸。

参考逻辑尺寸：bunk_bed[110,150]，cell_bars[180,12]（横向铁栏），toilet_sink[50,55]，workbench[180,70]，tool_locker[90,40]，communal_table[180,95]（固定桌与长凳整套），notice_board[120,16]。主美可按实际图给出等比建议；不能改逻辑碰撞。给两尺寸资源预览、来源/提示词、文件SHA256及透明/注册QA，分批可交第一轮合格资源。

## 规则接口

房间配置zones（名称、rect、色调）与fixtures（id、asset_id、rect、blocks_movement、blocks_sight）。床、工作台和公共桌挡路不挡视线；铁栏挡路但允许看穿；高工具柜挡路并挡视线；公告板为装饰。门、重箱仍沿原规则。

寻路使用移动阻挡，狱警视线和真实灯光使用视线阻挡，两者分开。摆设不能把出生点、货物、商人或巡逻点埋在碰撞体中。程序绘制一次柔和投影；角色和摆设按地面南侧深度排序。小地图显示分区和摆设，视野操作继续触屏优先。

R04为新布置与规则验证图；不是新增技能/机关或承诺随机配置均可通关。验收需实际截图、通路、巡逻持续运行、移动/视线差异、开路与小地图。Android/iOS真机及真人体验仍独立待验证。
