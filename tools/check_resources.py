"""Audit literal production dependencies without changing or deleting files."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {'.gd','.tscn','.tres','.cfg','.json'}
RESOURCE = re.compile(r'["\'](res://[^"\'\n]+)["\']')
LOAD = re.compile(r'(?:preload|load|FileAccess\.get_file_as_string)\(\s*["\'](res://[^"\'\n]+)["\']|^extends\s+["\'](res://[^"\'\n]+)["\']', re.M)

def audit():
    files = [p for folder in ['scripts','scenes','data','addons/escape_map_editor'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in TEXT_SUFFIXES]
    references, missing = {}, []
    for file in files:
        source = file.relative_to(ROOT).as_posix()
        text = file.read_text(encoding='utf-8-sig')
        for target in RESOURCE.findall(text):
            references.setdefault(target.removeprefix('res://'),set()).add(source)
        if file.suffix!='.gd':continue
        for match in LOAD.finditer(text):
            target = next(t for t in match.groups() if t)
            if any(c in target for c in ['%','*','{']):continue
            if not (ROOT/target.removeprefix('res://')).exists():
                missing.append({'source':source,'resource':target})
    unused = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT/'scripts').rglob('*.gd') if p.relative_to(ROOT).as_posix() not in references)
    return {'production_text_files':len(files),'missing_literal_loads':missing,'scripts_without_literal_references':unused,'note':'Unreferenced scripts are review candidates only; dynamic/editor entry points require manual verification.'}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    report=audit()
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return 1 if report['missing_literal_loads'] else 0

if __name__=='__main__':raise SystemExit(main())
