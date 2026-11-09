# TASKS

故事来源：亚瑟王与梅林传说（公版，完整一生） · 玩家身份：梅林的学徒（原创） · 玩法参考：战斗照杀戮尖塔、地图和成长照 Vampire's Fall 2 · 引擎：Godot 4 · 故事体量：一包 6 章 + 2–4 条支线 · 成色：可玩原型 · 交付：网页链接 + 新建 GitHub 仓库

## 当前状态（每轮结束更新；对话压缩后先读这里）
- 做到哪：第 15 步分批制作，第一批对白做到一半：初稿写完、五条走查路线跑通、四份审查报告出来、voices.md 定了，审查意见还没改
- 下一步：按审查报告改第 2–6 章和支线对白（先 🔴 后 🟠），同时照 voices.md 调口气；顺带补第 1 步改编策略小节、第 4 步取舍表。对白这批改完复查过，用户用 content/dialogue/script.html 按章读一遍。之后补第 9、10 步（第 2–6 章数值和关卡），再做第 15 步第二批
- 项目主页：https://claude.ai/artifact/7GrrutxtorkDnBVH2DNaTN （每步重跑 render_site.py，更新同一个页面）
- 仓库：https://github.com/salt-byte/arthur-rpg ，每步交接前提交并推送。旧白盒网页版在 docs/，GitHub Pages 打开后在 https://salt-byte.github.io/arthur-rpg/ 玩
- 卡在哪：无
- 最近一次 verify：2026-11-09 20261109-115232 整体 PASS（qa/verification.json）；--playtest 路线 a、b、c 都 PASS
- 停靠点：A0 ✓（第 3 步） · A1 ✓（第 4 步） · A2 ✓（第 6 步） · B ✓（第 11 步） · 白盒 ✓（第 13 步，2026-11-09） · C 未到（第 16 步） · D 未到（第 17 步）

状态：[ ] 待做 · [~] 进行中 · [x] 完成 · [!] 被退回
行号就是「第 N 步」：按做的顺序从 1 编到底；每做完一行，提交并推到仓库，按 producer 第 6 节交接，等用户点头再做下一行。2026-11-06 按插件 0.7.0 排成 20 步；2026-11-09 按插件 0.8.0 改成 17 步，新旧步号对照见 DEVLOG 第 22 节。

| # | 状态 | 任务 | 交给 | 依赖 | 层 | 验收标准 | 认领 / 结果 |
|---|---|---|---|---|---|---|---|
| 1 | [~] | 改编策略定位 | producer | — | — | 五项策略与红线记录并获用户确认 | 开工时定了：忠实改编、完整一生、玩家是梅林的学徒，玩家承诺写在 GAME_BRIEF。按 0.8.0 还缺 GAME_BRIEF「改编策略」小节（五项决定）和单列的改编红线，2026-11-09 补写，等用户确认 |
| 2 | [x] | 建立项目记录 | producer | 1 | — | 任务板、目录和可访问主页就绪；采用 GitHub 时建立仓库 | 旧第 1 步：仓库 salt-byte/arthur-rpg（公开）2026-11-05 建，每步交接前推送；项目主页 2026-11-06 补发（插件 0.7.0） |
| 3 | [x] | 世界观圣经 | story-bible | 2 | — | 世界规则、人物、术语与原作映射有依据；A0 确认 | 旧第 2 步：content/story/bible.json + bible.md 上半、source_extraction.md（38 条事件、7 条补写）。定调题：温情里带刺、忠实改编、主角动机=家人与继承者。检查：6 章、8 张人物卡关键字段不空、钩子 4/3/4/3/5/5；A0 通过 |
| 4 | [~] | 叙事骨架与改编取舍 | story-bible, story-map, story-review | 3 | — | 取舍表、主线、关键选择与结局边界成立；A1 故事地基确认 | 旧第 5、6 步：outline.json（32 节点、4 支线、3 结局）+ story.html 已发布；走一遍三个结局都走到、0 空卡片、0 无结果选项。独立审查 20 条（🔴5 🟠12 🟡3），核验后全部保留。两轮修改：第一轮 20 条，复查 14 好 6 部分好 + 10 处新问题，第二轮全部补完，脚本核对 0 问题；剧情谱 30 节点、条件选项上线；A2 通过。按 0.8.0 还缺改编取舍表：source_extraction.md 有 38 条事件、7 条补写，没有逐条标保留 / 简化 / 删除 / 新增和理由（照 story-bible/references/narrative-outline.md 补） |
| 5 | [x] | 核心玩法概念 | game-concept | 4 | — | CONCEPT 与系统索引齐全，硬否决逐项检查，原型假设明确 | 旧第 3 步：类型：CRPG 对话抉择 + 大地图明雷 + JRPG 回合制；定调：纯选择、意图预告、明雷、叙事进展（沿用：检查点重试、同伴系统、3–5 回合）。七条硬否决全过（第 3 条待白盒）；系统 14 个，mvp 7 个；「不做经验和等级」A1 已确认；A1 通过。2026-11-06 改：玩法参考换成战斗照杀戮尖塔、地图和成长照 Vampire's Fall 2，补「想要的感受」「三层循环」（每层写照哪个游戏），最大风险改成「两次看水面之间没什么可玩」；「支柱和不做清单」「三种需要」A1 前补。2026-11-06 玩法参考改成战斗照杀戮尖塔、地图和成长照 Vampire's Fall 2，CONCEPT 跟着改 |
| 6 | [x] | 玩法原型 | gameplay-prototype | 5 | mvp | 计划、可玩原型和试玩报告齐全；用户在 A2 确认继续 | 旧第 4 步：两个网页原型：怎么打（prototypes/how-to-fight/）→ 继续，打法定行动版，最后一场调过数；两次看水面之间（prototypes/between-visions/）→ 未评估，用户结束原型阶段，最大风险移到第 10 步白盒验证。A1 通过（2026-11-06） |
| 7 | [x] | 收敛故事与玩法 | story-bible, story-map, story-review | 6 | — | 认知边界、伏笔、facts 与内容计划完善；改变故事地基时重开 A1 | 旧第 5 步：定调：信息同步、学徒自己 3 个结局、4 条支线。10 个决定（主线 5 + 支线 4 + 结局 1），29 个选项；17 条 facts、12 条伏笔；19 个人物加了认知边界和别名。脚本检查：每个选项 2 章内有回读、facts 都有 known_by、伏笔都有回收章，0 问题 |
| 8 | [x] | 系统设计 | game-design | 7 | mvp | 规则、依赖、边界、参数和体验验收完整；用户确认模块 5 | 旧第 7 步：定调：目标优先级、你操作所有人、混合指引、只做关键几处。7 页设计页 + 7 个参数文件 + GDD（两张图）+ SCREENS（19 屏）+ 章节内容表玩法列；「设计总览」页面已发布。脚本核对：每个法术、同伴的招、敌人在章节内容表里都有第几章出现；每个面板在界面清单里有一行；三张流程图能渲染。CONCEPT 改两处（地图敌人、第一章例子）并记了改动。2026-11-06 退回：玩法参考改了，原型之后按新参考改：combat.md 照杀戮尖塔核对规则和数字，overworld.md 照 Vampire's Fall 2，补成长和装备两页，每页开头写「照」那一行。2026-11-06 重做：定调题（成长：技能点加进几棵树；装备：打怪随机掉；敌人：打死就没了，用户纠正）。combat.md、overworld.md 重写，progression.md、items.md 新写，story-unlocks.md 改了和升级、装备的分工；每页开头有「照」那一行，规则表逐条标出处；第 1 章战斗数取自原型报告；经验曲线用脚本按「只打必须打的 / 全打」两条线反推。九页设计页 + 九个参数文件；GDD 四张图（新加「变强从哪来」）、SCREENS 加 6 屏、章节内容表加「成长和装备」一列；check_style 禁用 0 条，check_project_data 0 个错误 |
| 9 | [ ] | 数值设计与模拟 | balancing, game-design | 8 | mvp | 公式、配置表、成长与资源模拟结果可检查；用户确认模块 6 | 已有：第 1 章五场仗的 --sim 模拟（DEVLOG 21.3：四场小仗 2–3 回合，学徒一个法术不放也能赢）。待做：照 balancing/references/numbers.md 定 TTK 基准，补第 2–6 章敌人、遭遇、成长和资源的数值并模拟。旧流程把这步排在最后（旧第 19 步） |
| 10 | [ ] | 关卡与任务设计 | game-design, quest-design | 9 | mvp | 第一段关卡目标、流程、任务状态及奖励可实现；用户确认模块 7 | 待做：照 game-design/references/level-design.md 写第 2–6 章的关卡结构、单关五段式、Boss 阶段和奖励放置。quests.json 已随第 15 步对白初稿写好，关卡定了以后回头核对 |
| 11 | [x] | 美术与界面设计 | art-direction, ui-layout | 10 | — | 目标图、界面清单、动线与反馈规范；B 确认 | 旧第 9 步：design/ART_DIRECTION.md、design/targets/ 两张、CREDITS.md 已交；没有玩法参考，界面观察跳过，风格契约写在 ART_DIRECTION 第 4 节；B 通过。界面清单 SCREENS.md（19 屏）在旧第 7 步写好 |
| 12 | [x] | 数据与工程 | game-data-schema, godot-project-structure | 11 | mvp | 数据样例可校验，工程可运行，存档与任务状态对应 | 旧第 8 步：定好本作的数据格式（content/README.md）：变量由 bible.json 生成 54 个；任务表 10 条（主线步骤 = 剧情谱节点）；新加 6 个指令；遭遇表；第 1 章样例对白 65 行和 NPC、刷新点、文本表 131 条。check_content 0 错误（6 条提醒是新指令）、tools/check_project_data.py 0 错误。Godot 4.3 工程骨架：--playtest 跑完第 1 章样例三条路线全过（变量、任务、能力、预言簿、存读档）；网页导出 35MB，无头浏览器里打开 0 报错。证据 qa/evidence/step6/ |
| 13 | [x] | 第一段完整可玩内容 | world-map, combat-system, progression-system, save-load, quest-design, dialogue-authoring, ui-layout, playtest-automation | 12 | mvp | 核心循环、剧情后果、奖励与存档接通；运行验证和四条体验门槛通过，用户试玩确认 | 旧第 10 步（白盒切片）：2026-11-09 按新玩法重做（DEVLOG 第 21 节）：参考代码 intent-battle、overworld-grid、xp-progression、random-affix-loot 带进 scripts/mechanics/，自带测试 62 个用例全过。森林 32×18，四群会走动、会追的敌人，头狼群堵在去石圈的路上，林边石龛、空心老橡树的包袱；战斗照杀戮尖塔，血带出战斗、喝药、逃跑；经验 N³、升级挑奖励加点、装备三格带词缀；结尾有试玩记录。verify.py 20261109-112111 六项 PASS；--playtest 三条路线 PASS（全打 28 经验 3 级、只打必须的 12 经验 2 级，和成长页对上）；网页版无头浏览器能进游戏。等用户试玩：四条硬门槛和复盘题、最大风险的留下 / 放弃信号都在白盒试玩时问。白盒试玩停靠点 2026-11-09 通过，四条硬门槛都过 |
| 14 | [x] | 范围复盘与生产计划 | producer | 13 | — | 首版范围、接口和批次确认；完成范围复盘 ① | 旧第 11 步：GAME_BRIEF 范围复盘表第一行：预算不限，全程约 3 小时 40 分，用户选了接受；没删内容 |
| 15 | [~] | 分批制作正式内容 | quest-design, dialogue-authoring, story-review, world-map, combat-system, progression-system, save-load, skill-checks, asset-sourcing, asset-generation, asset-upload, asset-pipeline, cutout-animation, style-consistency, ui-layout, localization-table | 14 | playable | 按适用系统分批实现，每批验证与试玩；必做项完成一半时范围复盘 ② | 按批做。① 对白（旧第 12 步），进行中：第 2–6 章主线和四条支线初稿写完，合进任务表和文本表；剧情走查五条路线跑通；第 1 章按新写法重过；审查报告四份（review_ch2_ch3 / ch4 / ch5 / ch6_cross，共 🔴33 🟠125 🟡103）还没改；voices.md 从马洛礼原文提炼了八个人的口气，台词只有第 1 章梅林三句跟着改了。② 地图、战斗、成长、存档（旧第 13 步）。③ 素材（旧第 14 步）。④ 界面和文本表（旧第 16 步）。必做项做完一半时范围复盘 ②（旧第 15 步） |
| 16 | [ ] | 整体验证与调整 | playtest-automation, story-review, balancing | 15 | full | 整体运行验证通过，剧情与数值问题修正；用户在 C 整体试玩 | 旧第 17 步证据化验证、第 18 步停靠点 C、第 19 步数值调整合在这一步 |
| 17 | [ ] | 发布与交付 | web-release, producer | 16 | full | D 发布检查通过；交付游戏、源文件、设计资料和已知问题 | 旧第 20 步 |
