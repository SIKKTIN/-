# R04斜俯视餐桌与独立餐盘

按用户批准的concept-overhead-v4.png替换食堂内四组餐桌和四个餐盘。建筑、墙、门、后厨、取餐台、走廊餐桌及其他地图不改。餐桌表面保持平行矩形、能看见顶部，桌沿和钢架减少正面强调；餐盘采用相同俯视方向。

正式素材由内置image_gen生成，原始PNG完整复制，未改像素：

- art/props/cafeteria_v41/communal_table_v41.png：完整餐桌与前后长凳，桌面无餐盘。
- art/props/cafeteria_v41/food_tray_v41.png：独立分格金属餐盘，米饭、蔬菜、土豆。
- generation-prompts-assets.txt：原图路径、完整生成提示词和餐盘比例修正记录。
- art/props/cafeteria_v41/manifest.json：原图SHA256、裁切元数据、等比落地注册。

餐桌保持原210×105落地范围，实际显示约210×116；旧PNG和旧定义保留。餐盘显示60×24.46，在每张桌面居中，排序高于桌子，不增加碰撞。餐具比原36单位宽更易辨识，符合批准概念图的桌面比例。

素材库“食堂设施→家具摆设”提供新餐桌，“食堂设施→餐盘”提供新餐盘，可以分别放置、移动、复制。缩略图使用原生MeshTexture资源和导入纹理。桌面空白，餐具不合进桌子，便于复用。

只有dine-table-0..3与dine-tray-0..3八个摆设引用/餐盘注册发生变化。r04-before-tables.json为修改前备份，integration.json记录实际摆放。所有非摆设地图数据及所有碰撞范围保持原值，就餐点不改。

导入时发现近期运行时绘制缓存新增fixtures_revision，但编辑器几何适配器缺少该属性，造成预览脚本错误。本次在preview_geometry.gd补齐版本号并随数据刷新递增，恢复共享绘制器的预览契约，不修改建筑绘制或贴图。

checks.json：28项原生编辑器/运行场景检查通过，包括正式素材库、透明纹理、等比缩放、餐盘完整落在桌面、排序、碰撞不变和全部就餐点寻路。access-checks.json：73项现有管制门、取餐、禁闭、逃脱回归通过。r04-tables-editor.png、r04-full.png、r04-tables-runtime.png为实际渲染截图。

未提交、发布或反馈制作人，待实际效果审评。
