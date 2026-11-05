extends Node
## 任务管理（对应原作的 QuestManager）。
## 结构：任务 → 分步目标(parts) → 完成条件(kill / collect，满足后自动进入下一步) → 结局(endings)。
## 存档里每个任务记 {state: active/done, part: 当前步, ending: 结局, kills: 计数}。
## 来自插件模板；本作的步骤 id 是剧情谱节点号，步骤可以带 battle（打赢这场遭遇进入下一步），没有物品。

signal changed
var table := {}
var runner  # YarnRunner，由 main 设置

func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/data/quests.json"))
	for k in d:
		if not k.begins_with("_"): table[k] = d[k]

func _rec(id) -> Dictionary: return GS.S.quests.get(str(id), {})
func state(id) -> String:
	var r := _rec(id)
	return r.get("state", "none")
func is_active(id) -> bool: return state(id) == "active"
func title(id) -> String: return tr(table[str(id)].name)
func is_main(id) -> bool: return table[str(id)].type == "main"

func start(id) -> void:
	var k := str(id)
	if state(k) != "none": return
	GS.S.quests[k] = {"state": "active", "part": int(table[k].parts[0].id), "ending": "", "kills": 0}
	check_auto()
	changed.emit()

func progress(id, part: int) -> void:
	var r := _rec(id)
	if r.is_empty() or r.state != "active": return
	if part > int(r.part):
		r.part = part
		r.kills = 0
	check_auto()
	changed.emit()

func complete(id, ending := "") -> void:
	var r := _rec(id)
	if r.is_empty() or r.state != "active": return
	r.state = "done"
	r.ending = ending
	changed.emit()

func part_def(id) -> Dictionary:
	var r := _rec(id)
	for p in table[str(id)].parts:
		if int(p.id) == int(r.get("part", 0)): return p
	return {}

func objective(id) -> String:
	var p := part_def(id)
	if p.is_empty(): return ""
	var t := tr(p.text)
	return runner.interpolate(t) if runner else t

func target(id):
	var p := part_def(id)
	if p.has("target"): return Vector2i(int(p.target[0]), int(p.target[1]))
	return null

func ending_text(id) -> String:
	var r := _rec(id)
	for e in table[str(id)].get("endings", []):
		if e.id == r.get("ending", ""): return tr(e.text)
	return ""

## 进行中的任务，主线在前
func active() -> Array:
	var a := []
	for k in table:
		if is_active(k): a.append(k)
	a.sort_custom(func(x, y): return (1 if is_main(x) else 0) > (1 if is_main(y) else 0) or (is_main(x) == is_main(y) and int(x) < int(y)))
	return a

func done() -> Array:
	var a := []
	for k in table:
		if state(k) == "done": a.append(k)
	return a

func _next_part(id) -> void:
	var parts: Array = table[str(id)].parts
	var r := _rec(id)
	for i in parts.size():
		if int(parts[i].id) == int(r.part) and i + 1 < parts.size():
			r.part = int(parts[i + 1].id)
			r.kills = 0
			return

## 打败敌人时调用：满足 kill 条件就进入下一步
func on_kill(enemy: String) -> void:
	for k in active():
		var p := part_def(k)
		if p.has("kill") and p.kill.enemy == enemy:
			var r := _rec(k)
			r.kills = int(r.get("kills", 0)) + 1
			if r.kills >= int(p.kill.count): _next_part(k)
	check_auto()
	changed.emit()

## 打赢一场遭遇时调用：当前步骤要打的就是这一场，就进入下一步
func on_battle_won(encounter: String) -> void:
	for k in active():
		var p := part_def(k)
		if p.get("battle", "") == encounter: _next_part(k)
	changed.emit()

## 本作没有物品，没有 collect 条件；留着这个入口给以后
func check_auto() -> void:
	pass
