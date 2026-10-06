# A19 门禁、禁闭室素材与编辑器图标

2026-10-06，主美。任务 a19-access-solitary-art-20261006，制作人独立验收。CLI已核对本人身份并反馈进行中；A17栅栏门复用。

新增3张透明原PNG、4个世界状态：门禁控制盒、禁闭室实心铁门关闭/打开、简陋薄单人铁床。沿用FINAL-WARM-01灰绿旧铁、深墨描边、暖浅磨损和固定轻度俯视。硬床没有枕头、厚被或蓬松床垫。

## 清单入口与尺寸

- 世界入口：`art/props/security_v19/manifest.json`，schema1 assets。
- 编辑器入口：`art/editor/v02/manifest.json`，schema1 assets[{id,name,category,editor_icon}],tools[]。
- 每个新增世界项已附 `editor_icon`；v02共13项（A17九状态+A19四状态），均为真正的Godot AtlasTexture .tres。

| ID | 地面/挂载标定 | 完整绘制尺寸 | 对应PNG |
|---|---|---|---|
| access_reader | 墙盒宽18，挂载建议离地38；无地面碰撞 | 18.35×30.10 | access_reader_v19.png |
| solitary_door_closed | 水平门槛80×14 | 81.31×80.33 | solitary_door_pair_v19.png左格 |
| solitary_door_open | 同上，门框保持固定 | 同上 | 同图右格 |
| solitary_bed | 地面72×112 | 73.39×141.57 | solitary_bed_v19.png |

world_size是裁区完整绘制框，不是碰撞尺寸。region取原PNG裁区，ground_rect和anchor是该裁区局部坐标；横纵使用同一比例，不能按新的脚印随意独立拉伸。

```text
scale = footprint.size / ground_rect.size
draw_origin = footprint.position - ground_rect.position * scale
draw_size = region.size * scale
```

两门状态同region尺寸、ground_rect、anchor、scale和world_size，朝向是门槛东西向、门面朝画面前方。原图固定框体行列和脚底一致，末端门把手可见边界相差1源像素（约0.11世界单位），共享裁框完整保留，未修改PNG去强行一致。打开门洞3处取样alpha=0，门柱仍是固定实体，实际通道边界由程序设置。

门开闭、锁定、食堂12:00–14:00门禁、被捕禁闭2游戏小时、伙伴撬锁救人由P52程序绑定。本素材仅提供状态外观；closed.blocking=true/open.blocking=false为门状态建议，不增加玩法。

门禁盒render_mode=wall_attachment，mount_anchor和recommended_mount_height_world齐全；ground_rect的1单位深是注册带。blocking=false，禁止作为地面障碍或绘制地面接触影。原图红绿指示是中性镜片，不含灯光晕圈；当前状态高亮、变色或交互信息由程序叠加。所有素材shadow_baked=false，床/门地面阴影由现有程序绘制一次。

## 编辑器图标接入

v02是增量清单：合并其13个assets到现有v01索引，保留v01 tools（v02 tools为空）。类别只用现有props/furniture，不添加未实现的新分类。A17旧world manifest不改。

新布告板编辑器ID用 **prison_notice_board**，其Atlas引用A17 notice_board_v17.png；A17世界原ID仍是notice_board。制作人加载A17时将世界实例别名映射为prison_notice_board，旧prison_v08的notice_board与其图标继续保留。其余A17 ID一一对应。

13个图标在 `art/editor/v02/icons/*.tres`，原PNG+region+透明方形margin，filter_clip=true，不另画一套不匹配的缩略图。TextureRect使用keep aspect centered，并将控件最小尺寸设48×48或64×64；Atlas资源本身保留源分辨率，非固定64像素位图。editor-icon-regions-v19.json记录全部region/margin及别名对应。

## 来源、原生检查与预览

新PNG由内置imagegen单独生成，以A17项目自有铁门为材质/风格参考。完整提示词 imagegen-prompts-v19.json，生成源路径/原样SHA source-license-v19.json。新世界PNG逐字节匹配工具输出，没有代码调alpha、抠背景、重画或缩放。Atlas只是资源元数据，A17原图及manifest无变化。

- qa-resources-v19.json：4项完整裁框、透明、开门通道、等比缩放、共用门注册及184旧资产/图标/清单SHA检查通过。
- qa-godot-v19.json：隔离Godot4.7.2 headless通过原生Texture2D/AtlasTexture读取、4个世界region/ground/scale、13个图标。13×2个48/64尺寸在Godot原生Image中按Atlas margin等比绘制并导出为QA缩略图；这是测试预览，未回写任何素材PNG。
- native-icons-v19/*.png：26张原生图标检查图，48或64像素；保留原材质比例和透明余量。
- qa-browser-v19.json：1280×720和960×540的尺寸/图标板通过，无字体缺失、脚本错误或溢出。contact-1280x720-v19.png / contact-960x540-v19.png已实际查看；床的长轴与门槛正确，48/64各状态可辨识。
- preview-v19.html / preview-v19.cjs：世界尺寸与原生图标并列的可运行预览与无界面截图工具。
- register-v19.py：只读原PNG、原样复制、建立world/Atlas/editor清单；prepare-native-v19.py只复制11张纹理、13个图标及3份清单进入最小隔离资源QA工程，不复制游戏工程、不启动主项目。

世界尺寸预览中门/伙伴为×1.5、门禁盒为×3细节、床为×1.1；图标为真实48/64。预览不是实际关卡或生产编辑器接入截图。生产编辑器合并、地图摆放、碰撞与状态切换由制作人验收。

此次只写允许的security_v19、editor/v02、docs/art/security-v19目录。不改scripts/data/scenes/旧manifest/旧PNG或根project.godot，不Git提交；所有协作命令用主美本人凭证CLI。交付版本和逐文件SHA见delivery-filelist-v19.json，CLI反馈与回执另存。复查原生图标若PNG已存在，只允许数据完全一致时读取，不覆盖不同预览。
