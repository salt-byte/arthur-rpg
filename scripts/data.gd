extends Node
## 静态数据：启动时把 content/data/*.json 全部读进来。代码里用到的数都从这里取（设计页第 6 节登记过的参数）。

const FILES := ["combat", "story-unlocks", "prophecy", "companions", "dialogue", "quests", "overworld", "npcs", "spawns"]

var tables := {}      # 文件名 -> 解析后的字典
var errors := []      # 读不出来的文件

func _ready() -> void:
	for f in FILES:
		var path := "res://content/data/%s.json" % f
		if not FileAccess.file_exists(path):
			errors.append("缺少 " + path)
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(d) != TYPE_DICTIONARY:
			errors.append("解析失败 " + path)
			continue
		tables[f] = d

func t(name: String) -> Dictionary:
	return tables.get(name, {})

func param(table: String, key: String, default = null):
	var d := t(table)
	if d.has(key): return d[key]
	var p: Dictionary = d.get("_params", {})
	return p.get(key, default)

## 遭遇 / 敌人
func encounter(id: String) -> Dictionary: return t("combat").get("encounters", {}).get(id, {})
func enemy(id: String) -> Dictionary: return t("combat").get("enemies", {}).get(id, {})

## 剧情给的能力
func unlock_def(id: String) -> Dictionary:
	for u in t("story-unlocks").get("unlocks", []):
		if u.id == id: return u
	return {}

## 看水面的一幕
func vision(decision: String) -> Dictionary:
	for v in t("prophecy").get("visions", []):
		if v.decision == decision: return v
	return {}

func companion_ids() -> Array:
	var a := []
	for c in t("companions").get("roster", []):
		a.append(c.id)
	return a
