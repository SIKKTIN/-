# 医务室双扇侧滑门

依据已确认的 `docs/art/clinic-restoration/door-day-night-concept-v2.png` 制作。

- `sliding_leaf.png`：独立灰绿金属左门扇、磨砂玻璃、内嵌拉手和吊轮，右扇由运行时镜像复用。
- `sliding_track.png`：独立蓝灰双轨及端部固定件。
- `manifest.json`：两个附件与一个完整门资源 `doorway_clinic_sliding_v2`，包含显示尺寸和运动参数。

模式：内置 `image_gen`。PNG 原样复制，保留原始 RGBA 像素和透明边距；有效区域只登记在元数据中。完整提示词、来源和哈希在 `docs/art/clinic-restoration/sliding-door-assets.json` / `sliding-door-registration.json`。

当前 R04 医务室通过 `access_id: clinic-entry` 与 08:00–20:00 定时门禁绑定。单独从编辑器放置素材不会自动创建定时规则；规则由地图 `access_doors` 描述。
