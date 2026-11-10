class_name PlaytestCh2
extends RefCounted
## --playtest 的第 2 章（第 15 步第二批）：照 design/levels/ch2.md 从皮匠楼走到庆功宴。
## 和玩家一样一格一格走、按确认、点战斗按钮；走路、打仗、截图、核对都借 main.gd 里的测试函数。
##   2-1 伦敦：墓地 → 比武场 → 皮匠楼门口（锁着）→ 墓地（亚瑟拔剑）→ 比武场 → 教堂（应验）→ 加冕，<<teleport>> 挪到大主教的厅门口
##   2-2 北门外大路：a 三群都打、开翻倒的货车；b 一群不碰；c 在路边石十字祈祷、打山坡上的骑兵（群攻）
##   2-3 贝德格兰：营地入口演开场；a 打游骑、开斥候的包袱；在木十字祈祷；走到旗前开打（先说话再 fight_npcs）
##   2-4 回伦敦：木十字传到桥头小礼拜堂，找店主买东西，走到大主教的厅门口，庆功宴看酒杯、选 D2，第 2 章结束

var m   # main.gd

func _init(main) -> void:
	m = main

func run(want: String) -> void:
	var w: World = m.world
	var route: String = m.route
	var want2: String = {"a": "D2a", "b": "D2b", "c": "D2c"}.get(route, "D2a")

	# ---------------- 2-1 伦敦 ----------------
	m._expect(w.area == "london" and w.W == 32 and w.H == 20, "第 2 章的伦敦是 32×20 的新图（%s %d×%d）" % [w.area, w.W, w.H])
	m._expect(w.player_cell == Vector2i(26, 15), "第 2 章从皮匠楼上开始（%s）" % w.player_cell)
	m._expect(w.exit_at(Vector2i(16, 0)) == null and w.blocked(Vector2i(16, 0)), "1201 时北门关着（出口带 cond，1204 才开）")
	m._expect(w.markers() == [Vector2i(7, 11)], "1201 的任务标记只标墓地门 (7, 11)，照 quests.json 的 target（%s）" % str(w.markers()))
	m._expect(m._npc_cell("shop_london") == Vector2i(18, 18) and w.npc_at(Vector2i(18, 18)) != null, "桥头铺子的店主站在 (18, 18)")
	await m._shot("map_london_ch2")
	if route == "a":
		await m._walk_onto(Vector2i(16, 3))
		await m._shot("map_london_gate_closed")

	# 墓地看剑 → 比武场凯忘了剑 → 跑回住处（锁着门）→ 墓地（亚瑟拔剑）→ 送回比武场 → 1203；一步里人换地方时「下一步」换成小目标
	for leg in [[Vector2i(7, 11), "Ch2_Churchyard", "quest_1002_p1202"], [Vector2i(11, 16), "Ch2_Tournament", "quest_1002_p1202b"],
			[Vector2i(26, 12), "Ch2_LockedDoor", "quest_1002_p1202c"], [Vector2i(7, 11), "Ch2_SwordPulled", "quest_1002_p1202d"],
			[Vector2i(11, 16), "Ch2_SwordToKay", "quest_1002_p1203"]]:
		await m._walk_onto(leg[0])
		await m._until(func(): return m.runner.visited(leg[1]) and not m.runner.running, 30.0)
		m._expect(Quests.objective("1002") == m.tr(leg[2]), "演完 %s，下一步换成「%s」（现在：%s）" % [leg[1], m.tr(leg[2]), Quests.objective("1002")])
		if leg[1] == "Ch2_LockedDoor":
			m._expect(w.markers().has(Vector2i(7, 11)) and not w.markers().has(Vector2i(11, 16)), "换了小目标以后标记跟着触发格走：标墓地门，不再标 target（%s）" % str(w.markers()))
	m._expect(m.runner.quest_part(1002) == 1203, "剑送到凯手里，任务到 1203 跟埃克托回教堂")

	# 教堂：第 1 章那句话应验，接着加冕；加冕末尾 <<teleport london 25 10>> 把人挪到大主教的厅门口
	var church_before: int = GS.book_page("D1").get("after", []).size()
	await m._walk_onto(Vector2i(7, 5))
	await m._until(func(): return m.runner.visited("Ch2_Coronation") and not m.runner.running and m.mode == "map", 60.0)
	await m._shot("toast_after")
	var after_key := "after_" + want
	m._expect(church_before == 0 and after_key in GS.book_page("D1").after, "教堂那一幕以后预言簿 D1 多了一行「后来」（%s）" % after_key)
	m._expect(w.area == "london" and w.player_cell == Vector2i(25, 10) and GS.S.cell == [25, 10],
		"加冕演完，<<teleport>> 把人挪到大主教的厅门口 (25, 10)（%s %s）" % [w.area, w.player_cell])
	m._expect(m.runner.quest_part(1002) == 1204 and Quests.objective("1002") == m.tr("quest_1002_p1204"), "任务到 1204：%s" % Quests.objective("1002"))
	m._expect(w.exit_at(Vector2i(16, 0)) != null, "1204 起北门开了")
	m._expect(w.markers() == [Vector2i(16, 0)], "1204 在伦敦标北门（%s）" % str(w.markers()))
	await m._shot("map_london_1204_gate_open")
	m.open_book()
	await m._until(func(): return m.screens.kind != "book")
	m._expect("book" in m._seen_screens, "地图上按 Esc 打开预言簿，看得到这一页和「后来」")
	if route == "a":
		await m._talk_npc("merlin_stone")
		m._expect(m.runner.visited("Ch2_Merlin"), "a：去墓地找梅林，他坐在那块石头边上（Ch2_Merlin）")
		await m._talk_npc("kay_gate")
		m._expect(m.runner.visited("Ch2_Kay"), "a：北门边找凯说话（Ch2_Kay）")

	# ---------------- 2-2 北门外大路 ----------------
	var fights0: int = GS.S.metrics.fights.size()
	await m._walk_area("london_north")
	m._expect(w.area == "london_north" and w.player_cell == Vector2i(16, 16), "出北门进北门外大路，落在 (16, 16)")
	m._expect(w.roamers.size() == 3, "北门外大路三群能绕开的小仗都在（%d 群）" % w.roamers.size())
	for r in w.roamers: print("  [地图] %s：%s，在 %s 一带转" % [r.id, World.group_label(r.enc), r.rect])
	m._expect(w.shrine_at(Vector2i(18, 16)) != null and w.chest_at(Vector2i(28, 14)) != null, "路边石十字 (18, 16)、翻倒的货车 (28, 14) 都在")
	m._expect(w.markers() == [Vector2i(24, 0)], "北门外大路标往贝德格兰的出口 (24, 0)（%s）" % str(w.markers()))
	await m._shot("map_london_north")
	if route == "c":
		m._shrine_plan = ["leave"]
		await m._pray_at("london_north_cross")
		m._expect(GS.S.last_shrine == "london_north_cross", "c：路边石十字祈祷，记成上次祈祷的地方")
	if route == "a":
		for zid in ["ch2_north_gate", "ch2_ford"]:
			await _fight_zone(zid)
		await m._walk_next_to(Vector2i(28, 14))
		var bag0: int = GS.S.bag.size()
		await m._press("confirm")
		await m._until(func(): return "london_north_cart" in GS.S.opened, 5.0)
		m._expect(GS.S.bag.size() == bag0 + 1, "开翻倒的货车：背包多了一件（%s）" % (Party.item_info(GS.S.bag[-1]).name if not GS.S.bag.is_empty() else ""))
	if route in ["a", "c"]:
		await _fight_zone("ch2_hill")
	if route == "b":
		m._expect(GS.S.metrics.fights.size() == fights0, "b：沿大路走，三群小仗都绕开了")

	# ---------------- 2-3 贝德格兰 ----------------
	await m._walk_area("bedegraine")
	m._expect(w.area == "bedegraine" and w.player_cell == Vector2i(8, 18), "进贝德格兰森林，落在南边入口 (8, 18)")
	m._expect(w.markers() == [Vector2i(22, 5)], "1204 在贝德格兰标旗前 (22, 5)（%s）" % str(w.markers()))
	await m._walk_onto(Vector2i(8, 17))
	await m._until(func(): return m.runner.visited("Ch2_BedegraineCamp") and not m.runner.running, 30.0)
	m._expect(m.runner.visited("Ch2_BedegraineCamp"), "往里走一格，营地开场演了（Ch2_BedegraineCamp）")
	m._expect(m._npc_cell("kay_camp") != Vector2i(-1, -1) and w.npc_at(m._npc_cell("kay_camp")) != null, "开场以后凯和亚瑟站在营地里")
	await m._shot("map_bedegraine")
	if route == "a":
		await _fight_zone("ch2_camp")
		await m._walk_next_to(Vector2i(1, 3))
		await m._press("confirm")
		await m._until(func(): return "bedegraine_scout_pack" in GS.S.opened, 5.0)
		m._expect("bedegraine_scout_pack" in GS.S.opened, "开斥候丢下的包袱")
	m._shrine_plan = ["leave"]
	await m._pray_at("bedegraine_camp")
	m._expect(GS.S.last_shrine == "bedegraine_camp" and Party.all_full(), "营地后头的木十字祈祷：三人回满，记成上次祈祷的地方")
	var travel: Array = m.travel_targets(m.shrine_def("bedegraine_camp")).map(func(o): return o.id)
	m._expect("london_bridge" in travel, "木十字的传送菜单里有桥头小礼拜堂（本章第一座，%s）" % str(travel))

	await m._walk_onto(Vector2i(22, 9))
	await m._shot("map_bedegraine_flag_marker")
	# 旗前三格：先说三句话，再 <<fight_npcs bedegraine>>
	await m._walk_onto(Vector2i(22, 5))
	await m._until(func(): return m.mode == "battle", 30.0)
	m._expect(m.battle_view.b != null and m.battle_view.b.enc_id == "bedegraine", "走到旗前开打：贝德格兰之战（剧情战，先说话再开打）")
	await _story_fight()
	await m._until(func(): return m.mode == "map" and not m.runner.running and not m.screens.is_open(), 60.0)
	m._expect(m.runner.visited("Ch2_Bedegraine") and m.runner.quest_part(1002) == 1205, "打赢贝德格兰，任务到 1205：%s" % Quests.objective("1002"))
	m._expect(w.markers() == [Vector2i(24, 13)], "1205 在贝德格兰标木十字 (24, 13)，提示传回伦敦（%s）" % str(w.markers()))
	await m._walk_onto(Vector2i(22, 10))
	await m._shot("map_bedegraine_1205_shrine_marker")

	# ---------------- 2-4 回伦敦 ----------------
	m._shrine_plan = ["travel:london_bridge"]
	await m._pray_at("bedegraine_camp")
	await m._until(func(): return w.area == "london", 10.0)
	m._expect(w.area == "london" and GS.S.last_shrine == "london_bridge", "从木十字传到桥头小礼拜堂（%s，上次祈祷 %s）" % [w.area, GS.S.last_shrine])
	m._expect(w.markers() == [Vector2i(25, 9)], "1205 在伦敦标大主教的厅门口 (25, 9)（%s）" % str(w.markers()))
	await m._shot("map_london_bridge")
	# 商店：面对店主按确认，Shop_london 里 <<open_shop london>>
	var prev: Callable = m.screens.auto_hook
	var shop := {"seen": false, "spent": 0, "bought": []}
	m.screens.auto_hook = func(kind: String) -> void:
		if kind == "shop": _on_shop(shop)
		else: prev.call(kind)
	var silver0 := int(GS.S.silver)
	var hp0 := int(GS.S.potions.get("potion_hp", 0))
	await m._walk_next_to(Vector2i(18, 18))
	await m._press("confirm")
	await m._until(func(): return m.runner.visited("Shop_london") and m.mode == "map" and not m.runner.running and not m.screens.is_open(), 30.0)
	m.screens.auto_hook = prev
	m._expect(shop.seen, "找店主说话打开了伦敦桥头的铺子")
	m._expect(int(GS.S.silver) == silver0 - int(shop.spent), "买东西扣的钱对得上：%d → %d（花 %d）" % [silver0, int(GS.S.silver), int(shop.spent)])
	if route != "c":
		m._expect("potion_hp" in shop.bought and int(GS.S.potions.get("potion_hp", 0)) == hp0 + 1, "买了一瓶血药（%d → %d）" % [hp0, int(GS.S.potions.get("potion_hp", 0))])

	# 大主教的厅门口：庆功宴，酒杯里看见 D2，第 2 章结束
	await m._walk_onto(Vector2i(25, 9))
	await m._until(func(): return m.runner.visited("Ch2_Feast") and not m.runner.running, 60.0)
	m._expect(str(m.runner.v("D2")) == want2 and not GS.book_page("D2").is_empty(), "庆功宴选 %s，预言簿有 D2 这一页（%s）" % [want2, str(m.runner.v("D2"))])
	m._expect(Quests.state("1002") == "done" and int(m.runner.v("chapter")) == 3, "第 2 章主线完成，进第 3 章")
	await m._until(func(): return m.screens.kind == "end", 40.0)
	for l in m.screens.data.get("metrics", []): print("  [试玩记录] ", l)
	print("  [第 2 章] 学徒 %d 级，经验 %d，银币 %d，打过 %d 群地图小仗" % [Party.level(), int(GS.S.xp_total), int(GS.S.silver),
		GS.S.metrics.fights.filter(func(f): return f.kind == "map").size()])
	m.verify("outcome", m.screens.kind == "end" and after_key in GS.book_page("D1").after and Quests.state("1002") == "done"
		and str(m.runner.v("D2")) == want2,
		"第 2 章按 %s / %s 走到底：教堂应验写上「%s」，贝德格兰打赢，传回桥头，庆功宴选 %s，1002 完成，出现白盒结尾" % [want, want2, UIKit.t(after_key), want2])

## 追一群能绕开的敌人，打赢，等升级、加点的画面都关上
func _fight_zone(zid: String) -> void:
	await m._hunt(zid)
	await m._until(func(): return m.mode == "battle")
	await m._auto_fight()
	await m._win_continue()
	await m._until(func(): return m.mode == "map" and not m.screens.is_open(), 30.0)
	m._expect(m.world.roamer(zid) == null and zid in GS.S.defeated, "%s 打赢，从地图上没了" % zid)

## 贝德格兰之战：照 ch2.md 第 5 节的解法打（先拆冲锋，再守人：要倒的人举盾、学徒给他护身，挡的那回合不打盾兵）；
## 输了点「再来一次」，最多三回
func _story_fight() -> void:
	for attempt in 3:
		var b = m.battle_view.b
		var texts: Array = b.intents.map(func(it): return b.intent_text(it))
		print("  [贝德格兰] 第 %d 次，第 1 回合意图：%s" % [attempt + 1, ", ".join(PackedStringArray(texts))])
		await _search_fight(b.ctx.duplicate(true))
		print("  [贝德格兰] %s，第 %d 回合；%s" % [b.result, b.turn, ", ".join(PackedStringArray(b.allies(false).map(func(u): return "%s %d/%d" % [u.name, u.hp, u.max])))])
		if b.result == "win":
			m._expect(true, "贝德格兰之战第 %d 次打赢（第 %d 回合）" % [attempt + 1, b.turn])
			await m._win_continue()
			return
		await m._until(func(): return not m.battle_view.end_btns.is_empty(), 10.0)
		m.battle_view.end_btns[0].pressed.emit()
		await m.get_tree().process_frame
	m._expect(false, "贝德格兰之战三次都没打赢")

## 最优打法（和 tools/sim_numbers.py 的 smart_plan 同一个思路）：战斗是确定的，每回合把三个人能排的组合
## 在一份新开的同一场仗里试一遍（先照前几回合的排法重放，再排这一组，往后按 _greedy 打完），挑打完剩血最多的那组，
## 再在真正的战斗画面里照它点按钮。不改战斗规则，只替玩家多想几步。
func _search_fight(ctx: Dictionary, max_turns := 14) -> void:
	var b = m.battle_view.b
	var history: Array = []
	while b.result == "" and history.size() < max_turns:
		var turn0: int = b.turn
		var best: Array = []
		var best_score := -INF
		for plan in _combos(_fresh(b, ctx, history)):
			var s = _fresh(b, ctx, history)
			if not _apply(s, plan): continue
			for i in max_turns:
				if s.result != "": break
				_greedy(s)
			var sc := _score(s)
			if sc > best_score:
				best_score = sc
				best = plan
		if best.is_empty():
			m._expect(false, "第 %d 回合一组能排的都没有" % turn0)
			return
		history.append(best)
		for p in best:
			if b.result != "" or b.turn != turn0: break
			m._plan(p[0], p[1], p[2])
		if b.result == "" and b.turn == turn0:
			m.battle_view._on_end_turn()
		var s = _fresh(b, ctx, history)
		var hp_of := func(x): return x.allies(false).map(func(u): return u.hp) + x.enemies(false).map(func(u): return u.hp)
		if hp_of.call(s) != hp_of.call(b): print("  [贝德格兰] 试算和实战对不上：%s / %s" % [hp_of.call(s), hp_of.call(b)])
	m._expect(b.result != "", "贝德格兰之战 %d 回合内分出胜负" % max_turns)

## 新开一份同样的仗，照 history 把前几回合重放一遍
func _fresh(b, ctx: Dictionary, history: Array):
	var s := Battle.new()
	s.setup(b.enc_id, ctx.duplicate(true), int(m.runner.v("chapter")), GS.S.vars.duplicate(true))
	for plan in history: _apply(s, plan)
	return s

func _apply(s, plan: Array) -> bool:
	for p in plan:
		if not s.plan(p[0], p[1], p[2]): return false
	s.end_turn()
	s.take_log()
	return true

## 这回合三个人能排的所有组合（不喝药）
func _combos(s) -> Array:
	var per := []
	for u in s.allies():
		var opts := []
		for act in s.actions_for(u.uid):
			if act.begins_with("potion") or s.why_not(u.uid, act) != "": continue
			var tk: String = s.target_kind(act)
			if tk == "": opts.append([u.uid, act, ""])
			elif tk in ["enemy", "ally"]:
				for t in s.valid_targets(act): opts.append([u.uid, act, t])
		per.append(opts)
	var out := [[]]
	for opts in per:
		var nxt := []
		for base in out:
			for o in opts: nxt.append(base + [o])
		out = nxt
	return out

## 打完以后的分：赢了按剩血算，输了按敌人还剩多少血扣
func _score(s) -> float:
	var mine := 0
	for u in s.allies(false): mine += maxi(0, u.hp)
	var theirs := 0
	for e in s.enemies(): theirs += e.hp
	return (1000.0 + mine * 10 - s.turn) if s.result == "win" else (-theirs * 10.0 + mine)

## 往后几回合的打法：打断蓄力、要倒的人举盾或护身，其余人打同一个不举盾的敌人
func _greedy(s) -> void:
	var tgt := _flag_target(s)
	var inc := {}
	for u in s.allies():
		var n := 0
		for it in s.intents:
			if not it.cancelled and it.act == "attack" and (it.target == u.uid or it.target == "all"): n += s.intent_damage(it, u.uid) * int(it.hits)
		inc[u.uid] = n
	for u in s.allies():
		if u.uid == "apprentice":
			var cut: Array = s.interruptible()
			var weak := ""
			for a in s.allies():
				if a.uid != "apprentice" and int(inc.get(a.uid, 0)) >= a.hp + int(a.block): weak = a.uid
			if not cut.is_empty() and s.plan("apprentice", "interrupt", cut[0]): pass
			elif weak != "" and s.plan("apprentice", "ward", weak): pass
			elif tgt != "" and s.plan("apprentice", "spark", tgt): pass
			else: s.plan("apprentice", "focus")
		elif int(inc.get(u.uid, 0)) >= u.hp + int(u.block):
			s.plan(u.uid, "guard")
		elif tgt != "":
			s.plan(u.uid, "attack", tgt)
	s.end_turn()
	s.take_log()

## 一回合一回合排：学徒先打断蓄力，有人这回合要倒就护他，否则星火；凯和亚瑟这回合要倒就举盾，否则打同一个目标
## （没倒的骑兵 → 血最少、这回合不举盾的步兵 → 盾兵）
func _hold_the_flag(max_turns := 14) -> void:
	var b = m.battle_view.b
	var n := 0
	while b.result == "" and n < max_turns:
		n += 1
		var turn0: int = b.turn
		var incoming := {}
		for u in b.allies():
			var inc := 0
			for it in b.intents:
				if not it.cancelled and it.act == "attack" and (it.target == u.uid or it.target == "all"): inc += b.intent_damage(it, u.uid) * int(it.hits)
			incoming[u.uid] = inc
		var tgt := _flag_target(b)
		var warded := ""
		for u in b.allies():
			if b.result != "" or b.turn != turn0: break
			if b.planned(u.uid) != null: continue
			var danger: bool = int(incoming.get(u.uid, 0)) >= u.hp + int(u.block)
			if u.uid == "apprentice":
				var cut: Array = b.interruptible()
				var weak := ""
				for a in b.allies():
					if a.uid != "apprentice" and int(incoming.get(a.uid, 0)) >= a.hp + int(a.block) - 4 and (weak == "" or a.hp < b.unit(weak).hp): weak = a.uid
				if b.has_spell("interrupt") and not cut.is_empty() and b.why_not("apprentice", "interrupt") == "":
					m._plan("apprentice", "interrupt", cut[0])
				elif weak != "" and b.has_spell("ward") and b.why_not("apprentice", "ward") == "":
					warded = weak
					m._plan("apprentice", "ward", weak)
				elif b.why_not("apprentice", "spark") == "" and tgt != "":
					m._plan("apprentice", "spark", tgt)
				else:
					m._plan("apprentice", "focus")
			elif danger and warded != u.uid and b.why_not(u.uid, "guard") == "":
				m._plan(u.uid, "guard")
			else:
				var e = b.unit(tgt)
				m._plan(u.uid, "attack", tgt if e != null and e.alive else b.enemies()[0].uid)
		if b.result == "" and b.turn == turn0:
			m.battle_view._on_end_turn()
	m._expect(b.result != "", "贝德格兰之战 %d 回合内分出胜负" % max_turns)

func _flag_target(b) -> String:
	var blocking := {}
	var best = null
	for it in b.intents:
		if it.cancelled: continue
		if it.act in ["block", "guard"]: blocking[it.uid] = true
		var e = b.unit(it.uid)
		if e != null and e.alive and it.act in ["charge", "summon", "buff"]: return e.uid
	for e in b.enemies():
		if blocking.has(e.uid): continue
		if best == null or e.hp < best.hp: best = e
	if best == null and not b.enemies().is_empty(): best = b.enemies()[0]
	return best.uid if best != null else ""

## 商店画面：a 买一瓶血药，再买一件买得起的装备；b 只买一瓶血药；c 看一眼就走
func _on_shop(rec: Dictionary) -> void:
	rec.seen = true
	await m._shot("screen_shop")
	var id: String = m.screens.data.get("shop", "")
	var items: Array = ShopLogic.stock(id)
	print("  [商店] %s：%s；兜里 %d 银" % [id, "、".join(PackedStringArray(items.map(func(e): return "%s %d" % [e.name, int(e.price)]))), int(GS.S.silver)])
	var want := [] if m.route == "c" else ["potion_hp"]
	if m.route == "a": want.append("gear")
	for k in want:
		for e in ShopLogic.stock(id):
			if (e.id == k or (k == "gear" and e.kind == "gear")) and ShopLogic.why_not(e) == "":
				var res: Dictionary = ShopLogic.buy(id, e)
				if res.ok:
					rec.spent = int(rec.spent) + int(res.price)
					rec.bought.append(e.id if e.kind == "potion" else "gear")
					print("  [商店] " + UIKit.f("shop_bought", {"t": res.name, "n": res.price}))
				break
	m.screens._rebuild()
	await m._shot("screen_shop_after")
	m.screens._choose("leave")
