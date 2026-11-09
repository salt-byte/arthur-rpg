# 第 5 章 · 圣杯与裂痕：交回说明

文件：`content/dialogue/Ch5.yarn`（26 个节点）、`frag/ch5_text.csv`（25 个文本键，其中 2 个改已有的键）。没有改别的文件，没有 #line，没有提交。

## 0. 先看这几条（要你定或要你合并时动手的）

1. **quests.json 1502 的 `battle` 必须拿掉**，否则是 bug。`scripts/quests.gd` 的 `on_battle_won` 在打赢「当前步骤的 battle」时自动跳到下一步：守城一仗打完，任务直接到 1503，两条支线立刻关门，Ch5_Return 和 Ch5_Supper 里的推进全落空。仗由 `Ch5_Defense` 里的 `<<fight_npcs camelot_defense>>` 开。片段见第 3 节。
2. **篇幅超了上限**：全文件 272 行台词和旁白 + 19 个选项（所有分支加起来）。一次通关读到的是主线 119–139 行，算上 NPC 闲话和两处物件 151–170 行。分支多在 D4（3 种）、S2（4 种）、凯走不走、V（3 种）、D5（4 种）叠在一起。要砍到 220 以内，建议砍 NPC 节点和圆桌物件（共约 60 行），主线节点不动。你定。
3. **附加选项 V 没加 `#key`**。水滴标记只给预言簿里的决定（D5）；V 是私下一句话，选完紧接着就是 D5 和自动存档，读档回不到 V 之前。要它也弹「说出口就不能收回」，在三个 V 选项后面加 `#key` 就行。你定。
4. **两处跳进支线作者的节点**：`Ch5_Bedivere` → `S2502_Rumor`（Side.yarn），`Prop_river` → `S2502_Boat`。支线作者在 Side.yarn 里留了接口注释，也已经照我贝狄威尔那句「下个月有比武……他不去」改了开头；他们改节点名时这里要跟着改。毒苹果（2501）的给任务人是王后的侍女，我没写她，只在凯、王后、高文嘴里留了苹果的线索。
5. **两条支线的关门提醒**：引擎里没找到 `closes_before` 的实现。关门点是 `Ch5_Arthur` 里选「这就去」跳 `Ch5_Supper` 那一下。我在 Yarn 里留了一个软关口（亚瑟问「今晚吃饭你来」，可以选「等一会儿」），正式的关门提醒要放在跳进 Ch5_Supper 之前。
6. **王后的名字**用 bible 的「桂妮维亚」，派活消息里写的是「桂妮薇儿」。

## 1. 节点：谁、在哪、什么时候触发

| 节点 | 步骤 | 触发 | 内容 |
|---|---|---|---|
| Ch5_Start | 开章 | maps.json `chapter_start.5` 指向它（起点放在阁楼，东边塔楼顶，照 Ch4） | 五旬节早上，凯喊你下楼；`<<start_quest 1005>>` |
| Ch5_Grail | 1501 | 1501 时走进圆桌大厅 | 加拉哈德坐上空椅子，圣杯显现，高文第一个发誓；莫德雷德没站起来，亚瑟摇头让贝狄威尔坐下 → 1502 |
| Ch5_Holdfast | 1502 | 城门洞里的凯（Ch5_Kay 没演过本节点时跳过来） | 凯的账本（回来画圈、死了划道）；贝狄威尔跑来报信；`<<companion bedivere party>>` `<<unlock u_bedivere>>` |
| Ch5_Defense | 1502 | Holdfast 之后，城门外山路拐弯处的牛车（一格触发） | `<<fight_npcs camelot_defense>>`；受伤的骑士讲路上的事；账本划了第一道 |
| Ch5_Return | 1502 | Defense 之后再进圆桌大厅 | 过了一个冬天；加拉哈德的消息；高文、兰斯洛特回来，兰斯洛特只看见一角。**演完两条支线的给任务人才出现** |
| Ch5_Supper | 1502 → 1503 | Ch5_Arthur 里选「这就去」 | 打猎的提议；S3c、S4a 的回读；可以劝亚瑟别去（D3b / D4b 不同回答）；夜里看见走廊的火把 → 1503 |
| Ch5_Exposure | 1503 | 1503 时走到王后的房间外（走廊一格） | 揭发。D4a：兰斯洛特带剑、说「你说过的」、用剑脊突围；D4b 无 D3b：阿格规文在北边；其余：阿格规文死；D4c 天亮时高文问「你什么都看不见吗？」；`<<book_after D4 …>>` → 跳 Judgment |
| Ch5_Judgment | 1503 → 1504 | Exposure 跳进来（第二天早上，大厅） | S3b 侍女送戒指；D4b+D3b「我说过……」；D4b 无 D3b 亚瑟判刑时看你；高文不去；加雷斯、加赫里斯（S2a 加雷斯拒绝；S2c 你可以去拦，他说当着王说了就得去）；亚瑟派你去看着 → 1504 |
| Ch5_Execution | 1504 | 1504 时走到城外河滩的木桩前（camelot_outside） | 法场。加赫里斯总是死；S2b 凯拖出加雷斯；S2c 和没做支线时加雷斯死；高文赶到；同伴状态全在这里改 → 1505；D1b 时跳 KayAfter |
| Ch5_KayAfter | 1505 | Execution 跳进来，只在 D1b | 有 S2b：亚瑟去看凯，「来看我哥哥」，凯留下；没有 S2b：凯把钥匙挂上椅背，回庄园，`<<companion kay left>>` |
| Ch5_Oath | 1505 | 1505 时走进礼拜堂 | 高文挑护腕上的名字、当众发誓；S2b 加雷斯和高文吵；私下的附加选项 V0/V1/V2 → 跳 Font |
| Ch5_Font | 1505 | Oath 跳进来 | 圣水盆 `<<vision D5>>`；关键选择 D5；`<<autosave>>` `<<complete_quest 1005>>` `<<chapter 6>>` |
| Ch5_Arthur | — | 亚瑟（大厅） | 1501 / 1502 两段 / 1505 听你回话 |
| Ch5_Guinevere | — | 王后（1501 大厅；1502 前段伤员屋；后段花园） | S4c 第一次跳 GuinevereDoor；S3b、其余各一句 |
| Ch5_GuinevereDoor | — | Guinevere 跳进来 | S4c 回读：信，一整天没开门 |
| Ch5_Lancelot | — | 兰斯洛特（1502 Return 之后，马厩） | S4b / D4a / 其余各一句 |
| Ch5_Gawain | — | 高文（1502 Return 之后井台；1504 棺材边或马厩） | 苹果（2501 线索）；S3a |
| Ch5_Gareth | — | 加雷斯（1502 Return 之后练剑场；1505 活着时） | S2a / S2b / 其余 |
| Ch5_Gaheris | — | 加赫里斯（1502 Return 之后练剑场） | 一句 |
| Ch5_Agravaine | — | 阿格规文（1502 Return 之后大厅；D4a 时 1504 起） | D4b 无 D3b 时整章不放 |
| Ch5_Mordred | — | 莫德雷德（1502 起大厅；1504 起手缠着布） | D4b 无 D3b 时埋第 6 章的疑心 |
| Ch5_Bedivere | — | 贝狄威尔（Holdfast 之后城门边伤员屋；1505） | Return 之后头一回跳 BedivereTourney，第二回跳 S2502_Rumor |
| Ch5_BedivereTourney | — | Bedivere 跳进来 | 2502 引子：下个月有比武，兰斯洛特说不去 |
| Ch5_Kay | — | 凯（1502 前段城门洞；其余厨房门口） | 没演 Holdfast 先演它；Return 之后苹果线索（2501） |
| Prop_round_table | — | 圆桌大厅的圆桌 | 法场之后：加赫里斯、（加雷斯）、（阿格规文）盖布；阿格规文 D4b 空椅落灰；兰斯洛特空椅搭着披风；凯走了空椅挂钥匙；1502 前段空了一大半 |
| Prop_river | — | 城下河边（camelot_outside） | S4c 且 1502：头一回跳 S2502_Boat；之后、或没做支线到了 1503：空船和洗衣妇；其余：洗衣裳的人 |

1503 是夜里：除了揭发那一格，这一步地图上不放任何 NPC。

## 2. 变量

用到的全在 Variables.yarn 里：`$D1 $D2 $D3 $D4 $D5 $S1 $S2 $S3 $S4 $V $kay_believes_you $kay_protected_gareth $player_at_arthur_side $player_late $c_kay`。

这章设的：`$D5`、`$V`、`$player_at_arthur_side`（D5a）、`$player_late`（D5c）；`<<companion>>` 改 `$c_bedivere $c_agravaine $c_gaheris $c_gareth $c_lancelot $c_kay`。

没声明、这章也没设的四个 bible 标记（flags_by_condition），都能从已有变量算出来，**不用加**：

| bible 标记 | 等于 | 谁读 |
|---|---|---|
| `arthur_knew_affair` | `$D4 == "D4b" and $D3 != "D3b"` | 第 4 章作者在 Ch4.yarn:264 留了注释；第 5 章直接用这个表达式 |
| `arthur_order_no_draw` | `$D5 == "D5a" and $D2 == "D2a"` | 第 6 章 |
| `kay_at_front` | `$D5 == "D5b" and $c_kay != "left" and ($kay_believes_you or $kay_protected_gareth)` | 第 6 章（Ch6.yarn:110 已这样写） |
| `bedivere_scouts` | `$D5 == "D5b"` 且上一条不成立 | 第 6 章（Ch6.yarn:130 已这样写） |

D5b 拆成两个互斥选项，条件就是上面两条：凯在、信你 →「告诉凯」；凯走了或不信你 →「告诉贝狄威尔」，凯在场时他听见了，笑一句「一条蛇？」（bible 下场表）。两个都 `set $D5 to "D5b"`。

阿格规文三种下场用的表达式：活着 `$D4 == "D4a"`；在北边 `$D4 == "D4b" and $D3 != "D3b"`；死 = 其余。凯离开 `$D1 == "D1b" and not $kay_protected_gareth`。加雷斯活 `$S2 == "S2a" or $S2 == "S2b"`，没做支线（`$S2 == ""`）按 S2c 算，死在法场。

## 3. quests.json 要改的

1502 去掉 `battle`（理由见第 0 节第 1 条），其余不动：

```json
"1005": {
  "type": "main",
  "name": "quest_1005_name",
  "desc": "quest_1005_desc",
  "chapter": 5,
  "parts": [
    { "id": 1501, "text": "quest_1005_p1501", "area": "camelot" },
    { "id": 1502, "text": "quest_1005_p1502", "area": "camelot" },
    { "id": 1503, "text": "quest_1005_p1503", "area": "camelot" },
    { "id": 1504, "text": "quest_1005_p1504", "area": "camelot_outside" },
    { "id": 1505, "text": "quest_1005_p1505", "area": "camelot" }
  ]
}
```

文本表改两个已有的键（在 ch5_text.csv 里）：
- `quest_1005_desc`：原文「圣杯在圆桌上方出现过一次……」在开章时显示，那时圣杯还没出现。改成「五旬节到了。亚瑟有个老规矩：不见着一件稀罕事，不开席。」
- `quest_1005_p1502`：原文「留在城里守着」没说去哪找谁。改成「留守卡美洛（城门找凯；骑士回来以后，去大厅找亚瑟）」。1502 这一步里要去四个地方（城门、牛车、大厅、亚瑟），一个坐标标不全；地图标记要么按 `visited("Ch5_Holdfast")`、`visited("Ch5_Defense")`、`visited("Ch5_Return")` 分段换，要么接受文字指路。

2501、2502 不用改，`opens_at` 还是 1502；它们的给任务人在 npcs.json 里加条件 `visited("Ch5_Return")`（支线作者也是这么写的：「高文 / 兰斯洛特找圣杯回来以后」）。

## 4. NPC 放哪、什么条件出现

格子坐标第 13 步做地图时补。条件都另加 `$chapter == 5`。

| id（建议） | 地方 | node | condition |
|---|---|---|---|
| arthur_hall | camelot 大厅 | Ch5_Arthur | `quest_part(1005) != 1503` |
| guinevere_hall | camelot 大厅 / 伤员屋 / 花园 | Ch5_Guinevere | `quest_part(1005) == 1501 or quest_part(1005) == 1502` |
| lancelot_stable | camelot 马厩 | Ch5_Lancelot | `quest_part(1005) == 1502 and visited("Ch5_Return")` |
| gawain_well | camelot 井台 | Ch5_Gawain | `quest_part(1005) == 1502 and visited("Ch5_Return")` |
| gawain_1504 | camelot 礼拜堂外 | Ch5_Gawain | `quest_part(1005) == 1504` |
| gareth_yard | camelot 练剑场 | Ch5_Gareth | `quest_part(1005) == 1502 and visited("Ch5_Return")` |
| gareth_after | camelot 马厩门口 | Ch5_Gareth | `quest_part(1005) == 1505 and ($S2 == "S2a" or $S2 == "S2b")` |
| gaheris_yard | camelot 练剑场 | Ch5_Gaheris | `quest_part(1005) == 1502 and visited("Ch5_Return")` |
| agravaine_hall | camelot 大厅 | Ch5_Agravaine | `quest_part(1005) == 1502 and visited("Ch5_Return") and not ($D4 == "D4b" and $D3 != "D3b")` |
| agravaine_after | camelot 大厅 | Ch5_Agravaine | `quest_part(1005) >= 1504 and $D4 == "D4a"` |
| mordred_hall | camelot 大厅 | Ch5_Mordred | `quest_part(1005) == 1502 or quest_part(1005) >= 1504` |
| bedivere_ward | camelot 城门边伤员屋 | Ch5_Bedivere | `(quest_part(1005) == 1502 and visited("Ch5_Holdfast")) or quest_part(1005) == 1505` |
| kay_gate | camelot 城门洞 | Ch5_Kay | `quest_part(1005) == 1502 and not visited("Ch5_Return")` |
| kay_kitchen | camelot 厨房门口 | Ch5_Kay | `$c_kay != "left" and (quest_part(1005) == 1501 or (quest_part(1005) == 1502 and visited("Ch5_Return")) or quest_part(1005) >= 1504)` |
| guinevere_maid | camelot 回廊（支线作者的人） | S2501_Rumor | `quest_part(1005) == 1502 and visited("Ch5_Return") and quest_state(2501) == "none"` |

触发格（不站人）：大厅入口（Ch5_Grail 在 1501、Ch5_Return 在 Defense 之后）、山路拐弯的牛车（Ch5_Defense）、王后房间外的走廊（Ch5_Exposure，1503）、河滩木桩（Ch5_Execution，1504）、礼拜堂入口（Ch5_Oath，1505）、圆桌（Prop_round_table）、城下河边（Prop_river）。

npcs.json `speakers` 要加三个不站在地图上的说话人：受伤的骑士、侍女、洗衣妇（头像可以先用村民）。

1502 前段（Return 之前）高文、兰斯洛特、加雷斯、加赫里斯都在外面找圣杯，状态还是 party，但这一段不能选他们上场（同伴页「这一段不在场」）。

## 5. 遭遇和敌人

`camelot_defense` 现在是空的（「第 10 步补」）。按 CONTENT_SCHEDULE 第 5 章那一行和剧情，建议：

```json
"camelot_defense": {
  "name": "enc_camelot_defense",
  "kind": "quest",
  "enemies": ["raider", "raider", "raider"],
  "party": { "fixed": ["kay", "bedivere"], "max": 2 },
  "win": { "type": "all_down" }
}
```

- 上场的只能是凯和贝狄威尔：亚瑟是王，不出城打强盗；高文、兰斯洛特、加雷斯在找圣杯。贝狄威尔一定上场，这一仗教「包扎」。
- 新敌人 `raider`（文本键 `enemy_raider`「劫道的强盗」已放进 csv）：每一招都打 `lowest_hp`。剧情里的来由是贝狄威尔那句「那帮人专挑身上带血的砍」。数值留给 balancing，可以照第 1 章的 `bandit` 改：去掉撒沙，砍改成全打血最少的人。

不需要别的新遭遇。比武（`tournament`）是支线作者的。

## 6. 别的数据（合并时顺手）

- prophecy.json 的 D5 那一幕加 `"text": "vision_D5"`（键在 csv 里，三句，每句不超过 30 字）。
- maps.json 加 `chapter_start.5`：`{"area": "camelot", "cell": [阁楼], "node": "Ch5_Start"}`。
- overworld.json 的 W2（圆桌）、W3（河边）对应 `Prop_round_table`、`Prop_river`。
- 预言簿文本：`after_D4a / after_D4b / after_D4b_refused / after_D4c`（D4 应验）、`after_S2a / after_S2b / after_S2c`（S2 应验在法场）、`book_told_D5a / D5b / D5c`。`book_told_D5b` 只有一个键，写成「告诉了凯或贝狄威尔」；要分开写，screens.gd 第 140 行要能读第二个键（比如 `book_told_D5b_bedivere`）。
- npc 名字键：贝狄威尔、受伤的骑士、洗衣妇是这章第一次出现。王后、兰斯洛特、高文、加赫里斯、阿格规文、莫德雷德在 ch3 / ch4 的 csv 里也有，值完全一样，合并时去重就行。
- 引擎注意：`book_after` 在那一页不存在时不加行，但还是弹提示。法场的 `<<book_after S2 …>>` 只在 `$S2` 是 S2a/S2b/S2c 时调；如果引擎在「美手」支线关门时自动把没做的设成 S2c，而玩家没看过那一幕，会弹一个空页的提示。建议 main.gd 的 book_after 在找不到页时不弹。

## 7. 逻辑自查：每个说话的人知道什么、从哪知道

| 人 | 这章说到的事 | 凭什么知道 |
|---|---|---|
| 你（选项、旁白视角） | 酒杯里那一幕（Supper 末、Exposure）；木碗里加雷斯那一幕（Judgment，S2c）；绿腰带（V1）；高文欠你命（V2）；梅林的字条（D3c） | D4 酒杯（第 4 章）；S2 木碗（支线 2401）；S1b、S3a 支线；Ch4.yarn:37 的字条「别来找我」 |
| 凯 | 账本；强盗；苹果两筐、高文爱吃（2501 线索）；法场上他俩不带剑；「王让我待在城门里头」（D1b 无 S2b）；蛇 | 总管管名单和厨房；贝狄威尔报信；宴席单子；审判时他在场（S2b 写了他在人群后扣皮带）；他自己的事；D5b 你告诉他或他在旁边听见 |
| 贝狄威尔 | 强盗专挑带血的砍；王让他留下；下个月比武、兰斯洛特说不去；河滩那匹马；蛇 | 他从山路上跑上来，看见了；圣杯那晚亚瑟朝他摇头；宫里的消息；法场之后他去了河滩（S2b 他给凯包扎）；D5b |
| 亚瑟 | 五旬节规矩；你们当中有人回不来；打猎；「这件事我不想知道」（D3b）；「我知道你要说什么」（D4b 无 D3b）；判火刑；「她伤着没有」；蛇 | 宫里的老规矩（马洛礼）；出征的人会死是常识，说的是怕；D3b 以后不想听你；D4b 你在第 4 章告诉过他；莫德雷德和十几个骑士作证；你回话；D5a |
| 桂妮维亚 | 座次；伤员住处；兰斯洛特添杯盘；门帘；果子先尝过（S3b）；请高文吃席 | 她管宴席和接待（人物卡）；S3b 她自己查过苹果（Side.yarn S2501_Feast） |
| 兰斯洛特 | 圣杯只看见一角；「你说过的」（D4a）；剑一直带着（D4a）；不再戴袖子（S4b） | 他自己去的；第 4 章你提醒过他（Ch4.yarn D4a）；S4b 后果。法场上他没说话，旁白只写他不看马前的脸，和「认不出加雷斯兄弟」对上 |
| 高文 | 一年零一天；隐士说他不配；苹果、皮内尔（S3a）；「你什么都看不见吗」（D4c）；不去看她烧；「他没带剑」（S2c）；誓言；「他认得他们」；「誓已经发了」（S2b）；V1 私下认错；V2 答应写信 | 马洛礼原话；他自己的路；S3a 他当场抓的人；你接替梅林以后人人知道你看得见（第 4 章公开）；审判时兄弟俩当众说了不带剑，他在场；「他认得他们」是他的误以为（bible 认知边界），他不在法场；其余是他自己的事 |
| 加雷斯 | 「有人告诉过我，不要去」（S2a）；不拿剑对着封他的人；「当着王说了就得去」（S2c）；凯救了他（S2b）；兰斯洛特没认出他们（S2b） | S2a 你告诉过他；兰斯洛特封他是原文；规则 6；S2b 他亲身经历，站在马前看见兰斯洛特没看他 |
| 加赫里斯 | 「兄弟里总得有一个人去」；剑不带 | bible 原话；他自己的选择 |
| 阿格规文 | 盯着王后的手；红袖子（S4a）；「一场又一场」（S3c）；剑脊（D4a） | 第 4 章起怀疑；S4a 伊莲恩逢人就讲；S3c 兰斯洛特为王后决斗是公开的；他自己挨的那一下 |
| 莫德雷德 | 看亚瑟一眼再开口；留城；座次有讲究；作见证；「阿格规文要是在」（D4b 无 D3b） | 习惯（伏笔）；他没发誓；第 5 章他知道王后和兰斯洛特的事；你能看见将来是公开的；阿格规文被调走是当众宣的王令（Ch4.yarn:267），他只说事实，不说王早知道 |
| 受伤的骑士 | 岔路口分开；同伴被水冲走 | 他自己的路 |
| 侍女 | 戒指（S3b）；信、王后一整天没开门（S4c） | 王后让她送；她守在门外 |
| 洗衣妇 | 船从上游漂来；阿斯托拉特的姑娘，抬上去埋了 | 她在河边洗衣裳，看见了 |

几处补写，给你过目：
- 1502 的守城仗写成强盗劫回城的伤员车。理由：骑士走了一半，强盗敢来；伤员是最好下手的，正好接上「盯血最少的人」。
- 莫德雷德没去找圣杯（他先看亚瑟，亚瑟没看他）。这接上第 4 章「好好当差」那场戏和他留在城里结交人。
- 凯请辞的直接起因：「王让我待在城门里头，看着柴火车。柴火是我送出去的，人是别人死的。」总管备柴，亚瑟护着他不让他上前，这一下又是「被弟弟可怜」。只在 D1b 无 S2b 这条路上由凯自己说出来，别的路线不提凯在哪，不冲突。
- 亚瑟不去法场，派你去看着、回来一句不少地告诉他。原文里亚瑟也没去。这给了你在法场的理由。
- 加雷斯在 S2c 路线里你可以当场拦，他不回头的理由是规则 6：他已经当着王说了去。这样 S2a（早就告诉他）和临时拦不住之间有因果。
- 兰斯洛特的披风：揭发那晚三条路线都掉在走廊里，后来有人搭在他的空椅背上（companions.json 的 left_item「披风」）。
- 高文护腕上「另有一处已经空了，那是阿格规文的」：Ch3.yarn:172 写的是三个名字，这一处只在阿格规文死了的路线出现。

## 8. knowledge_check 的判断

`knowledge_check.py .` 列出 Ch5 的 10 处候选，全部判为不算泄漏：

| 事 | 行 | 说话人 | 判断 |
|---|---|---|---|
| gareth_identity | Ch5.yarn:203、214、533 | 亚瑟、你（选项）、加赫里斯 | 加雷斯的身份在 2401 结尾公开；没做支线时原文的事照样发生，第 5 章亚瑟当众点他的名（outline 1504 本来就要这样）。脚本按节点名对公开点，Ch5_ 节点对不上，才列出来 |
| snake | Ch5.yarn:397–425（Ch5_Font） | 你（三个选项）、亚瑟、凯 ×2、贝狄威尔 | 全在 `<<vision D5>>` 之后、各自的 D5 选项里面：你说给谁，谁才接这句话。凯在「告诉贝狄威尔」那支说「一条蛇？」，是在台阶上听见的，bible 下场表就是这么写的 |

`--all` 看全部提到的地方，还有加雷斯自己说「加雷斯爵士」一处（知情）。没有「说法与事实矛盾」。

## 9. 检查结果

- `check_style.py content/dialogue/Ch5.yarn frag/ch5_text.csv`：禁用 0 条，待判 1 条。待判是 Ch5.yarn:59「划了第一道」：接的是凯前面那句「到今天一道还没划」，数的是账本上的道，留着。 style-ok
- `check_content.py .`：Ch5.yarn 0 个错误。只有没有 #line 的提醒（照你说的不加）和 `<<autosave>>` 等本作指令的「未知指令」提醒（README 说不算错）。和别的文件没有重名节点；两处跨文件跳转（S2502_Rumor、S2502_Boat）现在都找得到。
- `tools/check_project_data.py`：在临时副本里把 ch5_text.csv 合进 game_text.csv 后跑，Ch5 0 个错误（`book_after` 的文本键、`vision`、`companion`、`unlock`、`fight_npcs` 的参数都对得上）。
- 每句不超过 40 字（dialogue.json 的 max_chars_per_box），选项不超过 24 字：脚本量过，没有超的。
- 自己写的路线模拟（照 yarn_program.gd 的解析规则，加载 Ch5.yarn 和 Side.yarn）走了四条路线：原文路线（D1c D4c S2c S3c S4c V0 D5c）、凯离开（D1b D4b 无 D3b S2a S3a S4a V1 告诉贝狄威尔）、凯和好（D1b D3b D4b S2b S3b S4b 告诉亚瑟）、凯信你（D1a D4a 无支线 告诉凯）。四条都从开章走到 `<<chapter 6>>`，任务步骤 1501→1505 依次推进，同伴状态和 bible 下场表一致。
