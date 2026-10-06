# A17 监狱门与场景素材扩展

2026-10-06，主美。用户要求增加参考图中的监狱门和更多场景美术。沿用 FINAL-WARM-01：灰绿旧铁、暖白陶瓷、赭黄木框、深墨描边与轻度俯视。现有床、栅栏、便器、工作台及柜子复用。

交付 **8张透明原PNG，9个可独立引用的状态/道具**。素材已自检，生产关卡摆放、碰撞和门状态绑定由制作人独立验收。拼装图仅演示现有与新增素材的搭配，不是主游戏截图。

## 新素材

| ID | 内容 | 标定 |
|---|---|---|
| prison_gate_closed | 关闭滑动铁门 | 地面门槛80×14；绘制81.32×80.33 |
| prison_gate_open | 打开滑动铁门 | 与关闭状态同尺寸、同门框、同落点 |
| wall_vent | 墙面通风口 | 墙面宽48；绘制48.50×22.96 |
| caged_wall_lamp | 笼罩墙灯 | 墙面宽24；绘制24.32×13.35 |
| pipe_valve | 管线与阀门 | 墙面宽82；绘制83.54×98.84 |
| wash_basin | 双位洗漱盆 | 地面占位100×42；绘制101.20×53.20 |
| fire_extinguisher | 灭火器与挂架 | 墙面宽22；绘制22.56×42.41 |
| notice_board | 无字旧布告板 | 墙面宽90；绘制90.99×35.67 |
| laundry_cart | 洗衣推车 | 地面占位68×48；绘制69.17×57.98 |

门开闭图位于同一图集左右两格，其余道具各一张PNG。墙灯为无光晕的中性状态，灯光由程序控制；灭火器仅环境摆设；公告纸留白，若要公告内容由中文文字层绘制。

## 接口

入口：`art/props/prison_v17/manifest.json`，schema1 `assets`。每项有 id、texture、region、ground_rect、footprint_world_size、world_size、scale、anchor、elevation_world、shadow_baked、render_mode、blocking、interactive、sha256。

PNG保留完整原图，先取 `region`；`ground_rect`、`anchor`是裁区局部坐标。横纵同一缩放比例，不拉伸原图。地面素材适配现有 WorldVolume 的映射：

```text
scale = footprint.size / ground_rect.size
draw_origin = footprint.position - ground_rect.position * scale
draw_size = region.size * scale
```

也可使用锚点绘制：`draw_origin = world_south_center - anchor * scale`。源图裁出后建立 mipmap，避免直接在整张图集跨区缩小采样。

门两状态具有完全相同的 region 尺寸、ground_rect、anchor、world_size与scale，开闭切换门框不跳动。当前门槛为东西向80×14，应放在同方向的牢房/走廊入口；竖向通道需另一方向的图面标定。关闭状态 blocking=true、打开状态 blocking=false 仅给状态绑定建议，门框立柱仍有实体边界；锁头、门交互及实际碰撞由现有逻辑驱动，不能因PNG改变玩法。

五件墙面物件 `render_mode=wall_attachment`，`ground_rect`只是1世界单位深的注册带，不代表地面碰撞。推荐落点为墙脚中心减去 `recommended_mount_height_world`，使用 `mount_anchor` 和同一scale；优先挂在北侧/剖开的背景墙，避免高面板覆盖人物与交互信息。原门锁图标和人物标号保持独立信息层。

洗漱盆与洗衣推车是静态摆设，blocking=true、interactive=false；布告板、阀门等不附加互动。所有原图 shadow_baked=false；地面接触影由现有 SoftShadow 绘制一次，墙面附件无需调用地面矩形阴影。

## 来源与检查

使用内置 imagegen，以用户提供的场景图为风格/材质参考，每件单独生成。参考副本 user-reference-v17.png、完整最终提示词 imagegen-prompts-v17.json、源文件绝对路径与SHA source-license-v17.json。所有项目PNG逐字节匹配生成源，没有用代码抠背景、调alpha、补绘或拉伸。工具预览中的灰黑底/晕圈没有成为场景底图；透明边缘已在实际Canvas合成中查看。

- qa-resources-v17.json：9项裁框包含完整核心轮廓、没有邻格素材，RGBA透明，统一横纵比例、ground_rect合法。门开闭框体原始像素边界都是730×721，同源行列位置一致；打开门洞的3个取样点 alpha=0。门最外缘有最大alpha=1/255的原始残余，如实记录，无可见边框；原PNG未修改。旧资产基线129文件SHA无变化。
- qa-browser-v17.json：独立素材和拼装预览各1280×720、960×540，共4项通过；中文字体完整、无脚本错误、无横向溢出。预览已实际查看，主体未裁掉，门洞透明，人物/家具尺寸衔接。
- qa-godot-v17.json：隔离Godot4.7.2 headless Image/AtlasTexture读取、SHA、region、ground_rect、等比缩放和门注册通过；未启动生产项目。
- contact-1280x720-v17.png / contact-960x540-v17.png：独立9素材状态。检查板各素材使用1.8～2.2倍等比展示，墙灯按原定小尺寸展示，没有为检查图单独放大成大物件。
- scene-1280x720-v17.png / scene-960x540-v17.png：复用旧地板、床、便器、工作台、柜子和人物的拼装预览。高背景墙仅用于说明挂载位置，不替换现有碰撞或低墙规格。
- preview-v17.html：有“独立素材/拼装预览”两个视图；preview-v17.cjs 为无界面的自动截图检查。
- register-v17.py：只读分析PNG，原样复制并建立清单。godot-qa为本目录的最小资源检查工程，没有复制整套项目。

本次只写 `art/props/prison_v17/**` 与 `docs/art/prison-v17/**`，未改共享脚本、数据、场景、active配置、旧清单或根project.godot，未提交Git。正式交付版本与每文件SHA256见 delivery-filelist-v17.json，反馈回执另存。场景扩展还需制作人加载新清单、布置合适位置并检查实际遮挡、通道和门状态。
