extends RefCounted
## 照搬自 ai-rpg-studio 插件 mechanics-library（参考代码，带自动测试）；本项目不改规则，只从 content/data 传参数。
## 经验曲线 + 升级。曲线照宝可梦的六种成长速度（Bulbapedia「Experience」页），默认「较快」= n³。
## 宝可梦公式给的是「到达 n 级的累计经验」total(n)；从 n 升到 n+1 要 total(n+1) − total(n)。
## 经验按「当前等级内攒了多少」存；加经验时循环扣，一次大经验可以连升多级（原作同样）。
## 满级（原作 100 级）后不再获得经验；多出的经验在返回值里报出数量。
## 升级奖励照暗黑破坏神 2：每级 1 个技能点、5 个属性点；传入 skill-tree.gd 实例时技能点和解锁自动交给它。
## 叙事成长（mode = narrative）：不用经验，add_xp 不做事，解锁全走 skill-tree.gd 的 apply_story。

const DEFAULTS := {
	"mode": "xp",            # xp | narrative
	"curve": "medium_fast",  # erratic / fast / medium_fast / medium_slow / slow / fluctuating（宝可梦六种）；linear / table（通用）
	"base": 100,             # linear：1→2 级要的经验
	"growth": 50,            # linear：之后每级多要多少
	"table": [],             # table：第 i 项 = 从 i+1 级升到 i+2 级要的经验；比等级少时沿用最后一项
	"max_level": 100,        # 宝可梦 100 级封顶
	"at_cap": "discard",     # 满级后多出的经验：discard 清零并报出数量（原作满级不再获得经验）/ bank 存着，放开上限后补升
	"points_per_level": 1,   # 每级技能点（暗黑 2：1）
	"attribute_points_per_level": 5,  # 每级属性点（暗黑 2：5），交给界面让玩家分配
	"stats_per_level": {},   # 每升一级自动加的属性（交给 stats-modifiers 的 base），原作没有，留给别的游戏
	"rewards": {},           # 特定等级的额外奖励："5": {"points": 1, "unlock": ["id"], "stats": {"vit": 2}}
}
const POKEMON_CURVES := ["erratic", "fast", "medium_fast", "medium_slow", "slow", "fluctuating"]

var params: Dictionary
var level: int = 1
var xp: int = 0   # 当前等级内已攒的经验
var tree          # skill-tree.gd 实例，可为空


func _init(data: Dictionary = {}, tree_ref = null) -> void:
	params = DEFAULTS.duplicate(true)
	for k in data:
		params[k] = data[k]
	tree = tree_ref


func max_level() -> int:
	return int(params.max_level)


## 到达 lv 级的累计经验（宝可梦公式，向下取整；1 级定为 0）。
## 不规则（erratic）和起伏（fluctuating）是分段函数，分段边界照原作：< 50 / 50–67 / 68–97 / 98+，< 15 / 15–35 / 36+。
@warning_ignore("integer_division")
static func pokemon_total(curve: String, lv: int) -> int:
	if lv <= 1:
		return 0  # 第三世代起查表，1 级为 0；较慢（medium_slow）公式在 1 级会算出 −54
	var n3 := lv * lv * lv
	match curve:
		"fast":
			return 4 * n3 / 5
		"medium_slow":
			return 6 * n3 / 5 - 15 * lv * lv + 100 * lv - 140
		"slow":
			return 5 * n3 / 4
		"erratic":
			if lv < 50:
				return n3 * (100 - lv) / 50
			if lv < 68:
				return n3 * (150 - lv) / 100
			if lv < 98:
				return n3 * ((1911 - 10 * lv) / 3) / 500
			return n3 * (160 - lv) / 100
		"fluctuating":
			if lv < 15:
				return n3 * ((lv + 1) / 3 + 24) / 50
			if lv < 36:
				return n3 * (lv + 14) / 50
			return n3 * (lv / 2 + 32) / 50
	return n3  # medium_fast


## 从 lv 升到 lv+1 要的经验。宝可梦曲线 = total(lv+1) − total(lv)：把 total(lv) 直接当成本级所需是最常见的差一级错误。
func xp_to_next(lv: int) -> int:
	var c := str(params.curve)
	var need := 0
	if c in POKEMON_CURVES:
		need = pokemon_total(c, lv + 1) - pokemon_total(c, lv)
	elif c == "table":
		var t: Array = params.table
		need = int(t[clampi(lv - 1, 0, t.size() - 1)]) if not t.is_empty() else int(params.base)
	else:
		need = int(params.base) + int(params.growth) * (lv - 1)  # linear：lv=1 就是 1→2 级
	return maxi(1, need)  # 数据写成 0 或负数时按 1 算，避免死循环


## 从 1 级升到 lv 级一共要多少经验（给数值表和测试用）
func total_xp_for(lv: int) -> int:
	var c := str(params.curve)
	if c in POKEMON_CURVES:
		return pokemon_total(c, lv)
	var sum := 0
	for l in range(1, lv):
		sum += xp_to_next(l)
	return sum


## 加经验。返回 {from, to, levels, rewards: [每级一条], discarded, ignored}
func add_xp(amount: int) -> Dictionary:
	var out := {"from": level, "to": level, "levels": 0, "rewards": [], "discarded": 0, "ignored": false}
	if str(params.mode) == "narrative" or amount <= 0:
		out.ignored = true
		return out
	xp += amount
	return _resolve(out)


func _resolve(out: Dictionary) -> Dictionary:
	while level < max_level() and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		out.rewards.append(_reward(level))
	if level >= max_level() and str(params.at_cap) == "discard" and xp > 0:
		out.discarded = int(out.discarded) + xp
		xp = 0
	out.to = level
	out.levels = level - int(out.from)
	return out


func _reward(lv: int) -> Dictionary:
	var extra: Dictionary = params.rewards.get(str(lv), {})
	var rew := {
		"level": lv,
		"points": int(params.points_per_level) + int(extra.get("points", 0)),
		"attr_points": int(params.attribute_points_per_level),
		"unlock": extra.get("unlock", []).duplicate(),
		"stats": params.stats_per_level.duplicate(),
	}
	var add_stats: Dictionary = extra.get("stats", {})
	for s in add_stats:
		rew.stats[s] = float(rew.stats.get(s, 0.0)) + float(add_stats[s])
	if tree:
		tree.level = lv  # 技能的需求等级按角色等级判断
		tree.add_points(rew.points)
		for u in rew.unlock:
			tree.grant(str(u), "level")
	return rew


## 改等级上限（资料片放开上限）。bank 模式下存着的经验立刻补升。
func set_max_level(n: int) -> Dictionary:
	params.max_level = maxi(1, n)
	level = mini(level, max_level())
	return _resolve({"from": level, "to": level, "levels": 0, "rewards": [], "discarded": 0, "ignored": false})


## 给经验条用
func progress() -> Dictionary:
	var at_cap := level >= max_level()
	var need := xp_to_next(level)
	return {"level": level, "xp": xp, "need": need, "ratio": 1.0 if at_cap else float(xp) / need, "at_cap": at_cap}


func to_save() -> Dictionary:
	return {"level": level, "xp": xp}


## JSON 读回的数是 float，这里转回 int；数据里上限调低了就夹住。
func load_save(d: Dictionary) -> void:
	level = clampi(int(d.get("level", 1)), 1, max_level())
	xp = maxi(0, int(d.get("xp", 0)))
	if tree:
		tree.level = level
