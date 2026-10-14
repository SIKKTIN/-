# 洗衣房概念 v02 接入

按 `docs/concepts/laundry-restoration-v02.png` 制作并接入 R04，保留 900×480 房间范围。

- 四台同型滚筒洗衣机、四位供水管、窄布草架、净衣架、脏衣分拣台、叠衣台；复用并校准水池和帆布车。
- 灰白抹灰、灰绿墙裙、深灰基座、薄灰压顶；模块化横墙、纵墙、四向转角、三向接头与短门楣可用于地图编辑器。
- 南入口改为蓝灰双扇钢门。开启/关闭素材注册在编辑器，关闭门叶复用开启素材的门框像素，固定注册点。南入口继续沿用原来的常开通行设置；未新增门锁或交互规则。
- 蓝灰金属屋顶、两条磨砂采光带、通风罩、东侧天沟与落水管。室内隐藏屋顶，室外遮住家具。
- 收纳架、分拣台、叠衣台和布草车使用现有 linen 掉落表，支持搜刮及双向背包移动。
- 食堂后门、共用北墙、东西侧通道、已有门禁规则、人物 1.4 倍大小以及全身门碰撞均保留。

全部新图通过内置 imagegen 生成，原始 PNG 未改写；提示词与来源见 `generated-assets.json`、`pipe-assets.json`，校准与 SHA256 见 `asset-registration.json`。正式素材保存于 `art/props/laundry_v1`、`art/architecture/laundry_v1`，地面登记于 `art/environment/laundry_v1`。运行时家具/门纹理限长 512、采光带 256、屋顶和墙体 1024，静态绘制与纹理缓存复用。

`tools/register_laundry_restoration.py` 读取最新地图，写入前检查 SHA256，记录输入输出备份；对范围外字段和食堂共用墙不做修改。重复登记跳过相同 PNG，避免无意义重新导入。

`qa/laundry_restoration.gd` 验证地图保留范围、搜刮、全身通行、关闭阻挡、固定门框、屋顶切换、家具脚印、编辑器重读与资源可用性，以及医疗室滑门的门槛/门叶层次。完整结果见 `checks.json`，实机预览为 `runtime-interior.png`、`runtime-closed-door.png`、`runtime-roof.png`，编辑器预览为 `editor-layout.png`。

无自动 Git 提交。食堂连接处美术继续留待后续协调。
