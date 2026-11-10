#!/usr/bin/env python3
"""本项目的数据检查：插件的 check_content.py 查通用格式，这里查本作自己加的东西。

用法：python3 tools/check_project_data.py [项目根]
查：
  1. 本作新加的指令（vision / book_after / unlock / companion / chapter / autosave / teleport / open_shop）参数对得上：
     看水面的决定 id 在 prophecy.json 里，解锁 id 在 story-unlocks.json 里，同伴 id 在 companions.json 里；
     <<teleport 地方 x y>> 的地方在 maps.json 里、格子在图上且走得上去；<<open_shop 店>> 的店在 items.json shop.shops 里
  2. <<fight_npcs X>>、任务步骤的 battle、刷新点的 enemy 都是 combat.json 里的遭遇；遭遇里的敌人都存在
  3. 任务步骤、NPC、刷新点的 area 都在 overworld.json 的 areas 里
  4. 叙事进展的 at、看水面的节点、任务的开关节点都在剧情谱 outline.json 里
  5. 数据里用到的文本键（地方名、敌人名、提示框、画面文字、圣龛和宝物的名字）都在 game_text.csv 里
  6. maps.json 的地方都在 overworld.json 里登记过；出口通向的地方存在；圣龛、宝物、地图小仗的格子在图上
退出码：0 没错误；1 有错误。
"""
import csv
import glob
import json
import os
import re
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "content", "data")
load = lambda name: json.load(open(os.path.join(D, name), encoding="utf-8"))
errors = []

combat, quests, npcs, spawns = load("combat.json"), load("quests.json"), load("npcs.json"), load("spawns.json")
unlocks, prophecy, companions, overworld = load("story-unlocks.json"), load("prophecy.json"), load("companions.json"), load("overworld.json")
outline = json.load(open(os.path.join(ROOT, "content", "story", "outline.json"), encoding="utf-8"))
maps, items = load("maps.json"), load("items.json")
shops = items.get("shop", {}).get("shops", {})

texts = set()
for p in glob.glob(os.path.join(ROOT, "content", "strings", "*.csv")):
    if os.path.basename(p) != "dialogue.csv":
        texts |= {r[0] for r in csv.reader(open(p, encoding="utf-8")) if r}

beats = {b["id"] for a in outline["acts"] for b in a["beats"]} | {s["id"] for s in outline["side"]}
areas = {a["id"] for a in overworld["areas"]}
encounters = {k: v for k, v in combat["encounters"].items() if not k.startswith("_")}
enemies = {k for k in combat["enemies"] if not k.startswith("_")}
visions = {v["decision"] for v in prophecy["visions"]}
unlock_ids = {u["id"] for u in unlocks["unlocks"]}
comp_ids = {c["id"] for c in companions["roster"]}
STATES = {"none", "party", "left", "dead"}

# 1–2. 对白里的指令
for f in sorted(glob.glob(os.path.join(ROOT, "content", "dialogue", "*.yarn"))):
    name = os.path.basename(f)
    for i, line in enumerate(open(f, encoding="utf-8"), 1):
        for m in re.finditer(r"<<\s*(\w+)\s*([^>]*)>>", line.strip()):
            cmd, args = m.group(1), m.group(2).split()
            at = f"{name}:{i}"
            if cmd in ("vision", "book_after") and (not args or args[0] not in visions):
                errors.append(f"{at} <<{cmd}>> 的决定 {args[:1]} 不在 prophecy.json 的 visions 里")
            if cmd == "book_after" and (len(args) < 2 or args[1] not in texts):
                errors.append(f"{at} <<book_after>> 的文本键 {args[1:2]} 不在 game_text.csv 里")
            if cmd == "unlock" and (not args or args[0] not in unlock_ids):
                errors.append(f"{at} <<unlock>> 的 {args[:1]} 不在 story-unlocks.json 里")
            if cmd == "companion" and (len(args) != 2 or args[0] not in comp_ids or args[1] not in STATES):
                errors.append(f"{at} <<companion>> 要写成 <<companion 同伴id none|party|left|dead>>，现在是 {args}")
            if cmd == "fight_npcs" and (not args or args[0] not in encounters):
                errors.append(f"{at} <<fight_npcs>> 的遭遇 {args[:1]} 不在 combat.json 的 encounters 里")
            if cmd == "chapter" and (not args or not args[0].isdigit() or not 1 <= int(args[0]) <= 6):
                errors.append(f"{at} <<chapter>> 要跟 1–6 的章号")
            if cmd == "teleport":
                if len(args) != 3 or args[0] not in maps["areas"] or not args[1].isdigit() or not args[2].isdigit():
                    errors.append(f"{at} <<teleport>> 要写成 <<teleport 地方 x y>>，地方是 maps.json 里的 id，现在是 {args}")
                else:
                    rows = maps["areas"][args[0]]["rows"]
                    x, y = int(args[1]), int(args[2])
                    if not (0 <= y < len(rows) and 0 <= x < len(rows[0])) or maps["tiles"].get(rows[y][x], {"block": True}).get("block"):
                        errors.append(f"{at} <<teleport>> 的格子 ({x}, {y}) 不在 {args[0]} 图上，或者是挡路的格子")
            if cmd == "open_shop" and (len(args) != 1 or args[0] not in shops):
                errors.append(f"{at} <<open_shop>> 的店 {args[:1]} 不在 items.json 的 shop.shops 里")

# 2. 遭遇
for k, e in encounters.items():
    for en in e.get("enemies", []):
        if en not in enemies:
            errors.append(f"combat.json 遭遇 {k} 的敌人 {en} 不在 enemies 里")
    if "name" in e and e["name"] not in texts:
        errors.append(f"combat.json 遭遇 {k} 的名字键 {e['name']} 不在 game_text.csv 里")
for k in enemies:
    for step in combat["enemies"][k].get("pattern", []):
        if step.get("act") == "summon" and step.get("what") not in enemies:
            errors.append(f"combat.json 敌人 {k} 召唤的 {step.get('what')} 不存在")
    if combat["enemies"][k].get("name", "") not in texts:
        errors.append(f"combat.json 敌人 {k} 的名字键不在 game_text.csv 里")

# 2–4. 任务
for qid, q in quests.items():
    if qid.startswith("_"):
        continue
    for p in q["parts"]:
        if p.get("battle") and p["battle"] not in encounters:
            errors.append(f"quests.json {qid} 步骤 {p['id']} 的遭遇 {p['battle']} 不在 combat.json 里")
        if p.get("area") and p["area"] not in areas:
            errors.append(f"quests.json {qid} 步骤 {p['id']} 的地方 {p['area']} 不在 overworld.json 里")
        if q["type"] == "main" and str(p["id"]) not in beats:
            errors.append(f"quests.json {qid} 的步骤 {p['id']} 不是剧情谱里的节点")
    for key in ("opens_at", "closes_before"):
        if q.get(key) and q[key] not in beats:
            errors.append(f"quests.json {qid} 的 {key} {q[key]} 不是剧情谱里的节点")

# 3. NPC、刷新点
for n in npcs["npcs"]:
    if n.get("area") not in areas:
        errors.append(f"npcs.json {n['id']} 的地方 {n.get('area')} 不在 overworld.json 里")
for s in spawns["spawns"]:
    if s["enemy"] not in encounters:
        errors.append(f"spawns.json {s['id']} 的遭遇 {s['enemy']} 不在 combat.json 里")
    if s.get("area") not in areas:
        errors.append(f"spawns.json {s['id']} 的地方 {s.get('area')} 不在 overworld.json 里")

# 4. 节点
for u in unlocks["unlocks"]:
    if u["at"] not in beats and not u["at"].startswith("first_"):
        errors.append(f"story-unlocks.json {u['id']} 的 at {u['at']} 不是剧情谱里的节点")
for v in prophecy["visions"]:
    for key in ("seen_at", "decide_at"):
        if v[key] not in beats:
            errors.append(f"prophecy.json {v['decision']} 的 {key} {v[key]} 不是剧情谱里的节点")

# 5. 文本键
for a in overworld["areas"]:
    if a["name"] not in texts:
        errors.append(f"overworld.json 地方 {a['id']} 的名字键 {a['name']} 不在 game_text.csv 里")
for u in unlocks["unlocks"]:
    for k in (u.get("popup") or {}).values():
        if k not in texts:
            errors.append(f"story-unlocks.json {u['id']} 的提示框键 {k} 不在 game_text.csv 里")
for v in prophecy["visions"]:
    if v.get("text") and v["text"] not in texts:
        errors.append(f"prophecy.json {v['decision']} 的画面键 {v['text']} 不在 game_text.csv 里")

# 6. 地图
for a, ad in maps["areas"].items():
    if a not in areas:
        errors.append(f"maps.json 的地方 {a} 没在 overworld.json 的 areas 里登记")
    for e in ad.get("exits", []):
        if e["to"] not in maps["areas"]:
            errors.append(f"maps.json {a} 的出口通向不存在的地方 {e['to']}")
def on_map(area, cell, what):
    if area not in maps["areas"]:
        return
    rows = maps["areas"][area]["rows"]
    x, y = cell
    if not (0 <= y < len(rows) and 0 <= x < len(rows[0])):
        errors.append(f"{what} 的格子 {cell} 不在 {area} 图上")
for s_ in overworld["shrines"] + overworld["chests"]:
    on_map(s_["area"], s_["cell"], f"overworld.json {s_['id']}")
    if s_.get("name") and s_["name"] not in texts:
        errors.append(f"overworld.json {s_['id']} 的名字键 {s_['name']} 不在 game_text.csv 里")
for zid, z in spawns.get("zones", {}).items():
    on_map(z["area"], z["cell"], f"spawns.json zones.{zid}")
    if z["enemy"] not in encounters:
        errors.append(f"spawns.json zones.{zid} 的遭遇 {z['enemy']} 不在 combat.json 里")

for e in errors:
    print("错误 ", e)
print(f"本项目数据检查完：{len(encounters)} 场遭遇，{len(areas)} 个地方，{len([q for q in quests if not q.startswith('_')])} 条任务，{len(errors)} 个错误")
sys.exit(1 if errors else 0)
