#!/usr/bin/env node
// Standalone stdio MCP adapter, exported with each management project's collaboration files.
const fs=require('node:fs'),path=require('node:path'),readline=require('node:readline');
const {randomUUID,createPrivateKey,sign}=require('node:crypto');
const {performance}=require('node:perf_hooks');
const workflowVersion='3.10.0';
const canonical=v=>Array.isArray(v)?'['+v.map(canonical).join(',')+']':v&&typeof v==='object'?'{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}':JSON.stringify(v);
const str={type:'string'},obj={type:'object'},choices=values=>({type:'object',additionalProperties:{type:'string',enum:values}});
const taskCreateSchema={type:'object',additionalProperties:false,properties:{selfReviewRole:{type:'string',enum:['producer','art-director'],description:'明确允许对应管理者本人独立执行的任务自验收；不与旧 producerSelfReview 同时设置。'},producerSelfReview:{type:'boolean',description:'明确允许制作人本人承担的程序或主干集成任务自验收；仍需 progress/review 权限与两次操作。'},integrationTaskIds:{type:'array',items:str,description:'主干集成来源任务，须同时列入 dependencyIds；空数组表示初始主干集成。'},workScope:{type:'object',additionalProperties:false,properties:{allowedPaths:{type:'array',items:str},interfaceContract:str,entry:str},required:['allowedPaths','interfaceContract','entry']},id:str,title:str,description:str,kind:{type:'string',enum:['设计','程序','美术','关卡','测试','其他']},priority:{type:'string',enum:['低','普通','高','紧急']},milestoneId:str,dependencyIds:{type:'array',items:str},acceptance:str,start:str,end:str,positionIds:{type:'array',items:str},references:{type:'array',items:{type:'object',additionalProperties:false,properties:{kind:{type:'string',enum:['gameplay','capability','tool','requirement','asset','map','prototype']},targetId:str},required:['kind','targetId']}}},required:['id','title','description','kind','acceptance']};
const dependencyUpdateSchema={type:'object',additionalProperties:false,properties:{taskId:str,revision:str,dependencyIds:{type:'array',items:str},acceptImpact:{type:'boolean'}},required:['taskId','revision','dependencyIds']};
const milestoneUpdateSchema={type:'object',additionalProperties:false,properties:{taskId:str,revision:str,milestoneId:str},required:['taskId','revision','milestoneId']};
const createDispatchSchema={type:'object',additionalProperties:false,properties:{task:taskCreateSchema,assigneeId:str,reviewerId:str},required:['task','assigneeId']};
const specs=[
 ['diagnose','检查当前项目连接、身份权限、服务及导出工具版本；modules 可检查计划写入模块的授权。只读，不启动软件或修改权限。',{modules:{type:'array',items:str}},[]],
 ['request_example','获取工作流操作的输入样例；保留占位符并按实时数据填写后再调用，不自动执行。',{operation:str},['operation']],
 ['delivery_check','分页检查可见任务、待验收反馈、关联模块状态与里程碑准备情况。只读，不自动验收，不运行引擎。',{taskId:str,milestoneId:str,offset:{type:'integer',minimum:0},limit:{type:'integer',minimum:1,maximum:100}},[]],
 ['feedback_correct','已完成任务的原提交人或验收人追加说明更正，保留原验收及证据版本。交付内容改变应创建后续任务；此操作不表示重新验收。',{taskId:str,revision:str,feedbackId:str,correctionVersion:{type:'integer',minimum:0},note:str,deliveryVersion:str,evidence:{type:'array',items:str},requestId:str},['taskId','revision','feedbackId','correctionVersion','note','deliveryVersion','evidence','requestId']],
 ['content_template','按对象读取可写模板、必填字段、合法值及流程维护字段；不传 name 只列支持的模板目录。补齐引用后仍须 content_validate。',{name:str},[]],
 ['task_list','分页读取有权访问的任务摘要；默认本人任务，不返回正文和历史。view=review 只列本人待验收反馈。',{view:{type:'string',enum:['mine','review','dispatched','accessible']},status:{type:'string',enum:['待开始','进行中','受阻','待验收','已完成']},unfinished:{type:'boolean'},query:{type:'string'},offset:{type:'integer',minimum:0},limit:{type:'integer',minimum:1,maximum:100}},[]],
 ['phase_update','制作人明确设置项目阶段及计划开发线数，记录依据；不自动扩编或改写旧任务。',{scheduleRevision:str,phase:{type:'string',enum:['prototype','production']},reason:str,parallelLines:{type:'integer',minimum:1,maximum:100},requestId:str},['scheduleRevision','phase','reason','parallelLines','requestId']],
 ['feedback_append','原提交人为待验收反馈追加证据，保留原文、时间及版本；不得借此修改交付或验收标准。',{taskId:str,revision:str,feedbackId:str,evidenceVersion:{type:'integer',minimum:1},note:str,deliveryVersion:str,evidence:{type:'array',items:str},requestId:str},['taskId','revision','feedbackId','evidenceVersion','note','deliveryVersion','evidence','requestId']],
 ['task_create','原子创建待开始任务并派发。需要排期写入及 team_manage 权限，先读取 scheduleRevision；成功不代表 AI 已接手。',{scheduleRevision:str,task:taskCreateSchema,assigneeId:str,reviewerId:str,reason:str,requestId:str},['scheduleRevision','task','assigneeId','reason','requestId']],
 ['task_dependencies_update','修改未进入验收任务的依赖，记录原因和前后值。进行中任务新增未完成前置需 acceptImpact=true。',{scheduleRevision:str,...dependencyUpdateSchema.properties,reason:str,requestId:str},['scheduleRevision',...dependencyUpdateSchema.required,'reason','requestId']],
 ['task_milestone_update','调整既有任务所属里程碑；空 milestoneId 表示取消关联。允许完成或待验收任务，仅改变归属。',{scheduleRevision:str,...milestoneUpdateSchema.properties,reason:str,requestId:str},['scheduleRevision',...milestoneUpdateSchema.required,'reason','requestId']],
 ['task_plan_apply','在同一事务创建并派发任务、调整已有任务依赖与里程碑归属（合计最多50项）。任一步失败不留下部分派发。',{scheduleRevision:str,creates:{type:'array',items:createDispatchSchema,maxItems:50},dependencyUpdates:{type:'array',items:dependencyUpdateSchema,maxItems:50},milestoneUpdates:{type:'array',items:milestoneUpdateSchema,maxItems:50},reason:str,requestId:str},['scheduleRevision','reason','requestId']],
 ['task_inbox','读取实时任务、前置更新提示 dependencyUpdates、验收人与反馈。提示不会自动改变受阻状态或启动外部助手。',{},[]],
 ['task_read','读取任务当前内容与 revision。进度、验收和派发前必须核对此版本。',{taskId:str},['taskId']],
 ['feedback_submit','直接写入自己已分配任务的进度或待验收反馈，并返回接收回执。feedbackId 与 requestId 使用唯一编号，重试保持不变。',{taskId:str,revision:str,feedbackId:str,status:{type:'string',enum:['进行中','受阻','待验收']},summary:str,evidence:{type:'array',items:str},requestId:str},['taskId','revision','feedbackId','status','summary','evidence','requestId']],
 ['feedback_status','按 feedbackId 查询反馈是否收到、验收人及通过或退回结论。', {feedbackId:str},['feedbackId']],
 ['review_inbox','读取当前身份待验收任务与成果证据；不会自动验收或启动其他 AI 会话。',{},[]],
 ['feedback_review','指定验收负责人通过或退回反馈；需要 review 权限。仅明确允许的制作人开发或主美制作任务可自验收，仍须先提交证据。',{taskId:str,revision:str,feedbackId:str,evidenceVersion:{type:'integer',minimum:1,description:'反馈证据版本；存在补充证据时必须提供最新值。'},decision:{type:'string',enum:['accepted','returned']},note:str,requestId:str},['taskId','revision','feedbackId','decision','note','requestId']],
 ['task_dispatch','具有项目范围及 team_manage 权限的负责人派发已有任务。默认保留验收人，否则使用接收人的直属负责人或派发人。',{taskId:str,revision:str,assigneeId:str,reviewerId:str,requestId:str},['taskId','revision','assigneeId','requestId']],
 ['project_read','读取绑定项目的当前版本、身份权限、同步配置及指定内容模块。snapshotId 仅在当前内容已登记基准时有效，否则为 null；检查 baseline 状态。templates=true 返回内容模板。',{modules:{type:'array',items:str},templates:{type:'boolean'}},[]],
 ['content_baseline_prepare','仅写入一份不可变设计基准并登记，返回可用 snapshotId；不重写指南、工具、模块文档。先用 gc_project_read 核对 revision 和 baseline.prepareWrites。',{revision:str,requestId:str},['revision','requestId']],
 ['content_validate','校验设计草稿并返回字段差异和诊断，不写入提交文件。draft 使用已登记的 snapshotId；基准不可用时返回 diagnostics，调用 gc_content_baseline_prepare 准备。',{draft:obj},['draft']],
 ['content_submit','签名并保存设计提交，尚不应用。requestId 为本次操作唯一编号，重试沿用原编号。',{draft:obj,requestId:str},['draft','requestId']],
 ['content_scan','列出待处理设计提交及处理记录，返回 digest/reviewId 供后续预览与应用。',{},[]],
 ['content_preview','重新检查选定设计提交及冲突选择。使用 scan 返回的 id、digest、reviewId。',{id:str,digest:str,reviewId:str,decisions:choices(['keep','proposal'])},['id','digest','reviewId']],
 ['content_apply','按当前授权应用已检查的设计提交。冲突逐项指定 keep/proposal；过期版本会拒绝。',{id:str,digest:str,reviewId:str,decisions:choices(['keep','proposal']),requestId:str},['id','digest','reviewId','requestId']],
 ['collaboration_export','更新管理项目 ai/ 的协作快照、指南和编写工具。需要全部模块的项目写入授权。',{requestId:str},['requestId']],
 ['art_style_confirm','审阅已应用的风格草稿后确认新基准。需要 art-assets 项目写入及 review 权限，传 gc_project_read 返回的最新项目 revision、确认说明、唯一 requestId。',{revision:str,note:str,requestId:str},['revision','note','requestId']],
 ['engine_preview','按已保存配置预览工程同步。可传 modules（项目内容模块 ID，如 art-assets）仅同步获准模块文档，不导出凭证、协作上下文或其他模块；省略则完整同步并要求全部模块授权。',{modules:{type:'array',items:str,minItems:1,uniqueItems:true}},[]],
 ['engine_apply','执行当前开发者的工程同步预览。decisions 按文件路径选择 keep/replace，removals 明确列出允许移除的路径。',{token:str,decisions:choices(['keep','replace']),removals:{type:'array',items:str},requestId:str},['token','requestId']],
 ['operation_status','根据 requestId 查询执行状态。超时后先查询，再决定重试；running 在服务重启后可能需要检查处理记录。',{requestId:str},['requestId']],
 ['history','读取内容应用、工程同步和最近工作流执行记录。',{},[]]
];
const tools=specs.map(([name,description,properties,required])=>({name:'gc_'+name,description,inputSchema:{type:'object',properties:{...properties,timing:{type:'boolean',description:'返回本次调用的耗时统计，不保存请求正文或凭证。'}},required,additionalProperties:false}}));
function requestExample(operation){
 const name=typeof operation==='string'?operation.replace(/^gc_/,''):'',spec=specs.find(s=>s[0]===name);
 if(!spec)throw new Error('未知工作流操作，请查看工具列表或 CLI --help');
 const sample=(rule,key)=>{
  if(rule.enum)return rule.enum[0];
  if(rule.type==='object')return Object.fromEntries((rule.required||[]).map(k=>[k,sample(rule.properties[k],k)]));
  if(rule.type==='array')return [sample(rule.items||str,key+'Item')];
  if(rule.type==='integer')return rule.minimum??0;
  if(rule.type==='boolean')return false;
  return '<填写 '+key+'>';
 };
 const args=Object.fromEntries(spec[3].map(k=>[k,sample(spec[2][k],k)]));
 if(['content_submit','content_validate'].includes(name))args.draft={schema:1,format:'gamecreator-content-change',intent:'project_change',id:'<新的提交编号>',projectId:'<当前项目ID>',snapshotId:'<已登记基准的snapshotId>',target:{kind:'module',id:'project'},summary:'<修改说明>',compatibility:{reuse:'<复用>',modify:'<修改及兼容>',add:'<新增>',archive:'<归档，无则写无>'},operations:[{id:'overview',module:'project',op:'set',path:'/description',value:'<项目说明>'}]};
 if(name==='task_plan_apply')args.creates=[sample(createDispatchSchema,'creates')];
 if(name==='feedback_submit')args.status='待验收';
 if(name==='feedback_review')args.decision='returned';
 return {operation:'gc_'+name,arguments:args,notes:['样例只展示结构；尖括号为待替换值。先读取当前身份、任务与版本，再填写并核对。','CLI 的 content validate/submit --file 使用 arguments.draft 本身；其他 --file 使用 arguments。','同一次写入的 requestId 保持不变；预览、应用与验收分别执行。']};
}
function read(file){return JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));}
function createClient({projectDirectory,credentialFile,readSecret,readEndpoint,dispatch,accessContext}){
 async function call(name,args={}){
  const start=performance.now();
  const attach=value=>{if(args?.timing===true){const total=Math.round((performance.now()-start)*100)/100;value.timing={...value.timing,clientTotalMs:total,clientOutsideServerMs:Math.max(0,Math.round((total-(value.timing?.serverTotalMs||0))*100)/100)};}return value;};
  try{return attach(await invoke(name,args));}catch(e){attach(e);throw e;}
 }
 async function invoke(name,args={}){
  const spec=specs.find(s=>'gc_'+s[0]===name);if(!spec)throw new Error('未知工作流工具');
  if(!args||typeof args!=='object'||Array.isArray(args)||Object.keys(args).some(k=>k!=='timing'&&!Object.hasOwn(spec[2],k))||spec[3].some(k=>!Object.hasOwn(args,k)))throw new Error('工具参数缺失或包含未知字段');
  const secret=readSecret?readSecret():read(credentialFile),endpoint=readEndpoint?readEndpoint():read(path.join(projectDirectory,'ai/workflow-service.json'));
  if(secret.schema!==2||secret.projectId!==endpoint.projectId||!dispatch&&!/^http:\/\/127\.0\.0\.1:\d+\/workflow$/.test(endpoint.endpoint))throw new Error('工作流端点与开发者凭证不匹配');
  const privateKey=createPrivateKey({key:Buffer.from(secret.privateKey,'base64'),type:'pkcs8',format:'der'});if(privateKey.asymmetricKeyType!=='ed25519')throw new Error('凭证密钥格式无效');
  if(args.timing!==undefined&&typeof args.timing!=='boolean')throw new Error('timing 必须是布尔值');
  const {requestId,timing,...input}=args;
  if(spec[0]==='operation_status')input.requestId=requestId;
  if(input.draft){const {identity,...draft}=input.draft;const proposal={...draft,author:secret.memberName,identity:{memberId:secret.memberId,credentialId:secret.credentialId}};proposal.identity.signature=sign(null,Buffer.from(canonical(proposal)),privateKey).toString('base64');input.proposal=proposal;delete input.draft;}
  const body={schema:1,clientVersion:workflowVersion,session:endpoint.session,id:spec[0]==='operation_status'?randomUUID():requestId||randomUUID(),at:new Date().toISOString(),projectId:secret.projectId,memberId:secret.memberId,credentialId:secret.credentialId,operation:spec[0],input};
  if(timing===true)body.timing=true;
  if(accessContext)body.accessContext=accessContext;
  body.signature=sign(null,Buffer.from(canonical(body)),privateKey).toString('base64');
  if(dispatch)return dispatch(body);
  const response=await fetch(endpoint.endpoint,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(60000),redirect:'error'}),result=await response.json();
  if(!response.ok){const error=new Error(result.error||'工作流操作失败');error.diagnostics=result.diagnostics||[];error.code=result.code;error.guidance=result.guidance;error.timing=result.timing;throw error;}return result;
 }
 return {call};
}
function serve(client,options={}){
 let initialized=false;
 const output=v=>process.stdout.write(JSON.stringify(v)+'\n');
 const rl=readline.createInterface({input:process.stdin,crlfDelay:Infinity});
 rl.on('line',async line=>{
  let r;try{if(Buffer.byteLength(line)>3*1024*1024)throw new Error();r=JSON.parse(line);}catch{output({jsonrpc:'2.0',id:null,error:{code:-32700,message:'无效 JSON 或请求过大'}});return;}
  if(r.id===undefined)return;
  const respond=result=>output({jsonrpc:'2.0',id:r.id,result}),fail=(code,message)=>output({jsonrpc:'2.0',id:r.id,error:{code,message}});
  if(r.jsonrpc!=='2.0'||typeof r.method!=='string')return fail(-32600,'无效请求');
  if(r.method==='initialize'){initialized=true;options.onInitialize?.(r.params?.clientInfo);return respond({protocolVersion:['2024-11-05','2025-03-26','2025-06-18'].includes(r.params?.protocolVersion)?r.params.protocolVersion:'2025-06-18',capabilities:{tools:{}},serverInfo:{name:options.name||'gamecreator-workflow',version:options.version||workflowVersion},instructions:options.instructions||'先读取 gc_project_read 并核对 baseline；snapshotId 为空时用 gc_content_baseline_prepare 准备基准，再提交设计并查看差异后应用。已有任务归属用 gc_task_milestone_update 或 gc_task_plan_apply.milestoneUpdates；工程同步使用独立预览 token。连接与版本问题用 gc_diagnose，参数样例用 gc_request_example。反馈操作按 guidance 处理待验收补证据和已完成更正，交付前用 gc_delivery_check。新增内容先用 gc_content_template 按对象获取模板；失败按 diagnostics 修正；排查耗时传 timing:true。每项写入使用稳定的 requestId，超时先查询状态。'});}
  if(r.method==='ping')return respond({});if(!initialized)return fail(-32000,'请先初始化 MCP 连接');
  if(r.method==='tools/list')return respond({tools:options.tools||tools});
  if(r.method!=='tools/call')return fail(-32601,'未知 MCP 方法');
  try{const value=await client.call(r.params?.name,r.params?.arguments||{});respond({content:[{type:'text',text:JSON.stringify(value)}],structuredContent:value,isError:false});}
  catch(error){respond({isError:true,content:[{type:'text',text:JSON.stringify({error:error.message,code:error.code,guidance:error.guidance,diagnostics:error.diagnostics||[],timing:error.timing,hint:'先按 guidance 核对当前状态；连接或版本问题用 gc_diagnose，超时后使用原 requestId 查询 gc_operation_status。'})}]});}
 });
 rl.on('close',()=>options.onClose?.());
}
if(require.main===module){
 const args=process.argv.slice(2),option=k=>args[args.indexOf(k)+1];
 const projectDirectory=args.includes('--project')?option('--project'):path.resolve(__dirname,'..'),credentialFile=args.includes('--credential')?option('--credential'):process.env.GAMECREATOR_CREDENTIAL_FILE;
 if(!credentialFile){process.stderr.write('请用 --credential 或 GAMECREATOR_CREDENTIAL_FILE 指定开发者凭证文件。\n');process.exitCode=1;}else serve(createClient({projectDirectory:path.resolve(projectDirectory),credentialFile:path.resolve(credentialFile)}));
}
module.exports={createClient,tools,serve,canonical,workflowVersion,requestExample};
