class_name LevelGen
## Procedural builders for castle chunks and dungeon rooms. Deterministic for a
## given RandomNumberGenerator state, so numbered levels never change.
## Each builder returns {"chunk": Chunk, "spawns": [{kind, pos}], "pickups": [{kind, pos}], ...}

const CHUNK_W := 640.0
const BASE_Y := 300.0
const ROOM_W := 960.0
const ROOM_H := 360.0
const FLOOR_Y := 324.0
const CEIL_Y := 18.0

const PALETTES := {
	"night": {
		"sky": "0d2a44", "sky2": "123a5a", "far": "1d4e72", "mid": "0a1a32", "moon": "e0f08a",
		"ground": "00a07a", "ground_dark": "008a6a", "ground_top": "30d0a0",
		"stone": "14b4f0", "stone_light": "7ae8ff", "stone_dark": "0a78b8",
		"flag": "ff8aa0", "pole": "c8d0e0", "tree": "0a6a52", "water": "30c0c0",
		"spike": "c8d0e0", "chain": "ff8aa0", "door": "6a4a2a",
	},
	"dusk": {
		"sky": "4a1430", "sky2": "6a2038", "far": "8a2c44", "mid": "2a0a1c", "moon": "ffb050",
		"ground": "10907a", "ground_dark": "0a7060", "ground_top": "40c8a0",
		"stone": "18a8e8", "stone_light": "80e0ff", "stone_dark": "0a6aa8",
		"flag": "ffd060", "pole": "e0c8c0", "tree": "0a5a48", "water": "40b0c0",
		"spike": "e0c8c0", "chain": "ffd060", "door": "6a3a2a",
	},
	"dungeon": {
		"sky": "0a0e2e", "sky2": "121a46", "far": "161f52", "mid": "070a20", "moon": "000000",
		"ground": "14b4f0", "ground_dark": "0a78b8", "ground_top": "7ae8ff",
		"stone": "14b4f0", "stone_light": "7ae8ff", "stone_dark": "0a78b8",
		"flag": "ff8aa0", "pole": "c8d0e0", "tree": "0a6a52", "water": "20c8c0",
		"spike": "c8d0e0", "chain": "ff8aa0", "door": "a05a28",
	},
	"crimson": {
		"sky": "1e0812", "sky2": "2e0c1c", "far": "3a1022", "mid": "12040a", "moon": "000000",
		"ground": "e04a5a", "ground_dark": "a02a3a", "ground_top": "ff9aa0",
		"stone": "e04a5a", "stone_light": "ff9aa0", "stone_dark": "a02a3a",
		"flag": "ffd060", "pole": "e0c8c0", "tree": "5a1a28", "water": "c03070",
		"spike": "ffd0d0", "chain": "ffd060", "door": "5a3a5a",
	},
}

static var _pal_cache := {}


static func palette(pal_name: String) -> Dictionary:
	if not _pal_cache.has(pal_name):
		var p := {}
		for k in PALETTES[pal_name].keys():
			p[k] = Color(PALETTES[pal_name][k])
		_pal_cache[pal_name] = p
	return _pal_cache[pal_name]


static func pick_kind(rng: RandomNumberGenerator, pool: Array, exclude := []) -> String:
	var options := pool.filter(func(k): return not exclude.has(k))
	if options.is_empty():
		return pool[0]
	# Newer kinds (end of the pool) appear a bit more often.
	var weights := []
	var total := 0.0
	for i in options.size():
		var w := 1.0 + float(i) / options.size()
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in options.size():
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[options.size() - 1]


# ======================================================================== CASTLE

## kind: "start" | "normal" | "boss" | "end"
static func castle_chunk(rng: RandomNumberGenerator, x0: float, start_h: float, pal: Dictionary, pool: Array, density: float, difficulty: float, kind := "normal") -> Dictionary:
	var c := Chunk.new()
	c.setup(x0, x0 + CHUNK_W, pal)
	var spawns := []
	var pickups := []
	var cols := c.heights.size()
	var surfaces := []  # Vector2 points enemies can stand on

	var feature := "flat"
	if kind == "normal":
		feature = ["hills", "hills", "tower", "wall", "aqueduct", "hanging", "steps", "twin_towers"][rng.randi() % 8]

	# --- ground heightmap
	var h := start_h
	var targets := [start_h]
	for i in 3:
		targets.append(clampf(start_h + rng.randf_range(-70, 70), 220.0, 330.0) if feature == "hills" or feature == "hanging" else start_h)
	for i in cols:
		var t := float(i) / (cols - 1) * 3.0
		var seg := mini(int(t), 2)
		var f := t - seg
		h = lerpf(targets[seg], targets[seg + 1], (1.0 - cos(f * PI)) * 0.5)
		c.heights[i] = snappedf(h, 1.0)
	var end_h: float = c.heights[cols - 1]

	match feature:
		"tower":
			var w := rng.randf_range(40, 64)
			var tx := x0 + rng.randf_range(160, CHUNK_W - 160)
			var th := rng.randf_range(70, 170)
			var gy := c.ground_at(tx)
			c.add_rect(Rect2(tx, gy - th, w, th + 40), "tower")
			c.deco.append({"type": "flag", "pos": Vector2(tx + w / 2, gy - th - 5)})
			c.deco.append({"type": "window", "pos": Vector2(tx + w / 2 - 1, gy - th + 20)})
			surfaces.append(Vector2(tx + w / 2, gy - th - 5))
		"twin_towers":
			for k in 2:
				var w := rng.randf_range(36, 52)
				var tx := x0 + 120 + k * 260 + rng.randf_range(0, 60)
				var th := rng.randf_range(90, 180)
				var gy := c.ground_at(tx)
				c.add_rect(Rect2(tx, gy - th, w, th + 40), "tower")
				c.deco.append({"type": "flag", "pos": Vector2(tx + w / 2, gy - th - 5)})
				surfaces.append(Vector2(tx + w / 2, gy - th - 5))
		"wall":
			var w := rng.randf_range(160, 260)
			var wx := x0 + rng.randf_range(100, CHUNK_W - w - 60)
			var wh := rng.randf_range(50, 95)
			var gy := c.ground_at(wx)
			c.add_rect(Rect2(wx, gy - wh, w, wh + 40), "wall")
			c.deco.append({"type": "flag", "pos": Vector2(wx + 6, gy - wh - 5)})
			c.deco.append({"type": "flag", "pos": Vector2(wx + w - 8, gy - wh - 5)})
			surfaces.append(Vector2(wx + w * 0.3, gy - wh - 5))
			surfaces.append(Vector2(wx + w * 0.7, gy - wh - 5))
		"aqueduct":
			var px0 := rng.randf_range(140, 200)
			var px1 := CHUNK_W - rng.randf_range(140, 200)
			var by := start_h - rng.randf_range(10, 60)
			for i in cols:
				var x := i * Chunk.COL
				if x > px0 and x < px1:
					c.heights[i] = Chunk.PIT
			c.add_rect(Rect2(x0 + px0 - 16, by, px1 - px0 + 32, 14), "bridge")
			c.deco.append({"type": "arches", "x0": x0 + px0 - 16, "x1": x0 + px1 + 16, "y": by})
			surfaces.append(Vector2(x0 + (px0 + px1) / 2, by - 6))
			surfaces.append(Vector2(x0 + px0 + 30, by - 6))
		"hanging":
			var w := rng.randf_range(50, 80)
			var hx := x0 + rng.randf_range(180, CHUNK_W - 180)
			var bottom := rng.randf_range(40, 150)
			c.add_rect(Rect2(hx, -500, w, bottom + 500), "hang")
		"steps":
			var sx := x0 + 120
			for k in 4:
				var sh := 24.0 + k * 26.0
				var gy := c.ground_at(sx)
				c.add_rect(Rect2(sx, gy - sh, 56, sh + 40), "wall")
				surfaces.append(Vector2(sx + 28, gy - sh - 5))
				sx += 80

	if kind == "start":
		c.deco.append({"type": "flag", "pos": Vector2(x0 + 40, c.ground_at(x0 + 40) - 1)})

	# --- end: treasure tower
	var chest_pos := Vector2.ZERO
	if kind == "end":
		var tx := x0 + 300
		var gy := c.ground_at(tx)
		c.add_rect(Rect2(tx, gy - 110, 70, 150), "tower")
		c.deco.append({"type": "flag", "pos": Vector2(tx + 6, gy - 115)})
		c.deco.append({"type": "flag", "pos": Vector2(tx + 62, gy - 115)})
		chest_pos = Vector2(tx + 35, gy - 122)
		# Back wall so the dragon cannot leave the level.
		c.add_rect(Rect2(x0 + CHUNK_W - 30, -600, 30, 1200), "hang")

	# --- decorations: trees on the grass
	for k in rng.randi_range(2, 5):
		var tx := x0 + rng.randf_range(10, CHUNK_W - 10)
		var gy := c.ground_at(tx)
		if gy < Chunk.PIT and not c.is_solid(Vector2(tx, gy - 4)):
			c.deco.append({"type": "tree", "pos": Vector2(tx, gy + 1), "s": rng.randf_range(0.8, 1.3)})

	# --- ground surfaces
	var gx := x0 + 40.0
	while gx < x0 + CHUNK_W - 30:
		var gy := c.ground_at(gx)
		if gy < Chunk.PIT and not c.is_solid(Vector2(gx, gy - 6)):
			surfaces.append(Vector2(gx, gy - 4))
		gx += rng.randf_range(60, 110)

	# --- enemies
	if kind == "normal" or kind == "boss":
		var count := int(round(density * 4.2 * sqrt(difficulty) + rng.randf_range(-0.6, 0.9)))
		for k in count:
			var ek := pick_kind(rng, pool)
			var def := EnemyDB.get_def(ek)
			var pos: Vector2
			if def.get("flying", false):
				pos = Vector2(x0 + rng.randf_range(60, CHUNK_W - 40), rng.randf_range(120.0, 220.0))
			elif surfaces.is_empty():
				continue
			else:
				var s: Vector2 = surfaces[rng.randi() % surfaces.size()]
				pos = s + Vector2(rng.randf_range(-10, 10), -8)
			spawns.append({"kind": ek, "pos": pos})
	if kind == "boss":
		pass  # the World adds the boss itself

	# --- coins: 1-2 arcs
	for k in rng.randi_range(1, 2):
		var ax := x0 + rng.randf_range(60, CHUNK_W - 200)
		var ay := rng.randf_range(140, 250)
		var n := rng.randi_range(5, 8)
		for i in n:
			var p := Vector2(ax + i * 18.0, ay - sin(float(i) / (n - 1) * PI) * 40.0)
			if not c.is_solid(p) and not c.is_solid(p + Vector2(0, 6)):
				pickups.append({"kind": "coin", "pos": p})

	c.build()
	return {"chunk": c, "spawns": spawns, "pickups": pickups, "end_h": end_h, "chest": chest_pos, "surfaces": surfaces}


# ======================================================================== DUNGEON

## A closed room: floor, ceiling, entry + exit doors, platforms, hazards.
## Returns spawn points instead of enemies; the World runs the waves.
static func dungeon_room(rng: RandomNumberGenerator, x0: float, pal: Dictionary, pool: Array, difficulty: float) -> Dictionary:
	var c := Chunk.new()
	c.setup(x0, x0 + ROOM_W, pal)
	var points := []
	var pickups := []
	var traps := []

	# Floor heightmap (flat, with an optional water pit)
	c.heights.fill(FLOOR_Y)
	var has_water := rng.randf() < 0.45
	if has_water:
		var wx0 := rng.randf_range(260, 520)
		var ww := rng.randf_range(120, 220)
		for i in c.heights.size():
			var x := i * Chunk.COL
			if x >= wx0 and x <= wx0 + ww:
				c.heights[i] = FLOOR_Y + 30
		c.water.append(Rect2(x0 + wx0 - 4, FLOOR_Y + 6, ww + 8, 24))
	# Ceiling
	c.add_rect(Rect2(x0, -400, ROOM_W, 400 + CEIL_Y), "stone")
	# Side pillars (the left one doubles as the door frame)
	c.add_rect(Rect2(x0, CEIL_Y, 18, 40), "stone")
	c.add_rect(Rect2(x0 + ROOM_W - 18, CEIL_Y, 18, 40), "stone")

	# Platforms: hanging on chains or standing on pillars
	var n := rng.randi_range(3, 6)
	var placed: Array[Rect2] = []
	for k in n:
		for attempt in 8:
			var w := rng.randf_range(60, 150)
			var px := x0 + rng.randf_range(60, ROOM_W - w - 60)
			var py := rng.randf_range(110, 260)
			var r := Rect2(px, py, w, 8)
			var ok := true
			for o in placed:
				if o.grow(30).intersects(r):
					ok = false
			if not ok:
				continue
			placed.append(r)
			c.add_rect(r, "platform")
			if rng.randf() < 0.65:
				c.deco.append({"type": "chain", "pos": Vector2(px + 6, CEIL_Y), "to": Vector2(px + 6, py)})
				c.deco.append({"type": "chain", "pos": Vector2(px + w - 6, CEIL_Y), "to": Vector2(px + w - 6, py)})
			else:
				c.add_rect(Rect2(px + w / 2 - 6, py + 8, 12, FLOOR_Y - py - 8), "pillar")
			points.append(Vector2(px + w / 2, py - 8))
			if rng.randf() < 0.5:
				pickups.append({"kind": "coin_row", "pos": Vector2(px + 10, py - 14), "n": int(w / 16)})
			break

	# Floor spikes
	if rng.randf() < 0.5 + difficulty * 0.1:
		var sx := x0 + rng.randf_range(120, ROOM_W - 200)
		var sw := rng.randf_range(32, 64)
		if c.ground_at(sx) == FLOOR_Y and c.ground_at(sx + sw) == FLOOR_Y:
			c.hazards.append(Rect2(sx, FLOOR_Y - 6, sw, 6))

	# Torches on the back wall
	for k in 4:
		c.deco.append({"type": "torch", "pos": Vector2(x0 + 120 + k * 230, 70)})

	# Floor spawn points
	for k in 5:
		var fx := x0 + rng.randf_range(80, ROOM_W - 80)
		if c.ground_at(fx) == FLOOR_Y:
			points.append(Vector2(fx, FLOOR_Y - 10))
	# Air spawn points
	var air := []
	for k in 4:
		air.append(Vector2(x0 + rng.randf_range(120, ROOM_W - 120), rng.randf_range(70, 180)))

	# Arrow traps on the walls
	if pool.has("arrow_trap"):
		for k in rng.randi_range(1, 2):
			var left := k % 2 == 0
			traps.append(Vector2(x0 + (30 if left else ROOM_W - 30), rng.randf_range(90, 280)))

	# Keys in awkward places
	var keys := []
	for k in rng.randi_range(1, 2):
		if not placed.is_empty() and rng.randf() < 0.7:
			var r: Rect2 = placed[rng.randi() % placed.size()]
			keys.append(Vector2(r.get_center().x, r.position.y - 40))
		else:
			keys.append(Vector2(x0 + rng.randf_range(100, ROOM_W - 100), rng.randf_range(50, 90)))

	c.build()
	return {"chunk": c, "points": points, "air": air, "traps": traps, "keys": keys, "pickups": pickups}
