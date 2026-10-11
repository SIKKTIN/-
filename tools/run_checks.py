"""Run the current native Godot regression suite and retain one clear report."""
import argparse
import json
import os
import shutil
import subprocess
import time
from pathlib import Path
from check_resources import audit

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',default=os.environ.get('GODOT_BINARY') or shutil.which('godot') or shutil.which('godot4'))
    parser.add_argument('--only',nargs='+',help='Suite IDs from qa/regression_suite.json')
    parser.add_argument('--output',type=Path,default=ROOT/'docs/tests/current-regressions')
    args=parser.parse_args()
    if not args.godot:parser.error('Provide --godot or set GODOT_BINARY to the Godot executable.')
    suite=json.loads((ROOT/'qa/regression_suite.json').read_text(encoding='utf-8'))['checks']
    if args.only and set(args.only)-{c['id'] for c in suite}:parser.error('Unknown suite ID.')
    chosen=[c for c in suite if not args.only or c['id'] in args.only]
    args.output.mkdir(parents=True,exist_ok=True)
    resources=audit()
    results=[]
    for case in chosen:
        log=args.output/(case['id']+'.log')
        start=time.monotonic()
        report_file=ROOT/case['report']
        old_mtime=report_file.stat().st_mtime_ns if report_file.exists() else 0
        env=os.environ.copy()
        env['ESCAPE_DEV_SETTINGS_PATH']='user://regression-'+case['id']+'.cfg'
        with log.open('w',encoding='utf-8') as stdout:
            try:
                proc=subprocess.run([args.godot,'--headless','--path',str(ROOT),'--script','res://'+case['script']],cwd=ROOT,stdout=stdout,stderr=subprocess.STDOUT,env=env,timeout=case['timeout'])
                code=proc.returncode
            except subprocess.TimeoutExpired:code=124
        errors=any(token in log.read_text(encoding='utf-8') for token in ['SCRIPT ERROR:','ERROR:'])
        fresh=report_file.exists() and report_file.stat().st_mtime_ns>old_mtime
        report=json.loads(report_file.read_text(encoding='utf-8-sig')) if fresh else {}
        failed=report.get('failed',[])
        if fresh:shutil.copyfile(report_file,args.output/(case['id']+'.json'))
        ok=code==0 and not errors and fresh and not failed
        results.append(dict(id=case['id'],ok=ok,exit_code=code,seconds=round(time.monotonic()-start,2),checks=len(report.get('checks',{})),failed=failed,fresh_report=fresh,engine_errors=errors))
        print(f"{case['id']}: {'PASS' if ok else 'FAIL'} ({results[-1]['checks']} checks)",flush=True)
    result=dict(resources=resources,results=results,total_checks=sum(c['checks'] for c in results),passed=not resources['missing_literal_loads'] and all(c['ok'] for c in results))
    (args.output/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return 0 if result['passed'] else 1

if __name__=='__main__':raise SystemExit(main())
