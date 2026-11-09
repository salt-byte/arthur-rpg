# 第 4 章 · 梅林离开 · 交回说明

文件：`content/dialogue/Ch4.yarn`（17 个节点，197 行，其中选项 13 行；没有 `#line:` 标签）；`frag/ch4_text.csv`（39 个文本键，其中 1 个覆盖现有的 unlock_u_scabbard_lost_origin，4 个改现有的任务步骤文字）。

## 1. 节点：谁、在哪、怎么触发

| 节点 | 步骤 | 在哪 | 怎么触发 | 演完去哪 |
|---|---|---|---|---|
| `Ch4_Start` | 1401 | 卡美洛院子，井台边 | 换章自动演：maps.json 的 `chapter_start."4"` 指到它 | 玩家自己走去东塔楼的阁楼 |
| `Ch4_Attic` | 1401 | 卡美洛东塔楼顶上的阁楼 | 阁楼墙角的杖（道具，`quest_part(1004) == 1401`），或走进阁楼门 | 自动 `<<jump Ch4_Hall>>` |
| `Ch4_Hall` | 1401 → 1402 | 大厅 | 由 Ch4_Attic 跳过来 | 末尾进 1402，跳 Ch4_ScabbardGone |
| `Ch4_ScabbardGone` | 1402 | 王的卧房外的走廊（夜里） | 由 Ch4_Hall 跳过来 | 玩家出北门，去湖 |
| `Ch4_Chase` | 1402 | 湖：堤路上 | 碰到堤路上的摩根护卫队长（npcs.json `morgan_captain`，`quest_part(1004) == 1402`）。打仗用 `<<fight_npcs morgan_chase>>` | 打完跳 Ch4_LakeShore |
| `Ch4_LakeShore` | 1402 → 1403 | 湖岸：水边平石、芦苇丛 | 由 Ch4_Chase 跳过来 | 末尾进 1403，跳 Ch4_YearsLater |
| `Prop_hood` | 1402 | 湖：去堤路那段岸边的芦苇 | 道具。条件 `$D3 == "D3c" and quest_part(1004) == 1402 and not visited("Prop_hood")`；拿完从地图上消失（overworld.json 的 W1） | 回地图 |
| `Ch4_YearsLater` | 1403 | 大厅（十七年后） | 由 Ch4_LakeShore 跳过来 | 玩家去城门口接兰斯洛特；2401 从这一步开 |
| `Ch4_Lancelot` | 1403 → 1404 | 1403 在城门口；1404 在院子；1405 在回廊 | 和兰斯洛特说话。1403 那一支里他入队，任务进 1404 | 回地图 |
| `Ch4_Brothers` | 1404 → 1405 | 大厅 | `quest_part(1004) == 1404` 时走进大厅。建议做成大厅门口的高文（`gawain_hall_door`，节点 Ch4_Brothers） | 末尾进 1405，玩家还站在大厅里 |
| `Ch4_Feast` | 1405 | 大厅，圆桌 | `quest_part(1004) == 1405` 时走到圆桌边你的位子（主线标记在那把椅子上）。1404 演完玩家已经在大厅里，不能用「走进大厅」触发 | `<<chapter 5>>` |
| `Ch4_Arthur` | 1401、1402、1403、1405 | 1401 大厅王座；1402 院子（去北门的路上）；1403、1405 大厅王座边 | 和亚瑟说话 | — |
| `Ch4_Kay` | 1401–1405 | 1401 院子井台；1402 北门；1403、1404 厨房边的账房；1405 大厅门口 | 和凯说话。1403/1404 第一次说话 `<<jump S2401_Rumor>>`（Side.yarn，支线作者写的，里面开 2401，带 D1a、D1c 的回读） | — |
| `Ch4_Gawain` | 1401–1405 | 1401 大厅（D3b 时不放，他在外面追梅林）；1402 北门；1403 大厅；1404 院子；1405 大厅门口 | 和高文说话 | — |
| `Ch4_Guinevere` | 1401–1405 | 1401 大厅；1402 王的卧房外的走廊；1403、1404 大厅旁的回廊；1405 大厅门口 | 和王后说话 | — |
| `Ch4_Mordred` | 1405 | 大厅外的回廊 | 和莫德雷德说话（Ch4_Brothers 之后才出现） | — |
| `Ch4_Agravaine` | 1405 | 大厅外的回廊 | 和阿格规文说话（Ch4_Brothers 之后才出现） | — |

妮妙、摩根只在 Ch4_LakeShore 里出场，不站在地图上。湖岸上可以放一个骑白马的摩根人影当布景（1402，没有节点）。

## 2. 变量和函数

用到的（都在 Variables.yarn 里）：`$D1` `$D2` `$D3` `$D4` `$S1` `$lancelot_warned` `$player_name`（插值）。函数：`quest_part()` `has_unlock()` `visited()`。

设的：`$D4`（三个选项），`$lancelot_warned`（D4a）。

**缺一个**：`$arthur_knew_affair`（布尔，默认 false）。bible.json 里 D4b 的 `flags_by_condition` 写着「没有 D3b → arthur_knew_affair: true」，build_variables.py 没读 `flags_by_condition`，所以 Variables.yarn 里没有。Ch4_Feast 里 D4b 没有 D3b 那一支留了注释，要的话在注释下面加 `<<set $arthur_knew_affair to true>>`。Ch5.yarn 现在用的是 `$D4 == "D4b" and $D3 != "D3b"`，不加也能跑；加上以后第 6 章莫德雷德那句质问可以直接读它。

D4b 且有 D3b 时 `$D4` 仍然存 `"D4b"`（玩家选的就是它），结算按 D4c 走，靠 `$D3` 区分。Ch5.yarn 也是这么读的。

## 3. 要改的数据（合并时）

**quests.json 1004**：结构不用改。步骤文字改了四条，在 csv 里：
```json
"1004": {
  "type": "main", "name": "quest_1004_name", "desc": "quest_1004_desc", "chapter": 4,
  "parts": [
    {"id": 1401, "text": "quest_1004_p1401", "area": "camelot"},
    {"id": 1402, "text": "quest_1004_p1402", "area": "lake", "battle": "morgan_chase"},
    {"id": 1403, "text": "quest_1004_p1403", "area": "camelot"},
    {"id": 1404, "text": "quest_1004_p1404", "area": "camelot"},
    {"id": 1405, "text": "quest_1004_p1405", "area": "camelot"}
  ]
}
```
改文字的原因：p1403 原来是「去卡美洛的大厅」，现在这一步要去城门口接兰斯洛特；p1404 原来是「去大厅见新来的年轻人」，和厨房里那个不肯说名字的年轻人分不清，改成「去大厅见奥克尼来的人」；p1405 写明在圆桌边你的位子上入席，和触发方式对上。

**prophecy.json**：D4 那一条加 `"text": "vision_D4"`。三句各 18、21、30 字，在 30 字以内。

**story-unlocks.json**：
```json
{"id": "u_reveal", "...": "...", "popup": {"name": "unlock_u_reveal_name", "effect": "unlock_u_reveal_effect", "origin": "unlock_u_reveal_origin"}},
{"id": "u_kay_cover", "at": "1402", "...": "...", "popup": {"name": "unlock_u_kay_cover_name", "effect": "unlock_u_kay_cover_effect", "origin": "unlock_u_kay_cover_origin"}},
{"id": "u_lancelot", "...": "...", "popup": {"name": "unlock_u_lancelot_name", "effect": "unlock_u_lancelot_effect", "origin": "unlock_u_lancelot_origin"}}
```
u_kay_cover 的 at 从 1401 改成 1402：凯是在剑鞘被偷那一夜、听亚瑟说「我挨了刀不流血」之后才说「我骑在你前头」。u_scabbard_lost 的 origin 文字改了（见第 8 节第 1 条）。

**maps.json**：`"chapter_start": {"4": {"area": "camelot", "cell": [院子井台边], "node": "Ch4_Start"}}`。

**overworld.json**：`camelot`、`lake` 两片地方现在登记成 `chapter: 3`。第 4 章还要用（卡美洛第 5 章也用）。如果换章会关掉上一章的地方，这两片得改成能跨章，或者另登记一份第 4 章的。湖那片要在堤路前 30 秒路程内放一座圣龛；卡美洛的礼拜堂当第 4 章第一座圣龛。

**companions.json**：关系句建议加一条 `"lancelot_warned": "知道你在酒杯里看见过什么，不再当面看你的眼睛"`。

**Variables.yarn**：见第 2 节。

## 4. 地图上要站的人

| npcs.json id | 名字键 | 地方 · 位置 | 条件 | node |
|---|---|---|---|---|
| kay_ch4_yard | npc_kay | camelot · 院子井台 | `quest_part(1004) == 1401` | Ch4_Kay |
| kay_ch4_gate | npc_kay | camelot · 北门 | `quest_part(1004) == 1402` | Ch4_Kay |
| kay_ch4_office | npc_kay | camelot · 厨房边的账房 | `quest_part(1004) == 1403 or quest_part(1004) == 1404` | Ch4_Kay |
| kay_ch4_hall | npc_kay | camelot · 大厅门口 | `quest_part(1004) == 1405` | Ch4_Kay |
| arthur_ch4_throne | npc_arthur | camelot · 大厅王座 | `quest_part(1004) == 1401 or quest_part(1004) == 1403 or quest_part(1004) == 1405` | Ch4_Arthur |
| arthur_ch4_yard | npc_arthur | camelot · 院子 | `quest_part(1004) == 1402` | Ch4_Arthur |
| attic_staff | （道具） | camelot · 阁楼墙角 | `quest_part(1004) == 1401` | Ch4_Attic |
| gawain_ch4 | npc_gawain | camelot · 大厅 / 北门 / 院子 / 大厅门口（按步骤分四条） | 1401 加 `$D3 != "D3b"`；1402–1405 各一条 | Ch4_Gawain |
| gawain_hall_door | npc_gawain | camelot · 大厅门口 | `quest_part(1004) == 1404` | Ch4_Brothers |
| guinevere_ch4 | npc_guinevere | camelot · 大厅 / 卧房外走廊 / 回廊 / 大厅门口（按步骤分） | 1401–1405 | Ch4_Guinevere |
| lancelot_gate | npc_lancelot | camelot · 城门口 | `quest_part(1004) == 1403` | Ch4_Lancelot |
| lancelot_ch4 | npc_lancelot | camelot · 院子（1404）/ 回廊（1405） | `quest_part(1004) == 1404 or quest_part(1004) == 1405` | Ch4_Lancelot |
| mordred_ch4 | npc_mordred | camelot · 回廊 | `quest_part(1004) == 1405` | Ch4_Mordred |
| agravaine_ch4 | npc_agravaine | camelot · 回廊 | `quest_part(1004) == 1405` | Ch4_Agravaine |
| feast_seat | （道具） | camelot · 圆桌边你的椅子 | `quest_part(1004) == 1405` | Ch4_Feast |
| morgan_captain | npc_morgan_captain | lake · 堤路正中 | `quest_part(1004) == 1402` | Ch4_Chase |
| prop_hood | （道具） | lake · 去堤路那段岸边的芦苇 | `$D3 == "D3c" and quest_part(1004) == 1402 and not visited("Prop_hood")` | Prop_hood |
| maid_ch4_1 | 路人 | camelot · 院子、厨房 | `quest_part(1004) == 1401 or quest_part(1004) == 1402` | 空，闲话 bark_ch4_maid_1、bark_ch4_maid_2 |
| squire_ch4_1 | 路人 | camelot · 城门口 | `quest_part(1004) >= 1403` | 空，闲话 bark_ch4_squire_1 |

美手（厨房灶前）由支线作者放，条件写在 Side.yarn 的 S2401_Kitchen 注释里。

卡美洛这一章要有的地方：东塔楼阁楼、大厅（王座、王座左手边那块有坑的石板、圆桌和你的椅子）、王的卧房外走廊、院子井台、北门、城门口、厨房边的账房、回廊。湖：堤路（两边一人高的芦苇）、芦苇岸、水边平石、那块像人骑在马上的灰石头。

## 5. 遭遇和要新设计的敌人

只有一场：`morgan_chase`（combat.json 里现在是 `_待写`）。章节内容表定了敌人行为，下面是按台词对好的草案，数值交给 balancing：

```json
"morgan_chase": {
  "name": "enc_morgan_chase", "kind": "quest",
  "enemies": ["morgan_captain", "morgan_knight", "morgan_knight"],
  "party": {"fixed": ["arthur"]},
  "win": {"type": "all_down"}
}
```
- `morgan_knight`（摩根的骑士）：轮流防御（两个骑士隔回合举盾）；其中一个隔两回合吹号，从芦苇后面叫来 1 个骑士（召唤增援，上限 4）。台词写的是「三匹马横在路上，芦苇后面还藏着三匹」，对得上：开场 3 个，后面最多再来 3 个。
- `morgan_captain`（摩根的护卫队长，首领）：第一个头上有「？」的首领，战斗页「怎么设计每一场」第 3 条。台词写他握剑的手看不清，揭开以后看清剑刃朝哪边，所以「？」建议藏的是「打谁」：比如蓄力重劈，目标藏起来。
- 这一仗开打前已经失去剑鞘（见第 8 节第 1 条），亚瑟身上不该有「剑鞘」状态，这是第一场亚瑟会倒下的仗。
- 召唤出来的骑士照规则不给经验、不掉东西。
- 要加的文本键：`enemy_morgan_knight`、`enemy_morgan_captain`、`enc_morgan_chase` 已在 csv 里；招式名（`move_`）等写数值的人定。

红骑士（2401）是支线的仗，不在这里。

## 6. 逻辑自查：每个说话的人知道什么、什么时候、从哪知道

| 人 | 这章台词里用到的事 | 他从哪知道 | 对得上吗 |
|---|---|---|---|
| 凯 | 梅林昨晚跟湖边那个姑娘出了城 | 守门的说的（他是总管） | 对 |
| 凯 | D3b：高文天没亮就追出去了 | 总管管马厩；Ch3 里高文天没亮下楼牵马 | 对 |
| 凯 | 梅林在的那些年摩根没来过 | 总管接待来客，自己看见的 | 对 |
| 凯 | 剑鞘让亚瑟不流血 | 当场听亚瑟说的；之前不知道（他第 3 章没去湖边），所以先说「打十个」 | 对 |
| 凯 | 你能看见将来（「你那碗水里，照得出他叫什么吗？」） | 第 4 章你接替梅林，宫里人人知道（facts sight：第 4 章公开） | 对 |
| 亚瑟 | 梅林会被活着埋进土里 | Ch3_Night 梅林当面说的 | 对 |
| 亚瑟 | D3c：梅林走了没告诉他 | Ch3：出远门的事梅林只跟你说过 | 对 |
| 亚瑟 | D3a：你昨晚上了阁楼 | Ch3_Night：他的门在你身后半开着 | 对 |
| 亚瑟 | D3b：高文在追，蹄印往西南 | 他自己派的人；没说「康沃尔」，地方他第 4 章高文回来才知道 | 对 |
| 亚瑟 | D2a：泉边你说中了 | 第 2 章你告诉过他，第 3 章泉边应验 | 对 |
| 亚瑟 | D2b、D2c（没有 D1b、D3b）：「他说你也能看见」 | bible 写定的回读：梅林告诉过他。他此时还不确信，所以是问句 | 对 |
| 亚瑟 | 剑鞘的用处；摩根是伊格赖因的女儿 | 第 3 章湖边梅林说的；Ch3_Night 梅林提醒他看好剑鞘、提到摩根 | 对 |
| 亚瑟 | 「他母亲是我姐姐」 | 第 3 章营帐里梅林告诉他（facts mordred_parentage：亚瑟第 3 章知道）。只对你说，你也在场听过 | 对，没有当众说 |
| 亚瑟 | D4b：王后和兰斯洛特 | 宴席上你告诉他（facts affair：D4b 没有 D3b，第 4 章末） | 对；D3b 时他打断，没听到内容 |
| 高文 | D3b：康沃尔海边、一夜之间冒出来的石头、推不动 | 他自己追到康沃尔，听当地人说（bible D3b） | 对 |
| 高文 | 摩根的骑士盾上画着黑鸟 | 补写，他见过 | 不和任何设定冲突 |
| 高文 | S1a 的绿腰带、S1b 的秘密 | 他自己的事 | 对 |
| 高文 | 最小的弟弟要来、阿格规文去接、「我娘总算肯放人」 | 自己家的事 | 对；他不知道莫德雷德的身世，只叫他「老小」 |
| 高文 | 不提美手 | 他不知道美手是加雷斯（facts gareth_identity） | 对 |
| 王后 | 梅林在她婚宴上没喝酒 | 她自己看见的。她不知道梅林警告过亚瑟，台词里也没提 | 对 |
| 王后 | 1402：剑鞘被偷 | 那一夜走廊里的动静 | 对 |
| 王后 | 兰斯洛特回来、座次重排 | 她管宴席座次（人物卡的独立生活） | 对；没有当众把他的名字和「爱」放一起 |
| 王后 | 「别盯着它看」（你的杯子） | 你能看见将来，宫里人人知道 | 对 |
| 兰斯洛特 | 王让他跟着你 | 亚瑟交代的 | 对 |
| 兰斯洛特 | D4a：「什么门？」「我知道了」 | 你刚告诉他；他知道自己和王后的事（第 4 章起），所以不用再问 | 对 |
| 莫德雷德 | 「母亲让我带句话」 | 从奥克尼来，母亲是摩高斯；他第 4 章起知道自己是谁的儿子，这句话是在试亚瑟 | 对；没有说「我是你的儿子」 |
| 莫德雷德 | 奥克尼的渔夫拿你吓唬小孩 | 你当了十七年宫里的预言者，名声传过去了 | 对 |
| 莫德雷德 | 「你看见的是现在的我，还是以后的我」 | 他第 4 章起怀疑你看得见将来，防着你 | 对；他不知道梅林说过他会毁掉亚瑟，台词里没碰 |
| 阿格规文 | 离王最近的椅子没有奥克尼的；王后总是头一个站起来 | 自己看见的；第 4 章起怀疑 | 对；只说看见的，不下结论，没用 facts 关键词 |
| 摩根 | 父亲死的那一夜尤瑟顶着他的脸进了廷塔杰尔 | 她一直知道 | 对 |
| 摩根 | 湖里那几位夫人 | 她会法术，知道湖的规矩（世界规则 7） | 对；她不知道你的天分，台词里没提 |
| 妮妙 | 「他说你会来」 | D3a：梅林告诉了你地方，也跟她说过你会来（bible 回读原话） | 对 |
| 妮妙 | 「他教我的，我都学会了」「进了湖的东西，就归湖里」 | 她自己做的；湖的规矩 | 对；没提你看见过她封印梅林 |
| 护卫队长、侍从、传令官 | 夫人的吩咐；王找你；王令 | 职责之内 | 对 |
| 学徒（选项） | D3c「他跟我说过，要出一趟远门」 | Ch3_LakeShore 梅林对你说的 | 对 |
| 学徒（选项） | D3a「他说他早就看见了，还是要去」 | Ch3_Night 阁楼里梅林说的 | 对 |
| 学徒（选项） | 「你本来想跟他说的，另有一句」 | 第 3 章营帐里你在场 | 对 |
| 学徒（选项） | 「你把他怎么了？」 | 你看见过水面上那一幕；就算不算那一幕，也知道梅林是跟她走的 | 对 |
| 旁白 | 「和庄园那间阁楼一模一样」「梅林自己从来不系这根带子」 | 你从小跟着梅林 | 对 |

另外核对过的因果：
- 摩根为什么这时候来：Ch3_Night 梅林对亚瑟说「我在一天，摩根不敢碰它」；凯的台词「梅林在的那些年，她一次都没进过这扇门」接上。
- 为什么剑鞘拿不回来：摩根和妮妙都说了湖的规矩；亚瑟走进湖里，水清见底，什么都没有。
- 为什么亚瑟没拦住摩根：她说起父亲死的那一夜，亚瑟勒住马，剑垂着没往前走（他太相信、也太顾念身边的人）。
- 摩根怎么跑的：马洛礼第 4 卷她把自己和马变成石头；台词只给画面（马蹄印到一块像人骑在马上的灰石头跟前就没了），不点破。
- 兰斯洛特为什么跟着你：摩根恨梅林的人，湖边那一仗以后亚瑟不放心你一个人出城（补写）。
- 1404 亚瑟为什么只说「好好当差」：认他就得当众说出他母亲是自己的姐姐。
- D4b 亚瑟为什么只调走阿格规文、不动莫德雷德：没写出来，留给玩家看（他刚对莫德雷德说过「好好当差」）。
- 和别的章对过：Ch3（杖留在阁楼；梅林戴着兜帽走；D3b 高文天没亮出城；D3a 梅林把杖靠在墙角；D2b+D3a 的最后一课）、Ch5（圆桌有一把椅子空了很多年；王后转戒指；`$D4 == "D4b" and $D3 != "D3b"`）、Side（S2401_Rumor 的跳转；S1a 绿绸带边上压着金线）。

## 7. knowledge_check 的判断

`knowledge_check.py .` 在 Ch4.yarn 里只列出 1 条候选：

| 位置 | 说话人 | 事 | 判断 |
|---|---|---|---|
| Ch4.yarn:85（Ch4_Hall） | 高文 | merlin_place：「康沃尔海边……」 | **不算泄漏**。这句在 `<<if $D3 == "D3b">>` 里；bible facts 写高文 D3b 时第 4 章（几个月后）知道。脚本分不清分支 |

脚本只按关键词找。按关键词找不到、我逐句对过的：
- sight：凯、王后、莫德雷德都提到你看得见。第 4 章公开（facts 备注：你接替梅林，宫里人人知道）。
- mordred_parentage：亚瑟那句「他母亲是我姐姐」只对你说，你和亚瑟都在知情名单里，没有当众说，没碰关键词。
- affair：没有人当众说出来。阿格规文只说看见王后头一个站起来（第 4 章起怀疑）；画面文字 vision_D4 在 csv 里，只给学徒看。
- arthur_lineage：摩根说「伊格赖因的儿子」「你父亲顶着他的脸」，第 2 章起公开，摩根一直知道。
- gareth_identity：Ch4 里没人提美手是谁；凯那段在 Side.yarn。

## 8. 拿不准、要你定的地方

1. **剑鞘的「失去」挪到被偷那一夜。** 设计页的例子写「剑鞘沉进了湖里。亚瑟从此会流血」。可是剑鞘在追摩根那一仗之前就被割走了，失去要是放在湖边，那一仗亚瑟身上还挂着「剑鞘」状态，血掉不到 0，前后对不上。所以我把 `<<unlock u_scabbard_lost>>` 放进 Ch4_ScabbardGone，亚瑟说完「带着那一个，我挨了刀不流血」就弹；湖边留着他第一次见血的画面。提示框来历改成「摩根趁夜割走了剑鞘。亚瑟从此会流血。」（csv 里覆盖 `unlock_u_scabbard_lost_origin`）。想照设计页放回湖边，把那一行挪到 Ch4_LakeShore 的血珠后面，再让战斗在 morgan_chase 里关掉剑鞘。
2. **十七年。** bible 写「十几年」。定十七年，是为了莫德雷德到 1404 一定已经成年。
3. **兰斯洛特入队的理由是补写的**：亚瑟让他在卡美洛的日子跟着你出城，因为摩根的人还在外头。
4. **亚瑟那句「认了他，就得当着所有人说，他母亲是我姐姐」说得很直。** 只有你在场，没碰关键词。嫌太露可以换成选项二（什么也不说）那一路。
5. **2401 的关门提醒什么时候弹。** quests.json 写 `closes_before: 1405`，可 `<<progress_quest 1004 1405>>` 在 Ch4_Brothers 末尾。建议代码在玩家走到圆桌边你的位子（Ch4_Feast 触发）之前弹，这时 1405 才开始。第 3 章 S1 在 1305 前关门也是同一个问题。
6. **凯 1403/1404 跳进 Side.yarn 的 `S2401_Rumor`。** 支线作者在节点注释里要主线这么调。他改节点名的话，Ch4_Kay 这一处要跟着改。
7. **王后的名字**：派活消息里写的是「桂妮薇儿」，bible.json 和 Ch3、Ch5 都用「桂妮维亚」，我照 bible。
8. **npc_ 名字键和 ch3、ch5 的 csv 重复**（npc_gawain、npc_guinevere、npc_nimue、npc_lancelot、npc_mordred、npc_agravaine），值一样，合并时去重就行。
9. **overworld.json 的 camelot、lake 登记成第 3 章。** 第 4 章换章后它们会不会被关掉，取决于代码，见第 3 节。

## 9. 检查结果

- `check_style.py content/dialogue/Ch4.yarn frag/ch4_text.csv`：禁用 0 条，待判 0 条。
- `check_content.py .`：Ch4.yarn 0 个错误（197 条「没有 #line 行号」照要求忽略）；「未知指令」提醒是本作新加的六个指令。全项目其余报错都是别的文件的 #line。
- `knowledge_check.py .`：Ch4 候选 1 条，判过，见第 7 节。
- 另跑了 `tools/check_project_data.py .`（没要求，做参考）：Ch4 相关 4 条，都是 `after_D3a` `after_D3b` `after_D3c` `after_D3c_hood` 还不在 game_text.csv 里，合并 csv 后消失。
- 每个对话框不超过 40 字（dialogue.json 的 max_chars_per_box），脚本量过，0 条超出。
- 节点名和别的 .yarn 没有重名（Ch1、Ch2、Ch3、Ch5、Side 都查过）。
