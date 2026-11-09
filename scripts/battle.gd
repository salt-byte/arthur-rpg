class_name Battle
extends RefCounted
## 回合制战斗的规则，照 design/systems/combat.md（意图照《杀戮尖塔》，第 1 章的数来自原型 prototypes/how-to-fight）。
## 数全部从 content/data/combat.json 读；学徒和同伴的数从 Party 拿（技能树、装备、随机奖励都算进去）。
## 只管算，不管画：BattleView 和 --playtest 都调这里。
## 一回合：格挡清零 → 回法力 → 亮出意图 → 三个人各选一招（queue）→ end_turn()：
##   你们按站位（学徒 → 同伴一 → 同伴二）出手 → 你们的虚弱、易伤减 1 → 敌人格挡清零、按顺序出手 → 敌人的虚弱、易伤减 1。
## 伤害 = floor((点数 + 力量) × 虚弱 0.75 × 易伤 1.5)，先扣格挡（mechanics-library intent-battle 的「常见的坑」逐条对过）。
## 敌人的招按 pattern 轮着用，不看运气：同一场重来，同样的操作，意图逐字一样。

var P: Dictionary
var enc_id := ""
var enc: Dictionary
var units: Array = []       # {uid, id, side, name, hp, max, power, block, str, weak, vuln, alive, cover, pattern, ptr, pending, summoned}
var turn := 0
var mana := 0
var mana_max := 0
var intents: Array = []     # 敌人这回合要做的事，按出手顺序：{uid, act, move, power, hits, target, then, what, count, n, order, cancelled}
var queue: Array = []       # 你们这回合选的招：{who, act, target}
var result := ""            # "" 还在打 / "win" / "lose" / "flee"
var out: Array = []         # 发生的事（文字），界面和测试取走后清空
var chapter := 1
var vars := {}
var unlocks: Array = []
var A: Dictionary           # 学徒这一仗的数（Party.ap_stats()）
var potions := {}           # 这一仗带着的药；打赢、逃跑才写回背包，输了原样还回去
var potions_start := {}
var kills: Array = []       # 打倒的敌人 {id, summoned}，打赢后算经验和掉落
var stand_used := false
var steps: Array = []
var _setup_args := []
var _hp_start := {}

const SPELL_ORDER := ["spark", "ward", "focus", "interrupt", "twin_spark", "fire_rain", "blind", "haze", "still_water", "deflect", "reveal"]

## hp_now：{uid: 开打时的血}，不给就满血；potions_now：{potion_hp: n, ...}
func setup(id: String, party: Array, chapter_: int, unlocks_: Array, vars_: Dictionary, hp_now := {}, potions_now := {}) -> void:
	_setup_args = [id, party.duplicate(), chapter_, unlocks_.duplicate(), vars_.duplicate(), hp_now.duplicate(), potions_now.duplicate()]
	P = Data.t("combat")
	enc_id = id
	enc = Data.encounter(id)
	chapter = chapter_
	unlocks = unlocks_
	vars = vars_
	A = Party.ap_stats()
	units = []
	turn = 0
	queue = []
	intents = []
	result = ""
	out = []
	kills = []
	stand_used = false
	potions = potions_now.duplicate()
	potions_start = potions_now.duplicate()
	units.append(_unit("apprentice", "ally", UIKit.t("ui_you"), int(A.hp), 0))
	for c in party:
		var cs := Party.comp_stats(c, chapter)
		units.append(_unit(c, "ally", cs.name, int(cs.hp), int(cs.power)))
	for u in units:
		if hp_now.has(u.uid):
			u.hp = clampi(int(hp_now[u.uid]), 0, u.max)
			u.alive = u.hp > 0
	# 带着 0 血进来的人（上一仗倒下、站起来剩 1 血的不算）照样上场，只是站不起来：至少留 1 血
	for u in allies(false):
		if u.hp <= 0:
			u.hp = 1
			u.alive = true
	_hp_start = {}
	for u in units: _hp_start[u.uid] = u.hp
	for e in enc.get("enemies", []):
		_add_enemy(e, false)
	mana_max = int(A.mana_max)
	mana = mana_max   # 开场法力是满的（原型）
	# 开打时的效果：看穿（技能树）、明眼（装备）
	if int(A.see) > 0:
		for e in enemies(): e.vuln += int(A.see)
		out.append(UIKit.f("ev_see", {"n": A.see}))
	if int(A.start_vuln_top) > 0 and not enemies().is_empty():
		var top = enemies()[0]
		for e in enemies():
			if e.hp > top.hp: top = e
		top.vuln += int(A.start_vuln_top)
		out.append(UIKit.f("ev_keen", {"who": top.name, "n": A.start_vuln_top}))
	begin_turn()
	if int(A.start_block) > 0:
		unit("apprentice").block += int(A.start_block)
		out.append(UIKit.f("ev_vigil", {"n": A.start_block}))

## 输了「再来一次」：用开场时的参数重来，血、药、敌人都原样
func restart() -> void:
	setup(_setup_args[0], _setup_args[1], _setup_args[2], _setup_args[3], _setup_args[4], _setup_args[5], _setup_args[6])

func _unit(id: String, side: String, name: String, hp: int, power: int) -> Dictionary:
	return {"uid": id, "id": id, "side": side, "name": name, "hp": hp, "max": hp, "power": power, "block": 0, "str": 0,
		"weak": 0, "vuln": 0, "alive": true, "cover": false, "pattern": [], "ptr": 0, "pending": null, "summoned": false}

func _add_enemy(eid: String, summoned: bool) -> Dictionary:
	var ed: Dictionary = Data.enemy(eid)
	var base_name := UIKit.t(ed.get("name", eid))
	var name := base_name
	var n := 1
	while _name_taken(name):
		n += 1
		name = "%s %d" % [base_name, n]
	var uid := eid
	var k := 1
	while unit(uid) != null:
		k += 1
		uid = "%s#%d" % [eid, k]
	var u := _unit(uid, "enemy", name, int(ed.hp), 0)
	u.id = eid
	u.pattern = ed.get("pattern", [])
	u.summoned = summoned
	u["kind"] = ed.get("kind", "")
	u["vanish"] = ed.get("vanish_on_interrupt", false)
	units.append(u)
	return u

func _name_taken(name: String) -> bool:
	for u in units:
		if u.name == name: return true
	return false

# ---------------- 查询 ----------------
func unit(uid: String):
	for u in units:
		if u.uid == uid: return u
	return null

func allies(alive_only := true) -> Array:
	return units.filter(func(u): return u.side == "ally" and (u.alive or not alive_only))

func enemies(alive_only := true) -> Array:
	return units.filter(func(u): return u.side == "enemy" and (u.alive or not alive_only))

func intent_of(uid: String):
	for it in intents:
		if it.uid == uid: return it
	return null

func has_spell(s: String) -> bool:
	if s in Party.tree_spells(): return true
	if ("spell_" + s) in unlocks: return true
	for u in Data.t("story-unlocks").get("unlocks", []):
		if u.get("kind", "") == "spell" and u.get("what", "") == s and u.id in unlocks:
			return chapter >= int(u.get("usable_from_chapter", 1))
	return false

func spell_def(s: String) -> Dictionary:
	if P.spells.has(s): return P.spells[s]
	return Party.tree_spell_def(s)

func is_spell(act: String) -> bool:
	return not spell_def(act).is_empty() and act != "use_item"

func spells() -> Array:
	return SPELL_ORDER.filter(func(s): return has_spell(s) and is_spell(s))

func spell_cost(s: String) -> int:
	if s == "interrupt": return int(A.interrupt)
	return int(spell_def(s).get("mana", 0))

func can_flee() -> bool:
	return bool(P.get("flee_allowed", true)) and enc.get("flee", true) and enc.get("kind", "") != "story"

## 这个人这回合能选的招
func actions_for(uid: String) -> Array:
	var a := []
	if uid == "apprentice":
		a = spells().filter(func(s): return not spell_def(s).get("free_action", false))
		a.append("potion_hp")
		a.append("potion_mana")
		return a
	a = ["attack", "guard"]
	if uid == "kay" and _kay_cover_ok(): a.append("kay_cover")
	a.append("potion_hp")
	return a

## 凯「挡在前面」：第 1 章出发前一晚谁都没告诉（D1c），第 4 章起
func _kay_cover_ok() -> bool:
	return str(vars.get("D1", "")) == "D1c" and chapter >= 4

## 招要不要选目标：enemy / ally / ""
func target_kind(act: String) -> String:
	match act:
		"spark", "attack", "interrupt", "twin_spark", "blind": return "enemy"
		"ward", "potion_hp": return "ally"
	return ""

## 法力里已经被选进这回合的法术占掉的
func reserved() -> int:
	var r := 0
	for q in queue:
		if is_spell(q.act): r += spell_cost(q.act)
	return r

func mana_left() -> int:
	return mana - reserved()

func potions_left(kind: String) -> int:
	var n := int(potions.get(kind, 0))
	for q in queue:
		if q.act == kind: n -= 1
	return n

## 能不能选这一招；不能时返回原因（文本），能时返回 ""
func why_not(uid: String, act: String) -> String:
	var u = unit(uid)
	if u == null or not u.alive: return "dead"
	var q = planned(uid)
	var own_mana := spell_cost(q.act) if q != null and is_spell(q.act) else 0
	if is_spell(act) and spell_cost(act) > mana_left() + own_mana:
		return UIKit.f("ui_no_mana", {"need": spell_cost(act), "left": mana_left() + own_mana})
	if act == "interrupt" and interruptible().is_empty():
		return UIKit.f("ui_no_interrupt")
	if act in ["potion_hp", "potion_mana"]:
		var own := 1 if q != null and q.act == act else 0
		if potions_left(act) + own <= 0: return UIKit.t("ui_no_potion")
		if act == "potion_mana" and mana >= mana_max: return UIKit.t("ui_mana_full")
	if act == "twin_spark" and enemies().size() < 2: return UIKit.t("ui_need_two")
	return ""

## 这回合在蓄力、召唤或长嚎，还没被打断的敌人
func interruptible() -> Array:
	var a := []
	for it in intents:
		var e = unit(it.uid)
		if e != null and e.alive and not it.cancelled and it.act in ["charge", "summon", "buff"]:
			a.append(it.uid)
	return a

func valid_targets(act: String) -> Array:
	match target_kind(act):
		"enemy":
			if act == "interrupt": return interruptible()
			return enemies().map(func(e): return e.uid)
		"ally":
			if act == "potion_hp": return allies().filter(func(x): return x.hp < x.max).map(func(x): return x.uid)
			return allies().map(func(x): return x.uid)
	return []

## 选一招（同一个人再选就换掉原来那一招）
func plan(uid: String, act: String, target := "") -> bool:
	var old = planned(uid)
	unplan(uid)
	if why_not(uid, act) != "" or (target_kind(act) != "" and not target in valid_targets(act)):
		if old != null: queue.append(old)
		return false
	queue.append({"who": uid, "act": act, "target": target})
	return true

func unplan(uid: String) -> void:
	queue = queue.filter(func(q): return q.who != uid)

func planned(uid: String):
	for q in queue:
		if q.who == uid: return q
	return null

## 出手顺序只看站位：学徒 → 同伴一 → 同伴二（不看先选谁）
func exec_order() -> Array:
	var a := []
	for u in allies(false):
		var q = planned(u.uid)
		if q != null: a.append(q)
	return a

func slot_of(uid: String) -> int:
	var al := allies(false)
	for i in al.size():
		if al[i].uid == uid: return i + 1
	return 0

# ---------------- 伤害（只有这一处公式） ----------------
func hit_damage(base: int, src: Dictionary, tgt: Dictionary) -> int:
	var d := float(base + int(src.str))
	if int(src.weak) > 0: d *= float(P.rules.weak_mult)
	if int(tgt.vuln) > 0: d *= float(P.rules.vulnerable_mult)
	return maxi(int(P.rules.min_damage), int(floor(d + 0.000001)))

## 意图上显示的一下打多少（已经算进力量、虚弱、目标的易伤）
func intent_damage(it: Dictionary, target_uid := "") -> int:
	var e = unit(it.uid)
	var power := int(it.power)
	if it.act == "charge": power = int(it.then.get("power", 0))
	var t = unit(target_uid if target_uid != "" else it.get("target", ""))
	if e == null: return power
	return hit_damage(power, e, t if t != null else {"vuln": 0})

# ---------------- 意图 ----------------
func begin_turn() -> void:
	turn += 1
	intents = []
	for u in allies(false):
		u.block = 0
		u.cover = false
	if turn > 1:
		mana = mini(mana_max, mana + int(A.mana_regen))
	var order := 1
	for e in enemies():
		var it := _make_intent(e)
		it.order = order
		order += 1
		intents.append(it)
	out.append("[第 %d 回合] 法力 %d/%d" % [turn, mana, mana_max])
	for it in intents:
		out.append("[意图] %d. %s" % [it.order, intent_text(it)])

func _make_intent(e: Dictionary) -> Dictionary:
	var src: Dictionary
	var release := false
	if e.pending != null:
		src = e.pending
		e.pending = null
		release = true
	else:
		src = e.pattern[e.ptr % e.pattern.size()]
		e.ptr += 1
	var it := {"uid": e.uid, "act": src.get("act", "attack"), "move": src.get("move", ""), "power": int(src.get("power", 0)),
		"hits": int(src.get("hits", 1)), "target": "", "then": src.get("then", null), "what": src.get("what", ""),
		"count": int(src.get("count", 0)), "n": 0, "order": 0, "cancelled": false, "release": release}
	match it.act:
		"attack":
			it.target = _resolve(src.get("target", "lowest_hp"))
			if it.target == "all": it.act = "all"
		"charge":
			if it.then != null: it.then_target = _resolve(it.then.get("target", "lowest_hp"))
		"buff":
			it.n = int(src.get("strength", 1))
		"weak":
			it.n = int(src.get("stacks", 1))
			it.target = _resolve(src.get("target", "lowest_hp"))
		"block":
			it.n = int(src.get("block", 0))
	return it

func _resolve(t: String) -> String:
	if t == "all": return "all"
	if t == "lowest_hp": return _lowest()
	var u = unit(t)
	if u != null and u.alive and u.side == "ally": return t
	return _lowest()

func _lowest() -> String:
	var best = null
	for a in allies():
		if best == null or a.hp < best.hp: best = a
	return best.uid if best != null else ""

func intent_text(it: Dictionary) -> String:
	var e = unit(it.uid)
	var who: String = e.name
	match it.act:
		"attack":
			var n := str(intent_damage(it)) + ("×%d" % it.hits if it.hits > 1 else "")
			return UIKit.f("intent_attack", {"who": who, "move": UIKit.t(it.move), "target": _name(it.target), "n": n})
		"all":
			return UIKit.f("intent_all", {"who": who, "move": UIKit.t(it.move), "n": intent_damage(it, _lowest())})
		"charge":
			var th: Dictionary = it.then
			return UIKit.f("intent_charge", {"who": who, "move": UIKit.t(th.get("move", "")), "target": _name(it.get("then_target", "")), "n": intent_damage(it, it.get("then_target", ""))})
		"summon":
			return UIKit.f("intent_summon", {"who": who, "n": it.count, "what": UIKit.t(Data.enemy(it.what).get("name", it.what))})
		"buff":
			return UIKit.f("intent_buff", {"who": who, "move": UIKit.t(it.move), "n": it.n})
		"weak":
			return UIKit.f("intent_weak", {"who": who, "move": UIKit.t(it.move), "target": _name(it.target), "n": it.n})
		"block":
			return UIKit.f("intent_block", {"who": who, "move": UIKit.t(it.move), "n": it.n})
	return who

func _name(uid: String) -> String:
	var u = unit(uid)
	return u.name if u != null else uid

# ---------------- 结算 ----------------
## 一步一步记下这回合发生了什么，界面照着一来一回地播：
## {side: "ally"/"enemy"/"end", who, target, lines, hp: {uid: [hp, alive]}, order}
func end_turn() -> void:
	if result != "": return
	var q := exec_order()
	queue = []
	steps = []
	for i in q.size():
		if result != "": break
		var mark := out.size()
		_do(q[i])
		_step("ally", q[i].who, q[i].target, mark, i + 1)
	if result != "": return
	for u in allies(false):
		u.weak = maxi(0, u.weak - 1)
		u.vuln = maxi(0, u.vuln - 1)
	for e in enemies(false): e.block = 0
	for it in intents:
		if result != "": break
		var mark := out.size()
		_enemy_act(it)
		_step("enemy", it.uid, it.get("target", ""), mark, it.order)
	if result != "": return
	for e in enemies(false):
		e.weak = maxi(0, e.weak - 1)
		e.vuln = maxi(0, e.vuln - 1)
	var win: Dictionary = enc.get("win", {})
	if win.get("type", "") == "survive" and turn >= int(win.get("turns", 99)):
		result = "win"
		out.append("[结果] " + UIKit.t("ui_survived"))
		return
	var mark := out.size()
	begin_turn()
	_step("end", "", "", mark, 0)

func _step(side: String, who: String, target: String, mark: int, order: int) -> void:
	var lines := out.slice(mark)
	if lines.is_empty() and side != "end": return
	var hp := {}
	for u in units: hp[u.uid] = [u.hp, u.alive]
	steps.append({"side": side, "who": who, "target": target, "lines": lines, "hp": hp, "order": order})

## 照现在选的招试算一遍这回合，不改真的战斗：返回 {uid: 打完以后的血}
func preview() -> Dictionary:
	var c := Battle.new()
	c.P = P
	c.enc_id = enc_id
	c.enc = enc
	c.chapter = chapter
	c.vars = vars
	c.unlocks = unlocks
	c.A = A
	c.units = units.duplicate(true)
	c.turn = turn
	c.mana = mana
	c.mana_max = mana_max
	c.potions = potions.duplicate()
	c.stand_used = stand_used
	c.intents = intents.duplicate(true)
	c.queue = queue.duplicate(true)
	c.end_turn()
	var r := {}
	for u in units:
		var cu = c.unit(u.uid)
		r[u.uid] = cu.hp if cu != null else u.hp
	return r

## 我方目标先倒了：改打下一个还站着的敌人
func _enemy_target(uid: String):
	var t = unit(uid)
	if t != null and t.alive and t.side == "enemy": return t
	var es := enemies()
	return es[0] if not es.is_empty() else null

func _do(a: Dictionary) -> void:
	var u = unit(a.who)
	if u == null or not u.alive: return
	var act: String = a.act
	if is_spell(act):
		var cost := spell_cost(act)
		if cost > mana: return
		if act == "interrupt":
			var it = intent_of(a.target)
			var t = unit(a.target)
			if it == null or t == null or not t.alive or it.cancelled or not it.act in ["charge", "summon", "buff"]:
				out.append(UIKit.t("ev_interrupt_miss"))
				return
			mana -= cost
			it.cancelled = true
			out.append(UIKit.f("ev_cancel", {"who": t.name, "act": UIKit.t("act_" + it.act)}))
			if t.get("vanish", false):
				t.hp = 0
				t.alive = false
				kills.append({"id": t.id, "summoned": t.summoned})
				out.append(UIKit.f("ev_vanish", {"who": t.name}))
				_check_win()
			elif int(A.lever) > 0:
				t.vuln += int(A.lever)
				out.append(UIKit.f("ev_vuln", {"who": t.name, "n": A.lever}))
			return
		mana -= cost
		match act:
			"spark":
				var t = _enemy_target(a.target)
				if t != null:
					_strike(u, t, int(A.spark), UIKit.t("sp_spark"))
					t.vuln += int(A.spark_vuln)
					if t.alive: out.append(UIKit.f("ev_vuln", {"who": t.name, "n": A.spark_vuln}))
			"twin_spark":
				var t = _enemy_target(a.target)
				var hit := [t]
				for e in enemies():
					if e != t and hit.size() < 2: hit.append(e)
				for x in hit:
					if x != null and x.alive: _strike(u, x, int(A.spark), str(spell_def("twin_spark").name))
			"fire_rain":
				for x in enemies(): _strike(u, x, int(spell_def("fire_rain").get("damage", 2)), str(spell_def("fire_rain").name))
			"blind":
				var t = _enemy_target(a.target)
				if t != null:
					t.weak += int(spell_def("blind").get("weak", 2))
					out.append(UIKit.f("ev_weak", {"who": t.name, "n": spell_def("blind").get("weak", 2)}))
			"haze":
				for x in enemies():
					x.weak += int(spell_def("haze").get("weak", 1))
				out.append(UIKit.f("ev_haze", {"n": spell_def("haze").get("weak", 1)}))
			"ward":
				var t = unit(a.target)
				if t == null or not t.alive: t = u
				t.block += int(A.ward)
				out.append(UIKit.f("ev_ward_cast", {"target": t.name, "n": A.ward}))
				if int(A.ward_targets) > 1:
					var other = null
					for x in allies():
						if x != t and (other == null or x.hp < other.hp): other = x
					if other != null:
						other.block += int(A.ward)
						out.append(UIKit.f("ev_ward_cast", {"target": other.name, "n": A.ward}))
			"focus":
				mana = mini(mana_max, mana + int(A.focus))
				out.append(UIKit.f("ev_focus", {"n": A.focus}))
		return
	match act:
		"attack":
			var t = _enemy_target(a.target)
			if t != null: _strike(u, t, int(u.power), UIKit.t("act_attack"))
		"guard":
			u.block += Party.guard_block()
			out.append(UIKit.f("ev_guard", {"who": u.name, "n": Party.guard_block()}))
		"kay_cover":
			u.cover = true
			u.block += int(P.kay_cover_block)
			out.append(UIKit.f("ev_cover_up", {"n": P.kay_cover_block}))
		"potion_hp":
			if int(potions.get("potion_hp", 0)) <= 0: return
			var t = unit(a.target)
			if t == null or not t.alive: t = u
			potions.potion_hp = int(potions.potion_hp) - 1
			var heal := int(Party.potion_def("potion_hp").heal)
			var before: int = t.hp
			t.hp = mini(t.max, t.hp + heal)
			out.append(UIKit.f("ev_potion_hp", {"who": u.name, "target": t.name, "n": t.hp - before}))
		"potion_mana":
			if int(potions.get("potion_mana", 0)) <= 0: return
			potions.potion_mana = int(potions.potion_mana) - 1
			var before := mana
			mana = mini(mana_max, mana + int(Party.potion_def("potion_mana").restore_mana))
			out.append(UIKit.f("ev_potion_mana", {"n": mana - before}))

## 我方打一下：算伤害、扣格挡、扣血、看倒没倒
func _strike(src: Dictionary, t: Dictionary, base: int, label: String) -> void:
	var d := hit_damage(base, src, t)
	var bl := mini(t.block, d)
	t.block -= bl
	t.hp = maxi(0, t.hp - (d - bl))
	var line := UIKit.f("ev_strike", {"who": src.name, "move": label, "target": t.name, "n": d - bl})
	if bl > 0: line += UIKit.f("ev_blocked", {"n": bl})
	out.append(line)
	_check_enemy_down(t)

func _check_enemy_down(t: Dictionary) -> void:
	if t.hp > 0 or not t.alive: return
	t.alive = false
	kills.append({"id": t.id, "summoned": t.summoned})
	var it = intent_of(t.uid)
	if it != null and not it.cancelled and it.act in ["charge", "summon", "buff"]:
		it.cancelled = true
		out.append(UIKit.f("ev_void", {"who": t.name, "act": UIKit.t("act_" + it.act)}))
	else:
		out.append(UIKit.f("ev_down", {"who": t.name}))
	_check_win()

func _check_win() -> void:
	if result == "" and enemies().is_empty():
		result = "win"
		out.append("[结果] " + UIKit.t("ui_win"))

func _enemy_act(it: Dictionary) -> void:
	var e = unit(it.uid)
	if e == null or not e.alive or it.cancelled: return
	var move := UIKit.t(it.move)
	match it.act:
		"attack":
			for h in it.hits:
				if result != "": break
				_hit(it.target, int(it.power), e, move, true)
		"all":
			for a in allies():
				if result != "": break
				_hit(a.uid, int(it.power), e, move, false)
		"charge":
			var th: Dictionary = it.then.duplicate()
			th.target = it.get("then_target", th.get("target", "lowest_hp"))
			e.pending = th
			out.append(UIKit.f("ev_charge", {"who": e.name}))
		"summon":
			var room := int(P.enemy_cap) - enemies().size()
			var n := mini(it.count, room)
			var what := UIKit.t(Data.enemy(it.what).get("name", it.what))
			for i in n:
				_add_enemy(it.what, true)
			if n > 0:
				out.append(UIKit.f("ev_summon", {"who": e.name, "n": n, "what": what}))
			else:
				out.append(UIKit.f("ev_summon_none", {"who": e.name}))
		"buff":
			for x in enemies():
				if x.get("kind", "") == e.get("kind", ""): x.str += int(it.n)
			out.append(UIKit.f("ev_buff", {"who": e.name, "move": move, "n": it.n}))
		"weak":
			var t = unit(it.target)
			if t == null or not t.alive: t = unit(_lowest())
			if t != null:
				t.weak += int(it.n)
				out.append(UIKit.f("ev_weak_on", {"who": e.name, "move": move, "target": t.name, "n": it.n}))
		"block":
			e.block += int(it.n)
			out.append(UIKit.f("ev_enemy_block", {"who": e.name, "move": move, "n": it.n}))

## 敌人打我方一下：目标倒了改打血最少的；凯「挡在前面」把打向别人的一下拉到自己身上
func _hit(target_uid: String, power: int, e: Dictionary, move: String, single: bool) -> void:
	var t = unit(target_uid)
	if t == null or not t.alive:
		t = unit(_lowest())
		if t == null: return
	var kay = unit("kay")
	if single and t.uid != "kay" and kay != null and kay.alive and kay.cover:
		out.append(UIKit.f("ev_cover", {"target": t.name}))
		t = kay
	var d := hit_damage(power, e, t)
	var bl := mini(t.block, d)
	t.block -= bl
	var lost := d - bl
	var note := UIKit.f("ev_blocked", {"n": bl}) if bl > 0 else ""
	if t.hp - lost <= 0 and A.stand and not stand_used:
		stand_used = true
		lost = t.hp - 1
		note += UIKit.t("ev_stand")
	t.hp = maxi(0, t.hp - lost)
	out.append(UIKit.f("ev_hit", {"who": e.name, "move": move, "target": t.name, "n": lost}) + note)
	if t.hp == 0:
		t.alive = false
		out.append(UIKit.f("ev_down", {"who": t.name}))
		_check_lose()

func _check_lose() -> void:
	if allies().is_empty():
		result = "lose"
		out.append("[结果] " + UIKit.t("ui_lose"))

## 逃跑：不打了，回上次祈祷的圣龛（剧情战不能逃）
func flee() -> bool:
	if not can_flee() or result != "": return false
	result = "flee"
	out.append("[结果] " + UIKit.t("ui_fled"))
	return true

## 这一仗结束时每个人剩多少血（倒下的站起来剩 revive 点）
func hp_after(revive: int) -> Dictionary:
	var r := {}
	for u in allies(false):
		r[u.uid] = u.hp if u.hp > 0 else revive
	return r

func take_log() -> Array:
	var a := out
	out = []
	return a
