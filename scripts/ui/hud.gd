class_name Hud
extends Control
## 地图上的常驻和瞬时信息（ART_DIRECTION 第 4 节）：
## 常驻：左上「下一步：……」，右上预言簿按钮；手机上左下方向键、右下确认键。
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
var book_btn: Button
var touch: Control
var show_controls := true

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_btn = Button.new()
	book_btn.text = UIKit.t("ui_book_btn")
	book_btn.focus_mode = Control.FOCUS_NONE
	book_btn.size = Vector2(200, 44)
	book_btn.pressed.connect(func(): if main: main.open_book())
	add_child(book_btn)
	if DisplayServer.is_touchscreen_available():
		_build_touch()
	resized.connect(_place)
	_place()

func _place() -> void:
	var v := get_viewport_rect().size
	book_btn.position = Vector2(v.x - 216, 16)
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
	if show_controls and main and main.mode == "map":
		var t := UIKit.t("ui_controls")
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2).x
		draw_rect(Rect2(16, v.y - 52, w + 24, 36), Color(UIKit.INK, 0.7))
		draw_string(font, Vector2(28, v.y - 26), t, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SMALL * 2, UIKit.CREAM_DIM)
