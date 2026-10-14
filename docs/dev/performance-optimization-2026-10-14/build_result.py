from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
def read(name):
    return json.loads((out / name).read_text(encoding="utf-8"))
profile = read("forward_plus.json")
day = read("full-day-final.json")
startup = read("startup.json")
chase = read("chase.json")
bake = read("bake.json")
pack = read("pack-smoke.json")
pack_loading = read("pack-loading.json")
spikes = [s for s in day["spikes_over33ms"] if s["minute"] > 481]
cases = profile["cases"]
rows = "\n".join(
    f"  {name}: 整帧均值{case['frame_ms']['mean']:.2f} / P95 {case['frame_ms']['p95']:.2f} ms；主循环均值{case['game_script_ms']['mean']:.2f} ms"
    for name, case in cases.items()
    if name in ["dorm_idle", "tutorial_escort", "workshop_interior", "afternoon_work", "night_dorm", "cap60_running", "uncapped_running"]
)
hashes = {
    str(p.relative_to(root)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
    for p in root.joinpath("scripts").rglob("*.gd")
}
hashes["data/rooms/r04.json"] = hashlib.sha256(root.joinpath("data/rooms/r04.json").read_bytes()).hexdigest()
(out / "delivery-hashes.json").write_text(json.dumps(hashes, ensure_ascii=False, indent=2), encoding="utf-8")
text = f"""监狱风云：性能优化实施结果
日期：2026-10-14

已接入生产代码
1. 宿舍门静态范围缓存，按地图和门几何签名失效；普通帧统一同步一次门状态。交互提示复用已查询的门。
2. 保留所有源画，预生成裁片、分档缩放和 mipmap。运行时加载独立无损 .res，相同像素共享同一资源。新图/过期缓存可回退源画。素材目录缓存按变更失效；地图重载释放查找缓存，角色和地面缓存同步重建。
3. NPC 作息路线超过预算时留到后续帧；玩家操作保持即时，待规划 NPC 保持合法作息状态。例行寻路计入看守的共享预算。未改变碰撞规则或追捕感知频率。
4. 修正夜间查寝网格：开门后的门扇身体范围并非关闭范围的子集，增量更新独立查询查寝身体索引，与完整重建一致。
5. 新增加载进度场景，主场景仍支持直接实例化/编辑器试玩。建立 Windows 导出预设，排除 docs、qa、工具脚本、原型及备份文件。

同机原生实测（1200×720，Forward+ D3D12，i5-13500HX / RTX4050 Laptop）
  原审计纹理1225.36 MiB → {profile['resources']['texture_mib']:.2f} MiB，约减少35.9%。
  当前主场景准备{profile['startup_ready_ms']/1000:.2f}秒，首帧{profile['first_frame_ms']/1000:.2f}秒；原首帧22.48–30.42秒。
  带加载界面的完整进入游戏{startup['first_game_frame_ms']/1000:.2f}秒，加载画面{startup['loading_visible_ms']/1000:.2f}秒可见。
{rows}
  正式追捕由真实感知触发：{chase['chased_frames']}帧追捕、{chase['captures']}次捕获；4项检查通过。测量窗口整帧P95 {chase['frame_ms']['p95']:.2f}ms，主循环均值{chase['script_ms']['mean']:.2f}ms。追捕本身持续时间较短，整窗还包含捕获后的巡逻，不当作持续高负载追捕成绩。
  计时从场景创建开始，不包括 Godot 进程启动；没有清操作系统缓存，不能称为严格冷启动。背景应用和资源导入影响跨轮成绩；原审计同轮缓存开关对照才是门热点的直接归因证据。

正常速度整日
  真实运行{day['wall_seconds']:.2f}秒、{day['frame_ms']['count']}帧，08:00→次日08:00，全部NPC正常模拟。
  整帧均值{day['frame_ms']['mean']:.2f}ms，P95 {day['frame_ms']['p95']:.2f}ms，P99 {day['frame_ms']['p99']:.2f}ms。
  主循环均值{day['script_ms']['mean']:.2f}ms，P95 {day['script_ms']['p95']:.2f}ms；无误抓、工作/吃饭/睡眠及点名7项通过。
  首个地图重新载入后的预热帧2686.53ms包含资源/呈现初始化，已独立记录。之后 >33ms 共{len(spikes)}帧，最长{max(s['frame_ms'] for s in spikes):.2f}ms，集中在作息切换及长路径查询。
  此整日采集在最后的NPC错帧调度和查寝索引修正之前完成。最终调度另以两日完整状态、跨午夜切换、当前原生短测验证；没有把前一轮整日数据说成最终调度重新跑过15分钟。

回归与资源检查
  124份生产/构建脚本编译通过。
  宿舍门交互90项、门几何68项、车间门48项、增量导航23项、地板编辑57项、属性布局65项、缓存/重载27项、角色资源195项、NPC两日作息15项均通过；最终相应日志无SCRIPT ERROR。
  跨作息对照：优化前4项状态检查、优化后5项（含错帧确实发生）通过。这是0.2秒步长的加速状态验证，不能替代正常速度帧率测量。拆分多NPC规划并未解决单次复杂路径耗时，暂不宣称切换长帧全部消失。
  素材构建：{bake['baked']}份请求 → {bake['unique_resources']}份独立纹理；{bake['source_files_decoded']}张源图各解码一次；0失败。构建日志的直接读PNG警告仅属离线脚本，成品运行不读取这些源图。
  六个区域在1.0和1.8缩放的源图/运行时版本配对截图已存；对象锚点和逻辑裁片范围完全一致。食堂和车间近景已人工检查，文字与桌面细节正常；不把图片差异百分比当成视觉无损承诺。
  重复R01/R03/R04重载后R04缓存数量一致，未出现持续累积；覆盖有限，不声称证明无限运行无泄漏。
  最终资源包 build/performance-check.pck：{root.joinpath('build/performance-check.pck').stat().st_size/1048576:.2f}MiB。隔离目录加载全部4张地图/检查排除项16项通过，烘焙命中{pack['baked_hits']}，回退{pack['baked_misses']}。默认加载场景再测3项通过。资源包为PCK，未安装Windows导出模板，未宣称已生成独立发布EXE。

尚未达到的目标/已有问题
  整日P99目标20ms，实测21.25ms；最终短测60帧P95目标18.5ms，实测{cases['cap60_running']['frame_ms']['p95']:.2f}ms。主要CPU热点已消除，复杂寻路和切换尖峰仍需继续优化。下一步对连通索引更新、JPS和路径平滑分项计时，先降低单次搜索，再考虑跨帧任务；不能靠延迟捕获或关NPC掩盖尖峰。
  完整P104教程测试停在“return_brief/返工说明”，29项中8项未通过。将优化前的帧调度与作息实现放进隔离QA复测，在同一地图、同一位置复现相同8项失败，因此不是本轮错帧优化引入。教程护送、实际工资、警戒恢复和20分钟用餐已经跑通；完整教程仍有原有引导通路阻塞，需要单独修复，不能声称全教程通过。
  包体保留目录中动态引用的源图和旧资产，未在依赖证据不足时删除。下一阶段≤600MiB纹理预算、Compatibility/移动端对照尚未验收，不承诺换渲染器能修复当前CPU寻路问题。

操作与复现
  下次启动项目默认进入加载场景；已运行窗口仍使用旧代码，需重新启动才能使用优化。
  编辑器/其他任务仍在修改地图，R04当前哈希与开始时不同；本轮未编辑生产地图。地板、门交互QA均验证各自不写R04；未关闭用户原有窗口，也未提交/重置已有工作。
  最终核心与地图哈希：delivery-hashes.json。
  原生性能：Godot --path 项目 --script res://qa/performance_optimization_20261014/run.gd
  正常整日：Godot --path 项目 --script res://qa/performance_optimization_20261014/full_day.gd
  原生启动/追捕：同目录 startup.gd / chase.gd。
  构建素材：Godot --headless --path 项目 --script res://scripts/tools/bake_runtime_textures.gd（应在美术更新后、导出前执行）。
  资源包：Godot --headless --path 项目 --export-pack "Windows Desktop" build/performance-check.pck
  JSON证据及最终日志在本目录；早期失败诊断日志保留，已明确标注最终通过/未通过项目。
"""
(out / "result.txt").write_text(text, encoding="utf-8")
print(out / "result.txt")
