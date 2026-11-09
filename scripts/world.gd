class_name World
extends Node2D
## 白盒大地图（第 8 步）：色块格子，地图从 content/data/maps.json 读，人从 npcs.json，敌人从 spawns.json，
## 水面、圣龛、宝物从 overworld.json。规则照 design/systems/overworld.md：
## 方向键走格子；面对人或东西按确认才说话、祈祷、开宝物；能看将来的水面剧情到了才发光；
## 走到出口换地方；走上触发格、条件为真就开始对话（走进阁楼梅林就开口）。
## 敌人两种：任务敌人（spawns.json 的 spawns，站着不动，碰到就开打）；能绕开的敌人（spawns.json 的 zones，「明雷」）：
## 你走一格它们按数据顺序各走一格，4 格内（绕墙的走路步数）六成多的可能朝你追，不追时在出生格附近转，
## 永远不出自己那块 rect；上下左右挨着就开打；打赢的记进 GS.S.defeated，不再回来。
## 规则照插件 mechanics-library 的 overworld-grid（顺序移动、玩家和敌人走完都查碰撞、不隔墙追、不出框、打败的不回来、宽限步数）。
##
## spawns.json zones 的格式：{"area", "rect": [x1, y1, x2, y2]（含两端）, "groups": [{"enemy": 遭遇 id, "count", "cell": 出生格}]}；
## count > 1 时每只的出生格写 "cells": [[x, y], …]。群的 id 是「zone 名#序号」（forest_east#0），序号按 groups 展开后数。

signal want_dialog(node: String)
## 碰上敌人。任务敌人发 spawns.json 里那条记录；能绕开的敌人发 {id, enemy, cell, kind: "zone", area}（和 groups_here() 一样）
signal want_battle(spawn: Dictionary)
signal want_bark(text: String, at: Vector2)
## 面对圣龛按确认：发 overworld.json 里那座圣龛的记录
signal want_shrine(shrine: Dictionary)
## 面对没开过的宝物按确认：发 overworld.json 里那处宝物的记录（开过的冒 bark_chest_empty）
signal want_chest(chest: Dictionary)
signal area_changed(area: String)
signal moved(cell: Vector2i)

const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}
const DIR4: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]   # 找路、游荡的固定顺序
const NONE := Vector2i(-99999, -99999)
const TAG_RANGE := 5       # 能绕开的敌人：玩家几格以内才显示名字牌

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
## 这片地方还活着的能绕开的敌人群，顺序 = 数据顺序 = 行动顺序。
## 每个：{id, enemy, zone, rect: Rect2i, home: Vector2i（出生格）, cell: Vector2i, px: Vector2（画在哪）, stun, alert, mode}
var groups: Array = []
var steps := 0             # 走了多少步：随机数种子的一部分，存在 GS.S.world_steps
var grace_left := 0        # 还有几步敌人不追（逃跑 / 输了回圣龛以后）
var _redraw_sig := ""      # 开过的宝物、祈祷过的圣龛、打败记录变了就重画

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
	_set_area(id)
	_walk_id += 1          # 换了地方，上一条点出来的路作废
	player_cell = cell
	player.position = _px(cell)
	_last_trigger = cell   # 落脚的格子不算「走上去」
	moving = false
	GS.S.area = id
	GS.S.cell = [cell.x, cell.y]
	steps = int(GS.S.get("world_steps", 0))
	_build_groups()
	_update_cam()
	queue_redraw()
	player.queue_redraw()
	area_changed.emit(id)

func _set_area(id: String) -> void:
	area = id
	A = M.areas[id]
	rows = A.rows
	H = rows.size()
	W = rows[0].length()

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

func _p(key: String, default):
	return Data.param("overworld", key, default)

func _cond(expr) -> bool:
	if expr == null or str(expr) == "": return true
	return main == null or main.cond(str(expr))

func _can_move() -> bool:
	return main != null and main.can_move()

static func _v(c) -> Vector2i:
	return c if c is Vector2i else Vector2i(int(c[0]), int(c[1]))

static func _dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

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

## 这片地方还活着的能绕开的敌人群：[{id, enemy（遭遇 id）, cell: Vector2i, kind: "zone", area}]
func groups_here() -> Array:
	var a := []
	for g in groups: a.append(_group_info(g))
	return a

func _group_info(g: Dictionary) -> Dictionary:
	return {"id": g.id, "enemy": g.enemy, "cell": g.cell, "kind": "zone", "area": area}

func group_at(c: Vector2i):
	for g in groups:
		if g.cell == c: return g
	return null

func _group_by_id(id: String):
	for g in groups:
		if g.id == id: return g
	return null

func shrines_here() -> Array:
	var a := []
	for s in Data.t("overworld").get("shrines", []):
		if s.get("area", "") == area and s.get("cell") != null and _cond(s.get("condition", "")): a.append(s)
	return a

func shrine_at(c: Vector2i):
	for s in shrines_here():
		if _v(s.cell) == c: return s
	return null

func chests_here() -> Array:
	var a := []
	for s in Data.t("overworld").get("chests", []):
		if s.get("area", "") == area and s.get("cell") != null and _cond(s.get("condition", "")): a.append(s)
	return a

func chest_at(c: Vector2i):
	for s in chests_here():
		if _v(s.cell) == c: return s
	return null

func chest_opened(ch: Dictionary) -> bool:
	return ch.get("id", "") in GS.S.get("chests", [])

func shrine_prayed(sh: Dictionary) -> bool:
	return sh.get("id", "") in GS.S.get("prayed", [])

func water_at(c: Vector2i):
	for w in Data.t("overworld").get("water_spots", []):
		if w.area == area and w.has("cell") and Vector2i(int(w.cell[0]), int(w.cell[1])) == c: return w
	return null

func water_glows(w: Dictionary) -> bool:
	if main == null or main.runner == null: return false
	for q in Quests.active():
		if Quests.is_main(q) and str(main.runner.quest_part(int(q))) == str(w.get("glows_at", "")):
			return true
	return false

func trigger_at(c: Vector2i):
	for t in A.get("triggers", []):
		if Vector2i(int(t.cell[0]), int(t.cell[1])) == c and main.cond(t.get("cond", "")): return t
	return null

## 这格有没有触发格（不管条件真不真）：敌人不进
func _trigger_cell(c: Vector2i) -> bool:
	for t in A.get("triggers", []):
		if Vector2i(int(t.cell[0]), int(t.cell[1])) == c: return true
	return false

func exit_at(c: Vector2i):
	for e in A.get("exits", []):
		if Vector2i(int(e.cell[0]), int(e.cell[1])) == c: return e
	return null

## 玩家走不进的格子：墙、人、水面、圣龛、宝物（敌人另算：撞上去就开打）
func blocked(c: Vector2i) -> bool:
	if tile_def(tile(c)).get("block", false): return true
	if npc_at(c) != null: return true
	if water_at(c) != null: return true
	if shrine_at(c) != null: return true
	if chest_at(c) != null: return true
	return false

# ---------------- 走 ----------------
func _process(delta: float) -> void:
	_t += delta
	var sig := "%d/%d/%d" % [GS.S.get("chests", []).size(), GS.S.get("prayed", []).size(), GS.S.get("defeated", []).size()]
	if sig != _redraw_sig:
		_redraw_sig = sig
		queue_redraw()
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
	for s in shrines_here():
		if shrine_prayed(s): return true
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
	var g = group_at(n)
	if g != null:
		player.queue_redraw()
		_fight(g)
		return false
	if blocked(n):
		player.queue_redraw()
		return false
	moving = true
	player_cell = n
	var speed := float(_p("move_speed_tiles", 4))
	var tw := create_tween()
	tw.tween_property(player, "position", _px(n), 1.0 / speed)
	tw.parallel().tween_method(func(_x): _update_cam(), 0.0, 1.0, 1.0 / speed)
	tw.finished.connect(func():
		moving = false
		_arrive(n))
	return true

## 屏幕上的一点是地图上的哪一格
func cell_at_screen(pos: Vector2) -> Vector2i:
	var wp := get_canvas_transform().affine_inverse() * pos
	return Vector2i(floori(wp.x / cs), floori(wp.y / cs))

## 能不能点：人、发光或不发光的水面、敌人、圣龛、宝物，算「点了有事」
func clickable(c: Vector2i) -> bool:
	return npc_at(c) != null or water_at(c) != null or spawn_at(c) != null or group_at(c) != null \
		or shrine_at(c) != null or chest_at(c) != null

## 鼠标或手指点了地图上的一格：空地就走过去；人、水面、圣龛、宝物走到旁边再按确认；敌人走到旁边就开打。
## 能绕开的敌人每步都会动，所以每走一格重新找一次路；点的是会走的敌人，就一路跟着它现在的格子走。
func click_cell(c: Vector2i) -> void:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H: return
	_walk_id += 1
	var my := _walk_id
	var kind := ""
	var foe_id := ""
	if npc_at(c) != null or water_at(c) != null or shrine_at(c) != null or chest_at(c) != null: kind = "talk"
	elif spawn_at(c) != null: kind = "fight"
	elif group_at(c) != null:
		kind = "fight"
		foe_id = group_at(c).id
	elif blocked(c): return
	var guard := W * H
	while guard > 0:
		guard -= 1
		while moving: await get_tree().process_frame
		if my != _walk_id or not _can_move(): return
		var t := c
		if foe_id != "":
			var fg = _group_by_id(foe_id)
			if fg == null: return
			t = fg.cell
		if _at_goal(t, kind != ""): break
		var path := path_to(t, kind != "")
		if path.is_empty(): return
		if not step(path[0] - player_cell): return
	while moving: await get_tree().process_frame
	if my != _walk_id or not _can_move() or kind == "": return
	if foe_id != "":
		var fg = _group_by_id(foe_id)
		if fg == null: return
		c = fg.cell
	var d := c - player_cell
	if absi(d.x) + absi(d.y) != 1: return
	if kind == "fight":
		step(d)
	else:
		facing = d
		player.queue_redraw()
		interact()

## 寻路：只走空地；出口、敌人（站着的和会走的）、触发格只在它就是终点时才踩（触发格挡住唯一的路时也踩，比如阁楼门口）
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
	for g in groups: avoid[g.cell] = true
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
		want_dialog.emit(t.node)   # 先演剧情：这一步敌人都不动
		return
	if t == null: _last_trigger = Vector2i(-1, -1)
	_enemy_phase()

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
	var sh = shrine_at(c)
	if sh != null:
		want_shrine.emit(sh)
		return
	var ch = chest_at(c)
	if ch != null:
		if chest_opened(ch):
			want_bark.emit(UIKit.t("bark_chest_empty"), _px(c))
		else:
			want_chest.emit(ch)
		return

# ---------------- 能绕开的敌人（明雷） ----------------
## 进一片地方时按 spawns.json 的 zones 放敌人：打败过的跳过；GS.S.roamers 里记着位置、那格还能站就站回去，否则回出生格；
## 都站不下就在 rect 里从出生格往外找一格。不放在玩家身上和旁边。
func _build_groups() -> void:
	groups = []
	var dead: Array = GS.S.get("defeated", [])
	var saved := _roamers()
	var zones: Dictionary = Data.t("spawns").get("zones", {})
	for zid in zones:
		var z = zones[zid]
		if typeof(z) != TYPE_DICTIONARY or z.get("area", "") != area: continue
		if not _cond(z.get("condition", "")): continue
		var rect := _zone_rect(z)
		if rect.size.x <= 0 or rect.size.y <= 0: continue
		var k := 0
		for grp in z.get("groups", []):
			for j in maxi(int(grp.get("count", 1)), 1):
				var id := "%s#%d" % [zid, k]
				k += 1
				if id in dead: continue
				var home := _group_home(grp, j, rect)
				var g := {"id": id, "enemy": str(grp.get("enemy", "")), "zone": str(zid), "rect": rect, "home": home,
					"cell": NONE, "stun": 0, "alert": false, "mode": "stay"}
				var was := NONE
				var sv = saved.get(id)
				if sv is Array and sv.size() >= 2: was = Vector2i(int(sv[0]), int(sv[1]))
				g.cell = _free_spot(g, [was, home])
				if g.cell == NONE: continue
				g["px"] = _px(g.cell)
				groups.append(g)
				saved[id] = [g.cell.x, g.cell.y]

func _roamers() -> Dictionary:
	if typeof(GS.S.get("roamers")) != TYPE_DICTIONARY: GS.S["roamers"] = {}
	return GS.S.roamers

## rect 写成 [x1, y1, x2, y2]，两端都算
static func _zone_rect(z: Dictionary) -> Rect2i:
	var r = z.get("rect")
	if not (r is Array) or r.size() < 4: return Rect2i()
	return Rect2i(int(r[0]), int(r[1]), int(r[2]) - int(r[0]) + 1, int(r[3]) - int(r[1]) + 1)

static func _group_home(grp: Dictionary, j: int, rect: Rect2i) -> Vector2i:
	var lst = grp.get("cells", [])
	if lst is Array and j < lst.size() and lst[j] != null: return _v(lst[j])
	if j == 0 and grp.get("cell") != null: return _v(grp.cell)
	return rect.position + rect.size / 2

func _free_spot(g: Dictionary, cands: Array) -> Vector2i:
	for c in cands:
		if c != NONE and _spot_ok(g, c): return c
	var home: Vector2i = g.home
	var r: Rect2i = g.rect
	for rad in range(1, r.size.x + r.size.y + 1):
		for dy in range(-rad, rad + 1):
			var dx := rad - absi(dy)
			for c in [Vector2i(home.x - dx, home.y + dy), Vector2i(home.x + dx, home.y + dy)]:
				if _spot_ok(g, c): return c
	return NONE

func _spot_ok(g: Dictionary, c: Vector2i) -> bool:
	return g.rect.has_point(c) and _enemy_can_enter(c, g) and _dist(c, player_cell) > 1

## 敌人能进的格：不是墙、人（含玩家）、水面、出口、触发格、圣龛、宝物、任务敌人、别的群，也不是圣龛跟前一格
func _enemy_can_enter(c: Vector2i, g = null) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H: return false
	if c == player_cell: return false
	if blocked(c): return false
	if exit_at(c) != null or _trigger_cell(c): return false
	if spawn_at(c) != null: return false
	var o = group_at(c)
	if o != null and (g == null or o.id != g.id): return false
	for s in shrines_here():
		if _dist(_v(s.cell), c) == 1: return false
	return true

## 玩家走完一格以后：先查玩家是不是走到了敌人旁边，再让每群按数据顺序走一步、走完各查一次。
## 剧情、对话、战斗进行中（main.can_move() 为假）敌人都不动，也不再发 want_battle。
func _enemy_phase() -> void:
	steps += 1
	GS.S["world_steps"] = steps
	var can_chase := grace_left <= 0
	if grace_left > 0: grace_left -= 1
	queue_redraw()
	if groups.is_empty() or not _can_move(): return
	for g in groups:
		if _touching(g):
			_fight(g)
			return
	if steps % maxi(int(_p("enemy_move_every", 1)), 1) != 0: return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(GS.S.get("seed", 0)) + area.hash() + steps
	for g in groups:
		_group_turn(g, rng, can_chase)
		if _touching(g):
			_fight(g)
			return

## 一群走一步：玩家在 chase_radius 步以内（绕墙的走路步数）、第一步还在自己的 rect 里，掷一次 chase_chance 朝玩家走；
## 不追时在出生格 wander_radius 以内随机走一步或不动（被拉远了只许往回走）。走完立刻更新占位，后面的群看到的是新位置。
func _group_turn(g: Dictionary, rng: RandomNumberGenerator, can_chase: bool) -> void:
	g.mode = "stay"
	if int(g.stun) > 0:
		g.stun = int(g.stun) - 1
		return
	var next := NONE
	var alert := false
	var radius := int(_p("chase_radius", 4))
	if can_chase and radius > 0:
		var path := _enemy_path(g, player_cell, radius)
		if not path.is_empty() and g.rect.has_point(path[0]):
			alert = true
			if rng.randf() < float(_p("chase_chance", 0.65)):
				next = path[0]
	_set_alert(g, alert)
	var mode := "chase"
	if next == NONE:
		mode = "wander"
		if str(_p("idle", "wander")) != "wander": return
		var k := rng.randi_range(0, 4)
		if k == 4: return
		next = g.cell + DIR4[k]
		var dn := _dist(next, g.home)
		if dn > int(_p("wander_radius", 3)) and dn >= _dist(g.cell, g.home): return
	if not g.rect.has_point(next): return
	var onto_player: bool = next == player_cell
	if onto_player and str(_p("contact", "adjacent")) != "same": return
	if not onto_player and not _enemy_can_enter(next, g): return
	if not can_chase and _dist(next, player_cell) <= 1: return   # 宽限期里不贴上来
	_move_group(g, next)
	g.mode = mode

## 敌人找路：广度优先，最多 max_len 步，只走敌人能进的格（所以不穿墙、不踩别的群），终点本身可以踩。返回不含起点的路
func _enemy_path(g: Dictionary, goal: Vector2i, max_len: int) -> Array:
	var from: Vector2i = g.cell
	var prev := {from: from}
	var depth := {from: 0}
	var q: Array[Vector2i] = [from]
	var head := 0
	var found := false
	while head < q.size():
		var c := q[head]
		head += 1
		if c == goal:
			found = true
			break
		if int(depth[c]) >= max_len: continue
		for d in DIR4:
			var n := c + d
			if prev.has(n) or (n != goal and not _enemy_can_enter(n, g)): continue
			prev[n] = c
			depth[n] = int(depth[c]) + 1
			q.append(n)
	var out := []
	if not found: return out
	var back := goal
	while back != from:
		out.push_front(back)
		back = prev[back]
	return out

func _move_group(g: Dictionary, to: Vector2i) -> void:
	var from: Vector2i = g.cell
	g.cell = to
	_roamers()[g.id] = [to.x, to.y]
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_method(_set_group_px.bind(g), _px(from), _px(to), 1.0 / float(_p("move_speed_tiles", 4)))
	else:
		g.px = _px(to)

func _set_group_px(v: Vector2, g: Dictionary) -> void:
	g.px = v
	queue_redraw()

func _touching(g: Dictionary) -> bool:
	if int(g.get("stun", 0)) > 0: return false
	var dx := absi(g.cell.x - player_cell.x)
	var dy := absi(g.cell.y - player_cell.y)
	if str(_p("contact", "adjacent")) == "same": return dx == 0 and dy == 0
	if bool(_p("contact_diagonal", false)): return maxi(dx, dy) <= 1
	return dx + dy <= 1

func _fight(g: Dictionary) -> bool:
	if not _can_move(): return false
	print("  [敌人] 碰上：%s" % _group_label(g))
	want_battle.emit(_group_info(g))
	return true

func _set_alert(g: Dictionary, a: bool) -> void:
	if bool(g.alert) == a: return
	g.alert = a
	print("  [敌人] %s %s" % [_group_label(g), "开始追" if a else "不追了"])

## 「林子边的狼 ×2」：给测试打印用
func _group_label(g: Dictionary) -> String:
	var e := Data.encounter(g.enemy)
	return "%s ×%d" % [UIKit.t(e.get("name", g.enemy)), e.get("enemies", []).size()]

## 打赢了这群（main 调）：记进 GS.S.defeated，从地图上拿掉，再进这片地方、读档都不回来。
## 别的群这时还贴着你：原地停 flee_grace_steps 步，不会马上又开打（overworld.md 边界情况）
func remove_group(id: String) -> void:
	if typeof(GS.S.get("defeated")) != TYPE_ARRAY: GS.S["defeated"] = []
	if not (id in GS.S.defeated): GS.S.defeated.append(id)
	_roamers().erase(id)
	for i in range(groups.size() - 1, -1, -1):
		if groups[i].id == id:
			print("  [敌人] %s 已移除" % _group_label(groups[i]))
			groups.remove_at(i)
	for g in groups:
		if _touching(g): g.stun = int(_p("flee_grace_steps", 3))
	queue_redraw()

## 逃跑 / 输了回圣龛以后（main 调）：接下来 n 步里所有敌人不追，也不主动贴到你旁边；你自己撞上去照样开打
func grace(n: int = -1) -> void:
	if n < 0: n = int(_p("flee_grace_steps", 3))
	grace_left = maxi(n, 0)
	for g in groups: _set_alert(g, false)

# ---------------- 圣龛 ----------------
## 圣龛旁边一格能站的格子（先下、左、右、上；四面都不行就往外找最近的空格）。圣龛不在当前地方时按那片地方的地图算
func shrine_cell_near(shrine: Dictionary) -> Vector2i:
	if shrine.get("cell") == null: return player_cell
	var sa := str(shrine.get("area", area))
	var keep := []
	if sa != area and M.areas.has(sa):
		keep = [area, A, rows, W, H, groups]
		_set_area(sa)
		groups = []
	var out := _stand_near(_v(shrine.cell))
	if not keep.is_empty():
		area = keep[0]
		A = keep[1]
		rows = keep[2]
		W = keep[3]
		H = keep[4]
		groups = keep[5]
	return out

func _stand_near(sc: Vector2i) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		if _can_stand(sc + d): return sc + d
	var seen := {sc: true}
	var q := [sc]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in DIR4:
			var n: Vector2i = c + d
			if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= W or n.y >= H: continue
			seen[n] = true
			if _can_stand(n): return n
			if not tile_def(tile(n)).get("block", false): q.append(n)
	return sc

func _can_stand(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H: return false
	if blocked(c) or exit_at(c) != null or _trigger_cell(c): return false
	return spawn_at(c) == null and group_at(c) == null

## 换到圣龛那片地方（load_area），站到圣龛旁边、面朝圣龛。宽限步数由 main 另调 grace()
func go_to_shrine(shrine: Dictionary) -> void:
	if shrine.get("cell") == null: return
	var sa := str(shrine.get("area", area))
	if not M.areas.has(sa): return
	var sc := _v(shrine.cell)
	var near := shrine_cell_near(shrine)
	load_area(sa, near)
	facing = sc - near if _dist(sc, near) == 1 else Vector2i(0, -1)
	player.queue_redraw()

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
	# 圣龛：灰色石龛 + 顶上小十字；祈祷过的底下一圈淡金光
	for s in shrines_here():
		_draw_shrine(_px(_v(s.cell)), shrine_prayed(s))
	# 宝物：棕色小包袱；开过的是一块扁的空布
	for s in chests_here():
		_draw_chest(_px(_v(s.cell)), chest_opened(s))
	# 任务敌人：脚下暗红的圈 + 头顶交叉的两把剑和名字（overworld.md：看得见是什么、几个），站着不动
	for s in spawns_here():
		_draw_foe(_px(Vector2i(int(s.cell[0]), int(s.cell[1]))), s.enemy, true)
	# 能绕开的敌人：同样的画法，名字牌只在玩家 TAG_RANGE 格以内显示
	for g in groups:
		_draw_foe(g.get("px", _px(g.cell)), g.enemy, _dist(g.cell, player_cell) <= TAG_RANGE)
	# 人
	for n in npcs_here():
		var c := _px(Vector2i(int(n.cell[0]), int(n.cell[1])))
		var look: Dictionary = M.actors.get(n.get("look", ""), {})
		_figure(c, UIKit.hexcol(look.get("color", "")), look.get("hood", false), Vector2i(0, 1))
		var nm := UIKit.t(n.name) if n.get("name", "") != "" else ""
		if nm != "" and nm != n.name:
			_name_tag(nm, c + Vector2(0, -cs * 0.72), UIKit.CREAM)
		if n.get("node", "") != "" and main.runner != null and not main.runner.visited(n.node):
			_bubble(c + Vector2(cs * 0.34, -cs * 0.5))
	if hover_cell.x >= 0 and main != null and main.get("mode") == "map":
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

func _draw_foe(c: Vector2, enc_id: String, show_name: bool) -> void:
	draw_arc(c + Vector2(0, 14), cs * 0.44, 0, TAU, 32, UIKit.DANGER, 4.0)
	var e := Data.encounter(enc_id)
	var n: int = e.get("enemies", []).size()
	for i in n:
		var ox := (i - (n - 1) / 2.0) * 16.0
		draw_rect(Rect2(c.x + ox - 7, c.y - 4, 14, 20), Color("#55575F"))
		draw_rect(Rect2(c.x + ox - 7, c.y - 8, 14, 6), Color("#6C6E77"))
	_crossed_swords(c + Vector2(0, -cs * 0.62))
	if show_name:
		_name_tag(UIKit.t(e.get("name", enc_id)), c + Vector2(0, -cs * 0.95), UIKit.DANGER)

func _draw_shrine(c: Vector2, prayed: bool) -> void:
	if prayed:
		var a := 0.45 + 0.2 * sin(_t * 2.0)
		_ellipse(c + Vector2(0, 20), cs * 0.46, cs * 0.2, Color(UIKit.GOLD, 0.22))
		_ellipse_line(c + Vector2(0, 20), cs * 0.46, cs * 0.2, Color(UIKit.GOLD, a), 3.0)
	draw_rect(Rect2(c.x - 16, c.y + 20, 32, 6), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(c.x - 14, c.y - 12, 28, 34), UIKit.INK)
	draw_rect(Rect2(c.x - 12, c.y - 10, 24, 30), Color("#9A9CA4"))
	draw_rect(Rect2(c.x - 6, c.y - 4, 12, 14), Color("#5A5D68"))     # 龛里磨平了脸的像
	draw_rect(Rect2(c.x - 4, c.y - 28, 8, 18), UIKit.INK)
	draw_rect(Rect2(c.x - 9, c.y - 24, 18, 8), UIKit.INK)
	draw_rect(Rect2(c.x - 2, c.y - 26, 4, 16), Color("#C9CBD2"))
	draw_rect(Rect2(c.x - 7, c.y - 22, 14, 4), Color("#C9CBD2"))

func _draw_chest(c: Vector2, opened: bool) -> void:
	if opened:
		_ellipse(c + Vector2(0, 14), 20, 8, UIKit.INK)
		_ellipse(c + Vector2(0, 14), 18, 6, Color("#A08262"))
		return
	draw_rect(Rect2(c.x - 16, c.y + 18, 32, 6), Color(0, 0, 0, 0.25))
	draw_circle(c + Vector2(0, 6), 16, UIKit.INK)
	draw_circle(c + Vector2(0, 6), 14, Color("#8A5A32"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -14), c + Vector2(9, -14), c + Vector2(3, -6), c + Vector2(-3, -6)]), Color("#6E4526"))
	draw_rect(Rect2(c.x - 6, c.y - 8, 12, 4), UIKit.INK)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _ellipse_line(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w)

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
