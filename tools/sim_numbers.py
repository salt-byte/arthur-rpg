#!/usr/bin/env python3
"""数值模拟（第 9 步「数值设计与模拟」草稿用）。

只读 content/data/*.json，不改游戏数据、不改代码。
1. 战斗规则照 scripts/battle.gd 和 design/systems/combat.md 逐条搬过来（伤害只有 hit_damage 一处）。
   代码里还没写、设计页写了的几样（同伴专属招、撑过几回合、首领的「？」、补位）照设计页补上。
2. 数值全从 content/data/*.json 读（2026-11-09 第 2–6 章落进 combat.json）；本文件只记每场仗的元信息（META）和走的顺序。
3. 三种打法走完六章：全力（全打、用药）、省资源（全打、不喝药、血一路带着、只在任务战前回圣龛）、
   只打必须的（只打任务战和剧情战，普通装备）。另在每场任务战上跑三种退化打法做检验。

用法：
  python3 tools/sim_numbers.py --validate      # 第 1–6 章按 main.gd --sim 的三种固定打法打，和 Godot 的输出对照
  python3 tools/sim_numbers.py                 # 跑全部，结果写进 production/qa/balance/
"""
import copy
import itertools
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "production", "qa", "balance")


def load(name):
    with open(os.path.join(ROOT, "content", "data", name + ".json"), encoding="utf-8") as f:
        return json.load(f)


CB = load("combat")
PR = load("progression")
IT = load("items")
RULES = CB["rules"]

META = {
    # 第 2–6 章每场仗的元信息：第几章、给人看的名字、必打 / 支线 / 另一条路线，模拟按谁上场（最弱的那一组，NUMBERS.md 5.1）。
    # 数值本身全在 content/data/combat.json。
    "ch2_north_road": {"ch": 2, "label": "北门外的叛军步兵", "party": ["kay", "arthur"]},
    "ch2_ford": {"ch": 2, "label": "渡口的盾兵", "party": ["kay", "arthur"]},
    "ch2_hill": {"ch": 2, "label": "山坡上的骑兵", "party": ["kay", "arthur"]},
    "ch2_camp": {"ch": 2, "label": "营地外的游骑", "party": ["kay", "arthur"]},
    "bedegraine": {"ch": 2, "label": "贝德格兰之战", "party": ["kay", "arthur"], "required": True},
    "pellinore": {"ch": 3, "label": "泉边的佩利诺", "party": ["arthur"], "required": True, "no_scabbard": True},
    "ch3_road_knight": {"ch": 3, "label": "往卡美洛路上的骑士", "party": ["kay", "arthur"]},
    "ch3_squires": {"ch": 3, "label": "两个侍从", "party": ["kay", "gawain"]},
    "ch3_wild_pair": {"ch": 3, "label": "林边的两个野人", "party": ["kay", "arthur"]},
    "ch3_knight_pair": {"ch": 3, "label": "比武场外的挑战者", "party": ["kay", "gawain"]},
    "wild_men": {"ch": 3, "label": "支线：北边的野人", "party": ["gawain"], "side": True},
    "morgan_chase": {"ch": 4, "label": "追摩根", "party": ["arthur", "kay"], "required": True},
    "red_knight": {"ch": 4, "label": "支线：红地的红骑士", "party": ["gawain", "gareth"], "side": True},
    "ch4_brigands": {"ch": 4, "label": "林中的强人", "party": ["kay", "gawain"]},
    "ch4_wolves": {"ch": 4, "label": "冬狼", "party": ["kay", "gawain"]},
    "ch4_riders": {"ch": 4, "label": "湖边的摩根骑士", "party": ["kay", "lancelot"]},
    "ch4_mixed": {"ch": 4, "label": "路边的强人和狼", "party": ["gawain", "lancelot"]},
    "camelot_defense": {"ch": 5, "label": "守卡美洛", "party": ["kay", "bedivere"], "required": True},
    "tournament": {"ch": 5, "label": "支线：比武", "party": ["bedivere", "kay"], "side": True},
    "ch5_deserters": {"ch": 5, "label": "城外的逃兵", "party": ["kay", "bedivere"]},
    "ch5_raiders": {"ch": 5, "label": "河边的强盗", "party": ["kay", "bedivere"]},
    "ch5_pair": {"ch": 5, "label": "两个强盗", "party": ["kay", "bedivere"]},
    "ch5_mixed": {"ch": 5, "label": "落单的骑士", "party": ["kay", "bedivere"]},
    "ch6_looters": {"ch": 6, "label": "欢乐堡外的抢掠兵", "party": ["arthur", "bedivere"]},
    "joyous_gard": {"ch": 6, "label": "攻欢乐堡城门", "party": ["arthur", "bedivere"], "required": True},
    "ch6_shore": {"ch": 6, "label": "海边的兵", "party": ["arthur", "bedivere"]},
    "dover": {"ch": 6, "label": "多佛登陆", "party": ["gawain", "arthur"], "required": True},
    "ch6_riders": {"ch": 6, "label": "路上的骑兵", "party": ["arthur", "bedivere"]},
    "ch6_camp": {"ch": 6, "label": "营外的斥候", "party": ["arthur", "bedivere"]},
    "camlann": {"ch": 6, "label": "卡姆兰", "party": ["arthur", "bedivere"], "required": True},
    "camlann_rear": {"ch": 6, "label": "卡姆兰后队（D5c）", "party": ["bedivere", "kay"], "alt": True},
}

PROPOSAL = {
    # 第 1 章沿用 combat.json 的遭遇；顺序是玩家碰上的顺序（全打路线）
    "route": {
        1: ["forest_wolves", "road_bandits", "oak_wolves", "log_wolves", "wolves", "merlin_shadow"],
        2: ["ch2_north_road", "ch2_ford", "ch2_hill", "ch2_camp", "bedegraine"],
        3: ["pellinore", "ch3_road_knight", "ch3_wild_pair", "ch3_squires", "ch3_knight_pair", "wild_men"],
        4: ["ch4_brigands", "ch4_wolves", "morgan_chase", "ch4_riders", "ch4_mixed", "red_knight"],
        5: ["ch5_deserters", "ch5_raiders", "camelot_defense", "ch5_pair", "ch5_mixed", "tournament"],
        6: ["ch6_looters", "joyous_gard", "ch6_shore", "dover", "ch6_riders", "ch6_camp", "camlann"],
    },
    # 主线做完给的经验：从 progression.json 读（第 3 章 2026-11-09 改成 50，NUMBERS.md G9）
    "quest_xp": PR["xp"]["quest_by_chapter"],
    # 「撑过几回合」的仗按上场敌人给经验（combat.md「需要的新字段」，NUMBERS.md G4）
    "survive_gives_xp": True,
}

CH1_ENCOUNTERS = {"forest_wolves": "林子边的狼", "road_bandits": "路上的强盗", "oak_wolves": "橡树边的狼",
                  "log_wolves": "倒木后的灰狼", "wolves": "头狼群", "merlin_shadow": "梅林的影子"}

TARGETS = {
    # 回合区间（含）和打完剩血比例区间（只打必须的、最优打法）；NUMBERS.md 第 2、6 节
    "map": (2, 3), "quest": (3, 5), "boss": (4, 5), "boss_hard": (5, 6),
}
HARD_BOSSES = {"red_knight", "camlann"}           # 原作里打得艰难的
HP_BAND = {1: (0.55, 0.85), 2: (0.45, 0.75), 3: (0.35, 0.65), 4: (0.25, 0.55), 5: (0.15, 0.45)}
CH_DIFF = {1: 1, 2: 2, 3: 3, 4: 2, 5: 4, 6: 5}


def enemy_def(eid):
    return CB["enemies"][eid]


def enc_def(eid):
    e = CB["encounters"][eid]
    pd = e.get("party", {})
    d = dict(e)
    d["win"] = e.get("win", {"type": "all_down"})
    if eid in META:
        m = META[eid]
        d.update({"ch": m["ch"], "label": m["label"], "party": list(m["party"])})
        for f in ("required", "side", "alt", "no_scabbard"):
            if m.get(f):
                d[f] = True
    else:
        d.update({"ch": 1, "label": CH1_ENCOUNTERS.get(eid, eid), "party": list(pd.get("fixed", []))})
        if e["kind"] in ("quest", "story"):
            d["required"] = True
    return d


def is_boss_fight(enc):
    return any(enemy_def(x).get("boss") for x in enc["enemies"])


# ---------------------------------------------------------------------------
# 战斗（照 scripts/battle.gd）
# ---------------------------------------------------------------------------
def hit_damage(base, src, t):
    d = float(base + int(src.get("strength", 0)))
    if int(src.get("weak", 0)) > 0:
        d *= RULES["weak_mult"]
    if int(t.get("vulnerable", 0)) > 0:
        d *= RULES["vulnerable_mult"]
    return max(0, math.floor(d + 1e-6))


def absorb(t, dealt):
    b = min(t["block"], dealt)
    t["block"] -= b
    return b, dealt - b


class Battle:
    def __init__(self, enc_id, ctx, chapter):
        self.enc_id = enc_id
        self.enc = enc_def(enc_id)
        self.ctx = ctx
        self.chapter = chapter
        self.units = []
        self.turn = 0
        self.queue = []
        self.intents = []
        self.result = ""
        self.killed = []
        self.cover = False
        self.stand_used = False
        self.reserve = list(self.enc.get("reserve", []))
        self.field_max = int(self.enc.get("field_max", 0))
        self.potions_used = 0
        self.mana_spent = 0
        self.spells_cast = 0
        self.revealed = False
        self.takeover = False
        self.log = []
        for a in ctx["allies"]:
            u = self._unit(a["uid"], "ally", a["name"], a["max"], a["power"])
            u["hp"] = max(1, min(a["hp"], a["max"]))
            u["move"] = a.get("move", "")
            u["uses"] = int(a.get("uses", 0))
            self.units.append(u)
        for e in self.enc["enemies"]:
            self._add_enemy(e, False)
        self.mana_max = ctx["mana_max"]
        self.mana = self.mana_max
        self.potions = dict(ctx.get("potions", {}))
        st = ctx.get("start", {})
        if st.get("all_enemies_vulnerable", 0) > 0:
            for e in self.enemies():
                e["vulnerable"] += st["all_enemies_vulnerable"]
        if st.get("top_hp_vulnerable", 0) > 0 and self.enemies():
            top = self.enemies()[0]
            for e in self.enemies():
                if e["hp"] > top["hp"]:
                    top = e
            top["vulnerable"] += st["top_hp_vulnerable"]
        g = self.unit("gawain")
        if g is not None and g.get("move") == "noon_strength":
            g["strength"] += CB["companions"]["gawain"]["noon_strength"]
        self.begin_turn()

    def clone(self):
        c = copy.copy(self)
        c.units = [dict(u) for u in self.units]
        c.intents = [dict(i) for i in self.intents]
        c.queue = list(self.queue)
        c.killed = list(self.killed)
        c.reserve = list(self.reserve)
        c.potions = dict(self.potions)
        c.log = []
        return c

    def _unit(self, uid, side, name, hp, power):
        return {"uid": uid, "id": uid, "side": side, "name": name, "hp": hp, "max": hp, "power": power, "alive": True,
                "block": 0, "strength": 0, "weak": 0, "vulnerable": 0, "pattern": [], "ptr": 0, "pending": None,
                "kind": "", "boss": False, "summoned": False, "guarded_last": False, "guarded_now": False}

    def _add_enemy(self, eid, summoned):
        ed = enemy_def(eid)
        uid = eid
        k = 1
        while self.unit(uid) is not None:
            k += 1
            uid = "%s#%d" % (eid, k)
        u = self._unit(uid, "enemy", ed.get("name", eid), int(ed["hp"]), 0)
        u["id"] = eid
        u["pattern"] = ed["pattern"]
        u["kind"] = ed.get("kind", "")
        u["boss"] = bool(ed.get("boss", False))
        u["summoned"] = summoned
        self.units.append(u)
        return u

    def unit(self, uid):
        for u in self.units:
            if u["uid"] == uid:
                return u
        return None

    def allies(self, alive_only=True):
        return [u for u in self.units if u["side"] == "ally" and (u["alive"] or not alive_only)]

    def enemies(self, alive_only=True):
        return [u for u in self.units if u["side"] == "enemy" and (u["alive"] or not alive_only)]

    def intent_of(self, uid):
        for it in self.intents:
            if it["uid"] == uid:
                return it
        return None

    # ---- 意图 ----
    def begin_turn(self):
        self.turn += 1
        self.intents = []
        self.cover = False
        for u in self.allies(False):
            u["block"] = 0
            u["guarded_last"] = u["guarded_now"]
            u["guarded_now"] = False
        if self.turn == 4:
            g = self.unit("gawain")
            if g is not None and g.get("move") == "noon_strength":
                g["strength"] -= CB["companions"]["gawain"]["noon_strength"]
        if self.turn >= int(CB.get("mana_regen_from_turn", 2)):
            self.mana = min(self.mana_max, self.mana + self.ctx["mana_regen"])
        if self.turn == 1 and self.ctx.get("start", {}).get("apprentice_block", 0) > 0:
            ap = self.unit("apprentice")
            if ap:
                ap["block"] += self.ctx["start"]["apprentice_block"]
        # 越打越强（红骑士）：前几回合每回合开头力量 +N，和高文的正午之力对称
        for e in self.enemies():
            rise = enemy_def(e["id"]).get("rise")
            if rise and self.turn <= int(rise["turns"]):
                e["strength"] += int(rise["strength"])
        # 补位（比武：场上最多 field_max 个，倒一个下回合补一个）
        if self.field_max and self.reserve and len(self.enemies()) < self.field_max:
            self._add_enemy(self.reserve.pop(0), False)
        order = 1
        for e in self.enemies():
            it = self._make_intent(e)
            it["order"] = order
            order += 1
            self.intents.append(it)
        self.revealed = not any(it.get("hidden") for it in self.intents)

    def _make_intent(self, e):
        release = False
        if e["pending"] is not None:
            src = e["pending"]
            e["pending"] = None
            release = True
        else:
            src = e["pattern"][e["ptr"] % len(e["pattern"])]
            e["ptr"] += 1
        it = {"uid": e["uid"], "order": 0, "act": src.get("act", "attack"), "power": int(src.get("power", 0)),
              "hits": max(1, int(src.get("hits", 1))), "target": "", "then": src.get("then"), "then_target": "",
              "what": src.get("what", ""), "count": int(src.get("count", 0)), "strength": int(src.get("strength", 0)),
              "who": src.get("who", "same_kind"), "stacks": int(src.get("stacks", 0)), "block": int(src.get("block", 0)),
              "cancelled": False, "release": release, "lethal": bool(src.get("lethal", False)),
              "hidden": bool(src.get("hidden", False)) and not release, "done": False}
        if it["act"] in ("attack", "weak"):
            it["target"] = self._resolve(src.get("target", "lowest_hp"))
        elif it["act"] == "charge" and it["then"] is not None:
            it["then_target"] = self._resolve(it["then"].get("target", "lowest_hp"))
        return it

    def _resolve(self, t):
        if t == "all":
            return "all"
        if t == "lowest_hp":
            return self._lowest()
        u = self.unit(t)
        if u is not None and u["alive"] and u["side"] == "ally":
            return t
        return self._lowest()

    def _lowest(self):
        best = None
        for a in self.allies():
            if best is None or a["hp"] < best["hp"]:
                best = a
        return best["uid"] if best else ""

    def intent_damage(self, it, target_uid=""):
        e = self.unit(it["uid"])
        t = self.unit(target_uid or it["target"])
        if e is None:
            return 0
        power = it["power"]
        lethal = it.get("lethal", False)
        if it["act"] == "charge" and it["then"] is not None:
            power = int(it["then"].get("power", 0))
            lethal = bool(it["then"].get("lethal", False))
            if t is None:
                t = self.unit(it["then_target"])
        if lethal and t is not None:
            return t["hp"] + t["block"]
        extra = 0
        for o in self.intents:
            if o is it or o["order"] >= it["order"] or o["act"] != "buff" or o["cancelled"] or o["done"]:
                continue
            oe = self.unit(o["uid"])
            if oe and oe["alive"] and ((o["who"] == "same_kind" and oe["kind"] == e["kind"]) or (o["who"] == "self" and oe is e)):
                extra += o["strength"]
        src = dict(e)
        src["strength"] = e["strength"] + extra
        return hit_damage(power, src, t if t is not None else {"vulnerable": 0})

    # ---- 行动 ----
    def spells(self):
        return self.ctx["spells"]

    def interruptible(self):
        out = []
        for it in self.intents:
            e = self.unit(it["uid"])
            if e and e["alive"] and not it["cancelled"] and it["act"] in ("charge", "summon", "buff"):
                if it.get("hidden") and not self.revealed:
                    continue
                out.append(it["uid"])
        return out

    def options(self, uid, allow_potions=True):
        """这个人这回合能排的行动：[(act, target)]"""
        u = self.unit(uid)
        if u is None or not u["alive"]:
            return []
        opts = []
        es = [e["uid"] for e in self.enemies()]
        if uid == "apprentice":
            for s, sp in self.spells().items():
                if sp.get("free_action"):
                    continue
                if s == "interrupt":
                    for t in self.interruptible():
                        opts.append((s, t))
                elif s in ("spark", "blind"):
                    for t in es:
                        opts.append((s, t))
                elif s == "twin_spark":
                    if len(es) >= 2:
                        for t in es:
                            opts.append((s, t))
                elif s == "ward":
                    for a in self.allies():
                        opts.append((s, a["uid"]))
                elif s in ("focus", "fire_rain", "haze"):
                    opts.append((s, ""))
            if allow_potions and self.potions.get("potion_mana", 0) > 0 and self.mana <= 2:
                opts.append(("potion_mana", ""))
        else:
            for t in es:
                opts.append(("attack", t))
            opts.append(("guard", ""))
            mv = u.get("move")
            if mv == "kay_cover" and self.ctx.get("kay_cover"):
                opts.append(("kay_cover", ""))
            if mv == "double_strike" and len(es) >= 2:
                for t in es:
                    opts.append(("double_strike", t))
            if mv == "bandage" and u["uses"] > 0:
                for a in self.allies():
                    if a["max"] - a["hp"] >= 3:
                        opts.append(("bandage", a["uid"]))
        if allow_potions and self.potions.get("potion_hp", 0) > 0:
            heal = self.ctx.get("potion_heal", 6)
            for a in self.allies():
                if a["max"] - a["hp"] >= heal:
                    opts.append(("potion_hp", a["uid"]))
        return opts

    def cost(self, act):
        sp = self.spells().get(act)
        return int(sp.get("mana", 0)) if sp else 0

    def end_turn(self):
        if self.result:
            return
        q = list(self.queue)
        self.queue = []
        for a in q:
            if self.result:
                break
            self._do(a)
        for u in self.allies(False):
            self._tick(u)
        for it in self.intents:
            if self.result:
                break
            self._enemy_act(it)
        if self.result:
            return
        for u in self.enemies(False):
            self._tick(u)
        w = self.enc.get("win", {"type": "all_down"})
        if w.get("type") == "survive" and self.turn >= int(w.get("turns", 3)):
            self.result = "win"
            return
        self.begin_turn()

    def _tick(self, u):
        u["weak"] = max(0, u["weak"] - 1)
        u["vulnerable"] = max(0, u["vulnerable"] - 1)

    def _enemy_target(self, uid):
        t = self.unit(uid)
        if t is not None and t["alive"] and t["side"] == "enemy":
            return t
        es = self.enemies()
        return es[0] if es else None

    def _hit(self, src, t, base):
        dealt = hit_damage(base, src, t)
        b, d = absorb(t, dealt)
        t["hp"] = max(0, t["hp"] - d)
        return d

    def _do(self, a):
        u = self.unit(a["who"])
        if u is None or not u["alive"]:
            return
        act = a["act"]
        sp = self.spells().get(act) if u["uid"] == "apprentice" else None
        if sp is not None:
            if self.cost(act) > self.mana:
                return
            self.mana -= self.cost(act)
            self.mana_spent += self.cost(act)
            if act != "focus":
                self.spells_cast += 1
            if act == "spark":
                t = self._enemy_target(a["target"])
                if t is None:
                    return
                self._hit(u, t, int(sp["damage"]))
                if t["hp"] > 0:
                    t["vulnerable"] += int(sp.get("vulnerable", 1))
                self._check_enemy_down(t)
            elif act == "twin_spark":
                first = self._enemy_target(a["target"])
                lst = [first] if first else []
                for e in self.enemies():
                    if len(lst) >= int(sp.get("targets", 2)):
                        break
                    if e not in lst:
                        lst.append(e)
                for t in lst:
                    self._hit(u, t, int(sp["damage"]))
                    self._check_enemy_down(t)
            elif act == "fire_rain":
                for t in self.enemies():
                    self._hit(u, t, int(sp["damage"]))
                    self._check_enemy_down(t)
            elif act == "blind":
                t = self._enemy_target(a["target"])
                if t:
                    t["weak"] += int(sp["weak"])
            elif act == "haze":
                for t in self.enemies():
                    t["weak"] += int(sp["weak"])
            elif act == "ward":
                tg = self.unit(a["target"])
                lst = [tg] if tg is not None and tg["alive"] else [u]
                if int(sp.get("targets", 1)) > 1:
                    for x in self.allies():
                        if len(lst) >= int(sp["targets"]):
                            break
                        if x not in lst:
                            lst.append(x)
                for t in lst:
                    t["block"] += int(sp["block"])
            elif act == "focus":
                self.mana = min(self.mana_max, self.mana + int(sp.get("restore_mana", 2)))
            elif act == "interrupt":
                it = self.intent_of(a["target"])
                t = self.unit(a["target"])
                if it is None or t is None or not t["alive"] or it["cancelled"]:
                    return
                it["cancelled"] = True
                if self.ctx.get("start", {}).get("interrupt_vulnerable", 0) > 0:
                    t["vulnerable"] += self.ctx["start"]["interrupt_vulnerable"]
            return
        if act == "attack":
            t = self._enemy_target(a["target"])
            if t is None:
                return
            base = u["power"]
            if u.get("move") == "riposte" and u["guarded_last"]:
                base *= int(CB["companions"]["gareth"]["riposte_mult"])
            self._hit(u, t, base)
            self._check_enemy_down(t)
        elif act == "double_strike":
            first = self._enemy_target(a["target"])
            lst = [first] if first else []
            for e in self.enemies():
                if len(lst) >= 2:
                    break
                if e not in lst:
                    lst.append(e)
            for t in lst:
                self._hit(u, t, int(CB["companions"]["lancelot"]["double_strike_damage"]))
                self._check_enemy_down(t)
        elif act == "guard":
            u["block"] += self.ctx["guard_block"]
            u["guarded_now"] = True
        elif act == "kay_cover":
            self.cover = True
            u["block"] += int(CB["kay_cover_block"])
        elif act == "bandage":
            t = self.unit(a["target"])
            if t is None or not t["alive"] or u["uses"] <= 0:
                return
            u["uses"] -= 1
            t["hp"] = min(t["max"], t["hp"] + int(CB["companions"]["bedivere"]["bandage_heal"]))
        elif act == "potion_hp":
            if self.potions.get("potion_hp", 0) <= 0:
                return
            t = self.unit(a["target"])
            if t is None or not t["alive"]:
                t = u
            self.potions["potion_hp"] -= 1
            self.potions_used += 1
            t["hp"] = min(t["max"], t["hp"] + self.ctx.get("potion_heal", 6))
        elif act == "potion_mana":
            if self.potions.get("potion_mana", 0) <= 0:
                return
            self.potions["potion_mana"] -= 1
            self.potions_used += 1
            self.mana = min(self.mana_max, self.mana + self.ctx.get("potion_mana", 3))

    def _check_enemy_down(self, t):
        if t["hp"] > 0 or not t["alive"]:
            return
        t["alive"] = False
        if not t["summoned"]:
            self.killed.append(t["id"])
        it = self.intent_of(t["uid"])
        if it is not None:
            it["cancelled"] = True
        if not self.enemies() and not self.reserve:
            self.result = "win"

    def _enemy_act(self, it):
        e = self.unit(it["uid"])
        if e is None or not e["alive"]:
            return
        it["done"] = True
        e["block"] = 0
        if it["cancelled"]:
            return
        act = it["act"]
        if act == "attack":
            if it["target"] == "all":
                for a in self.allies():
                    if self.result:
                        break
                    self._enemy_hit(e, a["uid"], it, False)
            else:
                for _ in range(it["hits"]):
                    if self.result:
                        break
                    self._enemy_hit(e, it["target"], it, True)
        elif act == "charge":
            th = dict(it["then"])
            th["target"] = it["then_target"] if th.get("target") != "all" else "all"
            e["pending"] = th
        elif act == "summon":
            room = int(CB["enemy_cap"]) - len(self.enemies())
            for _ in range(min(it["count"], room)):
                self._add_enemy(it["what"], True)
        elif act == "buff":
            if it["who"] == "self":
                e["strength"] += it["strength"]
            else:
                for x in self.enemies():
                    if x["kind"] == e["kind"]:
                        x["strength"] += it["strength"]
        elif act == "weak":
            t = self.unit(it["target"])
            if t is None or not t["alive"]:
                t = self.unit(self._lowest())
            if t is None:
                return
            t["weak"] += it["stacks"]
        elif act == "block":
            e["block"] += it["block"]

    def _enemy_hit(self, e, target_uid, it, single):
        t = self.unit(target_uid)
        if t is None or not t["alive"]:
            t = self.unit(self._lowest())
            if t is None:
                return
        kay = self.unit("kay")
        if single and self.cover and t["uid"] != "kay" and kay is not None and kay["alive"]:
            t = kay
        if it.get("lethal"):
            t["block"] = 0
            t["hp"] = 0
        else:
            self._hit(e, t, it["power"])
        if t["uid"] == "arthur" and t["hp"] == 0 and self.ctx.get("scabbard"):
            t["hp"] = 1
        if t["hp"] == 0 and t["alive"] and self.ctx.get("start", {}).get("stand", 0) > 0 and not self.stand_used:
            self.stand_used = True
            t["hp"] = 1
        if t["hp"] == 0 and t["alive"]:
            t["alive"] = False
            if self.enc.get("end_if_down") == t["uid"]:
                self.result = "win"          # 剧情接管（佩利诺：亚瑟倒下也算撑过）
                self.takeover = True
            elif not self.allies():
                self.result = "lose"


# ---------------------------------------------------------------------------
# 打法
# ---------------------------------------------------------------------------
def godot_plan(b, strat):
    """照 main.gd 的 _sim_plan 一字一句搬：always_first / smart / no_magic"""
    es = b.enemies()
    low = es[0]
    threat = None
    for e in es:
        if e["hp"] < low["hp"]:
            low = e
        it = b.intent_of(e["uid"])
        if it is not None and it["act"] in ("summon", "buff") and threat is None:
            threat = e
    tgt = es[0] if strat == "always_first" else (threat if threat is not None else low)
    q = []
    if strat != "no_magic" and "spark" in b.spells() and b.cost("spark") <= b.mana:
        q.append({"who": "apprentice", "act": "spark", "target": tgt["uid"]})
    else:
        q.append({"who": "apprentice", "act": "focus", "target": ""})
    for a in b.allies():
        c = a["uid"]
        if c == "apprentice":
            continue
        if strat == "smart":
            incoming = 0
            for it in b.intents:
                if it["act"] == "attack" and it["target"] == c:
                    incoming += b.intent_damage(it) * it["hits"]
            if incoming >= 4 and a["hp"] <= incoming + 3:
                q.append({"who": c, "act": "guard", "target": ""})
                continue
        q.append({"who": c, "act": "attack", "target": tgt["uid"]})
    order = [u["uid"] for u in b.allies(False)]
    q.sort(key=lambda x: order.index(x["who"]))
    b.queue = q


def threat_of(b):
    """下一回合亮出来的意图一共能打掉多少（粗算，给最优打法评分用）"""
    n_allies = max(1, len(b.allies()))
    s = 0.0
    for it in b.intents:
        e = b.unit(it["uid"])
        if e is None or not e["alive"] or it["cancelled"]:
            continue
        if it.get("hidden") and not b.revealed:
            s += 5
            continue
        a = it["act"]
        if a == "attack":
            d = b.intent_damage(it, b.allies()[0]["uid"] if it["target"] == "all" and b.allies() else "")
            s += d * (n_allies if it["target"] == "all" else it["hits"])
        elif a == "charge":
            th = it["then"]
            d = hit_damage(int(th.get("power", 0)), e, {"vulnerable": 0})
            s += 0.8 * d * (n_allies if th.get("target") == "all" else 1)
        elif a == "summon":
            s += it["count"] * enemy_def(it["what"])["hp"] * 0.8
        elif a == "buff":
            n = 1 if it["who"] == "self" else len([x for x in b.enemies() if x["kind"] == e["kind"]])
            s += it["strength"] * n * 3
        elif a == "weak":
            s += it["stacks"] * 1.5
    for e in b.enemies():
        if e["pending"] is not None:
            th = e["pending"]
            d = hit_damage(int(th.get("power", 0)), e, {"vulnerable": 0})
            s += d * (n_allies if th.get("target") == "all" else 1)
    return s


def evaluate(b, survive):
    if b.result == "win":
        return 1e6 + 10 * sum(a["hp"] for a in b.allies()) - 1000 * b.turn
    if b.result == "lose":
        return -1e6
    ally = sum(a["hp"] for a in b.allies()) - 14 * len([a for a in b.allies(False) if not a["alive"]])
    enemy_hp = sum(e["hp"] for e in b.enemies()) + 0.5 * sum(e["block"] for e in b.enemies()) + \
        sum(enemy_def(x)["hp"] for x in b.reserve)
    strength = sum(e["strength"] for e in b.enemies())
    th = threat_of(b)
    w_enemy = 0.4 if survive else 1.3
    return (1.0 * ally - w_enemy * enemy_hp - 3 * strength - 4 * len(b.enemies()) - 0.6 * th
            + 0.7 * b.mana - 4 * b.potions_used)


def smart_plan(b, allow_potions, survive=False):
    """最优打法：把三个人这回合能排的组合全试一遍（战斗是确定的，试算 = 真打），挑评分最高的"""
    if not b.revealed and "reveal" in b.spells() and b.mana >= b.cost("reveal"):
        b.mana -= b.cost("reveal")          # 揭开：不占招，1 法力
        b.mana_spent += b.cost("reveal")
        b.revealed = True
    actors = [a["uid"] for a in b.allies()]
    opts = [b.options(u, allow_potions) for u in actors]
    best, best_q = None, None
    for combo in itertools.product(*opts):
        mana_need = sum(b.cost(act) for (act, _) in combo if act in b.spells())
        if mana_need > b.mana:
            continue
        hp_pots = sum(1 for (act, _) in combo if act == "potion_hp")
        if hp_pots > b.potions.get("potion_hp", 0):
            continue
        q = [{"who": u, "act": act, "target": t} for u, (act, t) in zip(actors, combo)]
        c = b.clone()
        if not b.revealed:          # 没揭开的「？」：试算时当它不出手
            for it in c.intents:
                if it.get("hidden"):
                    it["cancelled"] = True
        c.queue = q
        c.end_turn()
        s = evaluate(c, survive)
        if best is None or s > best:
            best, best_q = s, q
    b.queue = best_q or []


def fight(enc_id, ctx, chapter, policy, allow_potions=False, max_turns=20):
    b = Battle(enc_id, ctx, chapter)
    survive = b.enc.get("win", {}).get("type") == "survive"
    while not b.result and b.turn <= max_turns:
        if policy == "smart":
            smart_plan(b, allow_potions, survive)
        elif policy == "smart_simple":
            godot_plan(b, "smart")
        else:
            godot_plan(b, policy)
        b.end_turn()
    if not b.result:
        b.result = "timeout"
    return b


# ---------------------------------------------------------------------------
# 成长：等级、技能点、装备、随机奖励
# ---------------------------------------------------------------------------
NODES = PR["skill_tree"]["nodes"]
TREE_ORDER = ["spark", "water", "ward", "trick"]


def level_for(xp):
    lv = 1
    while lv < PR["progression"]["max_level"] and (lv + 1) ** 3 <= xp:
        lv += 1
    return lv


def build_ranks(level, plan):
    """按加点顺序把点数花下去：暗黑 2 规则（要上一格至少 1 点；超过需求等级几级才能多点几点）"""
    pts = 2 * (level - 1)
    ranks = {k: 0 for k in NODES}
    progress = True
    while pts > 0 and progress:
        progress = False
        for nid in plan(ranks, level):
            n = NODES[nid]
            if ranks[nid] >= n["max_rank"] or level < n["level_req"]:
                continue
            if ranks[nid] + 1 > 1 + (level - n["level_req"]):
                continue
            if any(ranks[r] < 1 for r in n.get("requires", [])):
                continue
            ranks[nid] += 1
            pts -= 1
            progress = True
            break
    return ranks


def plan_balanced(ranks, level):
    """四棵树轮着点：每次挑点数最少的那棵树里能点的第一格（progression 页「四棵树平均点」）"""
    by_tree = {t: [k for k, v in NODES.items() if v["tree"] == t] for t in TREE_ORDER}
    spent = {t: sum(ranks[k] for k in by_tree[t]) for t in TREE_ORDER}
    order = sorted(TREE_ORDER, key=lambda t: (spent[t], TREE_ORDER.index(t)))
    out = []
    for t in order:
        out.extend(by_tree[t])
    return out


def plan_spark(ranks, level):
    """全点星火（退化打法检验）：星火树点满再点水面"""
    return [k for k in NODES if NODES[k]["tree"] == "spark"] + [k for k in NODES if NODES[k]["tree"] == "water"] + \
           [k for k in NODES if NODES[k]["tree"] == "ward"] + [k for k in NODES if NODES[k]["tree"] == "trick"]


# 装备：每章开打时身上的三件（NUMBERS.md 3.4）。stats 是加成合计
GEAR = {
    "must": {   # 只打必须的：首领必掉的和剧情给的，全按普通算
        1: {},
        2: {"hp": 2},                                   # 头狼掉的粗布斗篷
        3: {"hp": 2, "spark": 1},                       # + 伦敦买的橡木杖（30 银）
        4: {"hp": 4, "mana_max": 2, "spark": 2, "focus": 1},          # 佩利诺掉的羊皮袄；梅林的杖（星火 +2，2026-11-09）
        5: {"hp": 4, "mana_max": 2, "spark": 2, "focus": 1, "ward": 1},  # + 护卫队长掉的银十字
        6: {"hp": 6, "mana_max": 2, "spark": 2, "focus": 1, "ward": 1},  # 镶边斗篷（守城后买）
    },
    "all": {    # 全打：每章约 4 件掉落，挑得出一件带一条词缀的
        1: {},
        2: {"hp": 4, "spark": 2, "mana_max": 1},        # 灼热的橡木杖、结实的粗布斗篷、河石护符
        3: {"hp": 4, "spark": 2, "mana_max": 2, "start_block": 3},  # 斗篷换成「·守夜」，护符「深水的」
        4: {"hp": 8, "spark": 2, "mana_max": 3, "focus": 1, "ward": 1},   # 梅林的杖；厚重的羊皮袄；深水的银十字
        5: {"hp": 10, "spark": 2, "mana_max": 3, "focus": 2, "ward": 1, "after_heal": 2},  # 镶边斗篷·回春；鹿角坠
        6: {"hp": 10, "spark": 4, "mana_max": 1, "focus": 1, "ward": 1, "after_heal": 2},  # 炽烈的冬青杖（星火 +4）换下梅林的杖，少了杖的法力 +2、凝神 +1
    },
}

# 随机奖励：每升一级按这个顺序挑（只挑眼下在队里的人的那两张；NUMBERS.md 3.5 的假设）
BOON_CYCLE = ["sharpen", "potion_bag", "well_fed", "iron_shield", "sharpen", "potion_bag", "sleep_on_it", "sharpen", "potion_bag"]


class Profile:
    def __init__(self, style):
        self.style = style            # full / save / must
        self.xp = 0
        self.level = 1
        self.boons = {}               # (id, who) -> n
        self.potions = {"potion_hp": 2 if style == "full" else 0, "potion_mana": 0}
        self.silver = 0
        self.hp = {}
        self.extra_points = 0
        self.levels_log = []

    def boon(self, bid, who=""):
        return self.boons.get((bid, who), 0)

    def gain_xp(self, n, chapter, party_ids):
        before = self.level
        self.xp += n
        self.level = level_for(self.xp)
        for lv in range(before + 1, self.level + 1):
            self.pick_boon(lv, chapter, party_ids)
        return self.level - before

    def pick_boon(self, lv, chapter, party_ids):
        bid = BOON_CYCLE[(lv - 2) % len(BOON_CYCLE)]
        comps = [c for c in party_ids if c != "apprentice"]
        if bid == "sharpen":
            for c in comps:
                if self.boon("sharpen", c) < 3:
                    self.boons[("sharpen", c)] = self.boon("sharpen", c) + 1
                    return
            bid = "potion_bag"
        if bid == "well_fed":
            for c in comps:
                if self.boon("well_fed", c) < 2:
                    self.boons[("well_fed", c)] = self.boon("well_fed", c) + 1
                    return
            bid = "potion_bag"
        if bid == "iron_shield" and self.boon("iron_shield") < 2:
            self.boons[("iron_shield", "")] = self.boon("iron_shield") + 1
            return
        if bid == "sleep_on_it" and self.boon("sleep_on_it") < 2 and lv >= 3:
            self.boons[("sleep_on_it", "")] = self.boon("sleep_on_it") + 1
            return
        if self.style == "full":
            self.potions["potion_hp"] = min(5, self.potions["potion_hp"] + 2)
        else:
            self.silver += 20 * chapter


def comp_stats(cid, chapter, prof):
    if chapter == 1:
        base = CB["companions"][cid]
        if "by_chapter" in base:
            hp, pw = base["by_chapter"]["1"]["hp"], base["by_chapter"]["1"]["power"]
        else:
            hp, pw = base["hp"], base["power"]
    else:
        bc = CB["companions"][cid]["by_chapter"]
        keys = [int(k) for k in bc if int(k) <= chapter] or [min(int(k) for k in bc)]
        st = bc[str(max(keys))]
        hp, pw = st["hp"], st["power"]
    return hp + 3 * prof.boon("well_fed", cid), pw + prof.boon("sharpen", cid)


def make_ctx(prof, enc_id, chapter, build="balanced", gear_route=None, unlocks=None):
    enc = enc_def(enc_id)
    route = gear_route or ("must" if prof.style == "must" else "all")
    gear = GEAR[route][chapter]
    plan = plan_spark if build == "spark" else plan_balanced
    lv_for_points = prof.level + (prof.boon("sleep_on_it") + 1) // 2  # 「多想了一夜」+1 点：粗算成半级
    ranks = build_ranks(min(10, lv_for_points), plan) if prof.level > 1 else {k: 0 for k in NODES}

    def node_sum(key, spell=None):
        s = 0
        for k, n in NODES.items():
            ef = n["effect"]
            if key not in ef:
                continue
            if spell is not None and ef.get("spell") != spell:
                continue
            if spell is None and "spell" in ef:
                continue
            s += int(ef[key]) * ranks[k]
        return s

    base = CB["spells"]
    have = ["spark", "ward", "focus"]
    if chapter >= 2 or enc_id == "merlin_shadow":     # 打断是第 1 章梅林说出秘密以后教的，头狼群时还不会
        have.append("interrupt")
    if chapter >= 4:
        have.append("reveal")
    if unlocks:
        have.extend(unlocks)
    sp = {}
    for s in have:
        d = dict(base[s])
        if s == "spark":
            d["damage"] = d["damage"] + node_sum("damage", "spark") + gear.get("spark", 0)
            d["vulnerable"] = d.get("vulnerable", 1) + node_sum("vulnerable", "spark")
        elif s == "ward":
            d["block"] = d["block"] + node_sum("block", "ward") + gear.get("ward", 0)
            d["targets"] = 2 if ranks["ward_twin"] > 0 else 1
        elif s == "focus":
            d["restore_mana"] = d.get("restore_mana", 2) + node_sum("restore_mana", "focus") + gear.get("focus", 0)
        elif s == "interrupt":
            d["mana"] = max(0, d["mana"] + node_sum("mana", "interrupt"))
        sp[s] = d
    for k, n in NODES.items():
        ef = n["effect"]
        if "new_spell" not in ef or ranks[k] <= 0:
            continue
        d = {"mana": int(ef.get("mana", 1))}
        if ef["new_spell"] == "twin_spark":
            d["damage"] = sp["spark"]["damage"]
            d["targets"] = 2
        elif ef["new_spell"] == "fire_rain":
            d["damage"] = int(ef.get("damage", 2))
        else:
            d["weak"] = int(ef.get("weak", 1))
        sp[ef["new_spell"]] = d
    ap_max = CB["apprentice"]["hp"] + node_sum("apprentice_hp") + gear.get("hp", 0)
    allies = [{"uid": "apprentice", "name": "你", "max": ap_max, "hp": prof.hp.get("apprentice", ap_max), "power": 0}]
    moves = {"kay": "kay_cover", "arthur": "scabbard", "gawain": "noon_strength", "lancelot": "double_strike",
             "gareth": "riposte", "bedivere": "bandage"}
    party = enc["party"]
    for cid in party:
        mh, pw = comp_stats(cid, chapter, prof)
        allies.append({"uid": cid, "name": cid, "max": mh, "hp": prof.hp.get(cid, mh), "power": pw,
                       "move": moves.get(cid, "") if chapter >= 3 or cid == "kay" else "",
                       "uses": CB["companions"]["bedivere"]["bandage_uses"] if cid == "bedivere" else 0})
    scabbard = chapter == 3 and "arthur" in party and not enc.get("no_scabbard")
    ctx = {"allies": allies, "spells": sp, "mana_max": CB["mana_max"] + node_sum("mana_max") + gear.get("mana_max", 0),
           "mana_regen": CB["mana_regen"] + node_sum("mana_regen"),
           "guard_block": CB["guard_block"] + 2 * prof.boon("iron_shield"),
           "potions": dict(prof.potions), "potion_heal": IT["potions"]["potion_hp"]["heal"] if chapter < 4 else IT["potions"]["potion_hp_big"]["heal"],
           "potion_mana": IT["potions"]["potion_mana"]["restore_mana"], "scabbard": scabbard, "kay_cover": False,
           "start": {"all_enemies_vulnerable": node_sum("battle_start_all_enemies_vulnerable"),
                     "top_hp_vulnerable": gear.get("start_vuln", 0), "apprentice_block": gear.get("start_block", 0),
                     "interrupt_vulnerable": node_sum("on_interrupt_vulnerable"),
                     "stand": node_sum("once_per_battle_survive_at")},
           "_ranks": ranks, "_gear": gear}
    return ctx


def xp_of(killed, chapter_of):
    per = PR["xp"]["per_enemy_by_chapter"]
    s = 0
    for eid in killed:
        ed = enemy_def(eid)
        n = per[min(5, int(ed.get("chapter", 1)) - 1)]
        if ed.get("boss"):
            n *= PR["xp"]["boss_mult"]
        s += n
    return s


# ---------------------------------------------------------------------------
# 跑一条路线
# ---------------------------------------------------------------------------
def summarize(b, ctx):
    allies = b.allies(False)
    hp_now = sum(a["hp"] for a in allies if a["alive"])
    hp_max = sum(a["max"] for a in allies)
    hp_start = sum(min(a["hp"], a["max"]) for a in ctx["allies"])
    return {"result": b.result, "turns": b.turn, "down": len([a for a in allies if not a["alive"]]),
            "hp_end": hp_now, "hp_max": hp_max, "hp_start": hp_start, "hp_pct": round(hp_now / hp_max, 2),
            "potions": b.potions_used, "spells": b.spells_cast, "mana_spent": b.mana_spent,
            "end_hp": {a["uid"]: a["hp"] if a["alive"] else 0 for a in allies},
            "takeover": b.takeover,
            "arthur_pct": round(next((a["hp"] / a["max"] for a in allies if a["uid"] == "arthur" and a["alive"]), 0), 2)}


def run_route(style, build="balanced"):
    prof = Profile(style)
    rows = []
    chapter_log = []
    for ch in range(1, 7):
        silver_start = prof.silver
        for enc_id in PROPOSAL["route"][ch]:
            enc = enc_def(enc_id)
            req = enc.get("required", False)
            side = enc.get("side", False)
            if style == "must" and not req:
                continue
            party_ids = ["apprentice"] + enc["party"]
            # 血：全力和只打必须的每场前回满（圣龛、升级、药）；省资源一路带着，只在任务战、剧情战前回圣龛
            if style != "save" or req or side or enc_id == "merlin_shadow":
                prof.hp = {}
            if enc_id == "merlin_shadow":
                ctx = make_ctx(prof, enc_id, ch, build)
                ctx["allies"] = ctx["allies"][:1]
                ctx["spells"] = {k: v for k, v in ctx["spells"].items() if k in ("spark", "ward", "focus", "interrupt")}
            else:
                ctx = make_ctx(prof, enc_id, ch, build)
            lv_at = prof.level
            b = fight(enc_id, ctx, ch, "smart", allow_potions=(style == "full"))
            tries = 1
            while b.result != "win" and tries < 3:
                # 输了：回圣龛回满再打一次（输了不罚）
                prof.hp = {}
                ctx = make_ctx(prof, enc_id, ch, build)
                if enc_id == "merlin_shadow":
                    ctx["allies"] = ctx["allies"][:1]
                b = fight(enc_id, ctx, ch, "smart", allow_potions=(style == "full"))
                tries += 1
            s = summarize(b, ctx)
            s.update({"style": style, "ch": ch, "enc": enc_id, "label": enc["label"], "kind": enc["kind"],
                      "boss": is_boss_fight(enc), "level": lv_at, "side": enc.get("side", False), "tries": tries, "required": req,
                      "spark": ctx["spells"]["spark"]["damage"], "mana_max": ctx["mana_max"],
                      "ap_hp": ctx["allies"][0]["max"]})
            prof.potions = dict(b.potions)
            killed = list(b.killed)
            s["killed"] = list(b.killed)
            if enc.get("win", {}).get("type") == "survive" and PROPOSAL["survive_gives_xp"]:
                killed = list(enc["enemies"])
            xp = xp_of(killed, ch)
            ups = prof.gain_xp(xp, ch, party_ids)
            s["xp"] = xp
            s["level_after"] = prof.level
            # 血带出战斗
            for a in b.allies(False):
                prof.hp[a["uid"]] = a["hp"] if a["alive"] else 1
            if ups:
                prof.hp = {}
            after_heal = GEAR["must" if style == "must" else "all"][ch].get("after_heal", 0)
            if after_heal:
                for k in list(prof.hp):
                    prof.hp[k] += after_heal
            # 银币：每只 2 × 章（召唤的不算）
            prof.silver += sum(IT["drops"]["group"]["silver_per_enemy_per_chapter"] * ch for _ in b.killed)
            rows.append(s)
        qxp = PROPOSAL["quest_xp"][ch - 1]
        prof.gain_xp(qxp, ch, ["apprentice"])
        chapter_log.append({"style": style, "ch": ch, "xp": prof.xp, "level": prof.level,
                            "silver_earned": prof.silver - silver_start,
                            "kills": sum(len([1 for _ in r["killed"]]) for r in rows if r["ch"] == ch),
                            "gear_drops": round(sum((1.0 if r["boss"] else IT["drops"]["group"]["gear_chance"]) for r in rows if r["ch"] == ch), 1)})
    return rows, chapter_log


def degenerate_checks():
    """在每场必打的仗上，按「只打必须的」等级和普通装备跑三种退化打法"""
    out = []
    prof = Profile("must")
    for ch in range(1, 7):
        alts = [k for k, v in META.items() if v.get("alt") and v["ch"] == ch]
        for enc_id in PROPOSAL["route"][ch][:-1] + alts + PROPOSAL["route"][ch][-1:]:
            enc = enc_def(enc_id)
            if not (enc.get("required") or enc.get("side") or enc.get("alt")):
                continue
            if enc_id == "merlin_shadow":
                continue
            row = {"ch": ch, "enc": enc_id, "label": enc["label"], "level": prof.level}
            for pol in ("smart", "always_first", "no_magic", "smart_spark_build"):
                prof.hp = {}
                if pol == "smart":
                    ctx = make_ctx(prof, enc_id, ch, "balanced", gear_route="must")
                    b = fight(enc_id, ctx, ch, "smart")
                elif pol == "smart_spark_build":
                    ctx = make_ctx(prof, enc_id, ch, "spark", gear_route="must")
                    b = fight(enc_id, ctx, ch, "smart")
                else:
                    ctx = make_ctx(prof, enc_id, ch, "balanced", gear_route="must")
                    b = fight(enc_id, ctx, ch, pol)
                s = summarize(b, ctx)
                row[pol] = "%s %d 回合 倒 %d 剩 %d%%" % ({"win": "赢", "lose": "输", "timeout": "超时"}[b.result], b.turn, s["down"], round(100 * s["hp_pct"]))
                row[pol + "_win"] = b.result == "win"
            out.append(row)
            if enc.get("required"):
                killed = list(enc["enemies"])
                prof.gain_xp(xp_of(killed, ch), ch, ["apprentice"] + enc["party"])
        prof.gain_xp(PROPOSAL["quest_xp"][ch - 1], ch, ["apprentice"])
    return out


def simple_player():
    """「普通玩家」对照：main.gd 的 smart（先打要叫人、要长嚎的，快倒的举盾；不用打断、护身），全打路线的等级和装备"""
    out = []
    prof = Profile("full")
    for ch in range(1, 7):
        for enc_id in PROPOSAL["route"][ch]:
            enc = enc_def(enc_id)
            prof.hp = {}
            ctx = make_ctx(prof, enc_id, ch, gear_route="all")
            if enc_id != "merlin_shadow":
                b = fight(enc_id, ctx, ch, "smart_simple")
                sm = summarize(b, ctx)
                out.append({"ch": ch, "enc": enc_id, "label": enc["label"], "kind": enc["kind"], "result": b.result,
                            "turns": b.turn, "down": sm["down"], "hp_pct": sm["hp_pct"],
                            "loss": round(1 - sm["hp_end"] / max(1, sm["hp_start"]), 2), "level": prof.level})
            prof.gain_xp(xp_of(list(enc["enemies"]), ch), ch, ["apprentice"] + list(enc["party"]))
        prof.gain_xp(PROPOSAL["quest_xp"][ch - 1], ch, ["apprentice"])
    return out


def map_no_magic():
    """地图小仗：学徒不放法术（只凝神）能不能赢；按全打路线的等级"""
    out = []
    prof = Profile("full")
    for ch in range(1, 7):
        for enc_id in PROPOSAL["route"][ch]:
            enc = enc_def(enc_id)
            if enc["kind"] == "map":
                prof.hp = {}
                ctx = make_ctx(prof, enc_id, ch, gear_route="all")
                b = fight(enc_id, ctx, ch, "no_magic")
                out.append({"ch": ch, "enc": enc_id, "label": enc["label"], "win": b.result == "win", "turns": b.turn,
                            "hp_pct": summarize(b, ctx)["hp_pct"]})
            killed = list(enc["enemies"]) if enc_id != "merlin_shadow" else ["merlin_shadow"]
            prof.gain_xp(xp_of(killed, ch), ch, ["apprentice"] + list(enc["party"]))
        prof.gain_xp(PROPOSAL["quest_xp"][ch - 1], ch, ["apprentice"])
    return out


# ---------------------------------------------------------------------------
def validate():
    """第 1 章：照 main.gd --sim（1 级、满血、没装备、学徒只会星火护身凝神），三种固定打法"""
    prof = Profile("must")
    lines = []
    for enc in ["forest_wolves", "road_bandits", "oak_wolves", "log_wolves", "wolves"]:
        for strat in ["always_first", "smart", "no_magic"]:
            ctx = make_ctx(prof, enc, 1)
            ctx["spells"] = {k: v for k, v in ctx["spells"].items() if k in ("spark", "ward", "focus")}
            b = Battle(enc, ctx, 1)
            g = 0
            while not b.result and g < 20:
                g += 1
                godot_plan(b, strat)
                b.end_turn()
            names = {"apprentice": "你", "kay": "凯", "arthur": "亚瑟"}
            down = len([u for u in b.allies(False) if not u["alive"]])
            hp = ", ".join("%s %d/%d" % (names[u["uid"]], u["hp"], u["max"]) for u in b.allies(False))
            lines.append("[sim] %s %s → %s 第 %d 回合，倒下 %d 人，剩血 %s" % (enc, strat, b.result, b.turn, down, hp))
    return lines


def godot_ctx(enc_id, ch):
    """照 Godot --sim 第 2–6 章的开法：1 级、满血、没装备、同伴按章的数；法术是开局三招 + 打断（第 2 章起）+ 揭开（第 4 章起）。
    Godot 里同伴专属招（剑鞘、正午之力、后发、连斩、包扎）还没写，这里关掉，两边才是同一套规则。"""
    prof = Profile("must")
    ctx = make_ctx(prof, enc_id, ch)
    gear = GEAR["must"][ch]
    ctx["allies"][0]["max"] -= gear.get("hp", 0)
    ctx["allies"][0]["hp"] = ctx["allies"][0]["max"]
    ctx["mana_max"] -= gear.get("mana_max", 0)
    base = CB["spells"]
    ctx["spells"]["spark"]["damage"] = base["spark"]["damage"]
    ctx["spells"]["ward"]["block"] = base["ward"]["block"]
    ctx["spells"]["focus"]["restore_mana"] = base["focus"].get("restore_mana", 2)
    ctx["start"]["apprentice_block"] = 0
    ctx["start"]["top_hp_vulnerable"] = 0
    return strip_moves(ctx)


def strip_moves(ctx):
    for a in ctx["allies"]:
        a["move"] = ""
        a["uses"] = 0
    ctx["scabbard"] = False
    return ctx


def must_ctxs():
    """「只打必须的」那条线每场仗开打时的我方（等级、技能树、普通装备，和 degenerate_checks 同一套），同伴专属招关掉。
    写进 production/qa/balance/sim_ctx.json，Godot --sim 原样读进去打，对照战斗规则本身。"""
    out = {}
    prof = Profile("must")
    for ch in range(1, 7):
        alts = [k for k, v in META.items() if v.get("alt") and v["ch"] == ch]
        for enc_id in PROPOSAL["route"][ch][:-1] + alts + PROPOSAL["route"][ch][-1:]:
            enc = enc_def(enc_id)
            if enc_id == "merlin_shadow":
                continue
            if ch >= 2:
                prof.hp = {}
                ctx = strip_moves(make_ctx(prof, enc_id, ch, "balanced", gear_route="must"))
                out[enc_id] = {k: v for k, v in ctx.items() if not k.startswith("_")}
                out[enc_id]["level"] = prof.level
                out[enc_id]["chapter"] = ch
            if enc.get("required"):
                prof.gain_xp(xp_of(list(enc["enemies"]), ch), ch, ["apprentice"] + enc["party"])
        prof.gain_xp(PROPOSAL["quest_xp"][ch - 1], ch, ["apprentice"])
    return out


def write_must_ctxs():
    ctxs = must_ctxs()
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "sim_ctx.json"), "w", encoding="utf-8") as f:
        json.dump({"_说明": "tools/sim_numbers.py 生成，别手改。Godot --sim 第 2–6 章「只打必须的等级」那一节原样读这里的我方数据。",
                   "ctx": ctxs}, f, ensure_ascii=False, indent=1)
    return ctxs


def validate_later(profile="lv1"):
    """第 2–6 章：三种固定打法。lv1 = 1 级没装备（godot_ctx）；must = 只打必须的等级和装备（must_ctxs）。
    撑过的仗按上场的敌人给经验"""
    lines = []
    names = {"apprentice": "你"}
    for k, v in CB["companions"].items():
        if isinstance(v, dict):
            names[k] = v.get("name", k)
    musts = must_ctxs()
    for enc in musts:          # 顺序和 sim_ctx.json 一样（Godot 按这个文件的顺序打）
        ed = enc_def(enc)
        ch = ed["ch"]
        for strat in ["always_first", "smart", "no_magic"]:
            ctx = godot_ctx(enc, ch) if profile == "lv1" else json.loads(json.dumps(musts[enc]))
            b = Battle(enc, ctx, ch)
            g = 0
            while not b.result and g < 20:
                g += 1
                godot_plan(b, strat)
                b.end_turn()
            down = len([u for u in b.allies(False) if not u["alive"]])
            hp = ", ".join("%s %d/%d" % (names[u["uid"]], u["hp"], u["max"]) for u in b.allies(False))
            res = b.result
            if b.result == "win":
                if b.takeover:
                    res += "/end_if_down"
                elif ed["win"].get("type") == "survive" and b.enemies():
                    res += "/survive"
                killed = list(ed["enemies"]) if res != "win" else list(b.killed)
                hp += "，经验 %d" % xp_of(killed, ch)
            party = "、".join(names[u["uid"]] for u in b.allies(False) if u["uid"] != "apprentice")
            lv = "" if profile == "lv1" else " %d 级" % ctx["level"]
            lines.append("[sim] 第 %d 章%s %s %s（%s）→ %s 第 %d 回合，倒下 %d 人，剩血 %s" % (ch, lv, enc, strat, party, res, b.turn, down, hp))
    return lines


def fmt_pct(x):
    return "%d%%" % round(100 * x)


def target_turns(r):
    if r["enc"] == "pellinore":
        return (3, 3)
    if r["enc"] == "dover":
        return (4, 4)
    if r["enc"] == "merlin_shadow":
        return (1, 3)
    if r["kind"] == "map":
        return TARGETS["map"]
    if r["boss"]:
        return TARGETS["boss_hard"] if r["enc"] in HARD_BOSSES else TARGETS["boss"]
    return TARGETS["quest"]


def hp_band(r):
    """只打必须的、最优打法打完剩的血；按章节内容表的难度。个别仗单列（NUMBERS.md 第 6 节）"""
    special = {"pellinore": (0.30, 0.65), "joyous_gard": (0.45, 0.80), "camlann": (0.15, 0.50), "dover": (0.25, 0.55)}
    if r["enc"] in special:
        return special[r["enc"]]
    return HP_BAND[CH_DIFF[r["ch"]]]


def check_row(r):
    """一场仗离没离开目标。任务战、剧情战按「只打必须的」看；地图小仗按「全力」看（打小仗的就是全打的人）"""
    flags = []
    if r["result"] != "win":
        flags.append("没打赢")
    if r.get("takeover"):
        flags.append("亚瑟倒下，剧情接管")
    look_turns = (r["kind"] == "map" and r["style"] != "must") or (r["kind"] != "map" and r["style"] == "must") \
        or (r.get("side") and r["style"] == "full")
    if look_turns:
        lo, hi = target_turns(r)
        if not (lo <= r["turns"] <= hi):
            flags.append("回合 %d 不在 %d–%d" % (r["turns"], lo, hi))
    if r["style"] == "must" and r["enc"] != "merlin_shadow":
        blo, bhi = hp_band(r)
        v = r["arthur_pct"] if r["enc"] == "pellinore" else r["hp_pct"]
        if not (blo <= v <= bhi):
            flags.append("剩血 %s 不在 %s–%s" % (fmt_pct(v), fmt_pct(blo), fmt_pct(bhi)))
    if r["kind"] == "map" and r["style"] == "full":
        loss = 1 - r["hp_end"] / max(1, r["hp_start"])
        lo = 0.05 if r["ch"] <= 2 else 0.08
        if not (lo <= loss <= 0.25):
            flags.append("掉血 %s 不在 %s–25%%" % (fmt_pct(loss), fmt_pct(lo)))
    return flags


def main():
    if "--validate" in sys.argv:
        write_must_ctxs()
        print("\n".join(validate() + validate_later() + validate_later("must")))
        return
    os.makedirs(OUT, exist_ok=True)
    all_rows, all_ch = [], []
    for style in ("full", "save", "must"):
        rows, chl = run_route(style)
        all_rows += rows
        all_ch += chl
    degen = degenerate_checks()
    mapnm = map_no_magic()
    simple = simple_player()
    val = validate()
    write_must_ctxs()
    val_later = validate_later() + validate_later("must")

    # ---- 写结果 ----
    with open(os.path.join(OUT, "sim_results.json"), "w", encoding="utf-8") as f:
        json.dump({"fights": all_rows, "chapters": all_ch, "degenerate": degen, "map_no_magic": mapnm, "simple_player": simple,
                   "ch1_validate": val, "ch2_6_validate": val_later}, f, ensure_ascii=False, indent=1)
    style_name = {"full": "全力", "save": "省资源", "must": "只打必须的"}
    md = []
    md.append("# 数值模拟结果（tools/sim_numbers.py 生成，别手改）\n")
    md.append("数值全从 content/data 读（第 2–6 章 2026-11-09 落进 combat.json，见 design/NUMBERS.md）。最优打法每回合把三个人能排的组合全试一遍，挑评分最高的。\n")
    md.append("## 第 1 章对照 Godot `--sim`（同样的三种固定打法）\n")
    md.append("```\n" + "\n".join(val) + "\n```\n")
    md.append("## 第 2–6 章对照 Godot `--sim`（先按 1 级、没装备，再按「只打必须的」等级和装备；同伴按章；同伴专属招两边都关掉）\n")
    md.append("```\n" + "\n".join(val_later) + "\n```\n")
    md.append("## 每章末等级和经验\n")
    md.append("| 章 | " + " | ".join("%s：经验 / 等级" % style_name[s] for s in ("full", "save", "must")) + " |")
    md.append("|---|---|---|---|")
    for ch in range(1, 7):
        cells = []
        for s in ("full", "save", "must"):
            c = [x for x in all_ch if x["style"] == s and x["ch"] == ch][0]
            cells.append("%d / %d 级" % (c["xp"], c["level"]))
        md.append("| %d | %s |" % (ch, " | ".join(cells)))
    md.append("")
    md.append("## 每章打倒几只、银币（只算打怪掉的，每只 2 × 章；省资源和只打必须的另把「钱袋」算进去）、期望掉几件装备（不含宝物和任务奖励）\n")
    md.append("| 章 | " + " | ".join("%s：只数 / 银币 / 装备" % style_name[s] for s in ("full", "save", "must")) + " |")
    md.append("|---|---|---|---|")
    for ch in range(1, 7):
        cells = []
        for s in ("full", "save", "must"):
            c = [x for x in all_ch if x["style"] == s and x["ch"] == ch][0]
            cells.append("%d / %d / %.1f" % (c["kills"], c["silver_earned"], c["gear_drops"]))
        md.append("| %d | %s |" % (ch, " | ".join(cells)))
    md.append("")
    for s in ("full", "save", "must"):
        md.append("## %s\n" % style_name[s])
        md.append("| 章 | 仗 | 类型 | 开打等级 | 星火 / 法力 / 学徒血 | 结果 | 回合 | 倒下 | 剩血 | 用药 | 法术 | 离开目标 |")
        md.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
        for r in [x for x in all_rows if x["style"] == s]:
            kind = {"map": "小仗", "quest": "任务战", "story": "剧情战"}[r["kind"]] + ("·首领" if r["boss"] else "")
            fl = check_row(r)
            md.append("| %d | %s | %s | %d | %d / %d / %d | %s%s | %d | %d | %d/%d（%s） | %d | %d | %s |" % (
                r["ch"], r["label"], kind, r["level"], r["spark"], r["mana_max"], r["ap_hp"],
                {"win": "赢", "lose": "输", "timeout": "超时"}[r["result"]], "" if r["tries"] == 1 else "（第 %d 次）" % r["tries"],
                r["turns"], r["down"], r["hp_end"], r["hp_max"], fmt_pct(r["hp_pct"]), r["potions"], r["spells"],
                "；".join(fl) if fl else "—"))
        md.append("")
    md.append("## 退化打法检验（只打必须的等级、普通装备）\n")
    md.append("| 章 | 仗 | 开打等级 | 最优打法（四棵树平均点） | 永远打排在最前的 | 学徒不放法术 | 全点星火 + 最优打法 |")
    md.append("|---|---|---|---|---|---|---|")
    for r in degen:
        md.append("| %d | %s | %d | %s | %s | %s | %s |" % (r["ch"], r["label"], r["level"], r["smart"], r["always_first"], r["no_magic"], r["smart_spark_build"]))
    md.append("")
    md.append("## 「普通玩家」对照（main.gd 的 smart 打法：不用打断和护身；全打路线的等级和装备）\n")
    md.append("| 章 | 仗 | 开打等级 | 结果 | 回合 | 倒下 | 剩血 | 这一场掉的血 |")
    md.append("|---|---|---|---|---|---|---|---|")
    for r in simple:
        md.append("| %d | %s | %d | %s | %d | %d | %s | %s |" % (r["ch"], r["label"], r["level"], {"win": "赢", "lose": "输", "timeout": "超时"}[r["result"]],
                                                       r["turns"], r["down"], fmt_pct(r["hp_pct"]), fmt_pct(r["loss"])))
    md.append("")
    md.append("## 地图小仗：学徒不放法术（全打路线的等级和装备）\n")
    won = sum(1 for r in mapnm if r["win"])
    md.append("赢 %d / %d 场。\n" % (won, len(mapnm)))
    md.append("| 章 | 仗 | 结果 | 回合 | 剩血 |")
    md.append("|---|---|---|---|---|")
    for r in mapnm:
        md.append("| %d | %s | %s | %d | %s |" % (r["ch"], r["label"], "赢" if r["win"] else "输", r["turns"], fmt_pct(r["hp_pct"])))
    with open(os.path.join(OUT, "sim_results.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(md) + "\n")
    print("\n".join(md))


if __name__ == "__main__":
    main()
