# CREDITS · 署名

仓库里用到别人做的美术和字体，按许可要求在这里署名。每加一个素材，加一行。

## 故事
蒙茅斯的杰弗里《不列颠诸王史》（约 1136）、托马斯·马洛礼《亚瑟之死》（1485），公版。所有台词是本作重写的。

## 美术

| 用在哪 | 素材 | 作者 | 许可 | 来源 |
|---|---|---|---|---|
| 目标图里的人物（design/targets/） | LPC 人物图层：男性身体、成年和老年男性头、眼睛、头发、长袖衣、板甲、皮甲、裤子、鞋、靴子、斗篷、兜帽、头盔 | Benjamin K. Smith (BenCreating)、bluecarrot16、Durrani、Eliza Wyatt (ElizaWy)、Evert、JaidynReiman、Joe White、Johannes Sjölund (wulax)、laetissima、Manuel Riecke (MrBeast)、Matthew Krohn (makrohn)、Michael Whitlock (bigbeargames)、MuffinElZangano、Napsio (Vitruvian Studio)、Nila122、Stephen Challener (Redshrike)、thecilekli、Thane Brimhall (pennomi)、TheraHedwig | 每个图层的许可不同，都在 CC-BY-SA 3.0、GPL 3.0、OGA-BY 3.0、CC-BY 3.0/4.0、CC0、GPL 2.0 之内；本仓库按 CC-BY-SA 3.0 用 | 逐个图层的作者、许可、链接：credits/lpc/characters_CREDITS_used.csv（从 Universal LPC Spritesheet Generator 的 CREDITS.csv 截取用到的类别） |
| 目标图里的大厅和教堂（design/targets/） | LPC 室内图块（墙、地板、壁炉、长桌、旗帜、地毯、烛台、柱子） | Lanea Zimmerman (Sharm)、Daniel Armstrong (HughSpectrum) 等 LPC 参赛者，见右列文件 | CC-BY-SA 3.0 / GPL 3.0 | credits/lpc/tiles_*.txt |

素材取自 [salt-byte/graveholme](https://github.com/salt-byte/graveholme) 的 source/assets，原始出处是 [OpenGameArt 的 LPC 合集](https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets-sprites-map-tiles) 和 [Universal LPC Spritesheet Generator](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator)。

目标图是用这些素材拼出来的派生作品，同样按 CC-BY-SA 3.0 发布。

## 字体
| 用在哪 | 字体 | 作者 | 许可 | 来源 |
|---|---|---|---|---|
| 目标图里的中文；之后游戏里的中文 | Fusion Pixel Font 12px 简体中文 | TakWolf | SIL OFL 1.1，全文 credits/FusionPixel_OFL.txt | [TakWolf/fusion-pixel-font](https://github.com/TakWolf/fusion-pixel-font) |

2026-11-09 重做白盒时云端拿不到 GitHub 的发布包，同一套字改从 npm 包 [@vp-tw/cjk-web-fonts-fusion-pixel-font](https://www.npmjs.com/package/@vp-tw/cjk-web-fonts-fusion-pixel-font) 取：它把 Fusion Pixel 12px 简体按 Unicode 分块拆成 woff2，合并回一个字体后再用 tools/build_font.py 截取游戏用到的字。许可不变（OFL 1.1）。

## 代码
Yarn 解释器、任务运行时、检查脚本改自 AI RPG Studio 插件的模板。
scripts/lib/ 下的经验曲线（xp_progression.gd）、技能树（skill_tree.gd）、随机词缀装备（affix_loot.gd）照搬插件 mechanics-library 的参考代码。
