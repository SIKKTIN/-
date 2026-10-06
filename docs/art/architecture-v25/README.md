# A25 食堂俯视纵墙与透明边缘返修

入口 `res://art/architecture/v25/manifest.json`；编辑器增量 `res://art/editor/v05/manifest.json`。

新增原图 `art/architecture/v25/cafeteria_return_top_v25.png`，1024×1536 RGB、不含透明背景，按24×128世界尺寸映射。约20单位平整浅石墙顶、4单位右暗侧边；仅两道细横缝，无首尾柱框、无正面石块立面。沿Y铺设真正墙顶，不能拿立面柱或端面重复代替。

`cafeteria_return_end_v25` 从已验收A24原图裁切纯墙面 `[200,259,74,288]`，映射24×90。只在最南末端画一次端面，不能沿纵墙重复。实际墙的top_rect和末端位置、小地图由制作人派生；素材没有另造一根可阻挡的柱。

原图由内置 imagegen生成，提示词见 [prompt.json](prompt.json)，来源/原样复制及A24交付不变验证见 [source-review.json](source-review.json)。区域仅为Atlas元数据；没有代码修改生产PNG。

用户再次否定旧运行图的L形连接：北翼外正面柱把纵顶挡到柱脚下才出现。因此加入第三项 `cafeteria_corner_l_v25`，916×1717透明原图。该模块不含外正面立柱，浅顶与窄暗侧连续转弯，横墙立面只在纵臂内侧。生产原图原样复制，提示词与单项比例编辑见 `corner-prompts.json`，来源/hash见 `corner-source-review.json`。

精确接口见 `corner-interface.json` schema2；12个Atlas源区绘制配准为80×150世界尺寸：纵臂24=浅顶20+暗侧4。源Y分段 `[287,467,859,1031,1420]` 对应目标Y `[0,20.412,77.436,110.484,150]`，分别匹配旧横墙实际压顶、基脚和实体底部。旧北翼左80单位绘制让位给模块，余段仍采原图；右外角可镜像。原source region末端含透明留白，不能用region末端代替可见墙脚。北翼baseline1261.5时模块顶1147.776，下沿1297.776后续接原纵顶。厨房20单位隔墙依物理宽派生，不能另外加柱。

`assembly_patches.source` 是完整916×1717原图的绝对像素坐标。运行纹理若已被裁为 `asset.region`，必须先减region起点 `[42,287]` 后采样，不能重复使用原图绝对坐标。首轮实际接入出现缺压顶和墙脚偏高，就是这种二次偏移；隔离原图采样正确不能替代游戏对照。

`corner-native.png`、JSON和stdout/stderr为隔离真实Forward+渲染，展示新增模块与原北翼的接点和纵顶续接，12源区绘制成功、stderr空。它用于配准检查，最终实际游戏画面仍需制作人提供并经美术核对。隔离资源/图标加载已更新为3项，全部通过。

横墙透明噪点：旧 `smoothstep(.02,.25,a)` 将alpha64提升到255，容易放大源图顶部黑色杂点。新版 `safe_edges_v25.gdshader` 只提高alpha大于0.90的实体核心；低于0.90不提升，低于0.12平滑衰减。保留RGB和调制，门洞真实透明仍透明。原始诊断见 `alpha-source-diagnosis.json`，传递值见 `alpha-transfer-check.json`：alpha8旧输出1.809、新0.006；alpha17旧27.233、新6.166；alpha64旧255、新64；alpha251至253实体核心升255。源图若有真正高alpha孤立点，不能凭本shader宣称已经清除，需实际近景对照。

验证区分：`godot-qa.json` 为隔离资源加载；`shader-native.json`、stdout/stderr和截图为真实Forward+编译及绘制，不用前者替代后者。实际游戏最终近景与目标对照见 `p55-visual-review.md`、`p55-visual-evidence.json`。

本轮不修改A24北翼、门柱、禁闭建筑、旧shader或已交付hash。FPS、真实墙派生渲染及共享代码由制作人负责。
