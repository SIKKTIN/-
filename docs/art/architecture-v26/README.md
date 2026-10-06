# A26 同源墙体瓦片组件

本轮完整替换食堂横墙、纵墙及转角的绘制来源。全部14个组件共用 art/architecture/v26/wall_tiles_master_v26.png，纹理路径/hash一致；没有独立生成另一种横墙、竖墙或转角图。

内置imagegen生成母版，提示词和内置输出来源见 prompt.json。生产PNG原样复制，1536×1024 RGB，SHA256 6848abbe6268ab75df0d31f97093e3500bf53cdb8f4aeec2c8c7c75e163504aa。没有后期像素修改，A24/A25已冻结交付hash保持。

母版三个源区：coping石面[0,0,1536,196]，plaster墙面[0,208,1536,496]，plinth墙脚[0,708,1536,312]。顶/侧/门柱/门楣全部采同coping，侧面仅照明乘0.78，柱立面乘0.84。正面及末端面共用同plaster/plinth。

| 组件 | 世界尺寸 |
|---|---|
| 横墙 | 128×114 |
| 纵顶 | 24×128或20×128，左右朝向分别定义 |
| 左右L | 80×150，24或20厚 |
| 南端面 | 24×90或20×90，仅末端一次 |
| 门柱 | 32×121.5 |
| 压顶 | 128×24 |
| 门楣 | 180×31.5 |

具体14个ID与assembly_patches见 art/architecture/v26/manifest.json schema2；详细消费契约 interface.json。所有asset.region均整幅[0,0,1536,1024]，patch.source是原图绝对坐标，不做第二次偏移。目标rect全正尺寸，纵向仅transpose交换UV轴。

128是材质采样周期、64是基础网格。H从共同起点采样；L后H接phase80，L150后V接phase22。右角及内隔墙位置偏离周期时将共同位置差加入源U，母版X重复，末块几何/UV裁剪。右向组件直接定义右侧几何，sourceU仍沿跑向正增长，避免把光照和石纹一起反转。

20厚隔墙专属组件：纵截面20=16.6667顶+3.3333侧，cross sourceV裁5/6；横臂仍80长、纹理跑向周期128，前墙只从x20开始。不能将整个L按20/24缩窄而把横石粒度一起压小。

北H基线1261.5时，H顶1147.5、立面起点1171.5、基脚1227.5、L末1297.5；柱top1140/front1171.5。门洞180、90立面及地图物理外墙24/内墙20由制作人保持，组件不改变碰撞或门禁规则。

编辑器增量 art/editor/v06/manifest.json，14个128×128 MeshTexture图标直接采用母版和同一套2D几何/UV，没有烘焙第二套生产纹理。MeshTexture要求二维顶点，参见[Godot文档](https://docs.godotengine.org/en/stable/classes/class_meshtexture.html#class-meshtexture-property-mesh)；绘图时还需持有资源引用。资源加载成功不是绘制证明，最终GPU长横/长纵/左右角及14实际可见图标见 native-preview.png、native-preview.json、native-icons-visible.json，RTX4050 Forward+，stderr空。

实际游戏完整/真实2倍近景及编辑器组件摆放由制作人提供，经主美亲眼核对后冻结在runtime；来源、hash、结论见 p56-visual-evidence.json、p56-visual-review.md。以真实视觉判断材质统一，不用加载成功替代。本母材较柔和，窄暗侧仍可辨，金属门主体清楚；纹理周期会重复，不宣称无限随机。
