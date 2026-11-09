extends RefCounted
## 意图预告的回合制战斗（纯逻辑，不画界面），伤害和状态照杀戮尖塔的意图系统（规则在 status_rules.gd）。
## 一回合：敌人亮出意图（对谁、什么招、每下几点 × 几下，已算力量 / 虚弱 / 目标易伤）→ 你给每个队员排一个行动，
## 确认前可改、可撤、可 undo → confirm() 按 execution_order() 结算 → 回合结束状态减 1 → 下一回合亮新意图。
## 数全部从 data 读。随机只走注入的 RandomNumberGenerator，而且只在亮意图时用；结算没有随机，
## 所以 preview() 算出来的就是 confirm() 打出来的。发生的每件事都追加进 events（Array of Dictionary）。

const Rules := preload("status_rules.gd")
const DEFAULTS := {
	"weak_mult": 0.75,               # 攻击者虚弱：伤害 × 0.75（原作 25% less）
	"vulnerable_mult": 1.5,          # 目标易伤：伤害 × 1.5（原作 50% more）
	"enemy_debuff_grace": true,      # 敌人给队员上的虚弱 / 易伤，上的那回合结束时不减（未核实，见 README）
	"execution": "party_first",      # party_first / enemies_first / speed（按速度，同速我方先、再按站位）
	"party_order": "slot",           # slot 按队伍站位 / plan 按你排的先后（改行动不挪位置）
	"party_retarget": "next_enemy",  # 你的目标先倒了：next_enemy 改打站位最前的活敌人 / fizzle 落空
	"enemy_retarget": "lowest_hp",   # 敌人的目标先倒了：lowest_hp 改打血最少的队员 / fizzle 落空
}
const FX := ["block", "strength", "weak", "vulnerable"]

var cfg: Dictionary = {}
var data: Dictionary = {}
var rng: RandomNumberGenerator
var units: Array = []        # {uid, side, name, hp, max_hp, power, speed, actions, alive, strength, weak, vulnerable, block, fresh, slot, pattern, pick, ptr, pending}
var round_no := 0
var intents: Array = []      # 这回合的意图，按敌人站位：{enemy, order, act, move, damage, hits, target, predicted{uid:每下}, basis, fx, status, released, then?}
var plan: Dictionary = {}    # 队员 uid -> {action, target, predicted(每下), basis}
var plan_seq: Array = []     # 排行动的先后（party_order = plan 时决定出手顺序）
var plan_version := 0        # 计划每改一次加 1；preview() 带着它，界面拿来判断预览过没过期
var events: Array = []
var result := ""             # "" 还在打 / win / lose
var _history: Array = []
var _rng_start := 0

# ---------------- 开打 / 重来 ----------------
func setup(data_: Dictionary, rng_: RandomNumberGenerator) -> void:
	data = data_
	cfg = DEFAULTS.duplicate()
	cfg.merge(data.get("rules", {}), true)
	rng = rng_
	_rng_start = rng.state
	_reset()

## 输了重来：rng 回到开打那一刻的 state，同样的操作得到逐字一样的意图
func restart() -> void:
	rng.state = _rng_start
	_reset()

func _reset() -> void:
	units = []
	var slot := 0
	for d in data.get("party", []):
		units.append(_make_unit(d, "party", slot))
		slot += 1
	for d in data.get("enemies", []):
		units.append(_make_unit(d, "enemy", slot))
		slot += 1
	round_no = 0
	events = []
	result = ""
	_begin_round()

func _make_unit(d: Dictionary, side: String, slot: int) -> Dictionary:
	var base := str(d.get("id", "%s%d" % [side, slot]))
	var uid := base
	var k := 1
	while unit(uid) != null:
		k += 1
		uid = "%s#%d" % [base, k]
	return {"uid": uid, "side": side, "name": str(d.get("name", uid)), "hp": int(d.get("hp", 1)), "max_hp": int(d.get("hp", 1)),
		"power": int(d.get("power", 0)), "speed": int(d.get("speed", 0)), "actions": d.get("actions", []),
		"strength": int(d.get("strength", 0)), "weak": int(d.get("weak", 0)), "vulnerable": int(d.get("vulnerable", 0)),
		"block": int(d.get("block", 0)), "fresh": {}, "pattern": d.get("intents", []), "pick": str(d.get("pick", "cycle")),
		"ptr": 0, "pending": null, "alive": true, "slot": slot}

# ---------------- 查询 ----------------
func unit(uid: String):
	for u in units:
		if u.uid == uid: return u
	return null

func living(side: String) -> Array:
	return units.filter(func(u): return u.side == side and u.alive)

func intent_of(uid: String):
	for it in intents:
		if it.enemy == uid: return it
	return null

## 还没排行动的活着的队员（界面拿来提醒「还有人没选」）
func unplanned() -> Array:
	return living("party").filter(func(u): return not plan.has(u.uid)).map(func(u): return u.uid)

## 意图头上的字：单下写「9」，多段写「每下×几下」如「6x3」（原作格式）
func intent_text(it: Dictionary, target := "") -> String:
	if it.predicted.is_empty(): return ""
	var n := int(it.predicted.get(target, it.predicted.values()[0]))
	return str(n) if int(it.hits) == 1 else "%dx%d" % [n, int(it.hits)]

## 按现在的状态重算某个意图打某人一下是几点（结算动画中途刷新头上的数用）
func intent_damage(enemy_uid: String, target_uid: String) -> int:
	var it = intent_of(enemy_uid)
	var e = unit(enemy_uid)
	var t = unit(target_uid)
	if it == null or e == null or t == null: return 0
	return Rules.hit_damage(int(it.damage), e, t, cfg)

# ---------------- 意图 ----------------
func _begin_round() -> void:
	round_no += 1
	for u in living("party"): u.block = 0   # 队员的格挡在自己回合开始时清零；敌人的在它出手那一步清
	plan = {}
	plan_seq = []
	_history = []
	plan_version += 1
	intents = []
	events.append({"type": "round", "round": round_no})
	var order := 0
	for e in living("enemy"):
		var it := _decide(e)
		order += 1
		it.order = order
		intents.append(it)
		var ev: Dictionary = it.duplicate(true)
		ev.type = "intent"
		events.append(ev)

func _decide(e: Dictionary) -> Dictionary:
	var src: Dictionary = {"act": "wait"}
	var released := false
	if e.pending != null:            # 上回合蓄力，这回合放出来
		src = e.pending
		e.pending = null
		released = true
	elif e.pattern.is_empty():
		pass
	elif e.pick == "random":
		src = _weighted(e.pattern)
	else:
		src = e.pattern[e.ptr % e.pattern.size()]
		e.ptr += 1
	var it := {"enemy": e.uid, "order": 0, "act": str(src.get("act", "attack")), "move": str(src.get("move", "")),
		"damage": int(src.get("damage", 0)), "hits": maxi(1, int(src.get("hits", 1))), "target": "", "predicted": {},
		"basis": {}, "fx": {}, "status": "pending", "released": released}
	for k in FX:
		if int(src.get(k, 0)) != 0: it.fx[k] = int(src[k])
	if it.act == "charge":
		var then: Dictionary = src.get("then", {}).duplicate(true)
		then.target = _pick_target(str(then.get("target", "lowest_hp")))
		it.then = then
		it.target = then.target
	elif it.damage > 0 or it.fx.has("weak") or it.fx.has("vulnerable"):
		it.target = _pick_target(str(src.get("target", "lowest_hp")))
		if it.damage > 0:
			var list: Array = living("party") if it.target == "all" else [unit(it.target)]
			for t in list:
				if t == null: continue
				it.predicted[t.uid] = Rules.hit_damage(it.damage, e, t, cfg)
				it.basis[t.uid] = Rules.basis(e, t)
	return it

func _weighted(list: Array) -> Dictionary:
	var total := 0
	for x in list: total += maxi(0, int(x.get("weight", 1)))
	if total <= 0: return list[0]
	var roll := rng.randi_range(1, total)
	for x in list:
		roll -= maxi(0, int(x.get("weight", 1)))
		if roll <= 0: return x
	return list[-1]

func _pick_target(rule: String) -> String:
	var heroes := living("party")
	if heroes.is_empty(): return ""
	match rule:
		"all": return "all"
		"random": return heroes[rng.randi_range(0, heroes.size() - 1)].uid
		"highest_hp": return _extreme(heroes, false)
		"lowest_hp": return _extreme(heroes, true)
	var u = unit(rule)
	if u != null and u.side == "party" and u.alive: return rule
	return _extreme(heroes, true)

func _extreme(list: Array, lowest: bool) -> String:   # 同血按站位，取最前
	var best = list[0]
	for u in list:
		if (lowest and u.hp < best.hp) or (not lowest and u.hp > best.hp): best = u
	return best.uid

# ---------------- 排行动 ----------------
## 能不能排；能返回 ""，不能返回原因
func why_not(uid: String, action: String, target := "") -> String:
	if result != "": return "battle_over"
	var u = unit(uid)
	if u == null or u.side != "party" or not u.alive: return "not_available"
	if action not in u.actions or not data.get("actions", {}).has(action): return "unknown_action"
	var kind := str(data.actions[action].get("target", "enemy"))
	var t = unit(target)
	if kind == "enemy" and (t == null or t.side != "enemy" or not t.alive): return "bad_target"
	if kind == "ally" and (t == null or t.side != "party" or not t.alive): return "bad_target"
	return ""

## 排或改一个队员的行动；同一个人再排就替换，位置不变
func set_action(uid: String, action: String, target := "") -> String:
	var why := why_not(uid, action, target)
	if why != "": return why
	var a: Dictionary = data.actions[action]
	if str(a.get("target", "enemy")) == "self": target = uid
	_snapshot()
	var t = unit(target)
	plan[uid] = {"action": action, "target": target, "predicted": action_preview(uid, action, target),
		"basis": Rules.basis(unit(uid), t) if t.side == "enemy" else null}
	if uid not in plan_seq: plan_seq.append(uid)
	return ""

func clear_action(uid: String) -> void:
	if not plan.has(uid): return
	_snapshot()
	plan.erase(uid)
	plan_seq.erase(uid)

func undo() -> bool:
	if _history.is_empty(): return false
	var h: Array = _history.pop_back()
	plan = h[0]
	plan_seq = h[1]
	plan_version += 1
	return true

## party_order = plan 时调整先后
func reorder(uid: String, index: int) -> bool:
	if uid not in plan_seq: return false
	_snapshot()
	plan_seq.erase(uid)
	plan_seq.insert(clampi(index, 0, plan_seq.size()), uid)
	return true

func _snapshot() -> void:
	_history.append([plan.duplicate(true), plan_seq.duplicate()])
	plan_version += 1

## 行动按钮上显示的数：每一下打到目标身上是几点（已算力量、虚弱、目标易伤；不扣格挡）
func action_preview(uid: String, action: String, target: String) -> int:
	var a: Dictionary = data.actions.get(action, {})
	var t = unit(target)
	if not _deals(a) or t == null or t.side != "enemy": return 0
	return Rules.hit_damage(_base(unit(uid), a), unit(uid), t, cfg)

func _deals(a: Dictionary) -> bool:
	return int(a.get("damage", 0)) > 0 or bool(a.get("use_power", false))

func _base(u: Dictionary, a: Dictionary) -> int:
	return int(a.get("damage", 0)) + (int(u.power) if bool(a.get("use_power", false)) else 0)

# ---------------- 出手顺序 ----------------
## 这回合谁先谁后：[{side, uid}]。preview()、confirm() 和界面上的顺序编号都只看它。
func execution_order() -> Array:
	var seq: Array = plan_seq if cfg.party_order == "plan" else living("party").map(func(u): return u.uid)
	var party := []
	for uid in seq:
		if plan.has(uid): party.append({"side": "party", "uid": uid})
	var foes := intents.map(func(it): return {"side": "enemy", "uid": it.enemy})
	match cfg.execution:
		"enemies_first": return foes + party
		"speed":
			var all: Array = party + foes
			for i in all.size():
				all[i].rank = i
				all[i].speed = int(unit(all[i].uid).speed)
			all.sort_custom(func(a, b): return a.speed > b.speed or (a.speed == b.speed and a.rank < b.rank))
			return all
	return party + foes

# ---------------- 结算 ----------------
## 照当前计划试算这一回合，真的战斗一点不动：{events, hp{uid:hp}, result, version}
func preview() -> Dictionary:
	var c = get_script().new()
	c.data = data
	c.cfg = cfg
	c.rng = RandomNumberGenerator.new()
	c.rng.seed = rng.seed
	c.rng.state = rng.state
	c.units = units.duplicate(true)
	c.intents = intents.duplicate(true)
	c.plan = plan.duplicate(true)
	c.plan_seq = plan_seq.duplicate()
	c.round_no = round_no
	c._resolve_round()
	var hp := {}
	for u in c.units: hp[u.uid] = u.hp
	return {"events": c.events, "hp": hp, "result": c.result, "version": plan_version}

## 确认计划，结算这一回合；返回这回合结算时发生的事件（不含下一回合的意图）
func confirm() -> Array:
	if result != "": return []
	var mark := events.size()
	_resolve_round()
	var out := events.slice(mark)
	if result == "":
		for u in units: Rules.tick(u, bool(cfg.enemy_debuff_grace))
		_begin_round()
	return out

func _resolve_round() -> void:
	for step in execution_order():
		if result != "": break
		if step.side == "party": _do_party(step.uid)
		else: _do_enemy(step.uid)

func _do_party(uid: String) -> void:
	var u = unit(uid)
	var p: Dictionary = plan[uid]
	if not u.alive:
		events.append({"type": "skip", "who": uid, "why": "down"})
		return
	var a: Dictionary = data.actions[p.action]
	var kind := str(a.get("target", "enemy"))
	var t = unit(p.target)
	var why := []
	var basis = p.basis
	if kind != "self" and not t.alive:
		var nt = null
		if kind == "enemy" and cfg.party_retarget == "next_enemy" and not living("enemy").is_empty():
			nt = living("enemy")[0]
		events.append({"type": "retarget", "who": uid, "from": p.target, "to": nt.uid if nt != null else "", "why": "target_down"})
		if nt == null: return
		t = nt
		why.append("retarget")
		basis = null
	events.append({"type": "action", "who": uid, "action": p.action, "target": t.uid})
	if _deals(a):
		var hits := maxi(1, int(a.get("hits", 1)))
		for h in hits:
			if not t.alive or result != "": break
			_hit(u, t, _base(u, a), int(p.predicted), why.duplicate(), basis, h, hits)
	if t.alive and t.side == "enemy":
		if bool(a.get("stun", false)): _stun(t)
		for k in ["weak", "vulnerable"]:
			if int(a.get(k, 0)) > 0: _status(t, k, int(a[k]), false)
	if int(a.get("block", 0)) > 0 and t.alive and t.side == "party":
		t.block += int(a.block)
		events.append({"type": "block", "who": uid, "target": t.uid, "n": int(a.block)})
	if int(a.get("strength", 0)) != 0: _status(u, "strength", int(a.strength), false)

func _do_enemy(uid: String) -> void:
	var it = intent_of(uid)
	var e = unit(uid)
	if e == null or not e.alive: return
	e.block = 0                       # 格挡在自己回合开始时清零（原作规则）；被打断也照清
	if it == null or it.status != "pending": return   # 作废的意图在作废那一刻已经记过 void
	it.status = "done"
	events.append({"type": "enemy_act", "enemy": uid, "act": it.act, "move": it.move, "target": it.target})
	if it.act == "charge":
		e.pending = it.then.duplicate(true)
		return
	var targets: Array = []
	var why := []
	var retargeted := false
	if it.target == "all":
		targets = living("party")
	elif it.target != "":
		var t = unit(it.target)
		if t == null or not t.alive:
			var nt = null
			if cfg.enemy_retarget == "lowest_hp" and not living("party").is_empty():
				nt = unit(_extreme(living("party"), true))
			events.append({"type": "retarget", "who": uid, "from": it.target, "to": nt.uid if nt != null else "", "why": "target_down"})
			t = nt
			why.append("retarget")
			retargeted = true
		if t != null: targets = [t]
	for t in targets:
		for h in int(it.hits):
			if result != "" or not t.alive or int(it.damage) <= 0: break
			var shown := int(it.predicted.get(it.target if retargeted else t.uid, 0))
			_hit(e, t, int(it.damage), shown, why.duplicate(), null if retargeted else it.basis.get(t.uid), h, int(it.hits))
		for k in ["weak", "vulnerable"]:
			if it.fx.has(k) and t.alive: _status(t, k, int(it.fx[k]), true)
	if it.fx.has("block"):
		e.block += int(it.fx.block)
		events.append({"type": "block", "who": uid, "target": uid, "n": int(it.fx.block)})
	if it.fx.has("strength"): _status(e, "strength", int(it.fx.strength), true)

## 打一下。predicted 是亮意图 / 排行动时显示的每下数；actual（掉的血）和它不一样时，reasons 一定写着为什么
func _hit(src: Dictionary, t: Dictionary, base: int, predicted: int, why: Array, basis, hit: int, hits: int) -> void:
	var dealt := Rules.hit_damage(base, src, t, cfg)
	if basis != null: why.append_array(Rules.changed(basis, src, t))
	var ab: Array = Rules.absorb(t, dealt)
	if ab[0] > 0: why.append("block")
	if ab[1] != predicted and why.is_empty(): why.append("unexplained")   # 不该出现：出现说明预告和结算用了两套算法
	t.hp = maxi(0, t.hp - ab[1])
	events.append({"type": "damage", "source": src.uid, "target": t.uid, "hit": hit + 1, "hits": hits, "predicted": predicted,
		"dealt": dealt, "blocked": ab[0], "actual": ab[1], "reasons": why, "hp": t.hp})
	if t.hp == 0: _down(t)

func _status(t: Dictionary, key: String, n: int, by_enemy: bool) -> void:
	Rules.apply(t, key, n, by_enemy and t.side == "party")
	events.append({"type": "status", "target": t.uid, "status": key, "n": n, "total": int(t[key])})

func _stun(e: Dictionary) -> void:
	var it = intent_of(e.uid)
	if it == null: return
	if it.status != "pending":
		events.append({"type": "stun_wasted", "enemy": e.uid, "why": "already_acted" if it.status == "done" else "already_void"})
		return
	it.status = "cancelled"
	events.append({"type": "void", "enemy": e.uid, "why": "stunned"})

func _down(t: Dictionary) -> void:
	t.alive = false
	t.pending = null
	events.append({"type": "down", "who": t.uid})
	if t.side == "enemy":
		var it = intent_of(t.uid)
		if it != null and it.status == "pending":
			it.status = "void"
			events.append({"type": "void", "enemy": t.uid, "why": "dead"})
	if living("enemy").is_empty(): _finish("win")
	elif living("party").is_empty(): _finish("lose")

func _finish(r: String) -> void:
	result = r
	events.append({"type": "result", "result": r})
