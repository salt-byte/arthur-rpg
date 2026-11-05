class_name YarnProgram
extends RefCounted
## 读取 .yarn 文件，解析成节点树。支持原作用到的 Yarn Spinner 2 语法子集：
##   title / tags / --- / ===            节点
##   说话人: 台词 #line:xxx               台词（没有「名字: 」就是旁白）
##   -> 选项 #quest <<if 条件>>           选项，下面缩进的是选中后的内容
##   <<if>> <<elseif>> <<else>> <<endif>> 条件分支
##   <<set $x to 值>> <<declare $x = 值>> 变量
##   <<jump 节点>> <<jump {$变量}>> <<stop>>
##   <<任意指令 参数...>>                  交给游戏处理（start_quest、add_gold、fight_npcs……）
##   {表达式}                              台词里插值

var nodes := {}        # title -> {"title", "tags", "body": [语句]}
var declares := {}     # 变量名 -> 默认值表达式

func load_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		push_error("找不到对话目录 " + dir)
		return
	for f in d.get_files():
		if f.ends_with(".yarn"):
			load_text(FileAccess.get_file_as_string(dir.path_join(f)), f)

func load_text(src: String, fname := "") -> void:
	var raw := src.split("\n")
	var i := 0
	while i < raw.size():
		var header := {}
		while i < raw.size() and raw[i].strip_edges() != "---":
			var h := raw[i].strip_edges()
			var c := h.find(":")
			if c > 0: header[h.substr(0, c).strip_edges()] = h.substr(c + 1).strip_edges()
			i += 1
		i += 1
		var toks := []
		while i < raw.size() and raw[i].strip_edges() != "===":
			var line: String = raw[i].replace("\t", "    ")
			var t := line.strip_edges()
			if t != "" and not t.begins_with("//"):
				toks.append({"indent": line.length() - line.lstrip(" ").length(), "text": t, "src": "%s:%d" % [fname, i + 1]})
			i += 1
		i += 1
		if header.has("title"):
			var r := _seq(toks, 0, -1, [])
			nodes[header.title] = {"title": header.title, "tags": header.get("tags", ""), "body": r[0]}

static func _cmd(t: String) -> String:
	# "<<if $x>>" -> "if $x"
	return t.substr(2, t.length() - 4).strip_edges() if t.begins_with("<<") and t.ends_with(">>") else ""

func _seq(toks: Array, i: int, min_indent: int, stops: Array) -> Array:
	var out := []
	while i < toks.size():
		var tk: Dictionary = toks[i]
		if tk.indent < min_indent: break
		var t: String = tk.text
		var c := _cmd(t)
		var word := c.split(" ")[0] if c != "" else ""
		if word in stops: break
		if t.begins_with("->"):
			var group := []
			var ind: int = tk.indent
			while i < toks.size() and toks[i].indent == ind and toks[i].text.begins_with("->"):
				var opt := _parse_text(toks[i].text.substr(2).strip_edges())
				var r := _seq(toks, i + 1, ind + 1, [])
				opt["body"] = r[0]
				group.append(opt)
				i = r[1]
			out.append({"type": "options", "options": group})
			continue
		if word == "if":
			var branches := []
			var cond := c.substr(3).strip_edges()
			i += 1
			while true:
				var r := _seq(toks, i, min_indent, ["elseif", "else", "endif"])
				branches.append([cond, r[0]])
				i = r[1]
				if i >= toks.size():
					push_error("缺少 <<endif>>：" + tk.src)
					break
				var e := _cmd(toks[i].text)
				i += 1
				if e.begins_with("elseif"): cond = e.substr(7).strip_edges()
				elif e == "else": cond = "true"
				else: break
			out.append({"type": "if", "branches": branches})
			continue
		i += 1
		if word == "set":
			var rest := c.substr(4).strip_edges()
			var sep := " to " if rest.find(" to ") > 0 else "="
			var p := rest.split(sep, true, 1)
			out.append({"type": "set", "var": p[0].strip_edges().trim_prefix("$"), "expr": p[1].strip_edges()})
		elif word == "declare":
			var p2 := c.substr(8).strip_edges().split("=", true, 1)
			declares[p2[0].strip_edges().trim_prefix("$")] = p2[1].strip_edges()
		elif word == "jump":
			out.append({"type": "jump", "node": c.substr(5).strip_edges()})
		elif word == "stop":
			out.append({"type": "stop"})
		elif c != "":
			out.append({"type": "command", "name": word, "args": _args(c.substr(word.length()).strip_edges())})
		else:
			var ln := _parse_text(t)
			ln["type"] = "line"
			out.append(ln)
	return [out, i]

## 台词 / 选项文本：拆出行号、标签、选项条件、说话人
static func _parse_text(t: String) -> Dictionary:
	var cond := ""
	var ci := t.rfind("<<if ")
	if ci >= 0 and t.ends_with(">>"):
		cond = t.substr(ci + 5, t.length() - ci - 7).strip_edges()
		t = t.substr(0, ci).strip_edges()
	var tags := []
	var id := ""
	var parts := t.split(" #")
	t = parts[0].strip_edges()
	for k in range(1, parts.size()):
		var tag: String = parts[k].strip_edges()
		if tag.begins_with("line:"): id = tag.substr(5)
		else: tags.append(tag)
	return {"text": t, "id": id, "tags": tags, "cond": cond}

static func split_speaker(t: String) -> Array:
	var re := RegEx.new()
	re.compile("^([^\\s:：]{1,12}): (.*)$")
	var m := re.search(t)
	if m: return [m.get_string(1), m.get_string(2)]
	return ["", t]

static func _args(s: String) -> Array:
	var out := []
	var cur := ""
	var q := false
	for ch in s:
		if ch == "\"":
			q = not q
		elif ch == " " and not q:
			if cur != "": out.append(cur)
			cur = ""
		else:
			cur += ch
	if cur != "": out.append(cur)
	return out
