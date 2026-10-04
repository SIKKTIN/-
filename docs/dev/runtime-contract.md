# Godot 主干与资产接口

v0.4（P13 手绘视觉接入，保留P11输入与规则）入口：`res://scenes/main.tscn`，根节点 `/root/EscapeGame`。历史交付与截图保留各自版本。

- 参考世界画布 1200×720；GameCreator 地图 cellSize=40，网格坐标乘40转换世界单位。人物位置为脚底中心，地图与UI各自处理输入。鼠标事件坐标通过get_global_transform_with_canvas().affine_inverse()转换，兼容缩放、相机与模拟输入，不读取操作系统光标位置代替事件。
- `scripts/actors/prisoner.gd` 保存稳定 `actor_id`（0—2）与独立 `skill_id`（chat/lockpick/strong），以及position、facing、action_state、escaped、selected。选择只改变输入归属，后续持续技能属于人物本身。
- 根节点 `snapshot()` 提供状态；`select_at(Vector2)`、`select_actor(int)`只改变选中，`command_move(actor_id, Vector2)`下达该人的持续移动命令；`orders.active`保存每人的路径/目标，换人不取消；`stop_selected()`/S只停止当前人物的移动和技能，`reset_round()`清空全员命令。左键选人/卡片，右键地面移动，E启停技能。无拖动输入、牵手或狱警选择。右键出口符号/出口线自动指向有效撤离位置。
- 当前v0.4/art-v03世界人物目标高度：友军60、狱警72单位；回滚art-v02为55/62、art-v01为42/48。manifest记录每帧rect与脚底anchor；消费真实facing，水平向左时仅身体围绕脚底原点镜像，向右恢复，纯竖直与停止保留最近水平朝向。逻辑朝向、编号及技能符号保持世界方向，角色轮廓不绑定技能。
- 首轮动画：四个角色各1张站立、2张交替迈步；播放依据实际位移，顶墙不迈步。聊天/撬锁/推箱用可共用的轻姿态和状态符号，暂不要求四方向完整动画。主美任务标准需同步此用户要求。
- 美术只写art/characters、art/environment、art/props、art/ui、art/fx、art/fonts、audio和docs/art；共享场景、逻辑和碰撞由制作人接入。
- 建议manifest：`art/characters/manifest.json`，schema=1，actors数组；每条actor_id（0、1、2、guard）、texture（res://路径）、frames（idle/walk_a/walk_b的[x,y,w,h]）、anchor（各帧脚底[x,y]）、world_height。道具与UI分别在自身目录交付清单，注明source/license。

当前双关、三技能与随机开局、警戒、环境与纸片风均已接入。导航用同一圆形碰撞规则验证路径并跳过已走过的格点；巡逻保留可用路径，门/箱变化或阻挡时重规划，被挡住的巡逻点改走下一点，禁止越墙/瞬移。真人趣味性与完整三次尝试仍待P09。

当前P13视觉消费层：`data/presentation/active.json`选v03；独立v01/v02/v03 profile引用版本清单，旧资源和P12证据保留。`ESCAPE_ART_PROFILE=v01`或v02可在单次启动覆盖，或将active.json改回旧profile后重启。v03地板按384世界单位重复（交付原建议512经实际比较后调整），边缘裁切源区域；墙18、宽障碍24，窄墙顶面内右侧4单位同材质0.68背光/柔和过渡，南front0.74。PNG不改像素，AtlasTexture按region取原图。门视觉20，箱按局部ground_rect消费，立面15.87，原逻辑footprint不变。地面警戒扇形调用原guard.view_polygon；身体按脚底y、体积按南侧落地边界排序；编号/技能/选中/朝向独立信息层。柔和接触影/统一右下短投影只绘一次，尊重shadow_baked。撬锁进度条位于动作徽章上方，侧栏说明与固定操作提示分开。snapshot.render_settings记录实际参数。
