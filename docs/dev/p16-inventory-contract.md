# P16 独立背包接口

基线 v0.6；2026-10-05 用户授权执行原计划，覆盖上一轮“仅制定计划”的限制。

`game.inventory` 维护唯一实例注册表、三个独立背包和局内钱包。普通角色 1 格，`backpack` 被动技能 3 格。`capacity` / `items` 为读取接口；`try_pickup` / `try_drop` / `try_transfer` 返回 `{ok, reason}`。操作重新检查所有权、角色状态、容量、距离与遮挡，不覆盖、不复制。拾取 60 单位，交接 40 单位。

实例字段：`id`、`definition_id`、`location`（ground/bag/escaped/consumed；P17 添加 shop）、`actor_id`、`position`。同一件物品始终只有一个实例 ID。钱包共享、不占格；被抓保留，逃脱物品标记 escaped 并禁止再操作，重开/换关清空。绘制层只读取状态。

R01/R02 保留三技能池，房间配置可提供 `skill_pool` 给 R03 四技能池。随机允许重复，固定种子复现。暂未声称 R03、物品使用和商人已实现。

主美 A05 接口：右侧背包三个槽位，每格 47×48（物品图标 28×28）；商人独立中立 NPC，脚底中心锚点、约 64 世界单位高，不占 actor_id。物品地面图标约 26×26，HUD 24–28。资源采用 art-v03 已确认 FINAL-WARM-01 风格，必须在新目录/新文件交付，禁止覆盖既有资产。物品 ID：scrap、door_key、lock_tool；技能 ID：backpack；反馈需要 trade、pickup、drop、transfer、full、empty。交互提示图标可点击，鼠标与 E 共用逻辑；UI 由制作人接入。

证据：`docs/tests/p16-inventory.json`，容量、守恒、拒绝重复/满包、交接、切换、被抓、离场、重置和随机池检查。技术检查不代替真人可玩性观察。
