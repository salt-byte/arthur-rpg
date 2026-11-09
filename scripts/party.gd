extends Node
## 学徒的经验、技能树、随机奖励、装备和背包，三个人带出战斗的血（design/systems/progression.md、items.md）。
## 状态全在 GS.S 里，存读档跟着走；数从 content/data/progression.json、items.json、combat.json 读。
## 经验曲线和投点照搬 scripts/lib/xp_progression.gd、skill_tree.gd；装备照搬 scripts/lib/affix_loot.gd。

const XPProg := preload("res://scripts/lib/xp_progression.gd")
const SkillTree := preload("res://scripts/lib/skill_tree.gd")
const AffixLoot := preload("res://scripts/lib/affix_loot.gd")

var xp
var tree
var loot
var PR: Dictionary
var IT: Dictionary
var C: Dictionary

func _ready() -> void:
	reload()

## 新开一局、读档以后调一次：按 GS.S 重建经验和技能树
func reload() -> void:
	PR = Data.t("progression")
	IT = Data.t("items")
	C = Data.t("combat")
	var nodes := {}
	for id in PR.skill_tree.nodes:
		var n: Dictionary = PR.skill_tree.nodes[id]
		nodes[id] = {"cost": int(n.get("cost", 1)), "level_req": int(n.level_req), "max_rank": int(n.max_rank), "requires": n.get("requires", [])}
	tree = SkillTree.new({"nodes": nodes, "respec_charges": int(PR.skill_tree.respec_charges), "respec_refund": float(PR.skill_tree.respec_refund)})
	xp = XPProg.new(PR.progression, tree)
	loot = AffixLoot.new(IT.loot)
	ensure_state()
	xp.load_save(GS.S.prog)
	tree.load_save(GS.S.tree)
	tree.level = xp.level

func ensure_state() -> void:
	var d := {"prog": {"level": 1, "xp": 0}, "tree": {}, "boons": {}, "comp": {}, "silver": 0, "bag": [],
		"equip": {"staff": null, "clothes": null, "charm": null}, "potions": {"potion_hp": 0, "potion_mana": 0},
		"hp": {}, "pending_boons": 0, "rng": {"drop": 0, "boon": 0}, "seed": 20261109, "shrine": null, "prayed": [], "chests": []}
	for k in d:
		if not GS.S.has(k): GS.S[k] = d[k]

func _store() -> void:
	GS.S.prog = xp.to_save()
	GS.S.tree = tree.to_save()

# ---------------- 等级、经验 ----------------
func level() -> int: return xp.level
func points() -> int: return tree.points
func progress() -> Dictionary: return xp.progress()
func rank(id: String) -> int: return tree.rank(id)

## 一只敌人给多少经验：3 × 章（第 1 章 2），首领 × 3，召唤出来的 0
func enemy_xp(eid: String, summoned := false) -> int:
	if summoned: return int(PR.xp.summoned)
	var ed: Dictionary = C.enemies.get(eid, {})
	var ch := clampi(int(ed.get("chapter", 1)), 1, 6)
	var n := int(PR.xp.per_enemy_by_chapter[ch - 1])
	if ed.get("boss", false): n *= int(PR.xp.boss_mult)
	return n

func quest_xp(chapter: int) -> int:
	var a: Array = PR.xp.quest_by_chapter
	return int(a[chapter - 1]) if chapter >= 1 and chapter <= a.size() else 0

## 加经验；升了级就三个人回满血、记下待挑的奖励。返回 xp_progression 的结果
func gain_xp(n: int) -> Dictionary:
	var r: Dictionary = xp.add_xp(n)
	if int(r.levels) > 0:
		GS.S.pending_boons = int(GS.S.pending_boons) + int(r.levels)
		if PR.get("progression", {}).get("heal_on_level_up", true): heal_all()
	_store()
	return r

# ---------------- 技能树 ----------------
func node_def(id: String) -> Dictionary: return PR.skill_tree.nodes.get(id, {})

func can_buy(id: String) -> Dictionary: return tree.can_buy(id)

func buy(id: String) -> Dictionary:
	var r: Dictionary = tree.buy(id)
	_store()
	return r

## 圣龛跟前洗点：点数全回来，奖励不回来
func respec() -> Dictionary:
	var r: Dictionary = tree.respec()
	_store()
	return r

func add_points(n: int) -> void:
	tree.add_points(n)
	_store()

func _eff(id: String, key: String) -> int:
	return rank(id) * int(node_def(id).get("effect", {}).get(key, 0))

## 技能树给的新招（双星、火雨、迷眼、乱影）
func tree_spells() -> Array:
	var a := []
	for id in PR.skill_tree.nodes:
		var ns: String = node_def(id).get("effect", {}).get("new_spell", "")
		if ns != "" and rank(id) > 0: a.append(ns)
	return a

func tree_spell_def(spell: String) -> Dictionary:
	for id in PR.skill_tree.nodes:
		var e: Dictionary = node_def(id).get("effect", {})
		if e.get("new_spell", "") == spell:
			var d := e.duplicate()
			d["name"] = node_def(id).name
			return d
	return {}

# ---------------- 学徒和同伴的数 ----------------
## 学徒这一仗用的全部数：基础（combat.json）+ 技能树 + 装备
func ap_stats() -> Dictionary:
	var g := gear_stats()
	var sp: Dictionary = C.spells
	return {
		"hp": int(C.apprentice.hp) + _eff("ward_sturdy", "apprentice_hp") + int(g.get("hp", 0)),
		"spark": int(sp.spark.damage) + _eff("spark_heat", "damage") + int(g.get("spark", 0)),
		"spark_vuln": int(sp.spark.vulnerable) + _eff("spark_ember", "vulnerable"),
		"ward": int(sp.ward.block) + _eff("ward_thick", "block") + int(g.get("ward", 0)),
		"ward_targets": 2 if rank("ward_twin") > 0 else 1,
		"focus": int(sp.focus.restore_mana) + _eff("water_ripple", "restore_mana") + int(g.get("focus", 0)),
		"mana_max": int(C.mana_max) + _eff("water_deep", "mana_max") + int(g.get("mana_max", 0)),
		"mana_regen": int(C.mana_regen) + _eff("water_tide", "mana_regen"),
		"interrupt": int(sp.interrupt.mana) + _eff("water_calm", "mana"),
		"see": _eff("trick_see", "battle_start_all_enemies_vulnerable"),
		"lever": _eff("trick_lever", "on_interrupt_vulnerable"),
		"stand": rank("ward_stand") > 0,
		"start_block": int(g.get("start_block", 0)),
		"start_vuln_top": int(g.get("start_vuln_top_hp", 0)),
		"after_heal": int(g.get("after_battle_heal", 0)),
	}

func comp_stats(id: String, chapter: int) -> Dictionary:
	var cd: Dictionary = C.companions.get(id, {})
	var st := cd
	if cd.has("by_chapter"):
		var bc: Dictionary = cd.by_chapter
		st = bc.get(str(chapter), bc.values()[-1])
	var plus: Dictionary = GS.S.comp.get(id, {})
	return {"hp": int(st.get("hp", cd.get("hp", 10))) + int(plus.get("hp", 0)),
		"power": int(st.get("power", cd.get("power", 2))) + int(plus.get("power", 0)),
		"name": cd.get("name", id)}

func guard_block() -> int:
	return int(C.guard_block) + 2 * int(GS.S.boons.get("iron_shield", 0))

func max_hp(uid: String, chapter: int) -> int:
	return ap_stats().hp if uid == "apprentice" else comp_stats(uid, chapter).hp

## 当前血：没记过的就是满的；上限变了就夹住
func cur_hp(uid: String, chapter: int) -> int:
	var m := max_hp(uid, chapter)
	if not GS.S.hp.has(uid): return m
	return clampi(int(GS.S.hp[uid]), 0, m)

func set_hp(uid: String, v: int, chapter: int) -> void:
	var m := max_hp(uid, chapter)
	if v >= m: GS.S.hp.erase(uid)
	else: GS.S.hp[uid] = maxi(0, v)

func heal_all() -> void:
	GS.S.hp = {}

func heal(uid: String, n: int, chapter: int) -> void:
	set_hp(uid, cur_hp(uid, chapter) + n, chapter)

# ---------------- 随机奖励 ----------------
## 抽三张不重样的；party 是眼下在队里的同伴（只给他们抽「磨了剑」「吃得饱」）
func roll_boons(party: Array) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = int(GS.S.seed) * 31 + int(GS.S.rng.boon) * 7919
	GS.S.rng.boon = int(GS.S.rng.boon) + 1
	var pool := []
	for b in PR.boons.pool:
		if int(b.get("from_level", 1)) > level(): continue
		if b.get("per_companion", false):
			for who in party:
				if _boon_count(b.id, who) < int(b.max): pool.append(_boon_card(b, who))
		elif int(b.max) < 0 or _boon_count(b.id, "") < int(b.max):
			pool.append(_boon_card(b, ""))
	var out := []
	while out.size() < int(PR.boons.choices) and not pool.is_empty():
		var i := r.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	while out.size() < int(PR.boons.choices):
		var filler: Dictionary = PR.boons.pool.filter(func(x): return x.id == PR.boons.filler)[0]
		out.append(_boon_card(filler, ""))
	return out

func _boon_key(id: String, who: String) -> String:
	return id + (":" + who if who != "" else "")

func _boon_count(id: String, who: String) -> int:
	return int(GS.S.boons.get(_boon_key(id, who), 0))

func _boon_card(b: Dictionary, who: String) -> Dictionary:
	var name := str(b.name).format({"who": comp_stats(who, 1).name if who != "" else ""})
	return {"id": b.id, "who": who, "name": name, "text": boon_text(b, who), "effect": b.effect}

func boon_text(b: Dictionary, who: String) -> String:
	var e: Dictionary = b.effect
	var nm: String = comp_stats(who, 1).name if who != "" else ""
	if e.has("companion_power"): return UIKit.f("boon_power", {"who": nm, "n": e.companion_power})
	if e.has("companion_hp"): return UIKit.f("boon_hp", {"who": nm, "n": e.companion_hp})
	if e.has("guard_block"): return UIKit.f("boon_guard", {"n": e.guard_block})
	if e.has("item"): return UIKit.f("boon_potions", {"n": e.count})
	if e.has("silver_per_chapter"): return UIKit.f("boon_silver", {"n": int(e.silver_per_chapter) * maxi(1, int(GS.S.vars.get("chapter", 1)))})
	if e.has("skill_points"): return UIKit.f("boon_point", {"n": e.skill_points})
	return ""

func take_boon(card: Dictionary) -> void:
	var key := _boon_key(card.id, card.who)
	GS.S.boons[key] = int(GS.S.boons.get(key, 0)) + 1
	var e: Dictionary = card.effect
	if card.who != "":
		var c: Dictionary = GS.S.comp.get(card.who, {"power": 0, "hp": 0})
		c.power = int(c.get("power", 0)) + int(e.get("companion_power", 0))
		c.hp = int(c.get("hp", 0)) + int(e.get("companion_hp", 0))
		GS.S.comp[card.who] = c
	if e.has("guard_block"):
		GS.S.boons["iron_shield"] = int(GS.S.boons.get("iron_shield", 0))  # 计数已在上面加过
	if e.has("item"): add_potion(e.item, int(e.count))
	if e.has("silver_per_chapter"): GS.S.silver = int(GS.S.silver) + int(e.silver_per_chapter) * maxi(1, int(GS.S.vars.get("chapter", 1)))
	if e.has("skill_points"): add_points(int(e.skill_points))
	GS.S.pending_boons = maxi(0, int(GS.S.pending_boons) - 1)

# ---------------- 药和银币 ----------------
func potions(kind: String) -> int: return int(GS.S.potions.get(kind, 0))

func potion_cap(kind: String) -> int: return int(IT.potion_cap.get(kind, 99))

## 加药，超过上限的按卖价换成银币；返回换掉了几瓶
func add_potion(kind: String, n: int) -> int:
	var room := potion_cap(kind) - potions(kind)
	var put := clampi(n, 0, maxi(0, room))
	GS.S.potions[kind] = potions(kind) + put
	var extra := n - put
	if extra > 0:
		GS.S.silver = int(GS.S.silver) + extra * sell_price_of_potion(kind)
	return extra

func sell_price_of_potion(kind: String) -> int:
	return int(floor(float(IT.potions[kind].price) * float(IT.shop.sell_pct) / 100.0))

func potion_def(kind: String) -> Dictionary: return IT.potions.get(kind, {})

# ---------------- 装备 ----------------
func item_info(it) -> Dictionary:
	if it == null: return {}
	if it.has("unique"):
		var u: Dictionary = IT.unique[it.unique]
		var lines := []
		for s in u.stats: lines.append("%s +%d" % [IT.loot.stat_names.get(s, s), int(u.stats[s])])
		return {"name": u.name, "slot": u.slot, "color": "#C9A24A", "rarity_name": UIKit.t("ui_unique"), "lines": lines,
			"stats": u.stats, "price": 0, "sellable": false, "look": u.get("look", "")}
	var d: Dictionary = loot.derive(it)
	var name: String = d.name
	if it.get("rarity", "") == "rare":
		name += str(IT.loot.slot_nouns.get(d.slot, ""))
	var stats := {}
	for m in d.modifiers: stats[m.stat] = int(stats.get(m.stat, 0)) + int(m.value)
	return {"name": name, "slot": d.slot, "color": d.color, "rarity_name": d.rarity_name, "lines": d.lines, "stats": stats,
		"price": d.price, "sellable": true, "look": d.look}

func gear_stats() -> Dictionary:
	var s := {}
	for slot in GS.S.equip:
		var it = GS.S.equip[slot]
		if it == null: continue
		var st: Dictionary = item_info(it).stats
		for k in st: s[k] = int(s.get(k, 0)) + int(st[k])
	return s

## 装上背包里第 i 件；身上那件回背包。血上限变低时当前血跟着降，最少剩 1
func equip(i: int, chapter: int) -> void:
	if i < 0 or i >= GS.S.bag.size(): return
	var it = GS.S.bag[i]
	var slot: String = item_info(it).slot
	var old = GS.S.equip.get(slot)
	GS.S.bag.remove_at(i)
	if old != null: GS.S.bag.insert(i, old)
	GS.S.equip[slot] = it
	_clamp_hp(chapter)

func unequip(slot: String, chapter: int) -> bool:
	var it = GS.S.equip.get(slot)
	if it == null or GS.S.bag.size() >= int(IT.bag_size): return false
	GS.S.equip[slot] = null
	GS.S.bag.append(it)
	_clamp_hp(chapter)
	return true

func _clamp_hp(chapter: int) -> void:
	var cur := cur_hp("apprentice", chapter)
	set_hp("apprentice", maxi(1, cur), chapter)

## 放进背包；满了按卖价换成银币。返回 {"put": bool, "silver": n}
func add_item(it: Dictionary) -> Dictionary:
	if GS.S.bag.size() >= int(IT.bag_size):
		var p := int(floor(item_info(it).price * float(IT.shop.sell_pct) / 100.0))
		GS.S.silver = int(GS.S.silver) + p
		return {"put": false, "silver": p}
	GS.S.bag.append(it)
	return {"put": true, "silver": 0}

func _drop_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(GS.S.seed) * 131 + int(GS.S.rng.drop) * 104729
	GS.S.rng.drop = int(GS.S.rng.drop) + 1
	return r

## 打赢一群敌人掉什么（items.md「哪里掉东西」）。kills：[{id, summoned}]
## 种子 = 存档里的计数，读档重打掉的一样
func roll_drops(kills: Array, chapter: int) -> Dictionary:
	var D: Dictionary = IT.drops
	var r := _drop_rng()
	var out := {"silver": 0, "potions": [], "items": [], "sold": []}
	var boss := false
	var n := 0
	var ilvl := chapter
	for k in kills:
		if k.get("summoned", false): continue
		n += 1
		var ed: Dictionary = C.enemies.get(k.id, {})
		ilvl = maxi(1, int(ed.get("chapter", chapter)))
		boss = boss or ed.get("boss", false)
		out.silver += int(D.group.silver_per_enemy_per_chapter) * ilvl
	if n == 0: return out
	if r.randf() < float(D.group.potion_chance):
		var kind := "potion_hp" if r.randf() < float(D.group.potion_mix.potion_hp) else "potion_mana"
		out.potions.append(kind)
	var gear_p := float(D.boss.gear_chance) if boss else float(D.group.gear_chance)
	if r.randf() < gear_p:
		var it: Dictionary = loot.roll_item(r, ilvl, {"min_rarity": D.boss.min_rarity} if boss else {})
		if not it.is_empty(): out.items.append(it)
	_grant_drops(out)
	return out

func open_chest(id: String, chapter: int) -> Dictionary:
	var out := {"silver": 0, "potions": [], "items": [], "sold": []}
	if id in GS.S.chests: return out
	GS.S.chests.append(id)
	var r := _drop_rng()
	var it: Dictionary = loot.roll_item(r, chapter, {"min_rarity": IT.drops.chest.min_rarity})
	if not it.is_empty(): out.items.append(it)
	_grant_drops(out)
	return out

func _grant_drops(out: Dictionary) -> void:
	GS.S.silver = int(GS.S.silver) + int(out.silver)
	for k in out.potions:
		var extra := add_potion(k, 1)
		if extra > 0: out.sold.append(UIKit.t(potion_def(k).name))
	for it in out.items:
		var res := add_item(it)
		if not res.put: out.sold.append(item_info(it).name)

## 剧情给的唯一物品（梅林的杖）
func grant_unique(id: String) -> void:
	add_item({"unique": id})

func drop_lines(out: Dictionary) -> Array:
	var a := []
	if int(out.silver) > 0: a.append(UIKit.f("ui_drop_silver", {"n": out.silver}))
	for k in out.potions: a.append(str(potion_def(k).name))
	for it in out.items:
		var inf := item_info(it)
		a.append("%s（%s）%s" % [inf.name, inf.rarity_name, "，".join(PackedStringArray(inf.lines))])
	for s in out.sold: a.append(UIKit.f("ui_bag_full", {"t": s}))
	return a
