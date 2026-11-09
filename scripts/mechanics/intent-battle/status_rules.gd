extends RefCounted
## 伤害公式和状态规则（照杀戮尖塔）：力量加在每一下的基础伤害上；攻击者虚弱 × weak_mult，
## 目标易伤 × vulnerable_mult；乘完才向下取整，不低于 0。格挡另扣，在各自回合开始时清零（在 intent-battle.gd 里）。
## 只有静态函数，intent-battle.gd 用 preload 调。

const TICKING := ["weak", "vulnerable"]

## 一下打多少（未扣格挡）。预告、按钮上的数、真正结算都只调这一个函数
static func hit_damage(base: int, src: Dictionary, t: Dictionary, cfg: Dictionary) -> int:
	var d := float(base + int(src.strength))
	if int(src.weak) > 0: d *= float(cfg.weak_mult)
	if int(t.vulnerable) > 0: d *= float(cfg.vulnerable_mult)
	return maxi(0, floori(d + 0.000001))

## 算预告那一刻的条件，结算时对比，变了就写进 reasons
static func basis(src: Dictionary, t: Dictionary) -> Dictionary:
	return {"s": int(src.strength), "w": int(src.weak) > 0, "v": int(t.vulnerable) > 0}

static func changed(old: Dictionary, src: Dictionary, t: Dictionary) -> Array:
	var now := basis(src, t)
	var why := []
	if now.s != old.s: why.append("strength")
	if now.w != old.w: why.append("weak")
	if now.v != old.v: why.append("vulnerable")
	return why

## 先扣格挡再掉血：返回 [挡掉的, 掉的血]
static func absorb(t: Dictionary, dealt: int) -> Array:
	var blocked := mini(int(t.block), dealt)
	t.block -= blocked
	return [blocked, dealt - blocked]

## 上状态。by_enemy：敌人上给队员的，这回合结束时不减（grace）
static func apply(t: Dictionary, key: String, n: int, by_enemy: bool) -> void:
	t[key] = int(t[key]) + n
	if by_enemy: t.fresh[key] = true

## 回合结束：虚弱、易伤各减 1
static func tick(u: Dictionary, grace: bool) -> void:
	for k in TICKING:
		if not (grace and u.fresh.has(k)): u[k] = maxi(0, int(u[k]) - 1)
	u.fresh = {}
