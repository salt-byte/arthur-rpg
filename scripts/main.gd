extends Node2D
## 入口。第 8 步白盒切片：色块地图 + 占位人物，把第 1 章（狼群、石圈看水面、阁楼学打断、梅林的影子、马厩的关键选择）
## 接到第 2 章教堂那一幕应验。剧情全在 content/dialogue/*.yarn，这里只实现指令、把地图 / 对话 / 战斗 / 整屏画面串起来。
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
	runner.init_vars()
	_end_shown = false
	var cs := chapter_start(1)
	world.load_area(cs.area, Vector2i(int(cs.cell[0]), int(cs.cell[1])))
	mode = "map"
	_refresh_next()
	start_dialog(cs.node)

func load_game() -> void:
	if not GS.load_save():
		new_game()
		return
	if not GS.S.has("defeated"): GS.S["defeated"] = []
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
			if e.is_action_pressed("confirm"):
				hud.show_controls = false
				world.interact()
			elif e.is_action_pressed("cancel"):
				open_book()

# ---------------- 对话 ----------------
func start_dialog(node: String) -> void:
	if runner.running or node == "": return
	mode = "dialog"
	print("[node] ", node)
	runner.start(node)

## YarnRunner 的界面接口
func dialog(entries: Array, cb := Callable()) -> void:
	mode = "dialog"
	dbox.show_entries(entries, cb)

func look_for(_who: String) -> String: return ""

func _on_dialog_finished() -> void:
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
	if runner.visited("Ch2_Church") and not _end_shown:
		_end_shown = true
		await get_tree().create_timer(2.5, true, false, true).timeout
		while screens.is_open() or runner.running:
			await get_tree().create_timer(0.5, true, false, true).timeout
		mode = "screen"
		screens.open("end", {}, _on_end)

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
	match cmd:
		"start_quest": Quests.start(args[0])
		"progress_quest": Quests.progress(args[0], int(args[1]))
		"complete_quest": Quests.complete(args[0], args[1] if args.size() > 1 else "")
		"companion": GS.S.vars["c_" + args[0]] = args[1]
		"unlock":
			if not args[0] in GS.S.unlocks: GS.S.unlocks.append(args[0])
			var u := Data.unlock_def(args[0])
			if u.has("popup") and Data.param("story-unlocks", "show_unlock_popup", true):
				_wait_screen("unlock", {"popup": u.popup})
				return true
		"vision":
			if GS.book_page(args[0]).is_empty(): GS.S.book.append({"decision": args[0], "after": []})
			var vd := Data.vision(args[0])
			print("  [看水面] ", UIKit.t(vd.get("text", "")))
			_wait_screen("vision", {"surface": vd.get("surface", ""), "text": UIKit.t(vd.get("text", ""))},
				func(): hud.show_toast([UIKit.f("ui_book_new", {"t": vd.get("surface", "")})]))
			return true
		"book_after":
			var page := GS.book_page(args[0])
			if not page.is_empty() and not args[1] in page.after: page.after.append(args[1])
			var ch := int(str(Data.vision(args[0]).get("seen_at", "1100")).substr(1, 1))
			hud.show_toast([UIKit.f("ui_book_toast", {"ch": ch}), UIKit.f("ui_book_after", {"t": UIKit.t(args[1])})])
			print("  [预言簿] 后来：", UIKit.t(args[1]))
		"chapter":
			var n := int(args[0])
			GS.S.vars["chapter"] = n
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
		_:
			push_warning("没实现的指令 <<%s>>" % cmd)
	return false

# ---------------- 战斗 ----------------
func _on_spawn_battle(sp: Dictionary) -> void:
	if mode != "map": return
	start_battle(sp.enemy, {"spawn": sp})

func start_battle(enc_id: String, ctx: Dictionary) -> void:
	var e := Data.encounter(enc_id)
	var party: Array = e.get("party", {}).get("fixed", []).duplicate()
	var b := Battle.new()
	b.setup(enc_id, party, int(runner.v("chapter")), GS.S.unlocks, GS.S.vars)
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
	if r == "win":
		Quests.on_battle_won(ctx.enc)
		if ctx.has("spawn"):
			GS.S.defeated.append(ctx.spawn.id)
			mode = "map"
			world.queue_redraw()
			start_dialog(ctx.spawn.get("on_defeat", ""))
		else:
			mode = "dialog"
			runner.resume()
	else:
		mode = "map"
		if ctx.has("yarn"):
			runner.abort()
	_refresh_next()

# =====================================================================
# 无头测试
# =====================================================================
var _key_pick := -1

func _playtest() -> void:
	print("[playtest] route=", route)
	Engine.time_scale = 6.0
	# 看门狗：卡住超过 4 分钟就判失败退出，不让 verify.py 干等
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func():
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
	verify("launch", world.area == "manor" and Quests.is_active("1001") and not GS.has_save(), "清存档后新开一局：在庄园，主线 1001 开始，没有旧存档")
	await _shot("gd_verify_render")

	# 一次输入：按「下」走一格
	var before := world.player_cell
	await _hold("move_down")
	verify("input", world.player_cell != before, "按「下」以后学徒从 %s 走到 %s" % [before, world.player_cell])

	# 找凯说话（按确认）
	await _talk_npc("kay")
	_expect(runner.visited("Kay"), "按确认和凯说话，跑了 Kay 节点")
	await _shot("map_manor")

	# 进林子，碰上狼
	await _walk_area("forest")
	_expect(world.area == "forest", "从庄园南门走进森林")
	await _shot("map_forest")
	var sp := _spawn("ch1_wolves")
	await _walk_next_to(Vector2i(int(sp.cell[0]), int(sp.cell[1])))
	world.step(Vector2i(int(sp.cell[0]), int(sp.cell[1])) - world.player_cell)
	await _until(func(): return mode == "battle")
	await _fight_wolves()
	await _until(func(): return mode == "map" and not runner.running)
	_expect(runner.quest_part(1001) == 1102, "打完狼任务到 1102 石圈")
	_expect(_spawn_visible("ch1_wolves") == false, "打赢的狼群从地图上消失")

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
	await _press("cancel")
	await _until(func(): return screens.kind == "" and mode == "map")

	# 回庄园，进阁楼：梅林开口、教打断、影子
	await _walk_area("manor")
	await _walk_onto(Vector2i(5, 3))
	await _until(func(): return mode == "battle")
	_expect(runner.has_unlock("u_interrupt"), "梅林教了打断（新能力提示弹过）")
	await _fight_shadow()
	await _until(func(): return mode == "map" and not runner.running)
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
	verify("coreLoop", Quests.state("1001") == "done" and runner.visited("Ch1_WolvesDone") and "ch1_wolves" in GS.S.defeated
		and runner.has_unlock("u_interrupt") and runner.v("D1") == want and runner.quest_part(1002) == 1203,
		"接 1001 → 打赢狼群 → 1102 → 看水面记下 D1 → 学打断、打赢影子 → 马厩选 %s → 1001 完成 → 进第 2 章 1203" % want)
	# 存档：马厩选完、进第 2 章时自动存过；存档里是第 2 章、选的是 want、站在伦敦
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GS.SAVE_PATH))
	_expect(typeof(saved) == TYPE_DICTIONARY and int(saved.vars.chapter) == 2 and saved.vars.D1 == want and saved.area == "london",
		"进第 2 章时自动存档：存档里是第 2 章、D1=%s、站在伦敦" % want)
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
	battle_view._on_end_turn()
	for i in 6:
		await get_tree().create_timer(0.55).timeout
		await _shot("demo_4_anim_%d" % i)
	await get_tree().create_timer(2.5).timeout
	await _shot("demo_5_turn2")
	get_tree().quit()

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
func _fight_wolves() -> void:
	var b := battle_view.b
	_expect(not "kay_cover" in b.actions_for("kay"), "第 1 章凯的菜单里没有「挡在前面」（%s）" % route)
	_expect(b.turn == 1 and b.intents.size() == 3, "狼群第 1 回合三只狼都亮出意图")
	# 第 1 回合：凯和亚瑟打头狼，学徒给凯护身
	_plan("kay", "attack", "wolf_leader")
	_plan("arthur", "attack", "wolf_leader")
	_plan("apprentice", "ward", "kay")
	battle_view._on_end_turn()
	var texts := b.intents.map(func(it): return b.intent_text(it))
	_expect("头狼 扑咬 → 亚瑟 5" in texts and "灰狼 咬 → 凯 3" in texts and "瘦狼 召唤 2" in texts,
		"第 2 回合同时亮出「头狼 扑咬 → 亚瑟 5」「灰狼 咬 → 凯 3」「瘦狼 召唤 2」")
	await _shot("battle_intents")
	# 第 2 回合：凯和亚瑟打瘦狼、学徒护身亚瑟
	var arthur_hp: int = b.unit("arthur").hp
	_plan("kay", "attack", "wolf_howler")
	_plan("arthur", "attack", "wolf_howler")
	_plan("apprentice", "ward", "arthur")
	await _shot("battle_planned")
	battle_view._on_end_turn()
	var log_t := "\n".join(PackedStringArray(_last_report()))
	_expect("瘦狼倒下，召唤作废" in log_t, "瘦狼在叫之前倒下，打印「瘦狼倒下，召唤作废」")
	_expect(arthur_hp - b.unit("arthur").hp == 1, "亚瑟有护身，头狼那一口只挨 1 点")
	# 第 3 回合收尾
	_plan("kay", "attack", "wolf_leader")
	_plan("arthur", "attack", "wolf_grey")
	_plan("apprentice", "spark", "wolf_grey")
	battle_view._on_end_turn()
	_expect(b.result == "win" and b.turn == 3, "狼群 3 回合打赢（设计页 3–5 回合）")
	await _shot("battle_win")
	battle_view.end_btns[0].pressed.emit()

func _fight_shadow() -> void:
	var b := battle_view.b
	_expect(b.allies().size() == 1, "影子那一仗只有学徒一个人")
	var first := b.intents.map(func(it): return b.intent_text(it))
	# 第一次：不打断，第 2 回合挨 12 点倒下
	_plan("apprentice", "spark", "merlin_shadow")
	battle_view._on_end_turn()
	battle_view._on_end_turn()
	var log_t := "\n".join(PackedStringArray(_last_report()))
	_expect(b.result == "lose" and "梅林的影子 重劈 → 你：12 点" in log_t, "不打断：第 2 回合学徒挨 12 点、倒下")
	_expect(battle_view.end_btns.size() == 2 and battle_view.end_btns[0].text == UIKit.t("ui_retry"), "输了出现「再来一次」和「回地图」")
	await _shot("battle_lose")
	battle_view.end_btns[0].pressed.emit()
	var again := b.intents.map(func(it): return b.intent_text(it))
	_expect(first == again and b.turn == 1, "再来一次：第 1 回合的意图逐字一样（%s）" % ", ".join(PackedStringArray(again)))
	# 第二次：第 1 回合打断
	_plan("apprentice", "interrupt", "merlin_shadow")
	battle_view._on_end_turn()
	_expect("蓄力被打断，作废" in "\n".join(PackedStringArray(_last_report())), "第 1 回合打断：打印「蓄力……作废」")
	_plan("apprentice", "spark", "merlin_shadow")
	battle_view._on_end_turn()
	_plan("apprentice", "interrupt", "merlin_shadow")
	battle_view._on_end_turn()
	_plan("apprentice", "spark", "merlin_shadow")
	battle_view._on_end_turn()
	_plan("apprentice", "spark", "merlin_shadow")
	battle_view._on_end_turn()
	_expect(b.result == "win", "打断两次、星火三次，5 回合打赢影子（第 %d 回合）" % b.turn)
	battle_view.end_btns[0].pressed.emit()

var _report_seen := []
func _plan(who: String, act: String, target := "") -> void:
	battle_view._on_act(who, act)
	if target != "": battle_view._on_target(target)
	if battle_view.b.planned(who) == null:
		_expect(false, "排不进去：%s %s → %s" % [who, act, target])

func _last_report() -> Array:
	return battle_view.last_report

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
	var start := world.player_cell
	var avoid := {}
	for e in world.A.get("exits", []): avoid[Vector2i(int(e.cell[0]), int(e.cell[1]))] = true
	for tr_ in world.A.get("triggers", []):
		if cond(tr_.get("cond", "")): avoid[Vector2i(int(tr_.cell[0]), int(tr_.cell[1]))] = true
	for s in world.spawns_here(): avoid[Vector2i(int(s.cell[0]), int(s.cell[1]))] = true
	var goal := {}
	if adjacent:
		for d in World.DIRS.values(): goal[t + d] = true
	else:
		goal[t] = true
	var prev := {start: start}
	var q := [start]
	var found = null
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if goal.has(c):
			found = c
			break
		for d in World.DIRS.values():
			var n: Vector2i = c + d
			if prev.has(n) or world.blocked(n) or n.x < 0 or n.y < 0 or n.x >= world.W or n.y >= world.H: continue
			if avoid.has(n) and not goal.has(n): continue
			prev[n] = c
			q.append(n)
	if found == null:
		_expect(false, "%s 里走不到 %s 旁边" % [world.area, t])
		return []
	var path := []
	var c: Vector2i = found
	while c != start:
		path.push_front(c)
		c = prev[c]
	return path

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
func _on_screen(kind: String) -> void:
	_seen_screens.append(kind)
	if kind in ["title", "end"]: return
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
