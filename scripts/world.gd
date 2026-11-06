class_name World
extends Node2D
## 白盒大地图（第 8 步）：色块格子，地图从 content/data/maps.json 读，人从 npcs.json，敌人从 spawns.json，
## 水面从 overworld.json。规则照 design/systems/overworld.md：
## 方向键走格子；面对人或东西按确认才说话；敌人站在路上，碰到就开打；能看将来的水面剧情到了才发光；
## 走到出口换地方；走上触发格、条件为真就开始对话（走进阁楼梅林就开口）。

signal want_dialog(node: String)
signal want_battle(spawn: Dictionary)
signal want_bark(text: String, at: Vector2)
signal area_changed(area: String)
signal moved(cell: Vector2i)

const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}

var main  # main.gd：问它现在能不能走、跑表达式
var M: Dictionary          # maps.json
var area := ""
var A: Dictionary          # 当前地方
var rows: Array = []
var W := 0
var H := 0
var cs := 64               # 一格多少像素
var player_cell := Vector2i.ZERO
var facing := Vector2i(0, 1)
var moving := false
var touch_dir := Vector2i.ZERO
var cam: Camera2D
var player: Node2D
var _t := 0.0
var _last_trigger := Vector2i(-1, -1)
var hover_cell := Vector2i(-1, -1)   # 鼠标停在哪一格
var _walk_id := 0                    # 点地面走路：新的一下点击取消上一条路

func _ready() -> void:
	M = Data.t("maps")
	cs = int(M.get("cell_px", 64))
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	player = Node2D.new()
	player.z_index = 5
	player.draw.connect(_draw_player)
	add_child(player)

func load_area(id: String, cell: Vector2i) -> void:
	area = id
	A = M.areas[id]
	rows = A.rows
	H = rows.size()
	W = rows[0].length()
	player_cell = cell
	player.position = _px(cell)
	_last_trigger = cell   # 落脚的格子不算「走上去」
	moving = false
	GS.S.area = id
	GS.S.cell = [cell.x, cell.y]
	_update_cam()
	queue_redraw()
	player.queue_redraw()
	area_changed.emit(id)

func _px(c: Vector2i) -> Vector2:
	return Vector2(c.x * cs + cs / 2.0, c.y * cs + cs / 2.0)

func _update_cam() -> void:
	var view := get_viewport_rect().size
	var size := Vector2(W * cs, H * cs)
	var p := player.position
	var c := Vector2()
	c.x = size.x / 2.0 if size.x <= view.x else clampf(p.x, view.x / 2.0, size.x - view.x / 2.0)
	c.y = size.y / 2.0 if size.y <= view.y else clampf(p.y, view.y / 2.0, size.y - view.y / 2.0)
	# 下面留出对话框和触屏键的位置：地图比屏幕矮时往上提一点
	cam.position = c

# ---------------- 这一格是什么 ----------------
func tile(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H: return "#"
	return rows[c.y][c.x]

func tile_def(ch: String) -> Dictionary:
	return M.tiles.get(ch, {"color": "#ff00ff", "block": true})

func npcs_here() -> Array:
	var a := []
	for n in Data.t("npcs").get("npcs", []):
		if n.area == area and n.cell != null and main.cond(n.get("condition", "")):
			a.append(n)
	return a

func npc_at(c: Vector2i):
	for n in npcs_here():
		if Vector2i(int(n.cell[0]), int(n.cell[1])) == c: return n
	return null

func spawns_here() -> Array:
	var a := []
	for s in Data.t("spawns").get("spawns", []):
		if s.area == area and s.cell != null and not (s.id in GS.S.get("defeated", [])) and main.cond(s.get("condition", "")):
			a.append(s)
	return a

func spawn_at(c: Vector2i):
	for s in spawns_here():
		if Vector2i(int(s.cell[0]), int(s.cell[1])) == c: return s
	return null

func water_at(c: Vector2i):
	for w in Data.t("overworld").get("water_spots", []):
		if w.area == area and w.has("cell") and Vector2i(int(w.cell[0]), int(w.cell[1])) == c: return w
	return null

func water_glows(w: Dictionary) -> bool:
	for q in Quests.active():
		if Quests.is_main(q) and str(main.runner.quest_part(int(q))) == str(w.get("glows_at", "")):
			return true
	return false

func trigger_at(c: Vector2i):
	for t in A.get("triggers", []):
		if Vector2i(int(t.cell[0]), int(t.cell[1])) == c and main.cond(t.get("cond", "")): return t
	return null

func exit_at(c: Vector2i):
	for e in A.get("exits", []):
		if Vector2i(int(e.cell[0]), int(e.cell[1])) == c: return e
	return null

func blocked(c: Vector2i) -> bool:
	if tile_def(tile(c)).get("block", false): return true
	if npc_at(c) != null: return true
	if water_at(c) != null: return true
	return false

# ---------------- 走 ----------------
func _process(delta: float) -> void:
	_t += delta
	if _has_glow(): queue_redraw()
	player.queue_redraw()
	if moving or main == null or not main.can_move(): return
	var d := _held_dir()
	if d != Vector2i.ZERO:
		step(d)

func _has_glow() -> bool:
	if area == "": return false
	if hover_cell.x >= 0: return true
	for w in Data.t("overworld").get("water_spots", []):
		if w.area == area and water_glows(w): return true
	return not markers().is_empty()

func _held_dir() -> Vector2i:
	if touch_dir != Vector2i.ZERO: return touch_dir
	for k in ["up", "down", "left", "right"]:
		if Input.is_action_pressed("move_" + k): return DIRS[k]
	return Vector2i.ZERO

## 往一个方向走一格（被挡住时只转身）。返回 true 表示真的动了
func step(d: Vector2i) -> bool:
	facing = d
	var n := player_cell + d
	var sp = spawn_at(n)
	if sp != null:
		want_battle.emit(sp)
		return false
	if blocked(n):
		player.queue_redraw()
		return false
	moving = true
	player_cell = n
	var speed := float(Data.param("overworld", "move_speed_tiles", 4))
	var tw := create_tween()
	tw.tween_property(player, "position", _px(n), 1.0 / speed)
	tw.parallel().tween_method(func(_v): _update_cam(), 0.0, 1.0, 1.0 / speed)
	tw.finished.connect(func():
		moving = false
		_arrive(n))
	return true

## 屏幕上的一点是地图上的哪一格
func cell_at_screen(pos: Vector2) -> Vector2i:
	var wp := get_canvas_transform().affine_inverse() * pos
	return Vector2i(floori(wp.x / cs), floori(wp.y / cs))

## 能不能点：人、发光或不发光的水面、敌人，算「点了有事」
func clickable(c: Vector2i) -> bool:
	return npc_at(c) != null or water_at(c) != null or spawn_at(c) != null

## 鼠标或手指点了地图上的一格：空地就走过去；人和水面走到旁边再说话 / 看；敌人走到旁边就开打
func click_cell(c: Vector2i) -> void:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H: return
	_walk_id += 1
	var my := _walk_id
	var kind := ""
	if npc_at(c) != null or water_at(c) != null: kind = "talk"
	elif spawn_at(c) != null: kind = "fight"
	elif blocked(c): return
	var path := path_to(c, kind != "")
	for n in path:
		while moving: await get_tree().process_frame
		if my != _walk_id or not main.can_move(): return
		if not step(n - player_cell): return
	while moving: await get_tree().process_frame
	if my != _walk_id or not main.can_move() or kind == "": return
	var d := c - player_cell
	if absi(d.x) + absi(d.y) != 1: return
	if kind == "fight":
		step(d)
	else:
		facing = d
		player.queue_redraw()
		interact()

## 寻路：只走空地；出口、敌人、触发格只在它就是终点时才踩（触发格挡住唯一的路时也踩，比如阁楼门口）
func path_to(t: Vector2i, adjacent: bool) -> Array:
	var p := _bfs(t, adjacent, true)
	if p.is_empty() and not _at_goal(t, adjacent): p = _bfs(t, adjacent, false)
	return p

func _at_goal(t: Vector2i, adjacent: bool) -> bool:
	var d := t - player_cell
	return (absi(d.x) + absi(d.y) == 1) if adjacent else (d == Vector2i.ZERO)

func _bfs(t: Vector2i, adjacent: bool, avoid_triggers: bool) -> Array:
	var start := player_cell
	var avoid := {}
	for e in A.get("exits", []): avoid[Vector2i(int(e.cell[0]), int(e.cell[1]))] = true
	if avoid_triggers:
		for tr_ in A.get("triggers", []):
			if main.cond(tr_.get("cond", "")): avoid[Vector2i(int(tr_.cell[0]), int(tr_.cell[1]))] = true
	for s in spawns_here(): avoid[Vector2i(int(s.cell[0]), int(s.cell[1]))] = true
	var goal := {}
	if adjacent:
		for d in DIRS.values(): goal[t + d] = true
	else:
		goal[t] = true
	if goal.has(start): return []
	var prev := {start: start}
	var q := [start]
	var found = null
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if goal.has(c):
			found = c
			break
		for d in DIRS.values():
			var n: Vector2i = c + d
			if prev.has(n) or n.x < 0 or n.y < 0 or n.x >= W or n.y >= H or blocked(n): continue
			if avoid.has(n) and not goal.has(n): continue
			prev[n] = c
			q.append(n)
	if found == null: return []
	var path := []
	var c: Vector2i = found
	while c != start:
		path.push_front(c)
		c = prev[c]
	return path

## 测试和传送用：直接站到某一格
func place(c: Vector2i, face := Vector2i(0, 1)) -> void:
	player_cell = c
	facing = face
	player.position = _px(c)
	_last_trigger = c
	_update_cam()

func _arrive(c: Vector2i) -> void:
	GS.S.cell = [c.x, c.y]
	moved.emit(c)
	var e = exit_at(c)
	if e != null:
		load_area(e.to, Vector2i(int(e.at[0]), int(e.at[1])))
		return
	var t = trigger_at(c)
	if t != null and c != _last_trigger:
		_last_trigger = c
		want_dialog.emit(t.node)
		return
	if t == null: _last_trigger = Vector2i(-1, -1)

## 面对的那一格按确认
func interact() -> void:
	var c := player_cell + facing
	var n = npc_at(c)
	if n != null:
		if n.get("node", "") != "":
			want_dialog.emit(n.node)
		else:
			var barks: Array = n.get("barks", [])
			if not barks.is_empty():
				var i := int(GS.S.vars.get("_bark_" + n.id, 0))
				GS.S.vars["_bark_" + n.id] = i + 1
				want_bark.emit(UIKit.t(barks[i % barks.size()]), _px(c))
		return
	var w = water_at(c)
	if w != null:
		if water_glows(w) and w.has("node"):
			want_dialog.emit(w.node)
		else:
			want_bark.emit(str(Data.param("prophecy", "idle_water_text", "")), _px(c))
		return

# ---------------- 任务标记：下一步该去的格子 ----------------
func markers() -> Array:
	var out := []
	if area == "": return out
	var q := ""
	for k in Quests.active():
		if Quests.is_main(k):
			q = k
			break
	if q == "": return out
	var p := Quests.part_def(q)
	var target_area: String = p.get("area", "")
	if target_area != "" and target_area != area:
		var ex = _exit_towards(target_area)
		if ex != null: out.append(Vector2i(int(ex.cell[0]), int(ex.cell[1])))
		return out
	for s in spawns_here(): out.append(Vector2i(int(s.cell[0]), int(s.cell[1])))
	for t in A.get("triggers", []):
		if main.cond(t.get("cond", "")): out.append(Vector2i(int(t.cell[0]), int(t.cell[1])))
	for w in Data.t("overworld").get("water_spots", []):
		if w.area == area and water_glows(w): out.append(Vector2i(int(w.cell[0]), int(w.cell[1])))
	return out

## 从这里去 target 先走哪个出口（按地方之间的连通找最短的）
func _exit_towards(target: String):
	var first := {}
	var seen := {area: true}
	var frontier := [area]
	while not frontier.is_empty():
		var nxt := []
		for a in frontier:
			for e in M.areas[a].get("exits", []):
				if seen.has(e.to): continue
				seen[e.to] = true
				first[e.to] = first.get(a, e)
				if e.to == target: return first[e.to]
				nxt.append(e.to)
		frontier = nxt
	return null

## 从站的地方走得到的格子（测试用：地图有没有把人、出口、敌人围死）
func reachable_from(c: Vector2i) -> Dictionary:
	var seen := {c: true}
	var q := [c]
	while not q.is_empty():
		var x: Vector2i = q.pop_back()
		for d in DIRS.values():
			var n: Vector2i = x + d
			if not seen.has(n) and n.x >= 0 and n.y >= 0 and n.x < W and n.y < H and not blocked(n):
				seen[n] = true
				q.append(n)
	return seen

# ---------------- 画 ----------------
func _draw() -> void:
	if rows.is_empty(): return
	for y in H:
		for x in W:
			var ch: String = rows[y][x]
			var col := UIKit.hexcol(tile_def(ch).get("color", "#ff00ff"))
			draw_rect(Rect2(x * cs, y * cs, cs, cs), col)
			draw_rect(Rect2(x * cs, y * cs, cs, cs), Color(0, 0, 0, 0.06), false, 1.0)
	# 出口：门口画一道金色的横杠
	for e in A.get("exits", []):
		var r := Rect2(int(e.cell[0]) * cs + 8, int(e.cell[1]) * cs + cs / 2.0 - 4, cs - 16, 8)
		draw_rect(r, Color(UIKit.GOLD, 0.7))
	# 水面
	for w in Data.t("overworld").get("water_spots", []):
		if w.area != area or not w.has("cell"): continue
		var c := _px(Vector2i(int(w.cell[0]), int(w.cell[1])))
		draw_circle(c, cs * 0.34, Color("#5C7C96"))
		if water_glows(w):
			var a := 0.55 + 0.35 * sin(_t * 2.4)
			draw_circle(c, cs * 0.30, Color(1.0, 0.96, 0.82, a))
			for i in 3:
				var rr := cs * (0.36 + fmod(_t * 0.25 + i / 3.0, 1.0) * 0.5)
				draw_arc(c, rr, 0, TAU, 32, Color(UIKit.DROP, 0.6 * (1.0 - fmod(_t * 0.25 + i / 3.0, 1.0))), 2.0)
	# 敌人：脚下暗红的圈 + 头顶交叉的两把剑和名字（overworld.md：看得见是什么、几个）
	for s in spawns_here():
		var c := _px(Vector2i(int(s.cell[0]), int(s.cell[1])))
		draw_arc(c + Vector2(0, 14), cs * 0.44, 0, TAU, 32, UIKit.DANGER, 4.0)
		var n: int = Data.encounter(s.enemy).get("enemies", []).size()
		for i in n:
			var ox := (i - (n - 1) / 2.0) * 16.0
			draw_rect(Rect2(c.x + ox - 7, c.y - 4, 14, 20), Color("#55575F"))
			draw_rect(Rect2(c.x + ox - 7, c.y - 8, 14, 6), Color("#6C6E77"))
		_crossed_swords(c + Vector2(0, -cs * 0.62))
		var nm := UIKit.t(Data.encounter(s.enemy).get("name", s.enemy))
		_name_tag(nm, c + Vector2(0, -cs * 0.95), UIKit.DANGER)
	# 人
	for n in npcs_here():
		var c := _px(Vector2i(int(n.cell[0]), int(n.cell[1])))
		var look: Dictionary = M.actors.get(n.get("look", ""), {})
		_figure(c, UIKit.hexcol(look.get("color", "")), look.get("hood", false), Vector2i(0, 1))
		var nm := UIKit.t(n.name) if n.get("name", "") != "" else ""
		if nm != "" and nm != n.name:
			_name_tag(nm, c + Vector2(0, -cs * 0.72), UIKit.CREAM)
		if n.get("node", "") != "" and not main.runner.visited(n.node):
			_bubble(c + Vector2(cs * 0.34, -cs * 0.5))
	if hover_cell.x >= 0 and main != null and main.mode == "map":
		var hr := Rect2(hover_cell.x * cs, hover_cell.y * cs, cs, cs)
		if clickable(hover_cell):
			draw_rect(hr.grow(-2), UIKit.GOLD, false, 4.0)
		elif not blocked(hover_cell):
			draw_rect(hr.grow(-4), Color(1, 1, 1, 0.35), false, 2.0)
	# 任务标记：金色的倒三角，上下浮动
	for m in markers():
		var c := _px(m) + Vector2(0, -cs * 0.9 + sin(_t * 4.0) * 5.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -10), c + Vector2(12, -10), c + Vector2(0, 8)]), UIKit.GOLD)
		draw_polyline(PackedVector2Array([c + Vector2(-12, -10), c + Vector2(12, -10), c + Vector2(0, 8), c + Vector2(-12, -10)]), UIKit.INK, 2.0)

func _draw_player() -> void:
	var look: Dictionary = M.actors.get("apprentice", {})
	_figure_on(player, Vector2.ZERO, UIKit.hexcol(look.get("color", "")), false, facing)

func _figure(c: Vector2, col: Color, hood: bool, face: Vector2i) -> void:
	_figure_on(self, c, col, hood, face)

## 占位人形：身子是衣色，头是肤色；兜帽的人头上一圈灰；脚下一小块阴影；朝向画一个金色小点
static func _figure_on(ci: CanvasItem, c: Vector2, col: Color, hood: bool, face: Vector2i) -> void:
	ci.draw_rect(Rect2(c.x - 16, c.y + 20, 32, 6), Color(0, 0, 0, 0.25))
	ci.draw_rect(Rect2(c.x - 14, c.y - 6, 28, 28), UIKit.INK)
	ci.draw_rect(Rect2(c.x - 12, c.y - 4, 24, 24), col)
	ci.draw_rect(Rect2(c.x - 11, c.y - 24, 22, 20), UIKit.INK)
	ci.draw_rect(Rect2(c.x - 9, c.y - 22, 18, 16), Color("#E8C4A0"))
	if hood:
		ci.draw_rect(Rect2(c.x - 11, c.y - 26, 22, 8), col.darkened(0.2))
		ci.draw_rect(Rect2(c.x - 11, c.y - 22, 4, 14), col.darkened(0.2))
		ci.draw_rect(Rect2(c.x + 7, c.y - 22, 4, 14), col.darkened(0.2))
	var f := c + Vector2(face.x * 20, face.y * 20 - 4)
	ci.draw_rect(Rect2(f.x - 3, f.y - 3, 6, 6), UIKit.GOLD)

func _name_tag(t: String, at: Vector2, col: Color) -> void:
	var font := UIKit.font()
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2).x
	var r := Rect2(at.x - w / 2.0 - 6, at.y - 22, w + 12, 28)
	draw_rect(r, Color(UIKit.INK, 0.75))
	draw_string(font, Vector2(at.x - w / 2.0, at.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2, col)

func _bubble(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 14, at.y - 14, 28, 20), UIKit.INK)
	draw_rect(Rect2(at.x - 12, at.y - 12, 24, 16), Color.WHITE)
	for i in 3:
		draw_rect(Rect2(at.x - 8 + i * 6, at.y - 5, 3, 3), UIKit.INK)

func _crossed_swords(c: Vector2) -> void:
	for s in [-1, 1]:
		draw_line(c + Vector2(-10 * s, -10), c + Vector2(10 * s, 10), UIKit.INK, 6.0)
		draw_line(c + Vector2(-10 * s, -10), c + Vector2(10 * s, 10), Color("#D8D8E0"), 3.0)
		draw_line(c + Vector2(6 * s, 2) , c + Vector2(2 * s, 6), UIKit.GOLD, 4.0)
