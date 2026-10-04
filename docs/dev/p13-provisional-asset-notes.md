# A04 暂定资源参数（非最终交付）

2026-10-04，主美已登记实际进行中，石材3原PNG完成，木箱/人物仍在生成。默认active=v02。

预定slots：floor_handpaint_v03；wall_top→stone_top_handpaint_v03；wall_front→stone_front_handpaint_v03；block_top→block_top_handpaint_v03（stone_top同原PNG上半Atlas区域单张适配）；crate→heavy_crate_handpaint_v03。门复用v02。region、底面矩形和文件哈希等待最终清单，不据此建立生产v03 profile。

暂定floor重复512（4排，每排128世界单位）、wall_top重复256；实际对照概念可比较floor384/512，保证人物突出。石材原PNG已查看，磨损/颗粒/不规则接缝符合方向；stone_front原图含上下半排，最终区域应清楚取单整排，避免多排被压进低立面。此建议已反馈主美，源PNG保留不程序重画。

暂定角色友军60/狱警72，最终以三姿势原图和清单为准；P13信息层已按world_height布置，脚底、左右镜像、编号不变。人物放大仅视觉，碰撞半径仍17、视野仍110。将检查窄通道、门边操作、前后遮挡、头部可选和三帧落脚点。待A04正式交付/独立验收后才切换引用、生成实际游戏风格图和完成P13。
