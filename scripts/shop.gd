class_name ShopLogic
extends RefCounted
## 商店（第 15 步第二批，第 2 章伦敦桥头的铺子先用）：规则照 design/systems/items.md「商店」和 mechanics-library shop-economy：
## 钱全是整数；一次买卖要么全成、要么什么都不变（先查钱、背包、药的上限，再扣钱）；药不限量；
## 装备货架照 items.json shop.shops.<id>.rolls 随机抽几件，不超过 max_rarity，按 restock.mode = chapter 每章换一批。
## 货架用存档里的种子 + 店 id + 章号抽，抽完存进 GS.S.shops，读档原样恢复，读档刷不出新货。
## 店主在 npcs.json（node 写 Shop_<店 id>），节点里 <<open_shop 店 id>> 打开 screens.gd 的 shop 画面。

static func shop_def(id: String) -> Dictionary:
	return Data.t("items").get("shop", {}).get("shops", {}).get(id, {})

## 这一章货架上的装备（第一次打开这一章时抽，存进存档）
static func shelf_gear(id: String) -> Array:
	if not GS.S.has("shops") or typeof(GS.S.shops) != TYPE_DICTIONARY: GS.S["shops"] = {}
	var ch := Party.chapter()
	var rec: Dictionary = GS.S.shops.get(id, {})
	if rec.is_empty() or int(rec.get("chapter", -1)) != ch:
		rec = {"chapter": ch, "gear": _roll_shelf(id, ch)}
		GS.S.shops[id] = rec
	return rec.gear

static func _roll_shelf(id: String, ch: int) -> Array:
	var out := []
	var order := ["normal", "magic", "rare"]
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(GS.S.get("seed", 1)), "shop", id, ch])
	for roll in shop_def(id).get("rolls", []):
		var cap := order.find(str(roll.get("max_rarity", "rare")))
		for i in int(roll.get("qty", 0)):
			var rar: String = Party.loot.roll_rarity(r)
			if order.find(rar) > cap: rar = order[cap]
			out.append(Party.loot.roll_item(r, ch, {"rarity": rar}))
	return out

## 货架上的每一样：{kind: potion / gear, id, name, price, item?, index?}；药按章开放（大瓶血药 from_chapter 4）
static func stock(id: String) -> Array:
	var IT: Dictionary = Data.t("items")
	var out := []
	for k in shop_def(id).get("stock", {}):
		var p: Dictionary = IT.potions.get(k, {})
		if p.is_empty() or int(p.get("from_chapter", 0)) > Party.chapter(): continue
		out.append({"kind": "potion", "id": k, "name": str(p.name), "price": int(p.price)})
	var gear := shelf_gear(id)
	for i in gear.size():
		var info := Party.item_info(gear[i])
		out.append({"kind": "gear", "id": "gear:%d" % i, "index": i, "name": "%s（%s）" % [info.name, info.rarity_name],
			"lines": info.lines, "color": info.color, "price": int(info.price), "item": gear[i]})
	return out

## 买不买得了：返回空字符串表示能买，否则是文本键（钱不够 / 背包满了 / 带不下了）
static func why_not(entry: Dictionary) -> String:
	var IT: Dictionary = Data.t("items")
	if int(GS.S.get("silver", 0)) < int(entry.price): return "shop_no_money"
	if entry.kind == "gear" and GS.S.bag.size() >= int(IT.bag_size): return "shop_bag_full"
	if entry.kind == "potion" and int(GS.S.potions.get(entry.id, 0)) >= int(IT.potion_cap.get(entry.id, 99)): return "shop_cap_full"
	return ""

## 买一样；成了返回 {ok: true, name, price}，不成返回 {ok: false, reason: 文本键}，什么都不变
static func buy(id: String, entry: Dictionary) -> Dictionary:
	var why := why_not(entry)
	if why != "": return {"ok": false, "reason": why}
	GS.S.silver = int(GS.S.silver) - int(entry.price)
	if entry.kind == "potion":
		GS.S.potions[entry.id] = int(GS.S.potions.get(entry.id, 0)) + 1
	else:
		var gear: Array = shelf_gear(id)
		var it: Dictionary = gear[int(entry.index)]
		gear.remove_at(int(entry.index))
		it["uid"] = Party._new_uid()
		GS.S.bag.append(it)
	return {"ok": true, "name": entry.name, "price": int(entry.price)}
