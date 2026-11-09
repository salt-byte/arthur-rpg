extends SceneTree
## 无头测试：godot --headless -s res://xp-progression/test_xp-progression.gd

const Progression := preload("xp-progression.gd")
const SkillTree := preload("skill-tree.gd")
const ID := "xp-progression"

var data: Dictionary
var failed := 0


func _init() -> void:
	var path: String = get_script().resource_path.get_base_dir() + "/example.json"
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	_case("six_curves_match_reference", _t_six_curves())
	_case("total_vs_next_offbyone", _t_offbyone())
	_case("medium_slow_level1_not_negative", _t_medium_slow_l1())
	_case("piecewise_segments_continuous", _t_piecewise())
	_case("multi_level_from_one_gain", _t_multi_level())
	_case("cap_discard_reports_excess", _t_cap_discard())
	_case("cap_bank_then_raise", _t_cap_bank())
	_case("level_rewards_from_data", _t_rewards())
	_case("prereq_and_flag_enforced", _t_prereq())
	_case("one_point_per_level_past_req", _t_level_req())
	_case("max_20_hard_points", _t_max_rank())
	_case("points_not_spent_twice", _t_points_once())
	_case("narrative_story_unlocks", _t_narrative())
	_case("save_roundtrip_ints", _t_save())
	quit(1 if failed > 0 else 0)


func _case(name: String, why: String) -> void:
	if why == "":
		print("[test] %s %s PASS" % [ID, name])
	else:
		failed += 1
		print("[test] %s %s FAIL %s" % [ID, name, why])


func _curve(c: String) -> Progression:
	return Progression.new({"curve": c})


## 100 级累计经验是 Bulbapedia 列出的六个数；2–5 级是公式向下取整的结果
func _t_six_curves() -> String:
	var ref := {
		"erratic": [600000, 15, 52, 122, 237],
		"fast": [800000, 6, 21, 51, 100],
		"medium_fast": [1000000, 8, 27, 64, 125],
		"medium_slow": [1059860, 9, 57, 96, 135],
		"slow": [1250000, 10, 33, 80, 156],
		"fluctuating": [1640000, 4, 13, 32, 65],
	}
	for c in ref:
		var p := _curve(c)
		if p.total_xp_for(100) != ref[c][0]:
			return "%s 100 级累计 %d，应为 %d" % [c, p.total_xp_for(100), ref[c][0]]
		for lv in range(2, 6):
			if p.total_xp_for(lv) != ref[c][lv - 1]:
				return "%s %d 级累计 %d，应为 %d" % [c, lv, p.total_xp_for(lv), ref[c][lv - 1]]
	if _curve("fluctuating").total_xp_for(10) != 540:
		return "起伏曲线 10 级应为 540"
	if Progression.new({}).params.curve != "medium_fast":
		return "默认曲线应为 medium_fast（n³）"
	return ""


func _t_offbyone() -> String:
	var p := Progression.new(data.progression)
	if p.xp_to_next(1) != 8 or p.xp_to_next(2) != 19:
		return "n³ 曲线 1→2=%d 2→3=%d，应为 8 / 27−8=19（把 total(2)=27 当 2→3 所需是差一级）" % [p.xp_to_next(1), p.xp_to_next(2)]
	p.add_xp(7)
	if p.level != 1:
		return "7 经验就升级了（1→2 要 8）"
	p.add_xp(1)
	if p.level != 2 or p.xp != 0:
		return "正好 8 经验应升到 2 级、余 0，实际 %d 级 %d" % [p.level, p.xp]
	var lin := Progression.new(data.curve_samples.linear)
	var tab := Progression.new(data.curve_samples.table)
	if lin.xp_to_next(1) != 100 or tab.xp_to_next(1) != 80 or tab.xp_to_next(9) != 320:
		return "linear / table 的第一项应对应 1→2 级，table 超出表长沿用最后一项"
	return ""


func _t_medium_slow_l1() -> String:
	var p := _curve("medium_slow")
	if p.total_xp_for(1) != 0 or p.xp_to_next(1) != 9:
		return "较慢曲线 1 级应为 0（公式算出 −54），1→2 应要 9，实际 %d / %d" % [p.total_xp_for(1), p.xp_to_next(1)]
	p.add_xp(9)
	if p.level != 2:
		return "9 经验应升到 2 级"
	return ""


func _t_piecewise() -> String:
	var e := _curve("erratic")
	var exp_e := {49: 120001, 50: 125000, 67: 249633, 68: 257834, 97: 571333, 98: 583539}
	for lv in exp_e:
		if e.total_xp_for(lv) != exp_e[lv]:
			return "不规则曲线 %d 级 %d，应为 %d（50–67 级是 (150−n)/100，写成 15−n 会变负）" % [lv, e.total_xp_for(lv), exp_e[lv]]
	var f := _curve("fluctuating")
	var exp_f := {14: 1591, 15: 1957, 35: 42017, 36: 46656}
	for lv in exp_f:
		if f.total_xp_for(lv) != exp_f[lv]:
			return "起伏曲线 %d 级 %d，应为 %d" % [lv, f.total_xp_for(lv), exp_f[lv]]
	for c in Progression.POKEMON_CURVES:
		var p := _curve(c)
		for lv in range(1, 100):
			if p.xp_to_next(lv) <= 0 or p.total_xp_for(lv + 1) <= p.total_xp_for(lv):
				return "%s 在 %d→%d 级不递增" % [c, lv, lv + 1]
	return ""


func _t_multi_level() -> String:
	var p := Progression.new(data.progression)
	var r: Dictionary = p.add_xp(p.total_xp_for(4) + 10)
	if p.level != 4 or p.xp != 10 or r.levels != 3:
		return "一次给 74 经验应连升到 4 级余 10，实际 %d 级 %d 余" % [p.level, p.xp]
	var lv: Array = r.rewards.map(func(x): return x.level)
	if lv != [2, 3, 4]:
		return "每升一级都要有一条奖励，实际 %s" % [lv]
	return ""


func _t_cap_discard() -> String:
	var p := Progression.new(data.progression)
	var r: Dictionary = p.add_xp(1000300)
	if p.level != 100 or p.xp != 0 or r.discarded != 300:
		return "100 级封顶应丢弃 300 并报出，实际 %d 级 xp=%d discarded=%d" % [p.level, p.xp, r.discarded]
	r = p.add_xp(50)
	if p.level != 100 or r.discarded != 50 or r.levels != 0:
		return "满级后再加经验应全部报为丢弃"
	if not p.progress().at_cap:
		return "progress() 没标出满级"
	return ""


func _t_cap_bank() -> String:
	var cfg: Dictionary = data.progression.duplicate(true)
	cfg.at_cap = "bank"
	cfg.max_level = 5
	var p := Progression.new(cfg)
	p.add_xp(525)
	if p.level != 5 or p.xp != 400:
		return "bank 模式 5 级封顶应存着 525−125=400，实际 %d 级 %d" % [p.level, p.xp]
	var r: Dictionary = p.set_max_level(7)
	if p.level != 7 or p.xp != 182 or r.levels != 2:
		return "放开到 7 级后应补升到 7 级余 400−91−127=182，实际 %d 级 %d" % [p.level, p.xp]
	return ""


func _t_rewards() -> String:
	var cfg: Dictionary = data.progression.duplicate(true)
	cfg.rewards = {"3": {"points": 1, "unlock": ["strike"]}, "5": {"stats": {"str": 2}}}
	var tree := SkillTree.new(data.skill_tree)
	var p := Progression.new(cfg, tree)
	var r: Dictionary = p.add_xp(p.total_xp_for(5))
	if tree.points != 5 or tree.level != 5:
		return "升到 5 级应得 4×1 + 3 级额外 1 = 5 点、树的等级同步为 5，实际 %d 点 %d 级" % [tree.points, tree.level]
	if tree.unlocked.get("strike", "") != "level" or tree.rank("strike") != 1:
		return "3 级奖励的 strike 没解锁"
	var last: Dictionary = r.rewards[-1]
	if last.level != 5 or last.attr_points != 5 or last.stats.get("str", 0.0) != 2.0:
		return "5 级奖励不对：%s" % [last]
	return ""


func _t_prereq() -> String:
	var tree := SkillTree.new(data.skill_tree)
	tree.level = 12
	tree.add_points(6)
	var r: Dictionary = tree.buy("cleave")
	if r.ok or r.reason != "missing_prereq" or tree.points != 6:
		return "strike 没投点也投进了 cleave：%s" % [r]
	tree.buy("strike")
	if not tree.buy("cleave").ok or tree.points != 4:
		return "满足前置后投 cleave 失败"
	r = tree.buy("whirl")
	if r.ok or r.missing != ["guard"]:
		return "whirl 缺 guard 应报出来：%s" % [r]
	r = tree.buy("blood_rite")
	if r.ok or r.reason != "missing_flag":
		return "没被转化也投进了 blood_rite"
	if not tree.buy("blood_rite", {"vamp": true}).ok:
		return "vamp 为真时投 blood_rite 失败"
	var t2 := SkillTree.new(data.skill_tree)
	t2.level = 6
	t2.add_points(1)
	t2.grant("strike", "story")
	if not t2.buy("cleave").ok:
		return "剧情给的前置也应算数"
	return ""


func _t_level_req() -> String:
	var tree := SkillTree.new(data.skill_tree)
	tree.add_points(10)
	tree.level = 5
	tree.buy("strike")
	var r: Dictionary = tree.buy("cleave")
	if r.reason != "level_too_low" or r.need != 6:
		return "5 级不能投需求 6 级的技能：%s" % [r]
	r = tree.buy("strike")
	if not r.ok or tree.rank("strike") != 2:
		return "5 级时需求 1 级的技能应能投到 5 点"
	tree.level = 6
	if not tree.buy("cleave").ok:
		return "6 级应能投第 1 点 cleave"
	r = tree.buy("cleave")
	if r.ok or r.reason != "need_level" or r.need != 7:
		return "6 级时 cleave 只能有 1 点，第 2 点要 7 级：%s" % [r]
	tree.level = 7
	if not tree.buy("cleave").ok or tree.rank("cleave") != 2:
		return "7 级应能投第 2 点 cleave"
	return ""


func _t_max_rank() -> String:
	var tree := SkillTree.new(data.skill_tree)
	tree.level = 99
	tree.add_points(30)
	for i in 20:
		if not tree.buy("strike").ok:
			return "第 %d 点投不进去" % (i + 1)
	var r: Dictionary = tree.buy("strike")
	if r.ok or r.reason != "max_rank" or tree.points != 10:
		return "第 21 点应被拒（上限 20）：%s" % [r]
	return ""


func _t_points_once() -> String:
	var tree := SkillTree.new(data.skill_tree)
	tree.add_points(3)
	tree.buy("strike")
	var r: Dictionary = tree.buy("strike")
	if r.ok or tree.points != 2:
		return "1 级时同一技能投了两点或扣了两次点：points=%d" % tree.points
	if tree.respec().refunded != 1 or tree.points != 3:
		return "洗点应退 1 点"
	r = tree.respec()
	if r.ok or tree.points != 3:
		return "洗点次数用完后又退了点"
	tree.add_respec_charges(1)
	tree.level = 3
	tree.buy("strike")
	tree.buy("strike")
	tree.grant("strike", "story")
	if tree.points != 2 or tree.rank("strike") != 2 or tree.unlocked.strike != "story":
		return "投过 2 点的技能被剧情送了 1 级后应退 1 点、等级不变，points=%d rank=%d" % [tree.points, tree.rank("strike")]
	tree.respec()
	if tree.rank("strike") != 1 or tree.points != 3:
		return "洗点应只拿走投的那 1 点、留下剧情给的 1 级"
	return ""


func _t_narrative() -> String:
	var n: Dictionary = data.narrative
	var tree := SkillTree.new(n.skill_tree)
	var p := Progression.new(n.progression, tree)
	if not p.add_xp(500).ignored or p.level != 1:
		return "叙事模式下经验应被忽略"
	var got: Array = tree.apply_story(["1103"])
	if got.size() != 1 or got[0].id != "u_interrupt":
		return "走到 1103 应解锁 u_interrupt：%s" % [got]
	if not tree.apply_story(["1103"]).is_empty():
		return "同一节点重复调用又给了一次"
	tree.apply_story({"1103": true, "1303": true}, {"D2b": false})
	if not tree.is_unlocked("u_scabbard") or tree.is_unlocked("u_still_water"):
		return "D2b 为假时不该给 u_still_water"
	tree.apply_story(["1103", "1303", "1305"], {"D2b": true, "D3a": true})
	if not tree.is_unlocked("u_still_water") or not tree.is_unlocked("u_deflect"):
		return "变量变真后再调应补上 u_still_water 和 u_deflect"
	got = tree.apply_story(["1103", "1303", "1305", "1402"], {"D2b": true, "D3a": true})
	if tree.is_unlocked("u_scabbard") or got.size() != 1 or got[0].change != "lost":
		return "1402 的 lose 应拿走剑鞘：%s" % [got]
	var t2 := SkillTree.new(n.skill_tree)
	t2.load_save(JSON.parse_string(JSON.stringify(tree.to_save())))
	if not t2.apply_story(["1103", "1303", "1305", "1402"], {"D2b": true, "D3a": true}).is_empty() or t2.is_unlocked("u_scabbard"):
		return "读档后补跑剧情解锁时又把丢掉的剑鞘给回来了"
	return ""


func _t_save() -> String:
	var tree := SkillTree.new(data.skill_tree)
	var p := Progression.new(data.progression, tree)
	p.add_xp(p.total_xp_for(6) + 10)
	tree.buy("strike")
	tree.buy("cleave")
	var text := JSON.stringify({"p": p.to_save(), "t": tree.to_save()})
	var d: Dictionary = JSON.parse_string(text)
	var tree2 := SkillTree.new(data.skill_tree)
	var p2 := Progression.new(data.progression, tree2)
	tree2.load_save(d.t)
	p2.load_save(d.p)
	if typeof(p2.level) != TYPE_INT or p2.level != 6 or p2.xp != 10 or tree2.level != 6:
		return "读档后等级/经验不对"
	if tree2.points != tree.points or tree2.rank("cleave") != 1 or typeof(tree2.ranks.cleave) != TYPE_INT:
		return "读档后技能树不对：%s" % [tree2.to_save()]
	p2.add_xp(p2.xp_to_next(6) - 10)
	if p2.level != 7 or p2.xp != 0:
		return "读档后接着升级失败"
	return ""
