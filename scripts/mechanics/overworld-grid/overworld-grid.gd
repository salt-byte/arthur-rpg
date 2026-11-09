extends RefCounted
## 格子大地图 + 明雷遇敌，照《吸血鬼的陨落 2》的大地图（敌人在地图上看得见、靠近会追、碰上开打、
## 逃跑回最近祈祷过的神龛）；追击概率、游荡、首领不动、神龛让敌人重生照 graveholme 实例。
## 玩家走一格，敌人按数据顺序各走一格；出口换地图；走到 NPC 旁边自动开口一次。纯逻辑，变化作为事件数组返回。

const DEFAULTS := {
	"contact": "adjacent",      # same：同一格才开打；adjacent：上下左右相邻就开打（原作判定未核实，本库选相邻）
	"contact_diagonal": false,  # adjacent 时斜角算不算碰上
	"chase_radius": 4,          # 走路步数（绕墙的路也算）在这之内才可能追；0 = 不追（graveholme 实例，未核实）
	"chase_chance": 0.65,       # 在追击范围内时，每回合追的概率；没追就按 idle 行动（graveholme 实例，未核实）
	"idle": "wander",           # 不追时做什么：wander 随机走 | patrol 沿路线 | stay 站着（graveholme 默认游荡）
	"enemy_move_every": 1,      # 玩家每走几步，敌人走一步
	"respawn": false,           # 重新进地图时，打败过的敌人回不回来；单个敌人可写 respawn 覆盖
	"talk": "adjacent",         # adjacent：走到 NPC 上下左右自动开口；facing：面朝 NPC 才开口
	"flee_to_shrine": true,     # 逃跑后传回最后一次祈祷的神龛（原作，Pocket Gamer 评测）；还没祈祷过就用愣住规则
	"flee_grace_steps": 3,      # 逃跑后这个敌人愣住几个敌人回合：不动、不触发（本库自定）
	"shrine_respawn": false,    # 开着时：在神龛祈祷后，打败过的非首领敌人下次进图时回来（graveholme 的做法）。原作打死就没了（用户玩过原作确认），默认关
	"wander_chance": 1.0,       # wander 敌人每回合挪动的概率
	"wander_radius": 3,         # 没写 zone 的敌人离出生点最远几格（曼哈顿）；写了 zone 就以 zone 为界
	"solid": "#T~",             # rows 里哪些字是墙
}

const DIR4: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const NONE := Vector2i(-99999, -99999)
const Walk = preload("grid_walk.gd")

var p: Dictionary = {}
var maps: Dictionary = {}
var rng: RandomNumberGenerator
var map_id := ""
var width := 0
var height := 0
var solid := PackedByteArray()
var player := Vector2i.ZERO
var facing := Vector2i(0, 1)
var enemies: Array = []        # 本图活着的敌人，顺序 = 数据顺序 = 行动顺序
var npcs: Array = []
var exits: Dictionary = {}     # 格子 -> {"to","at"}
var defeated: Dictionary = {}  # 敌人 id -> true，跨地图保留，要进存档
var steps := 0
var last_shrine: Dictionary = {}  # {"map","cell","id"}：最后一次祈祷时玩家站的地方，逃跑传回这里
var shrines: Dictionary = {}      # 本图神龛：格子 -> {"id"}；神龛格挡路，撞上就是祈祷
var _talk_latch := ""          # 上一个自动开口的 NPC；走开以前不再开口

func setup(world: Dictionary, params: Dictionary = {}, random: RandomNumberGenerator = null) -> void:
	p = DEFAULTS.duplicate(true)
	p.merge(world.get("params", {}), true)
	p.merge(params, true)
	maps = world.get("maps", {})
	rng = random
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 0
	defeated = {}
	steps = 0
	last_shrine = {}

## 进入一张图，站到 cell。落点在墙里、人身上、敌人身上或出口上时挪到最近的空格，并发 spawn_fixed。
func enter_map(id: String, cell: Vector2i) -> Array:
	var m: Dictionary = maps[id]
	map_id = id
	_load_grid(m)
	exits = {}
	for ex in m.get("exits", []):
		exits[_v(ex.cell)] = ex
	shrines = {}
	for sh in m.get("shrines", []):
		shrines[_v(sh.cell)] = {"id": str(sh.get("id", "shrine"))}
	npcs = []
	for n in m.get("npcs", []):
		npcs.append({"id": str(n.id), "cell": _v(n.cell), "node": str(n.get("node", ""))})
	enemies = []
	for d in m.get("enemies", []):
		var eid := str(d.id)
		if defeated.has(eid):
			if not bool(d.get("respawn", p.respawn)):
				continue
			defeated.erase(eid)
		enemies.append({"id": eid, "cell": _v(d.cell), "def": d, "wp": 0, "stun": 0})
	var ev: Array = []
	var safe := nearest_free(cell)
	ev.append({"type": "entered", "map": id, "cell": safe})
	if safe != cell:
		ev.append({"type": "spawn_fixed", "map": id, "from": cell, "to": safe})
	player = safe
	_talk_latch = ""
	ev.append_array(_check_talk())
	return ev

func _load_grid(m: Dictionary) -> void:
	solid = PackedByteArray()
	if m.has("rows"):
		var rows: Array = m.rows
		var chars := str(m.get("solid", p.solid))
		height = rows.size()
		width = str(rows[0]).length()
		for r in rows:
			var s := str(r)
			for x in width:
				solid.append(1 if x >= s.length() or chars.contains(s[x]) else 0)
	else:
		width = int(m.width)
		height = int(m.height)
		for v in m.blocked:
			solid.append(1 if int(v) != 0 else 0)

func walkable(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height and solid[c.y * width + c.x] == 0 and not shrines.has(c)

func npc_at(c: Vector2i) -> Dictionary:
	for n in npcs:
		if n.cell == c:
			return n
	return {}

func enemy_at(c: Vector2i) -> Dictionary:
	for e in enemies:
		if e.cell == c:
			return e
	return {}

func _free(c: Vector2i) -> bool:
	return walkable(c) and npc_at(c).is_empty() and enemy_at(c).is_empty() and not exits.has(c)

## 离 c 最近的能站的格（曼哈顿距离一圈圈往外找，顺序固定）。出口落点出错时用它纠正。
func nearest_free(c: Vector2i) -> Vector2i:
	return Walk.nearest(self, c, width + height)

# ---------------- 玩家走一步 = 一回合 ----------------

## 往 dir 走一格。撞墙、撞人只转身，不算一回合（敌人不动）。返回本回合按发生顺序排好的事件。
func step(dir: Vector2i) -> Array:
	var ev: Array = []
	if dir == Vector2i.ZERO:
		return ev
	facing = dir
	var t := player + dir
	var foe := enemy_at(t)
	if not foe.is_empty() and int(foe.stun) == 0:
		ev.append(_encounter(foe, "player_bump"))
		return ev
	if shrines.has(t):
		return pray()
	if not walkable(t) or not foe.is_empty() or not npc_at(t).is_empty():
		ev.append({"type": "bump", "cell": t})
		ev.append_array(_check_talk())
		return ev
	player = t
	steps += 1
	ev.append({"type": "moved", "cell": t})
	if exits.has(t):
		var ex: Dictionary = exits[t]
		ev.append({"type": "exit", "from": map_id, "to": str(ex.to)})
		ev.append_array(enter_map(str(ex.to), _v(ex.at)))
		return ev
	for e in enemies:  # 玩家自己走到敌人旁边
		if _touching(e):
			ev.append(_encounter(e, "player_moved"))
			return ev
	if steps % maxi(int(p.enemy_move_every), 1) == 0:
		for e in enemies:  # 按数据顺序一个个走；每走一个立刻查碰撞，前面的人占的格后面的人进不去
			if int(e.stun) > 0:
				e.stun = int(e.stun) - 1
				continue
			var mv := _enemy_turn(e)
			if not mv.is_empty():
				ev.append(mv)
			if _touching(e):
				ev.append(_encounter(e, "enemy_moved"))
				return ev
	ev.append_array(_check_talk())
	return ev

func _encounter(e: Dictionary, cause: String) -> Dictionary:
	return {"type": "encounter", "id": e.id, "encounter": str(e.def.get("encounter", e.id)), "cause": cause, "cell": e.cell}

func _touching(e: Dictionary) -> bool:
	if int(e.stun) > 0:
		return false
	var c: Vector2i = e.cell
	var dx := absi(c.x - player.x)
	var dy := absi(c.y - player.y)
	if p.contact == "same":
		return dx == 0 and dy == 0
	return maxi(dx, dy) <= 1 if p.contact_diagonal else dx + dy <= 1

func _enemy_turn(e: Dictionary) -> Dictionary:
	var d: Dictionary = e.def
	if d.get("boss", false):
		return {}  # 首领不动
	var mode := "chase"
	var next := NONE
	var radius := int(d.get("chase_radius", p.chase_radius))
	if radius > 0:
		var path := _path(e.cell, player, radius)
		if not path.is_empty() and rng.randf() < float(d.get("chase_chance", p.chase_chance)):
			next = path[0]
	if next == NONE:
		mode = str(d.get("idle", p.idle))
		match mode:
			"patrol":
				next = _patrol_step(e)
			"wander":
				next = _wander_step(e)
	if next == NONE or next == e.cell or not _in_zone(e, next):
		return {}
	if next == player and p.contact != "same":
		return {}
	if next != player and not _enemy_can_enter(next):
		return {}
	var from: Vector2i = e.cell
	e.cell = next
	return {"type": "enemy_moved", "id": e.id, "from": from, "to": next, "mode": mode}

## 敌人能进的格：不是墙、不是出口、没有 NPC、没有别的敌人、不是玩家。
func _enemy_can_enter(c: Vector2i) -> bool:
	return walkable(c) and not exits.has(c) and npc_at(c).is_empty() and enemy_at(c).is_empty() and c != player

## 敌人找路：广度优先，最多 max_len 步，goal 本身可以踩；不含起点，找不到返回 []。
func _path(from: Vector2i, goal: Vector2i, max_len: int) -> Array[Vector2i]:
	return Walk.bfs_path(self, from, goal, max_len)

func _patrol_step(e: Dictionary) -> Vector2i:
	var pts: Array = e.def.get("patrol", [])
	if pts.is_empty():
		return NONE
	if e.cell == _v(pts[int(e.wp) % pts.size()]):
		e.wp = (int(e.wp) + 1) % pts.size()
	var path := _path(e.cell, _v(pts[int(e.wp) % pts.size()]), width * height)
	return path[0] if not path.is_empty() else NONE

func _wander_step(e: Dictionary) -> Vector2i:
	if rng.randf() >= float(p.wander_chance):
		return NONE
	var n: Vector2i = e.cell + DIR4[rng.randi_range(0, 3)]
	var home := _v(e.def.cell)
	if not e.def.has("zone") and absi(n.x - home.x) + absi(n.y - home.y) > int(e.def.get("wander_radius", p.wander_radius)):
		return NONE
	return n

## 写了 zone [x, y, 宽, 高] 的敌人追、游荡、巡逻都不出这个矩形。
func _in_zone(e: Dictionary, c: Vector2i) -> bool:
	if not e.def.has("zone"):
		return true
	var z: Array = e.def.zone
	return Rect2i(int(z[0]), int(z[1]), int(z[2]), int(z[3])).has_point(c)

# ---------------- 战斗回来、对话、存档 ----------------

## 战斗结束后调用。赢了：记进 defeated，从地图上拿掉。
## 逃跑：祈祷过神龛就传回那里（原作做法）；没祈祷过，这个敌人愣住 flee_grace_steps 个敌人回合。
func after_battle(enemy_id: String, won: bool) -> Array:
	for e in enemies:
		if e.id != enemy_id:
			continue
		if won:
			defeated[enemy_id] = true
			enemies.erase(e)
			return [{"type": "defeated", "id": enemy_id}]
		if p.flee_to_shrine and not last_shrine.is_empty():
			var ev: Array = [{"type": "fled", "id": enemy_id, "to_shrine": last_shrine.id}]
			ev.append_array(enter_map(str(last_shrine.map), last_shrine.cell))
			return ev
		e.stun = int(p.flee_grace_steps)
		return [{"type": "fled", "id": enemy_id, "grace": e.stun}]
	return []

## 祈祷（撞上神龛或面对神龛按确认）：记下回城点，发 heal 让游戏回满血；shrine_respawn 时非首领敌人下次进图回来。
func pray() -> Array:
	var sh: Dictionary = shrines.get(player + facing, {})
	if sh.is_empty():
		return []
	last_shrine = {"map": map_id, "cell": player, "id": sh.id}
	var back: Array = []
	if p.shrine_respawn:
		var bosses := {}
		for m in maps.values():
			for d in m.get("enemies", []):
				if d.get("boss", false):
					bosses[str(d.id)] = true
		for id in defeated.keys():
			if not bosses.has(id):
				defeated.erase(id)
				back.append(id)
	return [{"type": "pray", "id": sh.id, "heal": true, "respawned": back}]

## 自动开口检查。每帧调也只在「新走到某个 NPC 旁边」时发一次 talk。
func check_talk() -> Array:
	return _check_talk()

func _check_talk() -> Array:
	var n := _talk_target()
	if n.is_empty():
		_talk_latch = ""
		return []
	if n.id == _talk_latch:
		return []
	_talk_latch = n.id
	return [{"type": "talk", "id": n.id, "node": n.node, "dir": n.cell - player, "auto": true}]

func _talk_target() -> Dictionary:
	var front := npc_at(player + facing)
	if p.talk == "facing" or not front.is_empty():
		return front
	for d: Vector2i in DIR4:
		var n := npc_at(player + d)
		if not n.is_empty():
			return n
	return {}

## 玩家按确认键：面前是神龛就祈祷；面前有 NPC 就开口，不受「自动开口一次」限制。
func interact() -> Array:
	if shrines.has(player + facing):
		return pray()
	var n := npc_at(player + facing)
	if n.is_empty():
		return []
	_talk_latch = n.id
	return [{"type": "talk", "id": n.id, "node": n.node, "dir": facing, "auto": false}]

## 存档只存位置、朝向、打败过谁；敌人读档后回到出生点。
func save_state() -> Dictionary:
	var sh := {} if last_shrine.is_empty() else {"map": last_shrine.map, "cell": [last_shrine.cell.x, last_shrine.cell.y], "id": last_shrine.id}
	return {"map": map_id, "cell": [player.x, player.y], "facing": [facing.x, facing.y], "defeated": defeated.keys(), "steps": steps, "last_shrine": sh}

func load_state(s: Dictionary) -> Array:
	defeated = {}
	for id in s.get("defeated", []):
		defeated[str(id)] = true
	steps = int(s.get("steps", 0))
	facing = _v(s.get("facing", [0, 1]))
	var sh: Dictionary = s.get("last_shrine", {})
	last_shrine = {} if sh.is_empty() else {"map": str(sh.map), "cell": _v(sh.cell), "id": str(sh.id)}
	return enter_map(str(s.map), _v(s.cell))

static func _v(c) -> Vector2i:
	return c if c is Vector2i else Vector2i(int(c[0]), int(c[1]))
