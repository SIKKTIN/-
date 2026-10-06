# P52 验证记录

2026-10-06，Godot 4.7.2，Windows原生CLI，制作人自测和单独验收。不是手机实机或真人体验记录。

## 结果

- `p52-access-headless-1200.json`、`p52-access-native-1200.json`、`p52-access-native-960.json`：各73项通过。
- `p52-editor-headless-1280.json`：71项通过；`p52-editor-native-1280.json`、`p52-editor-native-960.json`：各76项通过。
- `p52-rollcall-headless.json`：50项通过。由已有P45查房回归复用，更新已确认的“全厂区警戒”文案和R04捕获后进入禁闭的预期，不弱化实际增援捕获断言。
- 共492次程序检查结果通过；同一行为在不同尺寸/入口重复检查，不能理解成492项独立玩法。
- A17独立验收9状态及27交付文件SHA；A19独立验收4个世界状态、13个48/64编辑器图标及61交付文件SHA，无不一致。真实接入截图已查看。
- CLI headless编辑器导入完成，无脚本/资源报错；保留已有嵌套示例project.godot目录的导入提示。制作人没有关闭或保存用户已有编辑器窗口。

## 核心覆盖

食堂11:59.99关闭、12:00打开、13:59.99保持开放、14:00关闭、次日午间再开；真实碰撞和寻路都遵守门状态，未改变时不反复重建导航。三人实际从寝室去取餐并到用餐点；收餐先清理日常/动作并疏散伙伴和NPC，门外落点可站立且不重叠。

三人捕获进不同房间、范围限制、自救拒绝、两小时释放、跨午夜计时、已登记禁闭不作为查房缺员、不能跳过夜晚。外侧撬门分段累积/切人不打断、救援不改变主门、再次捕获重锁、钥匙及工具实际拾取/消耗/解救、重开清理状态。R01–R03仍捕获回原出生点。

新R04工作/自由活动/就餐/巡逻路线可达；白天非戒备不抓人。受控演练验证两人聊天牵制门岗、第三人撬主门并通过，20:00门岗下班后其余两人通过，三人结算成功。该演练只推进订单/技能，不等于在完整警报追捕AI下无人操控保证通关。

地图灯位优先采用17个重排灯位，均在界内；午夜禁闭区启用灯光。原生两尺寸查看日间食堂/禁闭与夜间禁闭，并检查主美联系表。

## 编辑器覆盖

复用P51真实输入回归：四地图格式、图标卡选择放置、隐藏/锁定/独显、对象筛选、墙刷、拖动与吸附、碰撞属性、商人办公点/匹配营业路径同步、其他工作/休息点保留、巡逻点排序、撤销、字段提交、未知字段保留、临时地图安全保存与备份、外部修改拒绝、地图切换未保存保护。原R04哈希在各QA运行前后保持一致，临时p52_qa.json及备份清理。

新增管制门/禁闭范围进入对象列表；门几何同步视觉与入口且可撤销。实际SpinBox调整开放分钟/禁闭总时长并撤销；关押/释放字段可见；错误门引用、开放分钟倒序、错误禁闭对象类型均拒绝。新增27项摆设都有配套图标，全部资源路径严格与manifest一致。Native版从真实工具栏启动未保存草稿游戏再返回，不保存R04且保留草稿历史。

## 截图和命令

`p52-1200/960-canteen-closed.png`、`canteen-open.png`、`confinement.png`、`confinement-night.png`、`escape.png`。

`p52-editor-1280/960-overview.png`、`gate-properties.png`、`scene/layout/patrol/dormitory.png`。

```powershell
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script qa/p52_access_confinement.gd
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path . --script qa/p52_access_confinement.gd -- 1200
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path . --script qa/p52_access_confinement.gd -- 960
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script qa/p52_editor_regression.gd
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path . --script qa/p52_editor_regression.gd -- 1280
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --path . --script qa/p52_editor_regression.gd -- 960
& 'E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script qa/p52_rollcall_regression.gd
```

## GameCreator

A17反馈`a17-final-v17-20261006`、A19反馈`a19-final-v19-20261006`均由制作人分别验收。正式R04变更`p52-r04-design-20261006`经baseline/validate/submit/list/preview/apply应用，原R04地图ID与56个历史对象ID保留，当前142个空间/规则对象。总览上限30行/40列，使用80世界单位一格（29×36）；不缩小Godot世界几何。其余三个地图未改，用户project.godot既有改动未纳入交付。
