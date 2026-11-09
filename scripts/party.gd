extends Node
## 学徒和同伴这一刻的样子：血、经验和等级、技能树、随机奖励、装备、背包、药、银币。
## 规则照 design/systems/progression.md（经验照宝可梦「较快」N³，技能树照暗黑 2，每级随机奖励照 Vampire's Fall 2）
## 和 design/systems/items.md（稀有度和词缀照暗黑 2）；数全部从 progression.json、items.json、combat.json 读。
## 经验、技能树、装备的算法用 mechanics-library 带进来的参考代码（scripts/mechanics/），这里只把本作的数接上去。
## 状态都存在 GS.S 里（存档跟着走）；Progression / SkillTree 两个对象读档时从 GS.S 重建。

const Progression := preload("res://scripts/mechanics/xp-progression/xp-progression.gd")
const SkillTree := preload("res://scripts/mechanics/xp-progression/skill-tree.gd")
const Loot := preload("res://scripts/mechanics/random-affix-loot/random-affix-loot.gd")
const SLOTS := ["staff", "clothes", "charm"]
const COMPANIONS := ["kay", "arthur", "gawain", "lancelot", "gareth", "bedivere"]

var PR: Dictionary          # progression.json
var IT: Dictionary          # items.json
var CB: Dictionary          # combat.json
var prog                    # xp-progression.gd
var tree                    # skill-tree.gd
var loot                    # random-affix-loot.gd

func _ready() -> void:
	PR = Data.t("progression")
	IT = Data.t("items")
	CB = Data.t("combat")
	loot = Loot.new(_loot_cfg())
	reset()

## 本作 items.json 的写法换成参考代码要的格式（稀有度按普通 → 精良 → 稀有排；稀有的随机名两张字表）
func _loot_cfg() -> Dictionary:
	var L: Dictionary = IT.get("loot", {})
	var colors := {"normal": "#D8D2C4", "magic": "#7FA4E6", "rare": "#E3C35A"}
	var rar := []
	for id in ["normal", "magic", "rare"]:
		var r: Dictionary = L.get("rarities", {}).get(id, {}).duplicate(true)
		r.id = id
		r.mult = 1.0
		r.color = colors[id]
		rar.append(r)
	var rn: Array = L.get("rare_names", [["无"], ["名"]])
	var bases: Dictionary = L.get("bases", {}).duplicate(true)
	for id in bases:     # 最新一档底材多一份权重（items.json drops.newest_base_weight）
		bases[id]["weight"] = 1
	return {"rarities": rar, "level_cap": int(L.get("level_cap", 6)), "bases": bases, "affixes": L.get("affixes", {}),
		"rare_names": {"first": rn[0], "second": rn[1]}, "stat_names": L.get("stat_names", {}), "name_format": "{prefix}{base}{suffix}"}

# ---------------- 开局、存读档 ----------------
func reset() -> void:
	tree = SkillTree.new(PR.get("skill_tree", {}))
	prog = Progression.new(PR.get("progression", {}), tree)

## 新开一局：往 GS.S 里写这一套字段的初始值
func new_game() -> void:
	reset()
	var S: Dictionary = GS.S
	S["prog"] = prog.to_save()
	S["tree"] = tree.to_save()
	S["boons"] = {}               # "kay:sharpen" -> 次数；不分人的写 "iron_shield"
	S["pending_levels"] = []      # 还没挑奖励的升级（每级一条）
	S["gear"] = {"staff": null, "clothes": null, "charm": null}
	S["bag"] = []                 # 装备配方（random-affix-loot 的格式），带 uid
	S["potions"] = {"potion_hp": 0, "potion_mana": 0}
	S["silver"] = 0
	S["seed"] = 20261109
	S["rng_n"] = 0
	S["uid_n"] = 0
	S["hp"] = {}
	S["xp_total"] = 0
	for u in ["apprentice", "kay", "arthur"]: S.hp[u] = max_hp(u)

## 读档后从 GS.S 重建对象（JSON 读回的数是 float，参考代码自己会转）
func restore() -> void:
	reset()
	if not GS.S.has("prog"):   # 旧存档（version 1，第 8 步白盒）没有成长和背包：补上初始值，血按满血算
		var keep: Dictionary = GS.S.duplicate()
		new_game()
		for k in keep: GS.S[k] = keep[k]
	tree.load_save(GS.S.get("tree", {}))
	prog.load_save(GS.S.get("prog", {}))

## 存档前把对象写回 GS.S
func store() -> void:
	GS.S["prog"] = prog.to_save()
	GS.S["tree"] = tree.to_save()

func chapter() -> int:
	return int(GS.S.vars.get("chapter", 1))

# ---------------- 谁在队里、多少血 ----------------
## 眼下跟着你的同伴（剧情变量 $c_<id> == "party"）
func companions_in_party() -> Array:
	return COMPANIONS.filter(func(c): return str(GS.S.vars.get("c_" + c, "")) == "party")

func _comp_def(c: String) -> Dictionary:
	var cd: Dictionary = CB.get("companions", {}).get(c, {})
	if cd.has("by_chapter"):
		var bc: Dictionary = cd.by_chapter
		var key := str(chapter())
		if not bc.has(key):
			var best := ""
			for k in bc:
				if int(k) <= chapter() and (best == "" or int(k) > int(best)): best = k
			key = best if best != "" else bc.keys()[0]
		var st: Dictionary = bc[key].duplicate()
		st.name = cd.get("name", c)
		return st
	return cd

func boon_count(id: String, who := "") -> int:
	return int(GS.S.get("boons", {}).get(id if who == "" else who + ":" + id, 0))

func max_hp(uid: String) -> int:
	if uid == "apprentice":
		return int(CB.apprentice.hp) + _node_sum("apprentice_hp") + gear_stat("hp")
	return int(_comp_def(uid).get("hp", 10)) + 3 * boon_count("well_fed", uid)

func power(uid: String) -> int:
	return int(_comp_def(uid).get("power", 2)) + boon_count("sharpen", uid)

func display_name(uid: String) -> String:
	if uid == "apprentice": return UIKit.t("ui_you")
	return str(_comp_def(uid).get("name", uid))

func hp(uid: String) -> int:
	return clampi(int(GS.S.hp.get(uid, max_hp(uid))), 0, max_hp(uid))

func set_hp(uid: String, v: int) -> void:
	GS.S.hp[uid] = clampi(v, 0, max_hp(uid))

func party_uids() -> Array:
	return ["apprentice"] + companions_in_party()

func heal_all() -> void:
	for u in party_uids(): set_hp(u, max_hp(u))

func all_full() -> bool:
	for u in party_uids():
		if hp(u) < max_hp(u): return false
	return true

# ---------------- 技能树、装备加成 ----------------
## 所有点了的格子里某个效果的总和（每点一次算一份）
func _node_sum(key: String, spell_id := "") -> int:
	var s := 0
	var nodes: Dictionary = PR.skill_tree.nodes
	for id in nodes:
		var ef: Dictionary = nodes[id].get("effect", {})
		if not ef.has(key): continue
		if spell_id != "" and str(ef.get("spell", "")) != spell_id: continue
		if spell_id == "" and ef.has("spell"): continue
		s += int(ef[key]) * tree.rank(id)
	return s

func gear_stat(stat: String) -> int:
	var s := 0
	for slot in SLOTS:
		var it = GS.S.get("gear", {}).get(slot)
		if it == null: continue
		for m in item_info(it).modifiers:
			if m.stat == stat: s += int(m.value)
	return s

## 学徒这一刻会的法术和每招的数（剧情给的 + 技能树给的；数加上技能树和装备）
func spells(unlocks: Array) -> Dictionary:
	var base: Dictionary = CB.get("spells", {})
	var have := []
	for s in Data.param("story-unlocks", "starting_spells", []): have.append(s)
	for u in Data.t("story-unlocks").get("unlocks", []):
		if u.get("kind", "") == "spell" and u.id in unlocks and chapter() >= int(u.get("usable_from_chapter", 1)):
			have.append(u.what)
	var out := {}
	for s in have:
		if not base.has(s): continue
		var d: Dictionary = base[s].duplicate(true)
		match s:
			"spark":
				d.damage = int(d.damage) + _node_sum("damage", "spark") + gear_stat("spark")
				d.vulnerable = int(d.get("vulnerable", 1)) + _node_sum("vulnerable", "spark")
			"ward":
				d.block = int(d.block) + _node_sum("block", "ward") + gear_stat("ward")
				d.targets = 2 if tree.rank("ward_twin") > 0 else 1
			"focus":
				d.restore_mana = int(d.get("restore_mana", 2)) + _node_sum("restore_mana", "focus") + gear_stat("focus")
			"interrupt":
				d.mana = maxi(0, int(d.mana) + _node_sum("mana", "interrupt"))
		out[s] = d
	# 技能树里的新招
	var nodes: Dictionary = PR.skill_tree.nodes
	for id in nodes:
		var ef: Dictionary = nodes[id].get("effect", {})
		if not ef.has("new_spell") or tree.rank(id) <= 0: continue
		var d := {"name": nodes[id].name, "mana": int(ef.get("mana", 1))}
		match str(ef.new_spell):
			"twin_spark":
				d.damage = int(out.get("spark", {}).get("damage", 2))
				d.targets = int(ef.get("targets", 2))
			"fire_rain": d.damage = int(ef.get("damage", 2))
			"blind", "haze": d.weak = int(ef.get("weak", 1))
		out[str(ef.new_spell)] = d
	return out

func mana_max() -> int:
	return int(CB.mana_max) + _node_sum("mana_max") + gear_stat("mana_max")

## 开打时交给 Battle 的我方数据
func battle_ctx(party: Array, unlocks: Array) -> Dictionary:
	var allies := []
	for uid in ["apprentice"] + party:
		var mh := max_hp(uid)
		allies.append({"uid": uid, "name": display_name(uid), "hp": maxi(1, hp(uid)), "max": mh, "power": power(uid) if uid != "apprentice" else 0})
	return {
		"allies": allies, "spells": spells(unlocks), "mana_max": mana_max(),
		"mana_regen": int(CB.mana_regen) + _node_sum("mana_regen"),
		"guard_block": int(CB.guard_block) + 2 * boon_count("iron_shield"),
		"potions": GS.S.potions.duplicate(),
		"potion_heal": int(IT.potions.potion_hp.heal), "potion_mana": int(IT.potions.potion_mana.restore_mana),
		"start": {"all_enemies_vulnerable": _node_sum("battle_start_all_enemies_vulnerable"),
			"top_hp_vulnerable": gear_stat("start_vuln_top_hp"), "apprentice_block": gear_stat("start_block"),
			"interrupt_vulnerable": _node_sum("on_interrupt_vulnerable"), "stand": _node_sum("once_per_battle_survive_at")},
	}

# ---------------- 打完一仗 ----------------
## 经验：一只普通敌人按它所在的章给，首领乘倍数，召唤出来的不给（Battle.killed 本来就不含召唤的）
func xp_for(killed: Array) -> int:
	var per: Array = PR.xp.per_enemy_by_chapter
	var s := 0
	for eid in killed:
		var ed: Dictionary = Data.enemy(eid)
		var n := int(per[clampi(int(ed.get("chapter", 1)) - 1, 0, per.size() - 1)])
		if ed.get("boss", false): n *= int(PR.xp.boss_mult)
		s += n
	return s

## 打赢以后：血带出战斗（倒下的站起来剩 1 点），给经验和掉落。返回给结算框和测试看的结果
func after_win(b: Battle) -> Dictionary:
	for u in b.allies(false):
		set_hp(u.uid, u.hp if u.alive else int(CB.get("downed_revive_hp", 1)))
	GS.S.potions = b.potions.duplicate()
	var res := {"xp": 0, "levels": 0, "level": prog.level, "drops": {}, "revived": b.allies(false).filter(func(u): return not u.alive).map(func(u): return u.name)}
	var heal := gear_stat("after_battle_heal")
	if heal > 0:
		for u in party_uids(): set_hp(u, hp(u) + heal)
		res["mend"] = heal
	var xp := xp_for(b.killed)
	var r := gain_xp(xp)
	res.xp = xp
	res.levels = r.levels
	res.level = prog.level
	res.at_cap = prog.level >= prog.max_level()
	if not b.killed.is_empty():
		res.drops = roll_drops(b.killed)
	return res

## 逃跑或输了选回圣龛：血也带回去（之后回圣龛时回满）
func after_lose(b: Battle) -> void:
	GS.S.potions = b.potions.duplicate()

func gain_xp(n: int) -> Dictionary:
	var r: Dictionary = prog.add_xp(n)
	GS.S["xp_total"] = int(GS.S.get("xp_total", 0)) + (0 if r.ignored else n)
	for rew in r.rewards:
		GS.S.pending_levels.append(int(rew.level))
	if r.levels > 0 and bool(PR.progression.get("heal_on_level_up", true)):
		heal_all()
	store()
	return r

func level() -> int: return prog.level

func xp_progress() -> Dictionary: return prog.progress()

# ---------------- 每升一级挑一个奖励 ----------------
func _rng(tag: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(GS.S.get("seed", 1)), tag, int(GS.S.get("rng_n", 0))])
	GS.S.rng_n = int(GS.S.get("rng_n", 0)) + 1
	return r

## 这一级的三张奖励（不重样；同伴的只给眼下在队里的；池子不够用「钱袋」补）
func boon_offers(lv: int) -> Array:
	var pool := []
	for b in PR.boons.pool:
		if lv < int(b.get("from_level", 1)): continue
		if b.get("per_companion", false):
			for c in companions_in_party():
				if int(b.max) < 0 or boon_count(b.id, c) < int(b.max):
					pool.append({"id": b.id, "who": c, "name": str(b.name).format({"who": display_name(c)}), "effect": b.effect})
		elif int(b.max) < 0 or boon_count(b.id) < int(b.max):
			pool.append({"id": b.id, "who": "", "name": b.name, "effect": b.effect})
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(GS.S.get("seed", 1)), "boon", lv])
	var out := []
	while out.size() < int(PR.boons.choices) and not pool.is_empty():
		out.append(pool.pop_at(r.randi_range(0, pool.size() - 1)))
	while out.size() < int(PR.boons.choices):
		out.append({"id": "purse", "who": "", "name": "钱袋", "effect": {"silver_per_chapter": 20}})
	for o in out: o["text"] = boon_text(o)
	return out

func boon_text(o: Dictionary) -> String:
	var ef: Dictionary = o.effect
	if ef.has("companion_power"): return UIKit.f("boon_power", {"who": display_name(o.who), "n": int(ef.companion_power)})
	if ef.has("companion_hp"): return UIKit.f("boon_hp", {"who": display_name(o.who), "n": int(ef.companion_hp)})
	if ef.has("guard_block"): return UIKit.f("boon_guard", {"n": int(ef.guard_block)})
	if ef.has("item"): return UIKit.f("boon_potion", {"n": int(ef.count)})
	if ef.has("silver_per_chapter"): return UIKit.f("boon_silver", {"n": int(ef.silver_per_chapter) * chapter()})
	if ef.has("skill_points"): return UIKit.f("boon_point", {"n": int(ef.skill_points)})
	return ""

func pick_boon(o: Dictionary) -> void:
	var key: String = o.id if str(o.get("who", "")) == "" else str(o.who) + ":" + str(o.id)
	GS.S.boons[key] = int(GS.S.boons.get(key, 0)) + 1
	var ef: Dictionary = o.effect
	if ef.has("companion_hp"): set_hp(o.who, hp(o.who) + int(ef.companion_hp))
	if ef.has("item"): add_potion(str(ef.item), int(ef.count))
	if ef.has("silver_per_chapter"): GS.S.silver = int(GS.S.silver) + int(ef.silver_per_chapter) * chapter()
	if ef.has("skill_points"): tree.add_points(int(ef.skill_points))
	if not GS.S.pending_levels.is_empty(): GS.S.pending_levels.pop_front()
	store()

# ---------------- 技能树 ----------------
func tree_points() -> int: return tree.points

func can_buy(id: String) -> Dictionary:
	tree.level = prog.level
	return tree.can_buy(id)

func buy(id: String) -> Dictionary:
	tree.level = prog.level
	var before := max_hp("apprentice")
	var r: Dictionary = tree.buy(id)
	if r.ok:
		set_hp("apprentice", hp("apprentice") + max_hp("apprentice") - before)   # 结实：血上限加了，现在的血也加
		store()
	return r

func respec() -> Dictionary:
	var r: Dictionary = tree.respec()
	set_hp("apprentice", hp("apprentice"))
	store()
	return r

## 这一格为什么点不了（给界面写在格子上）
func node_why(id: String) -> String:
	var c := can_buy(id)
	if c.ok: return ""
	match str(c.reason):
		"level_too_low", "need_level": return UIKit.f("tree_need_level", {"n": int(c.need)})
		"missing_prereq": return UIKit.f("tree_need_prev", {"t": str(PR.skill_tree.nodes[c.missing[0]].name)})
		"max_rank": return UIKit.t("tree_full")
		"no_points": return UIKit.t("tree_no_points")
	return str(c.reason)

# ---------------- 掉落、背包、装备 ----------------
func item_info(it: Dictionary) -> Dictionary:
	if it.has("unique"):
		var u: Dictionary = IT.unique.get(it.unique, {})
		var mods := []
		var lines := []
		for s in u.get("stats", {}):
			mods.append({"stat": s, "op": "flat", "value": float(u.stats[s])})
			lines.append("%s +%d" % [IT.loot.stat_names.get(s, s), int(u.stats[s])])
		return {"name": u.get("name", it.unique), "rarity_name": "", "color": "#E3C35A", "slot": u.get("slot", ""), "lines": lines, "modifiers": mods, "price": 0}
	var d: Dictionary = loot.derive(it)
	if str(it.get("rarity", "")) == "rare" and it.has("name"):
		d.name = str(d.name) + str(IT.loot.get("slot_nouns", {}).get(d.slot, ""))
	# 同一样属性（底材的血 + 词缀的血）合成一行：「血 +5」
	var sums := {}
	var keys := []
	for m in d.modifiers:
		if not sums.has(m.stat): keys.append(m.stat)
		sums[m.stat] = int(sums.get(m.stat, 0)) + int(m.value)
	d.lines = keys.map(func(k): return "%s +%d" % [IT.loot.stat_names.get(k, k), int(sums[k])])
	return d

func _new_uid() -> int:
	GS.S.uid_n = int(GS.S.get("uid_n", 0)) + 1
	return int(GS.S.uid_n)

func _roll_gear(r: RandomNumberGenerator, min_rarity := "") -> Dictionary:
	var ilvl := chapter()
	# 最新一档底材权重加倍（items.json drops.newest_base_weight）
	var top := 1
	for id in loot.cfg.bases:
		if int(loot.cfg.bases[id].qlvl) <= ilvl: top = maxi(top, int(loot.cfg.bases[id].qlvl))
	for id in loot.cfg.bases:
		loot.cfg.bases[id].weight = int(IT.drops.get("newest_base_weight", 2)) if int(loot.cfg.bases[id].qlvl) == top else 1
	var it: Dictionary = loot.roll_item(r, ilvl, {"min_rarity": min_rarity} if min_rarity != "" else {})
	it["uid"] = _new_uid()
	return it

## 一群敌人的掉落：银币一定有；三成一瓶药；四分之一一件装备；有首领一定掉一件精良以上
func roll_drops(killed: Array) -> Dictionary:
	var D: Dictionary = IT.drops
	var r := _rng("drop")
	var out := {"silver": int(D.group.silver_per_enemy_per_chapter) * killed.size() * chapter(), "potions": {}, "gear": []}
	if r.randf() < float(D.group.potion_chance):
		var kind := "potion_hp" if r.randf() < float(D.group.potion_mix.potion_hp) else "potion_mana"
		out.potions[kind] = 1
	var boss := killed.any(func(e): return Data.enemy(e).get("boss", false))
	if boss:
		out.gear.append(_roll_gear(r, str(D.boss.min_rarity)))
	elif r.randf() < float(D.group.gear_chance):
		out.gear.append(_roll_gear(r))
	_take(out)
	return out

## 野外的宝物：一件精良以上的装备；结果由存档里的种子和宝物 id 定，读档再开一样
func roll_chest(chest_id: String) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(GS.S.get("seed", 1)), "chest", chest_id])
	var out := {"silver": 0, "potions": {}, "gear": [_roll_gear(r, str(IT.drops.chest.min_rarity))]}
	_take(out)
	return out

func add_potion(kind: String, n: int) -> int:
	var cap := int(IT.potion_cap.get(kind, 99))
	var have := int(GS.S.potions.get(kind, 0))
	var put := mini(n, cap - have)
	GS.S.potions[kind] = have + maxi(0, put)
	if put < n:   # 带不下的按卖价换成银币（items.json bag_full）
		GS.S.silver = int(GS.S.silver) + (n - maxi(0, put)) * int(int(IT.potions[kind].price) * int(IT.shop.sell_pct) / 100)
	return maxi(0, put)

func _take(out: Dictionary) -> void:
	GS.S.silver = int(GS.S.silver) + int(out.silver)
	for k in out.potions: add_potion(k, int(out.potions[k]))
	for g in out.gear:
		if GS.S.bag.size() >= int(IT.bag_size):
			GS.S.silver = int(GS.S.silver) + int(item_info(g).price * int(IT.shop.sell_pct) / 100)
			out["sold"] = true
		else:
			GS.S.bag.append(g)

## 掉落写成一行字（结算框和测试用）
func drops_text(d: Dictionary) -> String:
	var parts := []
	if int(d.get("silver", 0)) > 0: parts.append(UIKit.f("loot_silver", {"n": int(d.silver)}))
	for k in d.get("potions", {}): parts.append(UIKit.f("loot_potion", {"t": str(IT.potions[k].name), "n": int(d.potions[k])}))
	for g in d.get("gear", []):
		var info := item_info(g)
		parts.append("%s（%s）" % [info.name, info.rarity_name])
	return "、".join(PackedStringArray(parts)) if not parts.is_empty() else UIKit.t("loot_none")

func bag_index(uid: int) -> int:
	for i in GS.S.bag.size():
		if int(GS.S.bag[i].get("uid", -1)) == uid: return i
	return -1

## 换上背包里的一件；那个格子原来的放回背包。血上限变了，现在的血跟着加减（不低于 1）
func equip(uid: int) -> bool:
	var i := bag_index(uid)
	if i < 0: return false
	var it: Dictionary = GS.S.bag[i]
	var slot: String = item_info(it).slot
	var before := max_hp("apprentice")
	var old = GS.S.gear.get(slot)
	GS.S.bag.remove_at(i)
	if old != null: GS.S.bag.append(old)
	GS.S.gear[slot] = it
	set_hp("apprentice", maxi(1, hp("apprentice") + max_hp("apprentice") - before))
	return true

func unequip(slot: String) -> bool:
	var old = GS.S.gear.get(slot)
	if old == null or GS.S.bag.size() >= int(IT.bag_size): return false
	var before := max_hp("apprentice")
	GS.S.gear[slot] = null
	GS.S.bag.append(old)
	set_hp("apprentice", maxi(1, hp("apprentice") + max_hp("apprentice") - before))
	return true

## 换上它和现在那一格比，每样属性差多少（界面上写「+2」「-1」）
func compare(it: Dictionary) -> Dictionary:
	var slot: String = item_info(it).slot
	var now = GS.S.gear.get(slot)
	var diff := {}
	for m in item_info(it).modifiers: diff[m.stat] = int(diff.get(m.stat, 0)) + int(m.value)
	if now != null:
		for m in item_info(now).modifiers: diff[m.stat] = int(diff.get(m.stat, 0)) - int(m.value)
	return diff

## 地图上喝药（背包里点「喝」）：给血最少的人
func drink_on_map(kind: String) -> String:
	if int(GS.S.potions.get(kind, 0)) <= 0 or kind != "potion_hp": return ""
	var low := ""
	for u in party_uids():
		if hp(u) < max_hp(u) and (low == "" or hp(u) * 100 / max_hp(u) < hp(low) * 100 / max_hp(low)): low = u
	if low == "": return ""
	GS.S.potions[kind] = int(GS.S.potions[kind]) - 1
	set_hp(low, hp(low) + int(IT.potions.potion_hp.heal))
	return low
