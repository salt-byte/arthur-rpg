# 第 6 章 · 最后一战：交回说明

Ch6.yarn 写完：25 个节点，238 行（台词 + 旁白 + 选项，含三个结局），17 个选项；对话框全部 ≤40 字。没加 `#line:`，没跑 yarn_lines.py，没改别的文件。只用 Variables.yarn 里声明过的变量，不需要新变量。合并时要补的只有两样：文本键（ch6_text.csv）和一场新遭遇 `camlann_rear`（只在 D5c 路线打，见第 5 节，要你定）。

---

## 1. 节点、触发和去向

| 节点 | 步骤 | 地方 | 谁 / 怎么触发 | 去向 |
|---|---|---|---|---|
| `Ch6_Start` | 1601 | joyous_gard | 第 5 章末 `<<chapter 6>>` 之后进地图自动演。`<<start_quest 1006>>`；加雷斯在队时设 left | — |
| `Ch6_Arthur` | 1601 / 1602 / 1603 / 1605 | 1601 营帐（joyous_gard）；1602 码头（coast）；1603 对岸营帐（coast）；1605 营帐外（camlann） | 和亚瑟说话。1601 → 攻城；1602 → 码头交接；1603 → 伦敦来信；1605 第一次 → 梦，之后一句「去火边歇一会儿」 | 见右列各节点 |
| `Ch6_1601_Assault` | 1601 | joyous_gard 城门 | Ch6_Arthur 1601 跳来 | `<<fight_npcs joyous_gard>>` → Ch6_1601_Parley |
| `Ch6_1601_Parley` | 1601 | joyous_gard | 接上 | `<<progress_quest 1006 1602>>`，玩家留在 joyous_gard，可以去城门口找兰斯洛特、营帐找王后，再去海边 |
| `Ch6_Gawain` | 1601 / 1603 | 1601 城门前；1603 对岸营地 | 和高文说话。1602 他没有台词，码头上可以不放他，或只冒闲话 | — |
| `Ch6_Kay` | 1601 / 1605 | 1601 粮车；1605 营地 | 和凯说话，只在 `$c_kay == "party"` 时站出来。别的步骤放他也行，只回「别看我，看路。」 | — |
| `Ch6_Bedivere` | 1601 / 1605 | 1601 帐篷门口；1605 营地 | 和贝狄威尔说话 | — |
| `Ch6_Lancelot` | 1602 | joyous_gard 城门口 | 1601 演完以后，他在门口收拾行李回法国 | — |
| `Ch6_Guinevere` | 1602 | joyous_gard 营帐门口 | 同上，王后已回到亚瑟这边 | — |
| `Ch6_Mordred` | 1602 | coast 码头石阶 | 和莫德雷德说话（亚瑟交接前） | — |
| `Ch6_1602_Harbor` | 1602 | coast 码头 | Ch6_Arthur 1602 跳来 | `<<progress_quest 1006 1603>>`，旁白渡海；玩家此后站在对岸营地（见第 11 节第 3 条） |
| `Ch6_1603_News` | 1603 | coast（对岸营帐） | Ch6_Arthur 1603 跳来 | 伦敦过场 → `<<progress_quest 1006 1604>>` → Ch6_1604_Crossing |
| `Ch6_1604_Crossing` | 1604 | coast → dover | 接上（开船前一夜、登陆） | `<<fight_npcs dover>>` → Ch6_1604_Gawain |
| `Ch6_1604_Gawain` | 1604 | dover 沙滩 | 接上 | 高文战死，`<<progress_quest 1006 1605>>`，玩家站在 dover，走去 camlann |
| `Ch6_1605_Camp` | 1605 | camlann | 1605 第一次进 camlann 自动演；加雷斯这时设回 party | — |
| `Ch6_Gareth` → `Ch6_Gareth_Bracer` | 1605 | camlann 营地 | 和加雷斯说话，只在 `$c_gareth == "party"` 时站出来；第一次交护腕，之后一句 | — |
| `Ch6_1605_Dream` | 1605 | camlann 营帐外 | Ch6_Arthur 1605 第一次跳来 | — |
| `Prop_campfire` | 1605 | camlann 营地篝火（物件） | 面对篝火按确认。走过 Ch6_1605_Dream 以后才有「在火边坐到天亮」 | → Ch6_1605_Parley |
| `Ch6_1605_Parley` | 1605 | camlann 战场 | 篝火跳来 | D5c `<<fight_npcs camlann_rear>>`，其余 `<<fight_npcs camlann>>` → Ch6_1605_Fall |
| `Ch6_1605_Fall` | 1605 | camlann 战场 | 接上 | `<<progress_quest 1006 1606>>` → 直接跳 Ch6_1606_Lake（地图要切到 lake_last，见第 11 节第 9 条） |
| `Ch6_1606_Lake` | 1606 | lake_last | 接上。D6 在这里选，`<<autosave>>` 后按 `$D6` 跳结局 | Ending_E1 / E2 / E3 |
| `Ending_E1` `Ending_E2` `Ending_E3` | 1606 | — | D6 跳来 | `<<complete_quest 1006 E?>>` `<<show_ending E?>>`，之后结局回顾按 prophecy.json 念 |

---

## 2. 变量

**只读，全在 Variables.yarn 里**：`$D2`(经 `$arthur_trusts_sight`) `$D3` `$D4` `$D5` `$S1` `$S2` `$V`；`$kay_believes_you` `$kay_protected_gareth` `$gareth_refused_order` `$guinevere_trusts_you` `$lancelot_warned` `$arthur_trusts_sight` `$arthur_fears_sight` `$player_knows_place` `$player_late`；`$c_kay` `$c_gareth` `$c_agravaine`。逐个查过，前面几章都有地方设它们（Ch1、Ch2、Ch3、Ch4、Ch5、Side）。

**写**：`$D6`，存选项 id `"E1"` `"E2"` `"E3"`（照 bible.json 的 D6 选项 id；任务里举例的 `"D6a"` 写法我没用，id 跟 bible 走）。

**同伴状态变化**：
| 时机 | 指令 | 条件 |
|---|---|---|
| Ch6_Start | `<<companion gareth left>>` | `$c_gareth == "party"`（S2a、S2b） |
| Ch6_1603_News | `<<companion mordred left>>`；`<<companion agravaine left>>` | 阿格规文那条只在 `$c_agravaine == "party"`（Ch4 设 party、Ch5 死了的路线设 dead） |
| Ch6_1604_Gawain | `<<companion gawain dead>>` | 总是 |
| Ch6_1605_Camp | `<<companion gareth party>>` | S2a、S2b |
| Ch6_1605_Parley | `<<companion kay dead>>` | D5b、凯在队、凯信你、没有 S2b |
| Ch6_1605_Fall | `<<companion mordred dead>>` | 总是 |
| Ch6_1606_Lake | `<<companion arthur left>>` | 船离岸 |

**bible 里有、Variables.yarn 没有的三个标记**：D5 的 `flags_by_condition` 写了 `arthur_order_no_draw`（D5a 且有 D2a）、`kay_at_front`（D5b、凯信你且没走）、`bedivere_scouts`（D5b、凯走了或不信你）。我没用，条件直接用已有变量拼：
- 凯去找蛇：`$D5 == "D5b" and $c_kay == "party" and ($kay_believes_you or $kay_protected_gareth)`，和 Ch5.yarn 里「告诉凯」那个选项的条件一字不差。
- 告诉的是贝狄威尔：`$D5 == "D5b"` 且上面那条不成立。
- 亚瑟下令不许拔剑：`$D5 == "D5a" and $arthur_trusts_sight`。

不需要新变量。要是嫌第一条在 Parley 里重复了四次太长，可以让 build_variables.py 把这三个标记补进来，由 Ch5 在选 D5 时设，我这边再换成标记名。

---

## 3. quests.json 要改的

1006 加 `decision` 和 `endings`（照支线的写法），步骤不动；1603 的 area 仍是 coast，但那时玩家在对岸（见第 11 节第 3 条）。

```json
"1006": {
  "type": "main",
  "decision": "D6",
  "name": "quest_1006_name",
  "desc": "quest_1006_desc",
  "chapter": 6,
  "parts": [
    {"id": 1601, "text": "quest_1006_p1601", "area": "joyous_gard", "battle": "joyous_gard"},
    {"id": 1602, "text": "quest_1006_p1602", "area": "coast"},
    {"id": 1603, "text": "quest_1006_p1603", "area": "coast", "_说明": "1602 演完渡海，1603 的 coast 是对岸班威克城外的营地"},
    {"id": 1604, "text": "quest_1006_p1604", "area": "dover", "battle": "dover"},
    {"id": 1605, "text": "quest_1006_p1605", "area": "camlann", "battle": "camlann", "_说明": "D5c 路线打 camlann_rear"},
    {"id": 1606, "text": "quest_1006_p1606", "area": "lake_last"}
  ],
  "endings": [
    {"id": "E1", "text": "quest_1006_end_E1"},
    {"id": "E2", "text": "quest_1006_end_E2"},
    {"id": "E3", "text": "quest_1006_end_E3"}
  ]
}
```

ch6_text.csv 里改了 `quest_1006_desc` 和六条步骤文字（原来 p1601「去欢乐堡外的营地」在章开头就已经站在营地里了，改成「去营帐找亚瑟」；p1603 写明在对岸；p1605 写明要到篝火边坐到天亮，不然玩家不知道谈判从哪开始）。新加 `quest_1006_end_E1–E3`，另加 `ending_E1–3_name`，结局回顾要标题就用，不要就删。

---

## 4. NPC 站位（npcs.json 用）

| id（建议） | 名字键 | 地方 | node | condition |
|---|---|---|---|---|
| arthur_jg | npc_arthur | joyous_gard 营帐 | Ch6_Arthur | `quest_part(1006) == 1601` |
| gawain_jg | npc_gawain | joyous_gard 城门前 | Ch6_Gawain | `quest_part(1006) == 1601` |
| kay_jg | npc_kay | joyous_gard 粮车 | Ch6_Kay | `quest_part(1006) == 1601 and $c_kay == "party"` |
| bedivere_jg | npc_bedivere | joyous_gard 帐篷门口 | Ch6_Bedivere | `quest_part(1006) == 1601` |
| lancelot_jg | npc_lancelot | joyous_gard 城门口 | Ch6_Lancelot | `quest_part(1006) == 1602` |
| guinevere_jg | npc_guinevere | joyous_gard 营帐门口 | Ch6_Guinevere | `quest_part(1006) == 1602` |
| arthur_coast | npc_arthur | coast 码头 / 对岸营帐 | Ch6_Arthur | `quest_part(1006) == 1602 or quest_part(1006) == 1603` |
| mordred_coast | npc_mordred | coast 码头石阶 | Ch6_Mordred | `quest_part(1006) == 1602` |
| gawain_coast | npc_gawain | coast 对岸营地 | Ch6_Gawain | `quest_part(1006) == 1603` |
| arthur_camlann | npc_arthur | camlann 营帐外 | Ch6_Arthur | `quest_part(1006) == 1605` |
| kay_camlann | npc_kay | camlann 营地 | Ch6_Kay | `quest_part(1006) == 1605 and $c_kay == "party"` |
| bedivere_camlann | npc_bedivere | camlann 营地 | Ch6_Bedivere | `quest_part(1006) == 1605` |
| gareth_camlann | npc_gareth | camlann 营地 | Ch6_Gareth | `quest_part(1006) == 1605 and $c_gareth == "party"` |
| campfire（物件） | — | camlann 营地中间 | Prop_campfire | `quest_part(1006) == 1605` |
| 路人士兵 / 水手 | npc_soldier / npc_sailor | joyous_gard、coast、camlann | "" | 各自那一步；闲话 `bark_jg_soldier_1/2`、`bark_coast_sailor_1`、`bark_camlann_soldier_1/2` |

自动触发：`Ch6_Start`（第 6 章第一次进 joyous_gard）、`Ch6_1605_Camp`（1605 第一次进 camlann）。

不站在地图上、只在过场说话的人（npcs.json 的 speakers 要配头像）：主教（罗切斯特主教）、信使、摩根。

`npc_gawain` `npc_lancelot` `npc_guinevere` `npc_mordred` `npc_bedivere` `npc_gareth` `npc_soldier` 别的分片已经加过，值一样，我这里删了没重复写。

---

## 5. 遭遇和敌人

| 遭遇 | 用在 | 建议 |
|---|---|---|
| `joyous_gard` | 1601 攻城门 | kind story、flee false；敌人 `joyous_guard` ×3；party max 2，不固定；win all_down。台词交代了为什么守军只挡：兰斯洛特下令不许杀王的人，和「全员轮流防御」对上 |
| `dover` | 1604 登陆 | 已有 survive 4、story、flee false。敌人 `dover_archer`（每回合箭雨打全部）。建议 party.fixed `["gawain"]`：高文最后一仗，打完他就死 |
| `camlann` | 1605，D5a、D5b | kind story、flee false；敌人 `mordred`（首领）+ `mordred_soldier` ×2；party.fixed `["arthur"]`、max 2；win all_down。台词里这一仗打完莫德雷德是退回人堆里，黄昏才死在亚瑟的矛下（Ch6_1605_Fall） |
| **`camlann_rear`（新）** | 1605，只在 D5c | 你在后队，侧面冲下来一队人扑辎重。敌人 `mordred_rider` ×2 + `mordred_soldier`；没有亚瑟；party max 2；win all_down；flee false。见第 11 节第 1 条 |

需要的敌人（名字键已在 csv）：
- `joyous_guard` 欢乐堡守军：轮流「举盾」（全员加挡）和「推」（小伤害），不连击。
- `dover_archer` 多佛的弓箭手：每回合「箭雨」打全部，固定伤害，撑过 4 回合（CONTENT_SCHEDULE 已定）。
- `mordred` 莫德雷德：两个「？」、召唤 `mordred_soldier`、蓄力重击亚瑟；召唤和蓄力在同一回合，只能打断一个（CONTENT_SCHEDULE 已定）。台词那头呼应：战斗里能打断他砍亚瑟的那一下，黄昏那一剑打断不了（拦不住的事），呼应第 1 章梅林「哪些能停，你得自己分」。
- `mordred_soldier` 莫德雷德的兵：普通步兵，被召唤的就是它。
- `mordred_rider` 莫德雷德的骑兵（camlann_rear 用）：冲锋打 lowest_hp。

凯在 D5b 战死的路线，camlann 开打时他已经是 dead，出战名单里没有他。加雷斯在 1601–1604 是 left，所以 joyous_gard、dover 选不到他。

---

## 6. 伏笔回收对照表

| 伏笔 | 在哪收 | 怎么收 |
|---|---|---|
| 剑鞘（第 3 章） | Ch6_1605_Fall | 贝狄威尔撕衣襟按伤口，一块红透再撕一块；亚瑟的手摸到腰间挂剑鞘的空皮扣，垂下来 |
| 梅林的白蜡木杖（第 1 章） | Ending_E3 | 你把杖靠在巨石上，杖头磨亮的那块对着你 |
| 绿腰带（第 3 章，S1） | Ch6_1604_Crossing / Ch6_1604_Gawain | S1a：开船前的信里「那条带子，我还系着」；S1b：高文临死让你拿走箱底的带子，夜里你在两件冬衣底下找到它，还卷成一团（照 Side.yarn 他藏的样子） |
| 摩根（第 1 章） | Ch6_1606_Lake | 黑船上掀开兜帽的女人，就是第 4 章站在湖边平石上扔掉剑鞘的那张脸；她叫亚瑟「伊格赖因的儿子」，和第 4 章她自己的叫法一样 |
| 那条蛇（第 5 章） | Ch6_1601_Parley（落空）、Ch6_1605_Parley（应验） | 欢乐堡两军中间没披甲的人面对面，你盯着草，什么也没有；卡姆兰蛇钻出来，按 D5 不同咬不同的人 |
| 湖给出的东西要收回（第 3 章） | Ch6_1606_Lake | 第三次，白袖子的手接住剑，挥三下，沉下去，水面连个泡都没冒 |
| 莫德雷德说话前先看一眼亚瑟（第 4 章） | Ch6_Mordred、Ch6_1602_Harbor、Ch6_1603_News、Ch6_1605_Fall | 码头上照旧先看亚瑟；伦敦夜里他朝走廊那头看了一眼，那头没有人（亚瑟出海了）；临死顺着矛杆挪到亚瑟跟前，抬眼看了亚瑟一眼，叫了一声「父亲」 |
| 学徒的木碗（第 1 章） | Ch6_1606_Lake（硌着胯骨）、Ending_E1 | 不倒水，扔进湖里，打个转沉下去；收尾湖面「只照出灰白的天」，对上第 1 章石圈那句 |
| 梅林的灰兜帽（第 1 章） | Ending_E3 | D3a 在石缝里亲眼看见；D3b 你把高文第 4 章带回来的那顶塞回石缝 |
| 高文护腕上弟弟们的名字（第 3 章，第 5 章已收） | Ch6_Gawain、Ch6_1604_Gawain、Ch6_Gareth_Bracer | 余波：有几处只剩线头；临死解下来给加雷斯，加雷斯翻过来看见自己的名字，扣了两回才扣上 |
| 凯的剑总放在别处（第 1 章，第 2 章已收） | Ch6_1605_Parley | 余波：凯倒下时手按在剑柄上，剑还没出鞘 |
| 亚瑟小时候「老盯着水桶看」（Ch1 亚瑟的台词） | Ch6_1606_Lake | 船上亚瑟：「你小时候总盯着水桶看。现在呢，看得见我去哪吗？」 |

**bible 列的第 6 章回读，逐条落点**：D3a → E3 选项；D4a / D4b（无 D3b）→ Parley 里阿格规文活着站在莫德雷德身后；D4b（无 D3b）→ 伦敦过场莫德雷德当众问调令（码头上他还先试探你）；D4c → 结局回顾；D5a 两句 → Ch6_1605_Dream；D5b 凯 → Ch6_Kay 1605 + Parley；D5b 贝狄威尔 → Parley「王要我站在他旁边」；D5c → 湖边「你来晚了一步」；S1a → 信开船前寄出，湖边兰斯洛特远远看见船；S2a → 加雷斯赶来卡姆兰、跟着上战场；S2c → Ch6_Kay 1601「我该少骂他几句」；S3a（V2）→ 开船前的信提那盘苹果；S3b → 伦敦信使认出你的戒指；S3c、S4a、S4b、S4c → 结局回顾（prophecy.json），对白里不写；V1 → 欢乐堡高文松手、Ch6_Gawain、兰斯洛特在对岸留船、湖边赶上说最后一句。

---

## 7. 逻辑自查表（谁凭什么知道）

| 说话人 | 说的事 | 怎么知道、什么时候 |
|---|---|---|
| 亚瑟 | 守军只挡不打 | 自己围城十五个星期看见的 |
| 亚瑟 | 高文发过誓 | 第 5 章 1505 当众发誓，他在场 |
| 亚瑟 | 「梅林说过的事拦不住」「他是我……」 | 第 3 章 1301 梅林告诉他摩高斯的孩子会毁掉他；他知道莫德雷德是自己的儿子，话停在「儿子」前面，没有当众说 |
| 亚瑟 | 梦见高文劝他等一个月；派贝狄威尔去谈 | 自己的梦、自己下的令（第 21 卷） |
| 亚瑟 | 谈判时草里有蛇，「你在礼拜堂看见的」 | 只在 D5a：Ch5 里你在礼拜堂门口当面告诉他 |
| 亚瑟 | 「你骗我」「快死的人」 | 看见贝狄威尔的靴子是干的；第 4 章起知道没有剑鞘血止不住 |
| 亚瑟 | 「高文在梦里跟我说，你会来」「你的盾，又换了一面」 | 自己的梦；眼前兰斯洛特的新盾（1602 他在城门口给新盾穿皮带） |
| 高文 | 你那天提的事 / 誓收不回 | V1：第 5 章你私下提绿腰带；誓是当众发的 |
| 高文 | 加雷斯留在卡美洛 | 兄弟之间说的 |
| 高文 | 兰斯洛特两回停手 | 1602–1603 之间班威克城下自己被打下马两回 |
| 高文 | 信里「王回去要打莫德雷德」 | 1603 信使来时他在帐篷口听完了 |
| 高文 | 那盘苹果 | S3a：你告诉他的，皮内尔当场被抓 |
| 高文 | 加雷斯「那天没去是对的」/「不该跟他吵」 | S2a 加雷斯违令没去法场；S2b 两兄弟当着宫里人吵过（Ch5） |
| 兰斯洛特 | 法场上的人没披甲，没认出是谁 | 他自己砍的；死了谁 1504 之后公开 |
| 兰斯洛特 | 在对岸留船 | 自己的安排（V1），1602 当面告诉你 |
| 兰斯洛特 | 高文的信 | V1：收到死前那封信，在船上读完 |
| 桂妮维亚 | 王要她回伦敦，莫德雷德看家 | 亚瑟告诉她的（交接在码头，决定在之前） |
| 桂妮维亚 | 莫德雷德「那天夜里站在我门外」 | 1503 揭发，她在屋里；莫德雷德各路线都在场（Ch5） |
| 桂妮维亚 | 戒指在你手上 | S3b：Ch5 开审前她让侍女塞给你 |
| 桂妮维亚 | 信尾「他说的那句话，我不懂」 | 她不知道莫德雷德是亚瑟的儿子（认知边界里没有她），所以照原样写给亚瑟 |
| 莫德雷德 | 阿格规文来信问调令 | D4b（无 D3b）：阿格规文在北边写信抱怨（bible）；Ch5 里阿格规文整章在北边，所以写成「来信」，不写「回来以后」 |
| 莫德雷德 | 「王在班威克城下中了箭，死了」 | 他自己编的；他知道亚瑟在班威克（码头上交接时知道王去哪） |
| 莫德雷德 | 「他连一句话都不肯给我」 | 第 4 章起从摩高斯那知道身世；1404 亚瑟只给了一句「好好当差」 |
| 莫德雷德 | 「印，国家，现在又是康沃尔和肯特」 | 1602 接过铜印和国家；1605 贝狄威尔带去的条件 |
| 莫德雷德 | 「父亲」 | 一直知道；第 6 章起这件事可以说出口（facts：public_after_ch 6） |
| 凯 | 厨房里那小子 | 第 4 章他给帮工起外号（S2 的给任务人）；法场死了谁 1504 后公开 |
| 凯 | 肩膀上替加雷斯挨的那一刀 | S2b：Ch5 法场，伤在肩膀 |
| 凯 | 「一条蛇是吧？我去找」 | D5b 凯信你：Ch5 你把他拉到一边说的；「明天两边在中间说话」是营地里传开的（贝狄威尔白天去谈的） |
| 凯 | 「你那条蛇，我还是不信」 | D5b 凯不信你：Ch5 你告诉贝狄威尔时他在旁边听见，笑了一声「一条蛇？」 |
| 凯 | 「在厨房里真是糟蹋了」 | 知道加雷斯在厨房干过一年 |
| 凯 | 「我先……看见它的」 | 他自己在草里先看见、踩住了蛇 |
| 贝狄威尔 | 见了莫德雷德，明天各带十四人 | 他就是去谈的人 |
| 贝狄威尔 | 「蛇是从草里出来的，你说的」 | D5b 告诉的是他：Ch5 他在剑柄上系了布条记着 |
| 贝狄威尔 | 「王要我站在他旁边」 | 亚瑟那边吹了短号，叫他回去（Parley 里先演号声） |
| 贝狄威尔 | 「高文让你等一个月」 | 亚瑟派他去谈时说了缘由 |
| 贝狄威尔 | 「你来晚了一步」 | D5c：他守在亚瑟身边，看着你从后队跑来 |
| 加雷斯 | 莫德雷德叫他弟弟、叫他去伦敦 | 他留在卡美洛，莫德雷德名义上是洛特的儿子、他的哥哥 |
| 加雷斯 | 「他说不该跟我吵？」 | 你交护腕时把高文的话带到了（旁白写明「把高文的话说了」） |
| 加雷斯 | 「法场上，你也是这么拖我的」 | S2b 法场上凯拖过他 |
| 摩根 | 「伊格赖因的儿子亚瑟」「去阿瓦隆」「伤吹了太多冷风」 | 她是亚瑟同母的姐姐；湖与阿瓦隆那边的人（世界规则 7）；眼前的伤 |
| 主教 | 教皇的令 | 他带着教皇的信来（第 20 卷罗切斯特主教） |
| 信使 | 王后的亲笔信；S3b 认出你的戒指捎话 | 王后交给他的；王后吩咐他找戴着她戒指的人 |
| 你（选项、旁白） | 「梅林说过，摩高斯的孩子会毁掉你」 | 第 3 章 1301 你在场；私下说，没有当众 |
| 你 | 「圣水盆里就是这样」 | 第 5 章看见的 |
| 你 | 认出摩根 | 第 4 章 1402 湖边，她站在平石上扔剑鞘，你们赶到岸边看见 |
| 你 | 「阿瓦隆」 | 摩根上一句刚说出这个地名（原来游戏里没出现过这个词，所以让她先说） |
| 你 | 「你让我替你看着他」 | 第 1 章阁楼，梅林：「我走了以后，你替我看着他。」 |
| 你 | 「我第一次在水里看清一整件事，是在庄园后面的石圈」 | 第 1 章 1102 |
| 旁白 | 伦敦那一段 | 你不在场：过场前写明亚瑟把王后的信塞给你念，过场是信里写的事，结尾回到信尾那一行。台词全部标了说话人 |

---

## 8. knowledge_check 判断（Ch6 的 11 条候选，全部判「不算」）

| 行 | 节点 · 说话人 | 事实 | 判断 |
|---|---|---|---|
| 325 | Ch6_1605_Dream · 亚瑟 | merlin_place（康沃尔） | 不算。说的是亚瑟割给莫德雷德的领地康沃尔（第 21 卷原文的条件），和梅林在哪无关 |
| 383 | Ch6_1605_Parley · 莫德雷德 | merlin_place（康沃尔） | 不算。同上，领地 |
| 521 | Ch6_1606_Lake · 你 | merlin_place | 不算。这个选项带 `<<if $player_knows_place>>`，只有 D3a / D3b（你知道地方）才出现 |
| 73 | Ch6_1601_Parley · 高文 | gareth_identity | 不算。2401 之后公开（原作事件不管做没做支线都发生）；S2c 时加雷斯死在法场，1504 后公开 |
| 90 | Ch6_Gawain · 高文 | gareth_identity | 不算。同上，而且是他亲弟弟 |
| 107 | Ch6_Kay · 凯 | gareth_identity | 不算。S2b 分支，凯在 S2 里改口叫「加雷斯爵士」 |
| 274、276 | Ch6_1604_Gawain · 高文 | gareth_identity | 不算。兄弟 |
| 111 | Ch6_Kay · 凯 | snake | 不算。D5b 且凯信你：Ch5 你亲口告诉他（bible 知情：凯 D5b） |
| 114 | Ch6_Kay · 凯 | snake | 不算。D5b 凯不信你：Ch5 他在旁边听见你告诉贝狄威尔（bible 认知边界：凯 D5b，信不信看 D1a / S2b） |
| 327 | Ch6_1605_Dream · 亚瑟 | snake | 不算。分支条件 `$D5 == "D5a"`，bible 知情：亚瑟 D5a |

另查了脚本列不出的几件：`mordred_parentage`（「他是我……」话没说完；「父亲」在第 6 章，facts 允许第 6 章公开）；`usurp`（台词里没用「篡位 / 伪造死讯」，莫德雷德当众说的是他编的死讯）；`affair`（王后只说莫德雷德「站在我门外」，没把兰斯洛特的名字和「爱」放一起）；`stone_sword_vs_excalibur`（全章没写「王者之剑」四个字，写「湖里来的那把剑」，免得撞 misnomer）。

---

## 9. 检查结果

- `check_style.py Ch6.yarn ch6_text.csv`：禁用 0 条，待判 0 条。
- `check_content.py .`：和 Ch6.yarn 有关的错误 0 条（另有 238 条「没有 #line」，按要求不加，数目正好等于台词行数）。提醒只有本作新指令 `companion` `book_after` `autosave`（插件指令表写死，不算错）。整个项目报的 1323 个错误是各章都还没编行号。
- `knowledge_check.py .`：Ch6 候选 11 条，判断见第 8 节。
- `tools/check_project_data.py .`（不在要求里，顺手跑的）：Ch6 7 条，都是合并前的预期：6 条 `after_D5*` 文本键在 ch6_text.csv 里；1 条 `camlann_rear` 遭遇等 combat.json。
- 路线模拟（自己写的小脚本，D1 × D2 × D3 × S2（含没做）× D5 全组合）：凯的下场和 bible 下场表一致；E2 能不能选和 outline.json 的 requires_any 一致；E1 总能选；E2、E3 四种有无组合都出现。
- 对过前几章正在写的文件：Ch4 摩根在湖边叫亚瑟「伊格赖因的儿子」；Ch5 凯的刀伤在肩膀、阿格规文整章在北边、D5 的三个选项条件、王后的戒指；Side 里 S1b 腰带卷成团压在两件冬衣底下。Ch6 都照这些改过。节点名和别的文件不重名。

---

## 10. 用到的文本键（ch6_text.csv，34 条）

改：`quest_1006_desc`、`quest_1006_p1601`–`p1606`。新：`quest_1006_end_E1–E3`、`ending_E1–3_name`、`after_D5a_trust` `after_D5a` `after_D5b_kay_gareth` `after_D5b_kay` `after_D5b_bedivere` `after_D5c`、`npc_sailor`、5 条闲话、4 个遭遇名、5 个敌人名。

---

## 11. 拿不准、要你定的

1. **D5c 打 `camlann_rear` 这场新遭遇。** bible 写 D5c「你在后队，等你赶到亚瑟身边，莫德雷德的那一剑已经落下了」，而 `camlann` 要亚瑟上场、莫德雷德蓄力砍亚瑟，你和亚瑟并肩打完这场，就说不上「在后队、来晚了」。所以 D5c 改打后队一仗（没有亚瑟）。代价：多一场遭遇的数据。不要的话，把那行换成 `camlann`，同时得改 D5c 的三句旁白。
2. **加雷斯 1601–1604 不在队。** 他的骑士是兰斯洛特封的（S2b 还替兰斯洛特作证），我让他不肯去围欢乐堡、留在卡美洛，卡姆兰前夜才赶来，正好对上 bible「跟着你上了最后一战的战场」。实现上用 `companion gareth left` → `party` 切，这几步圆桌面板上他的椅子会空着。要是你想让他一直跟着，就删掉这两处，再改高文、凯各一句。
3. **coast 一片地方两个用处**：1602 是英格兰这边的码头，1603 是对岸班威克城外的营地。地图要么做两张，要么一张海边图按 `quest_part` 换帐篷。
4. **S3a 回读和 V2、下场表冲突**：bible 里 S3a 的回读写「（选了 V2）在多佛受伤当晚写信，信里提到那盘苹果」，V2 和下场表都写「登陆前寄出」，兰斯洛特能不能远远看见那条船也按「登陆前」算。我照下场表：苹果写进开船前那封信。要改 bible 的话改 S3a 那条回读。
5. **高文第一次听说「兰斯洛特没认出法场上的人」**：bible 写的是「第 6 章兰斯洛特的回信」，我放在欢乐堡调停时兰斯洛特当面说（第 20 卷原文就是当面说），没有另写一封回信。
6. **莫德雷德临死叫亚瑟「父亲」** 是补写（原文没有这句）。他的命门是想被父亲承认，那句「他连一句话都不肯给我」到这里收。
7. **谈判从篝火开始**：在火边选「坐到天亮」才进谈判，这样玩家一定先看见篝火边站着谁（第四处看得出选择的地方）。你要是想让亚瑟的梦直接接谈判，就把篝火的选项挪进 Ch6_1605_Dream 结尾。
8. **王后的名字**：任务里写的是「桂妮薇儿」，bible.json、前几章和别的分片都用「桂妮维亚」，我用「桂妮维亚」。
9. **地图切换**：Ch6_1605_Fall 演完直接 `<<jump Ch6_1606_Lake>>`，引擎要在 1606 时把场景切到 lake_last（没有指令就补一个 teleport，或在 progress_quest 1606 时切）。
10. 欢乐堡调停里 V1 那一支高文不接话，分支里只有一行注释。插件的解析器能处理空分支，要是你们的版本报错，加一句旁白「高文咬着牙，没有拔剑。」就行（行数会到 239）。
11. S4c「兰斯洛特成了隐修士后常去那条河边」只留给结局回顾，Ch6 对白里没写（行数不够，兰斯洛特出场就那一次）。
