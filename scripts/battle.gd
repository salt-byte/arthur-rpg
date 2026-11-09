class_name Battle
extends RefCounted
## 回合制战斗的规则，照 design/systems/combat.md（敌人意图照《杀戮尖塔》）；数全部从 content/data/combat.json 读，
## 学徒和同伴这一刻的数（技能树、装备、随机奖励加过的）由 Party.battle_ctx() 算好传进来。
## 伤害公式只有一处：scripts/mechanics/intent-battle/status_rules.gd 的 hit_damage()（mechanics-library 带进来的，测试照原作核对过）。
## 只管算，不管画：BattleView 和 --playtest 都调这里。
## 一回合：亮出意图 → 你给每人排一个行动（queue）→ end_turn()：你们按学徒、同伴一、同伴二出手（你们的虚弱易伤减 1）
##   → 敌人按标好的顺序出手（敌人的虚弱易伤减 1）→ 下一回合：我方格挡清零、学徒回 1 法力、亮新意图。
## 敌人按招式表轮着出，不看运气：同一场重来，同样的操作，意图逐字一样。

const Rules := preload("res://scripts/mechanics/intent-battle/status_rules.gd")
const SPELL_ORDER := ["spark", "ward", "focus", "interrupt", "blind", "twin_spark", "fire_rain", "haze", "still_water", "deflect", "reveal"]

var P: Dictionary              # combat.json
var cfg: Dictionary            # P.rules
var ctx: Dictionary            # Party.battle_ctx()：我方的数
var enc_id := ""
var enc: Dictionary
var units: Array = []          # {uid, id, side, name, hp, max, power, alive, block, strength, weak, vulnerable, pattern, ptr, pending, kind, boss, summoned}
var turn := 0
var mana := 0
var mana_max := 0
var potions := {}              # 背包里的药，用掉就少；打完由 main 写回 Party
var intents: Array = []        # 这回合敌人要做的事：{uid, order, act, move, power, hits, target, then, then_target, what, count, strength, stacks, block, cancelled, release}
var queue: Array = []          # 你这回合排的行动：{who, act, target}
var result := ""               # "" 还在打 / win / lose / flee
var out: Array = []            # 发生的事（文字），界面和测试取走后清空
var steps: Array = []          # 这回合一步一步发生了什么，界面照着一来一回地播
var killed: Array = []         # 打倒的敌人 id（召唤出来的不算），结算经验和掉落用
var chapter := 1
var vars := {}
var _start: Dictionary = {}
var _cover := false
var _stand_used := false

func setup(id: String, ctx_: Dictionary, chapter_: int, vars_: Dictionary) -> void:
	P = Data.t("combat")
	cfg = P.get("rules", {})
	enc_id = id
	enc = Data.encounter(id)
	ctx = ctx_
	chapter = chapter_
	vars = vars_
	units = []
	turn = 0
	queue = []
	intents = []
	result = ""
	out = []
	steps = []
	killed = []
	for a in ctx.allies:
		var u := _unit(str(a.uid), "ally", str(a.name), int(a.max), int(a.power))
		u.hp = clampi(int(a.hp), 1, int(a.max))
		units.append(u)
	for e in enc.get("enemies", []):
		_add_enemy(e, false)
	mana_max = int(ctx.mana_max)
	mana = mana_max if int(P.mana_start) >= int(P.mana_max) else mini(mana_max, int(P.mana_start))
	potions = ctx.get("potions", {}).duplicate()
	# 开打时的效果：看穿（技能树）、明眼（装备）、守夜（装备）
	var st: Dictionary = ctx.get("start", {})
	if int(st.get("all_enemies_vulnerable", 0)) > 0:
		for e in enemies(): e.vulnerable += int(st.all_enemies_vulnerable)
		out.append(UIKit.f("ev_start_see", {"n": int(st.all_enemies_vulnerable)}))
	if int(st.get("top_hp_vulnerable", 0)) > 0 and not enemies().is_empty():
		var top = enemies()[0]
		for e in enemies():
			if e.hp > top.hp: top = e
		top.vulnerable += int(st.top_hp_vulnerable)
		out.append(UIKit.f("ev_start_keen", {"who": top.name, "n": int(st.top_hp_vulnerable)}))
	_start = {"units": units.duplicate(true), "mana": mana, "potions": potions.duplicate(), "out": out.duplicate()}
	begin_turn()

## 输了「再来一次」：回到开打那一刻，血量和敌人都原样
func restart() -> void:
	units = _start.units.duplicate(true)
	mana = int(_start.mana)
	potions = _start.potions.duplicate()
	turn = 0
	queue = []
	intents = []
	result = ""
	out = _start.out.duplicate()
	steps = []
	killed = []
	_stand_used = false
	begin_turn()

func _unit(id: String, side: String, name: String, hp: int, power: int) -> Dictionary:
	return {"uid": id, "id": id, "side": side, "name": name, "hp": hp, "max": hp, "power": power, "alive": true,
		"block": 0, "strength": 0, "weak": 0, "vulnerable": 0, "fresh": {}, "pattern": [], "ptr": 0, "pending": null,
		"kind": "", "boss": false, "summoned": false}

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
	u.kind = str(ed.get("kind", ""))
	u.boss = bool(ed.get("boss", false))
	u.summoned = summoned
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

func is_story() -> bool:
	return str(enc.get("kind", "")) == "story"

func can_flee() -> bool:
	return bool(P.get("flee_allowed", true)) and bool(enc.get("flee", true)) and not is_story() and result == ""

func has_spell(s: String) -> bool:
	return ctx.get("spells", {}).has(s)

func spell(s: String) -> Dictionary:
	return ctx.get("spells", {}).get(s, {})

func spells() -> Array:
	return SPELL_ORDER.filter(func(s): return has_spell(s) and not bool(spell(s).get("free_action", false)))

func spell_cost(s: String) -> int:
	return int(spell(s).get("mana", 0))

## 这个人这回合能选的行动 id
func actions_for(uid: String) -> Array:
	var a := []
	if uid == "apprentice":
		a = spells()
	else:
		a = ["attack", "guard"]
		if uid == "kay" and _kay_cover_ok(): a.append("kay_cover")
	if int(potions.get("potion_hp", 0)) > 0: a.append("potion_hp")
	if uid == "apprentice" and int(potions.get("potion_mana", 0)) > 0: a.append("potion_mana")
	return a

## 凯「挡在前面」：第 1 章出发前一晚谁都没告诉（D1c），第 4 章起
func _kay_cover_ok() -> bool:
	return str(vars.get("D1", "")) == "D1c" and chapter >= 4

## 行动要不要选目标：enemy / ally / ""
func target_kind(act: String) -> String:
	match act:
		"spark", "attack", "interrupt", "blind", "twin_spark": return "enemy"
		"ward", "potion_hp": return "ally"
	return ""

## 法力里已经被排进队列的法术占掉的
func reserved() -> int:
	var r := 0
	for q in queue:
		if has_spell(q.act): r += spell_cost(q.act)
	return r

func mana_left() -> int:
	return mana - reserved()

func _potions_reserved(kind: String) -> int:
	return queue.filter(func(q): return q.act == kind).size()

## 能不能把这个行动排进去；不能时返回原因（文本），能时返回 ""
func why_not(uid: String, act: String) -> String:
	var u = unit(uid)
	if u == null or not u.alive: return "dead"
	var own = planned(uid)
	if has_spell(act):
		var back := spell_cost(own.act) if own != null and has_spell(own.act) else 0
		if spell_cost(act) > mana_left() + back:
			return UIKit.f("ui_no_mana", {"need": spell_cost(act), "left": mana_left() + back})
	if act == "interrupt" and interruptible().is_empty():
		return UIKit.f("ui_no_interrupt")
	if act in ["potion_hp", "potion_mana"]:
		var back := 1 if own != null and own.act == act else 0
		if int(potions.get(act, 0)) - _potions_reserved(act) + back <= 0:
			return UIKit.t("ui_no_potion")
		if act == "potion_hp" and valid_targets(act).is_empty():
			return UIKit.t("ui_all_full")
	return ""

## 这回合在蓄力、召唤或长嚎、还没被打断的敌人
func interruptible() -> Array:
	var a := []
	for it in intents:
		var e = unit(it.uid)
		if e != null and e.alive and not it.cancelled and it.act in spell("interrupt").get("cancels", ["charge", "summon", "buff"]):
			a.append(it.uid)
	return a

func valid_targets(act: String) -> Array:
	match target_kind(act):
		"enemy":
			if act == "interrupt": return interruptible()
			return enemies().map(func(e): return e.uid)
		"ally":
			if act == "potion_hp": return allies().filter(func(a): return a.hp < a.max).map(func(a): return a.uid)
			return allies().map(func(a): return a.uid)
	return []

## 排一个行动（同一个人再排就换掉原来那个，出手顺序不变：照学徒、同伴一、同伴二）
func plan(uid: String, act: String, target := "") -> bool:
	if why_not(uid, act) != "": return false
	if target_kind(act) != "" and not target in valid_targets(act): return false
	unplan(uid)
	queue.append({"who": uid, "act": act, "target": target})
	var order := allies(false).map(func(a): return a.uid)
	queue.sort_custom(func(x, y): return order.find(x.who) < order.find(y.who))
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
	_cover = false
	for u in allies(false): u.block = 0          # 我方格挡在自己回合开始清零（照原作）
	if turn >= int(P.get("mana_regen_from_turn", 2)):
		mana = mini(mana_max, mana + int(ctx.get("mana_regen", P.mana_regen)))
	if turn == 1 and int(ctx.get("start", {}).get("apprentice_block", 0)) > 0:
		var ap = unit("apprentice")
		if ap != null:
			ap.block += int(ctx.start.apprentice_block)
			out.append(UIKit.f("ev_start_vigil", {"n": int(ctx.start.apprentice_block)}))
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
	var it := {"uid": e.uid, "order": 0, "act": str(src.get("act", "attack")), "move": str(src.get("move", "")),
		"power": int(src.get("power", 0)), "hits": maxi(1, int(src.get("hits", 1))), "target": "", "then": src.get("then", null),
		"then_target": "", "what": str(src.get("what", "")), "count": int(src.get("count", 0)), "strength": int(src.get("strength", 0)),
		"stacks": int(src.get("stacks", 0)), "block": int(src.get("block", 0)), "cancelled": false, "release": release,
		"lethal": bool(src.get("lethal", false))}
	match it.act:
		"attack", "weak":
			it.target = _resolve(str(src.get("target", "lowest_hp")))
		"charge":
			if it.then != null: it.then_target = _resolve(str(it.then.get("target", "lowest_hp")))
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

## 一个敌人打某人一下是几点：已算它的力量、虚弱和目标的易伤（不扣格挡，格挡另显示）
func intent_damage(it: Dictionary, target_uid := "") -> int:
	var e = unit(it.uid)
	var t = unit(target_uid if target_uid != "" else it.target)
	if e == null: return 0
	var power := int(it.power)
	var lethal: bool = it.get("lethal", false)
	if it.act == "charge" and it.then != null:
		power = int(it.then.get("power", 0))
		lethal = bool(it.then.get("lethal", false))
		if t == null: t = unit(it.then_target)
	if lethal and t != null: return int(t.hp) + int(t.block)   # 梅林的影子的重劈：挨上就倒（自创，见 combat.md 改动记录）
	return Rules.hit_damage(power, e, t if t != null else {"vulnerable": 0}, cfg)

func intent_text(it: Dictionary) -> String:
	var e = unit(it.uid)
	var who: String = e.name
	var move := UIKit.t(it.move)
	match it.act:
		"attack":
			if it.target == "all":
				return UIKit.f("intent_all", {"who": who, "move": move, "n": intent_damage(it, allies()[0].uid if not allies().is_empty() else "")})
			var n := str(intent_damage(it)) + ("×%d" % it.hits if it.hits > 1 else "")
			return UIKit.f("intent_attack", {"who": who, "move": move, "target": _name(it.target), "n": n})
		"charge":
			var th: Dictionary = it.then
			return UIKit.f("intent_charge", {"who": who, "move": UIKit.t(th.get("move", "")), "target": _name(it.then_target), "n": intent_damage(it)})
		"summon":
			return UIKit.f("intent_summon", {"who": who, "move": move, "n": it.count, "what": UIKit.t(Data.enemy(it.what).get("name", it.what))})
		"buff":
			return UIKit.f("intent_buff", {"who": who, "move": move, "n": it.strength})
		"weak":
			return UIKit.f("intent_weak", {"who": who, "move": move, "target": _name(it.target), "n": it.stacks})
		"block":
			return UIKit.f("intent_block", {"who": who, "move": move, "n": it.block})
	return who

func _name(uid: String) -> String:
	var u = unit(uid)
	return u.name if u != null else uid

# ---------------- 结算 ----------------
func end_turn() -> void:
	if result != "": return
	var q := queue.duplicate()
	queue = []
	steps = []
	for i in q.size():
		if result != "": break
		var mark := out.size()
		_do(q[i])
		_step("ally", q[i].who, q[i].target, mark, i + 1)
	for u in allies(false): Rules.tick(u, false)       # 你们的虚弱、易伤在你们出完手时减 1
	for it in intents:
		if result != "": break
		var mark := out.size()
		_enemy_act(it)
		_step("enemy", it.uid, it.get("target", ""), mark, it.order)
	if result != "": return
	for u in enemies(false): Rules.tick(u, false)      # 敌人的在敌人出完手时减 1
	var mark := out.size()
	begin_turn()
	_step("end", "", "", mark, 0)

func _step(side: String, who: String, target: String, mark: int, order: int) -> void:
	var lines := out.slice(mark)
	if lines.is_empty() and side != "end": return
	var hp := {}
	for u in units: hp[u.uid] = [u.hp, u.alive]
	steps.append({"side": side, "who": who, "target": target, "lines": lines, "hp": hp, "order": order})

## 不打了：回到上一次祈祷过的圣龛。剧情战不能逃
func flee() -> bool:
	if not can_flee(): return false
	result = "flee"
	out.append("[结果] " + UIKit.t("ui_fled"))
	return true

## 照现在排的行动试算一遍这回合，不改真的战斗：返回 {uid: 打完以后的血}
func preview() -> Dictionary:
	var c := Battle.new()
	c.P = P
	c.cfg = cfg
	c.ctx = ctx
	c.enc_id = enc_id
	c.enc = enc
	c.chapter = chapter
	c.vars = vars
	c.units = units.duplicate(true)
	c.turn = turn
	c.mana = mana
	c.mana_max = mana_max
	c.potions = potions.duplicate()
	c.intents = intents.duplicate(true)
	c.queue = queue.duplicate(true)
	c.killed = killed.duplicate()
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
	if has_spell(act):
		var sp := spell(act)
		if spell_cost(act) > mana: return
		mana -= spell_cost(act)
		match act:
			"spark":
				var t = _enemy_target(a.target)
				if t == null: return
				var d := _hit(u, t, int(sp.damage))
				if t.alive:
					t.vulnerable += int(sp.get("vulnerable", 1))
				out.append(UIKit.f("ev_spark", {"target": t.name, "n": d, "v": int(sp.get("vulnerable", 1))}) + _down_note(t))
				_check_enemy_down(t)
			"twin_spark":
				var first = _enemy_target(a.target)
				var list := [first] if first != null else []
				for e in enemies():
					if list.size() >= int(sp.get("targets", 2)): break
					if not e in list: list.append(e)
				for t in list:
					var d := _hit(u, t, int(sp.damage))
					out.append(UIKit.f("ev_spark", {"target": t.name, "n": d, "v": 0}) + _down_note(t))
					_check_enemy_down(t)
			"fire_rain":
				for t in enemies():
					var d := _hit(u, t, int(sp.damage))
					out.append(UIKit.f("ev_rain", {"target": t.name, "n": d}) + _down_note(t))
					_check_enemy_down(t)
			"blind":
				var t = _enemy_target(a.target)
				if t == null: return
				t.weak += int(sp.weak)
				out.append(UIKit.f("ev_blind", {"target": t.name, "n": int(sp.weak)}))
			"haze":
				for t in enemies(): t.weak += int(sp.weak)
				out.append(UIKit.f("ev_haze", {"n": int(sp.weak)}))
			"ward":
				var list := [unit(a.target)] if unit(a.target) != null and unit(a.target).alive else [u]
				if int(sp.get("targets", 1)) > 1:
					for x in allies():
						if list.size() >= int(sp.targets): break
						if not x in list: list.append(x)
				for t in list:
					t.block += int(sp.block)
					out.append(UIKit.f("ev_ward_cast", {"target": t.name, "n": int(sp.block)}))
			"focus":
				var n := int(sp.get("restore_mana", 2))
				mana = mini(mana_max, mana + n)
				out.append(UIKit.f("ev_focus", {"n": n}))
			"interrupt":
				var it = intent_of(a.target)
				var t = unit(a.target)
				if it == null or t == null or not t.alive or it.cancelled:
					out.append(UIKit.t("ev_interrupt_miss"))
					return
				it.cancelled = true
				out.append(UIKit.f("ev_cancel", {"who": t.name, "act": UIKit.t("act_" + it.act)}))
				if int(ctx.get("start", {}).get("interrupt_vulnerable", 0)) > 0:
					t.vulnerable += int(ctx.start.interrupt_vulnerable)
		return
	match act:
		"attack":
			var t = _enemy_target(a.target)
			if t == null: return
			var d := _hit(u, t, int(u.power))
			out.append(UIKit.f("ev_attack", {"who": u.name, "target": t.name, "n": d}) + _down_note(t))
			_check_enemy_down(t)
		"guard":
			var n := int(ctx.get("guard_block", P.guard_block))
			u.block += n
			out.append(UIKit.f("ev_guard", {"who": u.name, "n": n}))
		"kay_cover":
			_cover = true
			u.block += int(P.kay_cover_block)
			out.append(UIKit.f("ev_cover_cast", {"n": int(P.kay_cover_block)}))
		"potion_hp":
			if int(potions.get("potion_hp", 0)) <= 0: return
			var t = unit(a.target)
			if t == null or not t.alive: t = u
			potions.potion_hp = int(potions.potion_hp) - 1
			var heal := mini(int(ctx.get("potion_heal", 6)), t.max - t.hp)
			t.hp += heal
			out.append(UIKit.f("ev_potion", {"who": u.name, "target": t.name, "n": heal}))
		"potion_mana":
			if int(potions.get("potion_mana", 0)) <= 0: return
			potions.potion_mana = int(potions.potion_mana) - 1
			var n := int(ctx.get("potion_mana", 3))
			mana = mini(mana_max, mana + n)
			out.append(UIKit.f("ev_potion_mana", {"n": n}))

## 目标中途倒下：改打站位最前的活敌人（rules.party_retarget = next_enemy）
func _enemy_target(uid: String):
	var t = unit(uid)
	if t != null and t.alive and t.side == "enemy": return t
	if enemies().is_empty(): return null
	var nt = enemies()[0]
	if t != null: out.append(UIKit.f("ev_retarget", {"target": nt.name}))
	return nt

## 打一下：伤害照 status_rules.hit_damage（先加力量，再乘虚弱、易伤，最后向下取整），先扣格挡。返回掉的血
func _hit(src: Dictionary, t: Dictionary, base: int) -> int:
	var dealt := Rules.hit_damage(base, src, t, cfg)
	var ab: Array = Rules.absorb(t, dealt)
	t.hp = maxi(0, t.hp - int(ab[1]))
	t["_last_blocked"] = int(ab[0])
	return int(ab[1])

func _down_note(t: Dictionary) -> String:
	var s := ""
	if int(t.get("_last_blocked", 0)) > 0: s += UIKit.f("ev_blocked", {"n": int(t._last_blocked)})
	t["_last_blocked"] = 0
	return s

func _check_enemy_down(t: Dictionary) -> void:
	if t.hp > 0 or not t.alive: return
	t.alive = false
	if not t.summoned: killed.append(t.id)
	var it = intent_of(t.uid)
	if it != null and not it.cancelled and it.act in ["charge", "summon", "buff"]:
		it.cancelled = true
		out.append(UIKit.f("ev_void", {"who": t.name, "act": UIKit.t("act_" + it.act)}))
	else:
		if it != null: it.cancelled = true
		out.append(UIKit.f("ev_down", {"who": t.name}))
	if enemies().is_empty():
		result = "win"
		out.append("[结果] " + UIKit.t("ui_win"))

func _enemy_act(it: Dictionary) -> void:
	var e = unit(it.uid)
	if e == null or not e.alive: return
	e.block = 0                         # 敌人的格挡在它自己出手时清零（照原作）
	if it.cancelled:
		out.append(UIKit.f("ev_nothing", {"who": e.name}))
		return
	var move := UIKit.t(it.move)
	match it.act:
		"attack":
			if it.target == "all":
				for a in allies():
					if result != "": break
					_enemy_hit(e, a.uid, it, move, false)
			else:
				for h in it.hits:
					if result != "": break
					_enemy_hit(e, it.target, it, move, true)
		"charge":
			var th: Dictionary = it.then.duplicate()
			th.target = it.then_target
			e.pending = th
			out.append(UIKit.f("ev_charge", {"who": e.name, "move": UIKit.t(th.get("move", ""))}))
		"summon":
			var room := int(P.enemy_cap) - enemies().size()
			var n := mini(it.count, room)
			var what := UIKit.t(Data.enemy(it.what).get("name", it.what))
			for i in n: _add_enemy(it.what, true)
			if n > 0: out.append(UIKit.f("ev_summon", {"who": e.name, "n": n, "what": what}))
			else: out.append(UIKit.f("ev_summon_none", {"who": e.name}))
		"buff":
			var kinds := enemies().filter(func(x): return x.kind == e.kind)
			for x in kinds: x.strength += it.strength
			out.append(UIKit.f("ev_buff", {"who": e.name, "n": it.strength}))
		"weak":
			var t = unit(it.target)
			if t == null or not t.alive: t = unit(_lowest())
			if t == null: return
			t.weak += it.stacks
			out.append(UIKit.f("ev_weak", {"who": e.name, "target": t.name, "n": it.stacks}))
		"block":
			e.block += it.block
			out.append(UIKit.f("ev_enemy_block", {"who": e.name, "n": it.block}))

func _enemy_hit(e: Dictionary, target_uid: String, it: Dictionary, move: String, single: bool) -> void:
	var t = unit(target_uid)
	if t == null or not t.alive:
		t = unit(_lowest())
		if t == null: return
	var kay = unit("kay")
	if single and _cover and t.uid != "kay" and kay != null and kay.alive:
		out.append(UIKit.f("ev_cover", {"target": t.name}))
		t = kay
	var d := 0
	if it.get("lethal", false):
		t.block = 0
		d = int(t.hp)
		t.hp = 0
	else:
		d = _hit(e, t, int(it.power))
	out.append(UIKit.f("ev_hit", {"who": e.name, "move": move, "target": t.name, "n": d}) + _down_note(t))
	if t.hp == 0 and t.alive and int(ctx.get("start", {}).get("stand", 0)) > 0 and not _stand_used:
		_stand_used = true      # 不倒（技能树）：每场第一次有人血掉到 0，留 1 点
		t.hp = 1
		out.append(UIKit.f("ev_stand", {"who": t.name}))
	if t.hp == 0 and t.alive:
		t.alive = false
		out.append(UIKit.f("ev_down", {"who": t.name}))
		_check_lose()

## 三个人都倒下才输（原型的规矩）；只有学徒一个人上场的仗，学徒倒下就输
func _check_lose() -> void:
	if allies().is_empty():
		result = "lose"
		out.append("[结果] " + UIKit.t("ui_lose"))

func take_log() -> Array:
	var a := out
	out = []
	return a
