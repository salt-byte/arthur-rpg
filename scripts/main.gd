extends Node2D
## 入口。第 6 步只是工程骨架：读全部数据、加载对白、跑通指令。
## 地图、战斗、界面第 8 步（白盒）照设计页做；剧情不写进这里，这里只实现 Yarn 指令。
##
## 无头测试：godot --headless --path . -- --playtest [--route=a|b|c]
##   按顺序跑第 1 章的样例对白，关键选择按 route 选第几个，打印每句台词、每个指令，最后核对变量和存档。

var runner: YarnRunner
var playtest := false
var route := "a"
var fails := []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	playtest = "--playtest" in args
	for a in args:
		if a.begins_with("--route="): route = a.substr(8)
	TranslationServer.set_locale("zh")
	runner = YarnRunner.new()
	add_child(runner)
	runner.handler = self
	runner.ui = self
	runner.load_content("res://content/dialogue")
	Quests.runner = runner
	runner.init_vars()
	var summary := "[boot] ok tables=%d nodes=%d vars=%d quests=%d data_errors=%d" % [
		Data.tables.size(), runner.prog.nodes.size(), runner.prog.declares.size(), Quests.table.size(), Data.errors.size()]
	print(summary)
	for e in Data.errors: print("[boot] ", e)
	if playtest:
		await _playtest()
		get_tree().quit(1 if not fails.is_empty() else 0)
	else:
		_show_status(summary)

## 第 6 步的占位画面：中文字体第 8 步再接，这里只用 ASCII
func _show_status(summary: String) -> void:
	var l := Label.new()
	l.text = "Merlin's Apprentice - project skeleton\n" + summary.trim_prefix("[boot] ")
	l.position = Vector2(40, 40)
	l.add_theme_font_size_override("font_size", 24)
	add_child(l)

# ---------------- 无头测试 ----------------
func _playtest() -> void:
	print("[playtest] route=", route)
	_expect(tr("quest_1001_name") == "庄园的冬天", "文本表能按键取字（quest_1001_name）")
	_expect(tr("ch1_001") != "ch1_001", "对白表能按行号取字（ch1_001）")
	await _run("Ch1_Start")
	_expect(runner.quest_part(1001) == 1101, "开场后任务在 1101 赶狼")
	print("[battle] wolves（第 6 步跳过战斗，按打赢处理）")
	Quests.on_battle_won("wolves")
	await _run("Ch1_WolvesDone")
	_expect(runner.quest_part(1001) == 1102, "打完狼任务到 1102 石圈")
	await _run("Ch1_StoneCircle")
	_expect(not GS.book_page("D1").is_empty(), "看水面以后预言簿有 D1 这一页")
	await _run("Merlin")
	_expect(runner.has_unlock("u_interrupt"), "梅林教了打断")
	_expect(runner.quest_part(1001) == 1104, "影子那一仗以后任务到 1104 马厩")
	await _run("Ch1_Stable")
	var want: String = {"a": "D1a", "b": "D1b", "c": "D1c"}.get(route, "D1a")
	_expect(runner.v("D1") == want, "关键选择记成 %s" % want)
	_expect(runner.v("kay_believes_you") == (want == "D1a"), "凯信不信你跟着选项走")
	_expect(runner.v("kay_rift") == (want == "D1b"), "兄弟有没有疙瘩跟着选项走")
	_expect(Quests.state("1001") == "done", "第 1 章主线完成")
	_expect(int(runner.v("chapter")) == 2, "进入第 2 章")
	# 进第 2 章时已经自动存过档；JSON 读回来整数会变成小数，先过一遍 JSON 再比
	var before := JSON.stringify(JSON.parse_string(JSON.stringify(GS.S)))
	GS.new_game()
	_expect(GS.load_save() and JSON.stringify(GS.S) == before, "进第 2 章时自动存档，读回来和存之前一样")
	print("[playtest] %s（%d 条不过）" % ["PASS" if fails.is_empty() else "FAIL", fails.size()])

func _run(node: String) -> void:
	print("[node] ", node)
	runner.start(node)
	if runner.running: await runner.finished

func _expect(ok: bool, what: String) -> void:
	print("[check] ", "PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)

# ---------------- 给 YarnRunner 的界面接口（白盒前的文字版） ----------------
func dialog(entries: Array, cb := Callable()) -> void:
	for e in entries:
		var who: String = e.get("who", "")
		print(("  " + who + "：" if who != "" else "  ") + e.get("text", ""))
		if e.has("choices"):
			var cs: Array = e.choices
			var pick := 0
			if not cs.is_empty() and cs[0].kind == "key":
				pick = clampi({"a": 0, "b": 1, "c": 2}.get(route, 0), 0, cs.size() - 1)
				print("  [确认] 说出口就不能收回。确定吗？→ 确定")
			for i in cs.size():
				print("    %s %s%s" % ["→" if i == pick else " ", "💧" if cs[i].kind == "key" else "", cs[i].t])
			cs[pick].fn.call_deferred()
			return
	if cb.is_valid(): cb.call_deferred()

func look_for(_who: String) -> String: return ""

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
		"vision":
			if GS.book_page(args[0]).is_empty(): GS.S.book.append({"decision": args[0], "after": []})
			print("  [看水面] ", tr(Data.vision(args[0]).get("text", "")))
		"book_after": GS.book_page(args[0]).after.append(args[1])
		"chapter":
			GS.S.vars["chapter"] = int(args[0])
			GS.save()   # 进新的一章自动存档（overworld.md）
		"autosave": GS.save()
		"notify": print("  [提示] ", tr(args[0]))
		"fight_npcs":
			# 第 6 步没有战斗，按打赢处理；第 8 步换成真的战斗，打完再 runner.resume()
			GS.S.vars["last_battle"] = args[0]
			GS.S.vars["last_battle_won"] = true
			Quests.on_battle_won(args[0])
		_:
			push_warning("没实现的指令 <<%s>>" % cmd)
	return false
