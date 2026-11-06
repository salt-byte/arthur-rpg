class_name YarnRunner
extends Node
## 执行 Yarn 对话。台词按行号从对白表（TranslationServer）取文字；
## 遇到 <<指令>> 交给 handler.yarn_command(name, args)，返回 true 表示要等（比如战斗），之后调用 resume()。
## 来自插件 godot-project-structure 的模板；本作改了：关键选择 #key、quest_part()、has_unlock()，去掉了 graveholme 的物品、骰子、墓碑函数。

signal finished

var prog := YarnProgram.new()
var handler: Object
var ui: Node
var stack: Array = []
var running := false
var waiting := false
var current := ""

func load_content(dir: String) -> void:
	prog.load_dir(dir)

func has_title(t: String) -> bool: return prog.nodes.has(t)

## 新游戏 / 读档后补齐变量默认值
func init_vars() -> void:
	if not GS.S.has("vars"): GS.S["vars"] = {}
	for k in prog.declares:
		if not GS.S.vars.has(k):
			GS.S.vars[k] = eval(prog.declares[k])

func start(title: String) -> void:
	if running: return
	if not has_title(title):
		push_error("没有对话节点 " + title)
		return
	running = true
	_enter(title)
	_step()

func _enter(title: String) -> void:
	current = title
	GS.S.visited[title] = true
	stack = [{"stmts": prog.nodes[title].body, "pc": 0}]

func resume() -> void:
	if not waiting: return
	waiting = false
	_step()

func _step() -> void:
	while true:
		if stack.is_empty():
			_finish()
			return
		var f: Dictionary = stack[-1]
		if f.pc >= f.stmts.size():
			stack.pop_back()
			continue
		var s: Dictionary = f.stmts[f.pc]
		f.pc += 1
		match s.type:
			"line":
				_show_line(s)
				return
			"options":
				_present(["", ""], s)
				return
			"if":
				for b in s.branches:
					if _truthy(eval(b[0])):
						stack.append({"stmts": b[1], "pc": 0})
						break
			"set":
				GS.S.vars[s.var] = eval(s.expr)
			"jump":
				var t: String = s.node
				if t.begins_with("{"): t = str(eval(t.substr(1, t.length() - 2)))
				if not has_title(t):
					push_error("跳转目标不存在 " + t)
					stack.clear()
					continue
				_enter(t)
			"stop":
				stack.clear()
			"command":
				if handler.yarn_command(s.name, s.args):
					waiting = true
					return

## 中途停下（战斗输了选「回地图」）：这段对话不再往下走
func abort() -> void:
	if not running: return
	stack.clear()
	_finish()

func _finish() -> void:
	running = false
	waiting = false
	stack.clear()
	finished.emit()

## 台词后面紧跟选项时，把台词和选项放在同一个对话框里
func _take_options():
	for idx in range(stack.size() - 1, -1, -1):
		var f: Dictionary = stack[idx]
		if f.pc < f.stmts.size():
			var s: Dictionary = f.stmts[f.pc]
			if s.type == "options":
				f.pc += 1
				return s
			return null
	return null

func line_text(s: Dictionary) -> String:
	var t := s.text as String
	if s.id != "":
		var tr_t := str(TranslationServer.translate(s.id))
		if tr_t != "" and tr_t != s.id: t = tr_t
	return interpolate(t)

func _show_line(s: Dictionary) -> void:
	var sp := YarnProgram.split_speaker(line_text(s))
	var opts = _take_options()
	if opts != null:
		_present(sp, opts)
	else:
		ui.dialog([{"who": sp[0], "text": sp[1], "look": handler.look_for(sp[0])}], _step)

func _present(sp: Array, opts: Dictionary) -> void:
	var choices := []
	for o in opts.options:
		if o.cond != "" and not _truthy(eval(o.cond)): continue
		var opt: Dictionary = o
		# key：关键选择（带水滴标记，选中后先确认）。q / topic 是插件自带的图标
		var kind := "key" if "key" in o.tags else ("q" if "quest" in o.tags else ("topic" if "topic" in o.tags else ""))
		choices.append({"t": line_text(o), "kind": kind, "fn": func(): _choose(opt)})
	ui.dialog([{"who": sp[0], "text": sp[1], "look": handler.look_for(sp[0]), "choices": choices}])

func _choose(o: Dictionary) -> void:
	stack.append({"stmts": o.body, "pc": 0})
	_step()

# ---------------- 表达式 ----------------
var _re_var := RegEx.create_from_string("\\$([A-Za-z_][A-Za-z0-9_]*)")
var _re_interp := RegEx.create_from_string("\\{([^{}]+)\\}")

func eval(expr: String):
	var e := _re_var.sub(expr, "v(\"$1\")", true)
	e = e.replace(" is ", " == ").replace(" eq ", " == ").replace(" neq ", " != ")
	var ex := Expression.new()
	if ex.parse(e) != OK:
		push_error("表达式错误：%s（%s）" % [expr, ex.get_error_text()])
		return null
	var r = ex.execute([], self, false)
	if ex.has_execute_failed():
		push_error("表达式执行失败：" + expr)
		return null
	return r

func interpolate(t: String) -> String:
	var out := t
	for m in _re_interp.search_all(t):
		var val = eval(m.get_string(1))
		var sv := str(int(val)) if typeof(val) == TYPE_FLOAT and val == floor(val) else str(val)
		out = out.replace(m.get_string(0), sv)
	return out

static func _truthy(x) -> bool:
	if x == null: return false
	if typeof(x) == TYPE_STRING: return x != ""
	return bool(x)

# ---------------- 给 Yarn 用的函数 ----------------
func v(name: String):
	if GS.S.vars.has(name): return GS.S.vars[name]
	if prog.declares.has(name): return eval(prog.declares[name])
	push_error("未声明的变量 $" + name)
	return null

func is_quest_active(id: int) -> bool: return Quests.state(id) == "active"
func quest_state(id: int) -> String: return Quests.state(id)
## 任务现在在哪一步（主线就是剧情谱节点号）；没开始、已完成是 0
func quest_part(id: int) -> int:
	var r: Dictionary = GS.S.quests.get(str(id), {})
	return int(r.get("part", 0)) if r.get("state", "") == "active" else 0
func visited(node: String) -> bool: return GS.S.visited.has(node)
func has_unlock(id: String) -> bool: return id in GS.S.unlocks
