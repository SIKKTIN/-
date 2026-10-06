# A23 建筑素材制作交付

以用户确认的 `scene-concept-v21r2.png` 为制作基准。

入口：`res://art/architecture/v23/manifest.json`；编辑器增量入口：`res://art/editor/v03/manifest.json`。

提供不透明深灰屋顶、深灰墙立面、深灰压顶、浅灰食堂墙立面，以及两套嵌墙门的关闭/打开状态。浅石压顶明确复用原 `art/environment/low_wall_top_v02.png`。共9条素材定义，3张新增原始PNG，9个AtlasTexture图标；旧资源与旧清单不覆盖。

生成方式为内置 imagegen。最终提示词与禁闭门宽高修订提示词见 [prompts.json](prompts.json)；来源、字节一致性、真实透明区域及共同锚点见 [source-review.json](source-review.json)。Atlas只用区域定义，未用代码修改生产图像。

门素材不能按开态叶片重新裁切。两态完整区域尺寸和底部中心锚点相同：禁闭门984×640，食堂门965×561。实际金属轮廓仅0至1像素差；不做像素修正。门仅有薄金属边条，需由墙体装配遮住外缘，不能独立摆作巨型门架。禁闭门 `render_size=[160,110]`、逻辑门槛160×20；食堂门180×110、逻辑门槛180×31.5。轻微横纵适配比例记于 `scale_xy`，门高始终由 `render_size` 控制，不随通道宽度直接等比增大。

墙材质横向重复；立面整张按110或100墙高映射一次，避免把底部基座重复到墙中间。顶面材质横纵重复。材质没有几何投影、独立转角或烘焙投影；屋顶形状、墙厚、转角、门洞和阴影由制作人渲染器统一生成。

禁闭室完整实体屋顶必须覆盖原440×300房间内部，原室内家具仍可保留逻辑但视觉隐藏。食堂两侧墙使用相同墙高100、同材质与底部标高，禁闭室墙高110、厚28至32。开启门洞透明并不自动决定可通行，仍需制作人将门状态与碰撞/导航同步。

导入建议：PNG保留alpha、无损压缩、生成mipmap，线性过滤。Atlas区域 `filter_clip=true`，不能采样到邻格。图标用同一原图区域与6%留白，furniture归类材质、props归类门、tools为空；v03为增量目录。

检查证据见 [source-review.json](source-review.json)、[godot-qa.json](godot-qa.json)、[scale-preview.png](scale-preview.png)。实际游戏装配与运行验收由制作人P53单独完成。
