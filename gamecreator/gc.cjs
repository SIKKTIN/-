#!/usr/bin/env node
// Terminal adapter for the same signed workflow service used by MCP.
const fs=require('node:fs'),path=require('node:path');
const {randomUUID}=require('node:crypto');
const {createClient,tools,workflowVersion,requestExample}=require('./workflow-mcp.cjs');
const commands={
 'doctor':'diagnose','delivery check':'delivery_check','status':'project_read','project read':'project_read','phase update':'phase_update',
 'tasks list':'task_list','tasks show':'task_read','tasks create':'task_create','tasks dispatch':'task_dispatch',
 'tasks plan':'task_plan_apply','tasks dependencies':'task_dependencies_update','tasks milestone':'task_milestone_update',
 'feedback submit':'feedback_submit','feedback append':'feedback_append','feedback correct':'feedback_correct','feedback status':'feedback_status',
 'reviews list':'task_list','reviews show':'feedback_status','reviews submit':'feedback_review',
 'content templates':'content_template','content template':'content_template','content baseline':'content_baseline_prepare','content validate':'content_validate','content submit':'content_submit',
 'content list':'content_scan','content preview':'content_preview','content apply':'content_apply',
 'collaboration export':'collaboration_export','art confirm':'art_style_confirm','sync preview':'engine_preview',
 'sync apply':'engine_apply','operations show':'operation_status','history':'history'
};
const aliases={task:'taskId',plan:'token','request-id':'requestId',feedback:'feedbackId',assignee:'assigneeId',reviewer:'reviewerId','schedule-revision':'scheduleRevision','evidence-version':'evidenceVersion','delivery-version':'deliveryVersion','parallel-lines':'parallelLines'};
const globals=new Set(['project','credential','file','json','help','out','select','version']);
function usage(message){throw Object.assign(new Error(message),{exitCode:2});}
function readJson(file,max=3*1024*1024){try{if(!fs.statSync(file).isFile()||fs.statSync(file).size>max)throw Error();return JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));}catch{usage('无法读取 JSON 文件（不存在、格式错误或超过大小限制）：'+file);}}
function discover(start){
 let dir=path.resolve(start);
 while(true){
  if(fs.existsSync(path.join(dir,'ai/workflow-service.json')))return dir;
  for(const file of [path.join(dir,'cli.json'),path.join(dir,'gamecreator/cli.json')])if(fs.existsSync(file)){
   const link=readJson(file,32768);if(link.schema!==1||typeof link.projectId!=='string'||!path.isAbsolute(link.projectDirectory||''))usage('CLI 项目关联无效，请重新执行工程同步');
   const endpoint=readJson(path.join(link.projectDirectory,'ai/workflow-service.json'),32768);
   if(endpoint.projectId!==link.projectId)usage('CLI 项目关联与服务项目不一致，请重新执行工程同步');
   return link.projectDirectory;
  }
  const parent=path.dirname(dir);if(parent===dir)break;dir=parent;
 }
 usage('未找到项目连接。请更新协作文件并同步工程，或用 --project 指定 GameCreator 项目目录。');
}
function help(){return `GameCreator CLI · 连接已运行的 GameCreator 工作流服务
用法：gamecreator <命令> [参数] [--project <管理项目或引擎目录>] [--credential <凭证文件>] [--json]
也可运行：node ai/gc.cjs ...（管理项目）或 node gamecreator/gc.cjs ...（引擎工程）

${Object.entries(commands).map(([c,op])=>c.padEnd(23)+' '+tools.find(t=>t.name==='gc_'+op)?.description).join('\n')}

schema <命令>             查看该命令的输入 JSON 格式，无需连接
example <命令>            生成 --file 请求样例，无需连接；先填写占位符
call <工具名> --file x.json  调用任意现有工作流操作，例如 gc_task_plan_apply
--out <新文件>            保存 UTF-8 JSON；已有文件会在请求前拒绝，失败不写结果文件
--select <字段路径,...>    仅输出选定字段，例如 result.id,result.state；不减少服务器读取
--file <JSON文件>          输入参数；content validate/submit 接收设计草稿本身
--json                    输出完整结构化结果；默认列表为摘要
--timing                  返回耗时，并在 stderr 显示本次计时；不记录正文或凭证
--credential / GAMECREATOR_CREDENTIAL_FILE  只指定本人凭证路径，不在命令中传私钥
写入前核对 revision/scheduleRevision。自动生成 requestId 并先写到 stderr；重试沿用 --request-id。
工程同步必须先 preview，再用返回的 token 执行 apply；冲突选择由调用者明确提供。
`;}
function parse(argv){
 const words=[],options={};
 for(let i=0;i<argv.length;i++){
  const a=argv[i];if(a==='-h'){options.help=true;continue;}
  if(!a.startsWith('--')){words.push(a);continue;}
  const key=a.slice(2);if(!key||Object.hasOwn(options,key))usage('重复或无效参数：'+a);
  if(['json','help','mine','unfinished','templates','timing','version'].includes(key)){options[key]=true;continue;}
  if(!argv[i+1]||argv[i+1].startsWith('--'))usage('参数缺少值：'+a);options[key]=argv[++i];
 }
 return {words,options};
}
function resolveCommand(words){
 if(words[0]==='call'){if(words.length!==2)usage('call 后需要一个工具名');return {op:words[1].replace(/^gc_/,''),rest:[]};}
 const two=words.slice(0,2).join(' '),one=words[0];
 if(commands[two])return {op:commands[two],rest:words.slice(2),command:two};
 if(commands[one])return {op:commands[one],rest:words.slice(1),command:one};
 if(words.length===1&&tools.some(t=>t.name==='gc_'+one))return {op:one,rest:[]};
 usage('未知命令；运行 gamecreator --help 查看命令，gamecreator schema <命令> 查看参数。');
}
function output(result,command,json){
 if(json)return JSON.stringify(result,null,2);
 if(command==='content list')return result.items.map(x=>[x.id,x.summary,x.error||('未解决冲突 '+x.unresolved)].join('\t')).join('\n')||'没有待处理设计提交';
 if(result?.items&&command?.endsWith('list')&&Array.isArray(result.items))return `${result.total??result.items.length} 项（本页 ${result.items.length} 项）\n`+result.items.map(t=>[t.id,t.status,t.title,t.assigneeName||t.assigneeId||'',t.feedbackId||''].join('\t')).join('\n')+`\n${result.nextOffset==null?'':'下一页：--offset '+result.nextOffset}`;
 if(command==='status')return JSON.stringify({service:result.service,projectId:result.projectId,name:result.name,projectDirectory:result.projectDirectory,engineDirectory:result.engineDirectory,identity:result.identity,workflow:result.workflow,revision:result.revision,scheduleRevision:result.scheduleRevision,snapshotId:result.snapshotId,baseline:result.baseline},null,2);
 return JSON.stringify(result,null,2);
}
function validateOutput(options,cwd){
 if(options.select&&(!options.select.split(',').every(p=>p&&p.split('.').every(k=>/^[A-Za-z0-9_-]+$/.test(k)&&!['__proto__','prototype','constructor'].includes(k)))))usage('--select 需要逗号分隔的字段路径');
 if(options.out){const target=path.resolve(cwd,options.out);if(fs.existsSync(target))usage('--out 目标已存在，请指定新文件：'+target);try{if(!fs.statSync(path.dirname(target)).isDirectory())throw Error();fs.accessSync(path.dirname(target),fs.constants.W_OK);}catch{usage('--out 的父目录不存在或不可写');}}
}
function emitResult(result,{options,cwd,stdout,command}){
 let value=result;
 if(options.select)value=Object.fromEntries(options.select.split(',').map(p=>{let v=result;for(const k of p.split('.')){if(v==null||!Object.hasOwn(v,k))usage('结果中不存在 --select 字段：'+p);v=v[k];}return [p,v];}));
 if(options.out){const target=path.resolve(cwd,options.out),temp=path.join(path.dirname(target),'.gc-output-'+randomUUID()+'.tmp');try{fs.writeFileSync(temp,JSON.stringify(value,null,2)+'\n',{flag:'wx',encoding:'utf8',mode:0o600});fs.copyFileSync(temp,target,fs.constants.COPYFILE_EXCL);}finally{if(fs.existsSync(temp))fs.unlinkSync(temp);}stdout(JSON.stringify({outputFile:target,...(result.id?{requestId:result.id}:{}),...(result.status?{status:result.status}:{})})+'\n');return;}
 stdout(output(value,options.select?undefined:command,options.json||!!options.select)+'\n');
}
async function run(argv,{cwd=process.cwd(),env=process.env,stdout=s=>process.stdout.write(s),stderr=s=>process.stderr.write(s),clientFactory=createClient}={}){
 let requestId,options={},command,stage='arguments',operationSucceeded=false,projectDirectory;
 try{
  const parsed=parse(argv),words=parsed.words;options=parsed.options;
  if(options.version){stdout(JSON.stringify({version:workflowVersion})+'\n');return 0;}
  if(!words.length){stdout(help());return 0;}
  const schemaOnly=words[0]==='schema',exampleOnly=words[0]==='example';if(schemaOnly||exampleOnly)words.shift();
  const resolved=resolveCommand(words),{op,rest}=resolved;command=resolved.command;const spec=tools.find(t=>t.name==='gc_'+op);if(!spec)usage('未知工作流工具');
  validateOutput(options,cwd);
  const emit=value=>emitResult(value,{options,cwd,stdout,command});
  if(options.help&&!schemaOnly&&!exampleOnly){stdout(spec.description+'\n必需字段：'+spec.inputSchema.required.join(', ')+'\n用 --file 传入 JSON 参数；gamecreator schema '+(command||op)+' 查看完整格式。requestId 写入时可自动生成。\n');return 0;}
  if(schemaOnly){emitResult(spec.inputSchema,{options:{...options,json:true},cwd,stdout});return 0;}
  if(exampleOnly){const result=requestExample(op);emitResult(['content validate','content submit'].includes(command)?result.arguments.draft:result.arguments,{options:{...options,json:true},cwd,stdout});stderr(JSON.stringify({notes:result.notes})+'\n');return 0;}
  let args=options.file?readJson(path.resolve(cwd,options.file)):{};
  if(!args||typeof args!=='object'||Array.isArray(args))usage('--file 必须包含 JSON 对象');
  if(['content validate','content submit'].includes(command))args={draft:args};
  args={...args};
  if(rest.length){const key={content_template:'name',task_read:'taskId',feedback_status:'feedbackId',operation_status:'requestId'}[op];if(!key||rest.length!==1)usage('多余的位置参数');if(Object.hasOwn(args,key))usage('输入文件和命令重复指定 '+key);args[key]=rest[0];}
  if(command==='reviews list')args.view='review';
  for(const [flag,value]of Object.entries(options)){
   if(globals.has(flag))continue;
   if(flag==='mine'){if(args.view&&args.view!=='mine')usage('--mine 与 view 冲突');args.view='mine';continue;}
   const key=aliases[flag]||flag.replace(/-([a-z])/g,(_,c)=>c.toUpperCase()),rule=spec.inputSchema.properties[key];
   if(!rule)usage('此命令不支持 --'+flag+'；使用 gamecreator schema 查看参数');
   if(Object.hasOwn(args,key)&&!(key==='requestId'&&args[key]===value))usage('输入文件和命令重复指定 '+key);
   args[key]=rule.type==='boolean'?(typeof value==='boolean'?value:value==='true'?true:value==='false'?false:usage('--'+flag+' 需要 true 或 false')):rule.type==='integer'?Number(value):rule.type==='array'?String(value).split(',').filter(Boolean):rule.type==='object'?(()=>{try{return JSON.parse(value);}catch{usage('--'+flag+' 需要 JSON 对象');}})():value;
   if(rule.type==='integer'&&(!Number.isInteger(args[key])||rule.minimum!==undefined&&args[key]<rule.minimum||rule.maximum!==undefined&&args[key]>rule.maximum))usage('--'+flag+' 超出范围');
  }
  const writing=spec.inputSchema.required.includes('requestId')&&op!=='operation_status';
  if(writing){args.requestId??=randomUUID();requestId=args.requestId;if(op==='feedback_submit')args.feedbackId??=requestId;}
  if(Object.keys(args).some(k=>!Object.hasOwn(spec.inputSchema.properties,k))||spec.inputSchema.required.some(k=>!Object.hasOwn(args,k)))usage('参数缺失或包含未知字段；运行 gamecreator schema '+(command||op)+' 查看格式');
  stage='project_discovery';projectDirectory=discover(options.project?path.resolve(cwd,options.project):env.GAMECREATOR_PROJECT_DIR||cwd);
  stage='credential';const credential=options.credential||env.GAMECREATOR_CREDENTIAL_FILE;if(!credential)usage('请使用 --credential 或 GAMECREATOR_CREDENTIAL_FILE 指定本人凭证文件');
  const credentialFile=path.resolve(cwd,credential),secret=readJson(credentialFile,32768);
  if(secret.schema!==2||typeof secret.privateKey!=='string'||!secret.projectId||!secret.memberId||!secret.credentialId)usage('凭证格式无效，请使用本人长期开发者凭证');
  // Read once for this invocation; no persistent shared identity or secret cache.
  const client=clientFactory({projectDirectory,readSecret:()=>secret});
  if(writing)stderr(JSON.stringify({requestId,hint:'超时先用 operations show 查询；重试沿用同一 requestId 和参数。'})+'\n');
  stage='service';const result=await client.call('gc_'+op,args);operationSucceeded=writing&&result.status==='succeeded';stage='output';if(writing&&!operationSucceeded){stdout(JSON.stringify(result,null,2)+'\n');}else emit(result);if(options.timing)stderr(JSON.stringify({timing:result.timing})+'\n');if(writing&&result.status!=='succeeded'){stderr(JSON.stringify({error:result.error||'操作尚未成功，请按 requestId 查询状态',requestId,status:result.status,code:result.code,guidance:result.guidance})+'\n');return 1;}return command==='doctor'&&!result.ready?1:0;
 }catch(error){
  const offline=['ECONNREFUSED','ETIMEDOUT','ENOTFOUND'].includes(error.cause?.code)||['TimeoutError','AbortError'].includes(error.name)||error.message==='fetch failed';
  if(command==='doctor'&&!['arguments','output'].includes(stage)){const diagnostic={ready:false,clientVersion:workflowVersion,projectDirectory,checks:[{id:stage,status:'blocked',message:offline?'服务不可达或请求超时':error.message,next:stage==='project_discovery'?'在 GameCreator 中打开或登记该管理项目；用 --project 指定目录，必要时更新协作文件并同步工程入口':stage==='credential'?'用 --credential 指定用户交付给本助手的凭证文件':'打开对应 GameCreator 管理项目并重试 doctor；检查实时授权与客户端版本'}]};try{emitResult(diagnostic,{options:{...options,select:undefined},cwd,stdout,command});}catch(outputError){stderr(JSON.stringify({error:outputError.message,diagnostic})+'\n');return 2;}return offline?3:error.exitCode||1;}
  stderr(JSON.stringify({error:offline?'GameCreator 服务未连接或请求超时。请启动软件；写入超时先按 requestId 查询结果。':error.message,requestId,operationSucceeded:operationSucceeded||undefined,code:error.code,guidance:error.guidance,...(operationSucceeded?{next:'服务端操作已成功，结果输出失败；先按 requestId 查询，不要使用新编号重试'}:{}),diagnostics:error.diagnostics||[],timing:error.timing})+'\n');return error.exitCode|| (offline?3:1);
 }
}
if(require.main===module)run(process.argv.slice(2)).then(code=>{process.exitCode=code;});
module.exports={run,discover,commands};
