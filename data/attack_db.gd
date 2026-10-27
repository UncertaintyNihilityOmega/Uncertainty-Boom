class_name AttackDB
## The 60 attack styles. Each entry only lists what differs from DEFAULTS.
## Bought with gold in the Nest; "level" is the dragon level required to buy.
##
## pattern: ""        fan of `count` shots over `spread` degrees
##          "ring"    `count` shots evenly around 360 degrees
##          "back"    fan forward + mirrored fan backward
##          "wall"    `count` parallel shots side by side
##          "spiral"  `count` shots whose base angle rotates every shot
##          "twin_wave" two shots weaving in opposite phase
##          "rain"    `count` shots falling from the sky onto the aim point
##          "orbit"   `count` shots circling the dragon for `life` seconds
##          "mine"    shots stop after a short flight and wait for enemies
##          "chain"   instant lightning jumping between `count` enemies
## effect:  "burn" | "freeze" | "shock" | "poison"
## phase:   true = flies through walls and floors

const DEFAULTS := {
	"count": 1, "spread": 0.0, "speed": 420.0, "dmg": 1.0, "size": 3.0, "cd": 0.28,
	"burst": 1, "burst_gap": 0.07, "gravity": 0.0, "pierce": 0, "bounce": 0,
	"homing": 0.0, "explode": 0.0, "split": 0, "wave": 0.0, "life": 1.4,
	"knock": 170.0, "color": "ff8a20", "shape": "orb", "pattern": "", "effect": "",
	"jitter": 0.0, "accel": 0.0, "boomerang": false, "phase": false, "price": 0, "level": 1, "sound": "shoot",
}

const LIST := [
	# ---- Tier 1
	{"id": "ember", "name": "Ember Spit", "desc": "A trusty fireball.", "cd": 0.3},
	{"id": "twin", "name": "Twin Flame", "desc": "Two fireballs side by side.", "count": 2, "spread": 6.0, "price": 150, "cd": 0.32},
	{"id": "rapid", "name": "Spark Stream", "desc": "Tiny sparks, very fast.", "size": 2.0, "dmg": 0.5, "cd": 0.15, "speed": 520.0, "color": "ffd040", "price": 250},
	{"id": "trident", "name": "Trident", "desc": "Three-way spread.", "count": 3, "spread": 22.0, "price": 400, "level": 2, "cd": 0.34},
	{"id": "comet", "name": "Comet", "desc": "Big slow comet that explodes.", "size": 6.0, "dmg": 3.0, "cd": 0.55, "explode": 26.0, "speed": 360.0, "shape": "comet", "price": 500, "level": 2, "sound": "shoot_big"},
	{"id": "lob", "name": "Lava Lob", "desc": "Arcing lava blob.", "gravity": 700.0, "speed": 380.0, "explode": 30.0, "dmg": 2.5, "cd": 0.5, "shape": "bomb", "color": "ff5020", "price": 600, "level": 3},
	{"id": "serpent", "name": "Serpent Flame", "desc": "Weaving fire snake.", "wave": 16.0, "price": 650, "level": 3, "cd": 0.3},
	{"id": "seeker", "name": "Seeker", "desc": "Homes in on enemies.", "homing": 5.0, "speed": 330.0, "life": 2.2, "color": "ff70d0", "price": 800, "level": 3, "cd": 0.32},
	{"id": "lance", "name": "Flame Lance", "desc": "Pierces 3 enemies.", "pierce": 3, "speed": 760.0, "shape": "bolt", "dmg": 1.5, "cd": 0.4, "price": 900, "level": 4},
	{"id": "bouncer", "name": "Bouncing Ember", "desc": "Bounces off walls.", "bounce": 4, "life": 2.5, "gravity": 500.0, "price": 950, "level": 4, "cd": 0.34},
	# ---- Tier 2
	{"id": "buckshot", "name": "Dragon Buckshot", "desc": "Short-range blast.", "count": 7, "spread": 36.0, "jitter": 0.15, "life": 0.4, "dmg": 0.8, "cd": 0.6, "price": 1200, "level": 5},
	{"id": "triple_tap", "name": "Triple Tap", "desc": "Three quick shots.", "burst": 3, "burst_gap": 0.06, "cd": 0.45, "price": 1300, "level": 5},
	{"id": "nova", "name": "Nova Ring", "desc": "Fire in every direction.", "pattern": "ring", "count": 12, "speed": 300.0, "life": 0.8, "cd": 0.9, "price": 1500, "level": 6},
	{"id": "rear", "name": "Rear Guard", "desc": "Shoots forward and back.", "pattern": "back", "count": 2, "spread": 10.0, "price": 1600, "level": 6, "cd": 0.34},
	{"id": "cluster", "name": "Cluster Bomb", "desc": "Splits into 6 on impact.", "split": 6, "explode": 20.0, "dmg": 2.0, "cd": 0.7, "shape": "bomb", "gravity": 300.0, "price": 1700, "level": 6},
	{"id": "frost", "name": "Frost Breath", "desc": "Freezes enemies.", "effect": "freeze", "color": "80e0ff", "count": 3, "spread": 14.0, "price": 1800, "level": 7, "sound": "ice", "cd": 0.34},
	{"id": "meteor", "name": "Meteor Rain", "desc": "Meteors fall on the cursor.", "pattern": "rain", "count": 5, "size": 5.0, "dmg": 2.0, "explode": 24.0, "cd": 1.0, "color": "ff4010", "price": 2000, "level": 7},
	{"id": "boomerang", "name": "Fire Boomerang", "desc": "Flies out and comes back.", "boomerang": true, "life": 1.4, "pierce": 99, "speed": 460.0, "shape": "ring", "price": 2100, "level": 8, "phase": true},
	{"id": "wildfire", "name": "Wildfire", "desc": "Chaotic spray.", "count": 5, "spread": 50.0, "jitter": 0.3, "cd": 0.4, "dmg": 0.8, "price": 2200, "level": 8},
	{"id": "storm", "name": "Storm Breath", "desc": "Lightning jumps 3 enemies.", "pattern": "chain", "count": 3, "dmg": 1.5, "cd": 0.55, "color": "a0c8ff", "effect": "shock", "price": 2400, "level": 8, "sound": "zap"},
	{"id": "venom", "name": "Venom Spit", "desc": "Poison splash.", "effect": "poison", "color": "80ff60", "gravity": 300.0, "explode": 18.0, "price": 2500, "level": 9, "cd": 0.34},
	{"id": "orbit", "name": "Orbiting Embers", "desc": "Three embers circle you.", "pattern": "orbit", "count": 3, "life": 3.0, "cd": 1.6, "dmg": 1.5, "price": 2600, "level": 9},
	{"id": "rocket", "name": "Rocket Flame", "desc": "Accelerates, then explodes.", "accel": 900.0, "speed": 100.0, "explode": 32.0, "dmg": 3.0, "cd": 0.7, "shape": "comet", "price": 2800, "level": 9},
	{"id": "firewall", "name": "Firewall", "desc": "A wall of five flames.", "pattern": "wall", "count": 5, "speed": 340.0, "pierce": 2, "price": 3000, "level": 10},
	{"id": "spiral", "name": "Spiral Fire", "desc": "Spinning stream.", "pattern": "spiral", "count": 2, "cd": 0.14, "size": 2.5, "dmg": 0.6, "price": 3200, "level": 10},
	# ---- Tier 3
	{"id": "twin_serpent", "name": "Twin Serpents", "desc": "Two weaving snakes.", "pattern": "twin_wave", "count": 2, "wave": 18.0, "price": 3500, "level": 11, "cd": 0.36},
	{"id": "quad", "name": "Quad Flame", "desc": "Four-way spread.", "count": 4, "spread": 28.0, "price": 3600, "level": 11, "cd": 0.38},
	{"id": "wasp", "name": "Wasp Swarm", "desc": "Six tiny homing sparks.", "count": 6, "spread": 70.0, "homing": 6.0, "size": 2.0, "dmg": 0.6, "speed": 280.0, "life": 2.0, "cd": 0.7, "color": "ffe040", "price": 3800, "level": 11, "phase": true},
	{"id": "volcano", "name": "Volcano", "desc": "Three lava bombs.", "count": 3, "spread": 30.0, "gravity": 800.0, "speed": 460.0, "explode": 34.0, "dmg": 2.5, "cd": 0.9, "shape": "bomb", "price": 4200, "level": 12},
	{"id": "penta", "name": "Pentaflame", "desc": "Five-way spread.", "count": 5, "spread": 44.0, "price": 4500, "level": 12, "cd": 0.42},
	{"id": "sniper", "name": "Sky Piercer", "desc": "Fast bolt through everything.", "speed": 1200.0, "pierce": 99, "dmg": 5.0, "cd": 0.9, "shape": "bolt", "size": 2.0, "color": "fff0a0", "price": 4800, "level": 13, "phase": true},
	{"id": "mines", "name": "Ember Mines", "desc": "Drop explosive mines.", "pattern": "mine", "explode": 40.0, "dmg": 4.0, "cd": 0.8, "life": 8.0, "price": 5000, "level": 13},
	{"id": "shock_ring", "name": "Shock Nova", "desc": "Stunning ring of sparks.", "pattern": "ring", "count": 16, "effect": "shock", "color": "a0c8ff", "life": 0.5, "speed": 360.0, "cd": 1.1, "price": 5200, "level": 14, "sound": "zap"},
	{"id": "ice_lance", "name": "Ice Lance", "desc": "Freezing piercer.", "effect": "freeze", "pierce": 4, "speed": 800.0, "shape": "bolt", "color": "80e0ff", "dmg": 2.0, "cd": 0.45, "price": 5400, "level": 14, "sound": "ice"},
	{"id": "inferno", "name": "Inferno", "desc": "Sets enemies ablaze.", "effect": "burn", "count": 3, "spread": 18.0, "size": 4.0, "dmg": 1.2, "color": "ff3010", "price": 5600, "level": 15, "cd": 0.38},
	{"id": "pinball", "name": "Pinball", "desc": "Three wild bouncers.", "count": 3, "spread": 30.0, "bounce": 6, "life": 3.0, "price": 5800, "level": 15, "cd": 0.45},
	{"id": "hunter", "name": "Hunter Comet", "desc": "Homing explosive comet.", "homing": 3.5, "size": 5.0, "dmg": 3.0, "explode": 28.0, "cd": 0.65, "shape": "comet", "speed": 300.0, "life": 2.5, "price": 6000, "level": 16},
	{"id": "hail", "name": "Hailstorm", "desc": "Freezing hail from above.", "pattern": "rain", "count": 8, "effect": "freeze", "color": "c0f0ff", "dmg": 1.0, "cd": 0.9, "price": 6200, "level": 16, "sound": "ice"},
	{"id": "split_lance", "name": "Splitting Lance", "desc": "Pierces, then splits.", "pierce": 1, "split": 4, "speed": 700.0, "shape": "bolt", "price": 6400, "level": 17},
	{"id": "crossfire", "name": "Crossfire", "desc": "Spread both ways.", "pattern": "back", "count": 4, "spread": 30.0, "price": 6600, "level": 17, "cd": 0.42},
	# ---- Tier 4
	{"id": "thunder", "name": "Thunder Chain", "desc": "Lightning jumps 6 enemies.", "pattern": "chain", "count": 6, "dmg": 2.0, "effect": "shock", "cd": 0.6, "color": "c0d8ff", "price": 8000, "level": 19, "sound": "zap"},
	{"id": "halo", "name": "Ember Halo", "desc": "Six embers circle you.", "pattern": "orbit", "count": 6, "life": 4.0, "cd": 2.2, "dmg": 2.0, "price": 8500, "level": 19},
	{"id": "gatling", "name": "Dragon Gatling", "desc": "Absurd fire rate.", "cd": 0.1, "size": 2.0, "dmg": 0.45, "jitter": 0.12, "speed": 600.0, "price": 9000, "level": 20},
	{"id": "mortar", "name": "Mortar Barrage", "desc": "Four lobbed bombs.", "burst": 4, "burst_gap": 0.1, "gravity": 700.0, "speed": 420.0, "explode": 28.0, "dmg": 2.0, "cd": 1.0, "jitter": 0.2, "shape": "bomb", "price": 9500, "level": 20},
	{"id": "plasma", "name": "Plasma Orb", "desc": "Slow orb, melts all.", "size": 8.0, "dmg": 4.0, "pierce": 99, "speed": 220.0, "life": 2.5, "cd": 1.0, "color": "c060ff", "price": 10000, "level": 21, "sound": "magic", "phase": true},
	{"id": "starburst", "name": "Starburst", "desc": "Bursts into 8 stars.", "split": 8, "explode": 16.0, "shape": "star", "color": "fff060", "cd": 0.55, "price": 10500, "level": 21},
	{"id": "dragon_rain", "name": "Dragonfire Rain", "desc": "Twelve meteors.", "pattern": "rain", "count": 12, "explode": 20.0, "dmg": 1.5, "cd": 1.2, "price": 11000, "level": 22},
	{"id": "plague", "name": "Plague Cloud", "desc": "Poison ring.", "effect": "poison", "pattern": "ring", "count": 10, "speed": 160.0, "life": 1.2, "size": 5.0, "color": "80ff60", "cd": 1.2, "price": 11500, "level": 22},
	{"id": "helix", "name": "Double Helix", "desc": "Four-arm spiral.", "pattern": "spiral", "count": 4, "cd": 0.16, "size": 2.5, "dmg": 0.7, "price": 12000, "level": 23},
	{"id": "glacier", "name": "Glacier Wall", "desc": "Wall of ice.", "pattern": "wall", "count": 7, "effect": "freeze", "pierce": 3, "color": "80e0ff", "cd": 0.8, "price": 12500, "level": 24, "sound": "ice"},
	# ---- Tier 5
	{"id": "hellfire", "name": "Hellfire", "desc": "Burning explosive spread.", "count": 5, "spread": 30.0, "effect": "burn", "explode": 18.0, "dmg": 1.5, "cd": 0.45, "color": "ff2000", "price": 15000, "level": 27},
	{"id": "phoenix", "name": "Phoenix Swarm", "desc": "Ten homing firebirds.", "count": 10, "spread": 120.0, "homing": 7.0, "life": 2.5, "speed": 260.0, "dmg": 0.9, "cd": 0.9, "color": "ffa040", "price": 16000, "level": 28, "phase": true},
	{"id": "railgun", "name": "Railgun", "desc": "Devastating beam bolt.", "speed": 1600.0, "pierce": 99, "dmg": 9.0, "size": 3.0, "cd": 1.2, "shape": "bolt", "color": "80ffff", "price": 17000, "level": 29, "sound": "zap", "phase": true},
	{"id": "supernova", "name": "Supernova", "desc": "Exploding ring of 24.", "pattern": "ring", "count": 24, "explode": 14.0, "dmg": 1.5, "speed": 320.0, "life": 0.7, "cd": 1.4, "price": 18000, "level": 30, "sound": "shoot_big"},
	{"id": "black_hole", "name": "Black Hole", "desc": "Slow devouring void.", "size": 9.0, "dmg": 2.0, "pierce": 99, "speed": 120.0, "life": 3.0, "homing": 1.0, "effect": "shock", "color": "8040d0", "cd": 1.6, "price": 19000, "level": 31, "sound": "magic", "phase": true},
	{"id": "mega_comet", "name": "Mega Comet", "desc": "Huge explosive comet.", "size": 10.0, "dmg": 8.0, "explode": 60.0, "speed": 320.0, "cd": 1.3, "shape": "comet", "price": 20000, "level": 32, "sound": "shoot_big"},
	{"id": "tempest", "name": "Tempest", "desc": "Lightning jumps 10 enemies.", "pattern": "chain", "count": 10, "dmg": 2.5, "effect": "shock", "cd": 0.5, "color": "e0e8ff", "price": 22000, "level": 33, "sound": "zap"},
	{"id": "omniflame", "name": "Omniflame", "desc": "Homing fire both ways.", "pattern": "back", "count": 6, "spread": 60.0, "homing": 2.0, "cd": 0.4, "price": 24000, "level": 34},
	{"id": "armageddon", "name": "Armageddon", "desc": "Twenty meteors.", "pattern": "rain", "count": 20, "explode": 26.0, "dmg": 2.5, "cd": 1.5, "color": "ff3000", "price": 27000, "level": 35, "sound": "shoot_big"},
	{"id": "dragon_god", "name": "Dragon God Breath", "desc": "Everything at once.", "count": 7, "spread": 50.0, "pierce": 3, "explode": 20.0, "effect": "burn", "homing": 2.0, "dmg": 2.0, "cd": 0.45, "color": "ffd700", "price": 30000, "level": 36},
]

static var _cache := {}


static func get_attack(id: String) -> Dictionary:
	if _cache.is_empty():
		for entry in LIST:
			var a: Dictionary = DEFAULTS.duplicate()
			a.merge(entry, true)
			a.color = Color(a.color)
			_cache[a.id] = a
	return _cache.get(id, _cache["ember"])


static func all_ids() -> Array:
	var ids := []
	for entry in LIST:
		ids.append(entry.id)
	return ids
