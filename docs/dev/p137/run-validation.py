from pathlib import Path
import concurrent.futures,json,subprocess,time
root=Path(__file__).resolve().parents[3]
out=root/'docs/dev/p137/validation'
engine='E:/Godot/4.7/Godot_v4.7.2-stable_win64_console.exe'
labels=['navigation','structure','npc','player','staff','chase','tutorial','legacy','looting','quick','editor']
def run(label):
    script='res://qa/p137_navigation.gd' if label=='navigation' else 'res://docs/dev/p137/validation/'+label+'.gd'
    args=[engine,'--headless','--path',str(root),'--script',script]
    start=time.monotonic()
    with (out/(label+'.out')).open('w',encoding='utf-8') as stdout,(out/(label+'.err')).open('w',encoding='utf-8') as stderr:
        try:
            p=subprocess.run(args,cwd=root,stdout=stdout,stderr=stderr,timeout=240,creationflags=subprocess.CREATE_NO_WINDOW)
            return {'label':label,'exit_code':p.returncode,'seconds':round(time.monotonic()-start,2),'error_bytes':(out/(label+'.err')).stat().st_size}
        except subprocess.TimeoutExpired:
            return {'label':label,'timeout':True,'seconds':round(time.monotonic()-start,2)}
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    for future in concurrent.futures.as_completed([pool.submit(run,label) for label in labels]):
        result=future.result();results.append(result)
        (out/'results.json').write_text(json.dumps(results,indent=2),'utf-8')
        print(json.dumps(result),flush=True)
print('Targeted validation finished.',flush=True)
