extends Node
## 存档状态 S 和存读档。只有一个存档位（prophecy.json: single_save_slot），只有自动存档。
## 字段：
##   vars       Yarn 变量（$D1、$kay_believes_you、$c_kay……）
##   visited    走过的对话节点
##   quests     任务进度（quests.gd 写）
##   unlocks    学会的能力 id；失去的能力从这里拿掉
##   book       预言簿：[{decision, after: [文本键]}]
##   area, cell 站在哪
##   defeated   打赢过的刷新点 id（spawns.json），不再出现
##   version    存档格式版本，格式变了要写迁移（save-load）。2：加了成长、背包、圣龛、宝物（Party.restore() 补旧存档）
##   prog, tree, boons, pending_levels, gear, bag, potions, silver, hp, seed, rng_n, uid_n, xp_total   Party 管（party.gd）
##   shrines, last_shrine, opened, metrics   祈祷过的圣龛、上次祈祷的、开过的宝物、试玩记录（main.gd / world.gd 写）

const SAVE_PATH := "user://save.json"
const VERSION := 2

var S := {}

func _ready() -> void:
	new_game()

func new_game() -> void:
	S = {"version": VERSION, "vars": {}, "visited": {}, "quests": {}, "unlocks": [], "book": [],
		"area": "manor", "cell": null, "defeated": [], "shrines": [], "last_shrine": "", "opened": [], "metrics": {}}
	for sp in Data.param("story-unlocks", "starting_spells", []):
		S.unlocks.append("spell_" + sp)

func book_page(decision: String) -> Dictionary:
	for p in S.book:
		if p.decision == decision: return p
	return {}

func save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(S))
	return true

func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY: return false
	S = d
	for k in ["shrines", "opened", "defeated"]:
		if not S.has(k): S[k] = []
	if not S.has("last_shrine"): S["last_shrine"] = ""
	if not S.has("metrics"): S["metrics"] = {}
	S.version = VERSION
	return true

func has_save() -> bool: return FileAccess.file_exists(SAVE_PATH)
