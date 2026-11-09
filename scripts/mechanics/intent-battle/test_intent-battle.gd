extends SceneTree
## 无头测试：godot --headless -s res://intent-battle/test_intent-battle.gd

const Battle := preload("intent-battle.gd")
var data: Dictionary
var failed := 0

func _init() -> void:
	var path: String = get_script().resource_path.get_base_dir() + "/example.json"
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	_normal_flow()
	_plan_change_undo()
	_preview_no_mutation()
	_preview_matches_real()
	_retry_same_intents()
	_dead_enemy_voids_intent()
	_exec_order_defined()
	_retarget_mid_round()
	_stun_cancels_intent()
	_intent_includes_modifiers()
	_damage_rounding_order()
	_block_resets_at_turn_start()
	_multi_hit_display()
	_debuff_duration()
	quit(1 if failed > 0 else 0)

func _ok(name: String, cond: bool, why: String) -> void:
	if cond:
		print("[test] intent-battle %s PASS" % name)
	else:
		failed += 1
		print("[test] intent-battle %s FAIL %s" % [name, why])

func _build(d: Dictionary, seed_: int = 1):
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var b = Battle.new()
	b.setup(d, rng)
	return b

func _make(rules: Dictionary = {}, seed_: int = 1):
	var d: Dictionary = data.duplicate(true)
	d.rules.merge(rules, true)
	return _build(d, seed_)

## 用 example.json 的队伍和动作，敌人换成给定的
func _with_enemies(enemies: Array):
	var d: Dictionary = data.duplicate(true)
	d.enemies = enemies
	return d

func _of(evs: Array, type: String) -> Array:
	return evs.filter(func(e): return e.type == type)

func _hits(evs: Array, source: String) -> Array:
	return evs.filter(func(e): return e.type == "damage" and e.source == source)

func _actors(evs: Array) -> Array:
	var a := []
	for e in evs:
		if e.type == "action": a.append(e.who)
		elif e.type == "enemy_act": a.append(e.enemy)
	return a

func _snap(b) -> String:
	return var_to_str([b.units, b.intents, b.plan, b.plan_seq, b.round_no, b.events.size(), b.rng.state, b.result, b.plan_version])

func _never_silent(evs: Array) -> bool:
	for e in _of(evs, "damage"):
		if e.actual != e.predicted and (e.reasons.is_empty() or "unexplained" in e.reasons): return false
	return true

# 正常流程：亮意图 → 排行动 → 结算 → 赢
func _normal_flow() -> void:
	var b = _make()
	var lead = b.intent_of("alpha")
	var shown: bool = b.intents.size() == 3 and lead.order == 1 and lead.target == "squire" and int(lead.predicted.get("squire", -1)) == 5 and b.intent_text(lead) == "5"
	var first_round_ok := true
	var silent_ok := true
	var rounds := 0
	while b.result == "" and rounds < 12:
		var tgt := ""
		var low := 999
		for e in b.living("enemy"):
			if e.hp < low:
				low = e.hp
				tgt = e.uid
		for uid in ["fighter", "squire"]: b.set_action(uid, "attack", tgt)
		b.set_action("mage", "spark", tgt)
		var out: Array = b.confirm()
		silent_ok = silent_ok and _never_silent(out)
		if rounds == 0:
			var acts := _actors(out)
			first_round_ok = acts.slice(0, 3) == ["fighter", "squire", "mage"]
		rounds += 1
	var types := {}
	for e in b.events: types[e.type] = true
	var all_types: bool = types.has("round") and types.has("intent") and types.has("action") and types.has("damage") and types.has("result")
	_ok("normal_flow", shown and first_round_ok and silent_ok and b.result == "win" and all_types,
		"shown=%s first_round=%s silent_ok=%s result=%s rounds=%d types=%s" % [shown, first_round_ok, silent_ok, b.result, rounds, types.keys()])

# 计划阶段：改、撤、undo；不合法的排法拒绝且不改计划
func _plan_change_undo() -> void:
	var b = _make()
	var r1: String = b.set_action("fighter", "attack", "wolf")
	b.set_action("fighter", "attack", "alpha")
	var changed: bool = b.plan.fighter.target == "alpha" and b.plan_seq == ["fighter"] and int(b.plan.fighter.predicted) == 3
	b.clear_action("fighter")
	var cleared: bool = not b.plan.has("fighter")
	b.undo()
	var back1: bool = b.plan.has("fighter") and b.plan.fighter.target == "alpha"
	b.undo()
	var back2: bool = b.plan.fighter.target == "wolf"
	var bad: bool = b.set_action("fighter", "attack", "nobody") == "bad_target" and b.set_action("fighter", "spark", "wolf") == "unknown_action" \
		and b.set_action("mage", "guard", "wolf") == "bad_target"
	var kept: bool = b.plan.fighter.target == "wolf"
	b.set_action("squire", "defend")
	var self_ok: bool = b.plan.squire.target == "squire"
	_ok("plan_change_undo", r1 == "" and changed and cleared and back1 and back2 and bad and kept and self_ok,
		"r1=%s changed=%s cleared=%s back1=%s back2=%s bad=%s kept=%s self=%s" % [r1, changed, cleared, back1, back2, bad, kept, self_ok])

# 坑：preview 改了真实状态
func _preview_no_mutation() -> void:
	var b = _make()
	b.set_action("fighter", "attack", "wolf")
	b.set_action("squire", "attack", "wolf")
	b.set_action("mage", "guard", "squire")
	var before := _snap(b)
	var p: Dictionary = b.preview()
	b.preview()
	var after := _snap(b)
	_ok("preview_no_mutation", before == after and int(p.hp.wolf) == 0 and b.unit("wolf").hp == 4 and b.unit("wolf").alive,
		"state changed=%s preview wolf hp=%s real wolf hp=%s" % [before != after, p.hp.wolf, b.unit("wolf").hp])

# 坑：预告的数和实际伤害悄悄不一样
func _preview_matches_real() -> void:
	var b = _make()
	b.set_action("fighter", "attack", "alpha")
	b.set_action("squire", "attack", "alpha")
	b.set_action("mage", "guard", "squire")
	var p: Dictionary = b.preview()
	var real: Array = b.confirm()
	var same := JSON.stringify(p.events) == JSON.stringify(real)
	var lead_hit := _hits(real, "alpha")
	var wolf_hit := _hits(real, "wolf")
	var block_ok: bool = lead_hit.size() == 1 and lead_hit[0].predicted == 5 and lead_hit[0].blocked == 4 and lead_hit[0].actual == 1 and "block" in lead_hit[0].reasons
	var plain_ok: bool = wolf_hit.size() == 1 and wolf_hit[0].predicted == wolf_hit[0].actual and wolf_hit[0].reasons.is_empty()
	var b2 = _make()
	b2.set_action("fighter", "attack", "wolf")
	var p2: Dictionary = b2.preview()
	b2.set_action("fighter", "attack", "alpha")
	var stale_known: bool = p2.version != b2.plan_version
	_ok("preview_matches_real", same and block_ok and plain_ok and _never_silent(real) and stale_known,
		"same=%s block=%s plain=%s never_silent=%s stale=%s lead=%s" % [same, block_ok, plain_ok, _never_silent(real), stale_known, lead_hit])

func _plan_simple(b) -> void:
	b.set_action("fighter", "attack", "alpha")
	b.set_action("squire", "attack", "alpha")
	if b.unit("runt").alive: b.set_action("mage", "spark", "runt")

# 坑：重来时意图被重掷
func _retry_same_intents() -> void:
	var b = _make({}, 42)
	var r1 := var_to_str(b.intents)
	_plan_simple(b)
	b.preview()
	b.confirm()
	var r2 := var_to_str(b.intents)
	b.restart()
	var same1 := var_to_str(b.intents) == r1
	_plan_simple(b)
	b.confirm()
	var same2 := var_to_str(b.intents) == r2
	var seen := {}
	for s in range(1, 30): seen[var_to_str(_make({}, s).intents)] = true
	_ok("retry_same_intents", same1 and same2 and seen.size() > 1 and b.round_no == 2,
		"round1 same=%s round2 same=%s distinct intents across seeds=%d" % [same1, same2, seen.size()])

# 坑：已经倒下的敌人照样出手
func _dead_enemy_voids_intent() -> void:
	var b = _make()
	b.set_action("fighter", "attack", "wolf")
	b.set_action("squire", "attack", "wolf")
	b.set_action("mage", "guard", "fighter")
	var out: Array = b.confirm()
	var voided := out.any(func(e): return e.type == "void" and e.enemy == "wolf" and e.why == "dead")
	var acted := out.any(func(e): return (e.type == "enemy_act" and e.enemy == "wolf") or (e.type == "damage" and e.source == "wolf"))
	_ok("dead_enemy_voids_intent", voided and not acted, "voided=%s still acted=%s" % [voided, acted])

# 坑：排行动的先后和出手的先后混在一起
func _exec_order_defined() -> void:
	var b = _make()
	b.set_action("mage", "spark", "alpha")
	b.set_action("squire", "attack", "alpha")
	b.set_action("fighter", "attack", "alpha")
	var o1: Array = b.execution_order().map(func(s): return s.uid)
	var a1 := _actors(b.confirm()).slice(0, 3)
	var slot_ok: bool = o1.slice(0, 3) == ["fighter", "squire", "mage"] and a1 == ["fighter", "squire", "mage"]
	var p = _make({"party_order": "plan"})
	p.set_action("mage", "spark", "alpha")
	p.set_action("squire", "attack", "alpha")
	p.set_action("fighter", "attack", "alpha")
	p.set_action("mage", "spark", "runt")
	var kept: bool = p.plan_seq == ["mage", "squire", "fighter"]
	p.reorder("fighter", 0)
	var o2: Array = p.execution_order().map(func(s): return s.uid)
	var a2 := _actors(p.confirm()).slice(0, 3)
	var plan_ok: bool = kept and o2.slice(0, 3) == ["fighter", "mage", "squire"] and a2 == ["fighter", "mage", "squire"]
	var s = _make({"execution": "speed"})
	s.set_action("fighter", "defend")
	s.set_action("squire", "defend")
	s.set_action("mage", "guard", "fighter")
	var o3: Array = s.execution_order().map(func(x): return x.uid)
	var a3 := _actors(s.confirm())
	var want := ["alpha", "fighter", "squire", "wolf", "mage", "runt"]
	var speed_ok: bool = o3 == want and a3 == want
	_ok("exec_order_defined", slot_ok and plan_ok and speed_ok,
		"slot=%s/%s plan=%s/%s kept=%s speed=%s/%s" % [o1, a1, o2, a2, kept, o3, a3])

# 坑：目标在这回合中途倒下（重定向规则）
func _retarget_mid_round() -> void:
	var b = _make()
	for uid in ["fighter", "squire"]: b.set_action(uid, "attack", "wolf")
	b.set_action("mage", "spark", "wolf")
	var out: Array = b.confirm()
	var rt := out.filter(func(e): return e.type == "retarget" and e.who == "mage")
	var hit := _hits(out, "mage")
	var next_ok: bool = rt.size() == 1 and rt[0].to == "alpha" and hit.size() == 1 and hit[0].target == "alpha" and "retarget" in hit[0].reasons
	var f = _make({"party_retarget": "fizzle"})
	for uid in ["fighter", "squire"]: f.set_action(uid, "attack", "wolf")
	f.set_action("mage", "spark", "wolf")
	var fout: Array = f.confirm()
	var fizzle_ok: bool = fout.any(func(e): return e.type == "retarget" and e.who == "mage" and e.to == "") and _hits(fout, "mage").is_empty()
	var d: Dictionary = data.duplicate(true)
	d.party[1].hp = 5
	var eout: Array = _build(d).confirm()
	var ert := eout.filter(func(e): return e.type == "retarget" and e.who == "wolf")
	var ehit := _hits(eout, "wolf")
	var enemy_ok: bool = ert.size() == 1 and ert[0].from == "squire" and ert[0].to == "mage" and ehit.size() == 1 and ehit[0].target == "mage" and "retarget" in ehit[0].reasons
	var d2: Dictionary = d.duplicate(true)
	d2.rules.enemy_retarget = "fizzle"
	var enemy_fizzle: bool = _hits(_build(d2).confirm(), "wolf").is_empty()
	_ok("retarget_mid_round", next_ok and fizzle_ok and enemy_ok and enemy_fizzle,
		"next_enemy=%s fizzle=%s enemy_lowest=%s enemy_fizzle=%s" % [next_ok, fizzle_ok, enemy_ok, enemy_fizzle])

# 打断让意图作废：蓄力被打断就不放；没打断下回合放出来；敌人已经出手后才打断算浪费
func _stun_cancels_intent() -> void:
	var seed_ := -1
	for s in range(1, 60):
		if _make({}, s).intent_of("runt").act == "charge":
			seed_ = s
			break
	var b = _make({}, seed_)
	b.set_action("mage", "stun", "runt")
	b.set_action("fighter", "defend")
	b.set_action("squire", "defend")
	var out: Array = b.confirm()
	var voided := out.any(func(e): return e.type == "void" and e.enemy == "runt" and e.why == "stunned")
	var no_act := not out.any(func(e): return e.type == "enemy_act" and e.enemy == "runt")
	var not_released: bool = not b.intent_of("runt").released
	b.restart()
	b.set_action("mage", "guard", "fighter")
	b.confirm()
	var rel = b.intent_of("runt")
	var released: bool = rel.released and rel.act == "attack" and rel.damage == 6 and not rel.predicted.is_empty()
	var w = _make({"execution": "speed"})
	w.set_action("mage", "stun", "alpha")
	var wasted := w.confirm().any(func(e): return e.type == "stun_wasted" and e.why == "already_acted")
	_ok("stun_cancels_intent", seed_ > 0 and voided and no_act and not_released and released and wasted,
		"seed=%d voided=%s no_act=%s not_released=%s released=%s wasted=%s" % [seed_, voided, no_act, not_released, released, wasted])

# 坑：意图上的数没算敌人的力量、虚弱和队员的易伤；结算中途上了虚弱，伤害变了却不说
func _intent_includes_modifiers() -> void:
	var d = _with_enemies([{"id": "brute", "hp": 30, "speed": 1, "strength": 2, "weak": 1, "intents": [{"act": "attack", "damage": 6, "target": "fighter"}]}])
	d.party[0].vulnerable = 1
	var b = _build(d)
	var shown := int(b.intent_of("brute").predicted.fighter)
	var hit := _hits(b.confirm(), "brute")
	var full_ok: bool = shown == 9 and hit.size() == 1 and hit[0].actual == 9 and hit[0].reasons.is_empty()
	var c = _make()
	c.set_action("mage", "sap", "alpha")
	var p: Dictionary = c.preview()
	var out: Array = c.confirm()
	var lh := _hits(out, "alpha")
	var live_ok: bool = lh.size() == 1 and lh[0].predicted == 5 and lh[0].actual == 3 and "weak" in lh[0].reasons \
		and JSON.stringify(p.events) == JSON.stringify(out)
	_ok("intent_includes_modifiers", full_ok and live_ok, "shown=%d (want 9) hit=%s live=%s" % [shown, hit, lh])

# 坑：取整顺序。原作先乘完虚弱、易伤再向下取整：5 × 0.75 × 1.5 = 5.625 → 5；每步都取整会得到 4
func _damage_rounding_order() -> void:
	var d = _with_enemies([
		{"id": "e1", "hp": 30, "speed": 3, "weak": 1, "intents": [{"act": "attack", "damage": 5, "target": "fighter"}]},
		{"id": "e2", "hp": 30, "speed": 2, "intents": [{"act": "attack", "damage": 5, "target": "mage"}]},
		{"id": "e3", "hp": 30, "speed": 1, "weak": 1, "intents": [{"act": "attack", "damage": 5, "target": "squire"}]}])
	d.party[0].vulnerable = 1
	d.party[2].vulnerable = 1
	var b = _build(d)
	var shown := [int(b.intent_of("e1").predicted.fighter), int(b.intent_of("e2").predicted.mage), int(b.intent_of("e3").predicted.squire)]
	var out: Array = b.confirm()
	var dealt := [int(_hits(out, "e1")[0].actual), int(_hits(out, "e2")[0].actual), int(_hits(out, "e3")[0].actual)]
	_ok("damage_rounding_order", shown == [5, 7, 3] and dealt == [5, 7, 3], "shown=%s dealt=%s want [5, 7, 3]" % [shown, dealt])

# 格挡在自己回合开始时清零：队员的在下一回合开头清，敌人的在它下一次出手那一步清
func _block_resets_at_turn_start() -> void:
	var b = _make()
	b.set_action("fighter", "defend")
	b.confirm()
	var party_cleared: bool = b.unit("fighter").block == 0 and b.round_no == 2
	b.confirm()
	var enemy_kept: bool = b.unit("alpha").block == 6
	b.set_action("fighter", "attack", "alpha")
	var out: Array = b.confirm()
	var fh := _hits(out, "fighter")
	var absorbed: bool = fh.size() == 1 and fh[0].blocked == 3 and fh[0].actual == 0 and "block" in fh[0].reasons
	var enemy_cleared: bool = b.unit("alpha").block == 0
	_ok("block_resets_at_turn_start", party_cleared and enemy_kept and absorbed and enemy_cleared,
		"party_cleared=%s enemy_kept=%s absorbed=%s enemy_cleared=%s" % [party_cleared, enemy_kept, absorbed, enemy_cleared])

# 多段攻击：头上写「每下×几下」，力量加在每一下上，格挡一下一下地扣
func _multi_hit_display() -> void:
	var d: Dictionary = data.duplicate(true)
	d.party[0].strength = 1
	var b = _build(d)
	b.set_action("fighter", "flurry", "alpha")
	var per := int(b.plan.fighter.predicted)
	var fh := _hits(b.confirm(), "fighter")
	var party_ok: bool = per == 2 and fh.size() == 3 and fh.all(func(e): return e.dealt == 2 and e.hits == 3)
	var c = _build(_with_enemies([{"id": "hydra", "hp": 30, "speed": 1, "strength": 1, "intents": [{"act": "attack", "damage": 2, "hits": 3, "target": "fighter"}]}]))
	var label: String = c.intent_text(c.intent_of("hydra"), "fighter")
	c.set_action("fighter", "defend")
	var hh := _hits(c.confirm(), "hydra")
	var got := hh.map(func(e): return [e.dealt, e.blocked, e.actual])
	var enemy_ok: bool = label == "3x3" and got == [[3, 3, 0], [3, 2, 1], [3, 0, 3]] and c.unit("fighter").hp == 8
	_ok("multi_hit_display", party_ok and enemy_ok, "per_hit=%d party_hits=%d label=%s enemy_hits=%s" % [per, fh.size(), label, got])

# 虚弱 / 易伤每回合结束减 1；敌人刚上给队员的那回合不减
func _debuff_duration() -> void:
	var b = _make()
	b.set_action("squire", "expose", "alpha")
	b.confirm()
	var after1: int = b.unit("alpha").vulnerable
	b.set_action("fighter", "attack", "alpha")
	var boosted := int(b.plan.fighter.predicted)
	b.confirm()
	var after2: int = b.unit("alpha").vulnerable
	var hexer := [{"id": "hexer", "hp": 30, "speed": 1, "intents": [{"act": "debuff", "weak": 1, "target": "fighter"}, {"act": "wait"}]}]
	var g = _build(_with_enemies(hexer))
	g.confirm()
	var grace1: int = g.unit("fighter").weak
	g.set_action("fighter", "attack", "hexer")
	var weakened := int(g.plan.fighter.predicted)
	g.confirm()
	var grace2: int = g.unit("fighter").weak
	var nd = _with_enemies(hexer)
	nd.rules.enemy_debuff_grace = false
	var n = _build(nd)
	n.confirm()
	var no_grace: int = n.unit("fighter").weak
	_ok("debuff_duration", after1 == 1 and boosted == 4 and after2 == 0 and grace1 == 1 and weakened == 2 and grace2 == 0 and no_grace == 0,
		"vuln %d->%d boosted=%d weak(grace) %d->%d weakened=%d no_grace=%d" % [after1, after2, boosted, grace1, grace2, weakened, no_grace])
