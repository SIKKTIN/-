# 角色与动画预览器

地图编辑器工具栏的 **角色预览** 按钮打开独立预览窗口，不修改或保存地图。也可运行 `scripts/editor/open_character_previewer.ps1`，或在 Godot 中运行 `scenes/editor/character_previewer.tscn`。

预览器直接读取 `data/presentation/character_libraries.json`，显示当前 14 套已制作角色；后续向该目录清单注册的角色会自动出现。仅有概念图、尚未制作动画的形象不会列入。

- 搜索中文名称或角色 ID，切换角色。
- 站立 / 行走，播放 / 暂停，上一帧 / 下一帧，时间条和帧缩略图。
- 0.25–2 倍播放速度，1–6 倍放大；视窗不足时自动适配放大预览。右侧始终保留游戏 1 倍尺寸作为参照。
- 左右镜像、浅色 / 深色 / 地面色背景、脚底定位参考线。
- 空格播放或暂停，左右方向键逐帧；搜索框输入时不抢按键。

现有素材为单一斜俯视朝向及其左右镜像，尚未制作独立的朝上、朝下动画。预览使用与运行时一致的帧裁切、尺寸比例、脚底锚点和默认帧率，不改动美术原图。只在选中角色时准备其行走纹理，使用现有纹理缓存。

验证：`Godot_v4.7.2-stable_win64_console.exe --headless --path <项目目录> --script res://qa/character_previewer.gd`。去掉 `--headless` 可生成原生界面截图 `preview-1280.png` 和 `preview-960.png`。报告保存在本目录 `checks.json`。
