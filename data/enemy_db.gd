class_name EnemyDB
## The 22 enemy kinds. Behaviour lives in game/enemy.gd, this file is just data.
##
## Common keys: name, hp, gold, flying, stationary, boss, desc
## Extra keys used by Enemy:
##   speed  walk/fly speed (px/s)      w, h   collision half-size (px)
##   r      hit-test radius for shots  kb     knockback multiplier (0 = immune)
##   scale  art scale (feet-aligned)   top    px above centre for bars / markers

const ALL := {
	"squire": {
		"name": "Squire", "hp": 2.0, "gold": 2, "flying": false, "stationary": false, "boss": false,
		"desc": "Eager young soldier. Pokes you with a sword if you let him.",
		"speed": 42.0, "w": 4.0, "h": 6.0, "r": 8.0, "kb": 1.0, "top": 10.0,
	},
	"knight": {
		"name": "Shield Knight", "hp": 5.0, "gold": 5, "flying": false, "stationary": false, "boss": false,
		"desc": "Shield up in front. Hit him from behind, above, or with explosions.",
		"speed": 30.0, "w": 5.0, "h": 6.0, "r": 9.0, "kb": 0.7, "top": 10.0,
	},
	"archer": {
		"name": "Archer", "hp": 2.0, "gold": 4, "flying": false, "stationary": false, "boss": false,
		"desc": "Lobs arcing arrows and leads his target.",
		"speed": 38.0, "w": 4.0, "h": 6.0, "r": 8.0, "kb": 1.0, "top": 10.0,
	},
	"crossbow": {
		"name": "Crossbowman", "hp": 3.0, "gold": 5, "flying": false, "stationary": false, "boss": false,
		"desc": "Fast, flat bolts after a short aim.",
		"speed": 34.0, "w": 4.0, "h": 6.0, "r": 8.0, "kb": 1.0, "top": 10.0,
	},
	"bomber": {
		"name": "Bomb Carrier", "hp": 3.0, "gold": 5, "flying": false, "stationary": false, "boss": false,
		"desc": "Carries a huge bomb overhead and lobs it at you.",
		"speed": 30.0, "w": 4.0, "h": 6.0, "r": 10.0, "kb": 1.0, "top": 24.0,
	},
	"spearman": {
		"name": "Spearman", "hp": 3.0, "gold": 5, "flying": false, "stationary": false, "boss": false,
		"desc": "Throws spears in a flat arc.",
		"speed": 36.0, "w": 4.0, "h": 6.0, "r": 8.0, "kb": 1.0, "top": 12.0,
	},
	"mage": {
		"name": "Mage", "hp": 3.0, "gold": 8, "flying": false, "stationary": false, "boss": false,
		"desc": "Casts slow homing orbs, then blinks away.",
		"speed": 24.0, "w": 4.0, "h": 6.0, "r": 10.0, "kb": 1.0, "top": 18.0,
	},
	"cleric": {
		"name": "Cleric", "hp": 3.0, "gold": 8, "flying": false, "stationary": false, "boss": false,
		"desc": "Heals nearby soldiers with a glowing pulse. Take him out first.",
		"speed": 34.0, "w": 4.0, "h": 6.0, "r": 9.0, "kb": 1.0, "top": 16.0,
	},
	"balloon": {
		"name": "Balloon Bomber", "hp": 4.0, "gold": 7, "flying": true, "stationary": false, "boss": false,
		"desc": "Floats over you and drops bombs. Pop the balloon and he falls.",
		"speed": 40.0, "w": 4.0, "h": 6.0, "r": 12.0, "kb": 1.0, "top": 30.0,
	},
	"rocketeer": {
		"name": "Rocketeer", "hp": 3.0, "gold": 8, "flying": true, "stationary": false, "boss": false,
		"desc": "Jetpack soldier that circles, then rams you.",
		"speed": 90.0, "w": 4.0, "h": 6.0, "r": 9.0, "kb": 1.0, "top": 12.0,
	},
	"ballista": {
		"name": "Ballista", "hp": 8.0, "gold": 12, "flying": false, "stationary": true, "boss": false,
		"desc": "Fires a huge bolt along a long red aim line. Move!",
		"speed": 0.0, "w": 8.0, "h": 6.0, "r": 11.0, "kb": 0.0, "top": 12.0,
	},
	"cannon": {
		"name": "Cannon", "hp": 8.0, "gold": 12, "flying": false, "stationary": true, "boss": false,
		"desc": "Lobs cannonballs in a high arc.",
		"speed": 0.0, "w": 8.0, "h": 5.0, "r": 10.0, "kb": 0.0, "top": 10.0,
	},
	"catapult": {
		"name": "Catapult", "hp": 10.0, "gold": 14, "flying": false, "stationary": true, "boss": false,
		"desc": "Hurls a big slow boulder that crushes everything.",
		"speed": 0.0, "w": 12.0, "h": 8.0, "r": 14.0, "kb": 0.0, "top": 18.0,
	},
	"berserker": {
		"name": "Berserker", "hp": 6.0, "gold": 9, "flying": false, "stationary": false, "boss": false,
		"desc": "Charges when you are close. Stuns himself on walls.",
		"speed": 32.0, "w": 5.0, "h": 7.0, "r": 10.0, "kb": 0.5, "scale": 1.15, "top": 12.0,
	},
	"ice_mage": {
		"name": "Ice Mage", "hp": 4.0, "gold": 10, "flying": false, "stationary": false, "boss": false,
		"desc": "Fires a fan of ice shards that slow you down.",
		"speed": 24.0, "w": 4.0, "h": 6.0, "r": 10.0, "kb": 1.0, "top": 18.0,
	},
	"bat": {
		"name": "Cave Bat", "hp": 1.0, "gold": 2, "flying": true, "stationary": false, "boss": false,
		"desc": "Erratic flyer that swoops at you.",
		"speed": 70.0, "w": 4.0, "h": 3.0, "r": 7.0, "kb": 1.0, "top": 8.0,
	},
	"slime": {
		"name": "Slime", "hp": 3.0, "gold": 3, "flying": false, "stationary": false, "boss": false,
		"desc": "Bouncy. Splits into two small slimes when it pops.",
		"speed": 50.0, "w": 6.0, "h": 5.0, "r": 8.0, "kb": 1.0, "top": 8.0,
	},
	"skeleton": {
		"name": "Skeleton", "hp": 3.0, "gold": 4, "flying": false, "stationary": false, "boss": false,
		"desc": "Collapses into bones and rises again. Burn or blast the bones!",
		"speed": 50.0, "w": 4.0, "h": 6.0, "r": 8.0, "kb": 1.0, "top": 10.0,
	},
	"arrow_trap": {
		"name": "Arrow Trap", "hp": 6.0, "gold": 6, "flying": false, "stationary": true, "boss": false,
		"desc": "Wall-mounted. Fires volleys of three arrows.",
		"speed": 0.0, "w": 5.0, "h": 5.0, "r": 8.0, "kb": 0.0, "top": 9.0,
	},
	"ghost": {
		"name": "Ghost", "hp": 3.0, "gold": 8, "flying": true, "stationary": false, "boss": false,
		"desc": "Drifts through walls. Only hurts while visible.",
		"speed": 38.0, "w": 5.0, "h": 6.0, "r": 10.0, "kb": 0.8, "top": 11.0,
	},
	"golden_knight": {
		"name": "Golden Knight", "hp": 40.0, "gold": 80, "flying": false, "stationary": false, "boss": true,
		"desc": "Heavy gold armour. Charges, leaps, and shakes the ground.",
		"speed": 34.0, "w": 9.0, "h": 14.0, "r": 16.0, "kb": 0.1, "scale": 2.0, "top": 20.0, "mini": true,
	},
	"warlord": {
		"name": "Warlord", "hp": 90.0, "gold": 200, "flying": false, "stationary": false, "boss": true,
		"desc": "Rains arrows, slams the ground and calls reinforcements.",
		"speed": 24.0, "w": 14.0, "h": 18.0, "r": 21.0, "kb": 0.05, "scale": 2.5, "top": 26.0,
	},
}


## Returns a copy of the definition (safe to modify), or the squire for unknown ids.
static func get_def(kind: String) -> Dictionary:
	var d: Dictionary = ALL.get(kind, ALL["squire"])
	return d.duplicate()
