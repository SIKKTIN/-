# R04 · C 版灰绿地面与自然外围

用户选定 C 概念图后接入。采用清楚而克制的砖缝、灰绿色哑光地面、简化叶片与自由形土草边界；替换 V45 的写实碎纹理。

## 素材

使用内置 imagegen 生成，原始 PNG 不修改像素。原件及 SHA256 见 [terrain-registration.json](terrain-registration.json)。

- [已选概念图 C](approved-concept-c.png)
- [六种地面原图](../../../art/environment/factory_v46/floor_atlas.png)、[生成提示词](floor-prompt.txt)
- [四种透明土草与灌木原图](../../../art/environment/factory_v46/organic_atlas.png)、[生成提示词](organic-prompt.txt)
- [素材注册](../../../art/environment/factory_v46/manifest.json)

生活区使用灰绿地砖，车间使用冷灰大板，仓库与设备间使用深灰砖，通道和装卸场使用浅灰绿铺地，洗衣房使用浅绿小砖。外围以橄榄草地为底，加自然泥土斑块、草簇、小石与低矮灌木。自然素材用位置与等比例缩放产生变化，避免排成重复的行。带俯视立面、叶片与石块光照的素材固定朝向，禁止旋转、镜像及拉伸；左右狭窄外围使用从原图注册的三种单株灌木。

19 处地面覆盖范围保留，57 个自由形自然斑块。建筑、墙线、物件位置、碰撞与门禁未修改。编辑器和游戏使用同一地面渲染器；每张地图可以选择独立的地面素材清单，旧版地图仍可正常加载。

## 核对

- [原生编辑器地图效果](r04-terrain-overview.png)
- [游戏画面](loading-runtime.png)
- [检查记录](checks.json)：原生地图验证无错误、无警告；包含素材、原图、布局保持、游戏载入、固定朝向与等比例摆放。
- [西侧寝室实际画面](upright-west-dorm.png)、[西侧禁闭室实际画面](upright-west-confinement.png)：核对两张反馈截图指出的外围方向。

尚未向制作人反馈，未提交 Git。
