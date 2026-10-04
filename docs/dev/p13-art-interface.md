# P13 手绘资源接入接口（准备阶段）

用户在美术聊天确认本轮改进；A04负责手绘资源，P13负责渲染与实际验收。
默认active.json保持v02。A04正式交付且制作人独立accepted前，不替换最终引用。

profile沿用delivery/characters/environment/props/floor_tile_size/perspective，新增可选floor_asset：从环境清单按id消费Texture2D，不必使用整张文件作为地板。v03支持material_slots映射wall_top、wall_front、block_top、crate、door_closed、door_open至任意版本id；block_top_tiled决定宽障碍顶面整张适配或使用石材重复；world_size决定重复尺度。wall_elevation/block_elevation可选，默认18/24。outline_width可降低或关闭程序硬描边。v02缺省行为保持原样。

环境/props定义：texture为生成原PNG，region可选[x,y,w,h]，由AtlasTexture直接取区域，filter_clip=true防采样串帧；不生成重画后的PNG。world_size是消费区域的世界重复尺度。门箱ground_rect[x,y,w,h]相对所取region的局部坐标，映射到逻辑footprint；PNG/region透明padding与立面不挤占地面面积。elevation_world为视觉高度，非碰撞参数。

角色沿用manifest每帧frames、局部anchor、world_height和initial_walk_frame_seconds；每帧注册在同一世界脚底原点，真实位移驱动idle/walk_a/walk_b，左右镜像不翻转信息层。角色/环境声明shadow_baked，v03 soft_shadows=true时跳过已烘焙落地阴影；推荐均无烘焙落地影。短投影统一右下，半透明多层外缘与脚底椭圆接触，不改障碍或警戒。源原图有背景/帧串入/脚底剪边应由主美重生成或交清楚region，不能用程序重画修图。

准备验证：tests/p13_preparation_check.gd使用v02实际纹理，只运行阴影原型与直接区域消费，保存p13-preparation-v02-baseline.png、p13-preparation-soft-shadow.png和JSON。该证据不代表art-v03风格交付。

最终验收以确认概念docs/art/r02-perspective-study-v01.png对照实际游戏：地板保留淡石板材质但不过度抢眼；石材顶面/立面/箱木纹有统一手绘边缘和明暗；四人物身份与敦实轮廓、头手鞋清楚，三姿势不抖脚不突然变瘦；投影方向与接触一致、不叠影；门箱逻辑注册、技能徽章/进度条/编号、长说明固定操作提示及真实裁切视野可读。两房、两窗口1280/960均截图，由主美复核实际图，制作人运行相关规则/路线回归。v01/v02资源和既有P11/P12证据保留。
