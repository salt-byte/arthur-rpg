class_name Screens
extends Control
## 盖在地图上的整屏：标题、看水面、章节过渡、新能力、预言簿、白盒结束。一次只开一个，关上时回调。
## 看水面照 prophecy.md：画面切成一张静止的图，下面两三句具体的描写；全游戏最亮的就是这一圈（ART_DIRECTION 原则 2）。

var main
var kind := ""
var data := {}
var cb := Callable()
var auto := false
var auto_hook := Callable()     # --playtest：画面打开时交给测试（截图后它自己关）
var _labels: Array = []
var _buttons: Array = []
var _t := 0.0

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
		elif k in ["vision", "card", "unlock", "book"]:
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

func _add_button(text: String, pos: Vector2, w: float, fn: Callable) -> Button:
	var bt := Button.new()
	bt.text = text
	bt.position = pos
	bt.size = Vector2(w, 52)
	bt.pressed.connect(fn)
	add_child(bt)
	_buttons.append(bt)
	return bt

# ---------------- 各个画面 ----------------
func _build_title() -> void:
	var v := _view()
	_add_label(UIKit.t("ui_title"), Vector2(0, v.y * 0.22), v.x, UIKit.HUGE, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(UIKit.t("ui_subtitle"), Vector2(0, v.y * 0.22 + 100), v.x, UIKit.BODY, UIKit.CREAM_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var y := v.y * 0.55
	var first := _add_button(UIKit.t("ui_new_game"), Vector2(v.x / 2 - 140, y), 280, func(): _choose("new"))
	if data.get("can_continue", false):
		_add_button(UIKit.t("ui_continue"), Vector2(v.x / 2 - 140, y + 68), 280, func(): _choose("continue"))
	_add_label(UIKit.t("ui_controls"), Vector2(0, v.y - 64), v.x, UIKit.SMALL * 2, UIKit.CREAM_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	if not auto: first.grab_focus.call_deferred()

func _choose(what: String) -> void:
	data["choice"] = what
	close()

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

# ---------------- 输入 ----------------
func handle(e: InputEvent) -> void:
	match kind:
		"vision", "card", "unlock":
			if e.is_action_pressed("confirm"): close()
		"book":
			if e.is_action_pressed("confirm") or e.is_action_pressed("cancel"): close()

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
