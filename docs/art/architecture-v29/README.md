# A29 同套石墙向下 T 连接积木

厨房隔墙与横墙接点改用完整T：横向左右贯通，中央支墙向下。新图专门绘制，顶面、分支节点及两处内凹倒角连续，不是两个旧L拼合。原V24横墙与门柱、V27直纵顶、V28外围L保留。

## 资产与制作

入口 art/architecture/v29/manifest.json，注册 cafeteria_t_20_v29（132×80，stem x56宽20）、cafeteria_t_v29（136×80，stem x56宽24）。共同源 cafeteria_t_master_v29.png，1635×962 RGBA，SHA c61e00b01c3d0a0b22a04cb14198b88e898a21593729161ffd5f1999b1ab08a3。内置 imagegen 按V24/V28材质参考新生成，原样复制未涂改；提示见 prompt.json。

art/editor/v09/manifest.json 与两个独立2D MeshTexture图标显示 T，本轮不修改旧图标/PNG或共享scripts/data/Git。主美候选native-preview.png/native-detail.png是原生Forward+实际试拼，图标GPU可见，stderr0，最终游戏审美验收另行进行。

## 端口与采样

北横臂深24，左右出臂各56，纵臂至y80。原图横臂 y117..338，中央stem源x700..936；y338..382保存两个小内凹肩部，y382..847为直段。七段源区只是将同一张已画好的连续T注册到两种墙厚，不能用旧L替换源区，也不能整张PNG移动U或循环采样。

两处装饰内角肩部各4×4，位于y24..28，真实石体三角和透明三角均保留；物理纵墙仍20/24。左右下内空保持alpha0，不得用矩形包围盒阴影填满。沿用V25安全alpha shader。

原横翼起点Y1140，T起点Y1146.48（底线−115.02）。厨房左T20 offset[114,6.48]，右[754,6.48]，均132×80；对应stem世界x1270、1910。横顶cutout为[114,0,132,30.48]和[754,0,132,30.48]，只清旧压顶，原横墙立面仅遮stem20，左右墙身沿原middle绘制。两端横臂以石缝接原横顶，南stem y80 接原V27直纵顶，tile_origin/render_start=角起点+80，保持period123.1413612565。

左T地图mirror_x=false，右T地图mirror_x=true以对应V27右侧纵墙深边。T左右臂各56、stem居中，所以镜像后stem仍从x56开始；不要在patch内再次镜像。两种编辑图标展示默认T形，不依赖另外生成的右向材质。

render_mode 为 architecture_junction_t，分类/实际放置/组合空区验证由制作人P62维护。不能把新T图采作整段墙身，不能删去横臂一侧让T退化为L。

## 验收

先交完整候选、精确interface与原生试拼，再看实际厨房两个T点、两尺寸和编辑器独立组件。资源加载或测试数量不代替美术判断；完整横臂与中央分支必须在actual中可辨，原材质和规则保留。
