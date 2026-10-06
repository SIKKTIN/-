# A24 按确认概念还原建筑形体

本轮纠正A23/P53仅以功能、遮挡和墙高检查替代形体对照的问题。用户确认目标保留于 `concept-target.png`；失败运行标注图为 `failed-runtime-user.png`。

制作入口：`res://art/architecture/v24/manifest.json`、`assembly.json`；编辑器增量入口：`res://art/editor/v04/manifest.json`。11条素材与11个图标，由4张新生成原PNG提供完整建筑两态、轴向矩形屋顶精修、食堂门墙和同源结构模块。

原图保存于：

- `art/architecture/v24/solitary_shell_closed_v24.png`
- `art/architecture/v24/solitary_shell_open_v24.png`
- `art/architecture/v24/solitary_axis_roof_v24.png`
- `art/architecture/v24/cafeteria_portal_v24.png`

使用内置 imagegen，提示词和局部修订提示词在 [prompts.json](prompts.json)；原图来源及字节复制一致性在 [source-review.json](source-review.json)。生产像素没有由代码裁切、缩放、补画；裁切全部为Atlas元数据。

禁闭室按完整手绘闭态作稳定底图，依次叠同源新原图的**完整矩形屋顶补片**、开态门部补片。屋顶轮廓精修时生成工具连带轻移了门部，因此只消费精修图的屋顶，保持已经配准的原前墙/石柱/门位不变。补片均含原图完整形体与光影，程序不重新画材质或屋檐。精确region、锚点与对应render rect在assembly。门脚对准逻辑房间局部中心(300,298)，门口90×28；最终按屋顶189/立面109分段采样同源PNG，可视门口约89×97；这修正了早期统一映射的屋顶164/立面130比例残差。

食堂完整左翼包含左外角柱与左门柱，完整右翼包含右门柱与右外角柱，不可再叠一套独立柱。门楣单独位于180×90入口上方。长右翼应使用右门柱、中段重复及末端转角柱；不能将220宽完整右翼拉成924宽，也不能保留其末端柱后再接中段。食堂原图中央开口比例与逻辑180不同，完整portal只供原图参照，按同源模块装配。中文食堂牌由制作人绘一次，源图没有烘焙文字。

alpha处理：生成实体内部可能为251至253而非255。建筑层及OPEN补片需要 `opaque_core.gdshader` 将实体核心恢复不透明，保持原RGB、调制与抗锯齿外缘；这样不会透出旧闭门叶或室内底图，食堂真正alpha开口仍透明。初版使用保留名source_color导致实际shader编译失败，已改为texel_color。`godot-qa.json`仅证明隔离资源加载；真实Forward+编译与绘制证据见 `shader-native.json`、对应stdout/stderr与截图，不把两种检查混为一谈。

实际运行对照与剩余差异见 `p54-concept-comparison.md`、`p54-visual-evidence.json`。P54的逻辑、碰撞、导航和完整运行验收由制作人另行完成。没有修改A23资产、旧交付哈希或共享脚本/数据。
