class_name DialogBox
extends Control
## 对话框（design/systems/dialogue.md、ART_DIRECTION 风格契约）：
## 说话人名字放在左上一块小牌上，底色用这个人的衣色；打字机出字，按一下出全句；
## 选项一行一个，关键选择前面画水滴，选中后先问「说出口就不能收回。确定吗？」。

signal advanced

var main
var who := ""
var text_label: Label
var choice_labels: Array = []
var choices: Array = []
var sel := 0
var cb := Callable()
var typing := false
var confirm_open := false
var confirm_sel := 1         # 默认停在「再想想」
var auto := false            # --playtest：自动点完
var auto_pick := 0
var auto_key_hook := Callable()   # --playtest：关键选择时先交给测试截图，它再选
var _chars := 0.0
var _box := Rect2()
var _who_col := UIKit.CREAM_DIM
var _t := 0.0

const CPS := 45.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	text_label = UIKit.label("", UIKit.BODY)
	text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	text_label.add_theme_constant_override("line_spacing", 8)
	add_child(text_label)
	visible = false

func show_entries(entries: Array, callback: Callable) -> void:
	var e: Dictionary = entries[0]
	who = e.get("who", "")
	cb = callback
	choices = e.get("choices", [])
	sel = 0
	confirm_open = false
	_who_col = main.color_for(who) if main else UIKit.CREAM_DIM
	text_label.text = e.get("text", "")
	for l in choice_labels: l.queue_free()
	choice_labels = []
	for c in choices:
		var l := UIKit.label(c.t, UIKit.BODY)
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		add_child(l)
		choice_labels.append(l)
	visible = true
	if auto:
		print(("  " + who + "：" if who != "" else "  ") + text_label.text)
		text_label.visible_characters = -1
		typing = false
		_layout()
		if not choices.is_empty():
			var pick := 0
			if choices[0].kind == "key":
				pick = clampi(auto_pick, 0, choices.size() - 1)
			for i in choices.size():
				print("    %s %s%s" % ["→" if i == pick else " ", "💧" if choices[i].kind == "key" else "", choices[i].t])
			if choices[pick].kind == "key":
				print("  [确认] " + UIKit.t("ui_confirm_key") + " → " + UIKit.t("ui_yes"))
				if auto_key_hook.is_valid():
					sel = pick
					confirm_open = true
					confirm_sel = 0
					for l in choice_labels: l.visible = true
					queue_redraw()
					auto_key_hook.call(pick)
					return
			_pick(pick)
		else:
			_advance.call_deferred()
		return
	_chars = 0.0
	typing = true
	text_label.visible_characters = 0
	_layout()

func _layout() -> void:
	var view := get_viewport_rect().size
	var w := minf(1184.0, view.x - 32.0)
	var x := (view.x - w) / 2.0
	text_label.size = Vector2(w - 64, 0)
	text_label.position = Vector2(x + 32, 0)
	var line_h := 32.0
	var text_lines := maxi(1, _lines_for(text_label.text, w - 64))
	var text_h := text_lines * line_h
	var ch_h := 0.0
	var row_h := []
	for l in choice_labels:
		var n := maxi(1, _lines_for(l.text, w - 112))
		row_h.append(n * line_h + 8)
		ch_h += n * line_h + 8
	var h := 32.0 + text_h + (16.0 + ch_h if not choice_labels.is_empty() else 0.0) + 28.0
	h = maxf(h, 168.0)
	var y := view.y - h - 20.0
	_box = Rect2(x, y, w, h)
	text_label.position = Vector2(x + 32, y + 30)
	var cy := y + 30 + text_h + 16
	for i in choice_labels.size():
		var l: Label = choice_labels[i]
		l.size = Vector2(w - 112, 0)
		l.position = Vector2(x + 80, cy + 4)
		l.set_meta("rect", Rect2(x + 24, cy, w - 48, row_h[i]))
		cy += row_h[i]
	queue_redraw()

func _lines_for(t: String, width: float) -> int:
	var font := UIKit.font()
	var lines := 1
	var cur := 0.0
	for ch in t:
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY).x
		if cur + cw > width:
			lines += 1
			cur = cw
		else:
			cur += cw
	return lines

func _process(delta: float) -> void:
	_t += delta
	if not visible: return
	if typing:
		_chars += delta * CPS
		var total := text_label.get_total_character_count()
		text_label.visible_characters = int(_chars)
		if int(_chars) >= total:
			typing = false
			text_label.visible_characters = -1
	for l in choice_labels: l.visible = not typing
	queue_redraw()

func _draw() -> void:
	if not visible: return
	UIKit.draw_frame(self, _box)
	if who != "":
		var font := UIKit.font()
		var w := font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY).x
		var plate := Rect2(_box.position.x + 24, _box.position.y - 26, w + 32, 40)
		draw_rect(plate, UIKit.INK)
		draw_rect(plate.grow(-4), _who_col)
		draw_string(font, plate.position + Vector2(16, 29), who, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY, UIKit.CREAM)
	if not typing:
		for i in choice_labels.size():
			var r: Rect2 = choice_labels[i].get_meta("rect")
			if i == sel and not confirm_open:
				draw_rect(r, UIKit.NAVY_2)
				draw_rect(Rect2(r.position.x, r.position.y, 6, r.size.y), UIKit.GOLD)
			if choices[i].kind == "key":
				UIKit.draw_drop(self, Vector2(r.position.x + 32, r.position.y + 20), 22)
		if choices.is_empty():
			var b := _box.end - Vector2(36, 26 - sin(_t * 5.0) * 3.0)
			draw_colored_polygon(PackedVector2Array([b + Vector2(-8, -6), b + Vector2(8, -6), b + Vector2(0, 4)]), UIKit.GOLD)
	if confirm_open:
		var cw := 520.0
		var r := Rect2(_box.position.x + _box.size.x / 2.0 - cw / 2.0, _box.position.y - 170, cw, 140)
		UIKit.draw_frame(self, r, Color(UIKit.INK, 0.96), UIKit.DROP)
		var font := UIKit.font()
		UIKit.draw_drop(self, r.position + Vector2(36, 42), 26)
		draw_string(font, r.position + Vector2(60, 52), UIKit.t("ui_confirm_key"), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY, UIKit.CREAM)
		var opts := [UIKit.t("ui_yes"), UIKit.t("ui_no")]
		for i in 2:
			var br := Rect2(r.position.x + 60 + i * 210, r.position.y + 78, 180, 40)
			draw_rect(br, UIKit.GOLD if i == confirm_sel else UIKit.INK)
			draw_rect(br.grow(-4), UIKit.NAVY_2)
			draw_string(font, br.position + Vector2(18, 29), opts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY, UIKit.CREAM)
			set_meta("confirm_%d" % i, br)

# ---------------- 输入 ----------------
func handle(e: InputEvent) -> void:
	if confirm_open:
		if e.is_action_pressed("move_left") or e.is_action_pressed("move_up"): confirm_sel = 0
		elif e.is_action_pressed("move_right") or e.is_action_pressed("move_down"): confirm_sel = 1
		elif e.is_action_pressed("confirm"):
			_confirm(confirm_sel == 0)
		elif e.is_action_pressed("cancel"):
			_confirm(false)
		queue_redraw()
		return
	if e.is_action_pressed("confirm"):
		_press()
	elif not typing and not choices.is_empty():
		if e.is_action_pressed("move_up"): sel = (sel - 1 + choices.size()) % choices.size()
		elif e.is_action_pressed("move_down"): sel = (sel + 1) % choices.size()
		elif e is InputEventKey and e.pressed and e.keycode >= KEY_1 and e.keycode <= KEY_9:
			var i: int = e.keycode - KEY_1
			if i < choices.size():
				sel = i
				_press()
		queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT): return
	accept_event()
	if confirm_open:
		for i in 2:
			var r: Rect2 = get_meta("confirm_%d" % i, Rect2())
			if r.has_point(e.position):
				_confirm(i == 0)
		return
	if not typing and not choices.is_empty():
		for i in choice_labels.size():
			var r: Rect2 = choice_labels[i].get_meta("rect")
			if r.has_point(e.position):
				sel = i
				_press()
				return
		return
	_press()

func _press() -> void:
	if typing:
		typing = false
		text_label.visible_characters = -1
		return
	if choices.is_empty():
		_advance()
		return
	if choices[sel].kind == "key":
		confirm_open = true
		confirm_sel = 1
		queue_redraw()
		return
	_pick(sel)

func _confirm(yes: bool) -> void:
	confirm_open = false
	if yes: _pick(sel)
	queue_redraw()

func pick(i: int) -> void:
	confirm_open = false
	_pick(i)

func _pick(i: int) -> void:
	var fn: Callable = choices[i].fn
	choices = []
	for l in choice_labels: l.queue_free()
	choice_labels = []
	fn.call_deferred()

func _advance() -> void:
	var c := cb
	cb = Callable()
	advanced.emit()
	if c.is_valid(): c.call_deferred()

func close() -> void:
	visible = false
	for l in choice_labels: l.queue_free()
	choice_labels = []
	choices = []
