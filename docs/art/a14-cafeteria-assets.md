# A14 · 食堂可用素材交付

2026-10-05，主美。任务 `c2c6c499-e6e9-4568-b807-7a71c92c1eab`，由制作人验收。

用户已认可 A13 修订后的朴素配餐概念。此次交付四件可单独摆放的透明素材，沿用 `art-v03 / FINAL-WARM-01`：平行俯视、旧灰金属、深墨轮廓、少量白米饭、灰绿煮白菜、淡黄土豆与清汤。无地板、人物、文字及烘焙地面阴影。四张长木桌继续复用 `prison_v08/communal_table_v08.png`。

## 资源接口

入口：`art/props/cafeteria_v14/manifest.json`。每项提供 `id/texture/region/ground_rect/footprint_world_size/world_size/elevation_world/shadow_baked`。PNG 是完整生成源图，使用 `region` 取单一素材；`ground_rect` 是该裁区的局部坐标，不能直接按整张源图解释。

| ID | PNG | 逻辑脚印 | 实际绘制框世界尺寸 | 北向高度投影 |
|---|---|---|---|---|
| cafeteria_counter | cafeteria_counter_v14.png | 600×80 | 610.38×229.54 | 147.32 |
| cafeteria_return | cafeteria_return_v14.png | 110×70 | 111.77×106.01 | 35.12 |
| cafeteria_tray | cafeteria_tray_v14.png | 36×20桌面占位 | 36.42×20.45 | 0.21 |
| cafeteria_queue | cafeteria_queue_v14.png | 180×12 | 181.64×37.01 | 24.25 |

上述尺寸使用同一个横纵缩放系数，没有把原图拉宽或压扁。`world_size` 是完整裁区的绘制尺寸，不能再作为逻辑脚印使用。前台+后厨是一个组合：后厨向北投影，制作人应将图像覆盖的后方区纳入隐藏碰撞，避免穿过炉具/柜体；前台脚印与后厨碰撞职责不同。回收架实际生成较矮，保留约106的原始绘制高度，不拉伸到最初估计的140。

餐盘是非碰撞桌面配饰：36×20是摆放单元，彩色主体约36×13.81。裁区保留原PNG现有的透明余深，让 `ground_rect` 和缩放一致；这里的占位不表示餐盘实体占满20深度。程序将其压在桌面之上，避免被桌子覆盖。四件素材都不自行添加交互功能。

## 来源和检查

使用内置 `image_gen.imagegen`，参考已批准的 `docs/art/a13-cafeteria-concept.png`，每件单独生成。完整提示词与排队栏定向去背景修订见 `a14-imagegen-source.json`，四份源PNG绝对路径与SHA256见 `a14-qa-resources.json`；交付PNG逐字节匹配对应生成源文件。Python只读RGBA/alpha并写元数据，不改、重绘、缩放源PNG。

排队栏工具预览曾显灰色晕圈，因此做了一次内置图像编辑。随后检查透明空隙实际alpha=0，Godot原生合成也无灰晕。四素材均为真实RGBA；裁框不漏主体、不含相邻素材，`ground_rect`位于裁区内，横纵缩放相等，无遮挡背景或烘焙接触阴影。

`a14-register-resources.py` 可重复执行RGBA、哈希、裁框与标定检查，结果保存在 `a14-qa-resources.json`。`a14-resource-native.gd` 是独立SceneTree QA，命令：

```powershell
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/Project/Godot/这次怎么逃' --script 'E:/Project/Godot/这次怎么逃/docs/art/a14-resource-native.gd'
```

原生D3D12渲染检查通过，截图 `a14-contact-1280x720.png` 已实际查看；餐盘/回收架/取餐台在原定世界尺寸可辨识，排队栏在淡底与正常alpha合成下干净。截图中的青绿线仅为QA脚印辅助线，不属于PNG素材。

本次完成的是可用素材和接口。主美未编辑地图、脚本、旧资源或配置，未提交Git；R04实际摆放、碰撞、日程吃饭、镜头与游戏整合验收由制作人另行完成。

## 文件

- `art/props/cafeteria_v14/manifest.json`
- `art/props/cafeteria_v14/cafeteria_counter_v14.png`
- `art/props/cafeteria_v14/cafeteria_return_v14.png`
- `art/props/cafeteria_v14/cafeteria_tray_v14.png`
- `art/props/cafeteria_v14/cafeteria_queue_v14.png`
- `docs/art/a14-cafeteria-assets.md`
- `docs/art/a14-imagegen-source.json`
- `docs/art/a14-qa-resources.json`
- `docs/art/a14-register-resources.py`
- `docs/art/a14-resource-native.gd`
- `docs/art/a14-contact-1280x720.png`
