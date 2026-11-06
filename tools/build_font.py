"""从 Fusion Pixel Font 12px 简体（OFL 1.1，TakWolf）里只截游戏用到的字，生成 assets/fonts/pixel12.otf。

用法：python3 tools/build_font.py <fusion-pixel-12px-proportional-zh_hans.otf 的路径> [项目根]
扫描 scripts/ 下的 .gd 和 content/ 下的 .yarn .csv .json；加了新文字后重跑，再在 Godot 里重新导入。
插件 localization-table 的 build_fonts.py 截的是 Noto CJK；本项目按 ART_DIRECTION 用像素字，所以单写这一个。
"""
import glob
import os
import shutil
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

src = sys.argv[1]
root = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else ".")
chars = set(chr(c) for c in range(32, 127)) | set("·—…「」《》“”‘’！？，。、：；（）【】→←↑↓▼▲①②③④⑤×％")
files = glob.glob(os.path.join(root, "scripts/**/*.gd"), recursive=True)
files += [f for f in glob.glob(os.path.join(root, "content/**/*"), recursive=True) if f.endswith((".yarn", ".csv", ".json"))]
for f in files:
    chars |= set(open(f, encoding="utf-8").read())
text = "".join(sorted(c for c in chars if c.isprintable()))
font = TTFont(src)
cmap = font.getBestCmap()
missing = sorted(c for c in text if ord(c) not in cmap and not c.isspace())
opts = subset.Options()
opts.layout_features = ["*"]
opts.name_IDs = ["*"]
opts.notdef_outline = True
s = subset.Subsetter(opts)
s.populate(text=text)
s.subset(font)
out = os.path.join(root, "assets/fonts/pixel12.otf")
os.makedirs(os.path.dirname(out), exist_ok=True)
font.save(out)
lic = os.path.join(os.path.dirname(src), "OFL.txt")
if os.path.exists(lic):
    shutil.copy(lic, os.path.join(root, "assets/fonts/OFL.txt"))
print(f"{out} {os.path.getsize(out) // 1024} KB，{len(text)} 个字；字体里没有的 {len(missing)} 个：{''.join(missing[:40])}")
