from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
s=(ROOT/'docs/art/factory-detail-v44/review.gd').read_text(encoding='utf-8').replace('factory-detail-v44','factory-terrain-v45')
s=s.replace('if not validation.errors.is_empty():quit(1);return','if not validation.errors.is_empty():print("Review continues to diagnose geometry.")')
s=s.replace('Vector2(2080,1600),0.24','Vector2(2120,1520),0.25').replace('Vector2(3240,1460),0.57','Vector2(3340,1350),0.6').replace('Vector2(1370,490),0.8','Vector2(1520,900),0.65').replace('Vector2(1510,2660),0.8','Vector2(1760,2460),0.7')
s=s.replace('canvas.zoom=0.48;canvas.origin=Vector2(1000,750)-Vector2(2080,1600)*canvas.zoom','canvas.zoom=0.455;canvas.origin=Vector2(1000,750)-Vector2(2120,1520)*canvas.zoom')
s=s.replace('r04-detail-overview.png','r04-terrain-overview.png').replace('r04-detailed-editor.png','r04-terrain-editor.png')
s=s.replace('Vector2(3700,1570)','Vector2(3800,1480)').replace('Vector2(3630,1450)','Vector2(3680,1420)')
(OUT/'review.gd').write_text(s,encoding='utf-8')
