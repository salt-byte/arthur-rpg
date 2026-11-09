class_name BattleView
extends Control
## 战斗画面（design/systems/combat.md 第 2 节、ART_DIRECTION 第 2、4 节）。规则全在 Battle 里，这里只画和收输入。
## 一回合三步，顶上一直写着、走到哪步亮哪步：① 看敌人头上的牌子 ② 给每个人选行动 ③ 点「结束回合」。
## 敌人头顶的意图牌写出手顺序、招、点数和打谁；被盯上的人头顶标着要挨几点（红）。
## 选完行动马上显示打完以后的血（「8 → 3」）；点「结束回合」后一来一回地播：你们按 ①②③ 出手，再轮到敌人。

signal finished(result: String)   # "win" 打赢 / "back" 输了回圣龛 / "flee" 逃跑

var b: Battle
var auto := false                  # --playtest：不播动画
var stage: Control
var unit_btn := {}                 # uid -> Button（选目标用）
var act_btns: Array = []
var targeting := {}                # {who, act}
var hint := ""
var mode := "plan"                 # plan / anim / end
var bg := Color("#2C3A3A")
var title := ""
var end_btns: Array = []
var last_report: Array = []        # 上一次「结束回合」的全部记录（测试读）
var _hint_label: Label
var _clear_btn: Button
var _end_btn: Button
var _preview := {}                 # uid -> 打完以后的血
# 播放这回合时用：画面上显示的血、播到哪一步、飘字、横幅
var _shown := {}                   # uid -> [hp, alive]；空 = 用真的
var _old_intents: Array = []
var _done_orders := {}             # 已经出过手的敌人意图 order
var _actor := ""
var _floats: Array = []            # {uid, text, col, t}
var _banner := ""
var _banner_t := 0.0
var _ticker := ""
var _t := 0.0
var _turn_shown := 0               # 播放时顶上还写着这一回合，播完再换成下一回合
var reward_fn := Callable()        # 打赢时 main 给的：算经验和掉落，返回结算框里的几行字
var reward_lines: Array = []
var _flee_btn: Button

const STAGE := Vector2(1280, 720)
const STEP_TIME := 0.75
const ORDER_MARKS := "①②③④⑤"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(stage)
	stage.draw.connect(_draw_stage)
	_hint_label = UIKit.label("", UIKit.BODY, UIKit.CREAM_DIM)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_hint_label.add_theme_constant_override("line_spacing", 6)
	_hint_label.position = Vector2(900, 504)
	_hint_label.size = Vector2(356, 110)
	stage.add_child(_hint_label)
	_clear_btn = _button(UIKit.t("ui_clear"), Vector2(900, 628), Vector2(120, 52), _on_clear)
	_end_btn = _button(UIKit.t("ui_end_turn"), Vector2(1032, 628), Vector2(224, 52), _on_end_turn)
	_flee_btn = _button(UIKit.t("ui_flee"), Vector2(1116, 62), Vector2(148, 44), _on_flee)
	visible = false
	resized.connect(_center)

## 画面比 1280×720 小时整体缩小，保证「结束回合」一定在屏幕里
func _center() -> void:
	var view := get_viewport_rect().size
	var k := minf(1.0, minf(view.x / STAGE.x, view.y / STAGE.y))
	stage.scale = Vector2(k, k)
	stage.position = ((view - STAGE * k) / 2.0).floor()

func _button(text: String, pos: Vector2, sz: Vector2, fn: Callable) -> Button:
	var bt := Button.new()
	bt.text = text
	bt.position = pos
	bt.size = sz
	bt.focus_mode = Control.FOCUS_ALL
	bt.pressed.connect(fn)
	stage.add_child(bt)
	return bt

func open(battle: Battle, background: Color, name_text: String) -> void:
	b = battle
	bg = background
	title = name_text
	visible = true
	mode = "plan"
	targeting = {}
	_shown = {}
	_old_intents = []
	_floats = []
	reward_lines = []
	_flee_btn.visible = b.can_flee()
	_center()
	_rebuild()
	_print(b.take_log())
	if not auto: _flash_banner(UIKit.f("ui_turn", {"n": b.turn}))

# ---------------- 位置 ----------------
func _ally_pos(i: int) -> Vector2:
	return Vector2(190 + i * 170, 396)

func _enemy_pos(i: int, n: int) -> Vector2:
	return Vector2(950 + (i - (n - 1) / 2.0) * 136, 300)

func _pos_of(uid: String) -> Vector2:
	var al := b.allies(false)
	for i in al.size():
		if al[i].uid == uid: return _ally_pos(i)
	var shown := _shown_enemies()
	for i in shown.size():
		if shown[i].uid == uid: return _enemy_pos(i, shown.size())
	return Vector2.ZERO

## 画面上的敌人：播放时按快照（召唤来的狼叫出来以后才出现），平时是活着的加这回合刚倒下的
func _shown_enemies() -> Array:
	if not _shown.is_empty():
		return b.enemies(false).filter(func(e): return _shown.has(e.uid) and (_shown[e.uid][1] or _intent_in(_old_intents, e.uid) != null))
	return b.enemies(false).filter(func(e): return e.alive or b.intent_of(e.uid) != null)

func _intent_in(list: Array, uid: String):
	for it in list:
		if it.uid == uid: return it
	return null

func _hp(u: Dictionary) -> Array:
	if _shown.has(u.uid): return _shown[u.uid]
	return [u.hp, u.alive]

# ---------------- 搭按钮 ----------------
func _rebuild() -> void:
	for x in unit_btn.values(): x.queue_free()
	unit_btn = {}
	for x in act_btns: x.queue_free()
	act_btns = []
	for x in end_btns: x.queue_free()
	end_btns = []
	var al := b.allies(false)
	for i in al.size():
		_unit_button(al[i].uid, _ally_pos(i))
	var en := _shown_enemies()
	for i in en.size():
		_unit_button(en[i].uid, _enemy_pos(i, en.size()))
	for i in al.size():
		var u: Dictionary = al[i]
		var base := _col_pos(i) + Vector2(0, 16)
		var acts := b.actions_for(u.uid)
		var q = b.planned(u.uid)
		for j in acts.size():
			var a: String = acts[j]
			var pos := base + (Vector2((j % 3) * 140, (j / 3) * 46) if u.uid == "apprentice" else Vector2(0, j * 46))
			var bt := _button(_act_label(a, u.uid), pos, Vector2(132 if u.uid == "apprentice" else 196, 40), _on_act.bind(u.uid, a))
			bt.disabled = not u.alive or b.why_not(u.uid, a) != ""
			if q != null and q.act == a:
				_style_selected(bt)
			bt.set_meta("hint", _act_hint(u.uid, a))
			bt.set_meta("who", u.uid)
			bt.focus_entered.connect(_set_hint.bind(bt))
			bt.mouse_entered.connect(_set_hint.bind(bt))
			act_btns.append(bt)
	_clear_btn.disabled = b.queue.is_empty()
	_end_btn.disabled = false
	if _all_planned():
		_style_selected(_end_btn)
		hint = UIKit.t("ui_all_set")
	else:
		_end_btn.remove_theme_stylebox_override("normal")
		hint = UIKit.t("ui_queue_empty")
	_refresh_hint()
	_preview = b.preview() if not b.queue.is_empty() else {}
	if not auto:
		var focus: Button = _end_btn if _all_planned() else null
		if focus == null:
			for bt in act_btns:
				if not bt.disabled and b.planned(bt.get_meta("who", "")) == null:
					focus = bt
					break
		if focus: focus.grab_focus.call_deferred()
	stage.queue_redraw()

func _col_pos(i: int) -> Vector2:
	var cols := [Vector2(24, 520), Vector2(456, 520), Vector2(668, 520)]
	return cols[i] if i < cols.size() else Vector2(668 + (i - 2) * 212, 520)

func _all_planned() -> bool:
	for u in b.allies():
		if b.planned(u.uid) == null: return false
	return true

func _style_selected(bt: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIKit.GOLD.darkened(0.35)
	sb.border_color = UIKit.GOLD
	sb.set_border_width_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	bt.add_theme_stylebox_override("normal", sb)

## 点选区域：敌人从头顶的牌子到血条整列都能点；我方从头顶到血条
func _hit_rect(uid: String, p: Vector2) -> Rect2:
	if b.unit(uid).side == "enemy":
		return Rect2(p + Vector2(-68, -200), Vector2(136, 284))
	return Rect2(p + Vector2(-80, -170), Vector2(160, 254))

func _unit_button(uid: String, p: Vector2) -> void:
	var bt := Button.new()
	bt.flat = true
	var hr := _hit_rect(uid, p)
	bt.position = hr.position
	bt.size = hr.size
	bt.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = UIKit.GOLD
	ring.set_border_width_all(4)
	for st in ["normal", "disabled", "pressed"]: bt.add_theme_stylebox_override(st, empty)
	for st in ["hover", "focus"]: bt.add_theme_stylebox_override(st, ring)
	bt.disabled = true
	bt.pressed.connect(_on_target.bind(uid))
	stage.add_child(bt)
	unit_btn[uid] = bt

## 按钮上的字：法术写名字和要几点法力；砍、举盾写几点；药写还剩几瓶
func _act_label(a: String, uid := "") -> String:
	if b.has_spell(a):
		return "%s %d" % [b.spell(a).name, b.spell_cost(a)]
	match a:
		"attack": return UIKit.f("act_attack_n", {"n": int(b.unit(uid).power) if b.unit(uid) != null else 0})
		"guard": return UIKit.f("act_guard_n", {"n": int(b.ctx.get("guard_block", 3))})
		"potion_hp": return UIKit.f("act_potion_hp", {"n": int(b.potions.get("potion_hp", 0))})
		"potion_mana": return UIKit.f("act_potion_mana", {"n": int(b.potions.get("potion_mana", 0))})
	return UIKit.t("act_" + a)

func _act_hint(uid: String, a: String) -> String:
	var why := b.why_not(uid, a)
	var h := ""
	var sp := b.spell(a)
	match a:
		"spark": h = UIKit.f("hint_spark", {"n": int(sp.damage), "v": int(sp.get("vulnerable", 1))})
		"ward": h = UIKit.f("hint_ward", {"n": int(sp.block)})
		"focus": h = UIKit.f("hint_focus", {"n": int(sp.get("restore_mana", 2))})
		"interrupt": h = UIKit.f("hint_interrupt")
		"blind": h = UIKit.f("hint_blind", {"n": int(sp.weak)})
		"attack": h = UIKit.f("hint_attack", {"n": int(b.unit(uid).power)})
		"guard": h = UIKit.f("hint_guard", {"n": int(b.ctx.get("guard_block", 3))})
		"kay_cover": h = UIKit.f("hint_kay_cover", {"n": int(b.P.kay_cover_block)})
		"potion_hp": h = UIKit.f("hint_potion_hp", {"n": int(b.ctx.get("potion_heal", 6))})
		"potion_mana": h = UIKit.f("hint_potion_mana", {"n": int(b.ctx.get("potion_mana", 3))})
	if why != "" and why != "dead": h += "\n" + why
	return h

func _set_hint(bt: Button) -> void:
	if not targeting.is_empty() or mode != "plan": return
	hint = bt.get_meta("hint", "")
	_refresh_hint()

func _refresh_hint() -> void:
	_hint_label.text = hint

# ---------------- 操作 ----------------
func _on_act(uid: String, a: String) -> void:
	if mode != "plan": return
	var kind := b.target_kind(a)
	if kind == "":
		b.plan(uid, a)
		_rebuild()
		_maybe_auto_end()
		return
	targeting = {"who": uid, "act": a}
	var valid := b.valid_targets(a)
	for k in unit_btn:
		unit_btn[k].disabled = not (k in valid)
	for bt in act_btns: bt.disabled = true
	_end_btn.disabled = true
	hint = "%s · %s：%s" % [b.unit(uid).name, _act_label(a, uid), UIKit.t("ui_pick_target")]
	_refresh_hint()
	if not valid.is_empty(): unit_btn[valid[0]].grab_focus()
	stage.queue_redraw()

func _on_target(uid: String) -> void:
	if targeting.is_empty(): return
	b.plan(targeting.who, targeting.act, uid)
	targeting = {}
	_rebuild()
	_maybe_auto_end()

## 活着的人都排好了，就自动开打（用户：「结束回合这些不是应该它自己结束吗」）。
## 「结束回合」按钮留着，给只想让一部分人动的时候用。
func _maybe_auto_end() -> void:
	if mode != "plan" or not _all_planned(): return
	if auto:
		_on_end_turn()
		return
	await _wait(0.5)
	if mode == "plan" and _all_planned():
		_on_end_turn()

func cancel_target() -> void:
	if targeting.is_empty(): return
	targeting = {}
	_rebuild()

func _on_clear() -> void:
	if mode != "plan": return
	b.queue = []
	_rebuild()

func _on_end_turn() -> void:
	if mode != "plan": return
	targeting = {}
	_old_intents = b.intents.duplicate(true)
	_turn_shown = b.turn
	var before := {}
	for u in b.units: before[u.uid] = [u.hp, u.alive]
	b.end_turn()
	var report := b.take_log()
	last_report = report.duplicate()
	_print(report)
	_preview = {}
	if auto:
		_old_intents = []
		_after_turn()
		return
	await _play(before)
	_after_turn()

## 一来一回地播这回合：先你们（按 ①②③），再敌人（按牌子上的顺序）
func _play(before: Dictionary) -> void:
	mode = "anim"
	for bt in act_btns: bt.disabled = true
	for bt in unit_btn.values(): bt.disabled = true
	_clear_btn.disabled = true
	_end_btn.disabled = true
	_end_btn.remove_theme_stylebox_override("normal")
	_shown = before.duplicate(true)
	_done_orders = {}
	var side := ""
	for st in b.steps:
		if st.side == "end": break
		if st.side != side:
			side = st.side
			_actor = ""
			_ticker = ""
			_flash_banner(UIKit.t("ui_phase_ally" if side == "ally" else "ui_phase_enemy"))
			hint = UIKit.t("ui_phase_ally_hint" if side == "ally" else "ui_phase_enemy_hint")
			_refresh_hint()
			await _wait(0.8)
		_actor = st.who
		_ticker = "\n".join(PackedStringArray(st.lines.filter(func(l): return not str(l).begins_with("["))))
		hint = _ticker
		_refresh_hint()
		for uid in st.hp:
			var old: Array = _shown.get(uid, [st.hp[uid][0], true])
			var d: int = int(old[0]) - int(st.hp[uid][0])
			if d > 0: _floats.append({"uid": uid, "text": "-%d" % d, "col": UIKit.DANGER, "t": 0.0})
			if not st.hp[uid][1] and old[1]:
				_floats.append({"uid": uid, "text": UIKit.t("st_down"), "col": UIKit.CREAM, "t": -0.3})
		_shown = st.hp.duplicate(true)
		if st.side == "enemy": _done_orders[st.order] = true
		stage.queue_redraw()
		await _wait(STEP_TIME)
		_actor = ""
	_shown = {}
	_old_intents = []
	_done_orders = {}
	_ticker = ""
	_turn_shown = 0

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _flash_banner(t: String) -> void:
	_banner = t
	_banner_t = 1.1

func _after_turn() -> void:
	if b.result != "":
		_show_end()
		return
	mode = "plan"
	_rebuild()
	if not auto: _flash_banner(UIKit.f("ui_turn", {"n": b.turn}))

func _show_end() -> void:
	mode = "end"
	for x in act_btns: x.queue_free()
	act_btns = []
	_clear_btn.disabled = true
	_end_btn.disabled = true
	_flee_btn.visible = false
	if b.result == "win":
		reward_lines = reward_fn.call(b) if reward_fn.is_valid() else []
		end_btns.append(_button(UIKit.t("ui_continue"), Vector2(540, 420), Vector2(200, 52), _finish.bind("win")))
	else:
		end_btns.append(_button(UIKit.t("ui_retry"), Vector2(430, 420), Vector2(200, 52), _retry))
		end_btns.append(_button(UIKit.t("ui_back_shrine"), Vector2(650, 420), Vector2(200, 52), _finish.bind("back")))
	if auto:
		print("  [战斗结束] %s；按钮：%s" % [UIKit.t("ui_win") if b.result == "win" else UIKit.t("ui_lose"), "、".join(PackedStringArray(end_btns.map(func(x): return x.text)))])
		for l in reward_lines: print("  [结算] ", l)
	else:
		end_btns[0].grab_focus.call_deferred()
	stage.queue_redraw()

func retry() -> void:
	_retry()

func _retry() -> void:
	b.restart()
	mode = "plan"
	_flee_btn.visible = b.can_flee()
	_end_btn.disabled = false
	_rebuild()
	_print(b.take_log())
	if not auto: _flash_banner(UIKit.f("ui_turn", {"n": b.turn}))

func _on_flee() -> void:
	if mode != "plan" or not b.flee(): return
	_print(b.take_log())
	_finish("flee")

func _finish(r: String) -> void:
	visible = false
	for x in end_btns: x.queue_free()
	end_btns = []
	finished.emit(r)

## 键盘：选目标时 Esc 取消
func handle(e: InputEvent) -> void:
	if e.is_action_pressed("cancel"):
		cancel_target()

func _print(lines: Array) -> void:
	if auto:
		for l in lines: print("  ", l)

# ---------------- 画 ----------------
func _process(delta: float) -> void:
	if not visible: return
	_t += delta
	_banner_t = maxf(0.0, _banner_t - delta)
	for f in _floats: f.t += delta
	_floats = _floats.filter(func(f): return f.t < 1.2)
	stage.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), bg.darkened(0.55))

func _draw_stage() -> void:
	if b == null: return
	var font := UIKit.font()
	var ci := stage
	ci.draw_rect(Rect2(0, 0, STAGE.x, 488), bg)
	ci.draw_rect(Rect2(0, 340, STAGE.x, 148), bg.darkened(0.15))
	_draw_top()
	var intents := _old_intents if not _old_intents.is_empty() else b.intents
	var al := b.allies(false)
	for i in al.size():
		_draw_unit(al[i], _ally_pos(i), true)
	var en := _shown_enemies()
	for i in en.size():
		_draw_unit(en[i], _enemy_pos(i, en.size()), false)
	for i in al.size():
		_draw_incoming(al[i], _ally_pos(i), intents)
	for it in intents:
		if b.unit(it.uid) == null: continue
		_intent_plate(it, _pos_of(it.uid))
	if not targeting.is_empty():
		var pulse := 0.5 + 0.5 * sin(_t * 7.0)
		for uid in b.valid_targets(targeting.act):
			var r := _hit_rect(uid, _pos_of(uid))
			ci.draw_rect(r, Color(UIKit.GOLD, 0.12 + 0.12 * pulse))
			ci.draw_rect(r, Color(UIKit.GOLD, 0.6 + 0.4 * pulse), false, 4.0)
	for f in _floats:
		if f.t < 0.0: continue
		var p := _pos_of(f.uid) + Vector2(0, -40 - f.t * 50.0)
		var a := clampf(1.4 - f.t, 0.0, 1.0)
		ci.draw_string(font, p + Vector2(-58, 2), f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, UIKit.BIG, Color(UIKit.INK, a))
		ci.draw_string(font, p + Vector2(-60, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, UIKit.BIG, Color(f.col, a))
	# 下面一栏：每人的名字、行动按钮、排好的行动
	var panel := Rect2(8, 488, STAGE.x - 16, 224)
	UIKit.draw_frame(ci, panel)
	for i in al.size():
		var p := _col_pos(i)
		ci.draw_string(font, p, al[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY, UIKit.GOLD if al[i].alive else UIKit.CREAM_DIM)
		if al[i].uid == "apprentice":
			_mana(p + Vector2(56, -14))
		var q = b.planned(al[i].uid)
		var line := ""
		if not al[i].alive:
			line = UIKit.t("st_down")
		elif q != null:
			line = "%s %s" % [ORDER_MARKS.substr(b.queue.find(q), 1), _act_label(q.act, al[i].uid)]
			if q.target != "": line += " → " + b.unit(q.target).name
		elif mode == "plan":
			line = UIKit.t("ui_plan_none")
		ci.draw_string(font, p + Vector2(0, 182), line, HORIZONTAL_ALIGNMENT_LEFT, 400 if al[i].uid == "apprentice" else 200, UIKit.BODY, UIKit.GOLD if q != null else UIKit.CREAM_DIM)
	# 横幅：「你们出手」「敌人出手」「第 2 回合」
	if _banner_t > 0.0:
		var a := minf(1.0, _banner_t * 3.0)
		var r := Rect2(0, 210, STAGE.x, 72)
		ci.draw_rect(r, Color(UIKit.INK, 0.8 * a))
		ci.draw_string(font, Vector2(0, r.position.y + 50), _banner, HORIZONTAL_ALIGNMENT_CENTER, STAGE.x, UIKit.BIG, Color(UIKit.GOLD, a))
	if mode == "end": _draw_end()

## 顶上一行：第几回合 + 三步，当前这一步亮起来
func _draw_top() -> void:
	var ci := stage
	var font := UIKit.font()
	ci.draw_rect(Rect2(0, 0, STAGE.x, 52), Color(UIKit.INK, 0.85))
	ci.draw_string(font, Vector2(20, 36), UIKit.f("ui_turn", {"n": _turn_shown if _turn_shown > 0 else b.turn}), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY, UIKit.GOLD)
	var cur := 0
	if mode == "plan": cur = 3 if _all_planned() else 2
	var steps := [UIKit.t("ui_step1"), UIKit.t("ui_step2"), UIKit.t("ui_step3")]
	var x := 160.0
	for i in 3:
		var on := (i + 1) == cur
		var w := font.get_string_size(steps[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2).x
		if on: ci.draw_rect(Rect2(x - 8, 10, w + 16, 34), UIKit.GOLD)
		ci.draw_string(font, Vector2(x, 35), steps[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2, UIKit.INK if on else UIKit.CREAM_DIM)
		x += w + 18
		if i < 2:
			ci.draw_string(font, Vector2(x, 35), "→", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2, UIKit.CREAM_DIM)
			x += 32
	ci.draw_string(font, Vector2(STAGE.x - 260, 36), title, HORIZONTAL_ALIGNMENT_RIGHT, 240, UIKit.BODY, UIKit.CREAM)

func _draw_unit(u: Dictionary, p: Vector2, ally: bool) -> void:
	var ci := stage
	var font := UIKit.font()
	var hpv := _hp(u)
	var hp: int = hpv[0]
	var alive: bool = hpv[1]
	if _actor == u.uid:
		p += Vector2(28 if ally else -28, 0)
	var col := Color("#55575F")
	if ally:
		var look: Dictionary = Data.t("maps").actors.get(u.uid, {})
		col = UIKit.hexcol(look.get("color", ""))
	elif u.id == "merlin_shadow":
		col = Color("#3A3D52")
	elif u.get("kind", "") == "man":
		col = Color("#6B5A48")
	elif u.id == "wolf_leader":
		col = Color("#4A4C55")
	var a := 1.0 if alive else 0.35
	if ally:
		ci.draw_rect(Rect2(p.x - 30, p.y - 112, 60, 112), Color(UIKit.INK, a))
		ci.draw_rect(Rect2(p.x - 26, p.y - 72, 52, 68), Color(col, a))
		ci.draw_rect(Rect2(p.x - 20, p.y - 108, 40, 36), Color(Color("#E8C4A0"), a))
	elif u.get("kind", "") == "man":
		# 人形：灰褐的身子、兜帽，弓手手里一张弓
		ci.draw_rect(Rect2(p.x - 28, p.y - 112, 56, 112), Color(UIKit.INK, a))
		ci.draw_rect(Rect2(p.x - 24, p.y - 72, 48, 68), Color(col, a))
		ci.draw_rect(Rect2(p.x - 18, p.y - 108, 36, 36), Color(col.lightened(0.25), a))
		if u.id == "archer":
			ci.draw_arc(p + Vector2(-34, -60), 26, PI * 0.5, PI * 1.5, 12, Color("#C8B080", a), 4.0)
		else:
			ci.draw_line(p + Vector2(-24, -60), p + Vector2(-50, -96), Color("#C8C8D0", a), 5.0)
	elif u.id == "merlin_shadow":
		ci.draw_rect(Rect2(p.x - 30, p.y - 120, 60, 120), Color(UIKit.INK, a))
		ci.draw_rect(Rect2(p.x - 26, p.y - 116, 52, 112), Color(col, a))
		ci.draw_line(p + Vector2(-26, -90), p + Vector2(-46, -10), Color("#C8C8D0", a), 5.0)
	else:
		# 四足兽的轮廓块，头朝左（朝着你们）
		ci.draw_rect(Rect2(p.x - 44, p.y - 56, 88, 50), Color(UIKit.INK, a))
		ci.draw_rect(Rect2(p.x - 40, p.y - 52, 80, 42), Color(col, a))
		ci.draw_rect(Rect2(p.x - 52, p.y - 72, 30, 30), Color(UIKit.INK, a))
		ci.draw_rect(Rect2(p.x - 49, p.y - 69, 24, 24), Color(col.lightened(0.1), a))
		for lx in [-34, -18, 14, 30]:
			ci.draw_rect(Rect2(p.x + lx, p.y - 12, 8, 12), Color(col.darkened(0.2), a))
	var tags := []
	if _shown.is_empty():
		if int(u.block) > 0: tags.append(UIKit.f("st_block", {"n": int(u.block)}))
		if int(u.strength) > 0: tags.append(UIKit.f("st_strength", {"n": int(u.strength)}))
		if int(u.weak) > 0: tags.append(UIKit.f("st_weak", {"n": int(u.weak)}))
		if int(u.vulnerable) > 0: tags.append(UIKit.f("st_vulnerable", {"n": int(u.vulnerable)}))
	if u.get("pending") != null: tags.append(UIKit.t("st_charging"))
	if not tags.is_empty():
		ci.draw_string(font, p + Vector2(-60, 98), " ".join(tags), HORIZONTAL_ALIGNMENT_CENTER, 120, UIKit.SMALL * 2, UIKit.DROP)
	ci.draw_string(font, p + Vector2(-70, 28), u.name, HORIZONTAL_ALIGNMENT_CENTER, 140, UIKit.BODY, Color(UIKit.CREAM, a))
	var bar := Rect2(p.x - 50, p.y + 36, 100, 12)
	ci.draw_rect(bar.grow(2), UIKit.INK)
	var ratio := float(hp) / float(u.max)
	var after: int = _preview.get(u.uid, hp) if mode == "plan" else hp
	var ratio_after := float(after) / float(u.max)
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), UIKit.HP_OK if ratio > 0.34 else UIKit.DANGER)
	if after < hp:
		var lost := Rect2(bar.position + Vector2(bar.size.x * ratio_after, 0), Vector2(bar.size.x * (ratio - ratio_after), bar.size.y))
		ci.draw_rect(lost, Color(UIKit.CREAM, 0.55 + 0.45 * sin(_t * 6.0)))
		ci.draw_string(font, p + Vector2(-70, 74), "%d → %d" % [hp, after], HORIZONTAL_ALIGNMENT_CENTER, 140, UIKit.SMALL * 2, UIKit.DANGER if ally else UIKit.GOLD)
	else:
		ci.draw_string(font, p + Vector2(-50, 74), "%d/%d" % [hp, u.max], HORIZONTAL_ALIGNMENT_CENTER, 100, UIKit.SMALL * 2, Color(UIKit.CREAM, a))
	if not alive:
		ci.draw_line(p + Vector2(-40, -100), p + Vector2(40, -10), UIKit.DANGER, 4.0)

## 我方头顶：这回合谁要打他、几点；下回合要落下来的重劈用暗红
func _draw_incoming(u: Dictionary, p: Vector2, intents: Array) -> void:
	var ci := stage
	var font := UIKit.font()
	var y := p.y - 128
	for it in intents:
		var e = b.unit(it.uid)
		if e == null or it.cancelled or _done_orders.has(it.order): continue
		if not _hp(e)[1]: continue
		var hit := false
		var later := false
		var n := ""
		if it.act == "attack" and (it.target == u.uid or it.target == "all"):
			hit = true
			n = str(b.intent_damage(it, u.uid)) + ("×%d" % it.hits if it.hits > 1 else "")
		elif it.act == "weak" and it.target == u.uid:
			hit = true
			n = UIKit.f("st_weak", {"n": it.stacks})
		elif it.act == "charge" and it.get("then_target", "") == u.uid:
			hit = true
			later = true
			n = str(b.intent_damage(it, u.uid))
		if not hit: continue
		var t := "%s %s %s" % [ORDER_MARKS.substr(it.order - 1, 1), e.name, n]
		if later: t = UIKit.f("ui_next_hit", {"who": e.name, "n": n})
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2).x
		var r := Rect2(p.x - w / 2 - 10, y - 32, w + 20, 32)
		ci.draw_rect(r, UIKit.INK)
		ci.draw_rect(r.grow(-2), UIKit.DANGER.darkened(0.45) if later else UIKit.DANGER)
		ci.draw_string(font, r.position + Vector2(10, 24), t, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2, UIKit.CREAM)
		y -= 36

func _intent_plate(it: Dictionary, p: Vector2) -> void:
	var ci := stage
	var font := UIKit.font()
	var e = b.unit(it.uid)
	if _actor == it.uid: p += Vector2(-28, 0)
	var r := Rect2(p + Vector2(-66, -196), Vector2(132, 64))
	var alive: bool = _hp(e)[1]
	var dead: bool = not alive or it.cancelled or _done_orders.has(it.order)
	UIKit.draw_frame(ci, r, Color(UIKit.INK, 0.95) if not dead else Color(UIKit.NAVY, 0.7), UIKit.DANGER if not dead else UIKit.CREAM_DIM)
	_badge(r.position + Vector2(20, 20), it.order, UIKit.DANGER if not dead else UIKit.CREAM_DIM)
	var line1 := UIKit.t(it.move)
	var line2 := ""
	var num := ""
	match it.act:
		"attack":
			num = str(b.intent_damage(it)) + ("×%d" % it.hits if it.hits > 1 else "") if it.target != "all" else str(b.intent_damage(it, b.allies()[0].uid if not b.allies().is_empty() else ""))
			line2 = "→ " + (b._name(it.target) if it.target != "all" else UIKit.t("plate_all"))
		"charge":
			line1 = UIKit.t("act_charge")
			num = str(b.intent_damage(it))
			line2 = UIKit.f("plate_charge", {"move": UIKit.t(it.then.get("move", "")), "n": ""}).strip_edges()
		"summon":
			num = str(it.count)
			line2 = UIKit.f("plate_summon", {"n": it.count})
		"buff":
			num = "+%d" % it.strength
			line2 = UIKit.t("plate_buff")
		"weak":
			num = str(it.stacks)
			line2 = UIKit.f("plate_weak", {"t": b._name(it.target)})
		"block":
			num = str(it.block)
			line2 = UIKit.t("plate_block")
	var c1 := UIKit.CREAM if not dead else UIKit.CREAM_DIM
	ci.draw_string(font, r.position + Vector2(38, 30), line1, HORIZONTAL_ALIGNMENT_LEFT, 60, UIKit.BODY, c1)
	if num != "":
		var big := num.length() <= 2
		ci.draw_string(font, r.position + Vector2(r.size.x - 74, 34 if big else 30), num, HORIZONTAL_ALIGNMENT_RIGHT, 64, UIKit.BIG if big else UIKit.BODY, UIKit.GOLD if not dead else UIKit.CREAM_DIM)
	var fs := UIKit.SMALL * 2 if font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2).x <= 116 else UIKit.SMALL
	ci.draw_string(font, r.position + Vector2(10, 56), line2, HORIZONTAL_ALIGNMENT_LEFT, 116, fs, c1)
	if it.cancelled or not alive:
		ci.draw_line(r.position + Vector2(8, r.size.y / 2), r.end - Vector2(8, r.size.y / 2), UIKit.CREAM_DIM, 3.0)

func _badge(c: Vector2, n: int, col: Color) -> void:
	stage.draw_circle(c, 13, UIKit.INK)
	stage.draw_circle(c, 11, col)
	stage.draw_string(UIKit.font(), c + Vector2(-12, 7), str(n), HORIZONTAL_ALIGNMENT_CENTER, 24, UIKit.SMALL * 2 if n < 10 else UIKit.SMALL, UIKit.INK)

func _mana(p: Vector2) -> void:
	var left := b.mana_left()
	for i in b.mana_max:
		var c := p + Vector2(i * 22 + 10, 0)
		if i < left:
			UIKit.draw_drop(stage, c, 20, UIKit.DROP, true)
		elif i < b.mana:
			UIKit.draw_drop(stage, c, 20, UIKit.DROP, false)
		else:
			UIKit.draw_drop(stage, c, 20, Color(UIKit.CREAM_DIM, 0.35), false)
	stage.draw_string(UIKit.font(), p + Vector2(b.mana_max * 22 + 16, 12), UIKit.f("ui_mana", {"n": left, "max": b.mana_max}), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2, UIKit.DROP)

func _draw_end() -> void:
	var r := Rect2(STAGE.x / 2 - 360, 150, 720, 350)
	UIKit.draw_frame(stage, r, Color(UIKit.INK, 0.96))
	var t := UIKit.t("ui_win") if b.result == "win" else UIKit.t("ui_lose")
	stage.draw_string(UIKit.font(), Vector2(r.position.x, r.position.y + 64), t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UIKit.BIG + 12, UIKit.GOLD if b.result == "win" else UIKit.DANGER)
	var y := r.position.y + 118
	var lines: Array = reward_lines if b.result == "win" else [UIKit.t("ui_lose_hint")]
	for l in lines:
		stage.draw_string(UIKit.font(), Vector2(r.position.x + 40, y), str(l), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, UIKit.BODY, UIKit.CREAM)
		y += 38
