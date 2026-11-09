# 第 3 章 · 湖中剑与圆桌 · 交接说明

`content/dialogue/Ch3.yarn` 写完：16 个节点，200 行（台词 110、旁白 71、选项 19），没有 `#line:`。三项检查对 Ch3 都是零：check_style 禁用 0 待判 0；check_content 除「没有 #line」和六个本作指令的「未知指令」提醒外零错误；check_project_data 合进 ch3_text.csv 后零错误。knowledge_check 列出 3 处候选，判断见第 7 节，都不算违规。

## 1. 节点和触发

| 节点 | 步骤 | 谁触发、在哪 | 做什么 |
|---|---|---|---|
| Ch3_Start | 进第 3 章 | maps.json `chapter_start."3"`：area `camp`，node `Ch3_Start` | 营地开场；洛特的王后来求过和；`<<start_quest 1003>>` |
| Ch3_Tent | 1301 | camp：营帐门口那一格的触发点，cond `quest_part(1003) == 1301`；或和营帐里的亚瑟说话（Ch3_Arthur 跳过来） | 梅林说出摩高斯和孩子；天亮侍从带伤回营 → `progress 1302` |
| Ch3_Fountain | 1302 | fountain：走进泉边空地的触发点，cond `quest_part(1003) == 1302`；或和佩利诺说话（Ch3_Pellinore 跳过来） | D2a/D2b/D2c 开打前各一句 → `<<fight_npcs pellinore>>` → 剑断、佩利诺睡着 → `book_after D2` → D2c 时梅林问你 → `progress 1303` |
| Ch3_Lake | 1303 | lake：岸边触发点，cond `quest_part(1003) == 1303 and not visited("Ch3_Lake")`；或和湖中仙女说话 | 湖中剑、剑鞘；`unlock u_excalibur` `u_scabbard`；D2a 回读；D2b 教静水 `unlock u_still_water` → `progress 1304` |
| Ch3_Camelot | 1304 | camelot：城门那一格，cond `quest_part(1003) == 1304 and not visited("Ch3_Camelot")` | 梅林警告王后的事；D2a「你也看见了吗」；D1b 凯不同桌 → jump |
| Ch3_Wedding | 1304 | 由 Ch3_Camelot 跳过来 | 圆桌进门、婚礼、名字浮上椅背、高文受封；`companion guinevere party` `companion gawain party` `unlock u_round_table` `unlock u_gawain`；`<<objective 1003 quest_1003_p1304b>>` 把目标条换成「婚礼办完了。想好了，去大厅找梅林」。演完自由走动（绿衣骑士支线在这段开着） |
| Ch3_Merlin（1304 婚礼后那一支） | 1304 → 1305 | 卡美洛大厅靠窗的梅林 | 选「我明天就去」才 `progress 1305`；选「等我忙完这阵子」留在 1304 |
| Ch3_LakeShore | 1305 | lake：岸边触发点，cond `quest_part(1003) == 1305 and not visited("Ch3_LakeShore")`；或和湖边的梅林、妮妙说话；或看发光的湖面（water_spots 见第 3 节） | 梅林教妮妙按石头；梅林说过几天出远门；`<<vision D3>>` → jump |
| Ch3_Night | 1305 | 由 Ch3_LakeShore 跳过来（剪到当晚卡美洛） | 梅林告诉亚瑟和你自己会被活埋、看好剑鞘；关键选择 D3 → `autosave` `complete_quest 1003` `chapter 4` |
| Ch3_Arthur / Merlin / Kay / Gawain / Guinevere / Pellinore / LadyLake / Nimue | 各步 | npcs.json，见第 4 节 | 入口节点，按 `quest_part(1003)` 分支 |

## 2. 变量

只用了 Variables.yarn 里已有的，不要新变量。

- 读：`$D1`（凯、亚瑟的回读）、`$D2`（三个选项各有回读，见下）。
- 写：`$D3`；D3a 设 `merlin_told_place`、`player_knows_place`；D3b 设 `arthur_fears_sight`、`gawain_saw_stone`、`player_knows_place`；D3c 设 `merlin_note`。和 bible.json 的 flags 一一对上。
- 同伴：`<<companion guinevere party>>`（只上圆桌面板，Party.COMPANIONS 里没有她，不会被拉进战斗）、`<<companion gawain party>>`。
- 函数：`quest_part(1003)`、`visited("…")`。`visited("S2301_Rumor")` 读的是 Side.yarn 的节点。

D2 回读落在哪：
- D2a：泉边开打前「你说过剑会断。你没说我会死。」（这是亚瑟明知剑会断还去的理由）；剑断时他扭头看橡树；湖边「你说它会断，它真断了。」；卡美洛「你也看见了吗？」（两条都是 bible 指定的）。
- D2b：泉边梅林「就是今天。拦下今天，还有明天。你别拦。」；湖边「你来问我，是对的。」并教静水。
- D2c：泉边梅林等亚瑟走开，「庆功宴上，你盯着酒杯，脸都白了。你看见了，没说。为什么？」（接 Ch2 D2c 里梅林在火塘边看了你一会儿）。
- 三条都有 `<<book_after D2 after_D2x>>`，放在佩利诺睡着以后。

## 3. 要改的数据（我没动，给合并的人）

**quests.json**：1003 不用改。五步 1301–1305 的 area（camp / fountain / lake / camelot / lake）和对白一致。1302 带 `battle: pellinore`，打赢时 Quests.on_battle_won 会自动进到 1303，节点里那句 `progress_quest 1003 1303` 只是保险，不会跳步。

**prophecy.json**：D3 那一幕补文本键。
```json
{"decision": "D3", "seen_at": "1305", "surface": "湖面", "decide_at": "1305", "text": "vision_D3"}
```

**maps.json**：
```json
"chapter_start": { "3": { "area": "camp", "cell": [待定], "node": "Ch3_Start" } }
```
各地方的 triggers：
```json
{"cell": [营帐门口], "node": "Ch3_Tent", "cond": "quest_part(1003) == 1301"}
{"cell": [泉边空地入口], "node": "Ch3_Fountain", "cond": "quest_part(1003) == 1302"}
{"cell": [湖岸], "node": "Ch3_Lake", "cond": "quest_part(1003) == 1303 and not visited(\"Ch3_Lake\")"}
{"cell": [城门], "node": "Ch3_Camelot", "cond": "quest_part(1003) == 1304 and not visited(\"Ch3_Camelot\")"}
{"cell": [湖岸], "node": "Ch3_LakeShore", "cond": "quest_part(1003) == 1305 and not visited(\"Ch3_LakeShore\")"}
```

**overworld.json → water_spots**：
```json
{"area": "lake", "glows_at": "1305", "cell": [待定], "node": "Ch3_LakeShore"}
```

**game_text.csv**：见 ch3_text.csv（20 条，含小目标 quest_1003_p1304b）。`npc_gawain` `npc_guinevere` `npc_nimue` 和 ch4、ch5、side 的片段重复，值一样，合并时去重即可。

## 4. NPC 站位（npcs.json，格子第 13 步定）

都加 `$chapter == 3`。

| id | area | node | condition | 备注 |
|---|---|---|---|---|
| arthur_camp | camp | Ch3_Arthur | `quest_part(1003) == 1301 or quest_part(1003) == 1302` | 1301 在营帐里，1302 在马桩边 |
| merlin_camp | camp | Ch3_Merlin | 同上 | |
| kay_camp | camp | Ch3_Kay | 同上 | 坐在粮车车辕上 |
| soldier_camp | camp | "" | 同上 | barks：bark_camp_1、bark_camp_2 |
| pellinore_fountain | fountain | Ch3_Pellinore | `quest_part(1003) == 1302 or quest_part(1003) == 1303` | 1303 时躺着打呼噜 |
| arthur_fountain | fountain | Ch3_Arthur | `quest_part(1003) == 1303` | 剑断以后，抱着断剑 |
| merlin_fountain | fountain | Ch3_Merlin | `quest_part(1003) == 1302` | 1302 站在橡树边 |
| lady_lake | lake | Ch3_LadyLake | `quest_part(1003) == 1303 and not visited("Ch3_Lake")` | 站在水面上，离岸一格 |
| arthur_camelot | camelot | Ch3_Arthur | `quest_part(1003) >= 1304 and visited("Ch3_Wedding")` | 大厅 |
| merlin_camelot | camelot | Ch3_Merlin | `quest_part(1003) == 1304 and visited("Ch3_Wedding")` | 大厅靠窗；进 1305 后不在城里 |
| kay_camelot | camelot | Ch3_Kay | `quest_part(1003) >= 1304 and visited("Ch3_Wedding")` | 绿衣骑士支线的线索在他这里 |
| gawain_camelot | camelot | Ch3_Gawain | 同上 | 支线 2301 进行中时按 Side 的说明换节点 |
| guinevere_camelot | camelot | Ch3_Guinevere | 同上 | |
| pellinore_camelot | camelot | Ch3_Pellinore | 同上 | 圆桌边 |
| servant_camelot | camelot | "" | 同上 | barks：bark_camelot_1、bark_camelot_2；1305 时加 bark_camelot_3 |
| merlin_lake | lake | Ch3_Merlin | `quest_part(1003) == 1305 and not visited("Ch3_LakeShore")` | 站在妮妙身后 |
| nimue_lake | lake | Ch3_Nimue | 同上 | 蹲在水边，手按石头 |

## 5. 遭遇和敌人

只用到一场：`pellinore`（combat.json 里还是 `_待写`）。建议：
```json
"pellinore": {"name": "enc_pellinore", "kind": "story", "flee": false,
  "enemies": ["pellinore"], "party": {"fixed": ["arthur"], "max": 1},
  "win": {"type": "survive", "turns": 3}}
```
- 新敌人 `pellinore`（名字键 enemy_pellinore 已写）：首领，轮流「砍」和「蓄力 → 下回合重劈」，照 CONTENT_SCHEDULE 第 3 章那一格的决策点（打断还是等亚瑟防御、你给护身）。
- 剧情要求：学徒躲在橡树后头放法术，佩利诺看不见学徒，招式的 target 全写 `arthur`。佩利诺第 4 章说「我砍下去，跟砍在湿牛皮上似的」，说的就是护身。
- 这时亚瑟还没有剑鞘，血能掉到 0。数值要保证三回合内倒不了，或者亚瑟倒下也按「剧情接管」处理，不算输。
- 地图小仗：1302 打完到 1303 进湖之前，亚瑟手里只有半截剑。泉边到湖那段路最好不放小仗；放的话，要接受亚瑟拿断剑打。

## 6. 逻辑自查：每个说话的人知道什么、从哪知道

| 人物 | 这章说的事 | 凭什么知道 |
|---|---|---|
| 梅林 | 摩高斯是亚瑟的姐姐、孩子会毁掉亚瑟；佩利诺以后有用；剑鞘比剑贵十倍；王后会爱上兰斯洛特；自己会被活埋；摩根在他走后敢动剑鞘；康沃尔（D3a） | bible：梅林一直知道这些（认知边界「一直知道」）。D2c 时他知道你看见了：Ch2 庆功宴上他看着你推开酒杯 |
| 亚瑟 | 三个侍从被挑下马；剑会断（D2a）；凯不同桌（D1b）；「她问我那她坐哪」 | 侍从回营他在场；D2a 你在庆功宴上告诉过他；D1b 是他和凯之间的事；王后问的是他本人。他问「兰斯洛特是谁」，因为兰斯洛特第 4 章才来 |
| 凯 | 泉边骑士伤了第三个人；D1a「在教堂里把话咽回去了」；圣诞宴归他管、高文打赌 | 总管管营里的人和马；D1a 是 Ch2 教堂里他自己的事；圣诞宴是总管的差事，高文打赌是宫里的闲话 |
| 高文 | 「舅舅」；母亲身子重；三个弟弟的名字；你在贝德格兰弹火星子；上午力气大；梅林往西去了；D3b 被派去追 | 亚瑟的身世第 2 章已当众说破，摩高斯是伊格赖因的女儿，他是外甥；母亲怀孕他自然知道，孩子是谁的他不知道；贝德格兰的事是军中传言；梅林往西走他亲眼看见；D3b 亚瑟当面下令 |
| 桂妮维亚 | 抬桌进门时没人看她；梅林不正眼看她；父亲的信只问桌子 | 都是她亲眼所见、亲手所收。她不知道梅林的警告，只看得出梅林躲着她；学徒的两个选项都替梅林瞒着 |
| 佩利诺 | 守泉、挑翻侍从；知道亚瑟是王后要杀他；橡树后的小个子、砍在湿牛皮上；王请他入席 | 守泉是他自己的事；梅林当面说「他是王」；人影他瞥见过，护身他砍上去感觉得到；入席是王派人请的 |
| 湖中仙女 | 剑是湖里的、用完还回来、叫王者之剑；叫妮妙推船 | 剑是她们的（世界规则 7）；妮妙是她身边的人 |
| 妮妙 | 「是他要跟着我」 | bible：她想摆脱一直缠着她的梅林。她不知道你看见了什么 |
| 你（选项） | 「我没看见过这件事」；D3 把湖面那一幕告诉谁 | 1301 你在场；湖面上那一幕是你看见的；「出远门」是梅林在湖边只对你说的 |

和其他章对过的地方：
- Ch2（D2 那一幕）：画面是「泉边旧帐篷、带金字的半截落进泉里、剑尖抵住喉咙」，泉边那段逐项照着写了；Ch2 D2a 亚瑟说「当了王，就不能见了拦路的骑士掉头走」，和泉边那句接得上。
- Ch4（D3 后果）：Ch4 D3c 亚瑟说「他连我也没告诉」，选「他跟我说过要出远门」时亚瑟回「跟你说了」。所以 Ch3_Night 里梅林只对亚瑟说了活埋和剑鞘，出远门只在湖边对你说过。Ch4 D3a 亚瑟说「被活着埋进土里，他说得跟买匹马一样」，对得上 Ch3_Night。Ch4 阁楼里杖靠在墙角、D3c 字条压在烛台下，对上 D3a 梅林把杖靠在墙角、D3c 下楼的脚步声里没有杖点地。Ch4 凯说「梅林在的那些年，她一次都没进过这扇门」，对上梅林这章那句「我在一天，摩根不敢碰它」。D3b 高文后半夜追出去，对上 Ch4 凯那句「高文半夜就追出去了」。
- Ch5：高文挑护腕上的名字（加赫里斯、加雷斯、阿格规文三个），对上这章「三个名字」。
- Side.yarn：`S2301_Rumor` 是圣诞宴开支线，要主线调用。我挂在 Ch3_Kay（1304 婚礼后）：凯说「高文跟人打赌，宴上有人叫阵他头一个站起来」，选「圣诞那天，我去大厅坐着」就 `<<jump S2301_Rumor>>`，宴上正好是高文先站起来。Ch3_Gawain 里留了注释：支线进行中时，合并时让他先跳进支线的节点。

## 7. knowledge_check 的判断

| 位置 | 候选 | 判断 |
|---|---|---|
| Ch3.yarn:109 Ch3_Lake 湖中仙女「它叫王者之剑。」 | stone_sword_vs_excalibur：不在知情名单 + 说法矛盾（王者之剑） | 不算。这句就是这个名字第一次出现的地方（fact 写的是「第 3 章湖边以后才有这个名字」），剑是她给的，名字也由她来起。misnomers 是给第 1–2 章用的，脚本分不出章。全章只有这一处说「王者之剑」，婚礼上写的是「湖里得来的那把剑」 |
| Ch3.yarn:233 Ch3_Night 梅林「康沃尔。海边一块大石头……」 | merlin_place：梅林不在知情名单（只有妮妙） | 不算，只在 D3a 分支。bible D3a 写明「他把地方告诉你：康沃尔」，梅林「很多年前就看见了」。建议在 bible.json 这条 fact 的 known_by 里加上 merlin |

其余 28 处候选在别的章，不归我判。

## 8. 检查结果

- `check_style.py Ch3.yarn ch3_text.csv`：禁用 0，待判 0。
- `check_content.py .`：Ch3 没有错误。200 条「没有 #line」（按要求不加），15 条「未知指令」提醒（book_after、unlock、companion、vision、autosave、chapter、objective，本作指令）。没有和别的文件重名的节点。
- `tools/check_project_data.py .`：直接跑报 after_D2a/b/c 不在 game_text.csv（在片段里）；把 ch3_text.csv 拼进副本再跑，Ch3 零错误。
- 每个对话框都在 40 字以内；vision_D3 三句，每句不超过 30 字。
- `story_tree.py --check` 会把 1301–1305 当成任务报「不在 quests.json」。这个项目一章一条任务、节点是步骤，第 1、2 章也一样报，和对白无关。

## 9. 请你决定

1. **高文「等肚里这个生下来，我还得再缝一个」。** 在场的人里只有亚瑟和你知道那是莫德雷德。这句等于说莫德雷德的名字会缝上高文的护腕，比 bible 的伏笔多一步。Ch5 的护腕戏没提他，不矛盾；第 6 章可以收（莫德雷德篡位后高文拆这个名字）。不想多这一步，就把后半句删掉。
2. **梅林点名摩根。** 马洛礼原文是「一个你信得过的女人会偷走剑鞘」，这里写成「我在一天，摩根不敢碰它」，直接接上 bible「梅林在时她不敢动手」和 Ch4 凯那句。要更含糊，就改回原文的说法。
3. **支线关门提醒。** 引擎现在没有 warn_before_close。我在梅林那里放了「我明天就去 / 等我忙完这阵子」两个选项，后一个就是「先不走」。引擎以后加了弹窗，这两个选项可以留也可以并掉。
4. **补写的小事实**：佩利诺「守了三年那口泉」；洛特的王后在营里「住了五天」；北边「还有两个王没递降书」。都是马洛礼没写死的数，可以改。
