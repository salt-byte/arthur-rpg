#!/usr/bin/env python3
"""从故事圣经和同伴名单生成 content/dialogue/Variables.yarn（全部剧情变量的声明）。

用法：python3 tools/build_variables.py [项目根]
改了 bible.json 的选项标记或 companions.json 的名单，就重跑一次；不要手改 Variables.yarn。

命名（content/README.md「变量」一节）：
  （注释只能单独占一行：解释器把行尾带注释的指令当成台词）
  $D1…$D6、$S1…$S4、$V   每个决定选了哪个选项，存选项 id（"D1a"），没选是 ""
  $<标记名>               bible.json 里选项的 flags，布尔，默认 false
  $c_<同伴 id>            同伴状态："none" 还没来 / "party" 在队 / "left" 离开 / "dead" 离世
  系统变量                $player_name $chapter $last_battle $last_battle_won $back
"""
import json
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
bible = json.loads((ROOT / "content/story/bible.json").read_text(encoding="utf-8"))
roster = json.loads((ROOT / "content/data/companions.json").read_text(encoding="utf-8"))["roster"]

decisions = [d["id"] for d in bible["decisions"]]
flags = {}
for d in bible["decisions"]:
    for op in d["options"]:
        for f in (op.get("flags") or {}):
            flags.setdefault(f, []).append(op["id"])
        for cond in (op.get("flags_by_condition") or []):
            for f in (cond.get("flags") or {}):
                flags.setdefault(f, []).append(op["id"] + "（按条件）")

out = ["title: Variables", "tags: declarations", "---",
       "// 由 tools/build_variables.py 从 bible.json 和 companions.json 生成，不要手改。",
       "// 系统变量",
       '<<declare $player_name = "学徒">>',
       "<<declare $chapter = 1>>",
       '<<declare $last_battle = "">>',
       "<<declare $last_battle_won = false>>",
       '<<declare $back = "">>',
       "// 每个决定选了哪个选项（存选项 id，没选是空字符串）"]
for d in decisions:
    out.append(f'<<declare ${d} = "">>')
out.append("// $V：第 5 章高文发誓时的附加选项 V0 / V1 / V2")
out.append('<<declare $V = "">>')
out.append("// 选项带来的标记（后面是哪些选项会设它）")
for f in sorted(flags):
    out.append(f"// {'、'.join(dict.fromkeys(flags[f]))}")
    out.append(f"<<declare ${f} = false>>")
out.append('// 同伴状态："none" 还没来 / "party" 在队 / "left" 离开 / "dead" 离世')
for c in roster:
    out.append(f'<<declare $c_{c["id"]} = "none">>')
out.append("===")
dst = ROOT / "content/dialogue/Variables.yarn"
dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"写好 {dst.relative_to(ROOT)}：{len(decisions) + 1} 个决定，{len(flags)} 个标记，{len(roster)} 个同伴")
