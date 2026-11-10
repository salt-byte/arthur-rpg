class_name BattleSim
extends RefCounted
## 数值模拟和战斗规则的无头测试（godot --headless --path . -- --sim）。main.gd 的 --sim 只调这里。
## 1. 第 1 章五场仗、三种固定打法（1 级、满血、没装备），输出和以前逐字一样。
## 2. 第 2–6 章 31 场仗、同样三种打法，两种开法：1 级没装备（Party.battle_ctx）；「只打必须的」等级和装备
##    （tools/sim_numbers.py 写的 production/qa/balance/sim_ctx.json，原样读进来）。
##    对照：python3 tools/sim_numbers.py --validate 打印同样格式的行，两边逐字比。
## 3. combat.md「第 2–6 章的七个字段」七个字段各一条测试，打 [test] PASS / FAIL。
## 战斗是确定的（敌人按招式表轮着出），这里不掷骰，不用种子。

const CH1 := ["forest_wolves", "road_bandits", "oak_wolves", "log_wolves", "wolves"]
const STRATS := ["always_first", "smart", "no_magic"]
const CTX_FILE := "res://production/qa/balance/sim_ctx.json"

static var fails: Array = []

## 跑完全部，返回 FAIL 的条数
static func run() -> int:
	fails = []
	_ch1()
	var musts := _load_musts()
	if musts.is_empty():
		_check(false, "读不到 %s：先跑 python3 tools/sim_numbers.py --validate" % CTX_FILE)
	else:
		for profile in ["lv1", "must"]:
			for enc in musts:
				for strat in STRATS:
					_later(enc, strat, profile, musts[enc])
	_tests()
	print("[sim] 测试：%s，%d 条 FAIL" % ["PASS" if fails.is_empty() else "FAIL", fails.size()])
	return fails.size()

# ---------------- 第 1 章（和改之前逐字一样） ----------------
static func _ch1() -> void:
	for enc in CH1:
		for strat in STRATS:
			Party.heal_all()
			var b := Battle.new()
			b.setup(enc, Party.battle_ctx(["kay", "arthur"], ["spell_spark", "spell_ward", "spell_focus"]), 1, {})
			_play(b, strat)
			var down := b.allies(false).filter(func(u): return not u.alive).size()
			print("[sim] %s %s → %s 第 %d 回合，倒下 %d 人，剩血 %s" % [enc, strat, b.result, b.turn, down,
				", ".join(PackedStringArray(b.allies(false).map(func(u): return "%s %d/%d" % [u.name, u.hp, u.max])))])

# ---------------- 第 2–6 章 ----------------
static func _load_musts() -> Dictionary:
	if not FileAccess.file_exists(CTX_FILE): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(CTX_FILE))
	return d.get("ctx", {}) if d is Dictionary else {}

static func _later(enc: String, strat: String, profile: String, must: Dictionary) -> void:
	var ch := int(must.chapter)
	var roster: Array = must.allies.map(func(a): return str(a.uid)).filter(func(u): return u != "apprentice")
	var ctx: Dictionary
	if profile == "lv1":
		ctx = lv1_ctx(enc, ch, roster)
	else:
		ctx = must.duplicate(true)
	var b := Battle.new()
	b.setup(enc, ctx, ch, {})
	_play(b, strat)
	var down := b.allies(false).filter(func(u): return not u.alive).size()
	var hp := ", ".join(PackedStringArray(b.allies(false).map(func(u): return "%s %d/%d" % [Party.display_name(u.uid), u.hp, u.max])))
	var res := b.result
	if b.result == "win":
		if b.end_kind in ["survive", "end_if_down"]: res += "/" + b.end_kind
		hp += "，经验 %d" % Party.xp_for(b.xp_enemies())
	var party := "、".join(PackedStringArray(b.allies(false).filter(func(u): return u.uid != "apprentice").map(func(u): return Party.display_name(u.uid))))
	var lv := "" if profile == "lv1" else " %d 级" % int(must.level)
	print("[sim] 第 %d 章%s %s %s（%s）→ %s 第 %d 回合，倒下 %d 人，剩血 %s" % [ch, lv, enc, strat, party, res, b.turn, down, hp])

## 1 级、满血、没装备：第 ch 章的同伴数，法术是开局三招 + 打断（剧情第 1 章给）+ 揭开（第 4 章首领前给）
static func lv1_ctx(enc: String, ch: int, roster: Array) -> Dictionary:
	GS.new_game()
	Party.new_game()
	GS.S.vars["chapter"] = ch
	var party := Battle.party_for(Data.encounter(enc), roster, int(Data.param("combat", "party_max_companions", 2)))
	for u in ["apprentice"] + party: Party.set_hp(u, Party.max_hp(u))
	var unlocks := ["u_interrupt"]
	if ch >= 4: unlocks.append("u_reveal")
	return Party.battle_ctx(party, unlocks)

static func _play(b: Battle, strat: String) -> void:
	b.take_log()
	var guard := 0
	while b.result == "" and guard < 20:
		guard += 1
		sim_plan(b, strat)
		b.end_turn()
		b.take_log()

## always_first：三个人永远打第一只；smart：先打要叫人、要长嚎的，这回合挨打会倒的人举盾；no_magic：学徒只凝神。
## 和 tools/sim_numbers.py 的 godot_plan 一句一句对应（smart 数挨几下时连「？」也数进去，两边一样）
static func sim_plan(b: Battle, strat: String) -> void:
	var es := b.enemies()
	var low = es[0]
	var threat = null
	for e in es:
		if e.hp < low.hp: low = e
		var it = b.intent_of(e.uid)
		if it != null and it.act in ["summon", "buff"] and threat == null: threat = e
	var tgt = es[0] if strat == "always_first" else (threat if threat != null else low)
	if strat != "no_magic" and b.why_not("apprentice", "spark") == "": b.plan("apprentice", "spark", tgt.uid)
	else: b.plan("apprentice", "focus")
	for u in b.allies():
		var c: String = u.uid
		if c == "apprentice": continue
		if strat == "smart":
			var incoming := 0
			for it in b.intents:
				if it.act == "attack" and it.target == c: incoming += b.intent_damage(it) * int(it.hits)
			if incoming >= 4 and u.hp <= incoming + 3:
				b.plan(c, "guard")
				continue
		b.plan(c, "attack", tgt.uid)

# ---------------- 七个字段的测试 ----------------
static func _check(ok: bool, what: String) -> void:
	print("[test] ", "PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)

static func _battle(enc: String, roster: Array) -> Battle:
	var ch := int(Data.enemy(Data.encounter(enc).enemies[0]).get("chapter", 1))
	var b := Battle.new()
	b.setup(enc, lv1_ctx(enc, ch, roster), ch, {})
	b.take_log()
	return b

## 测试里不想让人倒下：把我方血调高（只改这一场的副本）
static func _tough(b: Battle) -> void:
	for u in b.allies():
		u.hp = 999
		u.max = 999

static func _tests() -> void:
	_test_survive()
	_test_hidden()
	_test_rise()
	_test_reserve()
	_test_guests()
	_test_end_if_down()
	_test_exclude()

## survive：佩利诺撑过 3 回合判赢；按上场的敌人给经验，不给掉落
static func _test_survive() -> void:
	var b := _battle("pellinore", ["arthur"])
	var n := b.survive_turns()
	var mid := []
	for i in n:
		if "pellinore" in b.interruptible() and b.why_not("apprentice", "interrupt") == "":
			b.plan("apprentice", "interrupt", "pellinore")
		elif b.why_not("apprentice", "ward") == "":
			b.plan("apprentice", "ward", "arthur")
		else:
			b.plan("apprentice", "focus")
		b.plan("arthur", "guard")
		b.end_turn()
		b.take_log()
		if i < n - 1: mid.append(b.result)
	_check(n == 3 and mid == ["", ""] and b.result == "win" and b.end_kind == "survive" and b.turn == 3,
		"survive：佩利诺 %d 回合，前两回合没完（%s），第 %d 回合敌人出完手判赢（%s/%s）" % [n, str(mid), b.turn, b.result, b.end_kind])
	_check(b.survived() and b.killed.is_empty() and b.xp_enemies() == ["pellinore"] and Party.xp_for(b.xp_enemies()) > 0,
		"survive：一个都没打倒，经验按上场的佩利诺给 %d" % Party.xp_for(b.xp_enemies()))

## hidden：护卫队长第 2 回合的蓄力是「？」，揭开前后显示不同；揭开不占招，揭开前打断不了
static func _test_hidden() -> void:
	var b := _battle("morgan_chase", ["arthur", "kay"])
	_tough(b)
	for u in b.allies(): b.plan(u.uid, "guard" if u.uid != "apprentice" else "focus")
	b.end_turn()
	b.take_log()
	var it = b.intent_of("morgan_captain")
	var before := b.intent_text(it)
	var hidden_ok: bool = b.is_hidden(it) and before.contains("？") and not "morgan_captain" in b.interruptible() and "reveal" in b.actions_for("apprentice")
	var m0 := b.mana
	var ok := b.reveal("morgan_captain")
	var after := b.intent_text(it)
	_check(hidden_ok and ok and before != after and not after.contains("？") and after.contains(UIKit.t("act_charge")),
		"hidden：揭开前「%s」，揭开后「%s」" % [before, after])
	_check(b.mana == m0 - b.spell_cost("reveal") and b.planned("apprentice") == null and "morgan_captain" in b.interruptible()
		and not "reveal" in b.actions_for("apprentice") and not b.plan("apprentice", "reveal"),
		"hidden：揭开花 %d 法力、不占学徒的招，揭开后才能打断" % b.spell_cost("reveal"))

## rise：红骑士前 3 回合每回合开头力量 +2，第 4 回合起不再涨
static func _test_rise() -> void:
	var b := _battle("red_knight", ["gawain"])
	_tough(b)
	var rise: Dictionary = Data.enemy("red_knight").rise
	var got := []
	var want := []
	for t in 5:
		got.append(int(b.unit("red_knight").strength))
		want.append(int(rise.strength) * mini(t + 1, int(rise.turns)))
		for u in b.allies(): b.plan(u.uid, "guard" if u.uid != "apprentice" else "focus")
		b.end_turn()
		b.take_log()
	_check(got == want, "rise：红骑士第 1–5 回合的力量 %s（应为 %s）" % [str(got), str(want)])

## reserve + field_max：比武场上最多 2 个，倒一个下回合补一个，后备也打完才赢；补上来的照常给经验
static func _test_reserve() -> void:
	var b := _battle("tournament", ["kay", "lancelot", "bedivere"])
	_tough(b)
	var fm := b.field_max
	var max_seen := 0
	var refilled := false
	var r0 := b.reserve.size()
	var early_win := false
	var g := 0
	while b.result == "" and g < 30:
		g += 1
		max_seen = maxi(max_seen, b.enemies().size())
		var t: String = b.enemies()[0].uid
		for u in b.allies():
			if u.uid != "apprentice": b.plan(u.uid, "attack", t)
			elif b.why_not("apprentice", "spark") == "": b.plan("apprentice", "spark", t)
			else: b.plan("apprentice", "focus")
		var before := b.reserve.size()
		b.end_turn()
		b.take_log()
		if b.reserve.size() < before and b.result == "": refilled = true
		if b.result == "win" and not b.reserve.is_empty(): early_win = true
	_check(fm == 2 and r0 == 1 and max_seen <= fm and refilled and not early_win and b.result == "win" and b.reserve.is_empty(),
		"reserve：场上最多 %d 个（见过 %d），后备 %d 个补上来过，后备打完才赢" % [fm, max_seen, r0])
	_check(b.killed.size() == 3 and Party.xp_for(b.xp_enemies()) == 3 * Party.xp_for(["tourney_knight"]),
		"reserve：补上来的那个照常给经验（打倒 %d 个，经验 %d）" % [b.killed.size(), Party.xp_for(b.xp_enemies())])

## guests：加雷斯受封前不在队里，红骑士那一仗照样上
static func _test_guests() -> void:
	var enc := Data.encounter("red_knight")
	var p1 := Battle.party_for(enc, ["gawain"], 2)
	var p2 := Battle.party_for(enc, ["kay", "gawain"], 2)
	var b := _battle("red_knight", ["gawain"])
	_check(p1 == ["gawain", "gareth"] and p2 == ["gawain", "gareth"] and b.unit("gareth") != null and "gareth" in b.guests,
		"guests：队里只有高文 → %s；队里有凯和高文 → %s（客人先于补位）" % [str(p1), str(p2)])

## end_if_down：佩利诺那一仗亚瑟倒下，剧情接管、算撑过，佩利诺不改打学徒；Yarn 拿得到结果
static func _test_end_if_down() -> void:
	var b := _battle("pellinore", ["arthur"])
	var g := 0
	while b.result == "" and g < 10:
		g += 1
		b.plan("apprentice", "focus")
		b.plan("arthur", "attack", "pellinore")
		b.end_turn()
		b.take_log()
	var ap = b.unit("apprentice")
	var yv := Battle.yarn_result(b)
	_check(b.result == "win" and b.end_kind == "end_if_down" and b.down_by == "arthur" and not b.unit("arthur").alive
		and ap.alive and ap.hp == ap.max and b.survived(),
		"end_if_down：第 %d 回合亚瑟倒下，这一仗停（%s/%s），学徒没挨打（%d/%d）" % [b.turn, b.result, b.end_kind, ap.hp, ap.max])
	_check(yv.get("last_battle") == "pellinore" and yv.get("last_battle_won") == true and yv.get("last_battle_end") == "end_if_down",
		"end_if_down：交给 Yarn 的变量 %s" % JSON.stringify(yv))

## exclude：比武不能带兰斯洛特，卡姆兰后队没有亚瑟；硬塞进来也上不了场
static func _test_exclude() -> void:
	var p1 := Battle.party_for(Data.encounter("tournament"), ["kay", "lancelot", "bedivere"], 2)
	var p2 := Battle.party_for(Data.encounter("camlann_rear"), ["kay", "arthur", "bedivere"], 2)
	GS.S.vars["chapter"] = 5
	var b := Battle.new()
	b.setup("tournament", Party.battle_ctx(["lancelot", "bedivere"], []), 5, {})
	_check(not "lancelot" in p1 and p1 == ["bedivere", "kay"] and not "arthur" in p2 and b.unit("lancelot") == null,
		"exclude：比武 → %s，卡姆兰后队 → %s，硬塞兰斯洛特进比武也不上场" % [str(p1), str(p2)])
