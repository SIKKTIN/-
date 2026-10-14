"""Guarded atomic patching for files held by live Godot editor watchers."""
from register_reading_chess_roofs import ROOT, sha
import os,tempfile
def patch(relative,pairs):
    path=ROOT/relative;digest=sha(path);text=path.read_text(encoding='utf-8')
    for old,new in pairs:
        if new in text:continue
        assert text.count(old)==1,(relative,old)
        text=text.replace(old,new,1)
    fd,tmp=tempfile.mkstemp(prefix=path.name+'.',suffix='.tmp',dir=path.parent)
    try:
        with os.fdopen(fd,'w',encoding='utf-8',newline='\n') as f:f.write(text)
        assert sha(path)==digest,'Source changed; retry patch against current contents.'
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)
patch('scripts/presentation/room_cover.gd',[
    ('const KIOSK_MANIFEST := "res://art/architecture/kiosk_v1/manifest.json"','const KIOSK_MANIFEST := "res://art/architecture/kiosk_v1/manifest.json"\nconst READING_CHESS_MANIFEST := "res://art/architecture/reading_chess_roofs_v1/manifest.json"'),
    ('TOOL_ROOM_MANIFEST,KIOSK_MANIFEST]:','TOOL_ROOM_MANIFEST,KIOSK_MANIFEST,READING_CHESS_MANIFEST]:'),
    ('"tool_room","warehouse"]: return str(spec.roof_style)','"tool_room","warehouse","reading","chess"]: return str(spec.roof_style)'),
    ('# The kiosk roof original already includes its vent and gutter.\n\tif style=="kiosk": return','# These fitted originals already include their roof-mounted details.\n\tif style in ["kiosk","reading","chess"]: return')])
patch('scripts/presentation/prop_catalog.gd',[
    ('\t"res://art/architecture/laundry_repair_v3/manifest.json",','\t"res://art/architecture/laundry_repair_v3/manifest.json",\n\t"res://art/architecture/reading_chess_roofs_v1/manifest.json",')])
patch('scripts/editor/map_document.gd',[
    ('"tool_room","warehouse","kiosk"]: return "屋顶样式无效。"','"tool_room","warehouse","kiosk","reading","chess"]: return "屋顶样式无效。"')])
anchor='\t\t\troofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().kiosk_roof_v1),"小卖铺 · 旧绿铁皮屋顶")'
patch('scripts/editor/map_editor.gd',[(anchor,anchor+'\n\t\t\troof_ids.append("reading")\n\t\t\troofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().roof_reading),"阅览室 · 旧砖红瓦屋顶")\n\t\t\troof_ids.append("chess")\n\t\t\troofs.add_icon_item(preload("res://scripts/presentation/world_texture.gd").load_asset(preload("res://scripts/presentation/room_cover.gd").definitions().roof_chess),"棋牌室 · 旧灰瓦屋顶")')])
print('Connected fitted roofs, preserved runtime caching, and exposed styles in editor.')
