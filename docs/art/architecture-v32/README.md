# A32 批准 C 圆弧同高石墙

批准依据是 approved-concept-c.png。内置 imagegen 按这张图提取/重构一张透明 T 墙顶加长纵墙母图，原输出逐字节复制。接口和整段 V 共用新 PNG，避免前轮正面柱石接旧窄顶面/侧影；旧 V24–31 全冻结不改。

入口 `art/architecture/v32/manifest.json`，六件：T20/T24、V左20/右20/左24/右24；v12六独立MeshTexture图标已GPU实际可见。T132/136×80、stemx56、逻辑北深24，有效北横深21。两小凹圆弧从北横阴影内部开始，经y21..24两侧8×3的同源接触带续入窄stem，横暗边停止于内角。

新V源窗口[470,298,88,278]，Y世界比例24/88，周期75.81818181818181，tile高151.63636363636363。T主stem从local24至80，56长源Y298..503.33333333333337，下段origin仍local24/world1170.48，clip80/world1226.48处phase56，必须续相位。20只压缩X截面，Y比例/周期与24相同。左default，右完整T mirror一次，V_r仅镜像X截面，不反向Y。

厨房必须完整绘制全部9patch，取消reuse_cap只stem。原H局部cap_cutouts拟[114,0,132,27.48]和[754,0,132,27.48]，保留其底沿与墙身，圆弧contact覆盖中央旧跨root暗线，物理stem20范围自local21切墙身；外围L仍30.48。两圆弧、两外端与原H底沿必须看实际图确认，不用源检查取代审美。完整长V同步换V32，原front/endface保留为方向不同的端面。

源RGBA有低alpha外缘，继承safe_edges_v25处理，真实两侧下内空alpha0；原生试拼未出现整块底板或光晕。主美只写新素材/图标/docs，shared/data/Git由制作人接入。初轮actual发现母图横条两外端黑边/小端帽，使其像贴板，未通过。仅修正新PNG的UV：外横臂取内部source116..426与602..910，弧头列426..470和558..602保持8world宽与contact一致，移除终止墙帽并减少密砖缝。sourcePNG/root/长V/phase/尺寸均不改，9patch完整绘制。修正版candidate停止改动，修正版实际完整左右game/editor、T/V独立实绘与分类已复核，圆弧一体同高方向符合批准C。按p65-visual-review.md记录细部差别及技术观察，实际证据原样复制后冻结交独立审。


