extends SceneTree
## overworld-grid 无头测试：godot --headless -s res://overworld-grid/test_overworld-grid.gd

const Overworld = preload("overworld-grid.gd")
const R := Vector2i(1, 0)
const L := Vector2i(-1, 0)
const U := Vector2i(0, -1)
const D := Vector2i(0, 1)
var failed := 0


func _init() -> void:
	_example_flow()
	_walk_and_bump()
	_patrol_and_cadence()
	_two_enemies_one_cell()
	_enemy_walks_into_player()
	_contact_modes()
	_no_chase_through_wall()
	_defeated_no_respawn()
	_talk_once()
	_exit_spawn_in_wall()
	_flee_grace()
	_deterministic_order()
	_chase_chance()
	_zone_and_boss()
	_flee_to_shrine()
	_shrine_respawn()
	quit(1 if failed > 0 else 0)


func check(case_name: String, errs: Array) -> void:
	if errs.is_empty():
		print("[test] overworld-grid %s PASS" % case_name)
	else:
		failed += 1
		print("[test] overworld-grid %s FAIL %s" % [case_name, "; ".join(errs)])


## 大多数用例要可预测的敌人：默认必追、不追时站着；要测概率和游荡的用例自己覆盖。
func mk(maps: Dictionary, params: Dictionary = {}, seed_value: int = 1) -> RefCounted:
	var o = Overworld.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var base := {"chase_chance": 1.0, "idle": "stay"}
	base.merge(params, true)
	o.setup({"maps": maps}, base, rng)
	return o


## 往 dir 连走最多 n 步，碰上敌人就停下返回那条 encounter（没碰上返回 {}）。
func walk_until_encounter(o, dir: Vector2i, n: int) -> Dictionary:
	for i in n:
		var es := of_type(o.step(dir), "encounter")
		if not es.is_empty():
			return es[0]
	return {}


func of_type(ev: Array, t: String) -> Array:
	return ev.filter(func(x): return x.type == t)


func enemy_cell(o, id: String) -> Vector2i:
	for e in o.enemies:
		if e.id == id:
			return e.cell
	return Vector2i(-1, -1)


func enemy_ids(o) -> Array:
	return o.enemies.map(func(x): return x.id)


func load_example() -> Dictionary:
	var path: String = (get_script() as Script).resource_path.get_base_dir() + "/example.json"
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# 正常流程（example.json，原作规则）：和长老说话 → 神龛祈祷 → 进森林碰上敌人 → 逃跑传回神龛 →
# 再进森林碰上 → 打赢 → 出去再回来，打败的敌人不在
func _example_flow() -> void:
	var e := []
	var o = Overworld.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	o.setup(load_example(), {}, rng)
	var log: Array = o.enter_map("village", Vector2i(1, 3))
	for dir in [R, R, R]:
		log.append_array(o.step(dir))
	var talks := of_type(log, "talk")
	if talks.size() != 1 or talks[0].id != "elder": e.append("走到长老下面应开口一次，得到 %s" % [talks])
	for dir in [R, R, U]:
		o.step(dir)
	var prayed := of_type(o.step(U), "pray")
	if prayed.size() != 1 or not prayed[0].heal or o.last_shrine.get("cell") != Vector2i(6, 2): e.append("撞上神龛应祈祷、回血、记下站位 (6,2)，得到 %s" % [prayed])
	for dir in [D, R, R, R]:
		o.step(dir)
	if o.map_id != "forest" or o.player != Vector2i(1, 3): e.append("走上出口应到森林 (1,3)，在 %s %s" % [o.map_id, o.player])
	var enc := walk_until_encounter(o, R, 10)
	if enc.is_empty(): e.append("森林里走一趟应碰上敌人")
	else:
		var fled: Array = o.after_battle(enc.id, false)
		if o.map_id != "village" or o.player != Vector2i(6, 2) or of_type(fled, "fled")[0].get("to_shrine", "") != "village_shrine":
			e.append("逃跑应传回神龛前 (6,2)，在 %s %s" % [o.map_id, o.player])
	for dir in [D, R, R, R]:
		o.step(dir)
	var enc2 := walk_until_encounter(o, R, 10)
	if enc2.is_empty(): e.append("第二次进森林应碰上敌人")
	else:
		o.after_battle(enc2.id, true)
		for i in 15:
			if o.map_id == "village":
				break
			var es := of_type(o.step(L), "encounter")
			if not es.is_empty():
				o.after_battle(es[0].id, true)
		o.step(R)
		if o.map_id != "forest" or enemy_ids(o).has(enc2.id): e.append("回森林后打败的 %s 不该在，敌人 %s" % [enc2.id, enemy_ids(o)])
	check("example_flow", e)


func _walk_and_bump() -> void:
	var e := []
	var o = mk({"m": {"rows": ["######", "#....#", "######"], "enemies": [{"id": "x", "cell": [4, 1], "chase_radius": 9}]}})
	o.enter_map("m", Vector2i(1, 1))
	var ev: Array = o.step(L)
	if o.player != Vector2i(1, 1) or of_type(ev, "bump").size() != 1: e.append("撞墙应原地不动并发 bump")
	if enemy_cell(o, "x") != Vector2i(4, 1) or o.steps != 0: e.append("撞墙不算一回合，敌人不该动")
	if o.facing != L: e.append("撞墙也要转身")
	ev = o.step(D)
	if o.player != Vector2i(1, 1): e.append("往下也是墙")
	check("walk_and_bump", e)


func _patrol_and_cadence() -> void:
	var e := []
	var maps := {"m": {"rows": ["########", "#......#", "########", "#......#", "########"],
		"enemies": [{"id": "s", "cell": [1, 1], "idle": "patrol", "patrol": [[1, 1], [5, 1]], "chase_radius": 0}]}}
	var o = mk(maps)
	o.enter_map("m", Vector2i(2, 3))
	var xs := []
	for i in 6:
		o.step(R if i % 2 == 0 else L)
		xs.append(enemy_cell(o, "s").x)
	if xs != [2, 3, 4, 5, 4, 3]: e.append("巡逻路线不对 %s" % [xs])
	var o2 = mk(maps, {"enemy_move_every": 2})
	o2.enter_map("m", Vector2i(2, 3))
	var xs2 := []
	for i in 4:
		o2.step(R if i % 2 == 0 else L)
		xs2.append(enemy_cell(o2, "s").x)
	if xs2 != [1, 2, 2, 3]: e.append("enemy_move_every=2 应隔一步走一次 %s" % [xs2])
	check("patrol_and_cadence", e)


# 坑：两个敌人走进同一格
func _two_enemies_one_cell() -> void:
	var e := []
	var o = mk({"m": {"rows": ["#######", "#.#...#", "#.....#", "#.#...#", "#######"],
		"enemies": [{"id": "a", "cell": [1, 1]}, {"id": "b", "cell": [1, 3]}]}}, {"chase_radius": 10})
	o.enter_map("m", Vector2i(5, 2))
	o.step(L)
	if enemy_cell(o, "a") != Vector2i(1, 2) or enemy_cell(o, "b") != Vector2i(1, 3): e.append("a 先占 (1,2)，b 该原地等，得到 a=%s b=%s" % [enemy_cell(o, "a"), enemy_cell(o, "b")])
	for dir in [R, L, R]:
		var ev: Array = o.step(dir)
		if enemy_cell(o, "a") == enemy_cell(o, "b"): e.append("两个敌人重叠在 %s" % enemy_cell(o, "a"))
		if not of_type(ev, "encounter").is_empty():
			break
	check("two_enemies_one_cell", e)


# 坑：只在玩家走完时查碰撞，敌人自己走过来漏掉
func _enemy_walks_into_player() -> void:
	var e := []
	var o = mk({"m": {"rows": ["##########", "#........#", "##########"], "enemies": [{"id": "x", "cell": [6, 1]}]}}, {"chase_radius": 10})
	o.enter_map("m", Vector2i(3, 1))
	var enc := of_type(o.step(R), "encounter")
	if enc.size() != 1 or enc[0].cause != "enemy_moved": e.append("敌人走到旁边应当场开打，得到 %s" % [enc])
	if enemy_cell(o, "x") != Vector2i(5, 1): e.append("敌人应停在 (5,1)")
	check("enemy_walks_into_player", e)


func _contact_modes() -> void:
	var e := []
	var maps := {"m": {"rows": ["##########", "#........#", "##########"], "enemies": [{"id": "x", "cell": [5, 1]}]}}
	var same = mk(maps, {"contact": "same", "chase_radius": 10})
	same.enter_map("m", Vector2i(3, 1))
	var a1: Array = of_type(same.step(L), "encounter")
	var a2: Array = of_type(same.step(R), "encounter")
	if not a1.is_empty(): e.append("same 模式第一步不该开打")
	if a2.size() != 1 or a2[0].cause != "enemy_moved" or enemy_cell(same, "x") != same.player: e.append("same 模式敌人应踩进玩家格开打 %s" % [a2])
	var adj = mk(maps, {"contact": "adjacent", "chase_radius": 10})
	adj.enter_map("m", Vector2i(3, 1))
	adj.step(L)
	var b2: Array = of_type(adj.step(R), "encounter")
	if b2.size() != 1 or b2[0].cause != "player_moved": e.append("adjacent 模式玩家走到旁边就开打 %s" % [b2])
	var diag_maps := {"m": {"rows": ["#####", "#...#", "#...#", "#####"], "enemies": [{"id": "x", "cell": [3, 2], "chase_radius": 0}]}}
	for cd in [false, true]:
		var o = mk(diag_maps, {"contact_diagonal": cd})
		o.enter_map("m", Vector2i(1, 1))
		if of_type(o.step(R), "encounter").is_empty() == cd: e.append("contact_diagonal=%s 斜角判定不对" % cd)
	check("contact_modes", e)


# 坑：隔着墙追，或者按直线距离追
func _no_chase_through_wall() -> void:
	var e := []
	var maps := {"m": {"rows": ["#######", "#..#..#", "#..#..#", "#..#..#", "#.....#", "#######"], "enemies": [{"id": "x", "cell": [4, 1]}]}}
	var o = mk(maps, {"chase_radius": 5})
	o.enter_map("m", Vector2i(2, 1))
	o.step(L)
	o.step(R)
	if enemy_cell(o, "x") != Vector2i(4, 1): e.append("隔墙直线 2 格、绕路 9 格，半径 5 不该追，到了 %s" % enemy_cell(o, "x"))
	var o2 = mk(maps, {"chase_radius": 10})
	o2.enter_map("m", Vector2i(2, 1))
	o2.step(L)
	if enemy_cell(o2, "x") != Vector2i(4, 2): e.append("半径 10 应绕路往下走，到了 %s" % enemy_cell(o2, "x"))
	for i in 8:
		var ev: Array = o2.step(R if i % 2 == 0 else L)
		if not o2.walkable(enemy_cell(o2, "x")): e.append("敌人进了墙 %s" % enemy_cell(o2, "x"))
		if not of_type(ev, "encounter").is_empty():
			break
	check("no_chase_through_wall", e)


# 坑：重新进图、读档以后打败的敌人又出来了
func _defeated_no_respawn() -> void:
	var e := []
	var maps := {
		"village": {"rows": ["#####", "#...#", "#####"], "exits": [{"cell": [3, 1], "to": "forest", "at": [2, 1]}]},
		"forest": {"rows": ["#########", "#.......#", "#########"], "exits": [{"cell": [1, 1], "to": "village", "at": [2, 1]}],
			"enemies": [{"id": "wolf", "cell": [5, 1], "chase_radius": 0}, {"id": "ogre", "cell": [7, 1], "chase_radius": 0, "respawn": false}]},
	}
	var o = mk(maps)
	o.enter_map("forest", Vector2i(2, 1))
	o.after_battle("wolf", true)
	o.step(L)
	o.step(R)
	if o.map_id != "forest" or enemy_ids(o).has("wolf"): e.append("离开再回来狼不该出现 %s" % [enemy_ids(o)])
	var saved: Variant = JSON.parse_string(JSON.stringify(o.save_state()))
	var o2 = mk(maps)
	o2.load_state(saved)
	if enemy_ids(o2).has("wolf") or not enemy_ids(o2).has("ogre"): e.append("读档后敌人不对 %s" % [enemy_ids(o2)])
	var o3 = mk(maps, {"respawn": true})
	o3.enter_map("forest", Vector2i(2, 1))
	o3.after_battle("wolf", true)
	o3.after_battle("ogre", true)
	o3.step(L)
	o3.step(R)
	if not enemy_ids(o3).has("wolf") or enemy_ids(o3).has("ogre"): e.append("respawn=true 时狼回来、写了 respawn:false 的食人魔不回来 %s" % [enemy_ids(o3)])
	check("defeated_no_respawn", e)


# 坑：自动开口每帧都触发
func _talk_once() -> void:
	var e := []
	var maps := {"m": {"rows": ["#######", "#.....#", "#######"], "npcs": [{"id": "elder", "cell": [4, 1], "node": "Elder_Hi"}]}}
	var o = mk(maps)
	o.enter_map("m", Vector2i(1, 1))
	var n := 0
	n += of_type(o.step(R), "talk").size()
	n += of_type(o.step(R), "talk").size()
	if n != 1: e.append("走到旁边应开口一次，得到 %d" % n)
	var spam := 0
	for i in 60:
		spam += o.check_talk().size()
	spam += of_type(o.step(R), "talk").size()
	spam += of_type(o.step(U), "talk").size()
	if spam != 0: e.append("站着不动、撞人、撞墙不该再开口，多了 %d 次" % spam)
	o.step(L)
	if of_type(o.step(R), "talk").size() != 1: e.append("走开再回来应再开口")
	var manual: Array = o.interact()
	if manual.size() != 1 or manual[0].auto: e.append("按确认键应开口")
	var maps2 := {"m": {"rows": ["#####", "#...#", "#...#", "#####"], "npcs": [{"id": "kid", "cell": [1, 2]}]}}
	var f = mk(maps2, {"talk": "facing"})
	f.enter_map("m", Vector2i(2, 1))
	if not of_type(f.step(L), "talk").is_empty(): e.append("facing 模式背对着不该开口")
	if of_type(f.step(D), "talk").size() != 1: e.append("facing 模式转身面对应开口")
	check("talk_once", e)


# 坑：出口落点在目标图的墙里
func _exit_spawn_in_wall() -> void:
	var e := []
	var maps := {
		"a": {"rows": ["#####", "#...#", "#####"], "exits": [{"cell": [3, 1], "to": "b", "at": [0, 1]}]},
		"b": {"rows": ["#######", "#.....#", "#######"], "exits": [{"cell": [1, 1], "to": "a", "at": [2, 1]}]},
	}
	var o = mk(maps)
	o.enter_map("a", Vector2i(2, 1))
	var ev: Array = o.step(R)
	var fix := of_type(ev, "spawn_fixed")
	if o.map_id != "b" or not o.walkable(o.player) or o.exits.has(o.player): e.append("落点应挪到能站、又不是出口的格，在 %s" % o.player)
	if o.player != Vector2i(2, 1) or fix.size() != 1: e.append("应挪到 (2,1) 并发 spawn_fixed，得到 %s %s" % [o.player, fix])
	check("exit_spawn_in_wall", e)


func _flee_grace() -> void:
	var e := []
	var o = mk({"m": {"rows": ["#######", "#.....#", "#######"], "enemies": [{"id": "x", "cell": [4, 1], "chase_radius": 0}]}}, {"flee_grace_steps": 3})
	o.enter_map("m", Vector2i(2, 1))
	if of_type(o.step(R), "encounter").is_empty(): e.append("走到旁边应开打")
	var fled: Array = o.after_battle("x", false)
	if fled.is_empty() or fled[0].type != "fled": e.append("逃跑应发 fled")
	var hits := []
	for dir in [L, R, L, R]:
		hits.append(of_type(o.step(dir), "encounter").size())
	if hits != [0, 0, 0, 1]: e.append("逃跑后 3 回合内不该再开打，之后该开打 %s" % [hits])
	check("flee_grace", e)


# 敌人按数据顺序行动；同一个种子跑两遍结果完全一样
func _deterministic_order() -> void:
	var e := []
	var data := load_example()
	var order := ["forest_wolf", "forest_slime", "forest_crow"]
	var runs := []
	for k in 2:
		var o = Overworld.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		o.setup(data, {"chase_radius": 3}, rng)
		var log: Array = o.enter_map("forest", Vector2i(1, 1))
		for dir in [R, R, D, D, R, U, U, R, R, D, L, U, R, R, D]:
			var ev: Array = o.step(dir)
			var last := -1
			for x in of_type(ev, "enemy_moved"):
				var idx := order.find(x.id)
				if idx <= last: e.append("同一回合敌人行动顺序乱了 %s" % [ev])
				last = idx
			log.append_array(ev)
			if not of_type(ev, "encounter").is_empty():
				break
		runs.append(str(log))
	if runs[0] != runs[1]: e.append("同一种子两次结果不同")
	check("deterministic_order", e)


# 追击概率：范围内每回合按 chase_chance 掷一次
func _chase_chance() -> void:
	var e := []
	var maps := {"m": {"rows": ["#########", "#.......#", "#########"], "enemies": [{"id": "x", "cell": [5, 1]}]}}
	for want in [0.0, 1.0, 0.65]:
		var o = mk(maps, {"chase_chance": want, "chase_radius": 4}, 3)
		o.enter_map("m", Vector2i(2, 1))
		var chased := 0
		var tries := 400
		for i in tries:
			o.enemies[0].cell = Vector2i(5, 1)
			if not o._enemy_turn(o.enemies[0]).is_empty():
				chased += 1
		var rate := float(chased) / tries
		if absf(rate - want) > 0.07: e.append("chase_chance=%s 实测 %.2f" % [want, rate])
	check("chase_chance", e)


# 坑：敌人追出自己的区域被一路拉走；首领被拉出来
func _zone_and_boss() -> void:
	var e := []
	var maps := {"m": {"rows": ["##########", "#........#", "#........#", "##########"],
		"enemies": [{"id": "w", "cell": [5, 1], "zone": [4, 1, 3, 2]}, {"id": "b", "cell": [8, 2], "boss": true}]}}
	var o = mk(maps, {"chase_radius": 10, "idle": "wander"})
	o.enter_map("m", Vector2i(1, 1))
	var zone := Rect2i(4, 1, 3, 2)
	for dir in [R, L, D, U, R, L, D, U]:
		var ev: Array = o.step(dir)
		if not zone.has_point(enemy_cell(o, "w")): e.append("w 出了自己的区域 %s" % enemy_cell(o, "w"))
		if enemy_cell(o, "b") != Vector2i(8, 2): e.append("首领不该动")
		if not of_type(ev, "encounter").is_empty():
			e.append("玩家没走近，区域边上的敌人不该碰上")
			break
	var o2 = mk(maps, {"chase_radius": 10})
	o2.enter_map("m", Vector2i(6, 2))
	o2.enemies.remove_at(0)
	var hit := of_type(o2.step(R), "encounter")
	if hit.size() != 1 or hit[0].id != "b": e.append("首领不动，但玩家走到旁边照样开打")
	check("zone_and_boss", e)


# 原作：逃跑回最后祈祷的神龛（坑：原地逃跑，下一步又被同一个敌人撞上）
func _flee_to_shrine() -> void:
	var e := []
	var maps := {
		"town": {"rows": ["#####", "#...#", "#####"], "shrines": [{"id": "s1", "cell": [1, 1]}], "exits": [{"cell": [3, 1], "to": "wild", "at": [1, 1]}]},
		"wild": {"rows": ["#######", "#.....#", "#######"], "enemies": [{"id": "x", "cell": [4, 1]}]},
	}
	var o = mk(maps, {"chase_radius": 0})
	o.enter_map("town", Vector2i(2, 1))
	if of_type(o.interact(), "pray").size() != 0: e.append("面朝下没有神龛，确认键不该祈祷")
	o.step(L)
	if o.last_shrine.get("id", "") != "s1": e.append("撞上神龛应记下回城点")
	o.step(R)
	if o.map_id != "wild": e.append("应走进野外")
	if walk_until_encounter(o, R, 3).get("id", "") != "x": e.append("走到敌人旁边应开打")
	o.after_battle("x", false)
	if o.map_id != "town" or o.player != Vector2i(2, 1): e.append("逃跑应回到神龛前 (2,1)，在 %s %s" % [o.map_id, o.player])
	var saved: Variant = JSON.parse_string(JSON.stringify(o.save_state()))
	var o2 = mk(maps)
	o2.load_state(saved)
	if o2.last_shrine.get("cell") != Vector2i(2, 1): e.append("回城点要进存档")
	check("flee_to_shrine", e)


# graveholme：祈祷让打败的非首领敌人下次进图回来，首领不回来
func _shrine_respawn() -> void:
	var e := []
	var maps := {
		"camp": {"rows": ["#####", "#...#", "#####"], "shrines": [{"id": "s", "cell": [1, 1]}], "exits": [{"cell": [3, 1], "to": "wild", "at": [2, 1]}]},
		"wild": {"rows": ["#########", "#.......#", "#########"], "exits": [{"cell": [1, 1], "to": "camp", "at": [2, 1]}],
			"enemies": [{"id": "wolf", "cell": [5, 1], "chase_radius": 0}, {"id": "king", "cell": [7, 1], "boss": true}]},
	}
	var d = mk(maps)                                   # 默认照原作：祈祷只回血，打死的不回来
	d.enter_map("wild", Vector2i(2, 1))
	d.after_battle("wolf", true)
	d.step(L)
	var dp := of_type(d.step(L), "pray")
	d.step(R)
	d.step(R)
	if dp.size() != 1 or not dp[0].respawned.is_empty() or enemy_ids(d).has("wolf"): e.append("默认祈祷后 wolf 不该回来，得到 %s / %s" % [dp, enemy_ids(d)])
	var o = mk(maps, {"shrine_respawn": true})
	o.enter_map("wild", Vector2i(2, 1))
	o.after_battle("wolf", true)
	o.after_battle("king", true)
	o.step(L)
	var pr := of_type(o.step(L), "pray")
	if pr.size() != 1 or pr[0].respawned != ["wolf"]: e.append("祈祷应只让 wolf 重生，得到 %s" % [pr])
	o.step(R)
	o.step(R)
	if o.map_id != "wild" or not enemy_ids(o).has("wolf") or enemy_ids(o).has("king"): e.append("回野外后 wolf 在、king 不在，得到 %s" % [enemy_ids(o)])
	check("shrine_respawn", e)
