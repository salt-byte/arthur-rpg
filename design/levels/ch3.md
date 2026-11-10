# 第 3 章 · 湖中剑与圆桌 · 关卡页（草稿）

结论：第 3 章主线五片地方、六个关卡，支线三片地方、一个关卡；难度 3，峰值放在本章第一场仗（泉边佩利诺，只能撑），之后四群小仗都在亚瑟拿到王者之剑以后、卡美洛的南北两条路上；新机制依次教撑过几回合、静水（D2b）、圆桌面板、出战选择、口头指路的支线。

## 1. 区域清单

| id | 名字 | 大小 | 连着 | 剧情节点 | 有什么 |
|---|---|---|---|---|---|
| camp | 亚瑟的营帐 | 24×16 | 东 (23, 8) → fountain（1302 起开） | 1301 | 营帐、马桩、粮车、随军神父的木祭台 |
| fountain | 林中泉边 | 24×16 | 西 (0, 8) → camp；东南 (23, 12) → lake（1303 起开） | 1302 | 泉、泉边旧帐篷、空地边的老橡树；空地只有一个口 |
| lake | 湖 | 32×18 | 西北 (0, 3) → fountain；南 (16, 17) → camelot 北门；北 (24, 0) → north_road（支线开了才通） | 1303、1305 | 湖面、岸边的路、湖中仙女站的那一格、岸边石龛；两群小仗 |
| camelot | 卡美洛 | 32×22 | 北门 (16, 0) → lake；正门 (16, 21) → camelot_outside | 1304，1305 当晚（过场） | 圆桌大厅、礼拜堂、回廊、马厩、院子和井、厨房、军需官 |
| camelot_outside | 卡美洛城外 | 32×20 | 北 (16, 0) → camelot 正门 | 婚礼之后可去，主线不经过 | 城南的路口、比武场边的空地、林子；两群小仗 |
| north_road | 往北的路 | 32×14 | 南 (16, 13) → lake；北 (16, 0) → castle | 支线 2301 第 1 步 | 一条往北的路、樵夫、野人出没的林子 |
| castle | 林中城堡 | 20×14 | 南 (10, 13) → north_road；北 (10, 0) → green_chapel（第 3 步起开） | 支线 2301 第 2 步 | 城门、大厅、客房（看水面 S1 的脸盆） |
| green_chapel | 绿色礼拜堂 | 18×12 | 南 (9, 11) → castle | 支线 2301 第 3 步 | 长满草的土包、溪水 |

卡美洛的格局（第 3–5 章共用，白盒坐标）：北门 (16, 0)，正门 (16, 21)。圆桌大厅在北边正中（x 9–23，y 2–8），王座 (16, 2)，圆桌 (14–18, 5–6)，大厅门 (16, 9)。礼拜堂在西翼（x 2–8，y 2–8），门 (5, 9)，圣龛在 (4, 4)，圣水盆 (6, 3)。回廊在东翼（x 24–30，y 2–8），王的卧房、王后的房间外是回廊尽头 (28, 3)–(28, 7)。东塔楼的阁楼（x 26–30，y 10–13），门 (28, 14)。宴会厅在西南（x 2–8，y 10–14）。厨房和账房（x 2–8，y 15–19），厨房后院 (2–5, 20)。院子正中（x 10–22，y 12–19），井在 (16, 15)，军需官在 (20, 14)，练剑场 (10–14, 17–20)。马厩在东南（x 24–30，y 15–20）。伤员屋在正门东边 (18, 20)。

卡美洛城外的格局（第 3–5 章共用）：北边正中是卡美洛正门。南北一条路 x = 16 通到河滩 (16, 17)；东西一条路 y = 9；东段是山路，在 (27, 9) 拐向南，到 (27, 14) 再往东出比武场方向；河滩小路 y = 17 往西出阿斯托拉特方向。河在 y = 18–19。比武场边的空地在东北（x 20–26，y 2–5）。第 3 章只开北半边，河滩和东西两个出口第 5 章才用。

## 2. 关卡

### 3-1 亚瑟的营帐（1301，约 4 分钟）

目标情绪：听见不该听的话。打了胜仗的营地里，你站在帐篷角落。
主推机制：没有。本章第一关只走路、说话，把节奏放慢。

| 段 | 发生什么 | 对白节点 / 遭遇 |
|---|---|---|
| 铺垫 | 营地开场，洛特的王后来求过和；凯坐在粮车车辕上，士兵说北边还有两个王没递降书 | Ch3_Start；Ch3_Kay；bark_camp_1/2 |
| 展开 | 随军神父的木祭台在营地西边，本章第一座圣龛 | 圣龛 `camp_altar` |
| 升温 | 走进营帐 | Ch3_Tent（帐门 (12, 4)） |
| 高潮 | 梅林说出摩高斯和孩子；你在场 | Ch3_Tent |
| 结算 | 天亮侍从带伤回营，泉边的骑士伤了第三个人；东边的路开了 | `progress 1302` |

### 3-2 林中泉边（1302，约 6 分钟）

目标情绪：明知会输还要站上去。只能撑。
主推机制：撑过几回合。

| 段 | 发生什么 | 对白节点 / 遭遇 |
|---|---|---|
| 铺垫 | 林子里一条小路，路边一座石十字；远处看得见泉边那顶旧帐篷 | 圣龛 `fountain_cross` |
| 展开 | 空地口站着梅林（橡树边），佩利诺在泉边。空地只有一个口，绕不过去 | npcs `merlin_fountain`、`pellinore_fountain` |
| 升温 | 走进空地口，开打前各路线各一句（D2a「你说过剑会断」） | Ch3_Fountain（空地口三格） |
| 高潮 | 和佩利诺：撑过 3 回合；你躲在老橡树后放法术，他的招全打亚瑟 | `pellinore`（剧情战，撑过 3 回合，`end_if_down: arthur`） |
| 结算 | 剑断，梅林让佩利诺睡着，预言簿「后来」；佩利诺躺着打呼噜，亚瑟抱着断剑 | Ch3_Fountain 结尾；`book_after D2` |

### 3-3 湖·王者之剑（1303，约 5 分钟）

目标情绪：缓一口气。断剑换成更好的剑。
主推机制：看选择才有的能力（静水，只在 D2b 路线）。

| 段 | 发生什么 | 对白节点 / 遭遇 |
|---|---|---|
| 铺垫 | 沿湖北岸走，湖面平得照得见云；路上没有敌人（亚瑟拿着半截剑，ch3 交接说明第 5 节） | — |
| 展开 | 东岸路边岸边石龛，祈祷回满（打完佩利诺第一次回血的地方） | 圣龛 `lake_shrine` |
| 升温 | 湖中仙女站在离岸一格的水面上 | npcs `lady_lake`；Ch3_Lake（东岸三格） |
| 高潮 | 王者之剑和剑鞘；D2b 路线梅林教静水 | Ch3_Lake；`unlock u_excalibur`、`u_scabbard`、`u_still_water` |
| 结算 | 往南去卡美洛的路上，东边林子里转着一个骑士带一个侍从（能绕开）；D2b 的人马上能用一次静水 | `ch3_road_knight`；宝物 `lake_boat` |

### 3-4 卡美洛·婚礼与圆桌（1304，约 7 分钟）

目标情绪：热闹。人一下子多起来，圆桌抬进门。
主推机制：同伴面板变成圆桌。

| 段 | 发生什么 | 对白节点 / 遭遇 |
|---|---|---|
| 铺垫 | 从北门进城，梅林拉你说王后的事 | Ch3_Camelot（北门里三格） |
| 展开 | 婚礼：圆桌进门，名字浮上椅背，高文受封入队；面板换成圆桌 | Ch3_Wedding；`companion gawain party`、`unlock u_round_table` |
| 升温 | 自由走动：礼拜堂的圣龛、院子里的军需官、凯说圣诞宴高文跟人打赌 | 圣龛 `camelot_chapel`；铺子 `shop_camelot`；Ch3_Kay → S2301_Rumor |
| 高潮 | 圣诞宴上绿衣骑士进门（接了支线的人看得到） | S2301_Rumor |
| 结算 | 梅林在大厅靠窗：选「我明天就去」进 1305；选「等我忙完这阵子」留在 1304（顶替支线关门提醒） | Ch3_Merlin |

### 3-5 卡美洛城外（婚礼之后可去，约 4 分钟）

目标情绪：手痒。新来的高文想试试身手。
主推机制：出战选择（第一次 3 个同伴可选）。

| 段 | 发生什么 | 对白节点 / 遭遇 |
|---|---|---|
| 铺垫 | 出正门，路口一座石十字；城门边的侍从冒一句「比武场那边天天有人叫阵」 | 圣龛 `camelot_outside_cross`；路人 bark |
| 展开 | 西北林子里两个侍从，碰上弹出战选择：凯、亚瑟、高文挑两个 | `ch3_squires`（侍从 ×2） |
| 升温 | 东北比武场边的空地，一个挑战的骑士带一个野人；兵器架上挂着东西 | `ch3_knight_pair`；宝物 `outside_rack` |
| 高潮 | 带高文打，正午之力前 3 回合多砍 3 | — |
| 结算 | 回城。这片地方主线不经过，主线标记不会领你来；全打的人靠侍从那句闲话和门口的路找到它 | — |

### 3-6 湖边·梅林要出远门（1305，约 7 分钟）

目标情绪：看见了，说不出口。
主推机制：没有。D3 是本章的关键选择，前面只放一群小仗。

| 段 | 发生什么 | 对白节点 / 遭遇 |
|---|---|---|
| 铺垫 | 出北门回湖边，岸边石龛 | 圣龛 `lake_shrine` |
| 展开 | 湖北岸往北的岔路口，林边转着两个野人（支线前先见一次「专挑一个人打」） | `ch3_wild_pair` |
| 升温 | 东岸，梅林站在妮妙身后，妮妙蹲在水边按着石头；湖面发光 | npcs `merlin_lake`、`nimue_lake`；Ch3_LakeShore |
| 高潮 | 湖面上：海边巨石，石缝里一角灰兜帽；梅林说要出远门 | `<<vision D3>>` |
| 结算 | 剪到当晚卡美洛，梅林对亚瑟说活埋和剑鞘；D3，自动存档，第 3 章结束 | Ch3_Night；`chapter 4` |

### 支线 2301 · 高文与绿衣骑士（约 10 分钟）

目标情绪：跟着一个怕死又要面子的人走一趟。
主推机制：只靠口头指路的支线。

| 段 | 发生什么 | 对白节点 / 遭遇 |
|---|---|---|
| 铺垫 | 圣诞宴上高文砍下绿衣骑士的头（S2301_Rumor），任务记录抄下高文的话；湖北岸的出口通了，地图上没有标记 | S2301_Rumor |
| 展开 | 往北的路：路口一块界石；樵夫说野人「两个两个地扑，专挑一个人打」，林子里有座城堡 | S2301_Road（入口三格）；npcs `woodcutter` |
| 升温 | 路上三个野人扑出来，只有你和高文 | `wild_men`（任务战，高文固定，最多 1 个同伴） |
| 高潮 | 城堡：城主天天打猎，你在客房的脸盆里看见绿腰带和门外喊「高文」的人（看水面 S1）；礼拜堂里斧头只划了一道浅口 | S2301_Castle；S2301_Chapel |
| 结算 | 礼拜堂外的老十字传回卡美洛礼拜堂；马厩里高文把绿腰带摊在草料上，S1 | S2301_Return |

---

## 3. 引导

结论：佩利诺那一仗的规则（打不赢、只能撑、他看不见你）先用空地的形状交代；出战选择靠「婚礼之后才出现的两群」教；口头指路靠一条没有岔路的往北的路。

| 新东西 | 怎么用地形和摆位教 | 参照第 1 章森林的哪一处 |
|---|---|---|
| 撑过几回合 | 空地是个口袋，只有一个口，口前一格触发；石十字在口外 4 格。空地东边一棵老橡树，开打前你就站在树后。开打后意图牌上佩利诺的招全指亚瑟，学徒头上没有箭头 | 头狼群堵在窄路上，绕不过 |
| 静水（D2b） | 拿到静水的下一段路上马上放一群小仗（往卡美洛路上的骑士），骑士砍 7 打血最少的人，正好用静水 | 包袱在老橡树里，拿到马上能换上 |
| 圆桌面板 | 大厅正中摆着圆桌，椅背能看名字；面板和地图上的桌子长一个样 | — |
| 出战选择 | 城外两群、湖北岸一群，条件都是 `visited("Ch3_Wedding")`：一定在高文入队以后才出现，碰上就弹出战选择。「两个侍从」给正午之力准备：侍从血 12，带高文第 1 回合砍得倒一只 | — |
| 口头指路 | 湖北岸出口在支线开了才通（出口条件）。往北的路只有一条，樵夫站在半道上，城堡在路尽头；城堡北门第 3 步才开。走不丢，也没有标记 | — |

只打必须打的人走的路线：营地 → 泉边 → 湖北岸、东岸（road_knight 的 rect 在东岸路外隔三格） → 北门 → 卡美洛 → 北门 → 湖东岸。一只小仗都不碰。

---

## 4. 场景交互

| 东西 | 在哪 | 能做什么 |
|---|---|---|
| 营帐里的地图桌 | camp (12, 2) | 看一眼：北边两个王的地方插着小旗 |
| 老橡树 | fountain (16, 5) | 1302 你站在树后；1303 树皮上一道新砍的口子 |
| 断剑 | fountain (19, 9)，1303 | 剑尖那半截在泉边的石头缝里，看得见拿不起 |
| 湖面 | lake (13, 11) | 1305 发光，看水面 D3；其余时候「水面很平静。」 |
| 搁浅的小船 | lake (29, 15) | 宝物 |
| 圆桌的椅背 | camelot (14–18, 5–6) | 1304 婚礼后看名字 |
| 兵器架 | camelot_outside (27, 3) | 宝物 |
| 客房的脸盆 | castle (15, 3) | 看水面 S1 |
| 土包 | green_chapel (9, 4) | 外人认不出是礼拜堂，看一眼只是长满草的土包（樵夫没听过礼拜堂的理由） |

---

## 5. Boss 和精英

### 佩利诺（首领，剧情战，撑过 3 回合；只有亚瑟上场）

| 阶段 | 回合 | 新加什么 | 玩家要学会的解法 |
|---|---|---|---|
| 一：两下 | 1 | 砍 6 × 2 打亚瑟 | 护身给亚瑟、亚瑟举盾，两下各挡一截 |
| 二：蓄力 | 2 | 蓄力：下回合重劈 16 打亚瑟 | 本章最难的取舍：这回合就花 3 点法力打断；或者留着，等落下时亚瑟举盾 3 + 护身 4，还掉 9 |
| 三：重劈 | 3 | 重劈落下 | 撑到这一回合敌人出完手，剧情接管。60 血三回合打不死，砍他没用，法力全花在亚瑟身上 |

原作里的破敌之道：马洛礼第 1 卷，亚瑟的剑断在佩利诺手里，梅林让佩利诺睡着才救下他。打不赢，只能撑，照这个做成撑过 3 回合；亚瑟倒下也由剧情接管（`end_if_down`）。数照 NUMBERS.md：只打必须的 3 级，撑过 3 回合亚瑟剩 56%。

### 野人群（支线任务战；只有高文）

| 阶段 | 回合 | 新加什么 | 玩家要学会的解法 |
|---|---|---|---|
| 一：扑 | 1–3 | 三只野人的招全打血最少的人，同一回合扑同一个人 | 给被盯的那个护身；高文正午之力前 3 回合力量 +3，抢在这三回合砍倒两只 |
| 二：撕 | 4 起 | 撕 3 × 2，还是打血最少的；高文的正午之力没了 | 剩一只时别再分散，两个人打同一只 |

原作里的破敌之道：高文的力气到正午最大（马洛礼），所以解法是前三回合压上去。数照 NUMBERS.md：全打的等级 3 回合剩 62%，普通玩家 6 回合 31%，比同章主线难一档，支线是自己找的。

### 小仗

四群都是两只、2–3 回合。`ch3_knight_pair`（骑士带野人）最难：骑士隔回合挡 6，野人盯血最少的人，先打谁要看那回合骑士挡不挡。

---

## 6. 奖励放置

结论：两处宝物都放在王者之剑以后的路上，佩利诺的掉落是本章唯一的首领掉落；钱的去处是卡美洛的军需官。

| 奖励 | 位置 | 类型 | 和投放怎么对上 |
|---|---|---|---|
| 搁浅的小船 | lake (29, 15)，挨着 `ch3_road_knight` | 宝物：装备 1 件，至少精良；第 3 章底材（紫杉杖、羊皮袄、银十字），词缀加「·明眼」「·回春」 | items.md「每章宝物 1–2」 |
| 兵器架 | camelot_outside (27, 3)，挨着 `ch3_knight_pair` | 同上 | 同上 |
| 樵夫的棚子 | north_road (26, 5) | 支线宝物 1 件 | 有仗的支线 1 处 |
| 佩利诺 | 泉边 | 首领必掉，至少精良（NUMBERS.md 3.1：只打必须的第 4 章开打时穿的羊皮袄就是这一件） | 撑过的仗按上场敌人给经验（G4），佩利诺首领 27 |
| 野人 | 往北的路 | 27 经验 | NUMBERS.md 4.1 全打本章 176 |
| 四群小仗 | 见摆位 | 每只 6 银，装备 25% | NUMBERS.md 4.1 |
| 卡美洛的军需官 | camelot (20, 14) | 羊皮袄 60、血药 | NUMBERS.md 4.2：全打的人本章 66 银 |

---

## 7. 摆位提案

### 7.1 能绕开的敌人（spawns.json `zones`）

```json
"ch3_lake_road": {
  "area": "lake", "rect": [20, 10, 8, 4], "cell": [23, 11],
  "enemy": "ch3_road_knight", "label": "enc_ch3_road_knight",
  "condition": "$chapter == 3 and visited(\"Ch3_Lake\")",
  "_说明": "湖东岸路外的林子，往卡美洛路上的骑士。拿到王者之剑以后才出现（ch3 交接说明第 5 节：断剑那段不放小仗）"
},
"ch3_lake_north": {
  "area": "lake", "rect": [27, 1, 4, 6], "cell": [28, 4],
  "enemy": "ch3_wild_pair", "label": "enc_ch3_wild_pair",
  "condition": "$chapter == 3 and visited(\"Ch3_Wedding\")",
  "_说明": "湖北岸往北岔路口东边的林子，支线之前先见一次野人"
},
"ch3_outside_west": {
  "area": "camelot_outside", "rect": [3, 2, 9, 5], "cell": [7, 4],
  "enemy": "ch3_squires", "label": "enc_ch3_squires",
  "condition": "$chapter == 3 and visited(\"Ch3_Wedding\")",
  "_说明": "城南路口西北的林子，高文入队后第一场，碰上必弹出战选择"
},
"ch3_outside_lists": {
  "area": "camelot_outside", "rect": [20, 2, 7, 4], "cell": [23, 3],
  "enemy": "ch3_knight_pair", "label": "enc_ch3_knight_pair",
  "condition": "$chapter == 3 and visited(\"Ch3_Wedding\")",
  "_说明": "比武场边的空地，挑战的骑士带野人，兵器架在 (27,3)"
}
```

zones 的 `condition` 代码已经认（world.gd 第 173 行），spawns.json 的 `_说明` 里没写，合并时补一句。

### 7.2 任务战和看水面（maps.json `triggers`、overworld.json `water_spots`）

```json
{"area": "camp", "cell": [12, 4], "node": "Ch3_Tent", "cond": "quest_part(1003) == 1301"},
{"area": "fountain", "cell": [14, 7], "node": "Ch3_Fountain", "cond": "quest_part(1003) == 1302"},
{"area": "fountain", "cell": [14, 8], "node": "Ch3_Fountain", "cond": "quest_part(1003) == 1302"},
{"area": "fountain", "cell": [14, 9], "node": "Ch3_Fountain", "cond": "quest_part(1003) == 1302"},
{"area": "lake", "cell": [16, 9], "node": "Ch3_Lake", "cond": "quest_part(1003) == 1303 and not visited(\"Ch3_Lake\")"},
{"area": "lake", "cell": [16, 10], "node": "Ch3_LakeShore", "cond": "quest_part(1003) == 1305 and not visited(\"Ch3_LakeShore\")"},
{"area": "lake", "cell": [16, 11], "node": "Ch3_LakeShore", "cond": "quest_part(1003) == 1305 and not visited(\"Ch3_LakeShore\")"},
{"area": "camelot", "cell": [16, 1], "node": "Ch3_Camelot", "cond": "quest_part(1003) == 1304 and not visited(\"Ch3_Camelot\")"},
{"area": "north_road", "cell": [16, 12], "node": "S2301_Road", "cond": "quest_part(2301) == 1 and not visited(\"S2301_Road\")"},
{"area": "green_chapel", "cell": [9, 10], "node": "S2301_Chapel", "cond": "quest_part(2301) == 3"}
```

```json
{"area": "lake", "glows_at": "1305", "cell": [13, 11], "node": "Ch3_LakeShore"},
{"area": "castle", "glows_at": "2301:2", "cell": [15, 3], "node": "S2301_Castle", "_说明": "客房的脸盆，支线 2301 第 2 步发光。world.gd 第 127 行的 glows_at 只比主线步骤，支线这种写法要代码认（第 3–5 章四条支线的看水面都会碰到）"}
```

野人三只在往北的路上站着当布景（npcs，look 野人，node 为空），开打在 S2301_Road 里。

### 7.3 出口

```json
{"area": "camp", "cell": [23, 8], "to": "fountain", "at": [1, 8], "cond": "quest_part(1003) >= 1302"},
{"area": "fountain", "cell": [0, 8], "to": "camp", "at": [22, 8]},
{"area": "fountain", "cell": [23, 12], "to": "lake", "at": [1, 3], "cond": "quest_part(1003) >= 1303"},
{"area": "lake", "cell": [0, 3], "to": "fountain", "at": [22, 12]},
{"area": "lake", "cell": [16, 17], "to": "camelot", "at": [16, 1]},
{"area": "lake", "cell": [24, 0], "to": "north_road", "at": [16, 12], "cond": "quest_state(2301) == \"active\""},
{"area": "camelot", "cell": [16, 0], "to": "lake", "at": [16, 16]},
{"area": "camelot", "cell": [16, 21], "to": "camelot_outside", "at": [16, 1], "cond": "visited(\"Ch3_Wedding\")"},
{"area": "camelot_outside", "cell": [16, 0], "to": "camelot", "at": [16, 20]},
{"area": "north_road", "cell": [16, 13], "to": "lake", "at": [24, 1]},
{"area": "north_road", "cell": [16, 0], "to": "castle", "at": [10, 12]},
{"area": "castle", "cell": [10, 13], "to": "north_road", "at": [16, 1]},
{"area": "castle", "cell": [10, 0], "to": "green_chapel", "at": [9, 10], "cond": "quest_part(2301) >= 3"},
{"area": "green_chapel", "cell": [9, 11], "to": "castle", "at": [10, 1]}
```

### 7.4 圣龛、宝物、铺子

```json
"shrines": [
  {"id": "camp_altar", "area": "camp", "cell": [5, 11], "name": "shrine_camp", "first_of_chapter": [3]},
  {"id": "fountain_cross", "area": "fountain", "cell": [10, 10], "name": "shrine_fountain", "_说明": "空地口外 4 格"},
  {"id": "lake_shrine", "area": "lake", "cell": [18, 8], "name": "shrine_lake", "_说明": "东岸路边；第 4 章离堤路口 3 格"},
  {"id": "camelot_chapel", "area": "camelot", "cell": [4, 4], "name": "shrine_camelot", "first_of_chapter": [4, 5]},
  {"id": "camelot_outside_cross", "area": "camelot_outside", "cell": [14, 7], "name": "shrine_camelot_outside", "_说明": "城南路口；第 5 章离牛车 15 格"},
  {"id": "north_road_stone", "area": "north_road", "cell": [18, 11], "name": "shrine_north_road"},
  {"id": "castle_chapel", "area": "castle", "cell": [3, 3], "name": "shrine_castle"},
  {"id": "green_chapel_cross", "area": "green_chapel", "cell": [2, 9], "name": "shrine_green_chapel", "_说明": "做完礼拜堂传回卡美洛礼拜堂"}
],
"chests": [
  {"id": "lake_boat", "area": "lake", "cell": [29, 15], "drop": "chest", "name": "chest_lake_boat",
   "condition": "$chapter == 3", "_说明": "搁浅的小船，挨着 ch3_lake_road"},
  {"id": "outside_rack", "area": "camelot_outside", "cell": [27, 3], "drop": "chest", "name": "chest_outside_rack",
   "condition": "$chapter == 3", "_说明": "比武场边的兵器架，挨着 ch3_outside_lists"},
  {"id": "north_road_shed", "area": "north_road", "cell": [26, 5], "drop": "chest", "name": "chest_north_road_shed",
   "_说明": "樵夫的棚子，支线宝物"}
]
```

```json
{"id": "shop_camelot", "name": "npc_quartermaster", "look": "villager1", "area": "camelot", "cell": [20, 14],
 "node": "Shop_camelot", "condition": "$chapter >= 3 and $chapter <= 5", "act": {"type": "look"},
 "_说明": "卡美洛的军需官，打开 items.json shops.camelot。第 5 章 1503 那一夜不在"}
```

### 7.5 chapter_start

```json
"3": {"area": "camp", "cell": [12, 13], "node": "Ch3_Start"}
```

---

## 8. 任务标记 target 提案（quests.json 1003、2301）

| 步骤 | area | target | 说明 |
|---|---|---|---|
| 1301 | camp | [12, 4] 帐门 | — |
| 1302 | fountain | [14, 8] 空地口 | 营地里先标东出口 |
| 1303 | lake | [16, 9] 东岸 | — |
| 1304 | camelot | [16, 1] 北门里 | 婚礼后小目标 quest_1003_p1304b 标大厅靠窗的梅林 [22, 3] |
| 1305 | lake | [16, 10] 东岸 | — |
| 2301 各步 | — | 不标（支线口述） | quests.md：支线没有标记，target 只给任务记录和测试用：north_road [16, 12]、castle [10, 4]、green_chapel [9, 6]、camelot 马厩 [26, 17] |
