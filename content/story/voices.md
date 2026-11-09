# 人物口气：从马洛礼原文提炼

改台词前先翻到这个人那一节：看原话，看「句式指纹」，照「给中文台词的建议」写。每节末尾给了 bible.md「说话方式」一行的改法，本文件不动 bible。

**来源和办法**：原文用古腾堡计划收的马洛礼《亚瑟之死》（Caxton 1485 年本的现代拼写整理本，公版）：第 1 卷 Project Gutenberg #1251（Book I–IX），第 2 卷 #1252（Book X–XXI）。用 WebFetch 每次读 10 万字符，让读取模型逐字列出指定人物的直接引语，标出 Book 和 Chapter。第 1 卷读了 Book I–VII 全部、Book VIII 开头和 Book IX 前半；第 2 卷读了 Book XVII 末到 Book XXI 卷末。梅林、亚瑟、凯、摩根和末卷几个人又按人单独重读一遍；石中剑、亚瑟梦见怪兽后梅林两次现身（Book I 第 20 章）、湖边取剑、湖边还剑、梅林拒绝报名（Book II 第 8 章）这几场读了整段对话。去重后得到 430 条引语片段（读取模型每段最多给 125 个字符，长话拆成几段），按人数问句、带 shall 的句子、叹词、誓语、称呼、自称，再挑最能看出口气的原话。做法借自女娲 nuwa-skill 的「表达 DNA」（MIT 许可，花叔）：句式指纹、口头禅、禁忌说法都从人物原话里数出来，不靠想象。中文示例守「肘击指令」（作者将生）的禁用语录。

**抽样的限度**：
- 读取模型转述原文，会漏句。片段数只看大小，比例差几个百分点不算数。
- 第 2 卷 Book X–XVI（崔斯特瑞姆和圣杯的大半）没读，凯和摩根在那几卷还有话。
- Book VI 起出现的「Sir Ector」是兰斯洛特的弟弟 Ector de Maris，已剔除。埃克托只算 Book I 的。
- 埃克托、莫德雷德、贝狄威尔原文话少，下面列的是抽到的全部或几乎全部。

## 总表

| 人物 | 引语片段 | 问句 | 带 shall | 叹 Alas | 说到自己（I / me / my） | 一句话 |
|---|---|---|---|---|---|---|
| 梅林 | 96 | 3（3%） | 37（39%） | 0 | 29（30%） | 结果当面说，带名字和期限，说完就走 |
| 亚瑟·少年（Book I 第 5–6 章） | 19 | 2 | 4 | 1 | 16 | 按先后交代事，嘴里总是“我哥” |
| 亚瑟·称王后 | 120 | 11（9%） | 25（21%） | 13（11%） | 98（82%） | 许诺快，伤心当场说出口 |
| 凯 | 21 | 2 | 6 | 0 | 16 | 起外号，拿自己的命打赌别人出身低 |
| 埃克托 | 15 | 4 | 2 | 0 | 8 | 问事实，叫人当场再做一遍 |
| 高文 | 42 | 4 | 6 | 3 | 33 | 誓语挂嘴上，骂人、认错都一口气说完 |
| 兰斯洛特 | 49 | 2 | 7 | 6 | 42 | 先称呼再说话，后悔挂在嘴上 |
| 桂妮维亚 | 29 | 3 | 3 | 3 | 22 | 平时客气，一生气罪名往上叠 |
| 莫德雷德 | 5（另与阿格规文同声 5） | 0 | 2 | 0 | 4 | 一句话表态，翻脸就威胁 |
| 贝狄威尔 | 9 | 2 | 3 | 0 | 7 | 领命一句，撒谎只报看见什么 |
| 摩根 | 17 | 2 | 2 | 0 | 14 | 命令短，谎话顺，捎话一层层加码 |

梅林和别人差得最远的三处：问句最少，shall 最多，说到自己最少。全书人物都爱用 for 补缘故（梅林 38%，兰斯洛特 39%，亚瑟 29%），这一条算马洛礼的文风，不算梅林的。

---

## 梅林

**原话**
- "That know I well, said Merlin, as well as thyself, and of all thy thoughts, but thou art but a fool to take thought, for it will not amend thee." （Book I, Chapter XX；扮成十四岁的孩子，对刚做完噩梦的亚瑟说） style-ok
- "for ye have lain by your sister, and on her ye have gotten a child that shall destroy you and all the knights of your realm." （Book I, Chapter XX；换成老人模样，同一场） style-ok
- "Whether liketh you better, said Merlin, the sword or the scabbard?" / "Ye are more unwise, said Merlin, for the scabbard is worth ten of the swords" （Book I, Chapter XXV；亚瑟答了“剑”之后） style-ok
- "Nay, said Merlin, not so, for I could save myself an I would; and thou art more near thy death than I am, for thou goest to the deathward, an God be not thy friend." （Book I, Chapter XXIII；亚瑟说“没有我你早死了”） style-ok
- "At this time, said Merlin, I will not tell it thee." （Book II, Chapter VIII；巴林问他名字） style-ok
- "Nay, said Merlin, it will not be" （Book IV, Chapter I；亚瑟叫他用法术躲开自己的结局，他答完就离开了亚瑟） style-ok

**句式指纹**
- 句子长，一句十五个词上下。先下结论或命令，后面补缘故。
- 几乎全是陈述句。96 条里 3 条问句：一条责问（"Hast thou not done enough?"），一条考题（剑还是剑鞘），一条在尤瑟临终床前当众问“亚瑟是不是你的继承人”。没有一次拿问题回答问题。 style-ok
- 带 shall 的占 39%，全书最高。将来的事当成已经定了的事说。
- 说到自己的只占 30%，别人都在一半以上。他说的是对方、第三个人、一把剑、一个地方。
- 称呼：对王叫 Sir，对一群诸侯叫 Fair sirs，对佩利诺直接叫 Knight，对妇人叫 lady。责骂时、扮孩子时改用 thou。
- 不发誓，不叹 Alas。拿上帝的意思当理由："There is none other remedy, but God will have his will."（Book I, Chapter IV） style-ok
- 口头词：Nay / Yea 一个字先表态；Lo 指着东西给人看（"Lo! yonder is that sword that I spake of."）；At this time 用来拒绝。 style-ok
- 骂人不绕：“你更蠢”“你是个傻子”“你该好好后悔”。
- 坏消息当面说完，带名字、带期限。说完不安慰，最多补半句自己的感受："but I may well be sorry, for I shall die a shameful death"。 style-ok

**从来不这么说的**
- 拿问题回答问题，打哑谜，说半句让人猜。
- 格言、比喻、对仗。96 条里找不出一句换个场景还能原样用的话。
- “我不知道”。他每回都说自己知道："I know it better than ye or any man living."（Book I, Chapter XX） style-ok
- 也许、恐怕、我看。抽到的梅林原话里一次 meseemeth、peradventure 都没有。
- 答应改命。

**给中文台词的建议**
- 先说结果，再补一句缘故。缘故落到具体的人、东西、日子上。
- 预言用“会”“要”，带名字和期限，不用“也许”。
- 不想答就说“这个现在不告诉你”，可以加一句什么时候会知道，然后转回对方眼前要办的事。
- 骂人直说。几乎不说“我”。

示例：
- 梅林: 亚瑟挑了剑，挑错了。那个剑鞘值十把剑，挂在腰上，挨多重的刀也不流血。你替我盯着，剑鞘一天也别离他的身。
- 梅林: 妮妙要走，我跟她一起走。到了康沃尔，她会把我关进一块石头底下，活着关进去。从明天起亚瑟身边是你。别来找我。

不要写成这样：
- 梅林: 你问我他会不会死？你看见的，就是答案。 style-ok

**对照 bible**

bible.md 现在这一行（2026-11-09 已改过一次）：

> **说话方式**：话少，句子短，说的都是眼前具体的人、物、地方和要做的事；不想说的就说到那件事打住，岔开去干手上的活，或者拿一个具体问题反问。不说格言和玄话，不拿同一个词正反对着说（用户 2026-11-09 纠正：“一个影子，你让它停下了。到了伦敦，有的事你停不了”“哪些能停，你得自己分”太 AI）。绝不说：我不知道；那件事我改得了。 style-ok

对不上的地方：
- “话少，句子短”：原文梅林话多，句子长，全书解释最多的人就是他（“Sirs, I shall tell you the cause”）。
- “岔开去干手上的活，或者拿一个具体问题反问”：原文他拒绝时明说“这个现在不告诉你”，接着转到对方要办的事上，或者走人。反问一次也没有。
- “具体”“不说格言”和两条“绝不说”对得上，留下。

建议改成：

> **说话方式**：话直，先说结果，后面补一句缘故，缘故落到具体的人、东西、日子上（“剑鞘值十把剑，挂在腰上就不流血”）。将来的事当成定了的事说，带名字和期限；坏消息当面说完，不安慰，最多补半句自己难受。不想答就说“这个现在不告诉你”，有时加一句什么时候会知道，然后转回对方眼前的事，或者走人。骂人直说。几乎不说“我”，不发誓，不打哑谜，不反问，不说格言和玄话（用户 2026-11-09 纠正过师父腔）。绝不说：我不知道；那件事我改得了。

### 梅林原文怎么说预言、怎么拒绝、怎么教

**说预言：谁、会怎样、多久以内，再补一句为什么。**
- "for I shall die a shameful death, to be put in the earth quick, and ye shall die a worshipful death." （Book I, Chapter XX） style-ok
- "Launcelot with this sword shall slay the man that in the world he loved best, that shall be Sir Gawaine." （Book II, Chapter XIX；写在巴林的剑上） style-ok
- "And that penance God hath ordained you for that deed, that he that ye shall most trust to of any man alive, he shall leave you there ye shall be slain." （Book III, Chapter XV；当面对佩利诺说） style-ok
- "Take none heaviness, said Merlin, for this same child within this twenty year shall revenge you on King Claudas," （Book IV, Chapter I） style-ok
- "Care ye not, said Merlin, for he is wholer than ye; for he is but asleep, and will awake within three hours." （Book I, Chapter XXIV） style-ok

规律：
- 名字点全：“that shall be Sir Gawaine”“his first name is Galahad”。
- 期限具体：三个小时以内、三年之内、二十年之内、“all in a day”。
- 缘故多半是对方自己做过的事（佩利诺没停下救那个姑娘；亚瑟和姐姐生了孩子），或者上帝的意思。
- 当着本人说。亚瑟、佩利诺、巴林都是当面听到自己的结局。
- 预言里没有比喻。最夸张的一句是“这里会有两个骑士之间空前绝后的一场决斗”，说的仍是一个具体地方的一场具体决斗。

**拒绝：明说不告诉，有时给个日子，然后转回正事或走人。**
- "At this time, said Merlin, I will not tell, but at that time when Sir Tristram is taken with his sovereign lady, then ye shall hear and know my name" （Book II, Chapter VIII；马克王问他名字） style-ok
- "As for that, said Merlin, be it as it be may, I can tell you wherefore ye ride this way, for to meet King Rience;" （Book II, Chapter VIII；巴林兄弟嫌他不报名，他把话拉回他们要办的事） style-ok
- 亚瑟叫他躲开自己的结局，他只回“Nay, it will not be”，说完就离开了亚瑟（Book IV, Chapter I）。
- Book II 第 8 章，他告诉巴林“你会打出世上最惨的一击”，巴林回嘴说真要那样他宁可自杀叫梅林说谎。梅林没接这句话，“vanished away suddenly”。

**教人：先考一道具体的二选一，答错当场纠正，给缘故，再叮嘱一句，叮嘱会反复说。**
- 湖边那场（Book I, Chapter XXV）：先问“剑和剑鞘你更喜欢哪个”，亚瑟答剑，他说“你更蠢”，讲剑鞘为什么值十把剑，叮嘱“剑鞘时时带在身上”。
- 剑鞘的事他说了三遍：Book I 第 25 章、Book II 第 11 章（"look ye keep well the scabbard of Excalibur"）、Book IV 第 1 章（叙述转述）。 style-ok
- 带人做事时告诉你在哪等、怎么打："Abide, said Merlin, here in a strait way ye shall meet with him"。 style-ok
- 没有让人自己去悟的话。第 1 章 Ch1.yarn 的 ch1_048、ch1_049（“它抬剑之前，肩膀先往后收。一看见它收肩，就拿手指着它，喊出声。”）已经是这个路子。

拒绝的示例：
- 梅林: 他叫什么，现在不告诉你。到了卡美洛，会有人当着你的面喊他。先去把马备好，天黑前要过河。

---

## 亚瑟·少年（拔剑前后，Book I 第 5–6 章）

**原话**
- "I will ride to the churchyard, and take the sword with me that sticketh in the stone, for my brother Sir Kay shall not be without a sword this day." （Book I, Chapter V；自言自语） style-ok
- "When I came home for my brother's sword, I found nobody at home to deliver me his sword; and so I thought my brother Sir Kay should not be swordless," （Book I, Chapter V） style-ok
- "Wherefore I, said Arthur, and for what cause?" （Book I, Chapter V；埃克托说他该当王） style-ok
- "Alas, said Arthur, my own dear father and brother, why kneel ye to me?" （Book I, Chapter VI） style-ok
- "That shall be done, said Arthur, and more, by the faith of my body, that never man shall have that office but he, while he and I live." （Book I, Chapter VI；埃克托求他让凯当总管） style-ok

**句式指纹**
- 按先后讲，用 and so 一件接一件串（回家拿剑、没人、想到哥、就去拔了）。
- 说到自己的占 16/19，说的是自己做了什么，理由都在别人身上：哥今天不能没有剑。
- 称呼：凯是“my brother Sir Kay”（三次），埃克托是“Sir”和“my own dear father”。
- 问句是真问：“为什么是我，凭什么？”
- 拔剑说得轻：“That is no mastery”（这不算本事）、“without any pain”。 style-ok
- 许诺一口答应，还往上加（“and more”），发誓 by the faith of my body。
- 原文这段没有坏消息要他说。他听到坏消息（不是亲生的）时的反应是“你们跪我干什么”。

**从来不这么说的**：说自己配当王；抱怨给凯当侍从；拿身世压人；绕弯子。

**给中文台词的建议**：句子短，按先后讲；叫凯“我哥”；吃惊时问“为什么是我”；答应别人当场答应，再多给一点。

示例：
- 亚瑟: 我回去拿哥的剑，门锁着，人全去比武场了。教堂院子里插着一把，我就拔了。哥今天总不能空着手上场。
- 亚瑟: 爹，你跪着干什么？起来。哥要当总管就让他当，只要我还活着，这个位置谁也拿不走。

不要写成这样：
- 亚瑟: 命运选中了我，我便不能辜负这把剑。 style-ok

**对照 bible**：亚瑟两段合在一行里，改法见下一节末尾。少年这半句“直来直去”对得上，可以再具体一点。

## 亚瑟·称王后

**原话**
- "Now ask, said Arthur, and ye shall have your asking." （Book VII, Chapter I；加雷斯来求赏） style-ok
- "By my head, said Arthur, ye shall wear it or it come on my back, or any man's that here is." （Book IV, Chapter XVI；摩根送来毒斗篷） style-ok
- "Alas, that ever I bare crown upon my head! for now have I lost the fairest fellowship of noble knights that ever held Christian king together." （Book XX, Chapter IX） style-ok
- "and much more I am sorrier for my good knights' loss than for the loss of my fair queen; for queens I might have enow, but such a fellowship of good knights shall never be together in no company." （Book XX, Chapter IX） style-ok
- "Ah, traitor untrue, said King Arthur, now hast thou betrayed me twice." （Book XXI, Chapter V；贝狄威尔第二次没扔剑） style-ok
- "Comfort thyself, said the king, and do as well as thou mayst, for in me is no trust for to trust in;" （Book XXI, Chapter V） style-ok

**句式指纹**
- 句子长短和少年时差不多，口气变成命令和许诺：“I charge you”“go thou”“make you ready”；有人求他，他先说“你说，我答应”。
- 叹得多：Alas 占 11%，全书最多的几个人之一。伤心、后悔当场说出来，常用“Alas, that ever……”起头；当众也说“me repenteth”（Book VII 没认出加雷斯，Book XVIII 王后的毒苹果案）。 style-ok
- 誓语：by my head（和高文共用）、by the faith of my body、make mine avow。许过的话一定提一句会守：“such cries I let make, and that will I hold”“I have promised to do the battle to the uttermost”。 style-ok
- 讲规矩时讲的是许过的话和当众定过的告示。抽到的 120 条里没有一条讲 law；判王后火刑他只说“there to have her judgment and receive the death”。 style-ok
- thou 占 31%：对下属、对敌人、对贝狄威尔用 thou；对一群骑士用 ye，叫 Fair lords、fair fellows；对高文叫 Dear nephew、my sister's son。
- 坏消息往大里说：“the greatest mortal war that ever was”；预感直说：“I dread me I have tarried over long”。 style-ok
- 听了梅林的预言，他叫梅林想办法改（"purvey for it, and put away by your crafts that misadventure"）。 style-ok

**从来不这么说的**：挖苦人、起外号（他转述凯给加雷斯起外号时说“Sir Kay in scorn named him Beaumains”，带着不满）；收回许过的话；拿谜语试探人。 style-ok

**给中文台词的建议**：许诺当场许，说清给什么；伤心说实话（“我心里从没这么沉过”），“唉”起头可以，别铺成长段抒情；叫高文“外甥”；讲规矩说“我许过”“我当众定过”，少说“法”。

示例：
- 亚瑟: 你开口，要什么我先答应。年初在伦敦，你替凯说过一句话，这个我记着。
- 亚瑟: 唉，两天里死了四十个骑士。我心里从没这么沉过。谁也别去告诉高文，他两个弟弟的事我自己跟他说。

不要写成这样：
- 亚瑟: 王冠很重，可它压着的从来不是我的头。 style-ok

**对照 bible**

现在：

> **说话方式**：少年时直来直去；称王后话变少，常讲「法」和「誓」。绝不说：（拔剑前）我是王；（称王后，当众）我错了。

对不上的地方：
- “称王后话变少”：原文称王后他的话比少年时多得多，抽到 120 条，伤心和后悔都当场说。
- “常讲「法」”：抽到的原话里找不到；“誓”对得上。
- “（当众）我错了”：他当众说过“me repenteth”（我后悔），这条“绝不说”要么删，要么改成更窄的。 style-ok

建议改成：

> **说话方式**：少年时句子短，按先后交代事（“我回去拿剑，门锁着，就去拔了那一把”），开口闭口“我哥”，听说自己要当王先问“为什么是我”。称王后命令和许诺多，有人求他，他先说“你说，我答应”，许过的话一定提一句会守；伤心和后悔当场说出来，常用“唉”起头；发誓说“凭我的脑袋”。讲规矩时说“我许过”“我当众定过”，很少说“法”。绝不说：（拔剑前）我是王；（称王后）挖苦人的话；收回自己许过的话。

---

## 凯

**原话**
- "Sir, lo here is the sword of the stone, wherefore I must be king of this land." （Book I, Chapter V） style-ok
- "And sithen he hath no name, I shall give him a name that shall be Beaumains, that is Fair-hands" （Book VII, Chapter I） style-ok
- "into the kitchen I shall bring him, and there he shall have fat brose every day, that he shall be as fat by the twelvemonths' end as a pork hog." （Book VII, Chapter I） style-ok
- "this desireth bread and drink and broth; upon pain of my life he was fostered up in some abbey" （Book VII, Chapter II） style-ok
- "It may well be, said Sir Kay, for yet heard I never that ever good knight came out of Cornwall." （Book IX, Chapter XIV；对崔斯特瑞姆） style-ok
- "Wit ye well, said he, my name is Sir Kay, the Seneschal, that wide-where is known." （Book IX, Chapter II） style-ok

**句式指纹**
- 断言多，问句只有两条，都是显摆或质问（“How liketh you my boy of the kitchen?”“know ye not me?”）。 style-ok
- 拿自己作保：“I dare undertake”“upon pain of my life”，专门用来断定别人出身低。
- 起外号带翻译：先起名，自己再解释一句（“Beaumains, that is Fair-hands”；“La Cote Male Taile, that is as much to say, the evil-shapen coat”）。外号都从对方身上一样看得见的东西来：手、衣服、老家。 style-ok
- 挖苦用的是灶房里的东西：稠粥、面包、汤、猪。
- 报名带官职：“Sir Kay, the Seneschal, that wide-where is known”。 style-ok
- Lo 指着东西给人看，后面接一个对自己有利的结论（“剑在这儿，所以我该当王”）。
- 一听对方来头大，口气马上变：“an ye be Sir Tristram de Liones, ye are the man called now most of prowess”。 style-ok
- 不要人帮忙：“I will none of your help... let me alone with them.”（Book VI, Chapter XI） style-ok
- 叫亚瑟“my brother Arthur”。
- 报坏消息顺手扎人一下：“But I shall ease your heart, yonder is Sir Launcelot that overcame you.”（Book VI, Chapter XVIII） style-ok

**从来不这么说的**：夸一个还不知道来历的新人；道歉（冒认拔剑后在教堂认错是叙述，抽到的原话里没有他道歉）；说自己害怕。

**给中文台词的建议**：外号从看得见的东西来，起完自己解释一句；断定别人时拿自己打赌（“我拿命担保”）；骂人的词从灶房里拿；报名带上“总管”；听到对方是谁家的人，口气立刻变。

示例：
- 凯: 学徒，你这件斗篷是拿麻袋改的吧？往后就叫你麻袋。
- 凯: 我是卡美洛的总管凯爵士，这城里谁不认得。你说你从康沃尔来？我拿命担保，康沃尔还没出过一个像样的骑士。

不要写成这样：
- 凯: 呵，你也配？命运真会开玩笑。 style-ok

**对照 bible**

现在：

> **说话方式**：爱给人起外号、挖苦人。绝不说：我先道歉。

对得上，太薄。建议改成：

> **说话方式**：爱给人起外号，外号从对方身上看得见的东西来（手、衣服、老家），起完自己解释一句；断定别人出身低时拿自己打赌（“我拿命担保他是修道院里养大的”），挖苦用的词是灶房、稠粥、猪；报名总带上“总管”；一听对方来头大，口气马上变。叫亚瑟“我弟弟”。绝不说：我先道歉；夸一个还不知道来历的新人。

---

## 埃克托

原文话少，抽到 15 条，全在 Book I 第 5–6 章。

**原话**
- "How gat ye this sword?" （Book I, Chapter V） style-ok
- "Found ye any knights about this sword?" （Book I, Chapter V） style-ok
- "Now let me see whether ye can put the sword there as it was, and pull it out again." （Book I, Chapter V） style-ok
- "Nay, nay, my lord Arthur, it is not so; I was never your father nor of your blood, but I wot well ye are of an higher blood than I weened ye were." （Book I, Chapter VI） style-ok
- "God forbid I should fail you Sir, said Sir Ector, I will ask no more of you, but that ye will make my son, your foster brother, Sir Kay, seneschal of all your lands." （Book I, Chapter VI） style-ok

**句式指纹**
- 问句占 4/15，全是问事实：剑怎么来的，旁边有没有骑士。不问感受。
- 祈使句短，用 Now 起头：“Now assay”“Now shall ye assay”“Now let me see”。要亲眼看一遍才信。
- 认了亚瑟是王，称呼当场改成“my lord Arthur”“Sir”，跪着说话；对凯还是直接叫“你试试”。
- 坏消息（他不是亲爹）两个 Nay 打头，一句话把实情说完。
- 只求一件事，为自己的儿子：“I will ask no more of you, but that……”。
- 归因于上帝：“for God will have it so”。

**从来不这么说的**：讲大道理；提自己养大了王；替凯辩解（凯冒认，他不吵，叫两个孩子各试一遍）。

**给中文台词的建议**：先问事实，问完叫人当场再做一遍；句子短，“来，你试试”；认了身份就改口；求人只求一件，求完就停。

示例：
- 埃克托: 剑哪来的？拔的时候旁边有骑士没有？走，回教堂。插回去，再拔一次给我看。
- 埃克托: 不，我的主上，没这回事。我从来不是你爹，你身上没有我的血。我只求你一件：让凯当你的总管。

不要写成这样：
- 埃克托: 孩子，血缘不重要，重要的是你心里认谁做父亲。 style-ok

**对照 bible**：次要人物表里埃克托只有「一句话」和「行为逻辑」，没有「说话方式」。建议补一行：

> **说话方式**：（原文话少）问事实，不问感受（“剑哪来的”“旁边有骑士没有”），问完要人当场再做一遍给他看；句子短，常用“来，你试试”起头；认了亚瑟是王，当场改口称“我的主上”，跪着把实情一句话说完；开口求人只求一件，为凯。绝不说：我把你养大的。

---

## 高文

**原话**
- "For I promise unto God, said Sir Gawaine, for the death of my brother, Sir Gareth, I shall seek Sir Launcelot throughout seven kings' realms, but I shall slay him or else he shall slay me." （Book XX, Chapter X） style-ok
- "Will ye so? said Sir Gawaine; then God speed you, for I will not hear your tales ne be of your counsel." （Book XX, Chapter I；阿格规文要去告发兰斯洛特） style-ok
- "Where art thou now, thou false traitor, Sir Launcelot? Why hidest thou thyself within holes and walls like a coward?" （Book XX, Chapter XX） style-ok
- "Mine uncle King Arthur, said Sir Gawaine, wit you well my death-day is come, and all is through mine own hastiness and wilfulness;" （Book XXI, Chapter II） style-ok
- "Alight, traitor knight, for if this mare's son hath failed me, wit thou well a king's son and a queen's son shall not fail thee." （Book XX, Chapter XXII） style-ok

**句式指纹**
- 誓语全书最多（9/42）：By my head、Jesu mercy、Jesu defend、by the faith of my body、I promise unto God。发誓带上代价：“I shall slay him or else he shall slay me”。
- Alas / Ah 起头，紧跟一句实话：“Alas, now is my joy gone.” style-ok
- 骂敌人：thou 加一串骂名（false traitor、recreant knight、like a coward），骂完叫阵：Come forth、Alight。
- 兄弟说错话当面拦：“Now brother, stint your noise”。叫亚瑟“Mine uncle”“my lord”。 style-ok
- 后果看得见就直说：“for I know what will fall of it”。
- 认错也一口气说完，把账全算在自己身上：“all is through mine own hastiness and wilfulness”。
- 夸人不打折：临死给兰斯洛特的信开头是“flower of all noble knights that ever I heard of or saw by my days”。 style-ok
- 拿家世压人：“a king's son and a queen's son shall not fail thee”。 style-ok

**从来不这么说的**：模棱两可，“也许”“再看看”；在兄弟背后告状；文绉绉的比喻（最像比喻的一句是骂兰斯洛特躲在“洞和墙里”）。

**给中文台词的建议**：句子冲，誓说到死；骂人带称号；拦人当面拦；认错时把原因说成自己的急脾气；叫亚瑟“舅舅”。

示例：
- 高文: 阿格规文，住嘴。这种话别在我跟前说。你们要去找舅舅，自己去，我不掺和。这事会闹出什么来，我清楚得很。
- 高文: 我对着上帝起誓，为了加雷斯，走遍七个王国我也要找到兰斯洛特。他死，或者我死。舅舅，备战吧。

不要写成这样：
- 高文: 复仇是一团火，烧掉敌人，也烧掉我自己。 style-ok

**对照 bible**

现在：

> **说话方式**：嗓门大，直来直去。绝不说：在外人面前说家里人的不是。

“直来直去”和“绝不说”对得上。“嗓门大”在抽到的原文里没有描写，可以留作补写。缺誓语和认错的样子。建议改成：

> **说话方式**：直来直去，誓语挂在嘴上（“凭我的脑袋”“耶稣保佑”），发誓带上代价（“他死，或者我死”）；骂敌人一串称号（“叛徒”“孬种骑士”），骂完就叫阵；兄弟说错话当面拦（“住嘴”），不在背后讲；叫亚瑟“舅舅”；认错时把原因全揽到自己的急脾气上。绝不说：在外人面前说家里人的不是；“也许”“再看看”。

---

## 兰斯洛特

**原话**
- "I am Launcelot du Lake, King Ban's son of Benwick, and very knight of the Table Round. And now I defy thee, and do thy best." （Book VI, Chapter VIII） style-ok
- "O thou false knight and traitor unto knighthood, who did learn thee to distress ladies and gentlewomen?" （Book VI, Chapter X） style-ok
- "Ah madam, said Launcelot, in this ye must hold me excused for divers causes" （Book XVIII, Chapter I；王后怪他冷淡） style-ok
- "Madam, said Sir Launcelot, I allow your wit, it is of late come since ye were wise." （Book XVIII, Chapter IX） style-ok
- "Alas, said Sir Launcelot, that ever I should live to hear that most noble king that made me knight thus to be overset with his subject in his own realm." （Book XXI, Chapter VIII） style-ok
- "Wherefore, madam, I pray you kiss me and never no more." （Book XXI, Chapter X） style-ok

**句式指纹**
- 开口先称呼：fair damosel、madam、my fair lords、fair brother、my lord。带 fair 的称呼 7/49，叫女士 11/49，都是全书最多。
- 报名报父亲、报圆桌，不报打赢过谁。被问名字时说“as for to tell thee my name I take no great force”（报不报都无所谓）。 style-ok
- 后悔挂嘴上：“me repenteth”4 条、Alas 6 条。
- “wit ye / you well”7 条，郑重的话前面都垫这一句。 style-ok
- 对欺负人的骑士骂得重，用 thou 加反问：“who did learn thee to distress ladies?” style-ok
- 说到王后的事就推开，不讲缘故：“ye must hold me excused for divers causes”。 style-ok
- 会冷冷顶一句，对王后也顶：“I allow your wit, it is of late come since ye were wise.” style-ok
- 对亚瑟一直敬：叫“my lord the king”“that most noble king that made me knight”；隔着城墙也只说“ye win no worship at these walls”。 style-ok
- 说预感极短，还留一半：“I have warning more than now I will say; therefore give me my rites.”（Book XXI, Chapter XII）抽到的人里，说“我知道的比现在说的多”的是他，梅林没这么说过。 style-ok

**从来不这么说的**：吹自己打赢过谁；说亚瑟一句坏话；当众把对王后的感情说破。

**给中文台词的建议**：先叫人再说话（“姑娘”“夫人”“各位大人”“我的王”）；报名带父亲和圆桌；郑重的话前面垫“您要知道”；后悔就说“这事我后悔”；涉及王后，一句“有好几层缘故，请您原谅”带过；偶尔冷冷顶一句。

示例：
- 兰斯洛特: 姑娘，我是湖上的兰斯洛特，班王的儿子，圆桌的骑士。绑你的人往哪边去了？带我去。
- 兰斯洛特: 我的王，您要知道，凡是您的事，我本该头一个到。这回我晚了一天，这事我后悔。

不要写成这样：
- 兰斯洛特: 剑能斩断一切，却斩不断我心里的那根线。 style-ok

**对照 bible**

现在：

> **说话方式**：谦和，从不夸口。绝不说：亚瑟一句坏话。

“从不夸口”对得上。“谦和”只说中一半：他对坏骑士骂得很重，对王后会冷嘲。建议改成：

> **说话方式**：开口先称呼（“姑娘”“夫人”“各位大人”“我的王”），郑重的话前面垫一句“您要知道”；报名报父亲和圆桌，从不报自己打赢过谁；对欺负人的骑士骂得重，带反问；说到王后的事，一句“有好几层缘故，请您原谅”带过；后悔就直说“这事我后悔”；偶尔冷冷顶一句，对王后也会。绝不说：亚瑟一句坏话；自己赢过谁。

---

## 桂妮维亚

**原话**
- "Ah! Sir Pellinore, said Queen Guenever, ye were greatly to blame that ye saved not this lady's life." （Book III, Chapter XV） style-ok
- "Launcelot, now I well understand that thou art a false recreant knight and a common lecher" （Book XVIII, Chapter II） style-ok
- "And never be thou so hardy to come in my sight; and right here I discharge thee this court" （Book XVIII, Chapter II；紧接上一句） style-ok
- "Slay not my noble knights, and I will go with thee upon this covenant, that thou save them" （Book XIX, Chapter II；对米里亚格朗斯） style-ok
- "Ye say well, said the queen, and better is peace than ever war, and the less noise the more is my worship." （Book XIX, Chapter V） style-ok
- "Through this man and me hath all this war been wrought, and the death of the most noblest knights of the world;" （Book XXI, Chapter IX；在修道院当着众人） style-ok

**句式指纹**
- 平时用 ye、Sir、Truly，礼数在。指人错处直说，同一个句型用过两回：“ye were greatly to blame”（Book III 对佩利诺，Book XVIII 对兰斯洛特）。 style-ok
- 推掉事情用“ye must hold me excused”，后面补一句“that me repenteth”。 style-ok
- 一生气就换成 thou，罪名一个叠一个（false recreant knight、common lecher），叠完下命令：别再让我看见你，你给我离开宫廷。
- 背后骂也不留情：“Fie on him”“No force, though he be destroyed”。 style-ok
- 会谈条件：“I will go with thee upon this covenant, that thou save them”。 style-ok
- 在乎体面，账算得清：“the less noise the more is my worship”。这是抽样里唯一一句像格言的话，说的是怎样不出丑，落在实处。 style-ok
- 下命令不商量：“I warn you that ye ride no more in no jousts”。 style-ok
- 偶尔用 meseemeth（我看）缓一下，2/29。
- 收尾那一场，她当着修女们把自己和兰斯洛特说在一起：“Through this man and me”。

**从来不这么说的**：哭着求人；说软话求兰斯洛特回来（她两次赶他走，修道院那次叫他再也别来见她）。

**给中文台词的建议**：平时客气，带称呼，指人错处直说“这是你的不是”；一生气称呼没了，换成“你”，罪名往上叠，叠完下命令；谈条件用“我跟你走，条件是……”。

示例：
- 桂妮维亚: 学徒，你早知道苹果里有毒，宴席散了才来说。这是你的不是。
- 桂妮维亚: 兰斯洛特，你这个假骑士，变了心的东西。别再让我看见你，明天天亮之前离开卡美洛。

不要写成这样：
- 桂妮维亚: 王冠是我的，心却不由我。 style-ok

**对照 bible**

现在：

> **说话方式**：礼数周全；话锋利的时候只说一句。绝不说：当众说兰斯洛特的名字和「爱」放在一起。

对不上的地方：
- “话锋利的时候只说一句”：原文她一生气说一串，罪名叠好几层，还连着下命令。
- “绝不说”：Book XXI 第 9 章她在修道院当众说了。要么加时间限定，要么只管到第 6 章那一场之前。

建议改成：

> **说话方式**：平时客气，带称呼，指人错处直说“这是你的不是”，推事情说“你得原谅我，我去不了”；一生气称呼就没了，换成“你”，罪名一个接一个往上叠，叠完下命令（“别再让我看见你”）；会谈条件（“我跟你走，条件是你放了他们”）；在乎体面，怕事情闹大。绝不说：哭着求人；当众把兰斯洛特的名字和“爱”放在一起（第 6 章修道院那一场之前）。

---

## 莫德雷德

原文话少：抽到五句独白，另有五句和阿格规文一起喊。他的信和对军队的嘱咐都是转述。

**原话**
- "Then will I, said Sir Mordred." （Book XX, Chapter I；高文不肯去告发） style-ok
- "Yea, so God me help, said Sir Mordred, there we found him unarmed, and there he slew Colgrevance, and armed him in his armour;" （Book XX, Chapter VII；向亚瑟报告） style-ok
- "Do thou thy worst, said Sir Mordred, wit thou well I shall defy thee." （Book XXI, Chapter I；对坎特伯雷大主教） style-ok
- "Peace, thou false priest, said Sir Mordred, for an thou chafe me any more I shall make strike off thy head." （Book XXI, Chapter I） style-ok
- "Traitor-knight, come out of the queen's chamber, for wit thou well thou art so beset that thou shalt not escape." （Book XX, Chapter III；和阿格规文同声） style-ok

**句式指纹**
- 独白全都很短，没有一句解释动机。
- 表态快：高文说不去，他接一句“Then will I”（那我去）。
- 向王报事只报事实，用 there…and there… 串：在哪、看见什么、谁干了什么，不加评语，起一个誓（so God me help）作保。
- 翻脸以后对神父用 thou，直接说要砍头。
- 抽到的原话里没有客套话，也没有一句对亚瑟说的软话。

**从来不这么说的**：讲自己的身世和委屈；长篇解释；求父亲。

**给中文台词的建议**：话少，句句短；接活一句“那我去”；在王面前报事一条一条，不带形容词；翻脸以后直接威胁。bible 写的宫里的客气是补写的面具，可以留，写法改成少开口、只报事实，不写圆滑的场面话。

示例：
- 莫德雷德: 高文不去，我去。
- 莫德雷德: 我对上帝起誓，王上。我们到的时候他没穿甲。他在门口杀了科尔格雷万斯，穿上那身甲，又杀了阿格规文。

不要写成这样：
- 莫德雷德: 王上，有些真相比谎言更伤人，您确定要听吗？ style-ok

**对照 bible**

现在：

> **说话方式**：客气，句句在理，听不出恶意。绝不说：我是你的儿子（第 6 章之前）。

“客气，听不出恶意”在原文里找不到依据，原文的莫德雷德话短、硬。bible 要保留，得标成补写。建议改成：

> **说话方式**：（原文话少，五句独白）话短，表态快，别人不肯干的事他一句“那我去”就接下；在王面前报事只报事实，在哪、谁、干了什么，一条一条说，不加评语，起个誓作保；宫里的客气是补写的面具，写成少开口、只报事实，不写成圆滑的场面话；翻脸以后句子更短，直接威胁。绝不说：我是你的儿子（第 6 章之前）；替自己解释动机。

---

## 贝狄威尔

原文话少，抽到九句，全在 Book XXI 第 4–6 章。

**原话**
- "My lord, said Bedivere, your commandment shall be done, and lightly bring you word again." （Book XXI, Chapter V） style-ok
- "If I throw this rich sword in the water, thereof shall never come good, but harm and loss." （Book XXI, Chapter V；藏剑时自言自语） style-ok
- "Sir, he said, I saw nothing but waves and winds." （Book XXI, Chapter V；第一次撒谎） style-ok
- "Sir, he said, I saw nothing but the waters wap and waves wan." （Book XXI, Chapter V；第二次撒谎） style-ok
- "Ah my lord Arthur, what shall become of me, now ye go from me and leave me here alone among mine enemies?" （Book XXI, Chapter V） style-ok
- "For from hence will I never go, said Sir Bedivere, by my will, but all the days of my life here to pray for my lord Arthur." （Book XXI, Chapter VI） style-ok

**句式指纹**
- 领命一句话，答得快：“your commandment shall be done”。
- 心里不服不顶嘴，自己嘀咕一句算得失：扔了“不会有好处，只有损失”。
- 撒谎只报看见什么，两次都用“I saw nothing but……”，第二次多了声音和颜色（wap、wan）。
- 叫亚瑟 My lord、Sir、my lord Arthur，到死不改。
- 怕了就直问“我怎么办”；临走那句是立誓留下来守墓。

**从来不这么说的**：当面驳王的命令；长篇解释；讲道理劝王。

**给中文台词的建议**：句子短，朴素；领命“遵命，我去去就回”；不服只在自语里嘀咕得失；撒谎时只说看见的东西；叫亚瑟“我的王”。

示例：
- 贝狄威尔: 遵命，王上。我去城门口数人，伤了几个、走不动的几个，回来报你。
- 贝狄威尔:（自语）城里最后两匹好马也派出去，回头有人来攻，拿什么送信。

不要写成这样：
- 贝狄威尔: 湖水收下了剑，也收下了一个时代。 style-ok

**对照 bible**：次要人物表里贝狄威尔没有「说话方式」。建议补一行：

> **说话方式**：（原文话少，九句，全在第 21 卷）话短，朴素；领命一句“遵命，我去去就回”；心里不服不当面顶，只自己嘀咕一句算得失；撒谎时只报看见的东西（“我只看见浪和风”）；叫亚瑟“我的王”，到死不改；怕了就直问“我怎么办”。绝不说：当面驳王的命令。

---

## 摩根（Morgan le Fay）

**原话**
- "Go fetch me my lord's sword, for I saw never better time to slay him than now." （Book IV, Chapter XIII；要杀睡着的丈夫尤里恩） style-ok
- "O fair son, Uwaine, have mercy upon me, I was tempted with a devil, wherefore I cry thee mercy;" （Book IV, Chapter XIII；被儿子抓住） style-ok
- "I may not, said Morgan le Fay, for I have such hasty tidings, that I may not tarry." （Book IV, Chapter XIV；王后留她，她撒谎） style-ok
- "Whatsoever come of me, my brother shall not have this scabbard." （Book IV, Chapter XIV；把剑鞘扔进湖里） style-ok
- "and tell him I fear him not while I can make me and them that be with me in likeness of stones; and let him wit I can do much more when I see my time." （Book IV, Chapter XV；捎给亚瑟的话） style-ok
- "Saw ye Arthur, my brother?" （Book IV, Chapter XV） style-ok

**句式指纹**
- 下命令短：“Go fetch me”“hie thee fast”“I charge you that none of you awake him”。 style-ok
- 口头禅 my time：“now I see my time”“when I see my time”。她等时机，也把时机挂在嘴上。
- 叫亚瑟“my brother”，抽到的原话里一次也没叫过他“王”；叫儿子“fair son, Uwaine”。
- 撒谎顺，理由现成：“I have such hasty tidings, that I may not tarry”。被抓住就立刻求饶，推给魔鬼。 style-ok
- 捎话挑衅用 and tell him / and let him wit，一层一层往上加。 style-ok
- 两条问句都是打探：“Saw ye Arthur, my brother?”“Of whence be ye?” style-ok
- 不叹气，不发誓。抽到的原话里没提梅林。
- 原文里没有她“说话慢”“叫人全名”的依据。
- 卷末接亚瑟上船的女王里第一位是“King Arthur's sister, Queen Morgan le Fay”。船上那位女王说“Ah, dear brother, why have ye tarried so long from me?”（Book XXI, Chapter V），原文没点名是谁，按“dear brother”推断是摩根。 style-ok

**从来不这么说的**：叫亚瑟“陛下”“王”；解释自己为什么恨；长篇抒情。

**给中文台词的建议**：命令短；叫亚瑟“我弟弟”；说谎给一个现成的小理由；给对头捎话用“告诉他……再让他知道……”往上加；“看准了时候”挂在嘴上。

示例：
- 摩根: 剑鞘在我手里。回去告诉我弟弟，是我拿的。再让他知道，我不怕他，等我看准了时候，还有他受的。
- 摩根: 王后，我不能多坐，家里来了急信。你们谁见过我弟弟？他走的哪条路？

不要写成这样：
- 摩根: 亚瑟·潘德拉贡，命运的轮子转回来了。 style-ok

**对照 bible**

现在：

> **说话方式**：（补写）说话慢，喜欢叫人的全名。绝不说：梅林的名字后面加上「大人」。

“说话慢”“叫全名”原文没有依据；她嘴里的亚瑟是“我弟弟”。关于梅林那条，抽到的原话里没有，留作补写。建议改成：

> **说话方式**：下命令短（“去把剑拿来”“快去”）；叫亚瑟“我弟弟”，从不叫他“王”；说谎张口就来，带一个现成的小理由（“家里来了急信，不能多留”）；被抓住就马上求饶，推给别人；给对头捎话一层层加码（“告诉他……再让他知道……”）；“看准了时候”挂在嘴上。绝不说：称亚瑟“陛下”；梅林的名字后面加上“大人”（补写）。
