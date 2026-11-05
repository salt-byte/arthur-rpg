# 梅林的学徒（暂定名）

把亚瑟王与梅林的传说做成一款 2D RPG。你是梅林的学徒，能在静止的水面上看见家里人的将来；每一章，你要决定把看见的事说给谁听。大结局改不了，谁陪亚瑟走到最后，由你说出口的话决定。

故事照公版原文改编：马洛礼《亚瑟王之死》（1485）和蒙茅斯的杰弗里。对白全部重写，不用现代改编作品的材料。

用 AI RPG Studio 插件一步一步做，现在做到第 6 步（数据格式和 Godot 工程骨架）。

## 先看哪份
| 想知道 | 看这里 |
|---|---|
| 做到哪、下一步做什么 | `TASKS.md` |
| 定了哪些需求 | `GAME_BRIEF.md` |
| 这是个什么游戏 | `design/CONCEPT.md` |
| 故事：世界、人物、选择和后果 | `content/story/bible.md` |
| 剧情谱（网页，下载后用浏览器打开） | `content/story/story.html` |
| 玩法：总览图和全部设计文档的目录 | `design/GDD.md` |
| 设计总览（网页，下载后用浏览器打开） | `design/design_overview.html` |
| 内容数据怎么写（对白、任务、变量、指令） | `content/README.md` |
| 每一步怎么做的、为什么这么定 | `DEVLOG.md` |

## 跑起来
```
bash tools/setup_godot.sh                                   # 装 Godot 4.3 和网页导出模板
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . --import
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . -- --playtest --route=a   # a / b / c 是第 1 章末的三个选项
```
