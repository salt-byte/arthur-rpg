extends SceneTree
## 随机词缀装备的无头测试：godot --headless -s res://random-affix-loot/test_random-affix-loot.gd

const Loot := preload("random-affix-loot.gd")
const ID := "random-affix-loot"

var _fails := 0
var _dir: String
var _data: Dictionary


func _init() -> void:
	_dir = get_script().resource_path.get_base_dir()
	_data = JSON.parse_string(FileAccess.get_file_as_string(_dir + "/example.json"))
	_case("normal_roll_and_derive", _t_normal())
	_case("same_seed_same_items", _t_same_seed())
	_case("item_seed_regenerates_after_save", _t_item_seed())
	_case("magic_layout_25_25_50", _t_magic_layout())
	_case("magic_never_without_affix", _t_magic_never_empty())
	_case("rare_3_to_6_max_3_prefix_3_suffix", _t_rare_counts())
	_case("rare_random_name_not_from_affixes", _t_rare_name())
	_case("no_duplicate_affix_group", _t_group())
	_case("affix_only_on_allowed_slot", _t_slot())
	_case("rolled_values_int_and_in_range", _t_range())
	_case("rarity_multiplier_rounds_not_truncates", _t_round())
	_case("save_keeps_recipe_not_stats", _t_save())
	_case("rarity_weights_relative_zero_never", _t_weights())
	_case("min_rarity_floor", _t_floor())
	_case("affix_level_formula", _t_alvl())
	_case("affix_level_gates_affixes_and_bases", _t_ilvl())
	_case("validate_rejects_bad_save", _t_validate())
	_case("with_stats_modifiers_inventory", _t_with_stats())
	quit(1 if _fails > 0 else 0)


func _case(name: String, err: String) -> void:
	if err == "":
		print("[test] %s %s PASS" % [ID, name])
	else:
		_fails += 1
		print("[test] %s %s FAIL %s" % [ID, name, err])


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _loot(over: Dictionary = {}) -> Object:
	var d: Dictionary = _data.duplicate(true)
	for k in over:
		d[k] = over[k]
	return Loot.new(d)


func _sides(loot: Object, it: Dictionary) -> Vector2i:
	var v := Vector2i.ZERO
	for p in it.affixes:
		if loot.cfg.affixes[p[0]].pos == "prefix":
			v.x += 1
		else:
			v.y += 1
	return v


# ---------------- 用例 ----------------

func _t_normal() -> String:
	var loot := _loot()
	var item := {"base": "short_sword", "rarity": "magic", "ilvl": 5, "affixes": [["sharp_2", 5], ["keen_1", 3]]}
	var d: Dictionary = loot.derive(item)
	if d.name != "嗜血的短剑·鹰眼":
		return "name=%s" % d.name
	if d.rarity_name != "魔法" or d.color != "#6f7cff":
		return "rarity display %s %s" % [d.rarity_name, d.color]
	if d.lines != ["攻击 8", "攻击 +5", "暴击 +3%"]:
		return "lines=%s" % [d.lines]
	var want := [{"stat": "attack", "op": "flat", "value": 8.0}, {"stat": "attack", "op": "flat", "value": 5.0}, {"stat": "crit", "op": "flat", "value": 0.03}]
	if str(d.modifiers) != str(want):
		return "mods=%s" % [d.modifiers]
	if d.price != 20:
		return "price=%d" % d.price
	var r := _rng(7)
	for i in 300:
		var it: Dictionary = loot.roll_item(r, 1 + i % 12)
		if it.is_empty():
			return "empty roll"
		var errs: Array = loot.validate(it)
		if not errs.is_empty():
			return "rolled invalid %s %s" % [it, errs]
	return ""


func _t_same_seed() -> String:
	var loot := _loot()
	var a := _rng(42)
	var b := _rng(42)
	var c := _rng(43)
	var diff := false
	for i in 50:
		var x: Dictionary = loot.roll_item(a, 6)
		var y: Dictionary = loot.roll_item(b, 6)
		if str(x) != str(y):
			return "same seed differs at %d" % i
		diff = diff or str(x) != str(loot.roll_item(c, 6))
	return "" if diff else "different seed gave identical items"


func _t_item_seed() -> String:
	var loot := _loot()
	var r := _rng(5)
	for i in 30:
		var it: Dictionary = loot.roll_item(r, 6, {"slot": "body"})
		var back: Dictionary = loot.deserialize(JSON.parse_string(JSON.stringify(it)))
		var again: Dictionary = loot.roll_item_from_seed(back.seed, back.ilvl, {"slot": "body"})
		if str(again) != str(it):
			return "regen %s != %s" % [again, it]
	return ""


func _t_magic_layout() -> String:
	var loot := _loot()
	var r := _rng(13)
	var n := {"both": 0, "prefix": 0, "suffix": 0}
	for i in 4000:
		var it: Dictionary = loot.roll_item(r, 10, {"base": "bone_ring", "rarity": "magic"})
		var s := _sides(loot, it)
		if s.x > 1 or s.y > 1 or s.x + s.y == 0:
			return "bad magic layout %s" % [it.affixes]
		n["both" if s.x + s.y == 2 else ("prefix" if s.x == 1 else "suffix")] += 1
	for k in {"both": 0.25, "prefix": 0.25, "suffix": 0.5}.keys():
		var want: float = {"both": 0.25, "prefix": 0.25, "suffix": 0.5}[k]
		if absf(n[k] / 4000.0 - want) > 0.03:
			return "%s share %.3f, want %.2f" % [k, n[k] / 4000.0, want]
	return ""


func _t_magic_never_empty() -> String:
	var bases: Dictionary = _data.bases.duplicate(true)
	bases["plain_belt"] = {"name": "布腰带", "slot": "belt", "qlvl": 1, "stats": {"defense": 1}}
	var loot := _loot({"bases": bases})
	var r := _rng(17)
	for i in 100:
		var it: Dictionary = loot.roll_item(r, 5, {"base": "plain_belt", "rarity": "magic"})
		if it.rarity != "normal" or not it.affixes.is_empty() or not loot.validate(it).is_empty():
			return "no-affix magic should become normal: %s" % [it]
	if not loot.validate({"base": "leather_cap", "rarity": "magic", "ilvl": 3, "affixes": []}).has("no_affix"):
		return "validate missed empty magic item"
	return ""


func _t_rare_counts() -> String:
	var loot := _loot()
	var r := _rng(19)
	var n := {3: 0, 4: 0, 5: 0, 6: 0}
	for i in 2000:
		var it: Dictionary = loot.roll_item(r, 10, {"base": "plate_armor", "rarity": "rare"})
		var s := _sides(loot, it)
		if s.x > 3 or s.y > 3:
			return "more than 3 on one side: %s" % [it.affixes]
		if not n.has(it.affixes.size()):
			return "rare with %d affixes" % it.affixes.size()
		n[it.affixes.size()] += 1
	for k in n:
		if absf(n[k] / 2000.0 - 0.25) > 0.04:
			return "count %d share %.3f, want 0.25" % [k, n[k] / 2000.0]
	return ""


func _t_rare_name() -> String:
	var loot := _loot()
	var r := _rng(23)
	for i in 300:
		var it: Dictionary = loot.roll_item(r, 8)
		if (it.rarity == "rare") != it.has("name"):
			return "name field on wrong rarity: %s" % [it]
	var item := {"base": "short_sword", "rarity": "rare", "ilvl": 5, "affixes": [["sharp_2", 5], ["keen_1", 3], ["swift_1", 2]], "name": [0, 0]}
	var d: Dictionary = loot.derive(item)
	if d.name != "鸦啼獠牙" or d.base_name != "短剑":
		return "rare name=%s base=%s" % [d.name, d.base_name]
	return ""


func _t_group() -> String:
	var loot := _loot()
	var r := _rng(11)
	var saw_five := false
	for i in 500:
		var it: Dictionary = loot.roll_item(r, 6, {"base": "short_sword", "rarity": "rare"})
		var seen := []
		for p in it.affixes:
			var g: String = loot.cfg.affixes[p[0]].group
			if seen.has(g):
				return "group %s twice: %s" % [g, it]
			seen.append(g)
		saw_five = saw_five or it.affixes.size() == 5
	if not saw_five:
		return "never used all 5 weapon groups"
	# 物品等级 1 的武器只有 attack、crit 两组：稀有要 3–6 条也只出 2 条，不重复、不卡死
	for i in 100:
		var it: Dictionary = loot.roll_item(r, 1, {"slot": "main_hand", "rarity": "rare"})
		if it.affixes.size() != 2:
			return "expected 2 affixes when groups run out, got %s" % [it.affixes]
	return ""


func _t_slot() -> String:
	var loot := _loot()
	var r := _rng(3)
	for i in 600:
		var it: Dictionary = loot.roll_item(r, 8, {"min_rarity": "magic"})
		var slot: String = loot.cfg.bases[it.base].slot
		for p in it.affixes:
			if not slot in loot.cfg.affixes[p[0]].slots:
				return "%s on %s" % [p[0], slot]
	return ""


func _t_range() -> String:
	var loot := _loot()
	var r := _rng(9)
	var seen := {}
	for i in 800:
		var it: Dictionary = loot.roll_item(r, 3, {"slot": "head", "rarity": "rare"})
		for p in it.affixes:
			var a: Dictionary = loot.cfg.affixes[p[0]]
			if typeof(p[1]) != TYPE_INT:
				return "value not int: %s" % [p]
			if p[1] < int(a.min) or p[1] > int(a.max):
				return "out of range %s" % [p]
			seen["%s=%d" % [p[0], p[1]]] = true
	for k in ["vigor_1=5", "vigor_1=10", "sturdy_1=1", "sturdy_1=2"]:
		if not seen.has(k):
			return "never rolled range end %s" % k
	return ""


func _t_round() -> String:
	var bases: Dictionary = _data.bases.duplicate(true)
	bases["test_axe"] = {"name": "斧", "slot": "main_hand", "stats": {"attack": 100}}
	var loot := _loot({"bases": bases, "rarities": [{"id": "odd", "weight": 1, "mult": 1.15}]})
	var d: Dictionary = loot.derive({"base": "test_axe", "rarity": "odd", "ilvl": 1, "affixes": []})
	if d.modifiers[0].value != 115:  # 100 × 1.15 = 114.999…，int() 截断会得 114
		return "100×1.15 gave %s" % d.modifiers[0].value
	return ""


func _t_save() -> String:
	var loot := _loot()
	var it: Dictionary = loot.roll_item_from_seed(1, 6, {"base": "short_sword", "rarity": "rare"})
	for k in it:
		if not k in ["base", "rarity", "ilvl", "affixes", "name", "seed"]:
			return "extra key in save: %s" % k
	var text := JSON.stringify(it)
	if text.length() > 220:
		return "save too big (%d): %s" % [text.length(), text]
	var back: Dictionary = loot.deserialize(JSON.parse_string(text))
	if str(back) != str(it):
		return "roundtrip %s != %s" % [back, it]
	if typeof(back.ilvl) != TYPE_INT or typeof(back.affixes[0][1]) != TYPE_INT or typeof(back.name[0]) != TYPE_INT:
		return "ints came back as floats"
	# 平衡补丁：底材攻击 8 → 10，旧存档的同一件装备跟着变
	var bases: Dictionary = _data.bases.duplicate(true)
	bases.short_sword.stats.attack = 10
	var patched := _loot({"bases": bases})
	if patched.derive(back).modifiers[0].value != 10:
		return "patch not applied: %s" % [patched.derive(back).modifiers[0]]
	return ""


func _t_weights() -> String:
	var loot := _loot({"rarities": [
		{"id": "z", "weight": 0, "mult": 9.0},  # 0 权重放最前：「<= 0」写错时它会被抽中
		{"id": "a", "weight": 3, "mult": 1.0},
		{"id": "b", "weight": 1, "mult": 1.0},
	]})
	var r := _rng(21)
	var n := {"a": 0, "b": 0, "z": 0}
	for i in 4000:
		n[loot.roll_rarity(r)] += 1
	if n.z != 0:
		return "zero weight dropped %d times" % n.z
	var share: float = n.a / 4000.0
	if share < 0.72 or share > 0.78:
		return "weights 3:1 gave a=%.3f" % share
	var none := _loot({"rarities": [{"id": "a", "weight": 0}]})
	if none.roll_rarity(r) != "" or not none.roll_item(r, 1).is_empty():
		return "all-zero weights should drop nothing"
	return ""


func _t_floor() -> String:
	var loot := _loot()
	var r := _rng(4)
	for i in 400:
		var it: Dictionary = loot.roll_item(r, 3, {"min_rarity": "magic"})
		if not it.rarity in ["magic", "rare"]:
			return "floor broken: %s" % it.rarity
	return ""


func _t_alvl() -> String:
	var bases := {
		"q30": {"slot": "body", "qlvl": 30}, "q3": {"slot": "body", "qlvl": 3},
		"q4": {"slot": "body", "qlvl": 4}, "wand": {"slot": "main_hand", "qlvl": 2, "magic_lvl": 1},
	}
	var loot := _loot({"bases": bases})
	var cases := [["q30", 50, 35], ["q30", 90, 81], ["q30", 10, 15], ["q30", 120, 99], ["q3", 10, 9], ["wand", 10, 11]]
	for c in cases:
		if loot.affix_level(c[0], c[1]) != c[2]:
			return "%s ilvl %d → %d, want %d" % [c[0], c[1], loot.affix_level(c[0], c[1]), c[2]]
	var small := _loot({"bases": bases, "level_cap": 30})  # 等级上限 30 的小游戏
	if small.affix_level("q4", 20) != 18 or small.affix_level("q4", 30) != 30:
		return "cap 30: %d %d" % [small.affix_level("q4", 20), small.affix_level("q4", 30)]
	return ""


func _t_ilvl() -> String:
	var loot := _loot()
	var r := _rng(8)
	var saw_t2 := false
	for lv in [1, 10]:
		for i in 600:
			var it: Dictionary = loot.roll_item(r, lv, {"min_rarity": "magic"})
			if int(loot.cfg.bases[it.base].qlvl) > lv:
				return "ilvl %d dropped base %s" % [lv, it.base]
			var alvl: int = loot.affix_level(it.base, lv)
			for p in it.affixes:
				var a: Dictionary = loot.cfg.affixes[p[0]]
				if int(a.level) > alvl or (a.has("max_level") and alvl > int(a.max_level)):
					return "%s on alvl %d" % [p[0], alvl]
				saw_t2 = saw_t2 or p[0] == "sharp_2"
	return "" if saw_t2 else "high level never rolled sharp_2"


func _t_validate() -> String:
	var loot := _loot()
	var bad := {
		"duplicate_group": {"base": "short_sword", "rarity": "rare", "ilvl": 6, "affixes": [["sharp_1", 2], ["sharp_2", 5], ["keen_1", 2]]},
		"affix_not_allowed": {"base": "short_sword", "rarity": "magic", "ilvl": 6, "affixes": [["sturdy_1", 1]]},
		"affix_not_allowed:sharp_2": {"base": "short_sword", "rarity": "magic", "ilvl": 1, "affixes": [["sharp_2", 5]]},
		"out_of_range": {"base": "leather_cap", "rarity": "magic", "ilvl": 3, "affixes": [["vigor_1", 99]]},
		"not_integer": {"base": "leather_cap", "rarity": "magic", "ilvl": 3, "affixes": [["vigor_1", 6.5]]},
		"too_many_affixes": {"base": "leather_cap", "rarity": "normal", "ilvl": 3, "affixes": [["vigor_1", 6]]},
		"too_many_prefixes": {"base": "short_sword", "rarity": "magic", "ilvl": 6, "affixes": [["sharp_2", 5], ["brutal_1", 7]]},
		"unknown_affix": {"base": "leather_cap", "rarity": "magic", "ilvl": 3, "affixes": [["removed_affix", 1]]},
	}
	for want in bad:
		var errs: Array = loot.validate(bad[want])
		if not errs.any(func(e): return str(e).begins_with(want)):
			return "%s not reported, got %s" % [want, errs]
	var good: Array = loot.validate({"base": "bone_ring", "rarity": "rare", "ilvl": 3, "affixes": [["keen_1", 2], ["brutal_1", 5], ["vigor_1", 7]], "name": [1, 2]})
	return "" if good.is_empty() else "valid ring flagged: %s" % [good]


func _t_with_stats() -> String:
	var sm_path := (_dir + "/../stats-modifiers/stats-modifiers.gd").simplify_path()
	var inv_path := (_dir + "/../stats-modifiers/inventory.gd").simplify_path()
	if not ResourceLoader.exists(sm_path) or not ResourceLoader.exists(inv_path):
		print("[test] %s with_stats_modifiers_inventory 跳过：没有 stats-modifiers" % ID)
		return ""
	var loot := _loot()
	var stats = load(sm_path).new()  # 默认：str 10 → attack 20；agi 10 → crit 0.10
	var table := {}
	var inv = load(inv_path).new(table, {}, stats)
	var sword := {"base": "short_sword", "rarity": "rare", "ilvl": 5, "affixes": [["sharp_2", 5], ["brutal_1", 10], ["swift_1", 2]], "name": [0, 0]}
	var ring := {"base": "bone_ring", "rarity": "magic", "ilvl": 2, "affixes": [["keen_1", 3]]}
	table["loot_1"] = loot.to_item_def(sword)
	table["loot_2"] = loot.to_item_def(ring)
	inv.add("loot_1")
	inv.add("loot_2")
	var r1: Dictionary = inv.equip("loot_1")
	var r2: Dictionary = inv.equip("loot_2")
	if not r1.ok or not r2.ok or r2.slot != "ring_1":
		return "equip failed %s %s" % [r1, r2]
	if stats.get_stat("attack") != 36.0:  # (20 + 8 + 5) × (1 + 0.10) = 36.3 → 36
		return "attack=%s" % stats.get_stat("attack")
	if absf(stats.get_stat("crit") - 0.14) > 0.0001:  # 0.05 + 0.005 × 12 + 0.03
		return "crit=%s" % stats.get_stat("crit")
	inv.unequip("main_hand")
	if stats.get_stat("attack") != 20.0 or absf(stats.get_stat("crit") - 0.13) > 0.0001:
		return "after unequip attack=%s crit=%s" % [stats.get_stat("attack"), stats.get_stat("crit")]
	return ""
