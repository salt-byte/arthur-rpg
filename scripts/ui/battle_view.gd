class_name BattleView
extends Control
## 战斗画面（design/systems/combat.md 第 2 节、ART_DIRECTION 第 2、4 节）。规则全在 Battle 里，这里只画和收输入。
## 敌人头顶是意图牌：出手顺序、招、点数、箭头指向目标，压在最上层。
## 我方每人头顶是你给他排的行动和先后；下面一栏给每人选行动，法力是一排水滴。
## 点「结束回合」后弹一张这回合发生了什么的单子，确认后进下一回合。

signal finished(result: String)   # "win" 打赢 / "back" 输了回地图

var b: Battle
var auto := false                  # --playtest：不弹单子
var stage: Control
var unit_btn := {}                 # uid -> Button（选目标用）
var act_btns: Array = []
var targeting := {}                # {who, act}
var hint := ""
var report: Array = []             # 这回合发生的事，弹单子用
var last_report: Array = []        # 上一次「结束回合」的全部记录（测试读）
var mode := "plan"                 # plan / report / end
var bg := Color("#2C3A3A")
var title := ""
var end_btns: Array = []
var _hint_label: Label
var _clear_btn: Button
var _end_btn: Button

const STAGE := Vector2(1280, 720)

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
	_hint_label.position = Vector2(900, 500)
	_hint_label.size = Vector2(356, 120)
	stage.add_child(_hint_label)
	_clear_btn = _button(UIKit.t("ui_clear"), Vector2(900, 648), Vector2(140, 48), _on_clear)
	_end_btn = _button(UIKit.t("ui_end_turn"), Vector2(1052, 648), Vector2(204, 48), _on_end_turn)
	visible = false
	resized.connect(_center)

func _center() -> void:
	var view := get_viewport_rect().size
	stage.position = ((view - STAGE) / 2.0).floor()

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
	_center()
	_rebuild()
	_print_log()

# ---------------- 位置 ----------------
func _ally_pos(i: int) -> Vector2:
	return Vector2(200 + i * 160, 400)

func _enemy_pos(i: int, n: int) -> Vector2:
	return Vector2(940 + (i - (n - 1) / 2.0) * 136, 300)

func _pos_of(uid: String) -> Vector2:
	var al := b.allies(false)
	for i in al.size():
		if al[i].uid == uid: return _ally_pos(i)
	var shown := _shown_enemies()
	for i in shown.size():
		if shown[i].uid == uid: return _enemy_pos(i, shown.size())
	return Vector2.ZERO

## 画面上的敌人：活着的，加上这回合刚倒下的（画成倒下）
func _shown_enemies() -> Array:
	return b.enemies(false).filter(func(e): return e.alive or b.intent_of(e.uid) != null)

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
	# 每个人一栏行动
	var cols := {0: Vector2(24, 540), 1: Vector2(456, 540), 2: Vector2(668, 540)}
	for i in al.size():
		var u: Dictionary = al[i]
		var base: Vector2 = cols.get(i, Vector2(668 + (i - 2) * 212, 540))
		var acts := b.actions_for(u.uid)
		for j in acts.size():
			var a: String = acts[j]
			var pos := base + (Vector2((j % 2) * 208, (j / 2) * 52) if u.uid == "apprentice" else Vector2(0, j * 52))
			var bt := _button(_act_label(a), pos, Vector2(196, 44), _on_act.bind(u.uid, a))
			bt.disabled = not u.alive or b.why_not(u.uid, a) != ""
			bt.set_meta("hint", _act_hint(u.uid, a))
			bt.focus_entered.connect(_set_hint.bind(bt))
			bt.mouse_entered.connect(_set_hint.bind(bt))
			act_btns.append(bt)
	_clear_btn.disabled = b.queue.is_empty()
	hint = UIKit.t("ui_queue_empty") if b.queue.is_empty() else ""
	_refresh_hint()
	if not act_btns.is_empty() and not auto:
		var first: Button = null
		for bt in act_btns:
			if not bt.disabled:
				first = bt
				break
		if first: first.grab_focus.call_deferred()
	stage.queue_redraw()

func _unit_button(uid: String, p: Vector2) -> void:
	var bt := Button.new()
	bt.flat = true
	bt.position = p + Vector2(-48, -124)
	bt.size = Vector2(96, 128)
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

func _act_label(a: String) -> String:
	if b.P.spells.has(a):
		return "%s  %d" % [b.P.spells[a].name, b.spell_cost(a)]
	return UIKit.t("act_" + a)

func _act_hint(uid: String, a: String) -> String:
	var why := b.why_not(uid, a)
	var h := ""
	match a:
		"spark": h = UIKit.f("hint_spark", {"n": b.P.spells.spark.damage})
		"ward": h = UIKit.f("hint_ward", {"n": b.P.spells.ward.absorb})
		"focus": h = UIKit.f("hint_focus", {"n": b.P.focus_bonus})
		"interrupt": h = UIKit.f("hint_interrupt")
		"attack": h = UIKit.f("hint_attack", {"n": b.unit(uid).weapon})
		"defend": h = UIKit.f("hint_defend")
		"kay_cover": h = UIKit.f("hint_kay_cover", {"n": b.P.kay_cover_reduce})
	if why != "" and why != "dead": h += "\n" + why
	return h

func _set_hint(bt: Button) -> void:
	if not targeting.is_empty(): return
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
		_after_plan()
		return
	targeting = {"who": uid, "act": a}
	var valid := b.valid_targets(a)
	for k in unit_btn:
		unit_btn[k].disabled = not (k in valid)
	for bt in act_btns: bt.disabled = true
	hint = UIKit.t("ui_pick_target")
	_refresh_hint()
	if not valid.is_empty(): unit_btn[valid[0]].grab_focus()
	stage.queue_redraw()

func _on_target(uid: String) -> void:
	if targeting.is_empty(): return
	b.plan(targeting.who, targeting.act, uid)
	targeting = {}
	_after_plan()

func _after_plan() -> void:
	_rebuild()

func cancel_target() -> void:
	if targeting.is_empty(): return
	targeting = {}
	_rebuild()

func _on_clear() -> void:
	b.queue = []
	_rebuild()

func _on_end_turn() -> void:
	if mode != "plan": return
	targeting = {}
	b.end_turn()
	report = b.take_log()
	last_report = report.duplicate()
	_print(report)
	if auto:
		_after_report()
		return
	mode = "report"
	for bt in act_btns: bt.disabled = true
	_clear_btn.disabled = true
	_end_btn.disabled = true
	stage.queue_redraw()

func _after_report() -> void:
	report = []
	if b.result != "":
		_show_end()
		return
	mode = "plan"
	_end_btn.disabled = false
	_rebuild()

func _show_end() -> void:
	mode = "end"
	for x in act_btns: x.queue_free()
	act_btns = []
	_clear_btn.disabled = true
	_end_btn.disabled = true
	if b.result == "win":
		end_btns.append(_button(UIKit.t("ui_continue"), Vector2(540, 400), Vector2(200, 52), _finish.bind("win")))
	else:
		end_btns.append(_button(UIKit.t("ui_retry"), Vector2(430, 400), Vector2(200, 52), _retry))
		end_btns.append(_button(UIKit.t("ui_back_map"), Vector2(650, 400), Vector2(200, 52), _finish.bind("back")))
	if auto:
		print("  [战斗结束] %s；按钮：%s" % [UIKit.t("ui_win") if b.result == "win" else UIKit.t("ui_lose"), "、".join(PackedStringArray(end_btns.map(func(x): return x.text)))])
	else:
		end_btns[0].grab_focus.call_deferred()
	stage.queue_redraw()

func retry() -> void:
	_retry()

func _retry() -> void:
	b.restart()
	mode = "plan"
	_end_btn.disabled = false
	_rebuild()
	_print_log()

func _finish(r: String) -> void:
	visible = false
	for x in end_btns: x.queue_free()
	end_btns = []
	finished.emit(r)

## 键盘：选目标时 Esc 取消；看单子时确认继续
func handle(e: InputEvent) -> void:
	if mode == "report" and (e.is_action_pressed("confirm") or e.is_action_pressed("cancel") or (e is InputEventMouseButton and e.pressed)):
		_after_report()
	elif e.is_action_pressed("cancel"):
		cancel_target()

func _gui_input(e: InputEvent) -> void:
	if mode == "report" and e is InputEventMouseButton and e.pressed:
		accept_event()
		_after_report()

func _print_log() -> void:
	_print(b.take_log())

func _print(lines: Array) -> void:
	if auto:
		for l in lines: print("  ", l)

# ---------------- 画 ----------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), bg.darkened(0.55))

func _draw_stage() -> void:
	if b == null: return
	var font := UIKit.font()
	var ci := stage
	# 地面
	ci.draw_rect(Rect2(0, 0, STAGE.x, 488), bg)
	ci.draw_rect(Rect2(0, 330, STAGE.x, 158), bg.darkened(0.15))
	# 顶上一行：第几回合、这一仗叫什么
	ci.draw_rect(Rect2(0, 0, STAGE.x, 52), Color(UIKit.INK, 0.8))
	ci.draw_string(font, Vector2(24, 36), UIKit.f("ui_turn", {"n": b.turn}), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY, UIKit.GOLD)
	ci.draw_string(font, Vector2(0, 36), title, HORIZONTAL_ALIGNMENT_CENTER, STAGE.x, UIKit.BODY, UIKit.CREAM)
	# 箭头先画，压在人下面
	for it in b.intents:
		var e = b.unit(it.uid)
		if e == null or not e.alive or it.cancelled: continue
		var from := _pos_of(it.uid) + Vector2(-40, -134)
		var tgt: String = it.target if it.act == "attack" else (it.get("then_target", "") if it.act == "charge" else "")
		if it.act == "all":
			for a in b.allies(): _arrow(from, _pos_of(a.uid) + Vector2(0, -132), false)
		elif tgt != "":
			_arrow(from, _pos_of(tgt) + Vector2(0, -132), it.act == "charge")
	# 我方
	var al := b.allies(false)
	for i in al.size():
		_draw_unit(al[i], _ally_pos(i), true)
	var en := _shown_enemies()
	for i in en.size():
		_draw_unit(en[i], _enemy_pos(i, en.size()), false)
	# 我方头顶：排了什么、第几个出手
	for i in al.size():
		var q = b.planned(al[i].uid)
		if q == null: continue
		var order := b.queue.find(q) + 1
		var p := _ally_pos(i) + Vector2(-70, -196)
		var r := Rect2(p, Vector2(140, 60))
		UIKit.draw_frame(ci, r, Color(UIKit.NAVY, 0.95), UIKit.CREAM_DIM)
		_badge(r.position + Vector2(18, 18), order, UIKit.CREAM_DIM)
		ci.draw_string(font, r.position + Vector2(34, 28), _act_label(q.act).split("  ")[0], HORIZONTAL_ALIGNMENT_LEFT, 98, UIKit.BODY, UIKit.CREAM)
		if q.target != "":
			ci.draw_string(font, r.position + Vector2(12, 52), "→ " + b.unit(q.target).name, HORIZONTAL_ALIGNMENT_LEFT, 120, UIKit.SMALL * 2, UIKit.CREAM_DIM)
	# 敌人头顶的意图牌（最上层）
	for it in b.intents:
		var e = b.unit(it.uid)
		if e == null: continue
		_intent_plate(it, _pos_of(it.uid))
	# 下面一栏
	var panel := Rect2(8, 488, STAGE.x - 16, 224)
	UIKit.draw_frame(ci, panel)
	for i in al.size():
		var cols := [Vector2(24, 528), Vector2(456, 528), Vector2(668, 528)]
		var p: Vector2 = cols[i] if i < cols.size() else Vector2(668 + (i - 2) * 212, 528)
		ci.draw_string(font, p, al[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY, UIKit.GOLD if al[i].alive else UIKit.CREAM_DIM)
		if al[i].uid == "apprentice":
			_mana(p + Vector2(64, -14))
	if mode == "report": _draw_report()
	if mode == "end": _draw_end()

func _draw_unit(u: Dictionary, p: Vector2, ally: bool) -> void:
	var ci := stage
	var font := UIKit.font()
	var col := Color("#55575F")
	if ally:
		var look: Dictionary = Data.t("maps").actors.get(u.uid, {})
		col = UIKit.hexcol(look.get("color", ""))
	elif u.id == "merlin_shadow":
		col = Color("#3A3D52")
	elif u.id == "wolf_leader":
		col = Color("#4A4C55")
	var a := 1.0 if u.alive else 0.35
	if ally:
		ci.draw_rect(Rect2(p.x - 30, p.y - 112, 60, 112), Color(UIKit.INK, a))
		ci.draw_rect(Rect2(p.x - 26, p.y - 72, 52, 68), Color(col, a))
		ci.draw_rect(Rect2(p.x - 20, p.y - 108, 40, 36), Color(Color("#E8C4A0"), a))
	else:
		# 四足兽或人影的轮廓块
		if u.id == "merlin_shadow":
			ci.draw_rect(Rect2(p.x - 30, p.y - 120, 60, 120), Color(UIKit.INK, a))
			ci.draw_rect(Rect2(p.x - 26, p.y - 116, 52, 112), Color(col, a))
			ci.draw_line(p + Vector2(26, -90), p + Vector2(46, -10), Color("#C8C8D0", a), 5.0)
		else:
			ci.draw_rect(Rect2(p.x - 44, p.y - 56, 88, 50), Color(UIKit.INK, a))
			ci.draw_rect(Rect2(p.x - 40, p.y - 52, 80, 42), Color(col, a))
			ci.draw_rect(Rect2(p.x + 22, p.y - 72, 30, 30), Color(UIKit.INK, a))
			ci.draw_rect(Rect2(p.x + 25, p.y - 69, 24, 24), Color(col.lightened(0.1), a))
			for lx in [-34, -18, 14, 30]:
				ci.draw_rect(Rect2(p.x + lx, p.y - 12, 8, 12), Color(col.darkened(0.2), a))
	# 状态：护身、防御
	var tags := []
	if u.ward > 0: tags.append(UIKit.f("st_ward", {"n": u.ward}))
	if u.defend: tags.append(UIKit.t("act_defend"))
	if u.get("pending") != null: tags.append(UIKit.t("st_charging"))
	if not tags.is_empty():
		ci.draw_string(font, p + Vector2(-48, -128 if ally else -136), " ".join(tags), HORIZONTAL_ALIGNMENT_LEFT, 96, UIKit.SMALL, UIKit.DROP)
	# 名字和血
	ci.draw_string(font, p + Vector2(-64, 28), u.name, HORIZONTAL_ALIGNMENT_CENTER, 128, UIKit.BODY, Color(UIKit.CREAM, a))
	var bar := Rect2(p.x - 48, p.y + 36, 96, 12)
	ci.draw_rect(bar.grow(2), UIKit.INK)
	var ratio := float(u.hp) / float(u.max)
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), UIKit.HP_OK if ratio > 0.34 else UIKit.DANGER)
	ci.draw_string(font, p + Vector2(-48, 72), "%d/%d" % [u.hp, u.max], HORIZONTAL_ALIGNMENT_CENTER, 96, UIKit.SMALL * 2, Color(UIKit.CREAM, a))
	if not u.alive:
		ci.draw_line(p + Vector2(-40, -100), p + Vector2(40, -10), UIKit.DANGER, 4.0)

func _intent_plate(it: Dictionary, p: Vector2) -> void:
	var ci := stage
	var font := UIKit.font()
	var e = b.unit(it.uid)
	var r := Rect2(p + Vector2(-66, -196), Vector2(132, 64))
	var dead: bool = not e.alive or it.cancelled
	UIKit.draw_frame(ci, r, Color(UIKit.INK, 0.95) if not dead else Color(UIKit.NAVY, 0.7), UIKit.DANGER if not dead else UIKit.CREAM_DIM)
	_badge(r.position + Vector2(20, 20), it.order, UIKit.DANGER if not dead else UIKit.CREAM_DIM)
	var line1 := UIKit.t(it.move)
	var line2 := ""
	var num := ""
	match it.act:
		"attack":
			num = str(it.power)
			line2 = "→ " + b._name(it.target)
		"all":
			num = str(it.power)
			line2 = "→ " + UIKit.t("plate_all")
		"charge":
			line1 = UIKit.t("act_charge")
			num = str(int(it.then.get("power", 0)))
			line2 = UIKit.f("plate_charge", {"move": UIKit.t(it.then.get("move", "")), "n": ""}).strip_edges()
		"summon":
			num = str(it.count)
			line2 = UIKit.f("plate_summon", {"n": it.count})
		"defend":
			line1 = UIKit.t("act_defend")
	var c1 := UIKit.CREAM if not dead else UIKit.CREAM_DIM
	ci.draw_string(font, r.position + Vector2(38, 30), line1, HORIZONTAL_ALIGNMENT_LEFT, 60, UIKit.BODY, c1)
	if num != "":
		ci.draw_string(font, r.position + Vector2(r.size.x - 50, 34), num, HORIZONTAL_ALIGNMENT_RIGHT, 40, UIKit.BIG, UIKit.GOLD if not dead else UIKit.CREAM_DIM)
	var fs := UIKit.SMALL * 2 if font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2).x <= 116 else UIKit.SMALL
	ci.draw_string(font, r.position + Vector2(10, 56), line2, HORIZONTAL_ALIGNMENT_LEFT, 116, fs, c1)
	if dead:
		ci.draw_line(r.position + Vector2(8, r.size.y / 2), r.end - Vector2(8, r.size.y / 2), UIKit.CREAM_DIM, 3.0)

func _badge(c: Vector2, n: int, col: Color) -> void:
	stage.draw_circle(c, 13, UIKit.INK)
	stage.draw_circle(c, 11, col)
	stage.draw_string(UIKit.font(), c + Vector2(-12, 7), str(n), HORIZONTAL_ALIGNMENT_CENTER, 24, UIKit.SMALL * 2 if n < 10 else UIKit.SMALL, UIKit.INK)

func _arrow(from: Vector2, to: Vector2, dashed: bool) -> void:
	var ci := stage
	var col := UIKit.DANGER
	if dashed:
		var d := to - from
		var n := int(d.length() / 18.0)
		for i in n:
			if i % 2 == 0:
				ci.draw_line(from + d * (float(i) / n), from + d * (float(i + 1) / n), col, 4.0)
	else:
		ci.draw_line(from, to, Color(UIKit.INK, 0.8), 7.0)
		ci.draw_line(from, to, col, 4.0)
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	ci.draw_colored_polygon(PackedVector2Array([to, to - dir * 18 + side * 10, to - dir * 18 - side * 10]), col)

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

func _draw_report() -> void:
	var lines := report.filter(func(l): return not str(l).begins_with("["))
	var h := 96.0 + lines.size() * 34.0
	var r := Rect2(STAGE.x / 2 - 380, 250 - h / 2, 760, h)
	UIKit.draw_frame(stage, r, Color(UIKit.INK, 0.96))
	var y := r.position.y + 44
	for l in lines:
		stage.draw_string(UIKit.font(), Vector2(r.position.x + 32, y), str(l), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 64, UIKit.BODY, UIKit.CREAM)
		y += 34
	stage.draw_string(UIKit.font(), Vector2(r.position.x + 32, r.end.y - 20), UIKit.t("ui_press"), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2, UIKit.GOLD)

func _draw_end() -> void:
	var r := Rect2(STAGE.x / 2 - 300, 260, 600, 220)
	UIKit.draw_frame(stage, r, Color(UIKit.INK, 0.96))
	var t := UIKit.t("ui_win") if b.result == "win" else UIKit.t("ui_lose")
	stage.draw_string(UIKit.font(), Vector2(r.position.x, r.position.y + 76), t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UIKit.BIG + 12, UIKit.GOLD if b.result == "win" else UIKit.DANGER)
