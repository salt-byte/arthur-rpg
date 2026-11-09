class_name Hud
extends Control
## 地图上的常驻和瞬时信息（ART_DIRECTION 第 4 节）：
## 常驻：左上「下一步：……」，右上菜单按钮；左下学徒的等级、经验条和三个人的血（技能点没用完时旁边一个金点）；
## 手机上左下方向键、右下确认键。
## 瞬时：走进新地方的地名、预言簿「后来」的提示条（右上，停 4 秒）、自动存档、人冒的一句话。

var main
var next_text := ""
var area_text := ""
var _area_t := 0.0
var toast_lines: Array = []
var _toast_t := 0.0
var _saved_t := 0.0
var bark := ""
var bark_at := Vector2.ZERO
var _bark_t := 0.0
var menu_btn: Button
var touch: Control
var show_controls := true
var party_rows: Array = []      # [[名字, 当前, 上限], ...]，main 每次刷新时调 set_party
var _t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_btn = Button.new()
	menu_btn.text = UIKit.t("ui_menu_btn")
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.size = Vector2(200, 44)
	menu_btn.pressed.connect(func(): if main: main.open_menu())
	add_child(menu_btn)
	if DisplayServer.is_touchscreen_available():
		_build_touch()
	resized.connect(_place)
	_place()

func _place() -> void:
	var v := get_viewport_rect().size
	menu_btn.position = Vector2(v.x - 216, 16)
	if touch:
		touch.position = Vector2.ZERO
		touch.size = v
		for c in touch.get_children():
			c.position = c.get_meta("anchor_fn").call(v)

func _build_touch() -> void:
	touch = Control.new()
	touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(touch)
	var dirs := {"up": [Vector2i(0, -1), Vector2(88, -232)], "down": [Vector2i(0, 1), Vector2(88, -96)],
		"left": [Vector2i(-1, 0), Vector2(20, -164)], "right": [Vector2i(1, 0), Vector2(156, -164)]}
	var arrows := {"up": "↑", "down": "↓", "left": "←", "right": "→"}
	for k in dirs:
		var bt := Button.new()
		bt.text = arrows[k]
		bt.size = Vector2(64, 64)
		bt.focus_mode = Control.FOCUS_NONE
		var d: Vector2i = dirs[k][0]
		var off: Vector2 = dirs[k][1]
		bt.set_meta("anchor_fn", func(v): return Vector2(off.x, v.y + off.y))
		bt.button_down.connect(func(): if main: main.world.touch_dir = d)
		bt.button_up.connect(func(): if main: main.world.touch_dir = Vector2i.ZERO)
		touch.add_child(bt)
	var ok := Button.new()
	ok.text = UIKit.t("ui_yes")
	ok.size = Vector2(120, 88)
	ok.focus_mode = Control.FOCUS_NONE
	ok.set_meta("anchor_fn", func(v): return Vector2(v.x - 152, v.y - 160))
	ok.pressed.connect(func():
		var ev := InputEventAction.new()
		ev.action = "confirm"
		ev.pressed = true
		Input.parse_input_event(ev))
	touch.add_child(ok)

func set_touch_visible(on: bool) -> void:
	if touch: touch.visible = on

## 三个人的血：rows = [[名字, 当前, 上限], ...]
func set_party(rows: Array) -> void:
	party_rows = rows
	queue_redraw()

func set_next(t: String) -> void:
	next_text = t
	queue_redraw()

func flash_area(t: String) -> void:
	area_text = t
	_area_t = 2.2

func show_toast(lines: Array) -> void:
	toast_lines = lines
	_toast_t = 4.0

func flash_saved() -> void:
	_saved_t = 1.6

func show_bark(t: String, screen_pos: Vector2) -> void:
	bark = t
	bark_at = screen_pos
	_bark_t = 2.6

func _process(delta: float) -> void:
	_area_t = maxf(0.0, _area_t - delta)
	_toast_t = maxf(0.0, _toast_t - delta)
	_saved_t = maxf(0.0, _saved_t - delta)
	_bark_t = maxf(0.0, _bark_t - delta)
	_t += delta
	queue_redraw()

func _draw() -> void:
	var v := get_viewport_rect().size
	var font := UIKit.font()
	if next_text != "":
		var w := font.get_string_size(next_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY).x
		var r := Rect2(16, 16, w + 48, 48)
		draw_rect(r, Color(UIKit.INK, 0.85))
		draw_rect(Rect2(r.position, Vector2(6, r.size.y)), UIKit.GOLD)
		draw_string(font, r.position + Vector2(24, 33), next_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY, UIKit.CREAM)
	if _area_t > 0.0:
		var a := minf(1.0, _area_t)
		var w := font.get_string_size(area_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BIG).x
		var r := Rect2(v.x / 2 - w / 2 - 32, 84, w + 64, 64)
		draw_rect(r, Color(UIKit.INK, 0.8 * a))
		draw_string(font, r.position + Vector2(32, 46), area_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BIG, Color(UIKit.CREAM, a))
	if _toast_t > 0.0 and not toast_lines.is_empty():
		var slide := clampf((4.0 - _toast_t) * 4.0, 0.0, 1.0)
		var body := PackedStringArray()
		for l in toast_lines.slice(1):
			body.append_array(UIKit.wrap(l, 412))
		var r := Rect2(v.x - 476 * slide, 76, 460, 64 + body.size() * 34)
		UIKit.draw_frame(self, r, Color(UIKit.INK, 0.95), UIKit.DROP)
		UIKit.draw_drop(self, r.position + Vector2(30, 32), 22)
		draw_string(font, r.position + Vector2(52, 40), toast_lines[0], HORIZONTAL_ALIGNMENT_LEFT, 392, UIKit.BODY, UIKit.DROP)
		var y := r.position.y + 76
		for l in body:
			draw_string(font, Vector2(r.position.x + 24, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY, UIKit.CREAM)
			y += 34
	if _saved_t > 0.0:
		var t := UIKit.t("ui_saved")
		draw_string(font, Vector2(v.x - 200, v.y - 24), t, HORIZONTAL_ALIGNMENT_RIGHT, 184, UIKit.SMALL * 2, Color(UIKit.GOLD, minf(1.0, _saved_t)))
	if _bark_t > 0.0 and bark != "":
		var w := font.get_string_size(bark, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY).x
		var r := Rect2(bark_at.x - w / 2 - 14, bark_at.y - 92, w + 28, 44)
		draw_rect(r, UIKit.INK)
		draw_rect(r.grow(-3), Color(UIKit.NAVY, 0.95))
		draw_string(font, r.position + Vector2(14, 31), bark, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.BODY, UIKit.CREAM)
	if main == null or main.mode == "map":
		_draw_party(v, font)
	if show_controls and main and main.mode == "map":
		var t := UIKit.t("ui_controls_menu")
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2).x
		draw_rect(Rect2(16, v.y - 52, w + 24, 36), Color(UIKit.INK, 0.7))
		draw_string(font, Vector2(28, v.y - 26), t, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2, UIKit.CREAM_DIM)

## 左下一小块：「Lv N」+ 细经验条，下面三个人的名字和血条。手机上放在方向键上面，电脑上放在操作提示上面
func _draw_party(v: Vector2, font: Font) -> void:
	var sz := UIKit.SMALL * 2
	var name_w := 0.0
	for r in party_rows:
		name_w = maxf(name_w, font.get_string_size(str(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
	name_w = clampf(name_w, 48, 96)
	var bar_w := 96.0
	var num_w := font.get_string_size("00/00", HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var w := 12 + name_w + 10 + bar_w + 10 + num_w + 12
	var row_h := 30.0
	var h := 10 + row_h + party_rows.size() * row_h + 8
	var bottom := v.y - 16
	if touch and touch.visible: bottom = v.y - 244
	elif show_controls and main and main.mode == "map": bottom = v.y - 60
	var r := Rect2(16, bottom - h, w, h)
	draw_rect(r, Color(UIKit.INK, 0.8))
	draw_rect(Rect2(r.position, Vector2(4, r.size.y)), UIKit.GOLD)
	var p := Party.progress()
	var x := r.position.x + 12
	var y := r.position.y + 10
	var lv := UIKit.f("ui_hud_lv", {"n": p.level})
	draw_string(font, Vector2(x, y + 23), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, UIKit.GOLD)
	var lw := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var xb := Rect2(x + lw + 12, y + 12, r.end.x - 12 - (x + lw + 12), 6)
	draw_rect(xb.grow(1), UIKit.NAVY_2)
	draw_rect(Rect2(xb.position, Vector2(xb.size.x * clampf(float(p.ratio), 0, 1), xb.size.y)), UIKit.GOLD)
	y += row_h
	for row in party_rows:
		var cur := int(row[1])
		var mx := maxi(1, int(row[2]))
		draw_string(font, Vector2(x, y + 23), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, name_w, sz, UIKit.CREAM)
		var hb := Rect2(x + name_w + 10, y + 11, bar_w, 8)
		var ratio := clampf(float(cur) / mx, 0, 1)
		draw_rect(hb.grow(1), UIKit.NAVY_2)
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * ratio, hb.size.y)), UIKit.HP_OK if ratio > 0.3 else UIKit.DANGER)
		draw_string(font, Vector2(hb.end.x + 10, y + 23), "%d/%d" % [cur, mx], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, UIKit.CREAM_DIM)
		y += row_h
	# 技能点没用完：块的右上角外面一个金点，一闪一闪
	if Party.points() > 0:
		var c := Vector2(r.end.x + 12, r.position.y + 10)
		var a := 0.6 + 0.4 * sin(_t * 4.0)
		draw_circle(c, 8, UIKit.INK)
		draw_circle(c, 6, Color(UIKit.GOLD, a))
