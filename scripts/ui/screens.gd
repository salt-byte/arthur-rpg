class_name Screens
extends Control
## 盖在地图上的整屏：标题、看水面、章节过渡、新能力、预言簿、白盒结束；
## 成长和装备的六屏：战斗结算、挑奖励、技能树、背包、圣龛、菜单（SCREENS.md、progression.md、items.md）。
## 一次只开一个，关上时回调；要玩家做选择的屏把结果写进 data.choice。
## 看水面照 prophecy.md：画面切成一张静止的图，下面两三句具体的描写；全游戏最亮的就是这一圈（ART_DIRECTION 原则 2）。

const PANEL_KINDS := ["result", "boon", "skills", "bag", "shrine", "menu"]
const LINE := 40.0            # BODY 一行（字高 32 + 行距 8）
const ROW := 32.0             # 单行 label 的高
const STATS := ["hp", "mana_max", "spark", "ward", "focus", "start_block", "start_vuln_top", "after_heal"]

var main
var kind := ""
var data := {}
var cb := Callable()
var auto := false
var auto_hook := Callable()     # --playtest：画面打开时交给测试（截图后它自己关）
var _labels: Array = []
var _buttons: Array = []
var _t := 0.0
# 六屏用：面板、要画的条、头像、技能树 / 背包底下那一行、背包的选中和右下的说明
var _panel := Rect2()
var _bars: Array = []           # {"r": Rect2, "v": 0..1, "c": Color}
var _avatars: Array = []        # {"p": Vector2, "c": Color}
var _info: Label
var _sel := {}                  # 背包：{"bag": i} 或 {"slot": "staff"}
var _detail := {}               # 背包右下的几行 label
var _act: Button                # 背包的「装上 / 卸下」

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func is_open() -> bool:
	return kind != ""

func open(k: String, d := {}, callback := Callable()) -> void:
	_clear()
	kind = k
	data = d
	cb = callback
	visible = true
	call("_build_" + k)
	queue_redraw()
	if auto:
		print("  [画面] %s %s" % [k, _summary()])
		if auto_hook.is_valid():
			auto_hook.call(k)
		elif k in ["vision", "card", "unlock", "book", "skills", "bag", "menu", "shrine"]:
			close.call_deferred()
		elif k == "result":
			data["choice"] = "ok"
			close.call_deferred()
		elif k == "boon":
			data["choice"] = 0
			close.call_deferred()

func close() -> void:
	if kind == "": return
	_clear()
	kind = ""
	visible = false
	var c := cb
	cb = Callable()
	if c.is_valid(): c.call()

func _clear() -> void:
	for l in _labels: l.queue_free()
	for bt in _buttons: bt.queue_free()
	_labels = []
	_buttons = []
	_bars = []
	_avatars = []
	_panel = Rect2()
	_info = null
	_sel = {}
	_detail = {}
	_act = null

## 技能树、背包点了以后整屏重搭，焦点回到 key 那个按钮
func _rebuild(key := "") -> void:
	_clear()
	call("_build_" + kind)
	queue_redraw()
	if key != "" and not auto:
		for bt in _buttons:
			if str(bt.get_meta("key", "")) == key:
				bt.grab_focus()
				break

func _summary() -> String:
	return " / ".join(_labels.map(func(l): return l.text))

func _view() -> Vector2:
	return get_viewport_rect().size

func _add_label(text: String, pos: Vector2, width: float, sz := UIKit.BODY, col := UIKit.CREAM, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UIKit.label(text, sz, col)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.horizontal_alignment = align
	l.position = pos
	l.size = Vector2(width, 0)
	l.add_theme_constant_override("line_spacing", 8)
	add_child(l)
	_labels.append(l)
	return l

## 单行：放不下就截成省略号（窄屏时格子里的字）
func _add_line(text: String, pos: Vector2, width: float, sz := UIKit.BODY, col := UIKit.CREAM, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UIKit.label(text, sz, col)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.horizontal_alignment = align
	l.position = pos
	l.size = Vector2(width, UIKit.font().get_height(sz))
	add_child(l)
	_labels.append(l)
	return l

func _add_button(text: String, pos: Vector2, w: float, fn: Callable) -> Button:
	var bt := Button.new()
	bt.text = text
	bt.position = pos
	bt.size = Vector2(w, 52)
	bt.clip_text = true
	bt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bt.pressed.connect(fn)
	add_child(bt)
	_buttons.append(bt)
	return bt

## 没有字的按钮：字由盖在上面的 label 写（label 不挡鼠标）
func _add_cell(r: Rect2, fn: Callable, key := "") -> Button:
	var bt := Button.new()
	bt.position = r.position
	bt.size = r.size
	bt.pressed.connect(fn)
	if key != "": bt.set_meta("key", key)
	add_child(bt)
	_buttons.append(bt)
	return bt

func _focus(bt: Control) -> void:
	if bt and not auto: bt.grab_focus.call_deferred()

func _box(bg: Color, edge: Color, width := 4, center := true, grow := 0.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.draw_center = center
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(0)
	b.set_expand_margin_all(grow)
	return b

func _style(bt: Button, normal: StyleBoxFlat, hover: StyleBoxFlat) -> void:
	bt.add_theme_stylebox_override("normal", normal)
	bt.add_theme_stylebox_override("hover", hover)
	bt.add_theme_stylebox_override("pressed", hover)
	bt.add_theme_stylebox_override("disabled", normal)
	bt.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, UIKit.CREAM, 3, false, 4))

## 面板居中；高度要等内容排完才知道的，先放在 top，排完调 _fit_panel
func _panel_at(w: float, h: float, top := -1.0) -> Rect2:
	var v := _view()
	w = minf(w, v.x - 32)
	h = minf(h, v.y - 24)
	_panel = Rect2(roundf((v.x - w) / 2), roundf((v.y - h) / 2) if top < 0 else top, w, h)
	return _panel

func _fit_panel(y_end: float) -> void:
	_panel.size.y = y_end - _panel.position.y
	var top := maxf(12.0, roundf((_view().y - _panel.size.y) / 2))
	var dy := top - _panel.position.y
	for l in _labels: l.position.y += dy
	for bt in _buttons: bt.position.y += dy
	for b in _bars: b.r = Rect2(b.r.position + Vector2(0, dy), b.r.size)
	for a in _avatars: a.p = a.p + Vector2(0, dy)
	_panel.position.y = top

func _bar(r: Rect2, v: float, col: Color) -> void:
	_bars.append({"r": r, "v": clampf(v, 0.0, 1.0), "c": col})

func _chapter() -> int:
	if main and main.get("runner"):
		var c = main.runner.v("chapter")
		if c != null: return int(c)
	return 1

## 等级、经验条（结算、菜单共用）。gain 写在右边。返回下一行的 y
func _xp_block(x: float, y: float, w: float, gain := "") -> float:
	var p := Party.progress()
	var t := UIKit.f("ui_lv_cap", {"lv": p.level}) if p.at_cap else UIKit.f("ui_lv_xp", {"lv": p.level, "xp": p.xp, "need": p.need})
	_add_line(t, Vector2(x, y), w)
	if gain != "":
		_add_line(gain, Vector2(x, y), w, UIKit.BODY, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_bar(Rect2(x, y + 38, w, 12), float(p.ratio), UIKit.GOLD)
	return y + 66

## 三个人的血：[[名字, 当前, 上限], ...]
func _hp_block(x: float, y: float, w: float, rows: Array) -> float:
	_add_line(UIKit.t("ui_party_hp"), Vector2(x, y), w, UIKit.SMALL * 2, UIKit.CREAM_DIM)
	y += 38
	var name_w := 132.0
	var num_w := 120.0
	var bw := clampf(w - name_w - num_w - 24, 80, 320)
	for r in rows:
		var cur := int(r[1])
		var mx := maxi(1, int(r[2]))
		_add_line(str(r[0]), Vector2(x, y), name_w)
		var ratio := float(cur) / mx
		_bar(Rect2(x + name_w + 8, y + 10, bw, 12), ratio, UIKit.HP_OK if ratio > 0.3 else UIKit.DANGER)
		_add_line("%d / %d" % [cur, mx], Vector2(x + name_w + bw + 20, y), num_w)
		y += 36
	return y

func _choose(what) -> void:
	data["choice"] = what
	close()

# ---------------- 各个画面 ----------------
func _build_title() -> void:
	var v := _view()
	_add_label(UIKit.t("ui_title"), Vector2(0, v.y * 0.22), v.x, UIKit.HUGE, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(UIKit.t("ui_subtitle"), Vector2(0, v.y * 0.22 + 100), v.x, UIKit.BODY, UIKit.CREAM_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var y := v.y * 0.55
	var first := _add_button(UIKit.t("ui_new_game"), Vector2(v.x / 2 - 140, y), 280, func(): _choose("new"))
	if data.get("can_continue", false):
		_add_button(UIKit.t("ui_continue"), Vector2(v.x / 2 - 140, y + 68), 280, func(): _choose("continue"))
	_add_label(UIKit.t("ui_controls_menu"), Vector2(0, v.y - 64), v.x, UIKit.SMALL * 2, UIKit.CREAM_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	if not auto: first.grab_focus.call_deferred()

func _build_vision() -> void:
	var v := _view()
	var c := Vector2(v.x / 2, minf(290.0, v.y * 0.4))
	data["center"] = c
	data["r"] = minf(190.0, v.y * 0.27)
	_add_label(data.get("surface", ""), Vector2(0, c.y - data.r - 64), v.x, UIKit.BODY, UIKit.DROP, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(data.get("text", ""), Vector2(v.x / 2 - 400, c.y + data.r + 36), 800, UIKit.BODY, UIKit.CREAM)
	_add_label(UIKit.t("ui_press"), Vector2(0, v.y - 44), v.x, UIKit.SMALL * 2, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)

func _build_card() -> void:
	var v := _view()
	_add_label(UIKit.f("ui_chapter", {"n": data.n}), Vector2(0, v.y * 0.36), v.x, UIKit.BIG, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(UIKit.t("chapter_%d" % int(data.n)), Vector2(0, v.y * 0.36 + 60), v.x, UIKit.HUGE, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(UIKit.t("ui_press"), Vector2(0, v.y - 64), v.x, UIKit.SMALL * 2, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)

func _build_unlock() -> void:
	var v := _view()
	var r := Rect2(v.x / 2 - 320, v.y / 2 - 150, 640, 280)
	data["rect"] = r
	_add_label(UIKit.t("ui_new_ability"), r.position + Vector2(36, 28), 560, UIKit.BODY, UIKit.GOLD)
	_add_label(UIKit.t(data.popup.name), r.position + Vector2(36, 66), 560, UIKit.BIG, UIKit.CREAM)
	_add_label(UIKit.t(data.popup.effect), r.position + Vector2(36, 124), 560, UIKit.BODY, UIKit.CREAM)
	_add_label(UIKit.t(data.popup.origin), r.position + Vector2(36, 166), 560, UIKit.BODY, UIKit.CREAM_DIM)
	_add_label(UIKit.t("ui_press"), r.position + Vector2(36, 232), 560, UIKit.SMALL * 2, UIKit.GOLD)

func _build_book() -> void:
	var v := _view()
	var r := Rect2(v.x / 2 - 480, maxf(24.0, v.y / 2 - 300), 960, minf(600.0, v.y - 48))
	data["rect"] = r
	_add_label(UIKit.t("ui_book"), r.position + Vector2(40, 28), 880, UIKit.BIG, UIKit.DROP)
	var y := r.position.y + 88
	var pages: Array = GS.S.book
	if pages.is_empty():
		_add_label(UIKit.t("ui_book_empty"), Vector2(r.position.x + 40, y), 880)
	for p in pages:
		var vd := Data.vision(p.decision)
		var ch := _chapter_of(vd.get("seen_at", ""))
		var l := _add_label(UIKit.f("ui_book_page", {"ch": ch, "surface": vd.get("surface", "")}), Vector2(r.position.x + 40, y), 880, UIKit.BODY, UIKit.GOLD)
		y += 40
		l = _add_label(UIKit.f("ui_book_seen", {"t": UIKit.t(vd.get("text", ""))}), Vector2(r.position.x + 40, y), 880)
		y += 40 * _rows(l.text, 880)
		var picked := str(main.runner.v(p.decision)) if main else ""
		var told := UIKit.t("book_told_" + picked) if picked != "" else UIKit.t("ui_book_undecided")
		l = _add_label(UIKit.f("ui_book_told", {"t": told}), Vector2(r.position.x + 40, y), 880)
		y += 40 * _rows(l.text, 880)
		for a in p.get("after", []):
			l = _add_label(UIKit.f("ui_book_after", {"t": UIKit.t(a)}), Vector2(r.position.x + 40, y), 880, UIKit.BODY, UIKit.DROP)
			y += 40 * _rows(l.text, 880)
		y += 16
	_add_label(UIKit.t("ui_close"), Vector2(r.position.x + 40, r.end.y - 48), 880, UIKit.SMALL * 2, UIKit.GOLD)

func _chapter_of(node: String) -> int:
	return int(node.substr(1, 1)) if node.length() == 4 else 1

func _rows(t: String, w: float) -> int:
	return int(ceil(UIKit.font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY).x / w)) if t != "" else 1

func _build_end() -> void:
	var v := _view()
	var r := Rect2(v.x / 2 - 420, v.y / 2 - 230, 840, 460)
	data["rect"] = r
	_add_label(UIKit.t("ui_slice_end"), r.position + Vector2(40, 32), 760, UIKit.BIG, UIKit.GOLD)
	var picked := str(main.runner.v("D1")) if main else ""
	var y := r.position.y + 104
	if picked != "":
		var l := _add_label(UIKit.f("ui_slice_d1", {"t": UIKit.t("book_told_" + picked)}), Vector2(r.position.x + 40, y), 760)
		y += 40 * _rows(l.text, 760) + 8
		var page := GS.book_page("D1")
		for a in page.get("after", []):
			l = _add_label(UIKit.f("ui_book_after", {"t": UIKit.t(a)}), Vector2(r.position.x + 40, y), 760, UIKit.BODY, UIKit.DROP)
			y += 40 * _rows(l.text, 760)
	var bt := _add_button(UIKit.t("ui_restart"), Vector2(v.x / 2 - 140, r.end.y - 84), 280, func(): _choose("restart"))
	if not auto: bt.grab_focus.call_deferred()

# ---------------- 战斗结算 ----------------
## data：{title, xp, level_up, drops: [字符串], hp: [[名字, 当前, 上限]]} → data.choice = "ok" / "bag"
func _build_result() -> void:
	var p := _panel_at(860, 0, 0)
	var x := p.position.x + 32
	var w := p.size.x - 64
	var y := p.position.y + 24
	_add_line(UIKit.f("ui_res_title", {"t": str(data.get("title", ""))}), Vector2(x, y), w, UIKit.BIG, UIKit.GOLD)
	y += 64
	y = _xp_block(x, y, w, UIKit.f("ui_xp_gain", {"n": int(data.get("xp", 0))}))
	if int(data.get("level_up", 0)) > 0:
		_add_line(UIKit.f("ui_level_up", {"n": Party.level()}), Vector2(x, y), w, UIKit.BODY, UIKit.GOLD)
		y += LINE
	elif Party.progress().at_cap:
		_add_line(UIKit.t("ui_res_cap"), Vector2(x, y), w, UIKit.BODY, UIKit.CREAM_DIM)
		y += LINE
	y += 4
	_add_line(UIKit.t("ui_res_drops"), Vector2(x, y), w, UIKit.SMALL * 2, UIKit.CREAM_DIM)
	y += 38
	var drops: Array = data.get("drops", [])
	if drops.is_empty():
		_add_line(UIKit.t("ui_res_nodrop"), Vector2(x, y), w)
		y += LINE
	for d in drops:
		_add_label(str(d), Vector2(x, y), w)
		y += LINE * maxi(1, UIKit.wrap(str(d), w).size())
	y += 8
	y = _hp_block(x, y, w, data.get("hp", []))
	y += 20
	var bw := minf(220.0, (w - 24) / 2)
	var ok := _add_button(UIKit.t("ui_res_ok"), Vector2(p.position.x + p.size.x / 2 - bw - 12, y), bw, func(): _choose("ok"))
	_add_button(UIKit.t("ui_res_bag"), Vector2(p.position.x + p.size.x / 2 + 12, y), bw, func(): _choose("bag"))
	_fit_panel(y + 52 + 24)
	_focus(ok)

# ---------------- 挑奖励 ----------------
## data：{cards: [{id, who, name, text, effect}], level} → data.choice = 卡的下标（int）
func _build_boon() -> void:
	var cards: Array = data.get("cards", [])
	var p := _panel_at(1040, 0, 0)
	var x := p.position.x + 32
	var w := p.size.x - 64
	var y := p.position.y + 24
	var title := UIKit.f("ui_boon_title", {"n": int(data.get("level", Party.level()))})
	_add_label(title, Vector2(x, y), w, UIKit.BIG, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	y += 56 * maxi(1, UIKit.wrap(title, w, UIKit.BIG).size()) + 4
	_add_label(UIKit.t("ui_boon_hint"), Vector2(x, y), w, UIKit.SMALL * 2, UIKit.CREAM_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	y += LINE + 8
	var n := maxi(1, cards.size())
	var gap := 20.0
	var cw := floorf((w - gap * (n - 1)) / n)
	var tw := cw - 32
	var any_who := cards.any(func(c): return str(c.get("who", "")) != "")
	var ch := 0.0
	for c in cards:
		var h := 24.0 + (64.0 if any_who else 0.0) + LINE * UIKit.wrap(str(c.get("name", "")), tw).size() + 12 + LINE * UIKit.wrap(str(c.get("text", "")), tw).size() + 16
		ch = maxf(ch, h)
	ch = maxf(ch, 200.0)
	var first: Button
	for i in cards.size():
		var c: Dictionary = cards[i]
		var r := Rect2(x + i * (cw + gap), y, cw, ch)
		var bt := _add_cell(r, func(): _choose(i), "card:%d" % i)
		if first == null: first = bt
		var yy := r.position.y + 24
		if any_who:
			var who := str(c.get("who", ""))
			if who != "":
				var actors: Dictionary = Data.t("maps").get("actors", {})
				_avatars.append({"p": Vector2(r.position.x + cw / 2, yy + 26), "c": UIKit.hexcol(actors.get(who, {}).get("color", ""))})
			yy += 64
		var nm := str(c.get("name", ""))
		_add_label(nm, Vector2(r.position.x + 16, yy), tw, UIKit.BODY, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		yy += LINE * UIKit.wrap(nm, tw).size() + 12
		_add_label(str(c.get("text", "")), Vector2(r.position.x + 16, yy), tw, UIKit.BODY, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_fit_panel(y + ch + 32)
	_focus(first)

# ---------------- 技能树 ----------------
## data：{respec: bool（圣龛打开时）, in_battle: bool（只能看）}。点格子直接 Party.buy，不写 choice
func _build_skills() -> void:
	var p := _panel_at(1180, 696)
	var x := p.position.x + 24
	var w := p.size.x - 48
	var y := p.position.y + 20
	var in_battle: bool = data.get("in_battle", false)
	_add_line(UIKit.t("ui_sk_title"), Vector2(x, y), w, UIKit.BIG, UIKit.GOLD)
	_add_line(UIKit.f("ui_sk_points", {"n": Party.points()}), Vector2(x, y + 10), w, UIKit.BODY, UIKit.GOLD if Party.points() > 0 else UIKit.CREAM_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	y += 60
	var ST: Dictionary = Data.t("progression").skill_tree
	var trees: Array = ST.trees.keys()
	var cols := {}
	for id in ST.nodes:
		var t: String = ST.nodes[id].tree
		if not cols.has(t): cols[t] = []
		cols[t].append(id)
	for t in cols:
		cols[t].sort_custom(func(a, b): return int(ST.nodes[a].level_req) < int(ST.nodes[b].level_req))
	var gx := 12.0
	var gy := 8.0
	var cw := floorf((w - gx * (trees.size() - 1)) / trees.size())
	var bottom := p.end.y - 20 - 52 - 12 - ROW - 12
	var ch := clampf(floorf((bottom - (y + 40) - gy * 3) / 4), 100, 132)
	var first: Button
	for ti in trees.size():
		var t: String = trees[ti]
		var cx := x + ti * (cw + gx)
		var spent := 0
		for id in cols.get(t, []): spent += Party.rank(id)
		_add_line(UIKit.f("ui_sk_tree", {"t": UIKit.t(ST.trees[t].name), "n": spent}), Vector2(cx, y), cw, UIKit.BODY, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		var ids: Array = cols.get(t, [])
		for ri in ids.size():
			var bt := _skill_cell(ids[ri], Rect2(cx, y + 40 + ri * (ch + gy), cw, ch), in_battle)
			if first == null and bt.get_meta("can", false): first = bt
	y = bottom + 12
	_info = _add_line("", Vector2(x, y), w, UIKit.SMALL * 2, UIKit.CREAM_DIM)
	_set_info(UIKit.t("ui_sk_battle") if in_battle else UIKit.t("ui_sk_hint"), Color("#E07A5F") if in_battle else UIKit.CREAM_DIM)
	var by := p.end.y - 20 - 52
	var close_bt := _add_button(UIKit.t("ui_btn_close"), Vector2(p.end.x - 24 - 200, by), 200, close)
	close_bt.set_meta("key", "close")
	if data.get("respec", false) and not in_battle:
		var rb := _add_button(UIKit.t("ui_sk_respec"), Vector2(p.end.x - 24 - 200 - 16 - 240, by), 240, _on_respec)
		rb.set_meta("key", "respec")
	_focus(first if first else close_bt)

## 一格：名字 + 点数 / 一句效果 / 要几级（或为什么点不了）。能点金边、点不了灰、点过填色
func _skill_cell(id: String, r: Rect2, in_battle: bool) -> Button:
	var d := Party.node_def(id)
	var rk := Party.rank(id)
	var mx := int(d.get("max_rank", 1))
	var cbuy := Party.can_buy(id)
	var can: bool = cbuy.ok and not in_battle
	var bt := _add_cell(r, func(): _on_skill(id), "sk:" + id)
	bt.set_meta("can", can)
	var bg := UIKit.NAVY.lerp(UIKit.GOLD, 0.38) if rk > 0 else (UIKit.NAVY_2 if can else Color("#151a2c"))
	var edge := UIKit.GOLD if can else (UIKit.INK if rk > 0 else Color(UIKit.CREAM_DIM, 0.22))
	var width := 4 if can else 2
	_style(bt, _box(bg, edge, width), _box(bg.lightened(0.08), UIKit.GOLD if can else UIKit.CREAM_DIM, width))
	var dim := rk == 0 and not can
	var c_main := Color(UIKit.CREAM, 0.5) if dim else UIKit.CREAM
	var c_sub := Color(UIKit.CREAM_DIM, 0.5) if dim else (UIKit.CREAM if rk > 0 else UIKit.CREAM_DIM)
	var ix := r.position.x + 12
	var iw := r.size.x - 24
	var y0 := r.position.y + maxf(6.0, (r.size.y - 3 * ROW) / 2)
	var rank_t := UIKit.f("ui_sk_rank", {"r": rk, "max": mx})
	var rank_w := UIKit.font().get_string_size(rank_t, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY).x
	_add_line(UIKit.t(d.get("name", id)), Vector2(ix, y0), iw - rank_w - 8, UIKit.BODY, c_main)
	_add_line(rank_t, Vector2(ix, y0), iw, UIKit.BODY, UIKit.GOLD if can or rk > 0 else c_sub, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_line(node_effect(d), Vector2(ix, y0 + ROW), iw, UIKit.SMALL * 2, c_sub)
	var lvl := Party.level()
	var need := int(d.get("level_req", 1)) + rk
	var foot := UIKit.f("ui_sk_req", {"n": need})
	var warn := Color("#E07A5F")
	var c_foot := c_sub
	if rk >= mx:
		foot = UIKit.t("ui_sk_no_max")
	elif lvl < need:
		c_foot = warn if not dim else Color(warn, 0.7)
	elif cbuy.get("reason", "") == "missing_prereq":
		foot = UIKit.t("ui_sk_no_prereq")
		c_foot = Color(warn, 0.7)
	_add_line(foot, Vector2(ix, y0 + ROW * 2), iw, UIKit.SMALL * 2, c_foot)
	bt.mouse_entered.connect(func(): _skill_info(id))
	bt.focus_entered.connect(func(): _skill_info(id))
	return bt

func _set_info(t: String, col := UIKit.CREAM_DIM) -> void:
	if _info == null: return
	_info.text = t
	_info.add_theme_color_override("font_color", col)

## 停在格子上：名字、效果、花几点法力，能不能点、为什么
func _skill_info(id: String) -> void:
	var d := Party.node_def(id)
	var eff := node_effect(d)
	var e: Dictionary = d.get("effect", {})
	if e.has("new_spell"): eff += UIKit.f("ui_sk_cost", {"n": int(e.get("mana", 0))})
	var head := UIKit.f("ui_sk_info", {"name": UIKit.t(d.get("name", id)), "eff": eff})
	if data.get("in_battle", false):
		_set_info(head + " · " + UIKit.t("ui_sk_battle"), Color("#E07A5F"))
		return
	var c := Party.can_buy(id)
	if c.ok:
		_set_info(head + " · " + UIKit.t("ui_sk_can"), UIKit.GOLD)
	else:
		_set_info(head + " · " + skill_reason(c), UIKit.CREAM)

## can_buy 的 reason → 玩家看得懂的一句
static func skill_reason(c: Dictionary) -> String:
	match str(c.get("reason", "")):
		"level_too_low", "need_level": return UIKit.f("ui_sk_req", {"n": int(c.get("need", 1))})
		"missing_prereq": return UIKit.t("ui_sk_no_prereq")
		"no_points": return UIKit.t("ui_sk_no_points")
		"max_rank": return UIKit.t("ui_sk_no_max")
	return UIKit.t("ui_sk_cannot")

func _on_skill(id: String) -> void:
	if data.get("in_battle", false):
		_skill_info(id)
		return
	var c := Party.can_buy(id)
	if not c.ok:
		_skill_info(id)
		return
	var r := Party.buy(id)
	print("  [加点] %s → %d / %d，剩 %d 点" % [Party.node_def(id).get("name", id), Party.rank(id), int(Party.node_def(id).get("max_rank", 1)), Party.points()])
	_rebuild("sk:" + id)
	if not r.get("ok", false): _set_info(skill_reason(r), UIKit.CREAM)

func _on_respec() -> void:
	var r := Party.respec()
	print("  [洗点] 退回 %d 点，现在 %d 点" % [int(r.get("refunded", 0)), Party.points()])
	_rebuild("respec")
	_set_info(UIKit.f("ui_sk_respec_done", {"n": Party.points()}), UIKit.GOLD)

## 技能格的效果拼成一句（覆盖 progression.json 16 格用到的键）
static func node_effect(d: Dictionary) -> String:
	var e: Dictionary = d.get("effect", {})
	if e.has("new_spell"):
		var what := ""
		if e.get("target", "") == "all_enemies" and e.has("damage"): what = UIKit.f("eff_all_damage", {"n": e.damage})
		elif e.get("target", "") == "all_enemies" and e.has("weak"): what = UIKit.f("eff_all_weak", {"n": e.weak})
		elif int(e.get("targets", 1)) >= 2: what = UIKit.t("eff_two_targets")
		elif e.has("weak"): what = UIKit.f("eff_one_weak", {"n": e.weak})
		return UIKit.f("eff_new_spell", {"t": what})
	var spell := str(e.get("spell", ""))
	if spell == "spark" and e.has("damage"): return UIKit.f("eff_spark_damage", {"n": e.damage})
	if spell == "spark" and e.has("vulnerable"): return UIKit.f("eff_spark_vuln", {"n": e.vulnerable})
	if spell == "focus" and e.has("restore_mana"): return UIKit.f("eff_focus", {"n": e.restore_mana})
	if spell == "interrupt" and e.has("mana"): return UIKit.f("eff_interrupt", {"n": absi(int(e.mana))})
	if spell == "ward" and e.has("block"): return UIKit.f("eff_ward_block", {"n": e.block})
	if spell == "ward" and e.has("targets"): return UIKit.t("eff_ward_two")
	if e.has("mana_max"): return UIKit.f("eff_mana_max", {"n": e.mana_max})
	if e.has("mana_regen"): return UIKit.f("eff_mana_regen", {"n": e.mana_regen})
	if e.has("apprentice_hp"): return UIKit.f("eff_hp", {"n": e.apprentice_hp})
	if e.has("once_per_battle_survive_at"): return UIKit.f("eff_survive", {"n": e.once_per_battle_survive_at})
	if e.has("battle_start_all_enemies_vulnerable"): return UIKit.f("eff_see", {"n": e.battle_start_all_enemies_vulnerable})
	if e.has("on_interrupt_vulnerable"): return UIKit.f("eff_lever", {"n": e.on_interrupt_vulnerable})
	return ""

# ---------------- 背包 ----------------
## data：{}（不写 choice）。点背包里一件 → 右下说明和比较 →「装上」；点身上的格子 →「卸下」
func _build_bag() -> void:
	var p := _panel_at(1220, 696)
	var x := p.position.x + 24
	var w := p.size.x - 48
	var wide := p.size.x >= 1060
	var ch := _chapter()
	var st := Party.ap_stats()
	var IT: Dictionary = Data.t("items")
	var bag: Array = GS.S.bag
	var bag_max := int(IT.get("bag_size", 20))
	var silver := UIKit.f("ui_bag_silver", {"n": int(GS.S.silver)})
	var potions := "%s · %s" % [UIKit.f("ui_bag_potion", {"t": str(Party.potion_def("potion_hp").get("name", "")), "n": Party.potions("potion_hp")}),
		UIKit.f("ui_bag_potion", {"t": str(Party.potion_def("potion_mana").get("name", "")), "n": Party.potions("potion_mana")})]
	var count := UIKit.f("ui_bag_count", {"n": bag.size(), "max": bag_max})
	var y := p.position.y + 16
	_add_line(UIKit.t("ui_bag_title"), Vector2(x, y), w, UIKit.BIG, UIKit.GOLD)
	var stat_lines := [UIKit.f("ui_bag_hp", {"cur": Party.cur_hp("apprentice", ch), "max": st.hp}),
		"%s %d" % [UIKit.t("stat_mana_max"), st.mana_max], "%s %d" % [UIKit.t("stat_spark"), st.spark],
		"%s %d" % [UIKit.t("stat_ward"), st.ward], "%s %d" % [UIKit.t("stat_focus"), st.focus]]
	var gx: float
	var gw: float
	var gy: float
	var cols: int
	if wide:
		var lw := 340.0
		y += 68
		_add_line(UIKit.t("ui_bag_worn"), Vector2(x, y), lw, UIKit.SMALL * 2, UIKit.CREAM_DIM)
		for i in 3:
			_slot_cell(["staff", "clothes", "charm"][i], Rect2(x, y + 32 + i * 60, lw, 52))
		var sy := y + 32 + 3 * 60 + 8
		for i in stat_lines.size():
			_add_line(stat_lines[i], Vector2(x, sy + i * ROW), lw)
		sy += stat_lines.size() * ROW + 12
		_add_line(potions, Vector2(x, sy), lw)
		_add_line(silver, Vector2(x, sy + ROW), lw)
		gx = x + lw + 28
		gw = w - lw - 28
		_add_line(count, Vector2(gx, y), gw, UIKit.SMALL * 2, UIKit.CREAM_DIM)
		gy = y + 32
		cols = 2
	else:
		_add_line(silver, Vector2(x, y + 10), w, UIKit.BODY, UIKit.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 64
		var sw := floorf((w - 16) / 3)
		for i in 3:
			_slot_cell(["staff", "clothes", "charm"][i], Rect2(x + i * (sw + 8), y, sw, 52))
		y += 60
		_add_line(" · ".join(PackedStringArray(stat_lines)), Vector2(x, y), w)
		_add_line("%s · %s" % [potions, count], Vector2(x, y + ROW), w, UIKit.BODY, UIKit.CREAM_DIM)
		gx = x
		gw = w
		gy = y + ROW * 2 + 8
		cols = 3
	var n := maxi(bag_max, bag.size())
	var rows := int(ceil(float(n) / cols))
	var rh := 36.0
	var cwid := floorf((gw - 8 * (cols - 1)) / cols)
	for i in n:
		var r := Rect2(gx + (i % cols) * (cwid + 8), gy + floorf(float(i) / cols) * (rh + 3), cwid, rh)
		_bag_cell(i, r, bag[i] if i < bag.size() else null)
	# 右下：选中那件 | 身上同一格那件；下面一行是装上以后的变化
	var dy := gy + rows * (rh + 3) + 8
	var dx := gx
	var dw := gw
	var half := floorf((dw - 16) / 2)
	_detail = {
		"a_name": _add_line("", Vector2(dx, dy), half),
		"b_name": _add_line("", Vector2(dx + half + 16, dy), half),
		"a_lines": _add_line("", Vector2(dx, dy + ROW), half, UIKit.SMALL * 2, UIKit.CREAM),
		"b_lines": _add_line("", Vector2(dx + half + 16, dy + ROW), half, UIKit.SMALL * 2, UIKit.CREAM_DIM),
		"delta": _add_line("", Vector2(dx, dy + ROW * 2), dw),
	}
	var by := p.end.y - 20 - 52
	var close_bt := _add_button(UIKit.t("ui_btn_close"), Vector2(p.end.x - 24 - 200, by), 200, close)
	close_bt.set_meta("key", "close")
	_act = _add_button(UIKit.t("ui_bag_equip"), Vector2(p.end.x - 24 - 200 - 16 - 200, by), 200, _on_bag_act)
	_act.set_meta("key", "act")
	_show_detail()
	var first: Button
	for bt in _buttons:
		if str(bt.get_meta("key", "")).begins_with("bag:") and not bt.disabled:
			first = bt
			break
	_focus(first if first else close_bt)

func _slot_cell(slot: String, r: Rect2) -> void:
	var it = GS.S.equip.get(slot)
	var bt := _add_cell(r, func(): _pick_slot(slot, true), "slot:" + slot)
	var sel: bool = _sel.get("slot", "") == slot
	_style(bt, _box(UIKit.NAVY_2, UIKit.GOLD if sel else UIKit.INK, 3), _box(UIKit.NAVY_2.lightened(0.1), UIKit.GOLD if sel else UIKit.CREAM_DIM, 3))
	bt.focus_entered.connect(func(): _pick_slot(slot, false))
	var lab_w := 72.0
	_add_line(UIKit.t("ui_slot_" + slot), Vector2(r.position.x + 12, r.position.y + 10), lab_w, UIKit.BODY, UIKit.CREAM_DIM)
	if it == null:
		_add_line(UIKit.t("ui_bag_empty"), Vector2(r.position.x + 12 + lab_w, r.position.y + 10), r.size.x - lab_w - 24, UIKit.BODY, Color(UIKit.CREAM_DIM, 0.6))
	else:
		var inf := Party.item_info(it)
		_add_line(str(inf.name), Vector2(r.position.x + 12 + lab_w, r.position.y + 10), r.size.x - lab_w - 24, UIKit.BODY, UIKit.hexcol(inf.color))

func _bag_cell(i: int, r: Rect2, it) -> void:
	var bt := _add_cell(r, func(): _pick_bag(i, true), "bag:%d" % i)
	if it == null:
		bt.disabled = true
		bt.focus_mode = Control.FOCUS_NONE
		_style(bt, _box(Color(UIKit.INK, 0.35), Color(UIKit.CREAM_DIM, 0.12), 2), _box(Color(UIKit.INK, 0.35), Color(UIKit.CREAM_DIM, 0.12), 2))
		return
	var sel: bool = int(_sel.get("bag", -1)) == i
	_style(bt, _box(UIKit.NAVY_2, UIKit.GOLD if sel else UIKit.INK, 3 if sel else 2), _box(UIKit.NAVY_2.lightened(0.1), UIKit.GOLD if sel else UIKit.CREAM_DIM, 3 if sel else 2))
	bt.focus_entered.connect(func(): _pick_bag(i, false))
	var inf := Party.item_info(it)
	_add_line(UIKit.f("ui_bag_item", {"t": inf.name, "r": inf.rarity_name}), Vector2(r.position.x + 10, r.position.y + 2), r.size.x - 20, UIKit.BODY, UIKit.hexcol(inf.color))

## 选中背包第 i 件。again：已经选中时再点一下 → 焦点跳到「装上」
func _pick_bag(i: int, again: bool) -> void:
	if again and int(_sel.get("bag", -1)) == i and _act and not _act.disabled:
		_focus(_act)
		return
	_sel = {"bag": i}
	_mark_selected("bag:%d" % i)
	_show_detail()

func _pick_slot(slot: String, again: bool) -> void:
	if again and _sel.get("slot", "") == slot and _act and not _act.disabled:
		_focus(_act)
		return
	_sel = {"slot": slot}
	_mark_selected("slot:" + slot)
	_show_detail()

## 选中的那格换成金边，别的换回去（不重搭，焦点不动）
func _mark_selected(key: String) -> void:
	for bt in _buttons:
		var k := str(bt.get_meta("key", ""))
		if not (k.begins_with("bag:") or k.begins_with("slot:")) or bt.disabled: continue
		var on := k == key
		var wdt := 3 if on or k.begins_with("slot:") else 2
		_style(bt, _box(UIKit.NAVY_2, UIKit.GOLD if on else UIKit.INK, wdt), _box(UIKit.NAVY_2.lightened(0.1), UIKit.GOLD if on else UIKit.CREAM_DIM, wdt))

## 学徒的数，假装 slot 那一格换成 item（null 是脱掉）
func _stats_with(slot: String, item) -> Dictionary:
	var saved = GS.S.equip.get(slot)
	GS.S.equip[slot] = item
	var s := Party.ap_stats()
	GS.S.equip[slot] = saved
	return s

## 「星火 2 → 4 · 血 14 → 16」；没变化返回 ""
func _delta(a: Dictionary, b: Dictionary) -> Array:
	var parts := []
	var up := 0
	var down := 0
	for k in STATS:
		var x := int(a.get(k, 0))
		var y := int(b.get(k, 0))
		if x == y: continue
		parts.append(UIKit.f("ui_bag_cmp", {"t": UIKit.t("stat_" + k), "a": x, "b": y}))
		if y > x: up += 1
		else: down += 1
	var col := UIKit.CREAM
	if up > 0 and down == 0: col = UIKit.HP_OK
	elif down > 0 and up == 0: col = Color("#E07A5F")
	return [" · ".join(PackedStringArray(parts)), col]

func _item_head(inf: Dictionary) -> String:
	return UIKit.f("ui_bag_item", {"t": inf.name, "r": inf.rarity_name})

func _set_line(key: String, t: String, col := UIKit.CREAM) -> void:
	var l: Label = _detail.get(key)
	if l == null: return
	l.text = t
	l.add_theme_color_override("font_color", col)

func _show_detail() -> void:
	if _detail.is_empty(): return
	for k in _detail: _set_line(k, "")
	if _act:
		_act.disabled = true
		_act.text = UIKit.t("ui_bag_equip")
	if _sel.has("bag"):
		var i := int(_sel.bag)
		if i >= GS.S.bag.size(): return
		var it = GS.S.bag[i]
		var inf := Party.item_info(it)
		var slot: String = inf.slot
		_set_line("a_name", _item_head(inf), UIKit.hexcol(inf.color))
		_set_line("a_lines", " · ".join(PackedStringArray(inf.lines)), UIKit.CREAM)
		var worn = GS.S.equip.get(slot)
		if worn == null:
			_set_line("b_name", UIKit.f("ui_bag_vs", {"t": UIKit.t("ui_bag_empty")}), UIKit.CREAM_DIM)
		else:
			var winf := Party.item_info(worn)
			_set_line("b_name", UIKit.f("ui_bag_vs", {"t": winf.name}), UIKit.hexcol(winf.color))
			_set_line("b_lines", " · ".join(PackedStringArray(winf.lines)), UIKit.CREAM_DIM)
		var d := _delta(Party.ap_stats(), _stats_with(slot, it))
		_set_line("delta", UIKit.f("ui_bag_if_equip", {"t": d[0] if d[0] != "" else UIKit.t("ui_bag_nochange")}), d[1])
		if _act:
			_act.disabled = false
			_act.text = UIKit.t("ui_bag_equip")
	elif _sel.has("slot"):
		var slot: String = _sel.slot
		var it = GS.S.equip.get(slot)
		if it == null:
			_set_line("a_name", UIKit.f("ui_bag_slot_empty", {"t": UIKit.t("ui_slot_" + slot)}), UIKit.CREAM_DIM)
			return
		var inf := Party.item_info(it)
		_set_line("a_name", _item_head(inf), UIKit.hexcol(inf.color))
		_set_line("b_name", UIKit.t("ui_bag_on_body"), UIKit.CREAM_DIM)
		_set_line("a_lines", " · ".join(PackedStringArray(inf.lines)), UIKit.CREAM)
		var d := _delta(Party.ap_stats(), _stats_with(slot, null))
		_set_line("delta", UIKit.f("ui_bag_if_unequip", {"t": d[0] if d[0] != "" else UIKit.t("ui_bag_nochange")}), d[1])
		if _act:
			_act.disabled = false
			_act.text = UIKit.t("ui_bag_unequip")
	else:
		_set_line("a_name", UIKit.t("ui_bag_pick"), UIKit.CREAM_DIM)

func _on_bag_act() -> void:
	var ch := _chapter()
	if _sel.has("bag"):
		var i := int(_sel.bag)
		if i >= GS.S.bag.size(): return
		var inf := Party.item_info(GS.S.bag[i])
		Party.equip(i, ch)
		print("  [换装] 装上 %s" % inf.name)
		_rebuild("slot:" + str(inf.slot))
	elif _sel.has("slot"):
		var slot: String = _sel.slot
		if GS.S.equip.get(slot) == null: return
		var nm := str(Party.item_info(GS.S.equip[slot]).name)
		if Party.unequip(slot, ch):
			print("  [换装] 卸下 %s" % nm)
			_rebuild("bag:%d" % (GS.S.bag.size() - 1))
		else:
			_set_line("delta", UIKit.t("ui_bag_full_unequip"), Color("#E07A5F"))

# ---------------- 圣龛 ----------------
## data：{name, others: [{id, name}]} → data.choice = "pray" / "travel:<id>" / "skills" / ""
func _build_shrine() -> void:
	var p := _panel_at(600, 0, 0)
	var x := p.position.x + 40
	var w := p.size.x - 80
	var y := p.position.y + 24
	_add_label(str(data.get("name", "")), Vector2(x, y), w, UIKit.BIG, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	y += 56 * maxi(1, UIKit.wrap(str(data.get("name", "")), w, UIKit.BIG).size()) + 4
	_add_label(UIKit.t("ui_shrine_hint"), Vector2(x, y), w, UIKit.SMALL * 2, UIKit.CREAM_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	y += LINE * maxi(1, UIKit.wrap(UIKit.t("ui_shrine_hint"), w).size()) + 12
	var first := _add_button(UIKit.t("ui_shrine_pray"), Vector2(x, y), w, func(): _choose("pray"))
	y += 64
	var others: Array = data.get("others", [])
	if others.is_empty():
		_add_label(UIKit.t("ui_shrine_no_travel"), Vector2(x, y), w, UIKit.SMALL * 2, UIKit.CREAM_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		y += LINE * maxi(1, UIKit.wrap(UIKit.t("ui_shrine_no_travel"), w).size()) + 8
	for o in others:
		var oid := str(o.get("id", ""))
		_add_button(UIKit.f("ui_shrine_travel", {"t": str(o.get("name", oid))}), Vector2(x, y), w, func(): _choose("travel:" + oid))
		y += 64
	_add_button(UIKit.t("ui_shrine_skills"), Vector2(x, y), w, func(): _choose("skills"))
	y += 64
	_add_button(UIKit.t("ui_shrine_leave"), Vector2(x, y), w, func(): _choose(""))
	_fit_panel(y + 52 + 28)
	_focus(first)

# ---------------- 菜单 ----------------
## data：{hp: [[名字, 当前, 上限]]} → data.choice = "book" / "bag" / "skills" / ""
func _build_menu() -> void:
	var p := _panel_at(680, 0, 0)
	var x := p.position.x + 36
	var w := p.size.x - 72
	var y := p.position.y + 24
	_add_line(UIKit.t("ui_menu_title"), Vector2(x, y), w, UIKit.BIG, UIKit.GOLD)
	y += 64
	y = _xp_block(x, y, w)
	y = _hp_block(x, y, w, data.get("hp", []))
	y += 20
	var bw := floorf((w - 16) / 2)
	var pts := Party.points()
	var sk := UIKit.f("ui_menu_skills_pts", {"n": pts}) if pts > 0 else UIKit.t("ui_menu_skills")
	var first := _add_button(UIKit.t("ui_book"), Vector2(x, y), bw, func(): _choose("book"))
	_add_button(UIKit.t("ui_bag_title"), Vector2(x + bw + 16, y), bw, func(): _choose("bag"))
	var skb := _add_button(sk, Vector2(x, y + 64), bw, func(): _choose("skills"))
	if pts > 0: skb.add_theme_color_override("font_color", UIKit.GOLD)
	_add_button(UIKit.t("ui_menu_back"), Vector2(x + bw + 16, y + 64), bw, func(): _choose(""))
	_fit_panel(y + 64 + 52 + 28)
	_focus(first)

# ---------------- 输入 ----------------
func handle(e: InputEvent) -> void:
	match kind:
		"vision", "card", "unlock":
			if e.is_action_pressed("confirm"): close()
		"book":
			if e.is_action_pressed("confirm") or e.is_action_pressed("cancel"): close()
		"result", "boon":
			if e.is_action_pressed("confirm"): _press_focused()
		"skills", "bag":
			if e.is_action_pressed("cancel"): close()
			elif e.is_action_pressed("confirm"): _press_focused()
		"menu", "shrine":
			if e.is_action_pressed("cancel"): _choose("")
			elif e.is_action_pressed("confirm"): _press_focused()

## 确认键不是 ui_accept 的那几个（Z）走到这里：按下有焦点的按钮；没有焦点就把焦点给第一个
func _press_focused() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f is Button and f in _buttons:
		if not f.disabled: f.pressed.emit()
		return
	for bt in _buttons:
		if not bt.disabled and bt.focus_mode != Control.FOCUS_NONE:
			bt.grab_focus()
			return

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and kind in ["vision", "card", "unlock", "book"]:
		accept_event()
		close()

# ---------------- 画 ----------------
func _process(delta: float) -> void:
	if kind == "vision":
		_t += delta
		queue_redraw()

func _draw() -> void:
	var v := _view()
	match kind:
		"title":
			draw_rect(Rect2(Vector2.ZERO, v), UIKit.NAVY)
			for i in 3:
				var rr := 120.0 + i * 70.0
				draw_arc(Vector2(v.x / 2, v.y * 0.22 + 40), rr, PI * 1.1, PI * 1.9, 48, Color(UIKit.DROP, 0.12), 2.0)
		"vision": _draw_vision()
		"card":
			draw_rect(Rect2(Vector2.ZERO, v), Color("#06070C"))
		"unlock":
			draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.5))
			UIKit.draw_frame(self, data.rect)
		"book":
			draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.55))
			UIKit.draw_frame(self, data.rect, Color(UIKit.NAVY, 0.97), UIKit.DROP)
		"end":
			draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.7))
			UIKit.draw_frame(self, data.rect)
		_:
			if kind in PANEL_KINDS:
				draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.6))
				UIKit.draw_frame(self, _panel, Color(UIKit.NAVY, 0.97))
				for b in _bars:
					draw_rect(b.r.grow(2), UIKit.INK)
					draw_rect(b.r, Color(UIKit.NAVY_2, 1.0))
					if b.v > 0.0:
						draw_rect(Rect2(b.r.position, Vector2(maxf(2.0, b.r.size.x * b.v), b.r.size.y)), b.c)
				for a in _avatars:
					_draw_avatar(a.p, a.c)

## 奖励卡上同伴的小头像：一圈墨黑底 + 人的颜色
func _draw_avatar(c: Vector2, col: Color) -> void:
	draw_circle(c, 26, UIKit.INK)
	draw_circle(c, 22, Color(col, 0.35))
	draw_circle(c + Vector2(0, -6), 9, col)
	draw_rect(Rect2(c.x - 12, c.y + 5, 24, 13), col)

## 看水面：四周压暗，一圈金边，水纹往外走；圈里是一张静止的白盒画面
func _draw_vision() -> void:
	var v := _view()
	draw_rect(Rect2(Vector2.ZERO, v), Color(0.02, 0.03, 0.06, 0.92))
	var c: Vector2 = data.center
	var r: float = data.r
	for i in 4:
		var k := fmod(_t * 0.2 + i / 4.0, 1.0)
		draw_arc(c, r + 16 + k * 90, 0, TAU, 64, Color(UIKit.DROP, 0.5 * (1.0 - k)), 2.0)
	draw_circle(c, r + 12, UIKit.INK)
	draw_circle(c, r + 8, UIKit.GOLD)
	draw_circle(c, r, Color("#F6EBCF"))
	# 白盒画面：左边亚瑟从石头里拔剑，右边凯举着同一把剑对着埃克托
	var ground := c.y + r * 0.35
	draw_rect(Rect2(c.x - r * 0.92, ground, r * 1.84, r * 0.3), Color("#C9C2A8"))
	var ax := c.x - r * 0.45
	draw_rect(Rect2(ax - 34, ground - 34, 68, 40), Color("#8C8F99"))
	draw_rect(Rect2(ax - 24, ground - 44, 48, 12), Color("#5A5D66"))
	draw_line(Vector2(ax, ground - 44), Vector2(ax, ground - 120), Color("#D8D8E0"), 5.0)
	draw_line(Vector2(ax - 12, ground - 100), Vector2(ax + 12, ground - 100), UIKit.GOLD, 5.0)
	var actors: Dictionary = Data.t("maps").actors
	World._figure_on(self, Vector2(ax + 30, ground - 44), UIKit.hexcol(actors.arthur.color), false, Vector2i(-1, 0))
	draw_line(Vector2(c.x, c.y - r * 0.8), Vector2(c.x, ground + r * 0.2), Color(UIKit.DROP, 0.35), 2.0)
	var kx := c.x + r * 0.32
	World._figure_on(self, Vector2(kx, ground - 26), UIKit.hexcol(actors.kay.color), false, Vector2i(1, 0))
	draw_line(Vector2(kx + 14, ground - 40), Vector2(kx + 60, ground - 92), Color("#D8D8E0"), 5.0)
	World._figure_on(self, Vector2(kx + 96, ground - 26), UIKit.hexcol(actors.ector.color), false, Vector2i(-1, 0))
