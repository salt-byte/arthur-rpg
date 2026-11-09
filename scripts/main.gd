extends Node2D
## 入口。白盒切片：色块地图 + 占位人物，把第 1 章（狼群、石圈看水面、阁楼学打断、梅林的影子、马厩的关键选择）
## 接到第 2 章教堂那一幕应验。剧情全在 content/dialogue/*.yarn，这里只实现指令、把地图 / 对话 / 战斗 / 整屏画面串起来。
## 第 10 步重做（照新的玩法参考）：森林里四群会走动的敌人、圣龛、宝物；打赢拿经验和掉落，升级挑奖励、加点，背包换装；
## 逃跑或输了回上次祈祷的圣龛。成长和背包在 party.gd，地图在 world.gd，战斗规则在 battle.gd。
##
## 测试：godot --path . -- --playtest [--route=a|b|c]（verify.py 用 xvfb 跑，SHOT_DIR 给了就截图）
##   清存档新开一局，用和玩家一样的走格子、按确认、点战斗按钮，走完白盒全程；
##   打印每句台词、每个指令、每回合敌人意图，按设计页验收条件核对，六项证据打 [verify] 行。

var runner: YarnRunner
var world: World
var hud: Hud
var dbox: DialogBox
var battle_view: BattleView
var screens: Screens
var mode := "title"          # title / map / dialog / battle / screen
var playtest := false
var route := "a"
var fails := []
var shot_dir := ""
var _battle_ctx := {}
var _end_shown := false

const RESTART_MARK := "user://verify_restart.json"

func _ready() -> void:
	_setup_input()
	var args := OS.get_cmdline_user_args()
	playtest = "--playtest" in args
	for a in args:
		if a.begins_with("--route="): route = a.substr(8)
	TranslationServer.set_locale("zh")

	world = World.new()
	world.main = self
	add_child(world)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.make_theme()
	layer.add_child(root)
	hud = Hud.new()
	hud.main = self
	root.add_child(hud)
	dbox = DialogBox.new()
	dbox.main = self
	root.add_child(dbox)
	battle_view = BattleView.new()
	root.add_child(battle_view)
	screens = Screens.new()
	screens.main = self
	root.add_child(screens)

	runner = YarnRunner.new()
	add_child(runner)
	runner.handler = self
	runner.ui = self
	runner.load_content("res://content/dialogue")
	Quests.runner = runner
	runner.finished.connect(_on_dialog_finished)
	world.want_dialog.connect(start_dialog)
	world.want_battle.connect(_on_spawn_battle)
	world.want_bark.connect(_on_bark)
	world.want_pray.connect(_on_pray)
	world.want_chest.connect(_on_chest)
	battle_view.reward_fn = _battle_rewards
	world.area_changed.connect(_on_area)
	Quests.changed.connect(_refresh_next)
	battle_view.finished.connect(_on_battle_finished)

	runner.init_vars()
	print("[boot] ok tables=%d nodes=%d vars=%d quests=%d data_errors=%d" % [
		Data.tables.size(), runner.prog.nodes.size(), runner.prog.declares.size(), Quests.table.size(), Data.errors.size()])
	for e in Data.errors: print("[boot] ", e)

	if FileAccess.file_exists(RESTART_MARK):
		await _restart_check()
		return
	if "--sim" in args:
		_sim()
		return
	if "--story" in args:
		await _story()
		return
	if "--battle-demo" in args:
		await _battle_demo()
		return
	if playtest:
		dbox.auto = true
		battle_view.auto = true
		screens.auto = true
		await _playtest()
		return
	show_title()

func _setup_input() -> void:
	var keys := {"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S], "move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D], "confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z],
		"cancel": [KEY_ESCAPE, KEY_X, KEY_TAB, KEY_M]}
	for a in keys:
		if InputMap.has_action(a): continue
		InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

# ---------------- 开局、读档、重新开始 ----------------
func show_title() -> void:
	mode = "title"
	screens.open("title", {"can_continue": GS.has_save()}, _on_title)

func _on_title() -> void:
	var c: String = screens.data.get("choice", "new")
	if c == "continue": load_game()
	else: new_game()

func new_game() -> void:
	GS.new_game()
	Party.new_game()
	if not playtest: GS.S.seed = randi()   # 每局的掉落、奖励不一样；测试用固定种子，结果可重复
	GS.S.metrics = {"t0": Time.get_ticks_msec(), "fights": [], "levelup_ms": [], "tree_ms": [], "bag_ms": [], "equip": 0}
	runner.init_vars()
	_end_shown = false
	var cs := chapter_start(1)
	_first_shrine(1)
	world.load_area(cs.area, Vector2i(int(cs.cell[0]), int(cs.cell[1])))
	mode = "map"
	_refresh_next()
	start_dialog(cs.node)

## 每章开始时这一章第一座圣龛自动记成「上次祈祷的地方」（overworld.json first_shrine_auto）：还没祈祷过就逃跑时也有地方回
func _first_shrine(ch: int) -> void:
	for sh in Data.t("overworld").get("shrines", []):
		if sh.get("first_of_chapter", false) and _area_chapter(sh.area) == ch:
			GS.S.last_shrine = sh.id
			return

func _area_chapter(a: String) -> int:
	for x in Data.t("overworld").get("areas", []):
		if x.id == a: return int(x.chapter)
	return 0

func shrine_def(id: String) -> Dictionary:
	for sh in Data.t("overworld").get("shrines", []):
		if sh.id == id: return sh
	return {}

func load_game() -> void:
	if not GS.load_save():
		new_game()
		return
	if not GS.S.has("defeated"): GS.S["defeated"] = []
	Party.restore()
	runner.init_vars()
	var c: Array = GS.S.cell if GS.S.cell != null else chapter_start(int(runner.v("chapter"))).cell
	world.load_area(GS.S.area, Vector2i(int(c[0]), int(c[1])))
	mode = "map"
	_refresh_next()
	_after_dialog_checks()

func restart() -> void:
	var d := DirAccess.open("user://")
	if d and d.file_exists("save.json"): d.remove("save.json")
	GS.new_game()   # GS 是全局单例，场景重载不会清它
	get_tree().reload_current_scene()

func chapter_start(n: int) -> Dictionary:
	return Data.t("maps").get("chapter_start", {}).get(str(n), {})

func save_game() -> void:
	Party.store()
	if GS.save():
		hud.flash_saved()
		print("  [存档] 第 %s 章 %s %s" % [str(runner.v("chapter")), GS.S.area, str(GS.S.cell)])

# ---------------- 给 World 和界面用的 ----------------
func can_move() -> bool:
	return mode == "map" and not runner.running and not screens.is_open()

func cond(expr: String) -> bool:
	if expr == "": return true
	return YarnRunner._truthy(runner.eval(expr))

func color_for(who: String) -> Color:
	for a in Data.t("maps").get("actors", {}).values():
		if a.get("name", "") == who and who != "": return UIKit.hexcol(a.color)
	return Color("#4A4F66")

func open_book() -> void:
	if mode != "map" or screens.is_open(): return
	mode = "screen"
	screens.open("book", {}, func(): mode = "map")

func open_bag() -> void:
	if mode != "map" or screens.is_open(): return
	mode = "screen"
	GS.S.metrics["bag_opens"] = int(GS.S.metrics.get("bag_opens", 0)) + 1
	screens.open("bag", {}, func():
		GS.S.metrics.bag_ms.append(Time.get_ticks_msec() - int(screens.data.get("t0", Time.get_ticks_msec())))
		GS.S.metrics.equip = int(GS.S.metrics.get("equip", 0)) + int(screens.data.get("equipped", 0))
		mode = "map")

func open_tree(respec := false, after := Callable()) -> void:
	if screens.is_open(): return
	mode = "screen"
	screens.open("tree", {"respec": respec}, func():
		GS.S.metrics.tree_ms.append(Time.get_ticks_msec() - int(screens.data.get("t0", Time.get_ticks_msec())))
		mode = "map"
		Party.store()
		if after.is_valid(): after.call())

func _refresh_next() -> void:
	for q in Quests.active():
		if Quests.is_main(q):
			hud.set_next(UIKit.f("ui_next", {"t": Quests.objective(q)}))
			world.queue_redraw()
			return
	hud.set_next("")

func _on_area(id: String) -> void:
	hud.flash_area(UIKit.t(Data.t("maps").areas[id].name))
	_refresh_next()
	print("  [地方] ", id, " ", world.player_cell)

func _on_bark(text: String, at: Vector2) -> void:
	hud.show_bark(text, world.get_canvas_transform() * at)
	print("  [冒话] ", text)

func _unhandled_input(e: InputEvent) -> void:
	if screens.is_open():
		screens.handle(e)
		return
	match mode:
		"battle": battle_view.handle(e)
		"dialog":
			if dbox.visible: dbox.handle(e)
		"map":
			if e is InputEventMouseMotion:
				world.hover_cell = world.cell_at_screen(e.position)
			elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				hud.show_controls = false
				world.click_cell(world.cell_at_screen(e.position))
			elif e.is_action_pressed("confirm"):
				hud.show_controls = false
				world.interact()
			elif e.is_action_pressed("cancel"):
				open_book()
			elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_B:
				open_bag()
			elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_K:
				open_tree()

# ---------------- 对话 ----------------
func start_dialog(node: String) -> void:
	if runner.running or node == "": return
	mode = "dialog"
	print("[node] ", node)
	runner.start(node)

## YarnRunner 的界面接口
func dialog(entries: Array, cb := Callable()) -> void:
	if story_mode:
		_story_dialog(entries, cb)
		return
	mode = "dialog"
	dbox.show_entries(entries, cb)

func look_for(_who: String) -> String: return ""

func _on_dialog_finished() -> void:
	if story_mode: return
	dbox.close()
	if mode in ["dialog", "battle"]: mode = "map"
	_after_dialog_checks.call_deferred()

## 一段对话演完以后：换章就换地方、开这一章的开场；教堂那一幕演完就是白盒的结尾
func _after_dialog_checks() -> void:
	if runner.running: return
	if GS.S.area != world.area:
		var c: Array = GS.S.cell
		world.load_area(GS.S.area, Vector2i(int(c[0]), int(c[1])))
	var cs := chapter_start(int(runner.v("chapter")))
	if not cs.is_empty() and not runner.visited(cs.node):
		start_dialog(cs.node)
		return
	_refresh_next()
	if not GS.S.get("pending_levels", []).is_empty() and mode == "map":
		_levelups()
		return
	if runner.visited("Ch2_Church") and not _end_shown:
		_end_shown = true
		await get_tree().create_timer(2.5, true, false, true).timeout
		while screens.is_open() or runner.running:
			await get_tree().create_timer(0.5, true, false, true).timeout
		mode = "screen"
		screens.open("end", {"metrics": metrics_lines()}, _on_end)

func _on_end() -> void:
	if screens.data.get("choice", "") == "restart":
		if playtest:
			var f := FileAccess.open(RESTART_MARK, FileAccess.WRITE)
			f.store_string(JSON.stringify({"fails": fails.size(), "route": route}))
			f.close()
		restart()

## 整屏画面盖上来，等它关上再让对话往下走
func _wait_screen(kind: String, data: Dictionary, after := Callable()) -> void:
	dbox.visible = false
	mode = "screen"
	screens.open(kind, data, func():
		mode = "dialog"
		if after.is_valid(): after.call()
		# 画面可能在 yarn_command 返回之前就关了（测试里立刻关），等 runner 标上「在等」再接着走
		runner.resume.call_deferred())

# ---------------- 指令（剧情不进代码，这里只实现指令） ----------------
func yarn_command(cmd: String, args: Array) -> bool:
	print("  [指令] ", cmd, " ", " ".join(args))
	if story_mode and _story_command(cmd, args): return false
	match cmd:
		"start_quest": Quests.start(args[0])
		"progress_quest": Quests.progress(args[0], int(args[1]))
		"complete_quest": Quests.complete(args[0], args[1] if args.size() > 1 else "")
		"objective": Quests.set_sub(args[0], args[1])
		"close_side":
			# 章末关门（quests.md「关门」）：接了没做完的支线先弹一次提醒，选「先不走」这段对话就停在这里；
			# 往前走，没做完的（包括没接的）按 quests.json 的 skip 结算
			var open := args.filter(func(id): return Quests.state(id) == "active")
			if open.is_empty() or story_mode:
				_close_sides(args)
				return false
			var names := "、".join(PackedStringArray(open.map(func(id): return "“%s”" % Quests.title(id))))
			dialog([{"who": "", "text": UIKit.f("ui_close_warn", {"t": names}), "look": "", "choices": [
				{"t": UIKit.t("ui_close_go"), "kind": "", "fn": func():
					_close_sides(args)
					runner.resume()},
				{"t": UIKit.t("ui_close_wait"), "kind": "", "fn": func(): runner.abort()}]}])
			return true
		"companion": GS.S.vars["c_" + args[0]] = args[1]
		"unlock":
			if not args[0] in GS.S.unlocks: GS.S.unlocks.append(args[0])
			var u := Data.unlock_def(args[0])
			if u.has("popup") and Data.param("story-unlocks", "show_unlock_popup", true):
				_wait_screen("unlock", {"popup": u.popup})
				return true
		"vision":
			if GS.book_page(args[0]).is_empty(): GS.S.book.append({"decision": args[0], "after": []})
			if not GS.S.metrics.has("left_at_vision"):
				GS.S.metrics["left_at_vision"] = _roamers_left(int(runner.v("chapter")))
				GS.S.metrics["vision_s"] = (Time.get_ticks_msec() - int(GS.S.metrics.get("t0", 0))) / 1000
			var vd := Data.vision(args[0])
			print("  [看水面] ", UIKit.t(vd.get("text", "")))
			_wait_screen("vision", {"surface": vd.get("surface", ""), "text": UIKit.t(vd.get("text", ""))},
				func(): hud.show_toast([UIKit.f("ui_book_new", {"t": vd.get("surface", "")})]))
			return true
		"book_after":
			var page := GS.book_page(args[0])
			if page.is_empty():
				# 没看过这一幕（支线没做、到关门时按默认结算）：预言簿没有这一页，不弹提示
				print("  [预言簿] 没有 %s 这一页，跳过" % args[0])
				return false
			if not args[1] in page.after: page.after.append(args[1])
			var ch := int(str(Data.vision(args[0]).get("seen_at", "1100")).substr(1, 1))
			hud.show_toast([UIKit.f("ui_book_toast", {"ch": ch}), UIKit.f("ui_book_after", {"t": UIKit.t(args[1])})])
			print("  [预言簿] 后来：", UIKit.t(args[1]))
		"chapter":
			var n := int(args[0])
			GS.S.vars["chapter"] = n
			_first_shrine(n)
			var cs := chapter_start(n)
			if not cs.is_empty():
				GS.S.area = cs.area
				GS.S.cell = cs.cell
			save_game()   # 进新的一章自动存档（overworld.md）
			_wait_screen("card", {"n": n})
			return true
		"autosave": save_game()
		"notify": hud.show_toast([UIKit.t(args[0])])
		"fight_npcs":
			start_battle(args[0], {"yarn": true})
			return true
		"show_ending":
			# 结局回顾那一屏第 16 步做；现在先打印，回到标题
			print("  [结局] ", args[0], " ", UIKit.t("ending_" + args[0] + "_title"))
		_:
			push_warning("没实现的指令 <<%s>>" % cmd)
	return false

func _close_sides(ids: Array) -> void:
	for id in ids:
		var r := Quests.close_side(id)
		if not r.is_empty(): print("  [关门] %s 没做完，按 %s 算" % [id, r.ending])

# ---------------- 战斗 ----------------
func _on_spawn_battle(sp: Dictionary) -> void:
	if mode != "map": return
	world._walk_id += 1   # 点地面走路的那条路作废
	if sp.get("roamer", false): world.stun_others(sp.id, int(Data.param("overworld", "flee_grace_steps", 3)))
	start_battle(sp.enemy, {"spawn": sp})

## 上场的人：剧情规定的同伴里眼下在队里的；没规定的按 party_max_companions 从队里取
func _party_for(e: Dictionary) -> Array:
	var pd: Dictionary = e.get("party", {})
	var inp: Array = Party.companions_in_party()
	var out: Array = pd.get("fixed", []).filter(func(c): return c in inp)
	var mx := int(pd.get("max", Data.param("combat", "party_max_companions", 2)))
	for c in inp:
		if out.size() >= mx: break
		if not c in out: out.append(c)
	return out.slice(0, mx)

func start_battle(enc_id: String, ctx: Dictionary) -> void:
	var e := Data.encounter(enc_id)
	var party := _party_for(e)
	var b := Battle.new()
	b.setup(enc_id, Party.battle_ctx(party, GS.S.unlocks), int(runner.v("chapter")), GS.S.vars)
	var m: Dictionary = GS.S.metrics
	var t := (Time.get_ticks_msec() - int(m.get("t0", 0))) / 1000
	m.fights.append({"enc": enc_id, "kind": e.get("kind", ""), "cause": ctx.get("spawn", {}).get("cause", "story"), "t": t})
	if not m.has("first_fight_s") and e.get("kind", "") == "map": m["first_fight_s"] = t
	_battle_ctx = ctx.duplicate()
	_battle_ctx["enc"] = enc_id
	dbox.visible = false
	mode = "battle"
	var bg := UIKit.hexcol(Data.t("maps").areas.get(world.area, {}).get("battle_bg", "#3F4A55"))
	print("[战斗] ", enc_id, " 上场：", ", ".join(PackedStringArray(b.allies().map(func(u): return u.name))))
	battle_view.open(b, bg, UIKit.t(e.get("name", enc_id)))

func _on_battle_finished(r: String) -> void:
	var ctx := _battle_ctx
	_battle_ctx = {}
	var b := battle_view.b
	if r == "win":
		Quests.on_battle_won(ctx.enc)
		if ctx.has("spawn"):
			GS.S.defeated.append(ctx.spawn.id)
			if ctx.spawn.get("roamer", false):
				world.remove_roamer(ctx.spawn.id)
				print("  [地图] %s 已移除" % UIKit.t(Data.encounter(ctx.enc).get("name", ctx.enc)))
			mode = "map"
			world.queue_redraw()
			if ctx.spawn.get("on_defeat", "") != "":
				start_dialog(ctx.spawn.on_defeat)
			else:
				_after_dialog_checks()
		else:
			mode = "dialog"
			runner.resume()
	else:
		Party.after_lose(b)
		if ctx.has("yarn"):
			runner.abort()
		mode = "map"
		if ctx.get("spawn", {}).get("roamer", false): world.reset_roamer(ctx.spawn.id)
		_return_to_shrine("flee" if r == "flee" else "lose")
	_refresh_next()

## 打赢时结算框里的几行：经验、升级、掉落、谁站起来了
func _battle_rewards(b: Battle) -> Array:
	var res: Dictionary = Party.after_win(b)
	_last_reward = res
	var xp: Dictionary = Party.xp_progress()
	var lines := []
	if res.at_cap and int(res.xp) > 0: lines.append(UIKit.t("res_xp_cap"))
	else: lines.append(UIKit.f("res_xp", {"n": int(res.xp), "lv": int(xp.level), "cur": int(xp.xp), "need": int(xp.need)}))
	if int(res.levels) > 0: lines.append(UIKit.f("res_level", {"n": int(res.level)}))
	if not res.drops.is_empty(): lines.append(UIKit.f("res_drops", {"t": Party.drops_text(res.drops)}))
	for nm in res.get("revived", []): lines.append(UIKit.f("res_revived", {"who": nm}))
	var hp := []
	for u in Party.party_uids(): hp.append("%s %d/%d" % [Party.display_name(u), Party.hp(u), Party.max_hp(u)])
	lines.append(UIKit.f("res_hp", {"t": "，".join(PackedStringArray(hp))}))
	return lines

var _last_reward := {}

## 逃跑，或者输了选「回圣龛」：回到上次祈祷过的圣龛跟前，三个人回满血；刚回来的几步里敌人不追
func _return_to_shrine(why: String) -> void:
	var sh := shrine_def(str(GS.S.get("last_shrine", "")))
	if sh.is_empty() or sh.cell == null: return
	world.load_area(sh.area, _beside_shrine(sh))
	Party.heal_all()
	world.grace = int(Data.param("overworld", "flee_grace_steps", 3))
	print("  [%s] 回到：%s，三人回满血" % ["逃跑" if why == "flee" else "输了", UIKit.t(sh.name)])
	hud.show_toast([UIKit.t(sh.name), UIKit.t("ui_back_at_shrine")])

func _beside_shrine(sh: Dictionary) -> Vector2i:
	var c := Vector2i(int(sh.cell[0]), int(sh.cell[1]))
	var A: Dictionary = Data.t("maps").areas[sh.area]
	for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		var ch: String = A.rows[n.y][n.x] if n.y >= 0 and n.y < A.rows.size() and n.x >= 0 and n.x < A.rows[0].length() else "#"
		if not Data.t("maps").tiles.get(ch, {"block": true}).get("block", false): return n
	return c

# ---------------- 圣龛、宝物 ----------------
func _on_pray(sh: Dictionary) -> void:
	if mode != "map": return
	Party.heal_all()
	if not sh.id in GS.S.shrines: GS.S.shrines.append(sh.id)
	GS.S.last_shrine = sh.id
	save_game()
	print("  [祈祷] 三人回满，记下：%s，已存档" % UIKit.t(sh.name))
	var travel := []
	for id in GS.S.shrines:
		var o := shrine_def(id)
		if id != sh.id and not o.is_empty() and _area_chapter(o.area) == int(runner.v("chapter")): travel.append(o)
	mode = "screen"
	screens.open("shrine", {"shrine": sh, "travel": travel}, func():
		mode = "map"
		var c: String = screens.data.get("choice", "leave")
		if c.begins_with("travel:"):
			var to := shrine_def(c.substr(7))
			world.load_area(to.area, _beside_shrine(to))
			GS.S.last_shrine = to.id
			print("  [传送] 传到：%s" % UIKit.t(to.name))
		elif c == "tree":
			open_tree(true))

func _on_chest(ch: Dictionary) -> void:
	if mode != "map" or ch.id in GS.S.opened: return
	var d: Dictionary = Party.roll_chest(ch.id)
	GS.S.opened.append(ch.id)
	world.queue_redraw()
	var t := Party.drops_text(d)
	print("  [宝物] %s：%s" % [UIKit.t(ch.get("name", ch.id)), t])
	hud.show_toast([UIKit.t(ch.get("name", ch.id)), UIKit.t("chest_open_" + str(ch.id)), UIKit.f("res_drops", {"t": t})])

# ---------------- 升级：每级挑一个奖励，挑完打开技能树 ----------------
func _levelups() -> void:
	if GS.S.pending_levels.is_empty() or screens.is_open(): return
	var lv := int(GS.S.pending_levels[0])
	var offers := Party.boon_offers(lv)
	mode = "screen"
	print("  [升级] %d 级，奖励：%s" % [lv, "、".join(PackedStringArray(offers.map(func(o): return o.name)))])
	screens.open("levelup", {"level": lv, "offers": offers, "points": int(Data.t("progression").progression.points_per_level)}, func():
		var o: Dictionary = screens.data.get("choice", offers[0])
		Party.pick_boon(o)
		GS.S.metrics.levelup_ms.append(int(screens.data.get("ms", 0)))
		print("  [奖励] 挑了 %s：%s" % [o.name, o.text])
		mode = "map"
		if not GS.S.pending_levels.is_empty():
			_levelups()
		elif Party.tree_points() > 0:
			open_tree(false, _after_dialog_checks)
		else:
			_after_dialog_checks())

# ---------------- 试玩记录（CONCEPT 最大风险：两次看水面之间玩家会不会自己去找仗打） ----------------
func _roamers_left(ch: int) -> int:
	var n := 0
	var zones: Dictionary = Data.t("spawns").get("zones", {})
	for z in zones:
		if _area_chapter(zones[z].get("area", "")) == ch and not z in GS.S.defeated: n += 1
	return n

func metrics_lines() -> Array:
	var m: Dictionary = GS.S.metrics
	var fights: Array = m.get("fights", [])
	var map_f := fights.filter(func(f): return f.kind == "map")
	var mine := map_f.filter(func(f): return f.cause == "player").size()
	var zones := 0
	for z in Data.t("spawns").get("zones", {}).values():
		if _area_chapter(z.get("area", "")) == 1: zones += 1
	var avg := func(a: Array) -> String:
		if a.is_empty(): return "—"
		var s := 0
		for x in a: s += int(x)
		return "%.1f" % (s / 1000.0 / a.size())
	return [
		UIKit.f("met_first", {"t": str(m.get("first_fight_s", "—"))}),
		UIKit.f("met_map", {"n": map_f.size(), "all": zones, "mine": mine, "chased": map_f.size() - mine}),
		UIKit.f("met_left", {"n": str(m.get("left_at_vision", "—"))}),
		UIKit.f("met_level", {"lv": Party.level(), "xp": int(GS.S.get("xp_total", 0))}),
		UIKit.f("met_pause", {"lv": avg.call(m.get("levelup_ms", [])), "tree": avg.call(m.get("tree_ms", [])), "bag": avg.call(m.get("bag_ms", [])), "eq": int(m.get("equip", 0))}),
	]

# =====================================================================
# 无头测试
# =====================================================================
var _key_pick := -1

## 三条路线（verify.py 跑 a；三条都要过）：
##   a 全打：森林里四群能绕开的敌人都打，开宝物、换装备、在石龛祈祷，马厩选 D1a
##   b 只打必须打的：绕开所有能绕开的敌人，头狼群照战斗设计页的例子打，马厩选 D1b
##   c 全打 + 逃跑、输了回圣龛、圣龛传送和洗点、召唤的狼不给经验，马厩选 D1c
const ROUTE_TREE := {"a": ["spark_heat", "spark_heat", "spark_heat", "spark_ember", "water_deep", "ward_sturdy"],
	"b": ["water_deep", "ward_sturdy", "trick_blind"], "c": ["ward_sturdy", "spark_heat", "trick_blind", "trick_see"]}
var _shrine_plan: Array = []
var _tree_tries := 0

func _playtest() -> void:
	print("[playtest] route=", route)
	Engine.time_scale = 6.0
	# 看门狗：卡住超过 6 分钟就判失败退出，不让 verify.py 干等
	get_tree().create_timer(360.0, true, false, true).timeout.connect(func():
		print("[playtest] FAIL 卡住了：mode=%s area=%s node=%s screen=%s" % [mode, world.area, runner.current, screens.kind])
		get_tree().quit(1))
	shot_dir = OS.get_environment("SHOT_DIR")
	var picks := {"a": 0, "b": 1, "c": 2}
	dbox.auto_pick = picks.get(route, 0)
	dbox.auto_key_hook = _on_key_choice
	screens.auto_hook = _on_screen
	var d := DirAccess.open("user://")
	if d and d.file_exists("save.json"): d.remove("save.json")
	_check_maps()
	_expect(tr("quest_1001_name") == "庄园的冬天", "文本表能按键取字（quest_1001_name）")
	_expect(tr("ch1_001") != "ch1_001", "对白表能按行号取字（ch1_001）")

	# 标题 → 新游戏
	show_title()
	await _until(func(): return screens.kind == "title")
	await _shot("title")
	screens.data["choice"] = "new"
	screens.close()
	await _until(func(): return mode == "map" and not runner.running)
	verify("launch", world.area == "manor" and Quests.is_active("1001") and not GS.has_save() and Party.level() == 1,
		"清存档后新开一局：在庄园，主线 1001 开始，学徒 1 级，没有旧存档")
	_expect(GS.S.last_shrine == "manor_chapel", "第 1 章开始时，庄园小礼拜堂自动记成上次祈祷的地方")
	await _shot("gd_verify_render")

	# 一次输入：按「下」走一格
	var before := world.player_cell
	await _hold("move_down")
	verify("input", world.player_cell != before, "按「下」以后学徒从 %s 走到 %s" % [before, world.player_cell])

	# 找凯说话：鼠标点凯，学徒自己走过去开口
	world.click_cell(_npc_cell("kay"))
	await _until(func(): return runner.running, 20.0)
	await _until(func(): return mode == "map" and not runner.running)
	_expect(runner.visited("Kay"), "鼠标点凯：学徒走到他旁边，跑了 Kay 节点")
	_expect(Party.companions_in_party() == ["kay", "arthur"], "凯和亚瑟在队里")
	if route == "c":
		_shrine_plan = ["leave", "travel:manor_chapel", "travel:forest_shrine", "tree"]
		await _pray_at("manor_chapel")
	await _shot("map_manor")

	# 进林子
	await _walk_area("forest")
	_expect(world.area == "forest", "从庄园南门走进森林")
	_expect(world.roamers.size() == 4, "森林里四群能绕开的敌人都在地图上（%d 群）" % world.roamers.size())
	for r in world.roamers: print("  [地图] %s：%s，在 %s 一带转" % [r.id, World.group_label(r.enc), r.rect])
	await _shot("map_forest")
	var hp_before_fights := Party.hp("kay")

	if route in ["a", "c"]:
		# 第一群：小路右边的蕨丛
		await _hunt("forest_east")
		await _until(func(): return mode == "battle")
		_expect(not "kay_cover" in battle_view.b.actions_for("kay"), "第 1 章凯的菜单里没有「挡在前面」（%s）" % route)
		if route == "c":
			# 逃跑：回到上次祈祷的圣龛（c 路线先在庄园小礼拜堂祈祷过）
			_expect(battle_view._flee_btn.visible, "地图上的小仗有「逃跑」按钮")
			battle_view._on_flee()
			await _until(func(): return mode == "map" and world.area == "manor")
			_expect(world.area == "manor" and Party.all_full(), "逃跑：回到庄园小礼拜堂跟前，三个人回满血")
			await _walk_area("forest")
			_expect(world.roamer("forest_east") != null, "逃跑后那群狼还在林子里")
			await _hunt("forest_east")
			await _until(func(): return mode == "battle")
		await _auto_fight()
		await _win_continue()
		_expect(Party.hp("kay") <= hp_before_fights, "血带出战斗：打完凯 %d/%d，没有回满" % [Party.hp("kay"), Party.max_hp("kay")])
		_expect(world.roamer("forest_east") == null and "forest_east" in GS.S.defeated, "打赢的那群狼从地图上没了")
		# 第二群：西边路上的强盗
		await _hunt("forest_road")
		await _until(func(): return mode == "battle")
		await _shot("battle_bandits")
		await _auto_fight()
		for l in _fight_log:
			if "撒了一把沙" in str(l) or ("凯·砍" in str(l)): print("  [强盗那一仗] ", l)
		await _win_continue()
		await _until(func(): return mode == "map" and not screens.is_open(), 30.0)
		_expect(Party.level() >= 2, "打完两群：学徒 %d 级，经验 %d" % [Party.level(), int(GS.S.xp_total)])
		# 第三群：空心老橡树边（c 路线故意让瘦狼叫狼，验召唤出来的不给经验）
		await _hunt("forest_oak")
		await _until(func(): return mode == "battle")
		var xp0 := int(GS.S.xp_total)
		_fight_log = []
		if route == "c":
			_plan("apprentice", "ward", "arthur")
			_plan("kay", "attack", "wolf")
			_plan("arthur", "attack", "wolf")
			_expect(battle_view.b.enemies().size() >= 2, "第 1 回合没打瘦狼")
		await _auto_fight()
		var summoned := _find_in(_fight_log, "叫来了 1 只")
		var spark4 := _find_in(_fight_log, "星火 → ") and _spark_hit(4)
		if route == "a": _expect(spark4, "点了两下星火加热：星火打 4 点")
		await _win_continue()
		if route == "c": _expect(not summoned or int(GS.S.xp_total) - xp0 == 4, "瘦狼叫来的狼不给经验：这一仗经验 %d（狼 2 + 瘦狼 2）" % (int(GS.S.xp_total) - xp0))
		await _until(func(): return mode == "map" and not screens.is_open(), 30.0)
		# 宝物：空心老橡树里的包袱
		var ch: Dictionary = Data.t("overworld").chests[0]
		await _walk_next_to(Vector2i(int(ch.cell[0]), int(ch.cell[1])))
		var bag0: int = GS.S.bag.size()
		await _press("confirm")
		await _until(func(): return "forest_oak" in GS.S.opened, 5.0)
		_expect(GS.S.bag.size() == bag0 + 1 and str(GS.S.bag[-1].rarity) in ["magic", "rare"], "开宝物：背包多了一件精良以上的装备（%s）" % (Party.item_info(GS.S.bag[-1]).name if not GS.S.bag.is_empty() else ""))
		# 背包：换上
		var hp_max0 := Party.max_hp("apprentice")
		var spark0 := int(Party.spells(GS.S.unlocks).spark.damage)
		var mp0 := Party.mana_max()
		open_bag()
		await _until(func(): return mode == "map" and not screens.is_open(), 10.0)
		var changed := Party.max_hp("apprentice") != hp_max0 or int(Party.spells(GS.S.unlocks).spark.damage) != spark0 or Party.mana_max() != mp0
		_expect(changed, "换上装备：血上限 %d → %d，星火 %d → %d，法力上限 %d → %d" % [hp_max0, Party.max_hp("apprentice"), spark0, int(Party.spells(GS.S.unlocks).spark.damage), mp0, Party.mana_max()])
		# 第四群：倒木后的灰狼
		await _hunt("forest_log")
		await _until(func(): return mode == "battle")
		await _auto_fight()
		await _win_continue()
		await _until(func(): return mode == "map" and not screens.is_open(), 30.0)
		_expect(world.roamers.is_empty(), "森林里能绕开的敌人打光了，安静下来")
	else:
		_expect(GS.S.defeated.is_empty(), "只打必须打的：没有碰上能绕开的敌人")

	# 林边石龛：头狼群前面的圣龛
	await _pray_at("forest_shrine")
	if route != "c":
		_expect(GS.S.last_shrine == "forest_shrine" and Party.all_full(), "林边石龛祈祷：三人回满，记成上次祈祷的地方")
	else:
		await _until(func(): return world.area == "manor", 10.0)
		_expect(world.area == "manor", "圣龛传送：从林边石龛传到庄园小礼拜堂")
		await _pray_at("manor_chapel")
		await _until(func(): return world.area == "forest", 10.0)
		_expect(world.area == "forest", "再传回林边石龛")
		await _pray_at("forest_shrine")   # 这一次在圣龛跟前打开技能树洗点

	# 头狼群：任务要打的，站着不动
	var sp := _spawn("ch1_wolves")
	await _walk_next_to(Vector2i(int(sp.cell[0]), int(sp.cell[1])))
	world.step(Vector2i(int(sp.cell[0]), int(sp.cell[1])) - world.player_cell)
	await _until(func(): return mode == "battle")
	await _fight_wolves()
	await _until(func(): return mode == "map" and not runner.running and not screens.is_open(), 40.0)
	_expect(runner.quest_part(1001) == 1102, "打完狼任务到 1102 石圈")
	_expect(_spawn_visible("ch1_wolves") == false, "打赢的狼群从地图上消失")
	_expect(not hud.tree_btn.visible or mode == "map", "技能按钮只在地图上出现，战斗里打不开技能树")

	# 石圈：发光的水面
	await _walk_area("stone_circle")
	var w: Dictionary = Data.t("overworld").water_spots[0]
	_expect(world.water_glows(w), "1102 时石圈的水面发光")
	await _shot("map_stone_circle")
	await _walk_next_to(Vector2i(int(w.cell[0]), int(w.cell[1])))
	await _press("confirm")
	await _until(func(): return mode == "map" and not runner.running and not screens.is_open())
	_expect(not GS.book_page("D1").is_empty(), "看水面以后预言簿有 D1 这一页")
	_expect(runner.quest_part(1001) == 1103, "看完水面任务到 1103 阁楼")
	_expect(not world.water_glows(w), "看完以后水面不再发光")
	var left := int(GS.S.metrics.get("left_at_vision", -1))
	_expect(left == (4 if route == "b" else 0), "试玩记录：走到石圈看水面时还剩 %d 群没打" % left)
	await _press("cancel")
	await _until(func(): return screens.kind == "" and mode == "map")

	# 回庄园，进阁楼：梅林开口、教打断、影子
	await _walk_area("manor")
	await _walk_onto(Vector2i(5, 3))
	await _until(func(): return mode == "battle")
	_expect(runner.has_unlock("u_interrupt"), "梅林教了打断（新能力提示弹过）")
	await _fight_shadow()
	await _until(func(): return mode == "map" and not runner.running and not screens.is_open(), 40.0)
	_expect(runner.quest_part(1001) == 1104, "影子那一仗以后任务到 1104 马厩")

	# 马厩：关键选择
	await _walk_onto(Vector2i(18, 5))
	await _until(func(): return world.area == "london" and mode == "map" and not runner.running and not screens.is_open(), 60.0)
	var want: String = {"a": "D1a", "b": "D1b", "c": "D1c"}.get(route, "D1a")
	_expect(runner.v("D1") == want, "关键选择记成 %s" % want)
	_expect(runner.v("kay_believes_you") == (want == "D1a"), "凯信不信你跟着选项走")
	_expect(runner.v("kay_rift") == (want == "D1b"), "兄弟有没有疙瘩跟着选项走")
	_expect(Quests.state("1001") == "done", "第 1 章主线完成")
	_expect(int(runner.v("chapter")) == 2 and runner.quest_part(1002) == 1203, "进第 2 章，任务到 1203 跟埃克托回教堂")
	var lv_want := 3 if route != "b" else 2
	_expect(Party.level() == lv_want, "第 1 章末学徒 %d 级、经验 %d（设计页：只打必须打的 12 / 2 级，全打 28 / 3 级）" % [Party.level(), int(GS.S.xp_total)])
	verify("coreLoop", Quests.state("1001") == "done" and runner.visited("Ch1_WolvesDone") and "ch1_wolves" in GS.S.defeated
		and int(GS.S.xp_total) > 0 and Party.level() >= 2 and runner.has_unlock("u_interrupt") and runner.v("D1") == want and runner.quest_part(1002) == 1203,
		"接 1001 → 打赢狼群（地图上打了 %d 群）→ 经验 %d、%d 级 → 看水面记下 D1 → 学打断、打赢影子 → 马厩选 %s → 1001 完成 → 进第 2 章 1203" % [
			GS.S.defeated.size() - 1, int(GS.S.xp_total), Party.level(), want])
	# 存档：马厩选完、进第 2 章时自动存过；存档里是第 2 章、选的是 want、站在伦敦，经验和背包都在
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GS.SAVE_PATH))
	_expect(typeof(saved) == TYPE_DICTIONARY and int(saved.vars.chapter) == 2 and saved.vars.D1 == want and saved.area == "london"
		and int(saved.prog.level) == Party.level() and saved.bag.size() == GS.S.bag.size(),
		"进第 2 章时自动存档：第 2 章、D1=%s、站在伦敦、%d 级、背包 %d 件" % [want, Party.level(), GS.S.bag.size()])
	await _shot("map_london")

	# 教堂：第 1 章那句话应验
	var church_before: int = GS.book_page("D1").get("after", []).size()
	await _walk_onto(Vector2i(9, 5))
	await _until(func(): return runner.visited("Ch2_Church") and not runner.running)
	await _shot("toast_after")
	var after_key := "after_" + want
	_expect(church_before == 0 and after_key in GS.book_page("D1").after, "教堂那一幕以后预言簿 D1 多了一行「后来」（%s）" % after_key)
	open_book()
	await _until(func(): return screens.kind != "book")
	_expect("book" in _seen_screens, "地图上按 Esc 打开预言簿，看得到这一页和「后来」")
	await _until(func(): return screens.kind == "end", 30.0)
	for l in screens.data.get("metrics", []): print("  [试玩记录] ", l)
	verify("outcome", screens.kind == "end" and after_key in GS.book_page("D1").after and runner.quest_part(1002) == 1204,
		"第 2 章教堂按 %s 演完：预言簿写上「%s」，任务到 1204，出现白盒结尾" % [want, UIKit.t(after_key)])
	print("[playtest] %s（%d 条不过）" % ["PASS" if fails.is_empty() else "FAIL", fails.size()])
	if screens.kind != "end":
		get_tree().quit(1)
		return
	# 重新开始：点结尾的「重新开始」，场景重载后由新的一轮补 [verify] restart
	screens.data["choice"] = "restart"
	screens.close()

## 截战斗画面用（不进 verify）：直接开狼群那一仗，按第 1 回合排好、结束回合，边播边截图
func _battle_demo() -> void:
	shot_dir = OS.get_environment("SHOT_DIR")
	GS.new_game()
	runner.init_vars()
	world.load_area("forest", Vector2i(19, 11))
	start_battle("wolves", {"spawn": {"id": "demo", "enemy": "wolves"}})
	await get_tree().create_timer(1.3).timeout
	await _shot("demo_0_start")
	battle_view._on_act("kay", "attack")
	await _shot("demo_1_targeting")
	battle_view._on_target("wolf_leader")
	battle_view._on_act("arthur", "attack")
	battle_view._on_target("wolf_leader")
	await _shot("demo_2_two_planned")
	battle_view._on_act("apprentice", "ward")
	battle_view._on_target("kay")
	await _shot("demo_3_all_planned")
	for i in 6:
		await get_tree().create_timer(0.55).timeout
		await _shot("demo_4_anim_%d" % i)
	await get_tree().create_timer(2.5).timeout
	await _shot("demo_5_turn2")
	get_tree().quit()

## 数值模拟（balancing，第 19 步调数值时用）：第 1 章五场仗，三种固定打法各打一遍，
## 打印回合数、输赢、倒下几个人。满血、1 级、没装备。不进 verify。
## 用法：godot --headless --path . -- --sim
func _sim() -> void:
	GS.new_game()
	Party.new_game()
	runner.init_vars()
	for enc in ["forest_wolves", "road_bandits", "oak_wolves", "log_wolves", "wolves"]:
		for strat in ["always_first", "smart", "no_magic"]:
			Party.heal_all()
			var b := Battle.new()
			b.setup(enc, Party.battle_ctx(["kay", "arthur"], ["spell_spark", "spell_ward", "spell_focus"]), 1, {})
			b.take_log()
			var guard := 0
			while b.result == "" and guard < 20:
				guard += 1
				_sim_plan(b, strat)
				b.end_turn()
				b.take_log()
			var down := b.allies(false).filter(func(u): return not u.alive).size()
			print("[sim] %s %s → %s 第 %d 回合，倒下 %d 人，剩血 %s" % [enc, strat, b.result, b.turn, down,
				", ".join(PackedStringArray(b.allies(false).map(func(u): return "%s %d/%d" % [u.name, u.hp, u.max])))])
	get_tree().quit()

## always_first：三个人永远打第一只；smart：先打要叫狼、要长嚎的，这回合挨打会倒的人举盾；no_magic：学徒只凝神
func _sim_plan(b: Battle, strat: String) -> void:
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
	for c in ["kay", "arthur"]:
		var u = b.unit(c)
		if u == null or not u.alive: continue
		if strat == "smart":
			var incoming := 0
			for it in b.intents:
				if it.act == "attack" and it.target == c: incoming += b.intent_damage(it) * int(it.hits)
			if incoming >= 4 and u.hp <= incoming + 3:
				b.plan(c, "guard")
				continue
		b.plan(c, "attack", tgt.uid)

func _restart_check() -> void:
	var m = JSON.parse_string(FileAccess.get_file_as_string(RESTART_MARK))
	DirAccess.open("user://").remove("verify_restart.json")
	show_title()
	await get_tree().process_frame
	var ok: bool = screens.kind == "title" and not GS.has_save() and not screens.data.get("can_continue", true)
	verify("restart", ok, "点「重新开始」以后存档删掉了，回到标题，没有「继续」")
	var prior := int(m.get("fails", 0)) if typeof(m) == TYPE_DICTIONARY else 1
	get_tree().quit(1 if prior > 0 or not ok else 0)

# ---------------- 测试里打仗：照战斗设计页的验收条件 ----------------
var _fight_log: Array = []

## 头狼群。b 路线照设计页「一个例子」打第 1、2 回合（基础数），其余路线按通用打法
func _fight_wolves() -> void:
	var b := battle_view.b
	_fight_log = []
	_expect(b.turn == 1 and b.intents.size() == 3, "狼群第 1 回合三只狼都亮出意图")
	if route == "b":
		_plan("apprentice", "ward", "arthur")
		_plan("kay", "attack", "wolf_leader")
		_plan("arthur", "attack", "wolf_leader")
		_expect(b.turn == 2, "三个人都排好就自动开打，进第 2 回合")
		var texts := b.intents.map(func(it): return b.intent_text(it))
		_expect("头狼 长嚎 力量 +1" in texts and "灰狼 咬 → 亚瑟 4" in texts and "瘦狼 嚎叫 叫来 1 只狼" in texts,
			"第 2 回合同时亮出「头狼 长嚎 力量 +1」「灰狼 咬 → 亚瑟 4」（排在前面的长嚎算进去）「瘦狼 嚎叫 叫来 1 只狼」（%s）" % ", ".join(PackedStringArray(texts)))
		_expect(b.unit("wolf_howler").hp == 5, "第 2 回合开始瘦狼还是满血 5 点")
		await _shot("battle_intents")
		_plan("apprentice", "spark", "wolf_howler")
		_plan("kay", "attack", "wolf_howler")
		await _shot("battle_planned")
		_plan("arthur", "guard")
		var t := "\n".join(PackedStringArray(_last_report()))
		_expect("你·星火 → 瘦狼：2 点，易伤 1" in t, "打印「星火 2，瘦狼 易伤 1」")
		_expect("凯·砍 → 瘦狼：4 点" in t and "瘦狼倒下，召唤作废" in t, "打印「凯 砍 4，瘦狼 倒下」「召唤作废」")
		_expect("灰狼 咬 → 亚瑟：1 点（挡掉 3）" in t, "头狼先长嚎，灰狼亮出来的 4 就是咬的 4：打印「亚瑟 挡掉 3，掉 1」")
	await _auto_fight()
	_expect(b.result == "win" and b.turn >= 3 and b.turn <= 6, "头狼群第 %d 回合打赢（设计页 4–5 回合）" % b.turn)
	await _shot("battle_win")
	await _win_continue()

## 影子：先不打断，第 2 回合挨重劈倒下；再来一次，意图逐字一样；打断就能赢。c 路线输了先选回圣龛，再走回阁楼打
func _fight_shadow() -> void:
	var b := battle_view.b
	_expect(b.allies().size() == 1 and not b.can_flee(), "影子那一仗只有学徒一个人，剧情战不能逃")
	var first := b.intents.map(func(it): return b.intent_text(it))
	_plan("apprentice", "spark", "merlin_shadow")
	if b.result == "" and b.turn == 2:
		_plan("apprentice", "focus")
	var t := "\n".join(PackedStringArray(_last_report()))
	_expect(b.result == "lose" and "梅林的影子 重劈 → 你：" in t, "不打断：第 2 回合学徒挨重劈、倒下")
	_expect(battle_view.end_btns.size() == 2 and battle_view.end_btns[0].text == UIKit.t("ui_retry") and battle_view.end_btns[1].text == UIKit.t("ui_back_shrine"),
		"输了出现「再来一次」和「回圣龛」")
	await _shot("battle_lose")
	if route == "c":
		battle_view.end_btns[1].pressed.emit()
		await _until(func(): return mode == "map" and not runner.running)
		_expect(world.area == str(shrine_def(GS.S.last_shrine).area) and Party.all_full(), "输了选回圣龛：回到 %s，三人回满" % UIKit.t(shrine_def(GS.S.last_shrine).get("name", "")))
		await _walk_area("manor")
		await _walk_onto(Vector2i(5, 3))
		await _until(func(): return mode == "battle")
		b = battle_view.b
	else:
		battle_view.end_btns[0].pressed.emit()
		var again := b.intents.map(func(it): return b.intent_text(it))
		_expect(first == again and b.turn == 1, "再来一次：第 1 回合的意图逐字一样（%s）" % ", ".join(PackedStringArray(again)))
	_plan("apprentice", "interrupt", "merlin_shadow")
	_expect(_find_in(_last_report(), "蓄力被打断，作废"), "第 1 回合打断：打印「蓄力……作废」")
	await _auto_fight()
	_expect(b.result == "win", "打断以后打赢影子（第 %d 回合）" % b.turn)
	await _win_continue()

## 通用打法：先管会叫狼、长嚎、蓄力的，打断够得着就打断；有人这回合会倒就护他；其余打血最少的
func _auto_fight(max_turns := 14) -> void:
	var b := battle_view.b
	var n := 0
	while b.result == "" and n < max_turns:
		n += 1
		var turn0 := b.turn
		var danger := ""
		for u in b.allies():
			var inc := 0
			for it in b.intents:
				if not it.cancelled and it.act == "attack" and (it.target == u.uid or it.target == "all"): inc += b.intent_damage(it, u.uid) * int(it.hits)
			if inc >= u.hp + int(u.block): danger = u.uid
		var tgt := _pick_target(b)
		for u in b.allies():
			if b.result != "" or b.turn != turn0: break
			if b.planned(u.uid) != null: continue
			if u.uid == "apprentice":
				var it_list := b.interruptible()
				if b.has_spell("interrupt") and not it_list.is_empty() and b.why_not("apprentice", "interrupt") == "":
					_plan("apprentice", "interrupt", it_list[0])
				elif danger != "" and b.has_spell("ward") and b.why_not("apprentice", "ward") == "":
					_plan("apprentice", "ward", danger)
				elif b.why_not("apprentice", "spark") == "":
					_plan("apprentice", "spark", tgt)
				else:
					_plan("apprentice", "focus")
			else:
				var e = b.unit(tgt)
				_plan(u.uid, "attack", tgt if e != null and e.alive else b.enemies()[0].uid)
		if b.result == "" and b.turn == turn0:
			battle_view._on_end_turn()
			_fight_log.append_array(battle_view.last_report)
	_expect(b.result != "", "这一仗 %d 回合内分出胜负（%s）" % [max_turns, b.enc_id])

func _pick_target(b: Battle) -> String:
	var best = null
	for it in b.intents:
		var e = b.unit(it.uid)
		if e != null and e.alive and not it.cancelled and it.act in ["summon", "buff", "charge"]:
			if best == null or e.hp < best.hp: best = e
	if best == null:
		for e in b.enemies():
			if best == null or e.hp < best.hp: best = e
	return best.uid if best != null else ""

func _win_continue() -> void:
	var b := battle_view.b
	if b.result != "win":
		_expect(false, "没打赢：%s" % b.enc_id)
		return
	await _shot("battle_result_" + b.enc_id)
	battle_view.end_btns[0].pressed.emit()
	await get_tree().process_frame

func _spark_hit(n: int) -> bool:
	for l in _fight_log:
		if str(l).begins_with("你·星火 → ") and ("：%d 点" % n) in str(l): return true
	return false

func _find_in(lines: Array, s: String) -> bool:
	for l in lines:
		if s in str(l): return true
	return false

func _plan(who: String, act: String, target := "") -> void:
	var b := battle_view.b
	var turn0 := b.turn
	battle_view._on_act(who, act)
	if target != "": battle_view._on_target(target)
	if b.turn != turn0 or b.result != "": _fight_log.append_array(battle_view.last_report)
	# 排进去了，或者这一下排满了、已经自动开打（回合往前走了 / 分出胜负）
	if b.planned(who) == null and b.turn == turn0 and b.result == "":
		_expect(false, "排不进去：%s %s → %s（%s）" % [who, act, target, b.why_not(who, act)])

func _last_report() -> Array:
	return battle_view.last_report

## 追着一群会走动的敌人，走到它旁边撞上去（它也可能自己追上来）
func _hunt(zid: String) -> void:
	for i in 300:
		if mode == "battle": return
		if not can_move():
			await get_tree().process_frame
			continue
		var r = world.roamer(zid)
		if r == null:
			_expect(false, "%s 不在地图上" % zid)
			return
		var d: Vector2i = r.cell - world.player_cell
		if absi(d.x) + absi(d.y) == 1:
			world.step(d)
			await _until(func(): return mode == "battle", 3.0)
			return
		var path := world.path_to(r.cell, true)
		if path.is_empty():
			_expect(false, "走不到 %s 旁边" % zid)
			return
		world.step(path[0] - world.player_cell)
		await _until(func(): return not world.moving)
		await get_tree().process_frame
	_expect(false, "追 %s 追了 300 步" % zid)

## 走到某座圣龛跟前祈祷（圣龛画面由 _on_screen 按 _shrine_plan 选）
func _pray_at(id: String) -> void:
	var sh := shrine_def(id)
	if world.area != sh.area: await _walk_area(sh.area)
	await _walk_next_to(Vector2i(int(sh.cell[0]), int(sh.cell[1])))
	await _press("confirm")
	await _until(func(): return screens.kind == "" and mode == "map", 20.0)

# ---------------- 测试里走路：和玩家一样一格一格走 ----------------
func _check_maps() -> void:
	for a in Data.t("maps").areas:
		var bad := []
		var ad: Dictionary = Data.t("maps").areas[a]
		for n in Data.t("npcs").npcs:
			if n.area == a and n.cell == null: bad.append(n.id)
		for s in Data.t("spawns").spawns:
			if s.area == a and s.cell == null: bad.append(s.id)
		_expect(bad.is_empty(), "%s：人和敌人都有格子坐标 %s" % [a, str(bad)])

func _spawn(id: String) -> Dictionary:
	for s in Data.t("spawns").spawns:
		if s.id == id: return s
	return {}

func _spawn_visible(id: String) -> bool:
	for s in world.spawns_here():
		if s.id == id: return true
	return false

func _npc_cell(id: String) -> Vector2i:
	for n in Data.t("npcs").npcs:
		if n.id == id: return Vector2i(int(n.cell[0]), int(n.cell[1]))
	return Vector2i(-1, -1)

func _talk_npc(id: String) -> void:
	await _walk_next_to(_npc_cell(id))
	await _press("confirm")
	await _until(func(): return mode == "map" and not runner.running)

## 走到出口、一路换地方，直到进了 target
func _walk_area(target: String) -> void:
	var guard := 0
	while world.area != target and guard < 6:
		guard += 1
		var ex = world._exit_towards(target)
		if ex == null:
			_expect(false, "从 %s 找不到去 %s 的出口" % [world.area, target])
			return
		var from := world.area
		await _walk_onto(Vector2i(int(ex.cell[0]), int(ex.cell[1])))
		await _until(func(): return world.area != from)

## 走到某一格旁边并面对它
func _walk_next_to(t: Vector2i) -> void:
	var path := _path(t, true)
	await _follow(path)
	var d := t - world.player_cell
	if absi(d.x) + absi(d.y) == 1:
		world.facing = d

func _walk_onto(t: Vector2i) -> void:
	await _follow(_path(t, false))

func _follow(path: Array) -> void:
	for c in path:
		while not can_move(): await get_tree().process_frame
		world.step(c - world.player_cell)
		await _until(func(): return not world.moving)

## 白盒用的寻路：只走空地，不踩出口、触发格和敌人，除非那就是终点
func _path(t: Vector2i, adjacent: bool) -> Array:
	var p := world.path_to(t, adjacent)
	if p.is_empty() and not world._at_goal(t, adjacent):
		_expect(false, "%s 里走不到 %s%s" % [world.area, t, " 旁边" if adjacent else ""])
	return p

func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

func _hold(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _until(func(): return world.moving, 3.0)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _until(func(): return not world.moving, 3.0)

func _until(cond_fn: Callable, timeout := 20.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond_fn.call():
		if Time.get_ticks_msec() - t0 > timeout * 1000.0:
			_expect(false, "等太久（%.0f 秒）：mode=%s area=%s node=%s screen=%s" % [timeout, mode, world.area, runner.current, screens.kind])
			return
		await get_tree().process_frame

## 关键选择：先截一张确认框，再选
func _on_key_choice(pick: int) -> void:
	await _shot("key_confirm")
	dbox.pick(pick)

## 整屏画面：截图后关上（标题和结尾由测试自己点）
var _seen_screens := []
var _first_level_checked := false
func _on_screen(kind: String) -> void:
	_seen_screens.append(kind)
	if kind in ["title", "end"]: return
	match kind:
		"levelup":
			var offers: Array = screens.data.offers
			var names := offers.map(func(o): return o.name)
			_expect(offers.size() == 3 and names[0] != names[1] and names[1] != names[2] and names[0] != names[2], "升级弹出三张不重样的奖励：%s" % "、".join(PackedStringArray(names)))
			if route == "a" and not _first_level_checked:
				_first_level_checked = true
				_expect(int(GS.S.xp_total) == 8 and Party.level() == 2 and Party.tree_points() == 2 and Party.all_full(),
					"打完林子边的狼和路上的强盗：经验 %d，%d 级，技能点 %d，三个人回满" % [int(GS.S.xp_total), Party.level(), Party.tree_points()])
			await _shot("screen_levelup")
			screens._pick_boon(0)
		"tree":
			await _shot("screen_tree")
			if screens.data.get("respec", false) and not Party.tree.paid.is_empty():
				var spent := 0
				for k in Party.tree.paid: spent += int(Party.tree.paid[k])
				var p0 := Party.tree_points()
				var r := Party.respec()
				_expect(Party.tree_points() == p0 + spent, "在圣龛跟前洗点：%d 点全拿回来" % spent)
			for id in ROUTE_TREE.get(route, []):
				if Party.tree_points() <= 0: break
				var why := Party.node_why(id)
				if why != "":
					if id == "spark_heat" and route == "a" and Party.tree.rank("spark_heat") == 2 and Party.level() == 2:
						_expect(why == "要 3 级", "2 级时星火加热第三下点不了，写着「%s」" % why)
					continue
				screens._buy_node(id)
			screens._choose("done")
		"shrine":
			await _shot("screen_shrine")
			var c: String = _shrine_plan.pop_front() if not _shrine_plan.is_empty() else "leave"
			if c.begins_with("travel:") and not screens.data.travel.any(func(o): return o.id == c.substr(7)):
				_expect(false, "圣龛画面里没有「传到」%s" % c.substr(7))
				c = "leave"
			screens.data["choice"] = c
			screens.close()
		"bag":
			await _shot("screen_bag")
			if not GS.S.bag.is_empty():
				var it0: Dictionary = GS.S.bag[0]
				Party.equip(int(it0.uid))
				screens.data["equipped"] = 1
				print("  [换装] 换上 %s：%s" % [Party.item_info(it0).name, "，".join(PackedStringArray(Party.item_info(it0).lines))])
			screens._choose("done")
		_:
			await _shot("screen_" + kind)
			screens.close()

func _shot(name: String) -> void:
	if shot_dir == "" or DisplayServer.get_name() == "headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := shot_dir.path_join(name + ".png")
	img.save_png(path)
	print("[shot] ", path)

func _expect(ok: bool, what: String) -> void:
	print("[check] ", "PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)

func verify(key: String, ok: bool, note: String) -> void:
	print("[verify] %s=%s %s" % [key, "PASS" if ok else "FAIL", note])
	if not ok: fails.append(key)

# ---------------- 剧情走查（--story） ----------------
## 不走地图、不打仗，按 qa/story_walk.json 的顺序把六章和支线的对白一段段演完：
## 关键选择按路线挑（--route=a|b|c|d，路线写在 story_walk.json 的 routes），普通选项第一次挑第一个，
## 同一组选项再来时挑下一个（菜单就这样问遍再离开）；仗直接判赢；看水面、得到能力、换章只打印不弹画面。
## 每段打印台词、指令、换了的「下一步」，最后核对：六条主线做完、六个决定都有值、结局记上了、支线都有结局。
## 用法：godot --headless --path . -- --story --route=a [--quiet]
var story_mode := false
var _story_walk := {}
var _story_route := {}
var _story_picks := {}      # 普通选项：同一组选项第几次出现
var _story_quiet := false
var _story_node_picks := 0
var _story_last_next := ""

func _story() -> void:
	story_mode = true
	_story_quiet = "--quiet" in OS.get_cmdline_user_args()
	_story_walk = JSON.parse_string(FileAccess.get_file_as_string("res://qa/story_walk.json"))
	_story_route = _story_walk.routes.get(route, {})
	print("[story] route=%s %s" % [route, JSON.stringify(_story_route)])
	GS.new_game()
	Party.new_game()
	GS.S.metrics = {"t0": Time.get_ticks_msec(), "fights": [], "levelup_ms": [], "tree_ms": [], "bag_ms": [], "equip": 0}
	runner.init_vars()
	Quests.changed.connect(_story_next)
	for ch in ["1", "2", "3", "4", "5", "6"]:
		print("\n[story] ==== 第 %s 章 ====" % ch)
		for e in _story_walk.chapters.get(ch, []):
			var step: Dictionary = e if e is Dictionary else {"node": e}
			if step.has("route") and not route in step.route: continue
			if step.has("if") and not YarnRunner._truthy(runner.eval(step["if"])):
				print("[story] 跳过 %s（%s 不成立）" % [step.get("node", step.get("battle", "")), step["if"]])
				continue
			if step.has("battle"):
				print("[story] [地图战] %s 直接判赢" % step.battle)
				Quests.on_battle_won(step.battle)
				if step.has("spawn"): GS.S.defeated.append(step.spawn)
				if not step.has("node"): continue
			var node: String = step.node
			if not runner.has_title(node):
				_expect(false, "story_walk.json 里的节点 %s 不存在" % node)
				continue
			_story_node_picks = 0
			print("\n[node] ", node)
			runner.start(node)
			var t0 := Time.get_ticks_msec()
			while runner.running:
				await get_tree().process_frame
				if Time.get_ticks_msec() - t0 > 20000:
					_expect(false, "%s 演了 20 秒还没完（卡在 %s）" % [node, runner.current])
					runner.abort()
		if int(runner.v("chapter")) != int(ch) + 1 and ch != "6":
			_expect(false, "第 %s 章走完了没换到第 %d 章（现在 $chapter = %s）" % [ch, int(ch) + 1, str(runner.v("chapter"))])
	_story_summary()
	print("[story] 结果：%s，%d 条 FAIL" % ["PASS" if fails.is_empty() else "FAIL", fails.size()])
	get_tree().quit(0 if fails.is_empty() else 1)

func _story_dialog(entries: Array, cb: Callable) -> void:
	for e in entries:
		if not _story_quiet: print("    %s%s" % [(e.who + ": ") if e.who != "" else "", e.text])
	var choices: Array = entries[-1].get("choices", [])
	if choices.is_empty():
		if cb.is_valid(): cb.call_deferred()
		return
	_story_node_picks += 1
	if _story_node_picks > 40:
		_expect(false, "%s 里选了 40 次还没出来，可能是菜单绕圈" % runner.current)
		runner.abort.call_deferred()
		return
	var pick := -1
	# 关键选择：选项下面 set 了哪个决定变量，就按路线挑
	for i in choices.size():
		for v in choices[i].get("sets", {}):
			if _story_route.has(v) and str(choices[i].sets[v]) == str(_story_route[v]):
				pick = i
	var why := "路线"
	if pick < 0:
		var overrides: Dictionary = _story_walk.get("picks", {}).get(route, {})
		var key := runner.current + "|" + "|".join(PackedStringArray(choices.map(func(c): return c.t)))
		var n := int(_story_picks.get(key, 0))
		_story_picks[key] = n + 1
		if overrides.has(runner.current):
			# 指定挑哪句：写选项里的几个字
			for i in choices.size():
				if str(overrides[runner.current]) in choices[i].t: pick = i
			why = "指定"
		if pick < 0:
			pick = mini(n, choices.size() - 1)
			why = "第 %d 次" % (n + 1)
	var c: Dictionary = choices[pick]
	var sets := ""
	if not c.get("sets", {}).is_empty(): sets = " " + JSON.stringify(c.sets)
	print("  [选] %s%s（%s，%d 选 1）%s" % ["◆ " if c.kind == "key" else "", c.t, why, choices.size(), sets])
	c.fn.call_deferred()

## 走查里不弹画面、不进战斗；返回 true 表示这里处理完了
func _story_command(cmd: String, args: Array) -> bool:
	match cmd:
		"vision":
			if GS.book_page(args[0]).is_empty(): GS.S.book.append({"decision": args[0], "after": []})
			var vd := Data.vision(args[0])
			print("  [看水面] %s：%s" % [vd.get("surface", ""), UIKit.t(vd.get("text", ""))])
			if vd.get("text", "") == "": _expect(false, "%s 那一幕没有画面文字（prophecy.json text）" % args[0])
			return true
		"unlock":
			if not args[0] in GS.S.unlocks: GS.S.unlocks.append(args[0])
			print("  [能力] ", args[0])
			return true
		"chapter":
			GS.S.vars["chapter"] = int(args[0])
			print("  [换章] 第 %s 章" % args[0])
			return true
		"fight_npcs":
			print("  [剧情战] %s 直接判赢" % args[0])
			if Data.encounter(args[0]).is_empty(): _expect(false, "遭遇 %s 不在 combat.json" % args[0])
			GS.S.vars["last_battle"] = args[0]
			GS.S.vars["last_battle_won"] = true
			Quests.on_battle_won(args[0])
			return true
		"autosave":
			return true
	return false

func _story_next() -> void:
	for q in Quests.active():
		if Quests.is_main(q):
			var t := Quests.objective(q)
			if t != _story_last_next:
				_story_last_next = t
				print("  [下一步] ", t)
			return

func _story_summary() -> void:
	print("\n[story] ==== 走完了 ====")
	var vars: Dictionary = GS.S.vars
	var line := []
	for k in ["D1", "D2", "D3", "D4", "D5", "D6", "S1", "S2", "S3", "S4", "V"]: line.append("%s=%s" % [k, str(vars.get(k, ""))])
	print("[story] 决定：", " ".join(PackedStringArray(line)))
	var comp := []
	for k in vars:
		if str(k).begins_with("c_"): comp.append("%s=%s" % [str(k).substr(2), str(vars[k])])
	comp.sort()
	print("[story] 同伴：", " ".join(PackedStringArray(comp)))
	var flags := []
	for k in vars:
		if typeof(vars[k]) == TYPE_BOOL and vars[k]: flags.append(str(k))
	flags.sort()
	print("[story] 标记：", " ".join(PackedStringArray(flags)))
	print("[story] 能力：", " ".join(PackedStringArray(GS.S.unlocks)))
	for p in GS.S.book: print("[story] 预言簿 %s：后来 %s" % [p.decision, "、".join(PackedStringArray(p.after.map(func(k): return UIKit.t(k))))])
	for q in Quests.table:
		var r: Dictionary = GS.S.quests.get(q, {})
		print("[story] 任务 %s %s：%s %s" % [q, Quests.title(q), r.get("state", "none"), r.get("ending", "")])
	for q in ["1001", "1002", "1003", "1004", "1005", "1006"]:
		_expect(Quests.state(q) == "done", "主线 %s 做完了" % q)
	for k in ["D1", "D2", "D3", "D4", "D5", "D6"]:
		_expect(str(vars.get(k, "")) != "", "%s 有值" % k)
	_expect(str(GS.S.quests.get("1006", {}).get("ending", "")) in ["E1", "E2", "E3"], "结局记在 1006 上（%s）" % str(GS.S.quests.get("1006", {}).get("ending", "")))
	for q in ["2301", "2401", "2501", "2502"]:
		_expect(Quests.state(q) == "done" and str(GS.S.quests.get(q, {}).get("ending", "")) != "", "支线 %s 有结局（做了，或到关门时按默认结算）" % q)
