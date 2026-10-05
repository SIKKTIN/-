## 从引擎效果到项目管理

AI 以引擎项目为主要工作目录，结合实际运行效果完成设计、开发与验证。GameCreator 项目保存正式设计、分工、进度和验收记录。

- 项目：这次怎么逃
- 项目 ID：project-10beb421-66ef-416e-8bcb-abf7bba4cd5c
- 引擎工程目录：E:\Project\Godot\这次怎么逃
- GameCreator 项目目录：E:\Docs\这次怎么逃
- 设计文档目录（相对工程）：docs/gamecreator

开始开发前先读 [本项目自定义规范](../docs/gamecreator/modules/project-management/standards.md)。内置通用规则与使用说明统一保存在 GameCreator 项目中。

### 制作人职责与交接边界

制作人默认负责目标、内容方案、设计基线、团队授权、任务分配、协调和验收。主美兼技术美术，负责表现与技术方案、美术和音效任务派发及审核；模块负责人完成各自模块，制作人维护主干并执行明确分配给自己的程序与集成任务。可以读取工程代码、运行已有原型、检查日志和测试证据，依据实际效果调整设计。开发授权以明确任务为准，制作人可以在自己的程序或集成任务范围内编写代码与场景，不自动接管别人的模块。

制作人依据真实测试报告作验收决策，无需逐项重跑常规测试；仍可体验关键节点或按风险抽查。测试任务交付报告，被测功能与里程碑分别验收，发现缺陷不等于报告无效。具体自测由各任务执行人完成，需要独立验证时另行分派，避免重复验收成为交付瓶颈。

项目范围、project_write 和 team_manage 表示管理项目的访问或操作授权，不等于承接所有岗位的制作任务。零个人任务不等于等待：继续完善设计、拆解依赖、准备工作包、协调阻塞并组织验收。完成设计和分工后，下一步是交接与跟踪；不能因“推进项目”“验证设计”“先做灰盒”而自行接替执行岗位。

工作包应说明接收人的成员 ID、岗位及任务 ID、两边项目入口、已应用的设计基准、前置依赖、允许修改的范围、交付位置、验收步骤和反馈方式。每位助手只使用自己的凭证；制作人分发其他成员的凭证，不借用它们切换身份执行任务。

创建身份或签发令牌不等于实际 AI 已接手。有已获授权的助手调度工具时，按工作包派发并核对接收结果；没有工具或尚未接入执行助手时，交付可直接使用的工作包，报告“待接入执行助手”及所缺条件。此时仍可推进其他管理工作，不自行代做，也不把任务标成进行中、完成或已验收。接手状态写入现有说明或交接记录，不新增任务状态枚举。

制作人承接核心程序和主干集成时，使用现有制作人身份、有效权限和明确的本人任务，无需创建第二身份或添加模块负责人岗位。具有排期写入与团队管理授权时，可以按已确认方案创建并派发自己的开发任务。其他兼任需明确授权与分配，不能借用令牌、扩大权限或接管别人任务。明确允许的制作人本人独立开发/集成任务可自验收，仍需先提交证据，再单独给出验收结论。

阶段汇报分别列出：设计已提交/已应用、身份已建立、工作包已交付、实际助手已接手、引擎成果已实现/已验收。分配后应说明由谁执行、下一次检查点和当前阻塞，不默认承诺“接下来我实现原型”。

上述是岗位执行约定。GameCreator 校验其接口内的授权，当前并不据此拦截外部终端或引擎工具的文件写入；工程操作的技术隔离须由 AI 运行环境与引擎工具落实。

## 原型双人开发与按需扩编

项目有原型开发与正式开发两个阶段，任务继续使用原有类型。新建项目默认原型开发，也可选择正式开发；预置制作人、主美两个活跃身份，不自动签发凭证、启动助手或生成任务链。到人员分配的协作令牌选择已有身份签发凭证。两人是默认配置，不是人数上限；已有项目不自动停用或改派成员。

原型期制作人直接开发核心玩法、关卡流程、共享接口和主干；主美兼技术美术，自己探索风格并制作关键视觉、UI、音效及技术方案。两人使用各自身份与明确任务，主美交付后由制作人检查接入后的可玩性、状态可读性和整体效果。无需另设常驻美术执行或审核身份。

原型任务按问题做短循环，不强制里程碑或多级派发：description 记录要验证的问题；workScope 记录改动范围、接口和运行入口；acceptance 写出本轮如何判断；反馈 summary 写实际观察、保留/修改/放弃决定和未覆盖项，evidence 附运行、试听或测试记录。实验方向被放弃仍可验收其有效结论，不能把它写成玩法验证通过。真人试玩与自动测试分别记录。

任务自验收须明确设置 selfReviewRole：producer 用于制作人本人的程序、关卡或集成任务；art-director 用于主美本人的设计、美术、其他方向的表现或音效任务。成员必须具备相应启用岗位、progress 与 review 权限，独立承担任务且没有协作者，并把本人设为 reviewerId。未显式指定验收人时，自验收任务默认本人；已有指定验收人保持有效。旧 producerSelfReview 继续兼容，不与 selfReviewRole 同时填写。其他成员不能通过此字段自验收，也不因阶段改变自动获得权限。

两次动作仍分别记录：gc_feedback_submit 提交待验收及非空证据，随后 gc_feedback_review 提交结论。主美风格发布另用 gc_art_style_confirm 确认已应用草稿，风格基准确认不等于资产任务验收或主干接入通过。

待验收后收到新的用户试听、试玩或测试结果，由原提交人调用 gc_feedback_append，传 taskId、最新 revision、feedbackId、evidenceVersion、note、deliveryVersion、evidence 和唯一 requestId。deliveryVersion 标明实际验证的构建、资源版本或哈希。系统保留原文、提交时间和追加记录，返回递增 evidenceVersion；验收须读取最新反馈并在 gc_feedback_review 传回该版本，旧证据版本会被拒绝。补充证据不修改任务、交付成果或验收标准；后者变化需退回重新提交。已处理反馈不能追加。

在“项目概览 → 项目阶段与开发计划”记录阶段及计划开发线数；MCP 使用 gc_phase_update，传 gc_project_read 返回的 scheduleRevision、phase（prototype 或 production）、reason、parallelLines 和 requestId。只有有项目排期写入权限的制作人能决定。切换不自动创建或激活成员，不改旧任务、反馈和验收约定。活跃身份数、历史成员数和计划并行线数分别展示；计划值不表示软件已监测实际运行的 AI。

进入正式开发前核对：同一可玩构建的核心体验已有证据；主干入口、资源路径和接口相对稳定；存在可量化且能独立交付的内容积压；真人观察与技术检查的风险、未覆盖项已记录。制作人据此明确说明依据，按瓶颈逐步增加模块负责人，正式阶段仍可保持两人。版本号、日期、岗位模板都不触发自动转换。新增任务明确文件范围、接口或资源契约、入口、交付版本和验收要求；模块交付、主干集成与里程碑分别确认。


## 制作人、主美与模块负责人

制作人与主美先给出可执行的方案，再分派任务和审核成果；模块负责人在约定范围内自主完成设计细化、实现、引擎集成、自测和文档回写。内容开发、美术设计、音效设计是负责方向，不要求按策划、程序、测试切换身份，也不增加任务类型。

- 制作人：制定游戏目标、核心玩法、内容结构、版本范围与优先级，协调共享系统和模块依赖，派发内容与功能任务，审核玩法、功能和整体体验；维护主干、共享接口与完整入口，执行本人明确承接的核心程序和集成任务。
- 主美（兼技术美术）：制定视觉风格和素材规格，给出渲染、材质、动画、特效、UI、导入及性能方案，统筹音效表现；派发美术、表现技术与音效任务，审核风格、品质、技术适配和引擎运行效果。
- 模块负责人：按负责模块细化方案，自主选择范围内的实现方法，完成代码或资产制作、集成和自测，提交运行入口、交付路径、测试证据、已知问题和待验收反馈。可以承担内容、美术、音效等方向，但只执行明确分配的任务，不因同属一个岗位而领取他人的模块。

制作人可以直接把“制定美术风格、技术路线和制作计划”等方案任务派给主美，主美以自己的身份提交方案待验收，由制作人审核。通过 MCP 创建或界面派发时，未明确指定任务岗位的方案任务会按接收的主美身份归类，无需填写内部岗位字段；已明确设置的岗位限制仍需核对。

原型期主美直接完成本人制作任务；内容积压明确后，再创建独立任务派给模块负责人并审核交付。方案与具体制作保留各自任务 ID，不把主美收到的方案任务转交给执行人代做。需要先确认方案才能制作时，将制作任务依赖指向方案任务。明确指定的验收人优先，本人任务明确允许时可自验收；模块负责人任务由独立负责人验收；负责人缺少有效权限时需先补齐授权。

工作顺序：制作人提出内容方案 → 主美提出配套表现与技术方案（需要时）→ 两位负责人协调接口与标准 → 按阶段由两位本人执行或派发模块 → 执行人实现并自测 → 指定审核人通过或退回 → 安排下一轮。

方案应明确目标、允许修改的目录与共享资源、依赖、交付入口、验收要求和审核人，不必规定每行代码或全部制作步骤。范围、公共接口或标准发生变化时先提出建议；实现细节由模块负责人自主决定。多个负责人并行修改同一共享文件前，先明确维护者和交接方式。

内容模块通常向制作人汇报；美术、表现技术和音效模块通常向主美汇报。直属负责人提供默认验收关系，任务明确指定的验收人优先。每项任务目前只有一名验收人，跨领域交付如需双方结论，安排独立审核任务并关联原任务，不宣称系统已支持双签。必要时另派独立验证任务，自测不等于验收，只有明确允许的制作人开发与主美制作任务可以自验收，仍须先提交证据再给出结论；其他执行人不能验收自己的工作。

制作人与主美不能只等待审核：应主动完善方案、分派工作、解决阻塞并依据真实引擎效果作出决策。可读取工程和运行已有成果；模块按明确分配执行；制作人以本人身份执行已分配的核心开发和集成任务，不能因无人接手自行扩权或借用其他成员令牌。

岗位名称不自动赋权。实时创建与派发任务仍需项目范围、project-schedule 模块的 project_write 和 team_manage；验收还需 review 与任务验收人身份。主美的素材专项权限覆盖风格、细节、技术方案、建议与美术派发，但专项派发不能替代上述实时排期工具授权。GameCreator 授权只约束自身接口，外部工程文件隔离由 AI 运行环境落实。

探索时缩小任务范围、明确假设并快速获取证据；原型制作时强调完整体验、稳定性和表现一致性，两者使用同一套身份和任务链路。没有真人观察证据时，不把自测通过表述为已验证趣味性。

## 制作人开发与主干集成

制作人维护能运行的主干、启动入口、核心骨架、公共接口与共享文件，也以同一个制作人身份承接明确分配给自己的程序和集成任务。模块负责人在约定范围完成独立模块，主美兼技术美术制定表现和技术方案并审核美术音效交付。

先在“项目管理 → 项目规范 → 项目整体约定”记录主干维护者、共享文件归属、完整流程入口和公共接口。MCP 编写对应 project-standards.mainline：ownerId 为成员 ID，sharedFiles、entry、interfaceContract 为说明文本。主干最小入口与依赖契约就绪后派发依赖它的模块；不依赖主干的方案工作可并行。

任务沿用现有类型，不增加探索或制作等分类。可填写 workScope 对象，其中 allowedPaths 为路径数组，interfaceContract 为接口契约，entry 为交付入口。主干集成任务另外填写 integrationTaskIds，标明集成哪些模块任务；这些 ID 同时加入 dependencyIds，空数组表示初始主干集成。模块交付通过只是满足集成前置，集成任务仍须单独验证与验收。交付提供提交或版本、改动清单、可运行入口、接口说明、自测结果和已知问题。

制作人创建自己的程序或集成任务时，assigneeId 使用自己的成员 ID；未明确限制任务岗位时按制作人身份分配，无需第二身份或兼任模块负责人。若要自验收，在任务上明确设置 producerSelfReview: true，并指定自己为 reviewerId（首次派发未指定时会使用本人）。已有明确验收人保持有效；本人同时需要 progress 与 review 权限。制作人的“程序”“关卡”或带 integrationTaskIds 的“其他”任务支持此约定，且必须由制作人本人独立执行、没有协作者。主美使用 selfReviewRole=art-director 的独立约定；模块负责人不能自验收。

自验收仍是两次动作：先 gc_feedback_submit 提交待验收与非空证据，再读取最新任务 revision，调用 gc_feedback_review 填写通过或退回结论。记录明确标注制作人自验收，保留执行反馈、验收者、时间与说明；不会因为有管理权限就自动完成任务。测试证据应来自实际运行，自验收不等于独立验证或真人体验结论。

主干集成后检查从启动到结算的完整路径、接口冲突与回归，再单独确认里程碑。任务开始后不倒改自验收约定、集成来源和执行范围；新范围另建后续任务。旧项目身份、已完成任务与反馈历史保持原样。

受阻反馈会记录当时未完成的前置任务。前置通过后，gc_task_inbox.dependencyUpdates 与任务清单显示待复查提示；执行人核对后提交进行中或新的受阻原因。系统保留原受阻状态和历史，不自动恢复制作、不自动唤醒外部 AI。提示基于读取时的最新状态；重新反馈后按新的阻碍重新判断。

路径及共享文件归属是协作约定，GameCreator 不据此拦截外部终端写文件。工作树用于隔离文件改动与合并，不作为多开游戏窗口的前提。调试前核对引擎工具提供的工程、编辑器和运行实例标识，运行、停止、输入、截图都指定同一目标；外部 MCP 未提供实例选择时先说明缺口，不宣称已经隔离。GameCreator 当前不控制 Godot 运行实例。


## 命令行协作（CLI）

CLI 与 MCP 是同一工作流服务的两种入口，权限、版本检查、冲突处理、回执和任务验收规则一致。按当前助手可用工具选择入口，无需同时连接两种客户端。CLI 当前需要 GameCreator 软件运行并已登记管理项目；不是脱离服务直接改存档，也不启动外部 AI。

在“项目内容同步”更新协作文件，管理项目会生成 ai/gc.cjs、ai/workflow-mcp.cjs 和 ai/WORKFLOW_CLI.md。启用工程协作同步后，引擎固定的 gamecreator/ 下生成 gc.cjs、workflow-mcp.cjs 和 cli.json；cli.json 只保存管理项目关联，不含凭证。即使另设协作入口子目录，CLI 仍在 gamecreator/，凭证仍按配置输出。目录迁移后重新同步。仅同步局部模块文档不会输出 CLI。

在引擎根目录执行下列命令；在管理项目中将 gamecreator/gc.cjs 换成 ai/gc.cjs。已安装软件包的 gamecreator 命令与这些脚本等价。

```powershell
$env:GAMECREATOR_CREDENTIAL_FILE = '本人凭证的绝对路径.json'
node gamecreator/gc.cjs status
node gamecreator/gc.cjs tasks list --mine --unfinished
node gamecreator/gc.cjs tasks show <任务ID>
node gamecreator/gc.cjs schema feedback submit
node gamecreator/gc.cjs feedback submit --file feedback.json --json
node gamecreator/gc.cjs reviews list --json
node gamecreator/gc.cjs reviews show <反馈ID>
```

先用 status 核对项目和本人权限；阶段、职责与实现范围仍按项目约定。凭证路径也可逐命令用 --credential 指定，或通过各助手独立进程的环境变量设置。CLI 不扫描 personal/，不选择其他成员身份，不持久保存私钥。只读帮助和 schema 无需凭证。未自动找到关联时用 --project 指定管理项目或已同步的引擎目录。

列表默认简短输出，--json 返回结构化结果；--status、--query、--limit、--offset 在服务端筛选分页。tasks list --view accessible 仅包含当前身份有权读取的任务，--view dispatched 查本人派发；reviews list 列出本人待验收反馈的编号和证据版本。任务正文用 tasks show 按需读取，验收证据用 reviews show 读取；依赖更新提示仍可通过 call gc_task_inbox 获取。

任务沿用现有类型与流程。批量派发用 tasks plan --file plan.json，复用同一事务（最多 50 项），不默认自动拆分或多次重试。阶段决定用 phase update，追加证据用 feedback append，验收用 reviews submit。先运行 schema <命令> 查看所需参数，输入文件必须包含已核对的 revision 或 scheduleRevision，不能在 CLI 内悄悄读取新版覆盖旧版。

设计流程为 project read --modules <模块ID> → content baseline（仅基准缺失时）→ content validate → content submit → content list → content preview → content apply。content validate/submit 的 --file 是设计草稿本身；其他命令的 --file 是对应操作的参数对象。复杂内容放 UTF-8 JSON 文件，不必将长文本拼进命令行。

工程交付为 sync preview → 检查文件差异 → sync apply --plan <token>；局部文档可用 sync preview --modules art-assets。冲突选择 decisions 和允许移除的 removals 通过 --file 明确提供，CLI 不自动覆盖冲突。同步预览属于当前身份，服务重启或预览过期后需重新预览。

每次写入自动生成 requestId，并在发送前输出到 stderr；可以显式传 --request-id。反馈编号未提供时使用同一 requestId。超时先用 operations show <requestId> 查询，重试沿用编号及相同参数，不生成另一个提交。不自动重试写入、不自动验收。stdout 为结果，stderr 为操作编号或错误；--json 便于脚本读取，退出码 0 成功、2 参数/文件错误、3 服务不可达或超时、1 其他失败。

### 按对象获取可写模板

准备新增内容时，先获取该对象的模板，再填写设计；无需反复读取整个项目或完整模板包。这是提交对象的结构辅助，任务类型与工作流程保持原样。

```powershell
node gamecreator/gc.cjs content templates --json
node gamecreator/gc.cjs content template milestone --json
node gamecreator/gc.cjs content template analysisParameter --json
node gamecreator/gc.cjs content validate --file draft.json --timing --json
```

MCP 对应 gc_content_template：不传 name 返回目录，传 name 只返回一个对象。当前提供 16 个高频模板：designDocument、designBlock、productionTask、milestone、system、capability、functionalUsage、functionalDependency、analysis、analysisParameter、analysisMetric、analysisVariant、map、mapLayer、mapObject、mapConnection。其他对象仍可从现有 context/templates.json 读取。schema <命令> 显示的是工具参数；content template 显示的是要写入的内容对象。

返回 template 是单个条目的初始值，collectionPath 指出所属集合；父级占位 ID 和引用需替换为实际 ID。fields 标明基本结构的 required、类型、枚举、范围以及 access：writable 可编辑；identity 在新建时指定，已有标识不可改；workflow 由进度、验收等专用流程维护，新建保留初始值。字段说明不替代完整 Schema、权限及引用检查。先读取目标模块；修改已有条目以当前内容为基础，不用空模板替换已有条目。

数值参数和指标的 ID 必须为 move_speed 这样的公式变量名，不能使用 UUID；模板现在生成合法且唯一的标识符。功能关联 sourceKind=design 时 sourceId 必须为空，玩法 ID 放在 gameplayId；rule/state/event 则引用该玩法内的子条目。

校验失败时先检查 diagnostics 的 module、operationId、path、expected 和 actual，集中修正本批次问题。字段提示覆盖上述对象的常用结构，仍保留原校验器对其他字段及业务关系的检查；流程字段错误可能先于结构错误返回。actual 对自由文本只返回类型和长度，避免整条正文反复输出。离线 ai/submit-change.cjs validate 使用同源校验包，也返回这些诊断。

### 定位调用耗时

CLI 使用 --timing；MCP 的工作流工具传 timing:true。结果与失败诊断都可携带 timing，CLI 同时将计时写到 stderr。不启用时保持原来的结果格式；计时不写入项目记录，也不影响 requestId 重试。

clientTotalMs 为客户端本次调用耗时，全局 MCP 包含本次连接和凭证挑战；serverTotalMs 为工作流服务排队至完成耗时；queueMs 是同项目的排队等待。clientOutsideServerMs 是客户端耗时减去服务计时，包含签名、连接、传输及响应解析等，不能直接视为纯网络耗时。

stagesMs 按实际发生的阶段记录 projectRead、authentication、editorWait、execution、contentValidation、contentWrite、journalWrite。内容校验与写入的细分目前覆盖设计提交流程，其他操作主要查看 execution。阶段可能嵌套，不能直接相加；缺失字段表示没有记录该阶段，不代表零成本。统计不包含 AI 思考、客户端工具调度或整轮对话耗时，不能据此将整个开发耗时归因于 MCP。

列表摘要、按需模板和字段诊断用于减少往返与重复读取；完整校验、权限和写入一致性检查继续保留。

### 连接诊断与请求样例

首次接手、服务连接失败、升级后找不到命令，先用 doctor。它验证本助手凭证，显示管理项目与引擎位置、当前身份及模块授权、客户端/服务版本和导出文件版本，并给出处理步骤。--modules 可检查准备写入的模块；ready 不代表所有操作都有权限。服务离线或缺少凭证时也会返回诊断，不需要查软件源码、进程或内部存档。doctor 不自动启动软件、打开项目或改变授权。

```powershell
node gamecreator/gc.cjs doctor --modules design-documents,project-schedule --json
node gamecreator/gc.cjs --version
node gamecreator/gc.cjs example tasks plan --out task-plan-request.json
node gamecreator/gc.cjs example feedback append --out append-request.json
node gamecreator/gc.cjs status --select identity.name,service.version --json
node gamecreator/gc.cjs content template designDocument --out document-template.json
```

example 和 schema 无需连接或凭证。example 输出可供 --file 使用的结构，必须填写尖括号占位符、实时版本和业务内容；不自动选择身份、验收结论或执行操作。content validate/submit 的样例是草稿本身；其他命令输出操作参数。MCP 使用 gc_request_example，operation 如 task_plan_apply，参数样例位于 arguments 中。

--out 保存 UTF-8 JSON，成功时 stdout 返回文件位置；现有文件会在请求前拒绝，请选择新文件名。普通操作失败不会创建结果文件；doctor 的失败诊断可保存，但退出码仍非零。--select 选择逗号分隔的字段路径，返回以路径为键的 JSON；这是本地输出裁剪，不减少服务端读取。不要合并 stderr 和 stdout 再解析 JSON。若写入成功但本地保存/选字段失败，错误返回 operationSucceeded 与 requestId；先查询 operations show，不能换新编号重做写入。

### 反馈状态与验收后更正

tasks show、reviews show、反馈回执及任务操作错误返回 guidance：当前任务状态、反馈状态、taskRevision、evidenceVersion、correctionVersion 和当前身份可执行的 actions。指引使用实时岗位与权限，最终操作仍重新检查版本与输入。反馈提交后必须核对成功回执和退出码，不能只因写好了本地文件就宣称提交成功。

- 进行中或受阻：feedback submit 报告实际进度；未完成前置会限制可提交的状态。
- 待验收：同一交付仅补充说明/证据用 feedback append，传最新 evidenceVersion。交付内容或验收依据改变，请验收人退回后重新提交；不要换 feedbackId 绕过待验收状态。
- 证据追加后：验收人重新读取证据版本再 reviews submit。旧版验收请求会被拒绝。
- 已完成：原提交人或指定验收人可用 feedback correct 追加说明更正，传最新 correctionVersion（初始为 0）、note、deliveryVersion 和 evidence。原反馈、证据版本、任务状态和验收结论保留；更正也显示在任务清单反馈中。
- 更正不能代替重新验收。涉及实现、交付范围或原结论变化时创建后续任务；更正文件建议另存为带版本的证据，不只覆盖原报告。仅修改磁盘上的报告不会更新 GameCreator 的反馈版本。

```powershell
node gamecreator/gc.cjs reviews show <反馈ID> --json
node gamecreator/gc.cjs example feedback correct --out correction-request.json
# 填写并核对 correction-request.json 后执行
node gamecreator/gc.cjs feedback correct --file correction-request.json --json
```

### 交付检查

```powershell
node gamecreator/gc.cjs delivery check --limit 20 --json
node gamecreator/gc.cjs delivery check --task <任务ID> --json
node gamecreator/gc.cjs delivery check --milestone-id <里程碑ID> --json
```

交付检查只返回当前身份可见的任务、未完成前置、待验收反馈、关联模块的登记状态，以及相关里程碑是否已具备单独确认的条件。支持 offset/limit 分页；milestones 汇总不局限于当前页。当仅能看到部分任务时 coverage=partial，不能据此判断整个里程碑。

任务完成不等于功能状态更新。素材和工具按全部关联任务及各自规则汇总；功能、玩法等状态独立维护。里程碑任务全部完成后仍需在项目排期中单独确认验收。检查不会改变任何进度，不运行引擎，也不读取或验证证据文件，实际表现与证据仍需负责人核对。

MCP 对应 gc_diagnose、gc_request_example、gc_delivery_check、gc_feedback_correct；与 CLI 复用同一服务和权限。升级后更新协作文件、工程同步并重启旧适配器；无需重新签发仍有效的成员凭证。


## 接手、反馈与验收

收到开发者凭证后，先用 CLI 的 status 或 MCP 核对项目、身份和权限。选择 MCP 时主动连接：调用 gc_connect_credential，传入用户交付给自己的凭证 JSON 绝对路径。从返回的 connection.id 取得连接编号；后续调用同时传 connectionId 与 credentialFile。工具读取并签名凭证，不要完整输出凭证文件或私钥，也不要扫描其他成员凭证。

1. 调用 gc_project_read 核对项目、身份与权限，再用 gc_task_inbox 和 gc_task_read 读取实时任务、依赖、直属负责人、验收负责人和 revision。导出的 Markdown 与 context 是阅读快照，不能替代当前授权和分工。模块负责人没有具体任务时报告缺口；制作人与主美继续方案、分工和审核，不自行扩大实现范围；用户只要求计划时先交付计划。
2. 如需引擎操作，另行检查引擎 MCP、引擎版本、插件与当前工程连接。GameCreator MCP 管理任务和反馈，引擎 MCP 操作场景与运行验证。复用已有可用环境；编辑场景或工程设置前核对运行状态。
3. 获准执行并实际开始后，用 gc_feedback_submit 报告进行中；遇到阻碍提交受阻与原因。每次写入前读取最新任务 revision，防止覆盖其他助手的更新。
4. 完成自测后，用 gc_feedback_submit 提交待验收，填写成果说明、工程交付路径、测试证据与遗留问题。服务根据任务验收人派送；任务未指定时使用执行人的直属负责人。没有有效且有权限的验收人时会拒绝提交验收，先由管理者补齐分工。进度权限不能自行验收。
5. 保存返回的 feedbackId 和 requestId。通过 gc_feedback_status 确认已收到、待谁验收、通过或退回原因。超时先查 gc_operation_status；同一次写入重试沿用 requestId，不重复生成反馈。旧文件反馈已经提交时先查询原文件处理回执，不再重复提交同一成果。
6. 验收人调用 gc_review_inbox，核对实际效果与证据，使用 gc_feedback_review 通过或退回，必须填写结论。需要任务验收人身份、review 权限与任务范围，仅明确允许的制作人开发与主美制作任务可自验收，其他成员不能验收自己参与执行的任务。通过后同步关联工具和素材进度；里程碑仍需单独确认。
7. 具有项目范围及 team_manage 权限的负责人使用 gc_task_dispatch 派发后续已有任务；新增任务与依赖调整见下方“制作中的任务创建与实时派发”；其他设计及验收标准变更仍走项目内容提交。模块负责人等待验收时可继续其他已分配任务，没有任务则等待下一次指令，不自行开工或持续高频轮询。

直属负责人提供默认汇报关系，任务的明确验收人优先；修改人员负责人不会静默迁移已有任务。反馈进入负责人队列不等于唤醒外部 AI 会话，实际助手接手由现有协作环境安排。

连接或工具不可用时，报告具体缺失项与服务版本；可以继续阅读文档，但不要宣称已同步成功。旧版逐项目适配器需更新协作文件，全局适配器需重启加载新工具。离线签名文件可在“任务清单 → 反馈记录 → 处理旧版文件反馈”读取处理，文件已生成、系统已收到与验收通过是三个不同状态。
## 测试范围与验收边界

模块负责人完成自测后提交给指定上级审核。高风险或跨模块改动按需要另派独立验证任务，无需固定设置测试岗位，也不要求每项探索任务都经过独立测试。

发放测试任务时明确运行入口、目标构建、玩家可见结果、最高风险和阻塞标准。测试自主安排执行顺序，先查主路径与最高风险，再按改动影响扩展；不要将全部边界作为每轮快速检查必过项。

区分三种检查范围（记录在普通任务说明中）：快速检查验证关键路径与少量风险；缺陷复测重复原步骤并检查受影响路径，共享系统变更扩大相关回归；版本验收按确认的基线集中检查核心路径、历史阻塞、兼容和发布要求。模板见软件“使用帮助 → 测试与验收”。

时间预算由项目按风险和环境成本设定，是软目标。六分钟仅可作为特定项目的试运行参考，不是默认强制时限；超过预算不自动失败，到点不自动通过。先给真实进展简报，需要继续时明确下一轮范围。

模块负责人提供可运行成果、改动范围、自检与已知问题，自检不替代已明确安排的独立测试。测试报告写明实际构建与入口、已执行步骤和结果、实际耗时、缺陷复现与证据、未覆盖项去向及下一步建议。未测试不能写成通过，无法复现不能猜测已修复；严重程度按玩家影响与恢复成本判断，偶发或边角不等于非阻塞。

制作人或指定负责人审核证据、协调修复与补测并作验收判断，不重复执行常规检查；仍可体验关键节点或按风险抽查，不以亲自测试次数为零为目标。沿用实际授权；仅明确允许的制作人开发与主美制作任务可自验收。

测试报告满足本轮约定且经审核后，测试任务可以完成，即使报告发现缺陷；被测功能、修复任务及里程碑分别验收。报告有效不等于功能通过，时间用完也不等于报告交付完成。

未覆盖项明确为下一轮补测、本阶段由负责人说明理由接受风险，或不在本轮范围并标明后续安排。既定关键验收条件必须补测或先经正式变更，不能静默放行。后续发布不能仅依赖测试报告完成，还需核对修复和版本验收条件。

使用现有任务说明、验收要求、结果与证据字段；报告完成后保留历史，后续修复或补测关联原任务。当前流程不自动计时或放行，也不修改已有任务验收标准。自动操作通过不证明真人理解或趣味性，需要时单独组织体验验证。

## 制作中的任务创建与实时派发

先连接 GameCreator 并读取当前排期。工作包 Markdown 只说明计划；设计草稿提交成功也不表示已应用。只有正式写入并返回派发回执后，才能报告“任务已创建并派发”；执行助手实际开始后反馈“进行中”，不能把已派发当成已接手。

1. 调用 gc_project_read，读取 project-schedule，取得专用 scheduleRevision。它是排期版本，不是整个项目的 revision，也不是设计提交的 snapshotId。需要调整已有任务时，再用 gc_task_read 获取该任务的 revision。
2. 已有任务直接用 gc_task_dispatch。新增单项任务用 gc_task_create：传 scheduleRevision、task、assigneeId、可选 reviewerId、reason 和唯一 requestId。task 必填 id（新 UUID）、title、description、kind、acceptance；可填写 priority、milestoneId、dependencyIds、计划 start/end、positionIds、references、workScope、integrationTaskIds 和 selfReviewRole（兼容旧 producerSelfReview）。里程碑、岗位与引用使用现有 ID。新任务只能是待开始，不能写实际完成时间、验收结果或伪造分工历史。
3. 单独调整前置任务用 gc_task_dependencies_update：传 taskId、任务 revision、scheduleRevision、完整的新 dependencyIds、reason、requestId。待验收与已完成任务禁止直接改依赖；正在进行的任务新增未完成前置时，确认将限制后续非受阻进度提交，再传 acceptImpact=true。原进度、成果和反馈保留，调整原因及依赖前后值进入排期变更记录。
4. 如果“新增集成任务”与“盲测必须等集成完成”是一组安排，用 gc_task_plan_apply 同时提交 creates 和 dependencyUpdates。新任务先生成唯一 ID，在同批依赖中引用；每批最多 50 项操作。整批检查任务、执行人、验收人、依赖存在性与无环，任意一步失败均不留下部分创建或派发。
5. 检查写入返回的 status=succeeded 与 result。result 包含 receiptId、新 scheduleRevision、created 与 updated；创建结果含 taskId、revision、assigneeId、reviewerId、dispatchId 和 delivery=task_inbox。用 gc_task_inbox / gc_task_read 核对，制作人在“任务清单 → 我派发的”查看正式任务。原长期凭证自动获得新分配的任务范围，不需要换令牌或先导出快照。
6. 超时先用同一 requestId 查询 gc_operation_status，重试保持编号与参数不变。版本过期时重新读取、评估后发起新的请求；同一个任务 ID 不能重复创建。编辑器有未保存内容会拒绝写入，保存后再重试。
7. 执行助手读取实时任务和排期变更记录，按依赖推进，提交进度、成果与证据；指定验收人通过或退回，再安排下一轮。未验收的前置任务会阻止后续进行中或待验收提交，但仍允许报告受阻。

制作人向主美派发方案任务时，只需选择主美的 assigneeId，task.positionIds 可省略；系统将未指定岗位的任务归到主美，并默认由派发的制作人验收。主美提交方案后，由制作人通过或退回。原型期主美直接承担明确的本人制作任务；需要扩编时，主美向模块负责人另建任务，按需要依赖方案任务并指定自己为 reviewerId；不要将方案任务改派给执行人。明确填写的岗位约束及已有验收人保持有效。

权限：创建并派发需要项目范围、project_write 的 project-schedule 模块授权，以及 team_manage；单独修改依赖或里程碑归属需要上述排期写入权，不要求 team_manage。验收人还需有效身份、review 权限和任务范围；仅明确允许的制作人开发与主美制作任务可自验收。直属负责人名称不会自动赋权。

玩法、需求说明、验收标准和其他模块的大批正式设计变更仍使用内容提交链路。实时排期工具与设计提交共用正式 project-schedule；排期变更记录属于系统审计，不通过设计草稿修改。工具写入成功会刷新当前客户端，但不会自动唤醒外部 AI 会话。

## 已有任务关联里程碑

先派任务、后建版本里程碑时，不重复创建或派发任务。读取 gc_project_read.scheduleRevision，并用 gc_task_read 获取每项任务的 revision，再调用 gc_task_plan_apply 的 milestoneUpdates；每项填写 taskId、revision、milestoneId。单项操作也可用 gc_task_milestone_update。milestoneId 为空字符串表示移回未分组，非空时必须是当前项目中已存在的里程碑 ID，不按任务标题推测归属。

milestoneUpdates 可与 creates、dependencyUpdates 同批提交，合计最多 50 项。同一任务同时调整依赖和归属时，两项都使用本次读取的原任务 revision。所有校验通过才整批保存。返回 milestoneUpdates 中的前后归属和新任务 revision，以及 affectedMilestones 的实时 completed、total、ready 与 requiresReacceptance。重复 requestId 查询原回执，不重复写审计。

已完成、待验收任务也允许仅调整归属；任务状态、分工、依赖、成果和原反馈快照保留。仅归属变化不阻止原成果验收，说明、验收标准、分工、依赖或成果变化仍需重新核对。已验收里程碑的任务构成改变后回到进行中，保留历史结论，由管理者重新确认。空里程碑不能验收。

## 设计提交基准与最小范围准备

gc_project_read 的 contentSnapshotId 是当前内容摘要；snapshotId 只有当前内容已有完整、已登记的基准时才有值，否则为 null。baseline.status 区分 current、stale、missing；availableSnapshotId 是仍可用的历史基准，不能当作最新内容快照。旧基准仍可走三方合并，但必须核对差异与冲突。

需要按最新内容编写时，读取 revision 以及 baseline.prepareWrites，调用 gc_content_baseline_prepare({revision,requestId})，使用 result.snapshotId 构造草稿，再执行 validate → submit → scan → preview → apply。该工具只写 ai/context/snapshots/<snapshotId>.json 并更新项目中的基准登记；不重写 ai/project.json、模块文档、指南或工具。它不替代需要更新阅读资料时的完整协作文件导出。

基准校验失败时查看 diagnostics 中的 submittedSnapshotId、currentSnapshotId、availableSnapshotId、reason 和 refreshTool。未登记、缺失或被修改与普通内容版本变化分别报告；不要只凭一个实时摘要假定提交基准已经存在。版本冲突需重新读取评估；超时沿用 requestId 查询 gc_operation_status。



### 编写或重组设计

可从 [打开 ai/WORKFLOW_MCP.md](<file:///E:/Docs/%E8%BF%99%E6%AC%A1%E6%80%8E%E4%B9%88%E9%80%83/ai/WORKFLOW_MCP.md>) 查看 AI 工作流工具，从软件“MCP 连接”复制全局接入配置；[打开 ai/mcp.config.example.json](<file:///E:/Docs/%E8%BF%99%E6%AC%A1%E6%80%8E%E4%B9%88%E9%80%83/ai/mcp.config.example.json>) 仅用于兼容旧版逐项目接入。工具提供读取、校验、签名提交、差异检查、应用和工程同步，使用当前开发者凭证授权。

1. 进入上述 GameCreator 项目，核对 project.gamecreator 中的项目 ID，阅读 [打开 PROJECT_STANDARDS.md](<file:///E:/Docs/%E8%BF%99%E6%AC%A1%E6%80%8E%E4%B9%88%E9%80%83/PROJECT_STANDARDS.md>)、[打开 GAMECREATOR_GUIDE.md](<file:///E:/Docs/%E8%BF%99%E6%AC%A1%E6%80%8E%E4%B9%88%E9%80%83/GAMECREATOR_GUIDE.md>) 和 [打开 ai/README.md](<file:///E:/Docs/%E8%BF%99%E6%AC%A1%E6%80%8E%E4%B9%88%E9%80%83/ai/README.md>)。
2. 在 GameCreator 的“项目管理 → 项目内容同步”更新协作文件，然后读取该目录的 ai/project.json、ai/context 与模板。
3. 在 **GameCreator 项目根目录**运行：

```sh
node ai/submit-change.cjs validate ai/draft.json
node ai/submit-change.cjs submit ai/draft.json <本开发者凭证的绝对路径>
```

4. 设计提交写入该项目的 ai/changes；管理者在“项目内容同步 → 设计提交”读取、处理冲突并应用。查看 ai/receipts 确认结果。

### 开发反馈与下一轮

开发进度与任务验收使用上面的实时 CLI 或 MCP 流程；已有需求建议、工具反馈和离线签名反馈仍可通过引擎工程 gamecreator/feedback 提交，在“任务清单 → 反馈记录 → 处理旧版文件反馈”处理；完整的跨模块设计编写使用上面的 ai/changes 流程。两种快照和提交格式不可混用。

根据实际效果决定修复实现还是调整需求；代码当前行为不自动成为已验收标准。变更应用后，重新同步工程文档与协作上下文，再继续开发。正式配置另走“数据同步”的导入、导出与冲突处理。

这些 Markdown 是同步副本，直接编辑不会回写 GameCreator；不要直接修改项目 archives 或只读上下文。目录搬迁后重新连接并同步入口。


# GameCreator 开发协作

项目：这次怎么逃

## 使用方式

1. 先读 [本项目自定义规范](../docs/gamecreator/modules/project-management/standards.md)，再读 project.json、context/tasks.json、context/tools.json 和项目设计文档。ID 是稳定身份，名称不可代替 ID。
2. 开始开发时反馈“进行中”；实现后建议反馈“待验收”，并写明测试结果、未完成项和交付入口。
3. 每个反馈文件只更新一个任务、工具或项目模块，放在 feedback/<更新编号>.json，使用 UTF-8 JSON。每次新反馈使用新的 UUID。先写 .tmp 文件再重命名为 .json，避免读取半写入文件。
4. GameCreator 的“任务清单 → 反馈记录 → 处理旧版文件反馈”会读取并比较差异，由用户应用或忽略。receipts/ 保存处理回执。重复读取不会再次应用；已处理的反馈请勿修改。
5. 收到回执后再次同步上下文，基于最新快照继续开发。

## 岗位工作与协作令牌

### 制作人职责与交接边界

制作人默认负责目标、内容方案、设计基线、团队授权、任务分配、协调和验收。主美兼技术美术，负责表现与技术方案、美术和音效任务派发及审核；模块负责人完成各自模块，制作人维护主干并执行明确分配给自己的程序与集成任务。可以读取工程代码、运行已有原型、检查日志和测试证据，依据实际效果调整设计。开发授权以明确任务为准，制作人可以在自己的程序或集成任务范围内编写代码与场景，不自动接管别人的模块。

制作人依据真实测试报告作验收决策，无需逐项重跑常规测试；仍可体验关键节点或按风险抽查。测试任务交付报告，被测功能与里程碑分别验收，发现缺陷不等于报告无效。具体自测由各任务执行人完成，需要独立验证时另行分派，避免重复验收成为交付瓶颈。

项目范围、project_write 和 team_manage 表示管理项目的访问或操作授权，不等于承接所有岗位的制作任务。零个人任务不等于等待：继续完善设计、拆解依赖、准备工作包、协调阻塞并组织验收。完成设计和分工后，下一步是交接与跟踪；不能因“推进项目”“验证设计”“先做灰盒”而自行接替执行岗位。

工作包应说明接收人的成员 ID、岗位及任务 ID、两边项目入口、已应用的设计基准、前置依赖、允许修改的范围、交付位置、验收步骤和反馈方式。每位助手只使用自己的凭证；制作人分发其他成员的凭证，不借用它们切换身份执行任务。

创建身份或签发令牌不等于实际 AI 已接手。有已获授权的助手调度工具时，按工作包派发并核对接收结果；没有工具或尚未接入执行助手时，交付可直接使用的工作包，报告“待接入执行助手”及所缺条件。此时仍可推进其他管理工作，不自行代做，也不把任务标成进行中、完成或已验收。接手状态写入现有说明或交接记录，不新增任务状态枚举。

制作人承接核心程序和主干集成时，使用现有制作人身份、有效权限和明确的本人任务，无需创建第二身份或添加模块负责人岗位。具有排期写入与团队管理授权时，可以按已确认方案创建并派发自己的开发任务。其他兼任需明确授权与分配，不能借用令牌、扩大权限或接管别人任务。明确允许的制作人本人独立开发/集成任务可自验收，仍需先提交证据，再单独给出验收结论。

阶段汇报分别列出：设计已提交/已应用、身份已建立、工作包已交付、实际助手已接手、引擎成果已实现/已验收。分配后应说明由谁执行、下一次检查点和当前阻塞，不默认承诺“接下来我实现原型”。

上述是岗位执行约定。GameCreator 校验其接口内的授权，当前并不据此拦截外部终端或引擎工具的文件写入；工程操作的技术隔离须由 AI 运行环境与引擎工具落实。

制作人先检查设计与团队，建立最小范围和验收基线，零个人任务时继续设计、分工和协调；分工后交接给实际助手并跟踪，不默认自己实现原型。沿入口文档找到绑定的 GameCreator 管理项目，阅读 ai/WORKFLOW_MCP.md 连接设计与同步工具，并阅读 ai/TEAM_MANAGEMENT.md；具有 team_manage 的制作人可运行该目录的 manage-team.cjs 创建主美与模块负责人并签发令牌。工作说明 .md 不是私有凭证。

启用人员分配后，先读 context/team.json、context/assignments.json 与 assignments/<令牌ID>.md，members/<执行者ID>.md 汇总执行分配。岗位描述要做什么；每个长期令牌代表一个开发者，可暂不指定任务，后续调整职责、岗位、权限和任务时继续使用同一令牌。已分配任务范围仅允许明确选择的工作；岗位范围包含所选岗位的后续任务；项目范围可用于零任务的制作人管理项目。范围不等于个人工作量，只有明确分配的任务计入个人任务。反馈权限和有效期以 GameCreator 当前授权为准。在“项目管理 → 工程同步”开启成员凭证并同步后，完整凭证位于所选协作入口目录的 personal/<成员ID>.json；尚未导出时由管理者单独交付。不得放入公共文档、反馈文件或版本库。工程同步复用已有令牌，不重新签发；开启成员凭证同步后会预览新增、更新和待移除凭证。

使用 Node.js 运行：

`node gamecreator/submit-feedback.cjs <私有凭证文件> <反馈草稿.json> gamecreator/feedback`

辅助工具会签名并添加 identity，不会将私钥写入反馈。草稿的 intent 为 progress（制作进度，默认）、review（验收结论）、propose（分工/排期建议）、spec_change（需求与验收变更建议）或 project_change（正式项目修改）。后两种需要独立权限、原因与影响说明，详见 [需求与项目修改](project-changes.md)；不会混入一键应用。执行成员提交待验收；提交已完成或可使用需要 review 权限。长期开发者必须有目标范围和 review 权限；旧版工作令牌仍受原选中任务限制，旧版成员令牌仍要求指定验收负责人或项目范围。propose 仅支持 task 的 result 文本，应用后追加到任务建议，不覆盖进度和结果。工具反馈根据引用该工具的制作任务核验授权。

改名或调整任务不改变成员与令牌 ID。管理者可在开发者与令牌页签重新复制凭证。任务范围、开发者和岗位启用状态、权限、有效期与撤销情况均按最新状态核验；项目范围无需逐一分配任务。未签名的旧反馈在启用 AI 团队后需逐条核实，不能一键应用。原始 author 文字不代表身份。实时任务进度与验收通过 gc_feedback_submit / gc_feedback_review 处理，离线文件反馈仍在 GameCreator 中读取处理；设计变更可通过已授权的 MCP 工具或客户端预览并应用；独立 team_manage 签名命令按授权直接管理团队。

## 文件约定

- context/ 与 project.json 由 GameCreator 生成，请勿修改。历史 snapshots/ 保留旧反馈的比较基准。
- feedback/ 由开发者、AI 助手或引擎工具写入。receipts/ 由 GameCreator 写入。
- 本目录用于开发协作，发布游戏时按工程规则排除。反馈中的路径、命令和链接仅作为说明，不会被自动执行。
- 单机工程无需额外服务器；反馈格式与引擎语言无关。

## 反馈格式

从 project.json 复制 projectId、engine、snapshotId。target.kind 为 task 或 tool；target.id 从对应上下文复制。

```json
{
  "schema": 1,
  "projectId": "project-10beb421-66ef-416e-8bcb-abf7bba4cd5c",
  "engine": "godot-gdscript",
  "id": "00000000-0000-4000-8000-000000000001",
  "snapshotId": "bd5b473b0ec47123d69083389cf14bc6ff05c7b828ab95eb4e34829e30c3a49f",
  "target": {
    "kind": "task",
    "id": "复制真实任务ID"
  },
  "author": "开发者或 AI 助手名称",
  "summary": "说明本次开发进展",
  "evidence": [
    "提交号、相关文件、运行入口、测试结果（如有）"
  ],
  "changes": {
    "status": "待验收",
    "result": "已实现内容、测试情况与剩余问题"
  }
}
```

上例仅为模板，必须替换更新编号与真实目标 ID 后提交。

## 允许回写的字段

- task：status（待开始/进行中/待验收/已完成/受阻）、actualStart、actualEnd（YYYY-MM-DD 或空字符串）、result（开发结果或受阻原因）。
- tool：status（待开发/开发中/待验收/可使用/停用）、usage（使用说明）、delivery（交付位置与测试结果）。
- changes 只填写本次要改的字段；未填写的字段保持原值。
- evidence 是文本数组，author 与 summary 必填。
- 标记“已完成”或“可使用”需要在 GameCreator 内核实验收。在 GameCreator 中，工具关联任务全部完成后同步为可使用；素材关联的美术任务全部完成后同步素材状态为已完成，退回任务也会更新素材状态。里程碑仍由管理者确认验收。
- 美术素材直接生成在游戏工程内，无需上传到 GameCreator。查看素材制作文档并按 context/tasks.json 中的 requirement/asset 引用定位对应美术任务；通过任务反馈 status 与 result 回写进度，在 result 中填写交付路径、验证结果与未完成项。路径按文档要求填写，不会自动执行。没有明确关联时请先在 GameCreator 中关联美术任务，不要根据名称猜测。
- 需求与验收标准通过 spec_change 提建议；项目范围且具有 project_write 权限的长期开发者可通过 project_change 修改已有项目内容与计划字段。详见 [需求与项目修改](project-changes.md)。新增、删除及跨模块结构变更通过绑定的 GameCreator 项目 ai/changes 提交；人员授权在 GameCreator 人员分配管理。
- 同字段两边同时修改会显示冲突；设计要求变化也会提示复核。


完整项目编写协议保存在绑定的 GameCreator 项目根目录 GAMECREATOR_GUIDE.md。
