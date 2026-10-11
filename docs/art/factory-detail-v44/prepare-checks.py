from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
s=(ROOT/'docs/art/factory-expansion-v43/verify.gd').read_text(encoding='utf-8')
s=s.replace('res://docs/art/factory-expansion-v43/','res://docs/art/factory-detail-v44/').replace('res://art/props/factory_v43/manifest.json','res://art/props/factory_v44/manifest.json')
s=s.replace('check("all new walls align20",range(old.walls.size(),doc.data.walls.size()).all(func(i):return doc.data.walls[i].all(func(n):return is_zero_approx(fmod(float(n),20)))))','check("wall tile geometry preserved",old.walls==doc.data.walls and old.architecture==doc.data.architecture)')
s=s.replace('check("three independent editable exits"','check("ground dressing retained in document",doc.data.get("ground_details",[]).size()>90)\n\tcheck("three independent editable exits"')
(OUT/'verify.gd').write_text(s,encoding='utf-8')
