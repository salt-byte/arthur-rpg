class_name Battle
extends RefCounted
## 回合制战斗的规则，照 design/systems/combat.md；数全部从 content/data/combat.json 读。
## 只管算，不管画：BattleView 和 --playtest 都调这里。
## 一回合：亮出意图 → 你排行动（queue）→ end_turn()：你们按排的先后出手 → 敌人按顺序出手 → 回法力 → 下一回合亮意图。
## 敌人怎么出手由 pattern 轮着用，不看运气：同一场重来，同样的操作，意图逐字一样。

var P: Dictionary
var enc_id := ""
var enc: Dictionary
var units: Array = []       # 单位：{uid, id, side, name, hp, max, armor, weapon, alive, defend, ward, cover, pattern, ptr, pending}
var turn := 0
var mana := 0
var mana_max := 0
var intents: Array = []     # 这回合敌人要做的事，按出手顺序：{uid, act, move, power, target, then, what, count, order, cancelled}
var queue: Array = []       # 你这回合排的行动：{who, act, target}
var result := ""            # "" 还在打 / "win" / "lose"
var out: Array = []         # 发生的事（文字），界面和测试取走后清空
var chapter := 1
var vars := {}
var unlocks: Array = []
var _focus_bonus := 0
var _setup_args := []

const SPELL_ORDER := ["spark", "ward", "focus", "interrupt", "still_water", "deflect", "reveal"]

func setup(id: String, party: Array, chapter_: int, unlocks_: Array, vars_: Dictionary) -> void:
	_setup_args = [id, party.duplicate(), chapter_, unlocks_.duplicate(), vars_.duplicate()]
	P = Data.t("combat")
	enc_id = id
	enc = Data.encounter(id)
	chapter = chapter_
	unlocks = unlocks_
	vars = vars_
	units = []
	turn = 0
	queue = []
	intents = []
	result = ""
	out = []
	var ap: Dictionary = P.apprentice
	units.append(_unit("apprentice", "ally", UIKit.t("ui_you"), int(ap.hp), int(ap.get("armor", 0)), 0))
	for c in party:
		var cd: Dictionary = P.companions.get(c, {})
		var st := cd
		if cd.has("by_chapter"):
			st = cd.by_chapter.get(str(chapter), cd.by_chapter.values()[-1])
		units.append(_unit(c, "ally", cd.get("name", c), int(st.get("hp", cd.get("hp", 10))), int(cd.get("armor", 0)), int(st.get("weapon", cd.get("weapon", 0)))))
	for e in enc.get("enemies", []):
		_add_enemy(e)
	mana_max = int(P.mana_max)
	mana = int(P.mana_start)
	begin_turn()

## 输了「再来一次」：用开场时的参数重来
func restart() -> void:
	setup(_setup_args[0], _setup_args[1], _setup_args[2], _setup_args[3], _setup_args[4])

func _unit(id: String, side: String, name: String, hp: int, armor: int, weapon: int) -> Dictionary:
	return {"uid": id, "id": id, "side": side, "name": name, "hp": hp, "max": hp, "armor": armor, "weapon": weapon,
		"alive": true, "defend": false, "ward": 0, "cover": false, "pattern": [], "ptr": 0, "pending": null}

func _add_enemy(eid: String) -> Dictionary:
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
	var u := _unit(uid, "enemy", name, int(ed.hp), int(ed.get("armor", 0)), 0)
	u.id = eid
	u.pattern = ed.get("pattern", [])
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
	if ("spell_" + s) in unlocks: return true
	for u in Data.t("story-unlocks").get("unlocks", []):
		if u.get("kind", "") == "spell" and u.get("what", "") == s and u.id in unlocks:
			return chapter >= int(u.get("usable_from_chapter", 1))
	return false

func spells() -> Array:
	return SPELL_ORDER.filter(func(s): return has_spell(s) and P.spells.has(s))

func spell_cost(s: String) -> int:
	return int(P.spells[s].get("mana", 0))

## 这个人这回合能选的行动 id
func actions_for(uid: String) -> Array:
	if uid == "apprentice":
		return spells().filter(func(s): return not P.spells[s].get("free_action", false))
	var a := ["attack", "defend"]
	if uid == "kay" and _kay_cover_ok(): a.append("kay_cover")
	return a

## 凯「挡在前面」：第 1 章出发前一晚谁都没告诉（D1c），第 4 章起
func _kay_cover_ok() -> bool:
	return str(vars.get("D1", "")) == "D1c" and chapter >= 4

## 行动要不要选目标：enemy / ally / ""
func target_kind(act: String) -> String:
	match act:
		"spark", "attack", "interrupt": return "enemy"
		"ward": return "ally"
	return ""

## 法力里已经被排进队列的法术占掉的
func reserved() -> int:
	var r := 0
	for q in queue:
		if P.spells.has(q.act): r += spell_cost(q.act)
	return r

func mana_left() -> int:
	return mana - reserved()

## 能不能把这个行动排进去；不能时返回原因（文本），能时返回 ""
func why_not(uid: String, act: String) -> String:
	var u = unit(uid)
	if u == null or not u.alive: return "dead"
	var own := 0
	for q in queue:
		if q.who == uid and P.spells.has(q.act): own = spell_cost(q.act)
	if P.spells.has(act) and spell_cost(act) > mana_left() + own:
		return UIKit.f("ui_no_mana", {"need": spell_cost(act), "left": mana_left() + own})
	if act == "interrupt" and interruptible().is_empty():
		return UIKit.f("ui_no_interrupt")
	return ""

## 这回合在蓄力或召唤、还没被打断的敌人
func interruptible() -> Array:
	var a := []
	for it in intents:
		var e = unit(it.uid)
		if e != null and e.alive and not it.cancelled and it.act in ["charge", "summon"]:
			a.append(it.uid)
	return a

func valid_targets(act: String) -> Array:
	match target_kind(act):
		"enemy":
			if act == "interrupt": return interruptible()
			return enemies().map(func(e): return e.uid)
		"ally":
			return allies().map(func(a): return a.uid)
	return []

## 排一个行动（同一个人再排就换掉原来那个，排到最后）
func plan(uid: String, act: String, target := "") -> bool:
	unplan(uid)
	if why_not(uid, act) != "": return false
	if target_kind(act) != "" and not target in valid_targets(act): return false
	queue.append({"who": uid, "act": act, "target": target})
	return true

func unplan(uid: String) -> void:
	queue = queue.filter(func(q): return q.who != uid)

func planned(uid: String):
	for q in queue:
		if q.who == uid: return q
	return null

# ---------------- 意图 ----------------
func begin_turn() -> void:
	turn += 1
	intents = []
	for u in allies(false):
		u.defend = false
		u.ward = 0
		u.cover = false
	var order := 1
	for e in enemies():
		e.defend = false
		var it := _make_intent(e)
		it.order = order
		order += 1
		if it.act == "defend": e.defend = true
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
		"target": "", "then": src.get("then", null), "what": src.get("what", ""), "count": int(src.get("count", 0)),
		"order": 0, "cancelled": false, "release": release}
	if it.act == "attack":
		it.target = _resolve(src.get("target", "lowest_hp"))
		if it.target == "all":
			it.act = "all"
	elif it.act == "charge" and it.then != null:
		it.then_target = _resolve(it.then.get("target", "lowest_hp"))
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
			return UIKit.f("intent_attack", {"who": who, "move": UIKit.t(it.move), "target": _name(it.target), "n": it.power})
		"all":
			return UIKit.f("intent_all", {"who": who, "move": UIKit.t(it.move), "n": it.power})
		"charge":
			var th: Dictionary = it.then
			return UIKit.f("intent_charge", {"who": who, "move": UIKit.t(th.get("move", "")), "target": _name(it.get("then_target", "")), "n": int(th.get("power", 0))})
		"summon":
			return UIKit.f("intent_summon", {"who": who, "n": it.count})
		"defend":
			return UIKit.f("intent_defend", {"who": who})
	return who

func _name(uid: String) -> String:
	var u = unit(uid)
	return u.name if u != null else uid

# ---------------- 结算 ----------------
## 一步一步记下这回合发生了什么，界面照着一来一回地播：
## {side: "ally"/"enemy"/"end", who, target, lines, hp: {uid: [hp, alive]}, order}
var steps: Array = []

func end_turn() -> void:
	if result != "": return
	var q := queue.duplicate()
	queue = []
	steps = []
	_focus_bonus = 0
	for i in q.size():
		if result != "": break
		var mark := out.size()
		_do(q[i])
		_step("ally", q[i].who, q[i].target, mark, i + 1)
	for it in intents:
		if result != "": break
		var mark := out.size()
		_enemy_act(it)
		_step("enemy", it.uid, it.get("target", ""), mark, it.order)
	if result != "": return
	var mark := out.size()
	mana = mini(mana_max, mana + int(P.mana_regen) + _focus_bonus)
	out.append(UIKit.f("ev_mana", {"n": mana}))
	begin_turn()
	_step("end", "", "", mark, 0)

func _step(side: String, who: String, target: String, mark: int, order: int) -> void:
	var lines := out.slice(mark)
	if lines.is_empty() and side != "end": return
	var hp := {}
	for u in units: hp[u.uid] = [u.hp, u.alive]
	steps.append({"side": side, "who": who, "target": target, "lines": lines, "hp": hp, "order": order})

## 照现在排的行动试算一遍这回合，不改真的战斗：返回 {uid: 打完以后的血}
func preview() -> Dictionary:
	var c := Battle.new()
	c.P = P
	c.enc_id = enc_id
	c.enc = enc
	c.chapter = chapter
	c.vars = vars
	c.unlocks = unlocks
	c.units = units.duplicate(true)
	c.turn = turn
	c.mana = mana
	c.mana_max = mana_max
	c.intents = intents.duplicate(true)
	c.queue = queue.duplicate(true)
	c.end_turn()
	var r := {}
	for u in units:
		var cu = c.unit(u.uid)
		r[u.uid] = cu.hp if cu != null else u.hp
	return r

func _do(a: Dictionary) -> void:
	var u = unit(a.who)
	if u == null or not u.alive: return
	var act: String = a.act
	if P.spells.has(act):
		if spell_cost(act) > mana: return
		if act == "interrupt":
			var it = intent_of(a.target)
			var t = unit(a.target)
			if it == null or t == null or not t.alive or it.cancelled or not it.act in ["charge", "summon"]:
				return
			mana -= spell_cost(act)
			it.cancelled = true
			out.append(UIKit.f("ev_cancel", {"who": t.name, "act": UIKit.t("act_" + it.act)}))
			return
		mana -= spell_cost(act)
		match act:
			"spark":
				var t = unit(a.target)
				if t == null or not t.alive:
					t = enemies()[0] if not enemies().is_empty() else null
				if t != null:
					var d := _dmg_to_enemy(t, int(P.spells.spark.damage))
					out.append(UIKit.f("ev_spark", {"target": t.name, "n": d}))
					_check_enemy_down(t)
			"ward":
				var t = unit(a.target)
				if t != null and t.alive:
					t.ward = int(P.spells.ward.absorb)
					out.append(UIKit.f("ev_ward_cast", {"target": t.name}))
			"focus":
				_focus_bonus = int(P.focus_bonus)
				out.append(UIKit.f("ev_focus", {"n": _focus_bonus}))
		return
	match act:
		"attack":
			var t = unit(a.target)
			if t == null or not t.alive:
				t = enemies()[0] if not enemies().is_empty() else null
			if t != null:
				var d := _dmg_to_enemy(t, int(u.weapon))
				out.append(UIKit.f("ev_attack", {"who": u.name, "target": t.name, "n": d}))
				_check_enemy_down(t)
		"defend":
			u.defend = true
			out.append(UIKit.f("ev_defend_act", {"who": u.name}))
		"kay_cover":
			u.cover = true

func _dmg_to_enemy(t: Dictionary, power: int) -> int:
	var d := maxi(int(P.min_damage), power - int(t.armor))
	if t.defend: d = ceili(d * float(P.defend_factor))
	t.hp = maxi(0, t.hp - d)
	return d

func _check_enemy_down(t: Dictionary) -> void:
	if t.hp > 0: return
	t.alive = false
	var it = intent_of(t.uid)
	if it != null and not it.cancelled and it.act in ["charge", "summon"]:
		it.cancelled = true
		out.append(UIKit.f("ev_void", {"who": t.name, "act": UIKit.t("act_" + it.act)}))
	else:
		out.append(UIKit.f("ev_down", {"who": t.name}))
	if enemies().is_empty():
		result = "win"
		out.append("[结果] " + UIKit.t("ui_win"))

func _enemy_act(it: Dictionary) -> void:
	var e = unit(it.uid)
	if e == null or not e.alive or it.cancelled: return
	var move := UIKit.t(it.move)
	match it.act:
		"attack":
			_hit(it.target, it.power, e.name, move, true)
		"all":
			for a in allies():
				if result != "": break
				_hit(a.uid, it.power, e.name, move, false)
		"charge":
			var th: Dictionary = it.then.duplicate()
			th.target = it.get("then_target", th.get("target", "lowest_hp"))
			e.pending = th
			out.append(UIKit.f("ev_charge", {"who": e.name}))
		"summon":
			var room := int(P.enemy_cap) - enemies().size()
			var n := mini(it.count, room)
			var what := ""
			for i in n:
				var s := _add_enemy(it.what)
				what = UIKit.t(Data.enemy(it.what).get("name", it.what))
			if n > 0:
				out.append(UIKit.f("ev_summon", {"who": e.name, "n": n, "what": what}))
		"defend":
			pass

func _hit(target_uid: String, power: int, who: String, move: String, single: bool) -> void:
	var t = unit(target_uid)
	if t == null or not t.alive:
		t = unit(_lowest())
		if t == null: return
	var reduce := 0
	var kay = unit("kay")
	if single and t.uid != "kay" and kay != null and kay.alive and kay.cover:
		out.append(UIKit.f("ev_cover", {"target": t.name}))
		t = kay
		reduce = int(P.kay_cover_reduce)
	var d := maxi(int(P.min_damage), power - int(t.armor))
	var note := ""
	if t.defend:
		d = ceili(d * float(P.defend_factor))
		note += UIKit.f("ev_defend")
	d = maxi(0, d - reduce)
	if t.ward > 0:
		var ab := mini(t.ward, d)
		t.ward -= ab
		d -= ab
		note += UIKit.f("ev_ward", {"n": ab})
	t.hp = maxi(0, t.hp - d)
	out.append(UIKit.f("ev_hit", {"who": who, "move": move, "target": t.name, "n": d}) + note)
	if t.hp == 0:
		t.alive = false
		out.append(UIKit.f("ev_down", {"who": t.name}))
		_check_lose()

func _check_lose() -> void:
	var ap = unit("apprentice")
	var comps := units.filter(func(u): return u.side == "ally" and u.uid != "apprentice")
	var all_comps_down := not comps.is_empty() and comps.all(func(u): return not u.alive)
	if (ap != null and not ap.alive) or all_comps_down:
		result = "lose"
		out.append("[结果] " + UIKit.t("ui_lose"))

func take_log() -> Array:
	var a := out
	out = []
	return a
