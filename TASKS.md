# TASKS

故事来源：亚瑟王与梅林传说（公版，完整一生） · 玩家身份：梅林的学徒（原创） · 玩法参考：战斗照杀戮尖塔、地图和成长照 Vampire's Fall 2 · 引擎：Godot 4 · 故事体量：一包 6 章 + 2–4 条支线 · 成色：可玩原型 · 交付：网页链接 + 新建 GitHub 仓库

## 当前状态（每轮结束更新；对话压缩后先读这里）
- 做到哪：第 10 步白盒按新玩法重做完（2026-11-09），到白盒试玩停靠点
- 下一步：用户试玩白盒，按四条硬门槛和复盘题判；判继续以后第 11 步范围复盘
- 项目主页：https://claude.ai/artifact/7GrrutxtorkDnBVH2DNaTN （每步重跑 render_site.py，更新同一个页面）
- 仓库：https://github.com/salt-byte/arthur-rpg ，每步交接前提交并推送。旧白盒网页版在 docs/，GitHub Pages 打开后在 https://salt-byte.github.io/arthur-rpg/ 玩
- 卡在哪：无
- 最近一次 verify：2026-11-09 20261109-115232 整体 PASS（qa/verification.json）；--playtest 路线 a、b、c 都 PASS
- 停靠点：A0 ✓ · A1 ✓（2026-11-06 重过） · A2 ✓ · B ✓ · 白盒 等你试玩 · C 未到 · D 未到

状态：[ ] 待做 · [~] 进行中 · [x] 完成 · [!] 被退回
行号就是「第 N 步」：按做的顺序从 1 编到底；每做完一行，提交并推到仓库，按 producer 第 6 节交接，等用户点头再做下一行。2026-11-06 按插件 0.7.0 重排：加了第 1 步建仓库、第 4 步玩法原型，共 20 步。

| # | 状态 | 任务 | 交给 | 依赖 | 层 | 验收标准 | 认领 / 结果 |
|---|---|---|---|---|---|---|---|
| 1 | [x] | 建 GitHub 仓库，推上 GAME_BRIEF、TASKS、DEVLOG、README；发布项目主页 | producer | — | — | 仓库链接点得开，main 上有这四个文件和 .gitignore；项目主页（render_site.py）发布成页面，链接写进当前状态；之后每一步交接前提交并推送、更新项目主页（producer/references/github-sync.md） | 仓库 salt-byte/arthur-rpg（公开）2026-11-05 建，每步交接前推送；项目主页 2026-11-06 补发（插件 0.7.0） |
| 2 | [x] | 世界与故事：世界观、人物卡、因果主线、分章梗概（故事圣经上半） | story-bible（改编作品先 story-extraction） | 1 | — | bible.md 上半有世界硬规则、势力、地点；每个重要人物一张卡（不含认知边界）；因果主线每个转折有中间环节；分章梗概章数和 GAME_BRIEF 一致，改编标原作出处、补写的标出来；用户在 A0 同意 | content/story/bible.json + bible.md 上半、source_extraction.md（38 条事件、7 条补写）。定调题：温情里带刺、忠实改编、主角动机=家人与继承者。检查：6 章、8 张人物卡关键字段不空、钩子 4/3/4/3/5/5；A0 通过 |
| 3 | [x] | 写概念页和系统清单，过硬否决 | game-concept | 2 | — | CONCEPT.md 七节都有内容、七条硬否决逐条有依据；第一章的例子用梗概的第一章、中心张力对着上半查；三层循环每层写得出玩家在做什么、为什么有意思、照哪个游戏的哪套规则（「自创」的进了最大风险候选）；想要的感受、三种需要、支柱和不做清单都有 | 类型：CRPG 对话抉择 + 大地图明雷 + JRPG 回合制；定调：纯选择、意图预告、明雷、叙事进展（沿用：检查点重试、同伴系统、3–5 回合）。七条硬否决全过（第 3 条待白盒）；系统 14 个，mvp 7 个；「不做经验和等级」A1 已确认；A1 通过。2026-11-06 改：玩法参考换成战斗照杀戮尖塔、地图和成长照 Vampire's Fall 2，补「想要的感受」「三层循环」（每层写照哪个游戏），最大风险改成「两次看水面之间没什么可玩」；「支柱和不做清单」「三种需要」A1 前补 |
| 4 | [x] | 玩法原型：拿 CONCEPT 的最大风险做一个半天到一天、用完就扔的原型，用户玩过再判结论 | gameplay-prototype | 3 | — | PLAN.md 动手前写好假设和留下 / 放弃 / 调参数三种信号；有人玩过（自己玩或别人玩），复盘五题逐题问过；REPORT.md 写了结论和回填；结论是继续；用户在 A1 同意 | 两个网页原型：怎么打（prototypes/how-to-fight/）→ 继续，打法定行动版，最后一场调过数；两次看水面之间（prototypes/between-visions/）→ 未评估，用户结束原型阶段，最大风险移到第 10 步白盒验证。A1 通过（2026-11-06） |
| 5 | [x] | 玩家在故事里：每章的决定和后果、认知边界、伏笔、facts（故事圣经下半） | story-bible | 2,4 | — | bible.json 的 facts 每条有 known_by；伏笔都有回收章；建 CONTENT_SCHEDULE 填好故事两列 | 定调：信息同步、学徒自己 3 个结局、4 条支线。10 个决定（主线 5 + 支线 4 + 结局 1），29 个选项；17 条 facts、12 条伏笔；19 个人物加了认知边界和别名。脚本检查：每个选项 2 章内有回读、facts 都有 known_by、伏笔都有回收章，0 问题 |
| 6 | [x] | 剧情谱 + 审查 | story-map, story-review | 5 | — | 剧情谱无空卡片、钩子曲线有峰值；审查报告给用户反驳；用户在 A2 同意 | outline.json（32 节点、4 支线、3 结局）+ story.html 已发布；走一遍三个结局都走到、0 空卡片、0 无结果选项。独立审查 20 条（🔴5 🟠12 🟡3），核验后全部保留。两轮修改：第一轮 20 条，复查 14 好 6 部分好 + 10 处新问题，第二轮全部补完，脚本核对 0 问题；剧情谱 30 节点、条件选项上线；A2 通过 |
| 7 | [x] | mvp 层每系统一页设计页，参数登记进 content/data/ | game-design | 4,6 | mvp | 每页上下两层齐全（一句话、例子、感受、规则 / 公式、边界、依赖、参数、验收、素材）；GDD.md、ui/SCREENS.md、CONTENT_SCHEDULE.md 玩法列按已定章节填好；代码里的数都能在设计页和 data/ 找到；公式和可调参数的起始值取自原型报告；每页有「体验」验收条件和退化打法；每页开头写了照哪个游戏，照原作的规则和数字附维基或攻略链接，规则表每条标了照原作 / 改了 / 自创 | 定调：目标优先级、你操作所有人、混合指引、只做关键几处。7 页设计页 + 7 个参数文件 + GDD（两张图）+ SCREENS（19 屏）+ 章节内容表玩法列；「设计总览」页面已发布。脚本核对：每个法术、同伴的招、敌人在章节内容表里都有第几章出现；每个面板在界面清单里有一行；三张流程图能渲染。CONCEPT 改两处（地图敌人、第一章例子）并记了改动。2026-11-06 退回：玩法参考改了，原型之后按新参考改：combat.md 照杀戮尖塔核对规则和数字，overworld.md 照 Vampire's Fall 2，补成长和装备两页，每页开头写「照」那一行。2026-11-06 重做：定调题（成长：技能点加进几棵树；装备：打怪随机掉；敌人：打死就没了，用户纠正）。combat.md、overworld.md 重写，progression.md、items.md 新写，story-unlocks.md 改了和升级、装备的分工；每页开头有「照」那一行，规则表逐条标出处；第 1 章战斗数取自原型报告；经验曲线用脚本按「只打必须打的 / 全打」两条线反推。九页设计页 + 九个参数文件；GDD 四张图（新加「变强从哪来」）、SCREENS 加 6 屏、章节内容表加「成长和装备」一列；check_style 禁用 0 条，check_project_data 0 个错误 |
| 8 | [x] | 定数据格式、搭工程 | game-data-schema, godot-project-structure | 7 | mvp | 空项目能 headless 运行、能导出网页；对白/变量/任务/NPC/刷新/文本表各有样例 | 定好本作的数据格式（content/README.md）：变量由 bible.json 生成 54 个；任务表 10 条（主线步骤 = 剧情谱节点）；新加 6 个指令；遭遇表；第 1 章样例对白 65 行和 NPC、刷新点、文本表 131 条。check_content 0 错误（6 条提醒是新指令）、tools/check_project_data.py 0 错误。Godot 4.3 工程骨架：--playtest 跑完第 1 章样例三条路线全过（变量、任务、能力、预言簿、存读档）；网页导出 35MB，无头浏览器里打开 0 报错。证据 qa/evidence/step6/ |
| 9 | [x] | 美术方向 + 目标图；界面观察 | art-direction, ui-layout | 4,7 | — | ART_DIRECTION 一页 + 1–2 张目标图；用户在 B 同意 | design/ART_DIRECTION.md、design/targets/ 两张、CREDITS.md 已交；没有玩法参考，界面观察跳过，风格契约写在 ART_DIRECTION 第 4 节；B 通过 |
| 10 | [x] | 白盒切片：色块地图 + 占位 NPC，围着最大风险做一章 + 一战 + 一次成长（升级，或剧情给的新招，照 CONCEPT）：第 1 章狼群和梅林的影子两场小仗、地图上的明雷、一次升级、一次看水面、一次说给谁听，接到第 2 章教堂那一幕应验 | world-map, combat-system, dialogue-authoring, quest-design, playtest-automation（白盒门槛和复盘）；写代码前先读 mechanics-library 对应的参考代码 | 7,8 | mvp | verify.py 六项 PASS；按垂直切片四条硬门槛判（没人指导走完一圈、前 2 分钟知道干什么、核心机制感觉好、没有致命 bug），复盘题逐题问过，结论是继续；用户在白盒试玩停靠点同意 | 2026-11-09 按新玩法重做（DEVLOG 第 21 节）：参考代码 intent-battle、overworld-grid、xp-progression、random-affix-loot 带进 scripts/mechanics/，自带测试 62 个用例全过。森林 32×18，四群会走动、会追的敌人，头狼群堵在去石圈的路上，林边石龛、空心老橡树的包袱；战斗照杀戮尖塔，血带出战斗、喝药、逃跑；经验 N³、升级挑奖励加点、装备三格带词缀；结尾有试玩记录。verify.py 20261109-112111 六项 PASS；--playtest 三条路线 PASS（全打 28 经验 3 级、只打必须的 12 经验 2 级，和成长页对上）；网页版无头浏览器能进游戏。等用户试玩：四条硬门槛和复盘题、最大风险的留下 / 放弃信号都在白盒试玩时问 |
| 11 | [ ] | 范围复盘 ① | producer | 10 | — | GAME_BRIEF 范围复盘表填了一行 |  |
| 12 | [ ] | 任务链 + 对白（每章过 knowledge_check 和 story-review） | quest-design, dialogue-authoring | 6,10 | playable | check_content.py 零错误；knowledge_check 候选逐条判过 |  |
| 13 | [ ] | 地图、战斗、成长、存档、检定（照设计页，用不到的划掉） | world-map, combat-system, progression-system, save-load, skill-checks（CRPG 检定时）；写代码前先读 mechanics-library 对应的参考代码 | 7,10 | playable | --playtest 打印和设计页验收条件一一对上；存读档一致；参考代码里列的坑逐条对照过 |  |
| 14 | [ ] | 按美术路线备素材（找开源 / AI 生图 / 收用户上传的）并核对许可，处理素材，做角色动画，统一画风 | asset-sourcing / asset-generation / asset-upload（照 GAME_BRIEF 的美术路线）, asset-pipeline, cutout-animation（选了骨骼拆件时）, style-consistency | 9 | playable | 素材清单 + 许可证 + CREDITS；处理脚本的提醒逐条处理过；角色每个动作有预览 GIF；留存截图无透明块、无绿边、无遮挡 |  |
| 15 | [ ] | 范围复盘 ② | producer | 12,13 | — | GAME_BRIEF 范围复盘表第二行 |  |
| 16 | [ ] | 界面（含触屏操作）、文本表 | ui-layout, localization-table | 9,13 | playable | 每屏留存截图；无方块字 |  |
| 17 | [ ] | 证据化验证 | playtest-automation | 12,13,14,16 | — | verification.json 六项 PASS，同一次运行 |  |
| 18 | [ ] | 停靠点 C：第一个可试玩版本 | producer | 17 | — | 用户按 3–5 个具体问题试玩并反馈 |  |
| 19 | [ ] | 数值模拟与调整 | balancing | 18 | full | 模拟曲线和设计页验收条件对上 |  |
| 20 | [ ] | 发布 | web-release | 19 | — | 发布前清单全过；网页版在无头浏览器里能进游戏、能触发对话；用户在 D 同意 |  |
