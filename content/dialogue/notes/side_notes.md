# 四条支线交回说明（Side.yarn）

四条支线写完了：17 个节点、224 行（2301 五个节点 70 行，2401 四个节点 61 行，2501 四个节点 46 行，2502 四个节点 47 行）。三个检查都过了：文风禁用 0、待判 0；check_content 和 Side.yarn 有关的错误 0（缺 #line 的不算）；knowledge_check 列出 3 条候选，都判为不算泄漏（见第 9 节）。不需要新变量。

文风照「肘击指令」（作者将生）写，逻辑照 voice-prompt.md 核心二；每行不超过 40 字（dialogue.md 的对话框上限），看水面每句不超过 30 字。

文件：
- `content/dialogue/Side.yarn`
- `scratchpad/frag/side_text.csv`（61 个键，新键和要改的旧键见第 4 节）
- 本文件

---

## 1. 每个节点由谁、在哪触发

线索节点（Rumor）都以 `<<start_quest>>` 结尾，被调用后这段对话就结束（解释器没有 detour，用 `<<jump>>` 调）。另外五个作者已经在各自的文件里给这几条支线留了口子，下表最后一列写怎么接。

| 节点 | 地方 | 触发 | 条件 | 和主线怎么接 |
|---|---|---|---|---|
| S2301_Rumor | 卡美洛大厅（圣诞宴） | 和高文说话 | `quest_part(1003) == 1304 and visited("Ch3_Wedding") and quest_state(2301) == "none"` | Ch3_Kay 1304 那一支已经给了线索（高文打赌有人叫阵他头一个站起来，「你去劝劝他」）；Ch3_Gawain 注释写了「合并时先跳进支线入口」：在它 1304 那一支开头加 `<<if quest_state(2301) == "none">><<jump S2301_Rumor>><<endif>>`。节点一开头就切到圣诞宴，绿衣骑士进门 |
| S2301_Road | 往北的路 | 走进这片地方，或和路边的樵夫说话 | `quest_part(2301) == 1` | 打 wild_men；樵夫指路去城堡（口头指路，没有标记） |
| S2301_Castle | 林中城堡门口 | 和城主说话 | `quest_part(2301) == 2` | 看水面 S1 在这里 |
| S2301_Chapel | 绿色礼拜堂 | 走进这片地方（或和绿衣骑士说话） | `quest_part(2301) == 3` | |
| S2301_Return | 卡美洛马厩 | 和高文说话 | `quest_part(2301) == 4` | Ch3_Gawain 在这个条件下 `<<jump S2301_Return>>`，或在马厩另放一个高文。关键选择 S1 |
| S2401_Rumor | 卡美洛（凯在厨房门口） | 和凯说话（1403、1404） | `quest_state(2401) == "none"` | Ch4_Kay 1403/1404 第一次说话跳过来。凯的线索（劈了快一年柴）、外号美手、D1a / D1c 回读都在这个节点里（2026-11-09 按 review_ch4 🔴1、🟠2 补） |
| S2401_Kitchen | 卡美洛厨房后院 | 和劈柴的美手说话 | `quest_part(2401) == 1 and not visited("S2401_Kitchen")` | 只演一次。凯当面挖苦一回；那一年在主线 1403 之前已经过去，节点里不再跳一年（review_ch4 🔴2） |
| S2401_RedLaunds | 去红地的路尽头（树下有号角） | 和美手说话 | `quest_part(1004) == 1405 and quest_part(2401) == 2` | 打 red_knight。姑娘求救在 S2401_Plea（Ch4_Brothers 末尾跳过去） |
| S2401_Knighted | 圆桌大厅 | 和兰斯洛特说话 | `quest_part(1004) == 1405 and quest_part(2401) == 3` | 宴席开席前。看水面 S2、关键选择 S2、加雷斯入队；Ch4_Arthur 这时说宴席压着等你们回来 |
| S2501_Rumor | 卡美洛回廊 | 和王后的侍女说话 | `visited("Ch5_Return") and quest_state(2501) == "none"` | Ch5_Return 注释写了「演完才出现给任务人（王后的侍女、贝狄威尔）」；侍女的节点挂这里 |
| S2501_Hall | 宴会厅 | 和凯说话 | `quest_part(2501) == 1` | 宴会厅里另放一个凯（Ch5_Kay 这时在厨房） |
| S2501_Bowl | 你在塔楼顶上的屋子（Ch4 说阁楼在东边塔楼顶上） | 和桌上的木碗互动 | `quest_part(2501) == 2` | 看水面 S3、关键选择 S3；结尾 `<<jump S2501_Feast>>` |
| S2501_Feast | 宴会厅 | 不单独触发 | — | 由 S2501_Bowl 跳过来，演三种后果 |
| S2502_Rumor | 城门边的伤员屋 | 和贝狄威尔说话 | `visited("Ch5_Return") and quest_state(2502) == "none"` | Ch5_Bedivere 1502 那一支先说「下个月有比武……兰斯洛特爵士倒说，他不去」，在这句后面接 `<<if quest_state(2502) == "none">><<jump S2502_Rumor>><<endif>>`。我的节点开头先跳到「比武开场那天傍晚」，两句接得上 |
| S2502_Tournament | 比武场 | 走进这片地方 | `quest_part(2502) == 1` | 打 tournament |
| S2502_Astolat | 阿斯托拉特城外河边的隐修士小屋 | 和床边的伊莲恩说话 | `quest_part(2502) == 2` | 看水面 S4、关键选择 S4 |
| S2502_Boat | 卡美洛城下河边 | 和小船互动 | `$S4 == "S4c" and quest_part(1005) == 1502 and not visited("S2502_Boat")` | Ch5 的 Prop_river 第一支写了同一条船。二选一，建议在 Prop_river 第一支里 `<<jump S2502_Boat>>`，把洗衣妇那句挪进我的节点；Ch5_GuinevereDoor 的条件改成 `visited("S2502_Boat")` |

## 2. 变量
用到的全在 Variables.yarn 里：`$S1`–`$S4`，以及 `gawain_confessed`、`gawain_early_letter`（S1a），`gawain_secret`（S1b），`gareth_refused_order`（S2a），`kay_protected_gareth`（S2b），`gawain_owes_you`、`apple_prevented`（S3a），`guinevere_trusts_you`、`apple_prevented`（S3b），`apple_happened`（S3c），`elaine_lives`、`rumor_up`（S4a），`elaine_convent`（S4b），`elaine_died`（S4c）。标记照 bible.json 的 flags 一一设。

不需要新变量。函数用了 `quest_part`、`quest_state`（写在第 1 节的条件里），对白里没有用 `visited`。

## 3. 要改的数据（不是我的文件，给你合并）

### quests.json
2301 加第 4 步（回卡美洛做决定）；其余三条只改文本键里的字（第 4 节），步骤结构不变。这段在一份拷贝里合进去跑过 `tools/check_project_data.py`，和 Side.yarn 有关的 0 错误。
```json
"2301": { "parts": [
  {"id": 1, "text": "quest_2301_p1", "area": "north_road", "battle": "wild_men"},
  {"id": 2, "text": "quest_2301_p2", "area": "castle"},
  {"id": 3, "text": "quest_2301_p3", "area": "green_chapel"},
  {"id": 4, "text": "quest_2301_p4", "area": "camelot"} ] },
"2401": { "parts": [
  {"id": 1, "text": "quest_2401_p1", "area": "camelot"},
  {"id": 2, "text": "quest_2401_p2", "area": "red_launds", "battle": "red_knight"},
  {"id": 3, "text": "quest_2401_p3", "area": "camelot"} ] },
"2501": { "parts": [
  {"id": 1, "text": "quest_2501_p1", "area": "camelot"},
  {"id": 2, "text": "quest_2501_p2", "area": "camelot"} ] },
"2502": { "parts": [
  {"id": 1, "text": "quest_2502_p1", "area": "tournament", "battle": "tournament"},
  {"id": 2, "text": "quest_2502_p2", "area": "astolat"} ] }
```
步骤里带 battle 的，打赢后 `Quests.on_battle_won` 会自动进下一步；节点里的 `<<progress_quest>>` 写在仗后面，重复调用不会出错。

### prophecy.json
visions 里 S1–S4 四条各加一个 `"text": "vision_S1"`（S2、S3、S4 同理）。正文在 side_text.csv。

### npcs.json
cell 第 13 步做地图时补。speakers 要给这些名字牌配头像：绿衣骑士、城主（红胡子大个子，和绿衣骑士用两套外观，礼拜堂那一下才认得出是一个人）、樵夫、美手（厨房衣服）、加雷斯（受封后）、红骑士、侍女、皮内尔、马多尔、伊莲恩、隐修士（只冒闲话）。

| id | 地方 | node | condition | barks |
|---|---|---|---|---|
| woodcutter | north_road | S2301_Road | `quest_part(2301) == 1` | bark_woodcutter_1 |
| castle_lord | castle | S2301_Castle | `quest_part(2301) == 2` | |
| green_knight | green_chapel | S2301_Chapel | `quest_part(2301) == 3` | |
| gawain_stable | camelot | S2301_Return | `quest_part(2301) == 4` | |
| beaumains | camelot（厨房后院） | S2401_Kitchen | `quest_part(2401) == 1 and not visited("S2401_Kitchen")` | bark_beaumains_1 |
| beaumains_red | red_launds | S2401_RedLaunds | `quest_part(2401) == 2` | |
| lancelot_knighting | camelot（圆桌大厅） | S2401_Knighted | `quest_part(2401) == 3` | |
| queen_maid | camelot（回廊） | S2501_Rumor | `visited("Ch5_Return") and quest_state(2501) == "none"`；开任务以后留着冒闲话，到 1503 撤 | bark_queen_maid_1 |
| kay_banquet | camelot（宴会厅） | S2501_Hall | `quest_part(2501) == 1` | |
| bowl_room | camelot（你的屋子，物件） | S2501_Bowl | `quest_part(2501) == 2` | |
| elaine | astolat | S2502_Astolat | `quest_part(2502) == 2` | |
| hermit | astolat | "" | `quest_part(2502) == 2` | bark_hermit_1 |
| boat | camelot_outside | S2502_Boat | 见第 1 节 | |

两处要你在主线 NPC 上加条件：
- **Ch5_Lancelot 不能在 2502 进行中站在马厩。** 第 1 步他戴着红袖子在比武场（宫里以为他在屋里躺着），第 2 步他在阿斯托拉特养伤。条件加 `quest_state(2502) != "active"`。
- **美手只在 `quest_part(2401) == 1` 时在后院。** 第 2 步他已经出了北门。

### combat.json
三场遭遇都还是 `_待写`。对白写定了这些事，数值留给 balancing：

| 遭遇 | 敌人 | 对白里写定的 | 上场 |
|---|---|---|---|
| wild_men（kind quest） | 野人 ×3 左右 | 樵夫说「两个两个地扑，专挑一个人打」：同一回合两只打同一个目标（target 都写 `lowest_hp`，或同一个 id） | fixed gawain，max 1。剧情上只有你和高文两个人往北走 |
| red_knight（kind quest） | 红骑士（首领）+ 红骑士的手下 ×2（端长矛） | 红骑士说「太阳还没到头顶，我越打越有劲」：前 3 回合每回合给自己加力量（设计表写每回合 +2），对应 CONTENT_SCHEDULE 的「越打越强」 | fixed gawain、gareth。**加雷斯这时还没入队**，见第 10 节第 1 条 |
| tournament（kind quest） | 输了马的骑士 ×3 | 「被他挑下马的三个骑士换了马，追了出去」：场上最多两个，倒一个下回合补上一个（CONTENT_SCHEDULE「打倒一个，下回合补上一个」） | fixed bedivere；兰斯洛特不能上场（他就是被追的那个） |

新敌人：`wild_man`、`red_knight`、`red_spearman`、`tourney_knight`（名字键在 csv 里）。红骑士加力量要 `buff` 支持 `"who": "self"`；比武骑士「场上最多两个、倒一个补一个」现在的遭遇格式没有，可以用 summon 凑，也可以在遭遇上加一个 `field_max`。

## 4. 文本键（side_text.csv）
- **改旧键**：`quest_2301_desc` `quest_2301_p1`–`p3` `quest_2301_end_S1_skip`；`quest_2401_desc` `quest_2401_p1`–`p3`；`quest_2501_desc` `quest_2501_p1` `p2`；`quest_2502_desc` `quest_2502_p1` `p2`。desc 改成「谁说的 + 原话」，照 quests.md 的「任务记录里抄下他这句话」；步骤写全去哪、找谁。
- **新键**：`quest_2301_p4`；`vision_S1`–`S4`；`book_told_S1a` `S1b` `S1_skip` `S2a`–`S2c` `S3a`–`S3c` `S4a`–`S4c`（screens.gd 读 `book_told_` + 选项 id）；`after_S1a` `S1b` `S3a`–`S3c` `S4a`–`S4c`；`npc_green_knight` `npc_castle_lord` `npc_woodcutter` `npc_beaumains` `npc_red_knight` `npc_queen_maid` `npc_pinel` `npc_mador` `npc_elaine` `npc_hermit`；四句 bark；`enc_wild_men` `enc_red_knight` `enc_tournament`；`enemy_wild_man` `enemy_red_knight` `enemy_red_spearman` `enemy_tourney_knight`。
- **没放的**：`after_S2a`–`S2c` 用 ch5_text.csv 里的版本（第 5 章法场应验，`<<book_after S2 …>>` 由第 5 章作者调），我这边删了；`npc_gawain` `npc_lancelot` `npc_guinevere` `npc_bedivere` `npc_gareth` 别的片段里已经有，值相同，没重复放。

## 5. 没做完时怎么算（代码处理）
在关门节点之前统一结算：任务没完成（`quest_state != "done"`，包括没开始和做到一半），把 `$Sx` 设成 skip_as，设上那个选项的标记，`complete_quest` 记这个结局。

| 支线 | 关门 | skip_as | 要设的标记 | 说明 |
|---|---|---|---|---|
| 2301 | 1305 之前 | `S1_skip` | 无 | 两个选项都不算：V1 不出现，第 4 章 Ch4_Gawain 的 S1 回读都不演。看水面在城堡、决定在卡美洛，中间关门会留下「看过没决定」的一页，所以加了 `book_told_S1_skip` |
| 2401 | 1405 之前 | `S2c` | 无 | 加雷斯不入队，第 5 章死在法场。看水面和决定在同一个节点，不会留下没决定的页 |
| 2501 | 1503 之前 | `S3c` | `apple_happened` | 宴会那一幕没演，帕特里斯的死由 Ch5_Supper 里阿格规文（或莫德雷德）那句回读带出来。Ch5 说两条支线的关门提醒放在跳进 Ch5_Supper 之前，结算要在 Ch5_Supper 开演之前做完，那句回读才读得到 |
| 2502 | 1503 之前 | `S4c` | `elaine_died` | 1503 以后结算，Prop_river 走第二支（空船，「早没气了，抬上去埋了」），不演 S2502_Boat |

## 6. 每条支线的选择怎么写的
- **S1**（S2301_Return，回卡美洛那晚的马厩）：高文把绿腰带摊在草料上，问明天宴上要不要说。S1a：第二天他当众说了，亚瑟换上一条绿布，他把腰带系在腰上打了个死结（和 Ch5_Oath 的「打了个死结」对上）。S1b：腰带塞进箱子最底下，压上两件冬衣（和 Ch5_Oath V1 的「压在他箱底」对上）。
- **S2**（S2401_Knighted，受封当晚的回廊）：加雷斯问以后会怎样，你看碗。S2a：他笑到一半看见你没笑，「行，我记着」。S2b：你转身去找凯，凯在大厅里把外号收回去，「叫你加雷斯爵士吧」（bible 第 4 章回读原句）。S2c：你把水泼到窗外。
- **S3**（S2501_Bowl，宴会前一天夜里）：画面里看不见那只手是谁的。S3a：高文要当场抓人，宴上他捏起油亮的苹果逼皮内尔咬一口。S3b：王后把整盘换成梨，侍女查出只有皮内尔进过那间屋，第二天王后派他去南边送信。S3c：帕特里斯吃了，马多尔告王后，十五天后兰斯洛特替她打赢。
- **S4**（S2502_Astolat，河边的小屋）：S4a：伊莲恩问那是谁，又说算了别说，天亮骑马回家。S4b：兰斯洛特当天下午把话说清，盾留给她父亲，红袖子托你送回去（「我宁可早一点让她恨我」Ch5_Lancelot 已经写了，这里没再说一遍）。S4c：你把水倒回河里，伊莲恩端汤出来问你喝不喝；之后河边的船（S2502_Boat）。

## 7. 和主线已经写的回读对过
Ch3 高文护腕内侧缝着弟弟们的名字 → 美手盯着那只护腕、受封时高文翻护腕给他看、S3 画面里那只护腕。Ch3_Kay 的「圣诞宴」线索 → S2301_Rumor 里高文抢在亚瑟前面接斧头。Ch4_Kay「后院劈柴」→ 美手在后院劈柴。Ch4 莫德雷德被高文叫作「我们家老小」→ 兰斯洛特只说「奥克尼的加雷斯爵士」，不说他是小儿子。Ch5_Return 兰斯洛特倒下躺了二十多天 → 贝狄威尔说「他说身子没缓过来」。Ch5_Gawain S3a「皮内尔关在塔底下了」、法场前侍女送来印章戒指（S3b）、Ch5_Supper 的 S3c / S4a 回读、法场上「没有盔甲，没有剑」（S2 画面）都和我这边的后果一致。

## 8. 逻辑自查：每个说话的人知道什么、什么时候、从谁那知道

### 2301（第 3 章）
| 人 | 说的事 | 凭什么知道 |
|---|---|---|
| 绿衣骑士（就是城主） | 规矩、礼拜堂、高文的名字 | 规矩是他定的；高文喊了一声「我高文来」才砍；腰带是他妻子照他的安排给的，第三天傍晚高文当面说「什么也没得着」 |
| 城主 | 礼拜堂不到两里、互换所得 | 他自己就是礼拜堂那个人。邀你去打猎，所以你不在高文屋里，看不见夫人送腰带 |
| 樵夫 | 野人两个两个地扑、林子里有城堡、城主天天打猎 | 住在这片林子；没听过礼拜堂（土包是空的，外人认不出） |
| 高文 | 一年后要去北边 | 绿衣骑士当众说「往北走」；他不知道礼拜堂在哪。请你同去的理由是「梅林带出来的，认得草，认得星星」，第 3 章他还不知道你能看见将来。礼拜堂之后，他从你嘴里知道你在碗里看见了（bible：S1 时知道你看见过） |
| 你 | 腰带、门外那一声 | 第一晚看水面看见卧房、绿腰带、门外喊「高文」；第三天傍晚你就站在喊人的城主身后，认出这一声；腰带是什么，礼拜堂里听绿衣骑士说了才知道 |

### 2401（第 4 章）
| 人 | 说的事 | 凭什么知道 |
|---|---|---|
| 凯 | 美手讨了一年饭、不说名字；出北门去红地；红地骑士吊人 | 他是总管，管厨房；姑娘当着大厅求救时说了红骑士吊人，他在场。「你不是能看见吗」：第 4 章起宫里人人知道 |
| 美手 / 加雷斯 | 一年后自己说名字；盯护腕 | 自己的身世只有他知道；护腕上缝着他自己的名字。受封前名字牌一律写「美手」，不漏真名 |
| 高文 | 给银币、「你这一手剑法跟谁学的」 | 不知道是弟弟（马洛礼：高文待他好，但不知道是谁）；红地看他的剑路起疑，受封时才知道 |
| 红骑士 | 越打越有劲 | 他自己的本事（马洛礼：到正午越来越强） |
| 兰斯洛特 | 「奥克尼的加雷斯爵士」 | 受封时加雷斯凑到他耳边说的（bible facts：兰斯洛特 S2 中知道） |
| 加雷斯 | 「他们说你能看见以后的事」 | 第 4 章公开 |
| 你 | 画面里的柴垛、木桩、兰斯洛特的剑 | 看水面；不知道那是王后的法场，只拿它和刚才受封那一剑比 |

### 2501（第 5 章）
| 人 | 说的事 | 凭什么知道 |
|---|---|---|
| 侍女 | 后天接风、请你去看一眼 | 王后差她来的。王后请你看，是因为第 4 章起宫里遇事都来问你，她又怕席上出事算到她头上（第 5 章她已经觉得阿格规文在盯她） |
| 凯 | 二十四个座、银盘留给高文装苹果 | 总管排座位；高文进城门就问厨房要苹果（Ch5_Kay 的采买单对得上） |
| 你 | 苹果、护腕、「那只手明天才会伸出来」 | 看水面；银盘还空着，所以苹果还没摆上去。看不见手是谁的，说不出下毒的人 |
| 高文（S3a） | 「冲我来的」 | 你告诉他的；宴上看仆人的眼神和苹果皮上的油光抓到皮内尔 |
| 桂妮维亚（S3b） | 「别让第三个人知道」 | 你告诉她的；她怕被说成下毒的人（bible 原话） |
| 侍女（S3b） | 只有皮内尔进过那间屋 | 王后让她暗中去厨房问的 |
| 皮内尔 | 「你杀了我表兄」 | 他自己的动机（马洛礼：为表兄拉莫拉克报仇；没提名字） |
| 马多尔 | 「王后的宴席，王后的苹果」 | 亲眼看见表弟吃了王后席上的苹果倒下 |

### 2502（第 5 章）
| 人 | 说的事 | 凭什么知道 |
|---|---|---|
| 贝狄威尔 | 红袖子骑士挑翻七个、一枪连两下、兰斯洛特说身子没缓过来 | 头一天他在比武场看着；兰斯洛特不去比武是宫里都听说的（Ch5_Bedivere 已经说过「他不去」） |
| 兰斯洛特 | 河边的隐修士 | 比武前他住在阿斯托拉特（马洛礼：借了城主儿子的白盾，戴了伊莲恩的袖子），认得那一带 |
| 伊莲恩 | 袖子是她给的 | 她自己给的。这时兰斯洛特还没告诉她心里另有人（马洛礼：伤好要走时才说） |
| 你 | 船上的姑娘是谁 | 画面里她胸口叠着红袖子，你刚在屋里桌上见过那只袖子。你知道兰斯洛特心里的人是谁（第 4 章酒杯），一句也没说出来 |

## 9. knowledge_check 的判断
跑 `knowledge_check.py .`，Side.yarn 里 3 条候选，都不算：
1. `Side.yarn` S2401_Knighted，加雷斯「他们说你能看见以后的事」（sight）：第 4 章你接替梅林，宫里人人知道（bible 认知边界总表：从第 4 章起公开）。不算。
2. S2401_Knighted，兰斯洛特「起来，奥克尼的加雷斯爵士」（gareth_identity）：加雷斯上一句刚凑到他耳边说了名字，facts 写兰斯洛特 S2 中知道。脚本只认节点名 `2401`，我的节点叫 S2401_*，对不上。不算。
3. S2401_Knighted，凯「叫你加雷斯爵士吧」（gareth_identity）：兰斯洛特已经当着大厅叫出名字，之后公开（public_after_node 2401）。不算。

改过一处：原来兰斯洛特说「洛特王的儿子」，命中 mordred_parentage 的关键词「王的儿子」，又和第 4 章莫德雷德被叫作「我们家老小」打架，改成「奥克尼的加雷斯爵士」，这条候选没了。

另外按 `--all` 看过：绿衣骑士说「绿腰带」在知情名单里。台词和旁白里没有出现苹果有毒、下毒、伊莲恩爱、兰斯洛特和王后、一条蛇、死在法场、剑鞘、康沃尔这些词（只在 `//` 注释里出现过「毒苹果」「下毒」，脚本不扫注释）。

## 10. 需要你决定的地方
1. **加雷斯在红骑士那一仗怎么上场。** 对白里他是主角（马洛礼里红骑士是他打的），可受封前他还不在队里，`_party_for` 只从在队的人里挑 fixed。两个办法：A 代码给遭遇加 `party.guests`（推荐，圆桌上不会提前多一把椅子）；B 在 S2401_RedLaunds 的 `<<fight_npcs red_knight>>` 前面加 `<<companion gareth party>>`，代价是受封前同伴面板上就有他。我现在写的是 A，`<<companion gareth party>>` 只在受封以后。
2. **S2301_Rumor 是整场圣诞宴（14 行），不止一句线索。** 线索那句已经在 Ch3_Kay（「你去劝劝他」）。绿衣骑士进门、砍头、头开口这一幕只在支线里演，不接支线的玩家看不到。要是你想让所有人都看到，就把这个节点挪进主线 1304 之后，任务从它的最后一行开。
3. **S2502_Boat 和 Ch5 的 Prop_river 写了同一条船**，二选一（建议见第 1 节）。
4. **2301 中间过了一年。** 做支线的玩家在 1305 之前过了一年，不做的没过。第 3 章梅林那一幕不提日子就不矛盾；Ch3 作者要是写了「第二天」之类，要对一下。
5. **原诗里绿衣骑士背后是摩根**（她把城主变成绿衣骑士，想吓王后）。bible 写摩根「第 3 章起学徒只听人说起过她」，这里正好是第一次听说的机会，但怕和第 3、4 章主线怎么引出摩根撞车，没写。要的话在 S2301_Chapel 加一句。
6. **wild_men 只带高文一个同伴**，比别的仗少一个人，难度要 balancing 按两个人调；不想要这个限制就把 max 去掉，台词不受影响。

## 11. 检查结果
- `check_style.py content/dialogue/Side.yarn side_text.csv`：禁用 0 条，待判 0 条。
- `check_content.py .`：Side.yarn 除缺 #line 以外 0 错误；提醒都是本作新加的指令（vision、book_after、autosave、companion）。
- `knowledge_check.py .`：Side.yarn 3 条候选，判断见第 9 节。
- 在项目的一份拷贝里（scratchpad/sidecheck）合进第 3 节的 quests.json、prophecy.json 改动和 side_text.csv，跑 `tools/check_project_data.py`：Side.yarn 0 错误（剩下的 7 个错误都在 Ch6.yarn）。
- 用游戏自己的 YarnProgram（Godot 4.3 无头）解析 Side.yarn：17 个节点全部解析出来，台词和选项数和上面的行数一致。
- 每行不超过 40 字，看水面每句不超过 30 字（脚本数过）。
