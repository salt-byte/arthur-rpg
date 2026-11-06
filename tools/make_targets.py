#!/usr/bin/env python3
"""第 7 步目标图：用 LPC 开源素材拼两张关键时刻的画面（1280×720，含真实的对话框和提示）。

用法：python3 tools/make_targets.py <LPC 素材目录> <像素字体.otf> [输出目录]
  LPC 素材目录：graveholme 仓库的 source/assets（chars/ 和 tiles/），许可见那里的 credits/
  像素字体：Fusion Pixel Font 12px 简体中文（OFL-1.1）
  输出：design/targets/01_feast_cup.png、02_church_kay.png

做法照 design/ART_DIRECTION.md：640×360 逻辑像素拼图块和人物，放大 2 倍；按章调色；界面在放大后的画面上画。
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

A = sys.argv[1]
FONT = sys.argv[2]
OUT = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(__file__), "..", "design", "targets")
os.makedirs(OUT, exist_ok=True)
LW, LH = 640, 360
_cache = {}


def sheet(path):
    if path not in _cache:
        _cache[path] = Image.open(os.path.join(A, path)).convert("RGBA")
    return _cache[path]


def tile(name, col, row, w=1, h=1):
    return sheet(f"tiles/{name}.png").crop((col * 32, row * 32, (col + w) * 32, (row + h) * 32))


DIR = {"up": 0, "left": 1, "down": 2, "right": 3}
ORDER = ["cape_bg", "body", "head", "eyes", "pants", "boots", "shirt", "armor", "cape_fg", "hair", "hat"]
CAST = {   # 每个同伴一种固定衣色（ART_DIRECTION 原则 3）；灰兜帽只给梅林
    "apprentice": dict(body="body", head="head", eyes="eyes", pants="pants_gray", boots="shoes", shirt="shirt_green", cape_bg="cape_bg_black", cape_fg="cape_fg_black", hair="hair_brown"),
    "kay": dict(body="body", head="head", eyes="eyes", pants="pants_brown", boots="boots", shirt="shirt_crimson", hair="hair_dark"),
    "arthur": dict(body="body", head="head", eyes="eyes", pants="pants_gray", boots="boots", shirt="shirt_purple", hair="hair_blond"),
    "merlin": dict(body="body", head="head_old", eyes="eyes", pants="pants_dark", boots="shoes", shirt="shirt_gray", hair="hair_long_white", hat="hood_gray"),
    "ector": dict(body="body", head="head_old", eyes="eyes", pants="pants_brown", boots="boots_black", shirt="shirt_tan", hair="hair_white"),
    "pellinore": dict(body="body", head="head", eyes="eyes", pants="pants_dark", boots="boots_black", armor="plate", hat="helm"),
    "lord1": dict(body="body", head="head", eyes="eyes", pants="pants_gray", boots="boots_black", shirt="shirt_white", armor="leather", hair="hair_red"),
    "lord2": dict(body="body", head="head", eyes="eyes", pants="pants_dark", boots="boots_black", shirt="shirt_gray", hair="hair_black"),
}


def char(who, d="down", anim="walk", frame=0):
    out = Image.new("RGBA", (64, 64))
    for slot in ORDER:
        n = CAST[who].get(slot)
        if n:
            out.alpha_composite(sheet(f"chars/{n}_{anim}.png").crop((frame * 64, DIR[d] * 64, frame * 64 + 64, DIR[d] * 64 + 64)))
    return out


def fill(canvas, t, x0, y0, x1, y1):
    for y in range(y0, y1, t.height):
        for x in range(x0, x1, t.width):
            canvas.alpha_composite(t, (x, y))


def table(canvas, col, row, width):
    """长桌：interior 图块 (20..22, 23..26)：左边一列、中间一列重复、右边一列"""
    for i in range(width):
        c = 20 if i == 0 else 22 if i == width - 1 else 21
        canvas.alpha_composite(tile("interior", c, 23, 1, 4), ((col + i) * 32, row * 32))


def goblet(canvas, x, y):
    px = [(1, 0), (2, 0), (3, 0), (4, 0), (1, 1), (2, 1), (3, 1), (4, 1), (2, 2), (3, 2), (2, 3), (3, 3), (1, 4), (2, 4), (3, 4), (4, 4)]
    for dx, dy in px:
        canvas.putpixel((x + dx, y + dy), (212, 168, 64, 255) if dy < 2 else (176, 132, 46, 255))
    for dx in (2, 3):
        canvas.putpixel((x + dx, y), (120, 24, 40, 255))   # 酒


def grade(img, sat=1.0, warm=(1.0, 1.0, 1.0), vignette=0.35, lift=1.0):
    a = np.asarray(img.convert("RGB")).astype(np.float32) / 255
    g = a.mean(axis=2, keepdims=True)
    a = g + (a - g) * sat
    a = a * np.array(warm, dtype=np.float32) * lift
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    a = a * (1 - vignette * np.clip(r - 0.45, 0, 1)[..., None])
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).convert("RGBA")


def up2(img):
    return img.resize((img.width * 2, img.height * 2), Image.NEAREST)


# ---------------- 界面 ----------------
NAVY, GOLD, INK, CREAM, DROP = (24, 30, 52, 235), (201, 162, 74, 255), (12, 12, 20, 255), (243, 234, 216, 255), (126, 196, 236, 255)


def font(px):
    return ImageFont.truetype(FONT, px)


def panel(d, x0, y0, x1, y1, fill=NAVY, edge=GOLD):
    d.rectangle([x0, y0, x1, y1], fill=INK)
    d.rectangle([x0 + 4, y0 + 4, x1 - 4, y1 - 4], fill=edge)
    d.rectangle([x0 + 8, y0 + 8, x1 - 8, y1 - 8], fill=fill)


def drop_icon(d, x, y, s=3):
    rows = ["..#..", "..#..", ".###.", ".###.", "#####", "#####", "#####", ".###."]
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch == "#":
                c = DROP if not (i == 1 and j in (4, 5)) else (230, 248, 255, 255)
                d.rectangle([x + i * s, y + j * s, x + i * s + s - 1, y + j * s + s - 1], fill=c)


def text(d, xy, s, px=24, fill=CREAM):
    d.fontmode = "1"
    d.text(xy, s, font=font(px), fill=fill)


# =============== 目标图一：庆功宴的酒杯（第 2 章 1205） ===============
def feast():
    c = Image.new("RGBA", (LW, LH), (0, 0, 0, 255))
    fill(c, tile("interior", 2, 29), 0, 96, LW, LH)                        # 木地板
    wall = Image.new("RGBA", (96, 96))
    wall.alpha_composite(tile("interior", 0, 27, 3, 2), (0, 0)); wall.alpha_composite(tile("interior", 0, 27, 3, 1), (0, 64))
    fill(c, wall, 0, 0, LW, 96)                                            # 石墙
    c.alpha_composite(tile("interior", 12, 9, 2, 3), (9 * 32, 0))          # 壁炉
    for x, b in [(3, 14), (6, 15), (13, 15), (16, 14)]:
        c.alpha_composite(tile("interior", b, 13, 1, 2), (x * 32, 8))      # 旗
    c.alpha_composite(tile("interior", 10, 29, 3, 3), (8 * 32 + 16, 8 * 32 + 8))  # 地毯
    for x in (2, 17):
        c.alpha_composite(tile("interior", 19, 21, 1, 2), (x * 32, 3 * 32 + 8))   # 烛台
    # 桌子后面的人：只露上半身
    for who, x in [("ector", 4.6), ("kay", 6.6), ("arthur", 9.0), ("merlin", 11.4), ("lord1", 13.4)]:
        c.alpha_composite(char(who, "down"), (int(x * 32), 4 * 32 - 30))
    table(c, 4, 4, 12)
    for gx in (5.1, 7.1, 9.5, 11.9, 13.9):
        goblet(c, int(gx * 32) + 10, 5 * 32 + 2)
    c.alpha_composite(tile("interior", 19, 10), (8 * 32, 5 * 32 - 8))       # 盘子
    c.alpha_composite(tile("interior", 20, 10), (11 * 32 - 12, 5 * 32 - 10))
    # 桌子这一边：背对镜头
    for who, x in [("lord2", 5.2), ("apprentice", 8.6), ("lord1", 12.8)]:
        c.alpha_composite(char(who, "up"), (int(x * 32), 6 * 32 + 6))
    base = up2(grade(c, sat=1.05, warm=(1.08, 1.0, 0.86), vignette=0.55))

    # 酒面特写：画面里最亮的东西
    v = Image.new("RGBA", (220, 220), (0, 0, 0, 0))
    vd = ImageDraw.Draw(v)
    for y in range(220):                                   # 天：金白往下变暖
        t = y / 220
        vd.line([(0, y), (220, y)], fill=(int(250 - 20 * t), int(236 - 40 * t), int(196 - 70 * t), 255))
    for x in range(0, 220, 9):                             # 林子的影子
        h = 18 + (x * 37) % 17
        vd.polygon([(x - 6, 128), (x + 4, 128 - h), (x + 14, 128)], fill=(150, 160, 96, 255))
    vd.rectangle([0, 128, 220, 220], fill=(176, 190, 112, 255))   # 空地
    v.alpha_composite(char("arthur", "right", "slash", 4), (44, 96))
    v.alpha_composite(char("pellinore", "left", "slash", 2), (106, 94))
    vd.ellipse([112, 122, 124, 138], fill=(150, 156, 166, 255), outline=(80, 84, 92, 255))     # 铁盾
    vd.line([(146, 110), (156, 92)], fill=(226, 232, 240, 255), width=2)                        # 佩利诺举着的剑
    vd.line([(90, 126), (104, 124)], fill=(226, 232, 240, 255), width=2)                         # 亚瑟手里剩下的半截
    vd.line([(86, 128), (90, 126)], fill=(120, 80, 40, 255), width=3)
    vd.line([(104, 96), (114, 84)], fill=(226, 232, 240, 255), width=2)                          # 断开飞出去的半截
    for (sx, sy) in [(108, 120), (104, 116), (112, 114), (100, 120)]:
        vd.point((sx, sy), fill=(255, 252, 230, 255))
    v = v.resize((440, 440), Image.NEAREST)
    mask = Image.new("L", (440, 440), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, 439, 439], fill=255)
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy, r = 940, 250, 190
    gd.ellipse([cx - r - 40, cy - r - 40, cx + r + 40, cy + r + 40], fill=(255, 220, 140, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(30))
    dim = Image.new("RGBA", base.size, (0, 0, 0, 90))
    base.alpha_composite(dim)
    base.alpha_composite(glow)
    vis = v.resize((2 * r, 2 * r), Image.NEAREST)
    m = mask.resize((2 * r, 2 * r))
    base.paste(vis, (cx - r, cy - r), m)
    d = ImageDraw.Draw(base)
    d.ellipse([cx - r - 10, cy - r - 10, cx + r + 10, cy + r + 10], outline=(150, 40, 60, 255), width=10)   # 杯沿上的酒色
    d.ellipse([cx - r - 18, cy - r - 18, cx + r + 18, cy + r + 18], outline=GOLD, width=8)                # 金杯沿
    for k, a in enumerate([120, 80, 45]):
        rr = r + 34 + k * 16
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=(255, 236, 190, a), width=3)          # 水纹
    # 对话框：三个关键选择
    panel(d, 40, 500, 1240, 704)
    text(d, (72, 520), "酒面上，亚瑟的剑砍在一面铁盾上，断成了两截。", 24)
    opts = ["告诉亚瑟：他的剑会在一场决斗里断掉", "告诉梅林", "谁都不说"]
    for i, o in enumerate(opts):
        y = 568 + i * 40
        if i == 0:
            d.rectangle([64, y - 4, 760, y + 32], fill=(52, 66, 104, 255))
        drop_icon(d, 76, y + 2, 3)
        text(d, (104, y), o, 24, CREAM if i == 0 else (205, 205, 215, 255))
    return base


# =============== 目标图二：教堂里凯改口（第 2 章 1203，D1a 应验） ===============
def church():
    c = Image.new("RGBA", (LW, LH), (0, 0, 0, 255))
    fill(c, tile("interior", 1, 31), 0, 96, LW, LH)                        # 菱形石地
    wall = Image.new("RGBA", (96, 96))
    wall.alpha_composite(tile("interior", 0, 27, 3, 2), (0, 0)); wall.alpha_composite(tile("interior", 0, 27, 3, 1), (0, 64))
    fill(c, wall, 0, 0, LW, 96)
    c.alpha_composite(tile("interior", 10, 29, 3, 3), (8 * 32 + 16, 6 * 32))      # 通道上的红毯
    table(c, 7, 1, 6)                                                       # 祭坛：铺白布的桌子
    for x in (6, 13):
        c.alpha_composite(tile("interior", 19, 21, 1, 2), (x * 32, 1 * 32 + 8))   # 烛台
    for x in (3, 16):
        c.alpha_composite(tile("interior", 15, 13, 1, 2), (x * 32, 4))
        c.alpha_composite(tile("interior", 13, 23, 1, 3), ((x + (1 if x < 10 else -1)) * 32, 3 * 32))   # 柱子
    c.alpha_composite(char("arthur", "down"), (9 * 32 + 16, 3 * 32 + 10))
    c.alpha_composite(char("ector", "right"), (6 * 32 + 8, 5 * 32))
    c.alpha_composite(char("kay", "left"), (9 * 32 + 8, 5 * 32))
    sd = ImageDraw.Draw(c)
    kx, ky = 9 * 32 + 8 + 22, 5 * 32 + 40          # 凯的手
    sd.rectangle([kx - 26, ky - 1, kx - 4, ky], fill=(226, 233, 241, 255))               # 剑身，平端着递向埃克托
    sd.rectangle([kx - 4, ky - 4, kx - 3, ky + 3], fill=(196, 152, 58, 255))             # 护手
    sd.rectangle([kx - 2, ky - 1, kx + 3, ky], fill=(110, 70, 36, 255))                  # 剑柄
    sd.point([(kx - 20, ky + 1), (kx - 13, ky - 2), (kx - 9, ky + 1)], fill=(140, 132, 122, 255))   # 石屑
    c.alpha_composite(char("apprentice", "right"), (4 * 32, 5 * 32 + 20))
    base = up2(grade(c, sat=0.95, warm=(1.04, 0.99, 0.92), vignette=0.6))
    d = ImageDraw.Draw(base)
    # 左上：下一步
    panel(d, 24, 18, 470, 74)
    text(d, (48, 32), "下一步：跟埃克托回教堂", 24)
    # 右上：预言簿多了一行（瞬时提示）
    panel(d, 760, 18, 1256, 112, fill=(30, 40, 64, 240), edge=(150, 200, 230, 255))
    drop_icon(d, 784, 36, 3)
    text(d, (812, 32), "预言簿 · 第 1 章那一页", 24, (205, 225, 240, 255))
    text(d, (784, 68), "后来：凯在教堂里改了口", 24)
    # 对话框
    panel(d, 40, 520, 1240, 704)
    panel(d, 64, 488, 184, 540, fill=(140, 40, 40, 255))
    text(d, (100, 498), "凯", 24, (246, 230, 200, 255))
    text(d, (76, 568), "父亲，这把剑……", 24)
    text(d, (76, 616), "……是亚瑟拔出来的。", 24)
    return base


feast().convert("RGB").save(os.path.join(OUT, "01_feast_cup.png"))
church().convert("RGB").save(os.path.join(OUT, "02_church_kay.png"))
print("写好", OUT)
