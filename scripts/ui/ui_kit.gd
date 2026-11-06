class_name UIKit
extends RefCounted
## 界面风格契约（design/ART_DIRECTION.md 第 4 节）：深蓝底、外圈墨黑 + 内圈金的像素边、直角；
## 金色是强调，水滴蓝只给看水面、预言簿和关键选择；Fusion Pixel 12 像素字放大到 24 用。

const NAVY := Color("#181E34")
const NAVY_2 := Color("#262E4C")
const INK := Color("#0B0E1A")
const GOLD := Color("#C9A24A")
const CREAM := Color("#F3EAD8")
const CREAM_DIM := Color("#B9B2A3")
const DROP := Color("#7EC4EC")
const DANGER := Color("#B03A2E")
const HP_OK := Color("#6FAF5A")

const FONT_PATH := "res://assets/fonts/pixel12.otf"
const BODY := 24
const SMALL := 12
const BIG := 36
const HUGE := 72

static var _font: Font

static func font() -> Font:
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH)
		else:
			_font = ThemeDB.fallback_font
	return _font

## 全局主题：所有 Label / Button 默认用像素字和契约里的颜色
static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = BODY
	th.set_color("font_color", "Label", CREAM)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		th.set_stylebox(st, "Button", _button_box(st))
	th.set_color("font_color", "Button", CREAM)
	th.set_color("font_hover_color", "Button", CREAM)
	th.set_color("font_pressed_color", "Button", INK)
	th.set_color("font_focus_color", "Button", CREAM)
	th.set_color("font_disabled_color", "Button", Color(CREAM_DIM, 0.5))
	return th

static func _button_box(state: String) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = {"normal": NAVY_2, "hover": NAVY_2.lightened(0.12), "pressed": GOLD, "focus": NAVY_2.lightened(0.12), "disabled": NAVY}[state]
	b.border_color = GOLD if state in ["hover", "focus", "pressed"] else INK
	b.set_border_width_all(4)
	b.set_corner_radius_all(0)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 4
	b.content_margin_bottom = 4
	if state == "disabled":
		b.border_color = Color(INK, 0.6)
	return b

## 像素边框：外圈墨黑 4、内圈金 4、深蓝底（九成不透明）
static func draw_frame(ci: CanvasItem, r: Rect2, bg := Color(NAVY, 0.92), edge := GOLD) -> void:
	ci.draw_rect(r, INK)
	ci.draw_rect(r.grow(-4), edge)
	ci.draw_rect(r.grow(-8), bg)

static func label(text: String, size := BODY, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## 水滴图标（关键选择、法力、预言簿）。c 是水滴中心，s 是高度
static func draw_drop(ci: CanvasItem, c: Vector2, s: float, col := DROP, filled := true) -> void:
	var r := s * 0.32
	var base := c + Vector2(0, s * 0.18)
	# 尖顶 + 下半圆
	var poly := PackedVector2Array([c + Vector2(0, -s * 0.5)])
	for i in range(0, 181, 15):
		var a := deg_to_rad(float(i))
		poly.append(base + Vector2(cos(a) * r, sin(a) * r))
	if filled:
		ci.draw_colored_polygon(poly, col)
	else:
		poly.append(poly[0])
		ci.draw_polyline(poly, col, 2.0)

static func hexcol(s: String) -> Color:
	return Color(s) if s != "" else CREAM_DIM

## 文本键 + 参数："ui_next" {"t": …}
static func f(key: String, args := {}) -> String:
	return str(TranslationServer.translate(key)).format(args)

static func t(key) -> String:
	return str(TranslationServer.translate(str(key)))

## 按宽度折行（逐字，中文不靠空格断行）
static func wrap(t: String, width: float, sz := BODY) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for ch in t:
		if cur != "" and font().get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width:
			out.append(cur)
			cur = ch
		else:
			cur += ch
	if cur != "": out.append(cur)
	return out
