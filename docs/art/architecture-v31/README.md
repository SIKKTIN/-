# A31 同源同透视石墙 T 接口

用户指出 V30 上部正面柱石与 V27 下部窄顶面/侧影不一致，这是透视和构造错误。上一轮将其称为细微石材变化并接受是误判，已正式记录 A30 correction。A31 改用冻结 V24 原 PNG 的 UV 元数据，不生成或修改生产 PNG，不使用调色遮盖差异。

入口 `art/architecture/v31/manifest.json`，本体 `cafeteria_t_20_v31` / `cafeteria_t_v31`，132/136×80，stemx56，横深24，下口80。两张 v11 独立 MeshTexture 图标由完整同源 T 几何和 UV 构成。

Stem 严格采用 V27 的转置 UV：原窗口 [232,192,245,74.07407407407408]，世界石缝周期61.57068062827225。56长 stub 的 sourceX 长222.83333333333334，终点454.83333333333337，原长度比例不变；24/20仅压缩横截面。左深边在右侧，右整 T 镜像一次接 V27_r，纵向采样方向不反转。进行中提交摘要曾将 source 宽误写223.1667，实际 manifest、检查及本说明均为222.83333333333334。

厨房保留原 H 完整顶面，不绘制 `horizontal_cap`，仅绘制 `longitudinal_stem`。V27 的 tile_origin 放在 T localy24（1170.48），render_top_start仍local80（1226.48）；下段第一可见处相位56，对应同一sourceX454.8333。若在local80重置 sourceX232，仍然会断石缝，不能验收。

初轮actual发现原H有效石体底local21至stem起点24间的3world暗断带。已与制作人协商契约例外，在主stem前补同源contact：dest[56,21,cross,3]、source[465.0625,192,11.9375,74.07407407407408]、transpose true、role longitudinal_stem，是上一V27周期尾3world，接local24的phase0。主stem24..80/下口80和下段origin24全不改，原PNG与H横臂均不动。原生试拼已补接触带，采用同一H顶面和V27相位延续，下段与stub同一顶面和侧影。源/几何/相位数值检查和图标 GPU 可见证据已完成；正式判断须看 P64 实际两条完整纵墙从顶部到末端及编辑器，不能只看 T 近景。

主美只改本版素材元数据、图标和文档；shared、地图和 Git 归制作人。旧 V24–30 冻结 hash 全部保持。修正版P64实际完整左右纵墙game/editor、两规格独立组件和分类图已复核；上下窄顶面和侧影一致，接触带已连接H底。原样复制证据后冻结，待制作人独立验收。


