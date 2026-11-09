extends RefCounted
## 大地图用的两个格子搜索，由 overworld-grid.gd 调用。q 是调用方实例：
## bfs_path 用 q._enemy_can_enter(c) 判断能不能走，nearest 用 q._free(c) 判断能不能站。

const DIR4: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## 广度优先找路，最多 max_len 步；只走 q 允许的格，所以不会穿墙、不会踩到别的敌人；goal 本身可以踩。
## 返回不含起点的路，找不到返回 []。邻居顺序固定（上右下左），同样的局面每次给同一条路。
static func bfs_path(q, from: Vector2i, goal: Vector2i, max_len: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var prev := {from: from}
	var depth := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	var found := false
	while head < queue.size():
		var c := queue[head]
		head += 1
		if c == goal:
			found = true
			break
		if int(depth[c]) >= max_len:
			continue
		for d: Vector2i in DIR4:
			var n := c + d
			if prev.has(n) or (n != goal and not q._enemy_can_enter(n)):
				continue
			prev[n] = c
			depth[n] = int(depth[c]) + 1
			queue.append(n)
	if not found:
		return out
	var back := goal
	while back != from:
		out.push_front(back)
		back = prev[back]
	return out


## 离 c 最近的能站的格：按曼哈顿距离一圈圈往外找，同一圈里的顺序固定。最多找 max_r 圈，找不到返回 c。
static func nearest(q, c: Vector2i, max_r: int) -> Vector2i:
	if q._free(c):
		return c
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			var dx := r - absi(dy)
			for cand: Vector2i in [Vector2i(c.x - dx, c.y + dy), Vector2i(c.x + dx, c.y + dy)]:
				if q._free(cand):
					return cand
	return c
