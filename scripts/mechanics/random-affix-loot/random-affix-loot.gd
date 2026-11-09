extends RefCounted
## 随机词缀装备（规则照暗黑破坏神 2 的普通 / 魔法 / 稀有三档），纯逻辑。
## 底材 × 稀有度（几条词缀、前后缀各几条上限）× 词缀（按部位和词缀等级抽，同一组一件只出一条）。
## 一件装备只存「配方」：{"base", "rarity", "ilvl", "affixes": [[词缀 id, 掷出的整数], ...], "name"?: [i, j], "seed"?}。
## 属性、名字、说明行都由 derive() 按当前数据现算：改了数值，旧存档里的装备跟着变。
## 修饰格式和 stats-modifiers 相同：{"stat", "op": flat|increased|more, "value"}。
## 用法：loot = Loot.new(data) → item = loot.roll_item(rng, 物品等级, {"slot": "head", "min_rarity": "rare"})
##       → loot.derive(item) 给界面；loot.to_item_def(item) 登记进 inventory.gd 的物品表。

const DEFAULTS := {
	"rarities": [  # 顺序 = 从低到高；weight 是相对权重（整数），不必加起来等于 100（原作没有固定权重，这三个数是自定的）
		{"id": "normal", "name": "普通", "weight": 70, "mult": 1.0, "count_weights": [[0, 1]], "color": "#c8c8c8"},
		# 魔法：1 条 75、2 条 25；前:后 = 1:2，各最多 1 条 → 前+后 25% / 只有前缀 25% / 只有后缀 50%
		{"id": "magic", "name": "魔法", "weight": 25, "mult": 1.0, "count_weights": [[1, 75], [2, 25]], "side_weights": [1, 2], "prefix_max": 1, "suffix_max": 1, "color": "#6f7cff"},
		# 稀有：3–6 条各 1/4；每条前后各半，前缀、后缀各最多 3 条；名字从两张词表里随机拼，和属性无关
		{"id": "rare", "name": "稀有", "weight": 5, "mult": 1.0, "count_weights": [[3, 1], [4, 1], [5, 1], [6, 1]], "side_weights": [1, 1], "prefix_max": 3, "suffix_max": 3, "random_name": true, "color": "#e8d36a"},
	],
	"level_cap": 99,   # 词缀等级公式里的等级上限（原作 99）
	"bases": {},       # id -> {"name", "slot", "equip_slots"?, "qlvl", "magic_lvl"?, "weight", "stats": {属性: 整数}, "price", "look"}
	"affixes": {},     # id -> {"group", "pos": prefix|suffix, "label", "slots": [...], "level", "max_level"?, "weight", "stat", "op", "percent", "min", "max"}
	"rare_names": {"first": ["无名"], "second": ["之物"]},
	"stat_names": {},  # 属性 -> 界面上的名字
	"name_format": "{prefix}{base}{suffix}",
	"store_seed": true,
}

var cfg: Dictionary

func _init(data: Dictionary = {}) -> void:
	cfg = DEFAULTS.duplicate(true)
	for k in data:
		cfg[k] = data[k]

# ---------- 掷装备 ----------

## 从外面的 rng 取一个种子，再用这个种子掷整件。每件装备只消耗外面 rng 的一次调用。
func roll_item(rng: RandomNumberGenerator, item_level: int, opts: Dictionary = {}) -> Dictionary:
	return roll_item_from_seed(rng.randi(), item_level, opts)

## 同一个种子 + 同样的数据 + 同样的参数 → 同一件装备。opts：slot / base / rarity / min_rarity
func roll_item_from_seed(seed: int, item_level: int, opts: Dictionary = {}) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var base_id := str(opts.get("base", ""))
	if base_id == "":
		var pool := []
		for id in cfg.bases:
			var b: Dictionary = cfg.bases[id]
			if int(b.get("qlvl", 1)) <= item_level and (not opts.has("slot") or b.slot == opts.slot):
				pool.append([id, b.get("weight", 1)])
		base_id = _pick(pool, r)
	if not cfg.bases.has(base_id):
		return {}
	var rarity := str(opts.get("rarity", ""))
	if rarity == "":
		rarity = roll_rarity(r, str(opts.get("min_rarity", "")))
	if rarity == "":
		return {}
	var base: Dictionary = cfg.bases[base_id]
	var ra := _rarity(rarity)
	var item := {"base": base_id, "rarity": rarity, "ilvl": item_level, "affixes": []}
	var alvl := affix_level(base_id, item_level)
	var n := int(float(_pick(ra.get("count_weights", []), r)))  # JSON 读来的 3 是 3.0，先转 float
	var cap := {"prefix": int(ra.get("prefix_max", 0)), "suffix": int(ra.get("suffix_max", 0))}
	var side_w: Array = ra.get("side_weights", [1, 1])
	var groups := []
	for i in n:
		var pools := {"prefix": [], "suffix": []}
		for id in cfg.affixes:
			var a: Dictionary = cfg.affixes[id]
			if pools.has(a.get("pos")) and affix_allowed(id, base.slot, alvl) and not groups.has(_group(id)):
				pools[a.pos].append([id, a.get("weight", 1)])
		# 先定前缀还是后缀：这一边满了或没词缀可抽，权重就是 0
		var sides := [["prefix", 0 if cap.prefix <= 0 or pools.prefix.is_empty() else side_w[0]],
			["suffix", 0 if cap.suffix <= 0 or pools.suffix.is_empty() else side_w[1]]]
		var side := _pick(sides, r)
		if side == "":
			break  # 能用的组用完了：少出几条，不重复、不死循环
		cap[side] -= 1
		var aid := _pick(pools[side], r)
		groups.append(_group(aid))
		var a: Dictionary = cfg.affixes[aid]
		item.affixes.append([aid, r.randi_range(int(a.min), int(a.max))])  # 两端都取得到的整数
	if n > 0 and item.affixes.is_empty():
		item.rarity = cfg.rarities[0].id  # 一条都没抽到就降成最低档，不出「没有词缀的魔法装备」
	elif ra.get("random_name", false):
		var rn: Dictionary = cfg.rare_names
		item["name"] = [r.randi_range(0, rn.first.size() - 1), r.randi_range(0, rn.second.size() - 1)]
	if cfg.store_seed:
		item["seed"] = seed
	return item

## 词缀等级（照原作公式，全程整数）：物品等级先抬到底材 qlvl、夹到上限；有 magic_lvl 的底材直接加；
## 否则 ilvl < 上限 - qlvl/2 时 = ilvl - qlvl/2，再往上 = 2×ilvl - 上限。词缀的 level ≤ 它 ≤ max_level 才能出。
func affix_level(base_id: String, item_level: int) -> int:
	var b: Dictionary = cfg.bases.get(base_id, {})
	var top := int(cfg.level_cap)
	var q := int(b.get("qlvl", 1))
	var il := mini(maxi(item_level, q), top)
	var half := int(q / 2.0)
	var al := il - half if il < top - half else 2 * il - top
	if int(b.get("magic_lvl", 0)) > 0:
		al = il + int(b.magic_lvl)
	return mini(al, top)

## 按权重掷稀有度；min_rarity 是保底（首领掉落），只在它和更高的档里掷。
func roll_rarity(r: RandomNumberGenerator, min_rarity: String = "") -> String:
	var pool := []
	var on := min_rarity == ""
	for ra in cfg.rarities:
		on = on or ra.id == min_rarity
		if on:
			pool.append([ra.id, ra.get("weight", 0)])
	var id := _pick(pool, r)
	if id == "" and min_rarity != "" and not pool.is_empty():
		return str(pool[0][0])  # 保底档和更高档全是 0 权重时给保底档
	return id

## 词缀能不能出现在这个部位、这个词缀等级上
func affix_allowed(affix_id: String, slot: String, alvl: int) -> bool:
	var a: Dictionary = cfg.affixes.get(affix_id, {})
	if a.is_empty() or int(a.get("level", 1)) > alvl:
		return false
	if a.has("max_level") and alvl > int(a.max_level):
		return false
	return not a.has("slots") or slot in a.slots

## 权重表 [[id, 权重], ...] 里抽一个。权重 ≤ 0 的永远抽不到；总权重 0 返回 ""。
static func _pick(entries: Array, r: RandomNumberGenerator) -> String:
	var total := 0
	for e in entries:
		total += maxi(int(e[1]), 0)
	if total <= 0:
		return ""
	var roll := r.randi_range(0, total - 1)
	for e in entries:
		roll -= maxi(int(e[1]), 0)
		if roll < 0:
			return str(e[0])
	return ""

# ---------- 给界面和属性系统 ----------

## 现算：名字、稀有度颜色、说明行、修饰、售价、外观图层。不进存档。
func derive(item: Dictionary) -> Dictionary:
	var base: Dictionary = cfg.bases.get(str(item.get("base", "")), {})
	var ra := _rarity(str(item.get("rarity", "")))
	var mult := float(ra.get("mult", 1.0))
	var mods := []
	var lines := []
	var stats: Dictionary = base.get("stats", {})
	for s in stats:
		var v := int(roundf(float(stats[s]) * mult))  # 乘完只取整一次，用 round 不用 int() 截断
		mods.append({"stat": s, "op": "flat", "value": float(v)})
		lines.append("%s %d" % [_stat_name(s), v])
	var prefix := ""
	var suffix := ""
	for pair in item.get("affixes", []):
		var a: Dictionary = cfg.affixes.get(str(pair[0]), {})
		if a.is_empty():
			continue
		var v := int(pair[1])
		var pct: bool = a.get("percent", false)
		mods.append({"stat": a.stat, "op": a.get("op", "flat"), "value": v / 100.0 if pct else float(v)})
		lines.append(("%s +%d%%" if pct else "%s +%d") % [_stat_name(a.stat), v])
		if a.get("pos", "") == "prefix" and prefix == "":
			prefix = str(a.get("label", ""))
		elif a.get("pos", "") == "suffix" and suffix == "":
			suffix = str(a.get("label", ""))
	var base_name := str(base.get("name", item.get("base", "")))
	var name := str(cfg.name_format).format({"prefix": prefix, "suffix": suffix, "rarity": ra.get("name", ""), "base": base_name})
	if ra.get("random_name", false) and item.has("name"):  # 稀有：随机名，和词缀无关；底材名另给界面放第二行
		var rn: Dictionary = cfg.rare_names
		name = str(rn.first[int(item.name[0]) % rn.first.size()]) + str(rn.second[int(item.name[1]) % rn.second.size()])
	return {
		"name": name, "base_name": base_name, "rarity_name": ra.get("name", ""), "color": ra.get("color", "#ffffff"),
		"slot": base.get("slot", ""), "look": base.get("look", ""), "lines": lines, "modifiers": mods,
		"price": int(roundf(float(base.get("price", 0)) * float(ra.get("price_mult", mult)))),
	}

## 给 inventory.gd 的物品表用的定义：{"slots", "mods", "name"}。实例 id 由调用方起（如 "loot_17"）。
func to_item_def(item: Dictionary) -> Dictionary:
	var base: Dictionary = cfg.bases.get(str(item.get("base", "")), {})
	var d := derive(item)
	return {"slots": base.get("equip_slots", [base.get("slot", "")]), "mods": d.modifiers, "name": d.name}

# ---------- 存档 ----------

## 读档：JSON 读回的数字全是浮点，这里转回整数；只留配方里的键。
func deserialize(d: Dictionary) -> Dictionary:
	var out := {"base": str(d.get("base", "")), "rarity": str(d.get("rarity", "")), "ilvl": int(d.get("ilvl", 1)), "affixes": []}
	for pair in d.get("affixes", []):
		out.affixes.append([str(pair[0]), int(roundf(float(pair[1])))])
	if d.has("name"):
		out["name"] = [int(d.name[0]), int(d.name[1])]
	if d.has("seed"):
		out["seed"] = int(d.seed)
	return out

## 查一件装备（掷出的或读档来的）是否符合当前数据。返回问题列表，空 = 没问题。
func validate(item: Dictionary) -> Array:
	var errs := []
	var base: Dictionary = cfg.bases.get(str(item.get("base", "")), {})
	var ra := _rarity(str(item.get("rarity", "")))
	if base.is_empty() or ra.is_empty():
		return ["unknown_base_or_rarity"]
	var affs: Array = item.get("affixes", [])
	var counts: Array = ra.get("count_weights", [[0, 1]]).filter(func(c): return int(c[1]) > 0).map(func(c): return int(c[0]))
	if counts.is_empty():
		counts = [0]
	if affs.size() > counts.max():
		errs.append("too_many_affixes")
	elif affs.is_empty() and counts.min() > 0:
		errs.append("no_affix")  # 魔法 / 稀有至少要有一条
	var alvl := affix_level(str(item.base), int(item.get("ilvl", 1)))
	var side := {"prefix": 0, "suffix": 0}
	var groups := []
	for pair in affs:
		var id := str(pair[0])
		if not cfg.affixes.has(id):
			errs.append("unknown_affix:" + id)
			continue
		var a: Dictionary = cfg.affixes[id]
		if not affix_allowed(id, base.slot, alvl):
			errs.append("affix_not_allowed:" + id)
		if groups.has(_group(id)):
			errs.append("duplicate_group:" + _group(id))
		groups.append(_group(id))
		if side.has(a.get("pos")):
			side[a.pos] += 1
		var v = pair[1]
		if typeof(v) != TYPE_INT and float(v) != roundf(float(v)):
			errs.append("not_integer:" + id)
		elif int(v) < int(a.min) or int(v) > int(a.max):
			errs.append("out_of_range:" + id)
	for k in side:
		if side[k] > int(ra.get(k + "_max", 0)):
			errs.append("too_many_%ses" % k)  # too_many_prefixes / too_many_suffixes
	return errs

func _rarity(id: String) -> Dictionary:
	for ra in cfg.rarities:
		if ra.id == id:
			return ra
	return {}

func _group(affix_id: String) -> String:
	return str(cfg.affixes.get(affix_id, {}).get("group", affix_id))

func _stat_name(s: String) -> String:
	return str(cfg.stat_names.get(s, s))
