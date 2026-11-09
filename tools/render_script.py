#!/usr/bin/env python3
"""把 content/dialogue/*.yarn 排成一页能读的剧本 content/dialogue/script.html（整份重写）。

名字牌是谁在说，没名字的是旁白；条件分支并排放，条件写成人话，灰字是原文；
看水面的画面、预言簿「后来」、小目标都从文本表取原文。改完对白跑一遍：

    python3 tools/render_script.py

页头和样式在 tools/script_page_head.html。
"""
import csv, html, json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DLG = os.path.join(ROOT, "content/dialogue")
OUT = os.path.join(DLG, "script.html")
FILES = ["Ch1", "Ch2", "Ch3", "Ch4", "Ch5", "Ch6", "Side"]

TEXT = {}
with open(os.path.join(ROOT, "content/strings/game_text.csv"), encoding="utf-8") as f:
    for row in csv.reader(f):
        if len(row) >= 2:
            TEXT[row[0]] = row[1]

outline = json.load(open(os.path.join(ROOT, "content/story/outline.json"), encoding="utf-8"))
BEAT, SIDE, CHOICE = {}, {}, {}
for act in outline.get("acts", []):
    for b in act.get("beats", []):
        BEAT[b["id"]] = b.get("title", "")
        for c in b.get("choices", []):
            for o in c.get("options", []):
                CHOICE[o["id"]] = o.get("label", "")
for s in outline.get("side", []):
    SIDE[s["id"]] = s.get("title", "")
    for c in s.get("choices", []):
        for o in c.get("options", []):
            CHOICE[o["id"]] = o.get("label", "")

proph = json.load(open(os.path.join(ROOT, "content/data/prophecy.json"), encoding="utf-8"))
VISION = {v["decision"]: v for v in proph.get("visions", [])}

PEOPLE = {"kay": "凯", "arthur": "亚瑟", "gawain": "高文", "gareth": "加雷斯", "gaheris": "加赫里斯",
          "agravaine": "阿格规文", "mordred": "莫德雷德", "lancelot": "兰斯洛特", "guinevere": "桂妮维亚",
          "bedivere": "贝狄威尔", "merlin": "梅林"}
STATE = {"party": "在队里", "left": "离队", "dead": "离世"}
NOT_STATE = {"party": "不在队里", "left": "没离队", "dead": "还活着"}
FLAG = {"kay_believes_you": "凯信你", "kay_protected_gareth": "凯在法场护过加雷斯", "player_knows_place": "你知道梅林在哪",
        "arthur_trusts_sight": "亚瑟信你的预见", "arthur_fears_sight": "亚瑟怕听你的预见", "lancelot_warned": "你提醒过兰斯洛特",
        "guinevere_trusts_you": "王后信你", "gareth_refused_order": "加雷斯没去法场", "player_late": "你来晚了",
        "merlin_teaches": "梅林正经教你", "gawain_owes_you": "高文欠你一条命", "arthur_knew_affair": "亚瑟知道王后的事"}
TAGS = {"chapter": "章节开场", "npc": "找他说话", "area": "走到这里触发", "battle": "战斗", "decision": "关键选择",
        "readback": "应验", "story": "剧情", "scene": "剧情", "cutscene": "过场", "event": "事件", "vision": "看水面",
        "prop": "物件", "rumor": "线索", "side": "支线", "ending": "结局"}
CMD = {"autosave": "存档", "book_after": "预言簿·后来", "chapter": "换章", "companion": "同伴", "complete_quest": "任务完成",
       "fight_npcs": "开打", "jump": "跳到", "objective": "小目标", "progress_quest": "任务推进", "show_ending": "结局",
       "start_quest": "接任务", "unlock": "能力", "vision": "看水面", "close_side": "支线关门"}
SKIP_CMD = {"set", "declare"}


def esc(t):
    return html.escape(t, quote=False)


def clean(t):
    t = re.sub(r"\s#[^\s#<]+", "", " " + t).strip()
    return t.replace("{$player_name}", "（你的名字）")


# ---------- 读 .yarn ----------
def read_nodes(path):
    nodes, cur, body = [], None, False
    for raw in open(path, encoding="utf-8").read().split("\n"):
        line = raw.rstrip()
        if cur is None:
            if line.startswith("title:"):
                cur = {"title": line[6:].strip(), "tags": [], "lines": []}
                body = False
            continue
        if not body:
            if line.startswith("tags:"):
                cur["tags"] = line[5:].split()
            elif line.strip() == "---":
                body = True
            continue
        if line.strip() == "===":
            nodes.append(cur)
            cur = None
            continue
        cur["lines"].append(line)
    return nodes


def choice_labels():
    """选项底下紧跟 <<set $X to "Y">> 的，把 Y 记成这个选项的说法，给条件翻译用。"""
    out = {}
    for name in FILES:
        lines = open(os.path.join(DLG, name + ".yarn"), encoding="utf-8").read().split("\n")
        for i, l in enumerate(lines):
            m = re.match(r"\s*<<set \$(\w+) to \"(\w+)\">>", l)
            if m and m.group(2) not in out:
                for j in range(i - 1, max(i - 4, -1), -1):
                    t = lines[j].strip()
                    if t.startswith("->"):
                        out[m.group(2)] = clean(re.sub(r"<<if .*?>>", "", t[2:]))
                        break
    return out


OPTLABEL = choice_labels()


# ---------- 条件写成人话 ----------
def human(cond):
    c = cond.strip()

    def qname(q):
        return SIDE.get(q) or TEXT.get(f"quest_{q}_name", q)

    rules = [
        (r'quest_part\((\d+)\) == (\d+)', lambda m: f"{m.group(2)} {BEAT.get(m.group(2), SIDE.get(m.group(1), ''))} 这一步" if m.group(1).startswith("1") else f"支线「{qname(m.group(1))}」第 {m.group(2)} 步"),
        (r'quest_part\((\d+)\) >= (\d+)', lambda m: f"{m.group(2)} {BEAT.get(m.group(2), '')} 以后"),
        (r'quest_state\((\d+)\) == "none"', lambda m: f"支线「{qname(m.group(1))}」还没接"),
        (r'quest_state\((\d+)\) == "active"', lambda m: f"支线「{qname(m.group(1))}」进行中"),
        (r'quest_state\((\d+)\) == "done"', lambda m: f"支线「{qname(m.group(1))}」做完了"),
        (r'quest_state\((\d+)\) != "active"', lambda m: f"支线「{qname(m.group(1))}」不在进行中"),
        (r'quest_state\((\d+)\) != "none"', lambda m: f"支线「{qname(m.group(1))}」接过了"),
        (r'not visited\("(\w+)"\)', lambda m: f"还没演过 {m.group(1)}"),
        (r'visited\("(\w+)"\)', lambda m: f"演过 {m.group(1)}"),
        (r'not has_unlock\("(\w+)"\)', lambda m: f"还没有 {TEXT.get('unlock_' + m.group(1) + '_name', m.group(1))}"),
        (r'has_unlock\("(\w+)"\)', lambda m: f"有 {TEXT.get('unlock_' + m.group(1) + '_name', m.group(1))}"),
        (r'\$c_(\w+) == "(\w+)"', lambda m: f"{PEOPLE.get(m.group(1), m.group(1))}{STATE.get(m.group(2), m.group(2))}"),
        (r'\$c_(\w+) != "(\w+)"', lambda m: f"{PEOPLE.get(m.group(1), m.group(1))}{NOT_STATE.get(m.group(2), '不是' + m.group(2))}"),
        (r'\$(\w+) == ""', lambda m: f"{m.group(1)} 还没定"),
        (r'\$(\w+) == "(\w+)"', lambda m: f"{m.group(1)} 选了 {m.group(2)}" + (f"「{CHOICE.get(m.group(2)) or OPTLABEL.get(m.group(2))}」" if (CHOICE.get(m.group(2)) or OPTLABEL.get(m.group(2))) else "")),
        (r'\$(\w+) != "(\w+)"', lambda m: f"{m.group(1)} 没选 {m.group(2)}"),
        (r'not \$(\w+)', lambda m: f"不是「{FLAG.get(m.group(1), m.group(1))}」"),
        (r'\$(\w+)', lambda m: FLAG.get(m.group(1), m.group(1))),
    ]
    for pat, fn in rules:
        c = re.sub(pat, fn, c)
    c = c.replace(" and ", "，并且").replace(" or ", "，或者").replace("not (", "并非（").replace("(", "（").replace(")", "）")
    return c


# ---------- 排版 ----------
class Parser:
    def __init__(self, lines):
        self.L = [(len(l) - len(l.lstrip(" ")), l.strip()) for l in lines
                  if l.strip() and not l.strip().startswith("//")]
        self.i = 0

    def block(self, indent):
        out = []
        while self.i < len(self.L):
            ind, t = self.L[self.i]
            if ind < indent or t.startswith(("<<elseif", "<<else>>", "<<endif>>")):
                break
            if t.startswith("<<if "):
                out.append(self.ifblock(ind))
            elif t.startswith("->"):
                out.append(self.options(ind))
            elif t.startswith("<<"):
                m = re.match(r"<<(\w+)\s*(.*?)>>", t)
                self.i += 1
                if m and m.group(1) not in SKIP_CMD:
                    out.append(("cmd", m.group(1), m.group(2).split()))
            else:
                self.i += 1
                t = clean(t)
                m = re.match(r"^([^\s:：<>\-][^\s:：]{0,10}): (.*)$", t)
                out.append(("say", m.group(1), m.group(2)) if m else ("nar", t))
        return out

    def ifblock(self, ind):
        branches = []
        cond = re.match(r"<<if (.*)>>", self.L[self.i][1]).group(1)
        self.i += 1
        while True:
            kids = self.block(ind + 1)
            branches.append((cond, kids))
            if self.i >= len(self.L):
                break
            t = self.L[self.i][1]
            if t.startswith("<<elseif"):
                cond = re.match(r"<<elseif (.*)>>", t).group(1)
                self.i += 1
            elif t.startswith("<<else>>"):
                cond = None
                self.i += 1
            else:          # <<endif>>
                self.i += 1
                break
        return ("if", branches)

    def options(self, ind):
        opts = []
        while self.i < len(self.L) and self.L[self.i][0] == ind and self.L[self.i][1].startswith("->"):
            t = self.L[self.i][1][2:].strip()
            key = "#key" in t
            m = re.search(r"<<if (.*?)>>\s*$", t)
            cond = m.group(1) if m else None
            text = clean(re.sub(r"<<if .*?>>\s*$", "", t))
            self.i += 1
            kids = self.block(ind + 1)
            opts.append((text, key, cond, kids))
        return ("opts", opts)


def render_cmd(name, args):
    label = CMD.get(name, name)
    a = " ".join(args)
    extra = ""
    if name == "vision":
        v = VISION.get(args[0], {})
        extra = (f'<div class="vis"><b>{esc(v.get("surface", ""))}里看见</b><p>{esc(TEXT.get(v.get("text", ""), ""))}</p></div>'
                 if v else "")
    elif name == "book_after" and len(args) >= 2:
        a = f"{args[0]}：{TEXT.get(args[1], args[1])}"
    elif name == "objective" and len(args) >= 2:
        a = TEXT.get(args[1], args[1])
    elif name == "progress_quest" and len(args) >= 2:
        a = f"{args[1]} 「{BEAT.get(args[1], '')}」" if args[0].startswith("1") else f"支线 {args[0]} 第 {args[1]} 步"
    elif name == "start_quest" and args:
        a = f"{args[0]} 「{TEXT.get('quest_' + args[0] + '_name', '')}」"
    elif name == "companion" and len(args) >= 2:
        a = f"{PEOPLE.get(args[0], args[0])} {STATE.get(args[1], args[1])}"
    elif name == "unlock" and args:
        a = TEXT.get(f"unlock_{args[0]}_name", args[0])
    elif name == "chapter" and args:
        a = f"第 {args[0]} 章"
    elif name == "jump" and args:
        return f'<span class="cmd c-jump"><b>{label}</b> <a href="#n-{esc(args[0])}">{esc(args[0])}</a></span>'
    return f'<span class="cmd c-{esc(name)}"><b>{esc(label)}</b> {esc(a)}</span>{extra}'


def render(items):
    out = []
    for it in items:
        kind = it[0]
        if kind == "say":
            out.append(f'<p class="say"><span class="who">{esc(it[1])}</span><span class="txt">{esc(it[2])}</span></p>')
        elif kind == "nar":
            out.append(f'<p class="nar">{esc(it[1])}</p>')
        elif kind == "cmd":
            out.append(render_cmd(it[1], it[2]))
        elif kind == "if":
            brs = []
            for cond, kids in it[1]:
                head = (f'<div class="cond">{esc(human(cond))} <code>{esc(cond)}</code></div>' if cond
                        else '<div class="cond">其余情况 </div>')
                body = render(kids) or '<p class="empty">（这一支没有台词）</p>'
                brs.append(f'<div class="br">{head}{body}</div>')
            out.append(f'<div class="if">{"".join(brs)}</div>')
        elif kind == "opts":
            lis = []
            for text, key, cond, kids in it[1]:
                badge = '<span class="badge">关键</span>' if key else ""
                oc = f'<span class="ocond">出现条件：{esc(human(cond))}</span>' if cond else ""
                lis.append(f'<li class="{"k" if key else ""}"><div class="opt">{badge}{esc(text)}{oc}</div>{render(kids)}</li>')
            out.append(f'<ol class="opts">{"".join(lis)}</ol>')
    return "".join(out)


def count(items):
    n = 0
    for it in items:
        if it[0] in ("say", "nar"):
            n += 1
        elif it[0] == "if":
            n += sum(count(k) for _, k in it[1])
        elif it[0] == "opts":
            n += sum(1 + count(k) for _, _, _, k in it[1])
    return n


def main():
    head = open(os.path.join(ROOT, "tools/script_page_head.html"), encoding="utf-8").read()
    sections, toc, total = [], [], 0
    for name in FILES:
        nodes = read_nodes(os.path.join(DLG, name + ".yarn"))
        title = f"第 {name[2:]} 章 · {TEXT.get('chapter_' + name[2:], '')}" if name.startswith("Ch") else "支线"
        arts, lines = [], 0
        for nd in nodes:
            when = []
            for l in nd["lines"]:
                s = l.strip()
                if not s:
                    continue
                if s.startswith("//"):
                    when.append(s[2:].strip())
                    continue
                break
            items = Parser(nd["lines"]).block(0)
            n = count(items)
            lines += n
            tags = "".join(f'<span class="tag">{esc(TAGS.get(t, t))}</span> ' for t in nd["tags"]).strip()
            whens = "".join(f'<p class="when">{esc(w)}</p>' for w in when)
            arts.append(f'<article class="node" id="n-{esc(nd["title"])}"><header><h3>{esc(nd["title"])}</h3>{tags}</header>'
                        f'{whens}<div class="body">{render(items)}</div></article>')
        total += lines
        toc.append(f'<a href="#s-{name}">{esc(title)}<small>{len(nodes)} 段 · {lines} 行</small></a>')
        sections.append(f'<section id="s-{name}"><h2>{esc(title)} <small>{name}.yarn · {len(nodes)} 段 · {lines} 行</small></h2>{"".join(arts)}</section>')
    lede = (f'<p class="lede">按 .yarn 排出来的剧本：名字牌是谁在说，没名字的是旁白；分支并排放，条件写成人话，灰字是原文。'
            f'共 {total} 行（台词、旁白、选项）。由 tools/render_script.py 生成。</p>')
    page = head + lede + f'\n<nav class="toc">{"".join(toc)}</nav>' + "".join(sections) + "</div></body></html>\n"
    open(OUT, "w", encoding="utf-8").write(page)
    print(f"script.html：{len(FILES)} 个文件，{total} 行")


if __name__ == "__main__":
    main()
