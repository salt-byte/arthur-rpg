"""把 design/ART_DIRECTION.md 和目标图合成一页「画风」网页：design/art_direction.html。

用法：python3 tools/render_art.py [项目根目录]
图片按相对路径 targets/*.png 引用：在仓库里打开、发布成页面（targets/ 一起发）都能看到。
改了 ART_DIRECTION.md 或目标图，重跑这个脚本再发布。
"""
import re
import sys
from pathlib import Path

import markdown

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
md = (ROOT / "design" / "ART_DIRECTION.md").read_text(encoding="utf-8")

# 标题行单独处理；「停靠点 B」一节在页面上写成等用户回答
lines = md.splitlines()
game = re.sub(r"^#\s*ART_DIRECTION\s*[·:：]\s*", "", lines[0]).strip()
body_md = "\n".join(lines[1:])
body_md = re.sub(r"## 停靠点 B[\s\S]*$", "", body_md)

# 目标图插进对应的关键时刻下面
IMG = {
    # 时刻一的图放在页首，这里不重复
    "### 时刻二": ("targets/02_church_kay.png", "目标图二：教堂里凯改了口"),
}

html = markdown.markdown(body_md, extensions=["tables", "sane_lists"])

def add_fig(m):
    head = m.group(0)
    for key, (src, cap) in IMG.items():
        if key.replace("### ", "") in head:
            return (head + f'\n<figure class="shot"><img src="{src}" alt="{cap}" width="1280" height="720">'
                    f"<figcaption>{cap}</figcaption></figure>")
    return head

html = re.sub(r"<h3>[^<]*</h3>", add_fig, html)
# 颜色值旁边放一个色块
html = re.sub(r"#([0-9A-Fa-f]{6})\b", lambda m: f'<span class="chip" style="--c:#{m.group(1)}"></span>#{m.group(1)}', html)
# 表格包一层，窄屏横向滚动
html = html.replace("<table>", '<div class="tablewrap"><table>').replace("</table>", "</table></div>")

PAGE = """<title>梅林的学徒画风</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Serif+SC:wght@600;900&family=Silkscreen&display=swap">
<style>
/* 版式：游戏自己的界面契约当页面皮肤，深蓝底、金色像素边、奶油色字；单栏阅读，目标图压在关键时刻下面 */
:root {
  --navy: #181E34;      /* 游戏面板底色 */
  --navy-2: #222A46;
  --ink: #0B0E1A;       /* 像素描边的墨黑 */
  --gold: #C9A24A;      /* 边框、强调 */
  --cream: #F3EAD8;     /* 正文 */
  --cream-dim: #B9B2A3;
  --drop: #7EC4EC;      /* 水滴蓝：只给看水面 */
  --f-display: "Noto Serif SC", "Songti SC", "STSong", serif;
  --f-body: -apple-system, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans SC", sans-serif;
  --f-pixel: "Silkscreen", ui-monospace, monospace;
  color-scheme: dark;
}
body { background: var(--navy); color: var(--cream); font: 16px/1.75 var(--f-body); }
.wrap { max-width: 860px; margin: 0 auto; padding-block: 40px 72px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
header { display: grid; gap: 14px; margin-bottom: 28px; }
.eyebrow { font: 12px/1 var(--f-pixel); letter-spacing: .14em; color: var(--gold); text-transform: uppercase; }
h1 { font: 900 clamp(30px, 6vw, 46px)/1.15 var(--f-display); margin: 0; text-wrap: balance; }
.hero { margin: 0; }
.frame { border: 4px solid var(--ink); outline: 4px solid var(--gold); outline-offset: 0; box-shadow: 0 0 0 8px var(--ink); margin: 12px; }
.frame img { display: block; width: 100%; height: auto; image-rendering: pixelated; }
figcaption { font-size: 13px; color: var(--cream-dim); margin-top: 18px; }
h2 { font: 600 24px/1.3 var(--f-display); color: var(--gold); margin: 48px 0 12px; padding-bottom: 8px;
  border-bottom: 4px solid var(--ink); box-shadow: 0 4px 0 var(--navy-2); text-wrap: balance; }
h3 { font: 600 19px/1.4 var(--f-display); margin: 32px 0 8px; text-wrap: balance; }
p, li { max-width: 68ch; }
strong { color: var(--gold); font-weight: 600; }
code { font-family: ui-monospace, monospace; font-size: .9em; background: var(--navy-2); padding: 1px 6px; }
ul { padding-left: 1.2em; display: grid; gap: 6px; }
.tablewrap { overflow-x: auto; margin: 14px 0; border: 4px solid var(--ink); background: var(--navy-2); }
table { border-collapse: collapse; width: 100%; min-width: 560px; font-size: 14.5px; }
th, td { text-align: left; vertical-align: top; padding: 10px 12px; border-bottom: 2px solid var(--navy); }
th { font-weight: 600; color: var(--gold); background: var(--ink); white-space: nowrap; }
tr:last-child td { border-bottom: 0; }
.chip { display: inline-block; width: 14px; height: 14px; background: var(--c); border: 2px solid var(--ink);
  outline: 1px solid var(--cream-dim); vertical-align: -2px; margin-right: 6px; }
.shot { margin: 18px 0 8px; }
.shot .frame img { image-rendering: pixelated; }
.ask { margin-top: 56px; padding: 20px 22px; background: var(--ink); border-left: 4px solid var(--drop); display: grid; gap: 8px; }
.ask h2 { margin: 0; border: 0; box-shadow: none; padding: 0; color: var(--drop); font-size: 20px; }
.ask p { margin: 0; color: var(--cream); }
a { color: var(--drop); }
a:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; }
</style>
<div class="wrap">
<header>
  <div class="eyebrow">Art direction · step 7 / 18</div>
  <h1>__GAME__ · 画风</h1>
</header>
<figure class="hero"><div class="frame"><img src="targets/01_feast_cup.png" alt="目标图一：庆功宴的酒杯，酒面里亚瑟的剑断成两截，对话框里三个关键选择" width="1280" height="720"></div>
<figcaption>目标图一 · 第 2 章庆功宴：低头看酒杯，酒面里亚瑟的剑砍在铁盾上断成两截。用 LPC 开源素材和 Fusion Pixel 字体拼出来的，不是游戏截图。</figcaption></figure>
__BODY__
<section class="ask">
  <h2>停靠点 B：等你看</h2>
  <p>画风：可以，按它批量找素材；再贴近某部参考作品；还是换方向？</p>
  <p>界面：照目标图里的样式继续；还是换方向？</p>
</section>
</div>
"""

out = PAGE.replace("__GAME__", game).replace("__BODY__", html)
# 关键时刻下面的图也套像素框
out = out.replace('<figure class="shot"><img', '<figure class="shot"><div class="frame"><img').replace(
    '"></img><figcaption>', '"></div><figcaption>')
out = re.sub(r'(<figure class="shot"><div class="frame"><img [^>]+>)(<figcaption>)', r"\1</div>\2", out)
(ROOT / "design" / "art_direction.html").write_text(out, encoding="utf-8")
print("写好 design/art_direction.html")
