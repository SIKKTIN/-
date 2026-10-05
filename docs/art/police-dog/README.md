# A08 警犬角色

日期：2026-10-05。FINAL-WARM-01 德国牧羊警犬，右向，暖棕/深色背斑、藏蓝项圈，与现有狱警线条和笔触衔接。交付一个待机和四个不同四足行走姿态；生产接入由制作人处理。

## 资源与接口

- 原始透明图集：art/characters/dog/police-dog-atlas-v01.png，1536×1024 RGBA。
- 程序入口清单：art/characters/dog/manifest.json，schema 1；manifest-v01.json 为同内容的版本存档，二者逐字节相同。
- 排列：3列×2行，第一行 idle/walk_0/walk_1，第二行 walk_2/walk_3/空白。
- world_height=44；idle 和 walk 使用同一 scale_height=380；walk.fps=10，4帧400ms闭环。

```text
scale = manifest.world_height / manifest.walk_animation.scale_height
position = world_foot_position - frame.anchor * scale
size = frame.region.size * scale
```

idle 也用此 scale（清单顶部及 idle.scale_height 为同一个380）。不要用各帧 region.height 单独算比例。不同 region/anchor 是逐帧裁切与脚底注册，人物实际大小稳定；原点位于犬身体中轴投影的地面，朝左时在原点镜像整个绘制。足底误差均为0；walk可见高度波动3.16%，头宽波动3.48%。idle约44.58像素，walk中位44像素，与72像素狱警的大小对照见检查图。

阴影未烘焙在PNG中。如关卡需要地面阴影，由程序单独绘制。保留角色接入现有逐帧裁切/mipmap流程；不要跨图集采样邻格。犬只AI、日程、碰撞和镜像动画切换均不属于本次素材交付。

## 来源与检查

使用内置 imagegen，参考项目自有 guard_01_handpaint_v03.png 的画风，未使用外部图片。完整最终提示词在 prompt-v01.json；原始生成路径及复制SHA256在 source-license-v01.json。项目PNG与工具原始输出逐字节相同，没有代码重画、插值、旋转人物、背景抠除或修改alpha。

qa-resources-v01.json 检查RGBA透明、完整轮廓、逐帧裁框位于本格、四种下半身轮廓、统一缩放、脚底与头身波动。真正透明像素占72.68%；空白格可见核心像素0，残余最大alpha=1/255，不影响显示。未把PNG黑底预览的透明RGB颜色当作地面或棕色背景。

qa-browser-v01.json：1280×720和960×540通过，字体完整、无溢出和脚本错误，真实动画时钟采样覆盖全部4帧，没有负序号。contact-1280x720-v01.png / contact-960x540-v01.png 包含idle、四帧、与狱警同场的原生尺寸左右镜像及3倍放大。

walk-cycle-10fps-v01.gif 为Canvas实际绘制导出的四帧循环，100ms每帧，无姿态合成。preview-v01.html 为可运行预览；preview-v01.cjs 为无界面检查程序。中间预览PNG不作为角色素材。

qa-godot-v01.json：隔离 Godot 4.7.2 headless Image/AtlasTexture/SpriteFrames 读取通过，1帧idle、4帧walk、10fps循环和5帧共同脚底尺度正确。QA工程为此目录内 godot-qa，不启动主项目。

没有修改现有 manifest-v09、active.json、共享scripts/data/scenes或根project.godot，没有Git提交。old-assets-v01.json 为只读核对记录；制作人可在并行任务中自行改动程序。最终资源SHA清单见 delivery-filelist-v01.json。本次为资源交付，主游戏接入、跟随/巡逻AI和实际移动观感由制作人验收。
