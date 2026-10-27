extends Node
## Save data, progression, currencies, unlocks, stats, achievements and settings.
## Single owner of persistent state: everything else goes through these methods.

const SAVE_VERSION := 1
const CASTLE_LEVELS := 20
const DUNGEON_LEVELS := 20
const CREATIVE_DISPLAY := 999999

const DEFAULT_SETTINGS := {
	"master": 0.8,
	"music": 0.6,
	"sfx": 0.8,
	"muted": false,
	"creative": false,
	"keyboard_mode": false,
	"fullscreen": false,
	"screen_shake": true,
}

var save_path := "user://save.dat"
var data: Dictionary = {}
## The run being played: {"track": "castle"|"dungeon", "level": int, "endless": bool}
var current: Dictionary = {}

var _level_cache := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	load_save()
	_apply_display()


# ---------------------------------------------------------------- persistence

func _fresh_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"gold": 0,
		"lifetime_gold": 0,
		"keys": 0,
		"owned_attacks": ["ember"],
		"equipped_attack": "ember",
		"owned_dragons": ["ember"],
		"equipped_dragon": "ember",
		"castle": {},   # "n" -> {done, stars:[b,b,b], best_gold}
		"dungeon": {},  # "n" -> {done, stars:[b,b,b], best_time}
		"endless": {"castle_best": 0, "castle_best_gold": 0, "dungeon_best": 0, "dungeon_best_gold": 0},
		"stats": {},
		"achievements": [],
		"settings": DEFAULT_SETTINGS.duplicate(),
	}


## Switches to another save file (used by debug runs so tests never touch the real save).
func use_save_file(path: String) -> void:
	save_path = path
	load_save()


func load_save() -> void:
	data = _fresh_data()
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f:
			var loaded = str_to_var(f.get_as_text())
			if loaded is Dictionary:
				for k in loaded.keys():
					data[k] = loaded[k]
	# Fill settings added after the save was written.
	for k in DEFAULT_SETTINGS.keys():
		if not data.settings.has(k):
			data.settings[k] = DEFAULT_SETTINGS[k]
	_level_cache = -1


func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(var_to_str(data))


func reset_save() -> void:
	var keep_settings: Dictionary = data.settings.duplicate()
	keep_settings.creative = false
	data = _fresh_data()
	data.settings = keep_settings
	_level_cache = -1
	save()
	Events.save_reset.emit()
	Events.currency_changed.emit()


# ---------------------------------------------------------------- currencies

func is_creative() -> bool:
	return bool(data.settings.creative)


func get_gold() -> int:
	return CREATIVE_DISPLAY if is_creative() else int(data.gold)


func get_keys() -> int:
	return CREATIVE_DISPLAY if is_creative() else int(data.keys)


func can_afford(gold: int) -> bool:
	return is_creative() or int(data.gold) >= gold


func can_afford_keys(keys: int) -> bool:
	return is_creative() or int(data.keys) >= keys


## Gold earned in play: counts toward dragon level (lifetime) and wallet.
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	var before := dragon_level()
	data.gold = int(data.gold) + amount
	data.lifetime_gold = int(data.lifetime_gold) + amount
	_level_cache = -1
	if dragon_level() > before:
		Sfx.play("levelup")
	Events.currency_changed.emit()
	check_achievements()


func spend_gold(amount: int) -> bool:
	if not can_afford(amount):
		return false
	if not is_creative():
		data.gold = int(data.gold) - amount
		stat_add("gold_spent", amount)
	Events.currency_changed.emit()
	return true


func add_keys(amount: int) -> void:
	if amount <= 0:
		return
	data.keys = int(data.keys) + amount
	stat_add("keys_earned", amount)
	Events.currency_changed.emit()


func spend_keys(amount: int) -> bool:
	if not can_afford_keys(amount):
		return false
	if not is_creative():
		data.keys = int(data.keys) - amount
	Events.currency_changed.emit()
	return true


# ---------------------------------------------------------------- dragon level (power)

static func xp_for_level(lvl: int) -> int:
	return 150 + 60 * (lvl - 1)


func dragon_level() -> int:
	if _level_cache < 0:
		var xp := int(data.lifetime_gold)
		var lvl := 1
		while xp >= xp_for_level(lvl):
			xp -= xp_for_level(lvl)
			lvl += 1
		_level_cache = lvl
	return _level_cache


## x = gold earned inside the current level, y = gold needed for the next one.
func level_progress() -> Vector2i:
	var xp := int(data.lifetime_gold)
	var lvl := 1
	while xp >= xp_for_level(lvl):
		xp -= xp_for_level(lvl)
		lvl += 1
	return Vector2i(xp, xp_for_level(lvl))


## Damage multiplier from dragon level (+4% per level).
func power_mult() -> float:
	return 1.0 + 0.04 * float(dragon_level() - 1)


# ---------------------------------------------------------------- attacks & dragons

func owns_attack(id: String) -> bool:
	return data.owned_attacks.has(id)


func attack_locked_by_level(id: String) -> bool:
	return not is_creative() and dragon_level() < int(AttackDB.get_attack(id).get("level", 1))


func buy_attack(id: String) -> bool:
	if owns_attack(id) or attack_locked_by_level(id):
		return false
	if not spend_gold(int(AttackDB.get_attack(id).price)):
		Sfx.play("error")
		return false
	data.owned_attacks.append(id)
	equip_attack(id)
	Sfx.play("buy")
	check_achievements()
	save()
	return true


func equip_attack(id: String) -> void:
	if owns_attack(id):
		data.equipped_attack = id
		save()


func equipped_attack() -> String:
	return data.equipped_attack


func owns_dragon(id: String) -> bool:
	return data.owned_dragons.has(id)


func buy_dragon(id: String) -> bool:
	if owns_dragon(id):
		return false
	if not spend_keys(int(DragonDB.get_dragon(id).price)):
		Sfx.play("error")
		return false
	data.owned_dragons.append(id)
	equip_dragon(id)
	Sfx.play("buy")
	check_achievements()
	save()
	return true


func equip_dragon(id: String) -> void:
	if owns_dragon(id):
		data.equipped_dragon = id
		save()


func equipped_dragon() -> String:
	return data.equipped_dragon


# ---------------------------------------------------------------- levels

func level_count(track: String) -> int:
	return CASTLE_LEVELS if track == "castle" else DUNGEON_LEVELS


## {done: bool, stars: [bool, bool, bool], best_gold: int, best_time: float}
func level_record(track: String, n: int) -> Dictionary:
	var rec: Dictionary = data[track].get(str(n), {})
	return {
		"done": rec.get("done", false),
		"stars": rec.get("stars", [false, false, false]),
		"best_gold": rec.get("best_gold", 0),
		"best_time": rec.get("best_time", 0.0),
	}


func is_level_unlocked(track: String, n: int) -> bool:
	if is_creative() or n == 1 and track == "castle":
		return true
	if track == "castle":
		return level_record("castle", n - 1).done
	if n == 1:
		return level_record("castle", 3).done
	return level_record("dungeon", n - 1).done


func is_endless_unlocked(track: String) -> bool:
	if is_creative():
		return true
	return level_record(track, 5).done


func endless_record(track: String) -> Dictionary:
	return {
		"best": data.endless.get(track + "_best", 0),
		"best_gold": data.endless.get(track + "_best_gold", 0),
	}


func start_level(track: String, n: int, endless := false) -> void:
	current = {"track": track, "level": n, "endless": endless}
	stat_add("levels_played")
	Events.request_screen.emit("world", current.duplicate())


## Called by the World when a run ends (win or loss). Banks currencies and
## records progress. Returns {"new_stars": int, "new_best": bool, "level_before": int, "level_after": int}.
func submit_result(result: Dictionary) -> Dictionary:
	var out := {"new_stars": 0, "new_best": false, "level_before": dragon_level(), "level_after": 0}
	add_gold(int(result.get("coins", 0)))
	add_keys(int(result.get("keys", 0)))
	var track: String = result.track
	if result.get("endless", false):
		var score := int(result.get("distance", 0)) if track == "castle" else int(result.get("rooms", 0))
		if score > int(data.endless[track + "_best"]):
			data.endless[track + "_best"] = score
			out.new_best = true
		data.endless[track + "_best_gold"] = maxi(int(data.endless[track + "_best_gold"]), int(result.get("coins", 0)))
	elif result.get("won", false):
		var key := str(result.level)
		var rec: Dictionary = data[track].get(key, {"done": false, "stars": [false, false, false], "best_gold": 0, "best_time": 0.0})
		var stars: Array = result.get("stars", [false, false, false])
		for i in 3:
			if stars[i] and not rec.stars[i]:
				rec.stars[i] = true
				out.new_stars += 1
		if not rec.done:
			rec.done = true
		if int(result.get("coins", 0)) > int(rec.best_gold):
			rec.best_gold = int(result.coins)
			out.new_best = track == "castle"
		var t := float(result.get("time", 0.0))
		if track == "dungeon" and (float(rec.best_time) <= 0.0 or t < float(rec.best_time)):
			rec.best_time = t
			out.new_best = true
		data[track][key] = rec
		if stars.count(true) == 3 and result.get("hearts_lost", 1) == 0:
			stat_add("flawless_levels")
	out.level_after = dragon_level()
	check_achievements()
	save()
	return out


func count_stars(track: String) -> int:
	var total := 0
	for key in data[track].keys():
		total += (data[track][key].stars as Array).count(true)
	return total


func count_cleared(track: String) -> int:
	var total := 0
	for key in data[track].keys():
		if data[track][key].done:
			total += 1
	return total


# ---------------------------------------------------------------- stats & achievements

func stat_add(stat: String, amount := 1) -> void:
	data.stats[stat] = int(data.stats.get(stat, 0)) + amount
	check_achievements()


func stat_max(stat: String, value: int) -> void:
	if value > int(data.stats.get(stat, 0)):
		data.stats[stat] = value
		check_achievements()


func get_stat(stat: String) -> int:
	match stat:
		"castle_cleared": return count_cleared("castle")
		"dungeon_cleared": return count_cleared("dungeon")
		"castle_stars": return count_stars("castle")
		"dungeon_stars": return count_stars("dungeon")
		"total_stars": return count_stars("castle") + count_stars("dungeon")
		"attacks_owned": return data.owned_attacks.size()
		"dragons_owned": return data.owned_dragons.size()
		"dragon_level": return dragon_level()
		"gold_earned": return int(data.lifetime_gold)
		"endless_castle_best": return int(data.endless.castle_best)
		"endless_dungeon_best": return int(data.endless.dungeon_best)
		"achievements": return data.achievements.size()
	return int(data.stats.get(stat, 0))


func is_achievement_unlocked(id: String) -> bool:
	return data.achievements.has(id)


func check_achievements() -> void:
	for a in AchievementDB.ALL:
		if data.achievements.has(a.id):
			continue
		if get_stat(a.stat) >= int(a.goal):
			data.achievements.append(a.id)
			Sfx.play("achievement")
			Events.achievement_unlocked.emit(a.id)


# ---------------------------------------------------------------- settings

func get_setting(key: String):
	return data.settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value) -> void:
	data.settings[key] = value
	if key == "fullscreen":
		_apply_display()
	Sfx.apply_settings()
	Events.settings_changed.emit()
	if key == "creative":
		Events.currency_changed.emit()
	save()


func _apply_display() -> void:
	if get_setting("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# ---------------------------------------------------------------- input map

func _register_inputs() -> void:
	_add_keys(&"move_left", [KEY_A, KEY_LEFT])
	_add_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_add_keys(&"jump", [KEY_W, KEY_SPACE, KEY_UP])
	_add_keys(&"dive", [KEY_S, KEY_DOWN])
	_add_keys(&"dash", [KEY_SHIFT])
	_add_keys(&"slowmo_key", [KEY_E])
	_add_keys(&"auto_attack", [KEY_R])
	_add_keys(&"pause", [KEY_ESCAPE, KEY_P])
	_add_mouse(&"fire", MOUSE_BUTTON_LEFT)
	_add_mouse(&"aim_dash", MOUSE_BUTTON_RIGHT)


func _add_keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
