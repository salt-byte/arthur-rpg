# 内容数据格式 · 梅林的学徒（暂定名）

游戏里所有剧情、任务、人物、敌人、文字都在 `content/` 里，代码只负责把它们跑起来。格式照插件的 game-data-schema；这页写本作在它上面加了什么、改了什么。

写完任何内容跑两个检查，都要零错误：
```
python3 <插件>/skills/dialogue-authoring/scripts/check_content.py .   # 通用格式
python3 tools/check_project_data.py .                                 # 本作加的东西
```
check_content 会对本作新加的指令（下面「本作新加的」那张表）报「未知指令」提醒，这是插件的指令表写死了，不算错；这些指令的参数由 check_project_data 查，新加指令时两处一起登记：这一页的表、`tools/check_project_data.py` 第 1 段。

## 目录
| 文件 | 写什么 | 谁写 |
|---|---|---|
| `dialogue/Variables.yarn` | 全部剧情变量的声明 | `tools/build_variables.py` 从 bible.json 生成，不手改 |
| `dialogue/Ch1.yarn` …… | 对白，一章一个文件 | dialogue-authoring；现在只有第 1 章样例 |
| `data/quests.json` | 任务表 + 任务系统的参数 | quest-design |
| `data/npcs.json` | NPC 表 | quest-design、world-map |
| `data/spawns.json` | 地图上的敌人 | quest-design |
| `data/combat.json` | 战斗参数、敌人、遭遇 | game-design → balancing |
| `data/story-unlocks.json` | 剧情给的能力、提示框文字 | game-design |
| `data/prophecy.json` | 看水面的每一幕、画面文字 | game-design、dialogue-authoring |
| `data/companions.json` | 同伴名单、关系句 | game-design |
| `data/dialogue.json` `data/overworld.json` | 对话和大地图的参数、地方列表、四处世界变化 | game-design、world-map |
| `strings/game_text.csv` | 游戏里除对白以外的文字：任务、地方、人名、敌人、提示框、画面 | 各 skill，写数据时一起加 |
| `strings/dialogue.csv` | 对白表 | yarn_lines.py 从 .yarn 导出，不手改 |
| `story/` | 故事圣经和剧情谱（游戏不读，Godot 也不导入） | story-bible、story-map |

## 变量
全部在 `Variables.yarn` 里声明，改了 bible.json 就重跑 `tools/build_variables.py`。

| 变量 | 类型 | 意思 |
|---|---|---|
| `$D1` … `$D6`、`$S1` … `$S4` | 字符串 | 这个决定选了哪个选项，存选项 id（`"D1a"`）；还没选是 `""` |
| `$V` | 字符串 | 第 5 章高文发誓时的附加选项（`"V0"` `"V1"` `"V2"`） |
| `$kay_believes_you` 等 26 个 | 布尔 | bible.json 选项里的标记，名字照抄 |
| `$c_kay` 等 | 字符串 | 同伴状态：`"none"` 还没来、`"party"` 在队、`"left"` 离开、`"dead"` 离世 |
| `$player_name` `$chapter` `$last_battle` `$last_battle_won` `$last_battle_end` `$back` | — | 系统变量；`$last_battle_end` 是这一仗怎么停的：all_down / survive / end_if_down / lose / flee |

能力（学会了什么）、预言簿、任务进度不放变量，存在存档的对应字段里，Yarn 里用函数读。

## 对白里能用的函数
| 函数 | 返回 |
|---|---|
| `quest_part(1001)` | 任务现在在哪一步（步骤 id，主线就是剧情谱节点号）；没开始是 0 |
| `is_quest_active(1001)` `quest_state(1001)` | 插件自带 |
| `visited("Ch1_WolvesDone")` | 这个节点走过没有 |
| `has_unlock("u_still_water")` | 学会了没有 |

## 指令
插件自带、本作照用：`<<start_quest id>>` `<<progress_quest id 步骤>>` `<<complete_quest id 结局>>` `<<fight_npcs 遭遇>>` `<<notify 文本键>>` `<<show_ending 结局>>` `<<open_shop 店>>`。`open_shop` 的店是 items.json `shop.shops` 的 id，写在店主的节点 `Shop_<店>` 里（第 15 步加，伦敦桥头先用）。`fight_npcs` 的参数是遭遇 id（combat.json 的 encounters），不是单个敌人。

本作新加的：
| 指令 | 做什么 |
|---|---|
| `<<vision D1>>` | 切到看水面画面，显示 prophecy.json 里这一幕的画面和文字，预言簿多一页 |
| `<<book_after D1 文本键>>` | 应验以后，预言簿那一页加一行「后来：……」 |
| `<<unlock u_interrupt>>` | 得到或失去一样能力，弹出「新能力提示」 |
| `<<companion kay party>>` | 改一个同伴的状态（none / party / left / dead），同时改 `$c_kay` |
| `<<chapter 2>>` | 章节过渡：显示章名和这章没做的支线，关闭上一章的地方 |
| `<<autosave>>` | 存档（关键选择之后、每个任务步骤之后） |
| `<<close_side 2501 2502>>` | 关门：没做完的支线按 quests.json 的 `skip` 结算（决定变量设成 `skip.ending`，设上 `skip.flags`，任务记成这个结局）；做完的不动。写在每章关门那一下之前 |
| `<<teleport london 25 10>>` | 把玩家挪到另一片地方的某一格，对话接着演（第 15 步加；第 2 章加冕散场挪到大主教的厅门口，第 4–6 章换场景用）。格子要走得上去，check_project_data 查 |
| `<<objective 1002 quest_1002_p1202b>>` | 这一步里的小目标：同一步里人换了地方，目标条换成这句；进下一步自动清掉（第 12 步加，第 2 章「跑回住处拿剑」用） |

关键选择的选项后面加 `#key`：界面上带水滴标记，选中后先弹「说出口就不能收回。确定吗？」，确定才执行选项下面的内容。选项下面写 `<<set $D1 to "D1a">>` 和 bible.json 里这个选项的标记，选项组后面写 `<<autosave>>`。

## 任务表 quests.json
- 主线一章一条：`1001` … `1006`。每一步的 id 就是剧情谱的节点号（1101、1102……），剧情谱改了任务跟着改。
- 支线 id 和剧情谱一致：`2301` 绿衣骑士、`2401` 美手、`2501` 毒苹果、`2502` 伊莲恩。`decision` 是它对应的决定，`opens_at` / `closes_before` 是开和关的节点，`endings` 是三个选项（绿衣骑士是两个选项加「没去」`S1_skip`）。
- 步骤可以带 `area`（在哪片地方）、`target`（那片地方里标哪一格，第 2 章起填）和 `battle`（这一步要打的遭遇）。地图上的主线标记：在 `area` 里、这一步还没换小目标时标 `target`；换了小目标标眼下成立的触发格；不在 `area` 里时标往那边走的出口，那片地方有这一章传得过去的圣龛、脚下这片也有圣龛时改标圣龛。地图上的仗（敌人站在地图上）打赢就自动进下一步；对白里 `<<fight_npcs>>` 开的剧情战打赢不自动进，由对白里的 `<<progress_quest>>` 推进（第 12 步改：多佛那一仗打完，高文还没死，「下一步」已经换成去卡姆兰）。
- 支线的 `skip`：到关门还没做完时按哪个结局算、要设哪些标记（照剧情谱的 `skip_as` 和 bible 的标记）。
- 参数（主线标点、支线不标点、关门提醒、每步存档）放在 `_params`。

## 地图 maps.json、overworld.json
- maps.json 每片地方：`rows`（一字一格，图例 `tiles`）、`exits`（走上去换地方，可以带 `cond`，不成立时门关着、走不上去）、`triggers`（走上去、`cond` 成立就演 `node`）、`battle_bg`。
- overworld.json：`areas` 的 `chapter` 写一个章号或数组（复用的地方写 `[3, 4, 5]`）；`shrines` 的 `first_of_chapter` 写章号数组；`chests` 可以带 `condition`；`water_spots` 的 `glows_at` 主线写步骤号，支线写「任务 id:步骤」（`"2301:2"`）。

## 地图上的敌人 spawns.json
`zones` 是能绕开、会走动的小仗；第 2 章起任务敌人走「先对话再 `<<fight_npcs>>`」，不进 `spawns`。`enemy` 填遭遇 id；`condition` 为真时站在那里；`on_defeat` 是打赢后的对话节点。

## 遭遇 combat.json → encounters
每场仗：`enemies`（按出手顺序）、`party.fixed`（剧情规定一定上场的同伴）、`party.max`、`win`（`all_down` 全倒，或 `survive` 撑过几回合后剧情接管）。敌人的 `pattern` 按回合轮着用，`target` 写同伴 id、`apprentice`、`lowest_hp` 或 `all`。

## 文本表
`game_text.csv` 两列：`keys`、`zh`。键的前缀：`quest_` 任务，`area_` 地方，`npc_` 人名，`bark_` 闲话，`enemy_` 敌人，`enc_` 遭遇，`unlock_` 新能力提示，`vision_` 看水面的画面，`chapter_` 章名。
