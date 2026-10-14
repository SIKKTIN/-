# 医务室专用屋顶

对应 `docs/art/clinic-restoration/roof-concept-v1.png`。四张内置 imagegen 原始 PNG 原样保留：灰绿防水屋面、磨砂天窗、小型排风口、排水格栅。完整提示词和来源在 `roof-assets.json`，哈希在 `roof-registration.json`。透明配件通过 manifest 的 region 取样，不改原始像素。

屋面只映射一次，随房间轮廓和门洞裁切，不在每个裁切块重新起算 UV；天窗、排风和排水格栅独立挂在屋顶节点上，随屋顶一起显隐。房间进入屋顶隐藏、出门屋顶显示；永久蓝灰墙边沿用转角修正版。

`visibility_rooms` 的 `roof_style: clinic` 选择这套屋顶。地图编辑器“房间可见范围”的屋顶样式里可选择“医务室 · 灰绿防水平顶”。运行 `python tools/register_clinic_roof.py` 只给当前保存地图的医务室设置屋顶样式，不移动房间、家具或人物。
