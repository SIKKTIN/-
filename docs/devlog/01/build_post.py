from pathlib import Path
import html
import json
import shutil
import zipfile

source = Path(__file__).resolve().parent
destination = Path.home() / 'Documents' / 'ChatGPT' / 'Taptap' / '\u76d1\u72f1\u98ce\u4e91_\u5f00\u53d1\u65e5\u5fd701'
destination.mkdir(parents=True, exist_ok=True)
(destination / 'images').mkdir(exist_ok=True)
data = json.loads((source / 'article.json').read_text(encoding='utf-8'))
for picture in (source / 'images').glob('*.png'):
    shutil.copy2(picture, destination / 'images' / picture.name)

escape = html.escape
paragraphs = lambda items: ''.join('<p>' + escape(item) + '</p>' for item in items)
content = paragraphs(data['intro'])
text = [data['title'], '', *data['intro']]
for index, section in enumerate(data['sections'], 1):
    content += '<section><h2>' + escape(section['heading']) + '</h2>' + paragraphs(section['paragraphs'])
    content += '<figure><img src="images/' + section['image'] + '" alt="' + escape(section['caption']) + '"><figcaption>' + escape(section['caption']) + '</figcaption></figure></section>'
    text.extend(['', section['heading'], *section['paragraphs'], '\u3010\u63d2\u56fe%d\uff1aimages/%s\u3011' % (index, section['image']), section['caption']])
content += '<section><h2>' + escape(data['closing_heading']) + '</h2>' + paragraphs(data['closing']) + '</section>'
text.extend(['', data['closing_heading'], *data['closing'], '', data['footer']])

document = '''<!doctype html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>''' + escape(data['title']) + '''</title><style>
*{box-sizing:border-box}body{margin:0;background:#e9e5db;color:#303b36;font-family:"Microsoft YaHei","PingFang SC",sans-serif}main{max-width:900px;margin:32px auto;background:#fbf9f3;box-shadow:0 8px 40px #263b3312;border-radius:12px;overflow:hidden}.cover{display:block;width:100%;height:auto}article{padding:36px 54px 48px}.meta{font-size:13px;color:#7d806e;letter-spacing:1px}.meta span{background:#e6ece5;color:#35685f;padding:5px 9px;border-radius:4px;margin-left:12px}h1{font-size:29px;line-height:1.6;color:#223e38;margin:18px 0 28px;letter-spacing:.4px}h2{font-size:23px;line-height:1.5;margin:34px 0 18px;color:#2e6257}p{font-size:17px;line-height:2;margin:0 0 18px;text-align:justify}figure{margin:24px -16px 30px}figure img{display:block;width:100%;border-radius:6px;border:1px solid #d6d6c8}figcaption{font-size:13px;line-height:1.7;text-align:center;color:#777c70;margin:10px 12px 0}.footer{border-top:1px solid #dfe0d4;padding-top:18px;margin-top:28px;font-size:13px;line-height:1.8;color:#777c70}@media(max-width:600px){main{margin:0;border-radius:0;box-shadow:none}article{padding:24px 22px 32px}h1{font-size:24px}h2{font-size:21px}p{font-size:16px}figure{margin-left:-10px;margin-right:-10px}}@media print{body{background:white}main{margin:0;box-shadow:none;max-width:none}article{padding:24px}figure{break-inside:avoid}}
</style></head><body><main><img class="cover" src="images/00-cover.png" alt="\u76d1\u72f1\u98ce\u4e91 \u5f00\u53d1\u65e5\u5fd701"><article><div class="meta">''' + data['date'] + '''<span>\u5f00\u53d1\u65e5\u5fd7 01 \u00b7 \u5f00\u53d1\u4e2d</span></div><h1>''' + escape(data['title']) + '</h1>' + content + '<div class="footer">' + escape(data['footer']) + '</div></article></main></body></html>'
(destination / 'article.html').write_text(document, encoding='utf-8')
(destination / '\u53d1\u5e03\u6b63\u6587.txt').write_text('\n\n'.join(text), encoding='utf-8-sig')
instructions = '\u6807\u9898\uff1a' + data['title'] + '\n\n\u5c01\u9762\uff1aimages/00-cover.png\n\u6b63\u6587\uff1a\u53d1\u5e03\u6b63\u6587.txt\n\u56fe\u6587\u9884\u89c8\uff1aarticle.html\n\u6b63\u6587\u63d2\u56fe\uff1a\u6309 01\u300102\u300103\u300104 \u987a\u5e8f\uff0c\u653e\u5230\u6b63\u6587\u6807\u8bb0\u4f4d\u7f6e\u3002\n\n\u6b63\u6587\u56db\u5f20\u56fe\u5747\u4e3aGodot\u5f00\u53d1\u7248\u5b9e\u673a\u622a\u56fe\uff1b\u80cc\u5305\u56fe\u4e3a\u7269\u54c1\u5c55\u793a\u573a\u666f\u3002\n\u5c01\u9762\u4f7f\u7528\u5185\u7f6e image_gen \u5de5\u5177\uff0c\u4ee5\u8f66\u95f4\u5b9e\u673a\u56fe\u4e3a\u53c2\u8003\u5236\u4f5c\uff0c\u662f\u5ba3\u4f20\u6392\u7248\u56fe\uff0c\u4e0d\u4ee3\u8868\u6e38\u620f\u5185\u754c\u9762\u3002\n\u5c01\u9762\u751f\u6210\u63d0\u793a\u8bcd\uff1a\u5c01\u9762\u63d0\u793a\u8bcd.txt\u3002\n\n\u672c\u7d20\u6750\u5305\u4ec5\u51c6\u5907\u4e86\u53d1\u5e03\u5185\u5bb9\uff0c\u5c1a\u672a\u53d1\u5e03\u5230\u4efb\u4f55\u5e73\u53f0\u3002\n'
(destination / '\u53d1\u5e03\u8bf4\u660e.txt').write_text(instructions, encoding='utf-8-sig')
if (source / 'cover-prompt.txt').exists():
    shutil.copy2(source / 'cover-prompt.txt', destination / '\u5c01\u9762\u63d0\u793a\u8bcd.txt')
archive = destination.parent / (destination.name + '.zip')
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as package:
    for file in sorted(destination.rglob('*')):
        if file.is_file(): package.write(file, str(Path(destination.name) / file.relative_to(destination)))
print(json.dumps({'destination':str(destination),'archive':str(archive),'pictures':len(list((destination/'images').glob('*.png'))),'body_characters':sum(len(p) for p in data['intro']+data['closing'])+sum(len(p) for s in data['sections'] for p in s['paragraphs'])}, ensure_ascii=True))
