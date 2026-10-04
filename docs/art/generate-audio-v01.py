"""Original lightweight procedural cues; writes only the assigned audio folder."""
from pathlib import Path
import math,random,struct,wave,json,hashlib
ROOT=Path('E:/Project/Godot/这次怎么逃')
OUT=ROOT/'audio';OUT.mkdir(parents=True,exist_ok=True)
RATE=44100
specs=[
 ('chat_loop',.80,True,'action_state becomes chatting','chat action ends/moves/captured/escaped/paused'),
 ('lockpick_loop',.80,True,'lockpick action active','lockpick action ends/moves/captured/escaped/paused'),
 ('crate_move_loop',.60,True,'crate actual displacement > 0 with pushing actor','crate stationary/push ends/paused'),
 ('detected',.24,False,'guard enters chasing from a detection','one shot, no warning or delayed state transition'),
 ('captured',.32,False,'actual capture/return event','one shot per actual capture'),
 ('cancelled',.16,False,'actual action cancelled with visible reason','one shot'),
 ('door_open',.22,False,'door actually becomes open','one shot'),
 ('escaped',.32,False,'one actor becomes escaped','one shot, no global win assertion'),
 ('complete',.64,False,'all actors escaped','one shot')]
rows=[]
def sin(f,t):return math.sin(2*math.pi*f*t)
for index,(name,duration,loop,start,stop) in enumerate(specs):
 filename=name+'_v01.wav';dest=OUT/filename
 if dest.exists():raise RuntimeError('Existing asset: '+filename)
 rng=random.Random(137+index);values=[];filtered=0.
 for n in range(round(duration*RATE)):
  t=n/RATE;edge=min(1.,t/.006,(duration-t)/.012);edge=max(0.,edge)
  if name=='chat_loop':
   beat=t%.20;env=math.sin(math.pi*min(1.,beat/.12))**2 if beat<.12 else 0.
   pitch=[210,265,235,290][min(3,int(t/.20))]
   v=env*(sin(pitch,t)+.25*sin(pitch*2,t))*.08
  elif name=='lockpick_loop':
   beat=t%.20;env=math.exp(-beat*65)*min(1,beat/.003)
   v=env*(sin(1550,t)+.35*sin(2310,t))*.09
  elif name=='crate_move_loop':
   filtered=.90*filtered+.10*rng.uniform(-1,1)
   v=filtered*.35*math.sin(math.pi*t/duration)**2
  elif name=='detected':
   v=.10*sin(420+700*t/duration,t)*math.sin(math.pi*t/duration)
  elif name=='captured':
   v=.10*sin(460-260*t/duration,t)*math.sin(math.pi*t/duration)
  elif name=='cancelled':
   v=.07*(sin(270,t)+.2*rng.uniform(-1,1))*math.exp(-t*24)
  elif name=='door_open':
   v=.07*(sin(180,t)+.3*sin(880,t))*math.exp(-t*18)
  elif name=='escaped':
   f=523.25 if t<.16 else 659.25
   local=t%.16;v=.10*sin(f,t)*math.sin(math.pi*local/.16)**2
  else:
   f=[523.25,659.25,783.99,1046.5][min(3,int(t/.16))]
   local=t%.16;v=.09*(sin(f,t)+.15*sin(f*2,t))*math.sin(math.pi*local/.16)**2
  values.append(int(max(-.16,min(.16,v*edge))*32767))
 values[0]=values[-1]=0
 payload=struct.pack('<'+'h'*len(values),*values)
 with wave.open(str(dest),'wb') as wav:
  wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(RATE);wav.writeframes(payload)
 peak=max(abs(x) for x in values)/32767
 rows.append(dict(id=name,texture=None,file='res://audio/'+filename,sample_rate=RATE,channels=1,bits=16,duration_seconds=len(values)/RATE,loop=loop,start_on=start,stop_on=stop,peak_dbfs=round(20*math.log10(peak),2),first_sample=values[0],last_sample=values[-1],source='Original deterministic mathematical synthesis by project art director',license='Project-owned original synthesis; no samples, voices or third-party audio',sha256=hashlib.sha256(dest.read_bytes()).hexdigest()))
(OUT/'manifest.json').write_text(json.dumps(dict(schema=1,cues=rows,loop_policy='only while corresponding actual action runs; pause/stop immediately; do not infer gameplay from audio'),ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(cues=len(rows),format='44.1kHz mono PCM16',max_peak_dbfs=max(r['peak_dbfs'] for r in rows))))
