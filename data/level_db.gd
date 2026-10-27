class_name LevelDB
## Level definitions. Levels are built by LevelGen from these parameters with a
## fixed seed, so every numbered level is always the same layout.

const CASTLE_NAMES := [
	"Sleepy Outpost", "Moonlit Bridge", "Bomb Hill", "Spear Ridge", "Balloon Pass",
	"Twin Towers", "Archer Alley", "The Aqueduct", "Siege Fields", "Warlord's Keep",
	"Dusk Gate", "Crossbow Crag", "Arcane Spires", "Holy Ramparts", "Golden Bastion",
	"Rocket Range", "Frozen Walls", "Catapult Canyon", "Phantom Fort", "Throne of Ash",
]

const DUNGEON_NAMES := [
	"Bat Cellar", "Slime Pit", "Bone Hall", "Trap Corridor", "Golden Vault",
	"Chain Gallery", "Flooded Crypt", "Haunted Wing", "Armory", "Warden's Den",
	"Crimson Cells", "Echo Halls", "Spike Gardens", "Sunken Shrine", "Gilded Tomb",
	"Arrow Maze", "Frost Catacomb", "Siege Vault", "Spectral Ward", "Heart of the Keep",
]

## Enemy kinds that enter the castle pool at each level (cumulative).
const CASTLE_INTRO := {
	1: ["squire", "archer"], 2: ["knight"], 3: ["bomber"], 4: ["spearman"], 5: ["balloon"],
	6: ["ballista"], 7: ["crossbow"], 8: ["cleric"], 9: ["cannon"], 11: ["mage", "rocketeer"],
	12: ["berserker"], 14: ["ice_mage"], 16: ["catapult"], 18: ["ghost"],
}

## Enemy kinds that enter the dungeon pool at each level (cumulative).
const DUNGEON_INTRO := {
	1: ["bat", "squire"], 2: ["slime"], 3: ["skeleton", "archer"], 4: ["arrow_trap"],
	6: ["knight", "bomber"], 7: ["mage"], 8: ["ghost"], 9: ["crossbow", "spearman"],
	11: ["berserker"], 12: ["cleric", "rocketeer"], 14: ["ice_mage"], 16: ["cannon"],
}

const CASTLE_BOSSES := {5: "golden_knight", 10: "warlord", 15: "golden_knight", 20: "warlord"}
const DUNGEON_BOSSES := {5: "golden_knight", 10: "golden_knight", 15: "warlord", 20: "warlord"}


static func _pool(intro: Dictionary, n: int) -> Array:
	var pool := []
	for lvl in intro.keys():
		if lvl <= n:
			pool.append_array(intro[lvl])
	return pool


## {name, track, n, seed, length, pool, density, palette, boss, difficulty}
static func castle(n: int) -> Dictionary:
	return {
		"track": "castle",
		"n": n,
		"name": CASTLE_NAMES[n - 1],
		"seed": 1000 + n * 7919,
		"length": 2600 + n * 260,
		"pool": _pool(CASTLE_INTRO, n),
		"density": 0.55 + n * 0.045,
		"palette": "night" if n <= 10 else "dusk",
		"boss": CASTLE_BOSSES.get(n, ""),
		"difficulty": 1.0 + (n - 1) * 0.08,
	}


## {name, track, n, seed, rooms, waves, pool, palette, boss, par_time, combo_target, difficulty}
static func dungeon(n: int) -> Dictionary:
	return {
		"track": "dungeon",
		"n": n,
		"name": DUNGEON_NAMES[n - 1],
		"seed": 5000 + n * 6271,
		"rooms": 2 + n / 4,
		"waves": 2 + n / 7,
		"pool": _pool(DUNGEON_INTRO, n),
		"palette": "dungeon" if n <= 10 else "crimson",
		"boss": DUNGEON_BOSSES.get(n, ""),
		"par_time": 45.0 + n * 6.0,
		"combo_target": 4 + n / 2,
		"difficulty": 1.0 + (n - 1) * 0.08,
	}


## Endless: everything unlocked so far, random seed, difficulty grows with progress.
static func endless(track: String) -> Dictionary:
	var base := castle(20) if track == "castle" else dungeon(20)
	base.name = "Endless " + ("Castles" if track == "castle" else "Dungeon")
	base.seed = randi()
	base.endless = true
	base.boss = ""
	base.difficulty = 1.0
	return base


static func get_level(track: String, n: int) -> Dictionary:
	return castle(n) if track == "castle" else dungeon(n)
