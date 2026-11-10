class_name Screens
extends Control
## 盖在地图上的整屏：标题、看水面、章节过渡、新能力、预言簿、白盒结束；第 10 步加了升级挑奖励、技能树、背包、圣龛。
## 第 15 步第二批加了商店。一次只开一个，关上时回调。
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
		elif k in ["vision", "card", "unlock", "book", "bag"]:
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
		var told_key := "book_told_" + picked
		if picked == "D5b" and main and str(main.runner.v("d5_told")) == "bedivere":
			told_key += "_bedivere"   # D5b 告诉凯和告诉贝狄威尔是同一个值，这里按 $d5_told 分开记
		var told := UIKit.t(told_key) if picked != "" else UIKit.t("ui_book_undecided")
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

# ---------------- 升级：挑一个奖励（progression.md「随机奖励」） ----------------
func _build_levelup() -> void:
	var v := _view()
	var r := Rect2(v.x / 2 - 470, v.y / 2 - 230, 940, 460)
	data["rect"] = r
	_add_label(UIKit.f("lv_title", {"n": int(data.level)}), r.position + Vector2(40, 30), 860, UIKit.BIG, UIKit.GOLD)
	_add_label(UIKit.t("lv_heal"), r.position + Vector2(40, 88), 860, UIKit.BODY, UIKit.CREAM)
	_add_label(UIKit.f("lv_points", {"n": int(data.get("points", 2))}), r.position + Vector2(40, 124), 860, UIKit.BODY, UIKit.DROP)
	var offers: Array = data.offers
	for i in offers.size():
		var o: Dictionary = offers[i]
		var pos := r.position + Vector2(40 + i * 296, 190)
		var bt := _card(pos, Vector2(280, 150), "%s\n\n%s" % [o.name, o.text], _pick_boon.bind(i))
		bt.get_child(0).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bt.get_child(0).position.y = 30
		if i == 0 and not auto: bt.grab_focus.call_deferred()
	_add_label(UIKit.t("lv_hint"), r.position + Vector2(40, r.size.y - 56), 860, UIKit.SMALL * 2, UIKit.CREAM_DIM)
	data["t0"] = Time.get_ticks_msec()

func _pick_boon(i: int) -> void:
	data["choice"] = data.offers[i]
	data["ms"] = Time.get_ticks_msec() - int(data.get("t0", 0))
	close()

# ---------------- 技能树：四棵树，每棵 4 格（progression.md「技能点和四棵树」） ----------------
func _build_tree() -> void:
	var v := _view()
	var r := Rect2(maxf(16.0, v.x / 2 - 620), maxf(16.0, v.y / 2 - 340), minf(1240.0, v.x - 32), minf(680.0, v.y - 32))
	data["rect"] = r
	if not data.has("t0"): data["t0"] = Time.get_ticks_msec()
	var P: Dictionary = Data.t("progression").skill_tree
	_add_label(UIKit.f("tree_title", {"lv": Party.level(), "n": Party.tree_points()}), r.position + Vector2(32, 22), r.size.x - 64, UIKit.BIG, UIKit.GOLD)
	var col_w := (r.size.x - 64) / 4.0
	var tids := ["spark", "water", "ward", "trick"]
	for ti in tids.size():
		var tid: String = tids[ti]
		var x := r.position.x + 32 + ti * col_w
		_add_label(str(P.trees[tid].name), Vector2(x, r.position.y + 84), col_w - 16, UIKit.BODY, UIKit.DROP)
		var nodes := []
		for id in P.nodes:
			if P.nodes[id].tree == tid: nodes.append(id)
		nodes.sort_custom(func(a, b): return int(P.nodes[a].level_req) < int(P.nodes[b].level_req))
		for ni in nodes.size():
			var id: String = nodes[ni]
			var nd: Dictionary = P.nodes[id]
			var rank: int = Party.tree.rank(id)
			var why := Party.node_why(id)
			var pos := Vector2(x, r.position.y + 122 + ni * 118)
			var bt := _card(pos, Vector2(col_w - 16, 110), "%s  %d/%d\n%s\n%s" % [nd.name, rank, int(nd.max_rank), UIKit.t("node_" + id), why if why != "" else UIKit.t("tree_click")], _buy_node.bind(id))
			bt.disabled = why != ""
			if why != "": bt.get_child(0).add_theme_color_override("font_color", UIKit.CREAM_DIM)
			if rank > 0: _gold(bt)
			bt.set_meta("node", id)
	var by := r.end.y - 68
	var done := _add_button(UIKit.t("tree_done"), Vector2(r.end.x - 252, by), 220, func(): _choose("done"))
	if data.get("respec", false) and not Party.tree.paid.is_empty():
		_add_button(UIKit.t("tree_respec"), Vector2(r.position.x + 32, by), 360, func():
			var rr := Party.respec()
			print("  [洗点] 点数全部拿回来：%d 点" % int(rr.get("refunded", 0)))
			_rebuild())
	if not auto: done.grab_focus.call_deferred()

## 文字多的按钮：按钮本身不放字（放了会被字撑宽），里面放一个会自动换行的标签
func _card(pos: Vector2, sz: Vector2, text: String, fn: Callable) -> Button:
	var bt := _add_button("", pos, sz.x, fn)
	bt.size = sz
	bt.clip_contents = true
	var l := UIKit.label(text, UIKit.BODY, UIKit.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.position = Vector2(12, 2)
	l.size = Vector2(sz.x - 24, sz.y - 4)
	l.add_theme_constant_override("line_spacing", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bt.add_child(l)
	return bt

func _buy_node(id: String) -> void:
	var r := Party.buy(id)
	if r.ok:
		print("  [加点] %s → %d 级，还剩 %d 点" % [Data.t("progression").skill_tree.nodes[id].name, int(r.rank), int(r.points)])
		data["bought"] = int(data.get("bought", 0)) + 1
	_rebuild()

func _rebuild() -> void:
	_clear()
	call("_build_" + kind)
	queue_redraw()

func _gold(bt: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIKit.GOLD.darkened(0.55)
	sb.border_color = UIKit.GOLD
	sb.set_border_width_all(3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	bt.add_theme_stylebox_override("normal", sb)

# ---------------- 背包：学徒三个格子、背包里的装备、药（items.md） ----------------
func _build_bag() -> void:
	var v := _view()
	var r := Rect2(maxf(16.0, v.x / 2 - 600), maxf(16.0, v.y / 2 - 330), minf(1200.0, v.x - 32), minf(660.0, v.y - 32))
	data["rect"] = r
	if not data.has("t0"): data["t0"] = Time.get_ticks_msec()
	_add_label(UIKit.t("bag_title"), r.position + Vector2(32, 22), 600, UIKit.BIG, UIKit.GOLD)
	_add_label(UIKit.f("bag_money", {"silver": int(GS.S.silver), "hp": int(GS.S.potions.get("potion_hp", 0)), "mp": int(GS.S.potions.get("potion_mana", 0))}),
		r.position + Vector2(32, 76), 700, UIKit.BODY, UIKit.CREAM)
	if int(GS.S.potions.get("potion_hp", 0)) > 0 and not Party.all_full():
		_add_button(UIKit.t("bag_drink"), r.position + Vector2(r.size.x - 452, 66), 420, func():
			var who := Party.drink_on_map("potion_hp")
			if who != "": print("  [喝药] %s 回 %d 血" % [Party.display_name(who), int(Data.t("items").potions.potion_hp.heal)])
			_rebuild())
	# 左：身上的三个格子
	var y := r.position.y + 130
	_add_label(UIKit.f("bag_you", {"hp": Party.max_hp("apprentice"), "mp": Party.mana_max()}), Vector2(r.position.x + 32, y), 460, UIKit.BODY, UIKit.DROP)
	y += 44
	for slot in Party.SLOTS:
		var it = GS.S.gear.get(slot)
		var head := UIKit.t("slot_" + slot)
		if it == null:
			_add_label("%s：%s" % [head, UIKit.t("slot_empty")], Vector2(r.position.x + 32, y), 460, UIKit.BODY, UIKit.CREAM_DIM)
			y += 92
			continue
		var info := Party.item_info(it)
		var l := _add_label("%s：%s" % [head, info.name], Vector2(r.position.x + 32, y), 460, UIKit.BODY, UIKit.hexcol(info.color))
		_add_label("  " + "，".join(PackedStringArray(info.lines)), Vector2(r.position.x + 32, y + 34), 340, UIKit.SMALL * 2, UIKit.CREAM)
		if not it.has("unique"):
			_add_button(UIKit.t("bag_off"), Vector2(r.position.x + 380, y + 26), 110, func():
				Party.unequip(slot)
				_rebuild())
		y += 92
	# 右：背包
	var x := r.position.x + 540
	y = r.position.y + 130
	_add_label(UIKit.f("bag_list", {"n": GS.S.bag.size(), "max": int(Data.t("items").bag_size)}), Vector2(x, y), 600, UIKit.BODY, UIKit.DROP)
	y += 44
	if GS.S.bag.is_empty():
		_add_label(UIKit.t("bag_empty"), Vector2(x, y), 600, UIKit.BODY, UIKit.CREAM_DIM)
	for it in GS.S.bag:
		if y > r.end.y - 150: break
		var info := Party.item_info(it)
		_add_label("%s（%s）" % [info.name, info.rarity_name], Vector2(x, y), 460, UIKit.BODY, UIKit.hexcol(info.color))
		var diff := Party.compare(it)
		var parts := []
		for st in diff:
			if int(diff[st]) != 0: parts.append("%s %s%d" % [Data.t("items").loot.stat_names.get(st, st), "+" if int(diff[st]) > 0 else "", int(diff[st])])
		_add_label("  " + "，".join(PackedStringArray(info.lines)) + ("  ｜换上：" + "，".join(PackedStringArray(parts)) if not parts.is_empty() else ""),
			Vector2(x, y + 34), 520, UIKit.SMALL * 2, UIKit.CREAM)
		var uid := int(it.uid)
		_add_button(UIKit.t("bag_on"), Vector2(r.end.x - 152, y + 4), 120, func():
			Party.equip(uid)
			print("  [换装] 换上 %s" % info.name)
			data["equipped"] = int(data.get("equipped", 0)) + 1
			_rebuild())
		y += 84
	var bt := _add_button(UIKit.t("tree_done"), Vector2(r.end.x - 252, r.end.y - 68), 220, func(): _choose("done"))
	if not auto: bt.grab_focus.call_deferred()

# ---------------- 圣龛：祈祷以后（overworld.md「圣龛」） ----------------
func _build_shrine() -> void:
	var v := _view()
	var r := Rect2(v.x / 2 - 380, v.y / 2 - 220, 760, 440)
	data["rect"] = r
	var sh: Dictionary = data.shrine
	_add_label(UIKit.t(sh.name), r.position + Vector2(36, 26), 680, UIKit.BIG, UIKit.GOLD)
	var y := r.position.y + 82
	var desc := UIKit.t("shrine_desc_" + str(sh.id))
	_add_label(desc, Vector2(r.position.x + 36, y), 680, UIKit.BODY, UIKit.CREAM)
	y += 40 * _rows(desc, 660) + 12
	_add_label(UIKit.t("shrine_done"), Vector2(r.position.x + 36, y), 680, UIKit.BODY, UIKit.DROP)
	y += 40 * _rows(UIKit.t("shrine_done"), 660) + 20
	var first: Button = null
	for o in data.get("travel", []):
		var bt := _add_button(UIKit.f("shrine_travel", {"t": UIKit.t(o.name)}), Vector2(r.position.x + 36, y), 680, func():
			data["choice"] = "travel:" + str(o.id)
			close())
		if first == null: first = bt
		y += 60
	var tb := _add_button(UIKit.t("shrine_tree") if Party.tree_points() == 0 else UIKit.f("shrine_tree_pts", {"n": Party.tree_points()}),
		Vector2(r.position.x + 36, y), 330, func(): _choose("tree"))
	var go := _add_button(UIKit.t("shrine_leave"), Vector2(r.position.x + 386, y), 330, func(): _choose("leave"))
	if not auto: (first if first else go).grab_focus.call_deferred()

# ---------------- 商店：药不限量，装备货架每章换一批（items.md「商店」，第 15 步第二批） ----------------
func _build_shop() -> void:
	var v := _view()
	var r := Rect2(maxf(16.0, v.x / 2 - 560), maxf(16.0, v.y / 2 - 320), minf(1120.0, v.x - 32), minf(640.0, v.y - 32))
	data["rect"] = r
	var id: String = data.get("shop", "")
	_add_label(str(ShopLogic.shop_def(id).get("name", id)), r.position + Vector2(32, 22), r.size.x - 64, UIKit.BIG, UIKit.GOLD)
	_add_label(UIKit.f("shop_money", {"silver": int(GS.S.silver), "hp": int(GS.S.potions.get("potion_hp", 0)), "mp": int(GS.S.potions.get("potion_mana", 0))}),
		r.position + Vector2(32, 76), r.size.x - 64, UIKit.BODY, UIKit.CREAM)
	var y := r.position.y + 128
	var items := ShopLogic.stock(id)
	if not items.any(func(e): return e.kind == "gear"):
		_add_label(UIKit.t("shop_sold_out"), Vector2(r.position.x + 32, r.end.y - 128), 600, UIKit.SMALL * 2, UIKit.CREAM_DIM)
	for e in items:
		if y > r.end.y - 150: break
		var col := UIKit.hexcol(e.color) if e.has("color") else UIKit.CREAM
		_add_label(e.name, Vector2(r.position.x + 32, y), 560, UIKit.BODY, col)
		if e.has("lines"):
			_add_label("  " + "，".join(PackedStringArray(e.lines)), Vector2(r.position.x + 32, y + 34), 560, UIKit.SMALL * 2, UIKit.CREAM)
		_add_label(UIKit.f("shop_price", {"n": int(e.price)}), Vector2(r.end.x - 400, y + 6), 140, UIKit.BODY, UIKit.GOLD)
		var why := ShopLogic.why_not(e)
		var bt := _add_button(UIKit.t("shop_buy") if why == "" else UIKit.t(why), Vector2(r.end.x - 232, y), 200, func(): _shop_buy(e))
		bt.disabled = why != ""
		y += 76 if e.has("lines") else 60
	var done := _add_button(UIKit.t("shrine_leave"), Vector2(r.end.x - 252, r.end.y - 68), 220, func(): _choose("leave"))
	if not auto: done.grab_focus.call_deferred()

func _shop_buy(e: Dictionary) -> void:
	var res := ShopLogic.buy(data.get("shop", ""), e)
	if res.ok:
		data["bought"] = int(data.get("bought", 0)) + 1
		print("  [商店] " + UIKit.f("shop_bought", {"t": res.name, "n": res.price}))
	else:
		print("  [商店] 买不了 %s：%s" % [e.name, UIKit.t(res.reason)])
	_rebuild()

func _build_end() -> void:
	var v := _view()
	var r := Rect2(v.x / 2 - 420, maxf(16.0, v.y / 2 - 320), 840, minf(640.0, v.y - 32))
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
	var m: Array = data.get("metrics", [])
	if not m.is_empty():
		_add_label(UIKit.t("ui_metrics"), Vector2(r.position.x + 40, y + 12), 760, UIKit.BODY, UIKit.GOLD)
		_add_label("\n".join(PackedStringArray(m)), Vector2(r.position.x + 40, y + 52), 760, UIKit.SMALL * 2, UIKit.CREAM)
	var bt := _add_button(UIKit.t("ui_restart"), Vector2(v.x / 2 - 140, r.end.y - 84), 280, func(): _choose("restart"))
	if not auto: bt.grab_focus.call_deferred()

# ---------------- 输入 ----------------
func handle(e: InputEvent) -> void:
	match kind:
		"vision", "card", "unlock":
			if e.is_action_pressed("confirm"): close()
		"book":
			if e.is_action_pressed("confirm") or e.is_action_pressed("cancel"): close()
		"bag", "tree", "shrine", "shop":
			if e.is_action_pressed("cancel"): _choose("leave" if kind in ["shrine", "shop"] else "done")

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
		"end", "levelup", "tree", "bag", "shrine", "shop":
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
