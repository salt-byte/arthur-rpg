extends RefCounted
## 照搬自 ai-rpg-studio 插件 mechanics-library（参考代码，带自动测试）；本项目不改规则，只从 content/data 传参数。
## 技能树 + 统一解锁接口。投点规则照暗黑破坏神 2：
##   每个技能有需求等级（原作分档 1 / 6 / 12 / 18 / 24 / 30），角色等级不到不能投；
##   前置技能每个至少投 1 点；同一技能每超过需求等级 1 级才能多投 1 点；每个技能最多 20 点（装备加的不算）。
## 三种来源写进同一张 unlocked 表，界面和战斗只问 is_unlocked(id) / rank(id)：
##   buy(id)          花技能点投 1 点，查前置、需求等级、剧情身份
##   grant(id, 来源)  升级奖励、任务奖励直接给 1 级，免费，不查前置（原作没有，留给剧情游戏）
##   apply_story()    剧情走到某个节点、满足变量条件时给（arthur-rpg 的 story-unlocks.json 格式）
## 叙事成长的游戏只用 apply_story，不用点数。

const DEFAULTS := {
	"nodes": {},              # id -> {"cost": 1, "level_req": 1, "max_rank": 20, "requires": [前置 id], "flags": [剧情变量]}
	"max_rank": 20,           # 每个技能最多投几点（暗黑 2：20）
	"respec_charges": 1,      # 能洗几次点（暗黑 2：第一个任务的奖励可洗一次，之后靠道具）；-1 不限
	"respec_refund": 1.0,     # 洗点退还比例，按投点时花的点算
	"story_unlocks": [],      # [{"id", "at": 剧情节点, "requires": [变量], "kind", "what"}]；kind = lose 时拿走同 what 的解锁
}

var params: Dictionary
var level: int = 1               # 角色等级，xp-progression 升级 / 读档时更新
var points: int = 0
var ranks: Dictionary = {}       # id -> 花点投进去的点数（原作叫硬点）
var unlocked: Dictionary = {}    # id -> 第一次解锁的来源 "bought" / "level" / "story" / 自定义
var paid: Dictionary = {}        # id -> 一共花在这个技能上的点（洗点按这个退）
var story_done: Dictionary = {}  # 已经处理过的剧情条目 id（不论给还是拿）
var respec_left: int = 0


func _init(data: Dictionary = {}) -> void:
	params = DEFAULTS.duplicate(true)
	for k in data:
		params[k] = data[k]
	respec_left = int(params.respec_charges)


func add_points(n: int) -> void:
	points += maxi(0, n)


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


## 当前等级 = 投的点 + 免费给的 1 级
func rank(id: String) -> int:
	var free := 1 if unlocked.has(id) and unlocked[id] != "bought" else 0
	return int(ranks.get(id, 0)) + free


## 能不能投 1 点；不能时 reason 是 unknown / missing_prereq / missing_flag / level_too_low / need_level / max_rank / no_points
func can_buy(id: String, flags: Dictionary = {}) -> Dictionary:
	var node: Dictionary = params.nodes.get(id, {})
	if node.is_empty():
		return {"ok": false, "reason": "unknown"}
	var missing: Array = []
	for r in node.get("requires", []):
		if rank(str(r)) < 1:
			missing.append(r)
	if not missing.is_empty():
		return {"ok": false, "reason": "missing_prereq", "missing": missing}
	for f in node.get("flags", []):
		if not flags.get(f, false):
			missing.append(f)
	if not missing.is_empty():
		return {"ok": false, "reason": "missing_flag", "missing": missing}
	var req := int(node.get("level_req", 1))
	if level < req:
		return {"ok": false, "reason": "level_too_low", "need": req}
	var r := rank(id)
	if r >= int(node.get("max_rank", params.max_rank)):
		return {"ok": false, "reason": "max_rank"}
	if r >= level - req + 1:  # 需求等级时能投 1 点，之后每升 1 级多 1 点
		return {"ok": false, "reason": "need_level", "need": req + r}
	var cost := int(node.get("cost", 1))
	if points < cost:
		return {"ok": false, "reason": "no_points", "cost": cost}
	return {"ok": true, "cost": cost}


func buy(id: String, flags: Dictionary = {}) -> Dictionary:
	var c := can_buy(id, flags)
	if not c.ok:
		return c
	points -= int(c.cost)
	ranks[id] = int(ranks.get(id, 0)) + 1
	paid[id] = int(paid.get(id, 0)) + int(c.cost)
	if not unlocked.has(id):
		unlocked[id] = "bought"
	return {"ok": true, "id": id, "spent": c.cost, "rank": rank(id), "points": points}


## 免费给 1 级。已经花点投过的，第一点转成免费并退回那一点（剧情送了就不该再占着玩家的点）。
func grant(id: String, source: String = "story") -> bool:
	if unlocked.get(id, "") == "bought":
		var cost := int(params.nodes.get(id, {}).get("cost", 1))
		ranks[id] = int(ranks[id]) - 1
		paid[id] = int(paid[id]) - cost
		points += cost
		unlocked[id] = source
		return true
	if unlocked.has(id):
		return false
	unlocked[id] = source
	return true


## 拿走一个解锁，投在上面的点退回
func revoke(id: String) -> bool:
	points += int(paid.get(id, 0))
	paid.erase(id)
	ranks.erase(id)
	return unlocked.erase(id)


func add_respec_charges(n: int) -> void:
	if respec_left >= 0:
		respec_left += n


## 洗点：拿掉所有花点投的等级，按当时花的点退；升级和剧情给的那 1 级留着。
func respec() -> Dictionary:
	if respec_left == 0:
		return {"ok": false, "reason": "no_charges"}
	var refund := 0
	var removed: Array = []
	for id in paid:
		refund += int(floor(int(paid[id]) * float(params.respec_refund)))
		removed.append(id)
		if unlocked.get(id, "") == "bought":
			unlocked.erase(id)
	paid.clear()
	ranks.clear()
	points += refund
	if respec_left > 0:
		respec_left -= 1
	return {"ok": true, "refunded": refund, "removed": removed}


## 剧情解锁。reached：走过的节点（Array 或 Dictionary 都行，按 has() 查）；flags：剧情变量。
## 每条只处理一次，可以每走一个节点调一次，也可以读档后整体再调一次补齐。按数据顺序处理。
func apply_story(reached, flags: Dictionary = {}) -> Array:
	var out: Array = []
	for e in params.story_unlocks:
		var eid := str(e.id)
		if story_done.has(eid) or not reached.has(str(e.get("at", ""))):
			continue
		var ok := true
		for f in e.get("requires", []):
			if not flags.get(f, false):
				ok = false
		if not ok:
			continue  # 条件没满足：这次不记 done，变量以后变真了还能补上
		story_done[eid] = true
		if str(e.get("kind", "")) == "lose":
			for other in params.story_unlocks:
				var oid := str(other.id)
				if oid != eid and str(other.get("what", "")) == str(e.get("what", "")) and unlocked.has(oid):
					revoke(oid)
					out.append({"id": oid, "change": "lost", "by": eid})
		elif grant(eid, "story"):
			out.append({"id": eid, "change": "gained", "kind": e.get("kind", ""), "what": e.get("what", "")})
	return out


## 等级不在这里存，由 xp-progression 读档时写回 level
func to_save() -> Dictionary:
	return {"points": points, "ranks": ranks.duplicate(), "unlocked": unlocked.duplicate(), "paid": paid.duplicate(),
		"story_done": story_done.keys(), "respec_left": respec_left}


func load_save(d: Dictionary) -> void:
	points = int(d.get("points", 0))
	respec_left = int(d.get("respec_left", params.respec_charges))
	unlocked = d.get("unlocked", {}).duplicate()
	ranks.clear()
	paid.clear()
	var rk: Dictionary = d.get("ranks", {})
	for id in rk:
		ranks[id] = int(rk[id])  # JSON 读回是 float
	var pd: Dictionary = d.get("paid", {})
	for id in pd:
		paid[id] = int(pd[id])
	story_done.clear()
	for id in d.get("story_done", []):
		story_done[str(id)] = true
