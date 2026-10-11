# 年长工人行走修复

旧图有重复的同侧迈步姿势，无法形成完整的双腿交替周期。此次保留已批准的站立原图、头像和身份，使用内置 imagegen 重绘独立的八帧行走图；最终采用 `art/characters/factory_cast_v47/older_worker_walk_v2.png`。

新版包含两种相反的触地姿势、抬脚和经过姿势。裁切与头部中轴、脚底基线通过元数据登记，PNG 原始像素保持不变。默认行走为 8 FPS；沿用当前角色登记的游戏尺寸。运行时与预览器均读取同一清单。

原生游戏与预览器验证共 182 项通过：本次修复 41 项，预览器回归 141 项。

角色库支持站立和行走来自不同文件，同文件角色仍使用一次解码的缓存路径。预览器显示当前动画对应的素材文件。新 PNG 在尚未被 Godot 导入时也可通过现有原图读取路径使用。

`registration.json` 记录裁切和脚底锚点，`previous-walk.json` 保留旧登记。`prompt.txt` 是最终采用图片的编辑提示词，`pose-guide.png` 是用于约束步态的示意参考。

运行 `qa/older_worker_walk.gd` 检查游戏内帧纹理、脚底、循环、镜像和停止后恢复站立；`qa/character_previewer.gd` 覆盖其他角色以及播放器操作。使用 `scripts/editor/open_character_previewer.ps1 -CharacterId older_worker` 可以直接查看修复后的角色。
