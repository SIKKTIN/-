# A07 四角色八帧行走资源交付

日期：2026-10-05。风格：FINAL-WARM-01。交付状态：主美资源自检通过，提交制作人独立验收；生产关卡接入与实际移动效果由 P27 检查。

四个现有身份各提供 8 个真实不同姿态，顺序 walk_0…walk_7，12fps，完整周期 2/3 秒。第一排是第一步，第二排是另一条腿迈步；各步有接触、下沉、经过、抬脚阶段。右向原图由运行时镜像为左向。旧 idle、world_height 60/72、碰撞与移动逻辑保留。四张最终透明 PNG 均为内置 imagegen 生成结果的逐字节原样复制，未用代码重画、拉伸人物、插值或合成动画姿态。源、两轮完整提示词及 SHA256 见 a07-source-license-v09.json、a07-imagegen-prompts-v09.json、a07-imagegen-corrections-v09.json。

## 最终资源及接口

- art/characters/walk_v09/inmate_01_walk8_v09.png
- art/characters/walk_v09/inmate_02_walk8_v09.png
- art/characters/walk_v09/inmate_03_walk8_v09.png
- art/characters/walk_v09/guard_01_walk8_v09.png
- art/characters/manifest-v09.json

仅以上四张 PNG 进入生产清单；同目录 draft_v09 是历史草稿，不接入。PNG 均为 1774×887 RGBA，无烘焙地面阴影、技能图标或文字。

制作人 2026-10-05 的反馈允许逐帧不同 region 尺寸，统一 scale_height 与脚底原点，以消除共享大框混入邻帧。最终清单据此更新：

```text
scale = actor.world_height / actor.walk_animation.scale_height
destination.position = world_foot_position - frame.anchor * scale
destination.size = frame.region.size * scale
```

每个角色八帧使用完全相同的 scale；不要除以各帧 region.height，不再使用 shared_frame_size 或 frame_world_height。每帧 anchor 指明该裁框内的头部中轴/脚底坐标，映射到统一世界脚底原点。不同裁框的 anchor 数值可以不同，映射后的脚底误差均为 0；角色大小不随透明裁框变化。保留 P26 的逐帧裁切再建 mipmap 缓存，避免整张图集跨区采样；每帧 Atlas 可启用 filter_clip。

分行边界取实际透明间隔，狱警为 y=455，其他角色为 y=443。裁框仅含本姿态，所有 32 帧的核心像素完整保留，邻帧核心像素为 0。上一版共用大裁框与旧预览的负帧序号已修正。a07-contact-*-v09.png 和 v09r2.png 为历史排查记录，正式证据只用 v09r3。

## 检查证据

| 角色 | 八帧实际高度波动 | 头宽波动 | 不同下半身轮廓 |
|---|---:|---:|---:|
| 细长伙伴 | 1.44% | 1.67% | 8 |
| 圆胖伙伴 | 3.38% | 1.46% | 8 |
| 方壮伙伴 | 3.28% | 1.46% | 8 |
| 深蓝狱警 | 3.13% | 2.25% | 8 |

新走路中位可见高度与旧 idle 对齐。高度变化均低于 6%，头宽变化均低于 8%。源复制 SHA 一致；旧资产基线 101 文件无改动。轮廓差异是辅助证据，姿态、角色身份与闭环也已检查原图和八帧接触表。

- a07-qa-resources-v09.json：四角色、32 帧、透明区与邻帧隔离、共同缩放、旧资产 SHA 检查通过。
- a07-qa-browser-v09.json：1280×720、960×540 均通过，中文字体完整，无越界和脚本错误；真实计时采样覆盖全部八帧，帧号无负值。
- docs/tests/a07-qa-godot-v09.json：隔离项目中的 Godot 4.7.2 headless 原生 Image / AtlasTexture / SpriteFrames 检查通过，32 个不同裁框、统一缩放和脚底原点、8帧12fps循环可读。
- a07-contact-1280x720-v09r3.png、a07-contact-960x540-v09r3.png：旧 idle 与新八帧并列，脚底线、原生60/72尺寸左右镜像对照；帽子上方无游离碎片。
- a07-walk8-12fps-v09.gif：原生尺寸八帧左右镜像循环。GIF 以 80/90ms 表达帧时长，周期 670ms，约11.94fps；可运行 HTML 和生产配置为精确12fps。
- a07-resource-preview-v09.html：可运行资源预览，a07-preview-v09.cjs 是无界面的自动检查与导出工具；a07-assemble-v09.py 只读生成 PNG 并建立裁框/缩放元数据。

本次没有修改共享 scripts、data、scenes、根 project.godot，没有启动生产项目或抢占可见 Godot 窗口。隔离 QA 工程位于 docs/art/a07-godot-qa-v09。主游戏中的实际移动速度、动画切换、idle衔接和 mipmap 视觉表现仍需制作人接入后验收。
