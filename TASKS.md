# TASKS

故事来源：亚瑟王与梅林传说（公版，完整一生） · 玩家身份：梅林的学徒（原创） · 玩法参考：不指定 · 引擎：Godot 4 · 故事体量：一包 6 章 + 2–4 条支线 · 成色：可玩原型 · 交付：网页链接 + 新建 GitHub 仓库

## 当前状态（每轮结束更新；对话压缩后先读这里）
- 做到哪：第 6 步完成，等用户答第 7 步的定调题
- 下一步：第 7 步 · 美术方向 + 目标图；界面观察（art-direction、ui-layout）——先问定调题（视觉基调、最先看清什么）
- 仓库：https://github.com/salt-byte/arthur-rpg （2026-11-05 建好，到第 5 步为止的产物已推上去）。插件 0.5 起建仓库是第 1 步；本项目已做到第 5 步，行号不改，仓库算在第 6 步之前补做。之后每步交接前提交并推送
- 卡在哪：无
- 最近一次 verify：NOT_RUN（verify.py 第 8 步白盒时接上）；--playtest 第 1 章样例三条路线 PASS（2026-11-05）
- 停靠点：A0 ✓ · A1 ✓ · A2 ✓ · B 未到 · 白盒 未到 · C 未到 · D 未到

状态：[ ] 待做 · [~] 进行中 · [x] 完成 · [!] 被退回
行号就是「第 N 步」：按做的顺序从 1 编到底；每做完一行，按 producer 第 6 节交接，等用户点头再做下一行。

| # | 状态 | 任务 | 交给 | 依赖 | 层 | 验收标准 | 认领 / 结果 |
|---|---|---|---|---|---|---|---|
| 1 | [x] | 世界与故事：世界观、人物卡、因果主线、分章梗概（故事圣经上半） | story-bible（改编作品先 story-extraction） | — | — | bible.md 上半有世界硬规则、势力、地点；每个重要人物一张卡（不含认知边界）；因果主线每个转折有中间环节；分章梗概章数和 GAME_BRIEF 一致，改编标原作出处、补写的标出来；用户在 A0 同意 | content/story/bible.json + bible.md 上半、source_extraction.md（38 条事件、7 条补写）。定调题：温情里带刺、忠实改编、主角动机=家人与继承者。检查：6 章、8 张人物卡关键字段不空、钩子 4/3/4/3/5/5；A0 通过 |
| 2 | [x] | 写概念页和系统清单，过硬否决 | game-concept | 1 | — | CONCEPT.md 七节都有内容、七条硬否决逐条有依据；第一章的例子用梗概的第一章、中心张力对着上半查；用户在 A1 同意 | 类型：CRPG 对话抉择 + 大地图明雷 + JRPG 回合制；定调：纯选择、意图预告、明雷、叙事进展（沿用：检查点重试、同伴系统、3–5 回合）。七条硬否决全过（第 3 条待白盒）；系统 14 个，mvp 7 个；「不做经验和等级」A1 已确认；A1 通过 |
| 3 | [x] | 玩家在故事里：每章的决定和后果、认知边界、伏笔、facts（故事圣经下半） | story-bible | 1,2 | — | bible.json 的 facts 每条有 known_by；伏笔都有回收章；建 CONTENT_SCHEDULE 填好故事两列 | 定调：信息同步、学徒自己 3 个结局、4 条支线。10 个决定（主线 5 + 支线 4 + 结局 1），29 个选项；17 条 facts、12 条伏笔；19 个人物加了认知边界和别名。脚本检查：每个选项 2 章内有回读、facts 都有 known_by、伏笔都有回收章，0 问题 |
| 4 | [x] | 剧情谱 + 审查 | story-map, story-review | 3 | — | 剧情谱无空卡片、钩子曲线有峰值；审查报告给用户反驳；用户在 A2 同意 | outline.json（32 节点、4 支线、3 结局）+ story.html 已发布；走一遍三个结局都走到、0 空卡片、0 无结果选项。独立审查 20 条（🔴5 🟠12 🟡3），核验后全部保留。两轮修改：第一轮 20 条，复查 14 好 6 部分好 + 10 处新问题，第二轮全部补完，脚本核对 0 问题；剧情谱 30 节点、条件选项上线；A2 通过 |
| 5 | [x] | mvp 层每系统一页设计页，参数登记进 content/data/ | game-design | 2,4 | mvp | 每页上下两层齐全（一句话、例子、感受、规则 / 公式、边界、依赖、参数、验收、素材）；GDD.md、ui/SCREENS.md、CONTENT_SCHEDULE.md 玩法列按已定章节填好；代码里的数都能在设计页和 data/ 找到 | 定调：目标优先级、你操作所有人、混合指引、只做关键几处。7 页设计页 + 7 个参数文件 + GDD（两张图）+ SCREENS（19 屏）+ 章节内容表玩法列；「设计总览」页面已发布。脚本核对：每个法术、同伴的招、敌人在章节内容表里都有第几章出现；每个面板在界面清单里有一行；三张流程图能渲染。CONCEPT 改两处（地图敌人、第一章例子）并记了改动 |
| 6 | [x] | 定数据格式、搭工程 | game-data-schema, godot-project-structure | 5 | mvp | 空项目能 headless 运行、能导出网页；对白/变量/任务/NPC/刷新/文本表各有样例 | 定好本作的数据格式（content/README.md）：变量由 bible.json 生成 54 个；任务表 10 条（主线步骤 = 剧情谱节点）；新加 6 个指令；遭遇表；第 1 章样例对白 65 行和 NPC、刷新点、文本表 131 条。check_content 0 错误（6 条提醒是新指令）、tools/check_project_data.py 0 错误。Godot 4.3 工程骨架：--playtest 跑完第 1 章样例三条路线全过（变量、任务、能力、预言簿、存读档）；网页导出 35MB，无头浏览器里打开 0 报错。证据 qa/evidence/step6/ |
| 7 | [x] | 美术方向 + 目标图；界面观察 | art-direction, ui-layout | 2,5 | — | ART_DIRECTION 一页 + 1–2 张目标图；用户在 B 同意 | design/ART_DIRECTION.md、design/targets/ 两张、CREDITS.md 已交；没有玩法参考，界面观察跳过，风格契约写在 ART_DIRECTION 第 4 节；B 通过 |
| 8 | [ ] | 白盒切片：色块地图 + 占位 NPC，围着最大风险做第 1 章：狼群和梅林的影子两场小仗、一次看水面、一次说给谁听、一次剧情给法术，接到第 2 章教堂那一幕应验 | world-map, combat-system, dialogue-authoring, quest-design | 5,6 | mvp | verify.py 六项 PASS；盲玩子 agent 记录出来；用户在白盒试玩停靠点同意 |  |
| 9 | [ ] | 范围复盘 ① | producer | 8 | — | GAME_BRIEF 范围复盘表填了一行 |  |
| 10 | [ ] | 任务链 + 对白（每章过 knowledge_check 和 story-review） | quest-design, dialogue-authoring | 4,8 | playable | check_content.py 零错误；knowledge_check 候选逐条判过 |  |
| 11 | [ ] | 地图、战斗、叙事进展、存档（照设计页） | world-map, combat-system, progression-system, save-load | 5,8 | playable | --playtest 打印和设计页验收条件一一对上；存读档一致 |  |
| 12 | [ ] | 找素材 / 生图并核对许可，处理素材，统一画风 | asset-sourcing（或 asset-generation）, asset-pipeline, style-consistency | 7 | playable | 候选表 + 许可证 + CREDITS；留存截图无透明块、无遮挡 |  |
| 13 | [ ] | 范围复盘 ② | producer | 10,11 | — | GAME_BRIEF 范围复盘表第二行 |  |
| 14 | [ ] | 界面（含触屏操作）、文本表 | ui-layout, localization-table | 7,11 | playable | 每屏留存截图；无方块字 |  |
| 15 | [ ] | 证据化验证 | playtest-automation | 10,11,12,14 | — | verification.json 六项 PASS，同一次运行 |  |
| 16 | [ ] | 停靠点 C：第一个可试玩版本 | producer | 15 | — | 用户按 3–5 个具体问题试玩并反馈 |  |
| 17 | [ ] | 数值模拟与调整 | balancing | 16 | full | 模拟曲线和设计页验收条件对上 |  |
| 18 | [ ] | 发布 | web-release | 17 | — | 发布前清单全过；网页版在无头浏览器里能进游戏、能触发对话；用户在 D 同意 |  |
