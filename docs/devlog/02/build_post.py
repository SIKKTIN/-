"""Build an offline illustrated post and upload bundle without publishing it."""
from pathlib import Path
import hashlib
import html
import json
import shutil
import zipfile

source = Path(__file__).resolve().parent
destination = Path.home() / "Documents" / "ChatGPT" / "Taptap" / "监狱风云_开发日志02"
destination.mkdir(parents=True, exist_ok=True)
(destination / "images").mkdir(exist_ok=True)
data = json.loads((source / "article.json").read_text(encoding="utf-8"))
escape = html.escape
paragraphs = lambda items: "".join("<p>" + escape(item) + "</p>" for item in items)
content = paragraphs(data["intro"])
text = [data["title"], "", *data["intro"]]
pictures = ["00-cover.png"]
index = 0
for section in data["sections"]:
    content += "<section><h2>" + escape(section["heading"]) + "</h2>" + paragraphs(section["paragraphs"])
    text.extend(["", section["heading"], *section["paragraphs"]])
    figures = [{"image": section["image"], "caption": section["caption"]}] + section.get("extra_images", [])
    for figure in figures:
        index += 1
        filename = figure["image"]
        assert Path(filename).name == filename
        pictures.append(filename)
        content += '<figure><a href="images/' + filename + '"><img src="images/' + filename + '" alt="' + escape(figure["caption"]) + '"></a><figcaption>' + escape(figure["caption"]) + '</figcaption></figure>'
        text.extend([f"【插图{index}：images/{filename}】", figure["caption"]])
    content += "</section>"
content += "<section><h2>" + escape(data["closing_heading"]) + "</h2>" + paragraphs(data["closing"]) + "</section>"
text.extend(["", data["closing_heading"], *data["closing"], "", data["footer"]])

style = """
*{box-sizing:border-box}body{margin:0;background:#e9e5db;color:#303b36;font-family:"Microsoft YaHei","PingFang SC",sans-serif}main{max-width:940px;margin:32px auto;background:#fbf9f3;box-shadow:0 8px 40px #263b3312;border-radius:12px;overflow:hidden}.cover{display:block;width:100%;height:auto}article{padding:36px 54px 48px}.meta{font-size:13px;color:#7d806e;letter-spacing:1px}.meta span{background:#e6ece5;color:#35685f;padding:5px 9px;border-radius:4px;margin-left:12px}h1{font-size:29px;line-height:1.6;color:#223e38;margin:18px 0 28px;letter-spacing:.4px}h2{font-size:23px;line-height:1.5;margin:34px 0 18px;color:#2e6257}p{font-size:17px;line-height:2;margin:0 0 18px;text-align:justify}figure{margin:24px -16px 30px}figure img{display:block;width:100%;height:auto;border-radius:6px;border:1px solid #d6d6c8}figcaption{font-size:13px;line-height:1.7;text-align:center;color:#777c70;margin:10px 12px 0}.footer{border-top:1px solid #dfe0d4;padding-top:18px;margin-top:28px;font-size:13px;line-height:1.8;color:#777c70}@media(max-width:600px){main{margin:0;border-radius:0;box-shadow:none}article{padding:24px 22px 32px}h1{font-size:24px}h2{font-size:21px}p{font-size:16px}figure{margin-left:-10px;margin-right:-10px}}@media print{body{background:white}main{margin:0;box-shadow:none;max-width:none}article{padding:24px}figure{break-inside:avoid}}
"""
document = '<!doctype html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>' + escape(data["title"]) + '</title><style>' + style + '</style></head><body><main><img class="cover" src="images/00-cover.png" alt="监狱风云 开发日志02"><article><div class="meta">' + escape(data["date"]) + '<span>开发日志 02 · 开发中</span></div><h1>' + escape(data["title"]) + '</h1>' + content + '<div class="footer">' + escape(data["footer"]) + '</div></article></main></body></html>'
(destination / "article.html").write_text(document, encoding="utf-8")
(destination / "发布正文.txt").write_text("\n\n".join(text), encoding="utf-8-sig")
for filename in pictures:
    shutil.copy2(source / "images" / filename, destination / "images" / filename)
shutil.copy2(source / "cover-prompt.txt", destination / "封面提示词.txt")
instructions = "标题：" + data["title"] + "\n\n封面：images/00-cover.png\n正文：发布正文.txt\n图文预览：article.html\n\n正文插图顺序：\n"
instructions += "\n".join(f"{i}. images/{filename}" for i, filename in enumerate(pictures[1:], 1))
instructions += "\n\n按正文中的插图标记放置图片。地图总览在预览中可点击打开原图。\n封面使用内置 image_gen，以第一篇封面为系列风格参考、当前地图总览为场景来源。封面是宣传排版图，提示词见封面提示词.txt。\n正文前四张为2026-10-14从当前Godot项目截图，暂时隐藏HUD和看守视野提示，并移动角色和展示镜头；没有重绘场景。总览镜头拉远，近景保持0.8镜头缩放。\n开始界面和设置图来自当天原生菜单功能检查；开始界面的背景为插画，按钮与设置为真实界面。继续游戏目前为预留入口。\n\n本素材包只准备发布内容，尚未发布到任何平台。\n"
(destination / "发布说明.txt").write_text(instructions, encoding="utf-8-sig")
manifest = {"date": data["date"], "title": data["title"], "files": {}}
export_files = [destination / filename for filename in ["article.html", "发布正文.txt", "发布说明.txt", "封面提示词.txt"]]
export_files += [destination / "images" / filename for filename in pictures]
for file in export_files:
    manifest["files"][file.relative_to(destination).as_posix()] = {"bytes": file.stat().st_size, "sha256": hashlib.sha256(file.read_bytes()).hexdigest()}
(destination / "素材清单.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
export_files.append(destination / "素材清单.json")
archive = destination.parent / (destination.name + ".zip")
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as package:
    for file in sorted(export_files):
        package.write(file, str(Path(destination.name) / file.relative_to(destination)))
print(json.dumps({"destination": str(destination), "archive": str(archive), "pictures": len(pictures), "body_characters": sum(len(p) for p in data["intro"] + data["closing"]) + sum(len(p) for s in data["sections"] for p in s["paragraphs"])}, ensure_ascii=True))
