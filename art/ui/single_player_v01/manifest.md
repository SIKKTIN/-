# 单主角背包图标

`inventory-icons.png`：1280×1280，透明 PNG。ImageGen 内置工具生成，未对像素做后期编辑。

Godot 以四个等大象限读取透明内容的实际边界，创建 AtlasTexture；只在初始化读取一次。启用 mipmap，背包物品格与详情图使用带 mipmap 的线性采样。

| 象限 | 游戏定义 |
| --- | --- |
| 左上：黄铜钥匙 | door_key |
| 右上：撬锁工具 | lock_tool |
| 左下：齿轮零件 | scrap |
| 右下：帆布背包 | backpack |

生成提示词：

> Production game UI icon atlas, exactly four isolated objects in a two-by-two grid with equal quadrants and generous transparent margins: top-left tarnished brass key; top-right steel lockpick bundle with wrapped handle; bottom-left a small heap of three or four old gears; bottom-right khaki and olive brown canvas satchel. Hand-painted 2D industrial prison survival game style, subtle dark outlines, soft shading, desaturated steel, brass and khaki, neutral front/top three-quarter lighting. No cast shadows outside the objects, no labels, numbers, frames, dividers, neon or background. Fully transparent background.

HUD 面板、按钮、铆钉和进度条采用 Godot 原生绘制；`art/ui/fullscreen/interaction.svg` 延续现有矢量图标的线宽和配色。
