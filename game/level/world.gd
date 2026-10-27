class_name World
extends Node2D
## Runs one level (castle or dungeon, numbered or endless): builds terrain,
## spawns everything, tracks combo / score / stars, and ends the run.

const BG_SCRIPT := preload("res://game/level/background.gd")
const HUD_SCRIPT := preload("res://game/level/hud.gd")

var level: Dictionary
var track := "castle"
var level_n := 1
var endless := false
var difficulty := 1.0
var finished := false
var kill_y := 520.0
var ceiling_y := -150.0          # the dragon cannot dash above this
var target_time_scale := 1.0
var pal: Dictionary

var player: Dragon
var fx: Fx
var camera: Camera2D
var hud
var bg
var terrain_layer: Node2D
var pickups_layer: Node2D
var enemies_layer: Node2D
var shots_layer: Node2D
var enemies: Array = []
var chunks: Array = []
var doors: Array = []          # [{rect: Rect2, body: StaticBody2D, x: float}]
var rng := RandomNumberGenerator.new()

# Run statistics
var coins := 0
var keys := 0
var kills := 0
var enemies_total := 0
var coins_total := 0
var coins_collected := 0
var keys_total := 0
var hearts_lost := 0
var combo := 0
var combo_timer := 0.0
var max_combo := 0
var time := 0.0
var distance := 0
var rooms_cleared := 0

# Castle state
var end_x := 0.0
var chest: Pickup
var boss_alive := false
var _next_chunk_x := 0.0
var _next_h := LevelGen.BASE_Y
var _chunk_index := 0

# Dungeon state
var rooms: Array = []          # see _add_room()
var room_i := 0
var _banner_t := 0.0

var _won_coins_collected := -1  # snapshot before the end-of-level coin vacuum
var _won_keys := -1
var _last_source := ""
var _last_effect := ""
var _pause_overlay: Node


func setup(args: Dictionary) -> void:
	track = args.get("track", "castle")
	level_n = int(args.get("level", 1))
	endless = bool(args.get("endless", false))
	level = LevelDB.endless(track) if endless else LevelDB.get_level(track, level_n)
	rng.seed = level.seed
	difficulty = level.difficulty
	pal = LevelGen.palette(level.palette)

	bg = BG_SCRIPT.new()
	bg.setup(pal, track == "dungeon")
	add_child(bg)
	terrain_layer = _layer("Terrain")
	pickups_layer = _layer("Pickups")
	enemies_layer = _layer("Enemies")
	player = Dragon.new()
	player.setup(self)
	add_child(player)
	shots_layer = _layer("Shots")
	fx = Fx.new()
	add_child(fx)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	hud = HUD_SCRIPT.new()
	hud.setup(self)
	add_child(hud)

	if track == "castle":
		_build_castle()
	else:
		_build_dungeon()
	camera.global_position = player.global_position
	camera.reset_smoothing()
	Sfx.play_music(track)
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	fx.big_popup(player.global_position + Vector2(0, -50), level.name, Color("ffe070"), 16.0)


func _layer(layer_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = layer_name
	add_child(n)
	return n


# ======================================================================== frame

func _physics_process(delta: float) -> void:
	enemies = enemies_layer.get_children().filter(func(e): return not e.is_queued_for_deletion())
	if finished:
		return
	time += delta
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			Events.combo_changed.emit(0)
	_check_hazards()
	if Game.has_meta("autoplay"):
		_autoplay()
	if Game.has_meta("debug_pause") and time > 1.0:
		var which: String = Game.get_meta("debug_pause")
		Game.remove_meta("debug_pause")
		open_pause()
		if which == "settings":
			_pause_overlay._open_settings()
	if track == "castle":
		_update_castle()
	else:
		_update_dungeon(delta)


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	Engine.time_scale = move_toward(Engine.time_scale, target_time_scale, real_delta * 5.0)
	AudioServer.playback_speed_scale = clampf(0.55 + 0.45 * (Engine.time_scale - 0.25) / 0.75, 0.55, 1.0)
	if player and not player.dead:
		var look := Vector2(signf(player.velocity.x) * 50.0, player.velocity.y * 0.08)
		camera.global_position = player.global_position + look
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * fx.trauma
	bg.follow(camera.get_screen_center_position())


## Debug bot (--autoplay): moves mostly rightwards by chaining dashes,
## auto-attacks and uses slow motion now and then.
func _autoplay() -> void:
	var beat := int(time * 8.0)
	var back := beat % 56 >= 48
	var y := player.global_position.y
	var want_y := 170.0 + sin(time * 0.7) * 60.0
	if track == "dungeon":
		want_y = 220.0 + sin(time * 0.9) * 80.0
	if is_instance_valid(chest) and absf(chest.global_position.x - player.global_position.x) < 260.0:
		back = chest.global_position.x < player.global_position.x
		want_y = chest.global_position.y - 4.0
	_press(&"move_right", not back)
	_press(&"move_left", back)
	# Tap jump (= dash up / diagonal in the air) whenever below the wanted height.
	_press(&"jump", y > want_y and beat % 3 == 0)
	_press(&"auto_attack", true)
	_press(&"slowmo_key", beat % 80 < 6)


func _press(action: StringName, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not finished and not get_tree().paused:
		open_pause()
		get_viewport().set_input_as_handled()


func open_pause() -> void:
	if _pause_overlay or finished:
		return
	target_time_scale = Engine.time_scale
	get_tree().paused = true
	_pause_overlay = load("res://ui/pause_menu.gd").new()
	hud.add_child(_pause_overlay)
	_pause_overlay.setup({})
	_pause_overlay.resume_pressed.connect(_on_resume)
	_pause_overlay.restart_pressed.connect(func(): Game.start_level(track, level_n, endless))
	_pause_overlay.quit_pressed.connect(func(): Events.request_screen.emit("levels", {"track": track}))


func _on_resume() -> void:
	if _pause_overlay:
		_pause_overlay.queue_free()
		_pause_overlay = null
	get_tree().paused = false
	if player:
		target_time_scale = player.SLOWMO_SCALE if player.slowmo else 1.0


# ======================================================================== queries (enemy contract)

func is_solid(p: Vector2) -> bool:
	for d in doors:
		if d.rect.has_point(p):
			return true
	for c in chunks:
		if p.x >= c.x0 and p.x <= c.x1 and c.is_solid(p):
			return true
	return false


func water_at(p: Vector2) -> bool:
	for c in chunks:
		if p.x >= c.x0 and p.x <= c.x1:
			for w in c.water:
				if w.has_point(p):
					return true
	return false


func ground_y(x: float, from_y: float) -> float:
	var best := Chunk.PIT
	for c in chunks:
		if x >= c.x0 and x <= c.x1:
			best = minf(best, c.surface_below(x, from_y))
	return best


func view_rect() -> Rect2:
	var c := camera.get_screen_center_position()
	return Rect2(c - Vector2(320, 180), Vector2(640, 360))


func is_active_pos(p: Vector2) -> bool:
	return view_rect().grow(40.0).has_point(p)


func nearest_enemy(pos: Vector2, max_dist: float):
	var best = null
	var best_d := max_dist
	for e in enemies:
		if not is_instance_valid(e) or e.dead or not is_active_pos(e.global_position):
			continue
		var d: float = e.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func spawn_enemy(kind: String, pos: Vector2) -> Node:
	var e: Enemy = Enemy.new()
	e.setup(kind, self)
	e.position = pos
	enemies_layer.add_child(e)
	_count_spawn.call_deferred(e)
	if EnemyDB.get_def(kind).get("boss", false):
		boss_alive = true
	if track == "dungeon" and room_i < rooms.size() and rooms[room_i].state == "fighting":
		rooms[room_i].alive.append(e)
	return e


## Split slimes and summoned squires are tagged "spawned" by Enemy right after
## creation; they do not count toward the Kills star.
func _count_spawn(e) -> void:
	if is_instance_valid(e) and not e.has_meta("spawned"):
		enemies_total += 1
		e.set_meta("counted", true)


func spawn_pickup(kind: String, pos: Vector2, value := 1, placed := false) -> Pickup:
	var p := Pickup.new()
	p.setup(kind, self, value, placed)
	p.position = pos
	pickups_layer.add_child(p)
	return p


# ======================================================================== combat

## Every source of player damage goes through here so kills can be attributed.
func damage_enemy(e, dmg: float, knock: Vector2, effect := "", source := "shot") -> void:
	if not is_instance_valid(e) or e.dead:
		return
	_last_source = source
	_last_effect = effect
	e.take_hit(dmg, knock, effect, source)
	_last_source = ""
	_last_effect = ""


func explode_at(pos: Vector2, radius: float, dmg: float, effect := "", color := Color(1, 0.5, 0.1), source := "explosion") -> void:
	fx.explosion(pos, radius, color)
	Sfx.play("explode" if radius >= 30.0 else "explode_small", 0.1, -3.0)
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - pos
		if to.length() <= radius + e.get_radius():
			var k := to.normalized() * 120.0 + Vector2(0, -200.0)
			damage_enemy(e, dmg, k, effect, source)
	for s in get_tree().get_nodes_in_group("enemy_shots"):
		if not s.has_meta("indestructible") and s.global_position.distance_to(pos) < radius:
			s.destroy()


func chain_lightning(from: Vector2, dir: Vector2, a: Dictionary) -> void:
	var hit := {}
	var cur := from
	var target = null
	var best := 280.0
	for e in enemies:
		if not is_instance_valid(e) or e.dead or not is_active_pos(e.global_position):
			continue
		var to: Vector2 = e.global_position - from
		var score := to.length() * (1.6 - to.normalized().dot(dir))
		if to.length() < 280.0 and score < best:
			best = score
			target = e
	if target == null:
		_zigzag(from, from + dir * 90.0, a.color)
		return
	var dmg: float = a.dmg * Game.power_mult()
	for i in a.count:
		if target == null:
			break
		hit[target.get_instance_id()] = true
		_zigzag(cur, target.global_position, a.color)
		cur = target.global_position
		damage_enemy(target, dmg, Vector2(0, -120), a.effect, "chain")
		fx.sparks(cur, a.color, 6, 100.0)
		var next = null
		var nd := 140.0
		for e in enemies:
			if not is_instance_valid(e) or e.dead or hit.has(e.get_instance_id()):
				continue
			var d: float = e.global_position.distance_to(cur)
			if d < nd:
				nd = d
				next = e
		target = next


func _zigzag(a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(2, int(a.distance_to(b) / 14.0))
	var prev := a
	for i in range(1, n + 1):
		var p := a.lerp(b, float(i) / n)
		if i < n:
			p += (b - a).normalized().orthogonal() * randf_range(-6, 6)
		fx.line(prev, p, col, 2.0, 0.18)
		fx.line(prev, p, Color.WHITE, 1.0, 0.1)
		prev = p


func on_enemy_hit(e, was_airborne: bool) -> void:
	combo += 2 if was_airborne else 1
	combo_timer = 2.5
	max_combo = maxi(max_combo, combo)
	Game.stat_max("max_combo", combo)
	Events.combo_changed.emit(combo)
	if player:
		player.refill_meter(1.5)
	if combo >= 2:
		fx.popup(e.global_position + Vector2(0, -14), "x%d" % combo, Color.WHITE if not was_airborne else Color("ffe070"))


func on_enemy_died(e) -> void:
	if e.has_meta("counted") or not e.has_meta("spawned"):
		kills += 1
	var kind: String = e.kind
	var def: Dictionary = EnemyDB.get_def(kind)
	Game.stat_add("kills")
	Game.stat_add("kills_" + kind)
	if e.is_airborne():
		Game.stat_add("airborne_kills")
	match _last_source:
		"dash": Game.stat_add("dash_kills")
		"slam": Game.stat_add("slam_kills")
	var effect: String = e.killed_by if e.killed_by != "" else _last_effect
	if effect != "":
		Game.stat_add(effect + "_kills")
	if player:
		player.on_kill(_last_source)
	Events.enemy_killed.emit(kind, e.global_position, e.is_airborne())
	# Gold drop, multiplied by the combo.
	var gold := int(def.get("gold", 2)) * clampi(combo, 1, 5 if def.get("boss", false) else 25)
	var pieces := mini(gold, 6 if not def.get("boss", false) else 20)
	for i in pieces:
		var value := gold / pieces + (1 if i < gold % pieces else 0)
		var c := spawn_pickup("coin", e.global_position + Vector2(0, -4), value)
		c.pop(Vector2(randf_range(-110, 110), randf_range(-260, -120)))
	if def.get("boss", false):
		Game.stat_add("bosses_killed")
		_check_boss_alive.call_deferred()
		fx.big_popup(e.global_position + Vector2(0, -30), "BOSS DOWN!", Color("ffe070"), 20.0)
		for i in 3:
			spawn_pickup("key", e.global_position + Vector2(0, -10), 1).pop(Vector2(randf_range(-80, 80), -250))
	elif track == "dungeon" and rng.randf() < 0.08:
		spawn_pickup("key", e.global_position, 1).pop(Vector2(0, -200))
	if player and player.hearts < player.MAX_HEARTS and randf() < 0.05:
		spawn_pickup("heart", e.global_position, 1).pop(Vector2(randf_range(-40, 40), -200))


func _check_boss_alive() -> void:
	boss_alive = false
	for e in enemies_layer.get_children():
		if not e.dead and EnemyDB.get_def(e.kind).get("boss", false):
			boss_alive = true
	if not boss_alive and chest:
		chest.locked = false


func collect_pickup(p: Pickup) -> void:
	match p.kind:
		"coin":
			coins += p.value
			if p.placed:
				coins_collected += 1
			Game.stat_add("coins_collected")
			Sfx.play("coin", 0.05, -8.0)
		"key":
			keys += 1
			Sfx.play("key")
			fx.popup(p.global_position, "+1 key", Color("ffc830"))
		"heart":
			player.heal(1)
			Sfx.play("buy")
			fx.popup(p.global_position, "+1", Color("ff5060"))
		"chest":
			Game.stat_add("chests_opened")
			Sfx.play("chest")
			fx.explosion(p.global_position, 20.0, Color("ffd84a"))
			fx.big_popup(p.global_position + Vector2(0, -20), "+100", Color("ffd84a"), 18.0)
			coins += 100
			keys += 1
			for i in 14:
				var c := spawn_pickup("coin", p.global_position, 0)
				c.pop(Vector2(randf_range(-150, 150), randf_range(-320, -160)))
			if not endless:
				_win()


func on_player_died() -> void:
	target_time_scale = 1.0
	await get_tree().create_timer(1.4, true, false, true).timeout
	finish(false)


func _win() -> void:
	target_time_scale = 0.35
	fx.big_popup(player.global_position + Vector2(0, -40), "VICTORY!", Color("ffe070"), 24.0)
	player.velocity = Vector2.ZERO
	await _vacuum_pickups()
	finish(true)


## End of level: every coin and key left on the map flies to the dragon before
## the results. The Treasure / Keys stars use what was collected before this.
func _vacuum_pickups() -> void:
	_won_coins_collected = coins_collected
	_won_keys = keys
	await get_tree().create_timer(0.5, true, false, true).timeout
	target_time_scale = 1.0
	for p in pickups_layer.get_children():
		if p.kind == "coin" or p.kind == "key":
			p.locked = false
			p.homing = true
	var waited := 0.0
	while waited < 2.5:
		await get_tree().create_timer(0.1, true, false, true).timeout
		waited += 0.1
		var left := pickups_layer.get_children().filter(func(p): return p.kind == "coin" or p.kind == "key")
		if left.is_empty() and waited >= 1.0:
			break


func _check_hazards() -> void:
	if player == null or player.dead:
		return
	var pp := player.global_position
	for c in chunks:
		if pp.x < c.x0 - 20 or pp.x > c.x1 + 20:
			continue
		for h in c.hazards:
			if h.grow(2.0).has_point(pp + Vector2(0, 5)):
				player.hurt(1, pp + Vector2(0, 10))


# ======================================================================== castle

func _build_castle() -> void:
	kill_y = 520.0
	camera.limit_left = 0
	camera.limit_top = -200
	camera.limit_bottom = 400
	terrain_layer.add_child(_side_wall(-30.0))
	if endless:
		for i in 3:
			_add_castle_chunk("start" if i == 0 else "normal")
	else:
		var n := int(ceil(float(level.length) / LevelGen.CHUNK_W))
		for i in n:
			var kind := "normal"
			if i == 0:
				kind = "start"
			elif i == n - 1:
				kind = "end"
			elif i == n - 2 and level.boss != "":
				kind = "boss"
			_add_castle_chunk(kind)
		camera.limit_right = int(end_x)
	player.position = Vector2(80, LevelGen.BASE_Y - 30)


func _side_wall(x: float) -> StaticBody2D:
	var b := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(30, 2000)
	cs.shape = r
	cs.position = Vector2(x + 15, 0)
	b.add_child(cs)
	return b


func _add_castle_chunk(kind: String) -> void:
	var pool: Array = level.pool
	var density: float = level.density
	if endless:
		difficulty = minf(1.0 + _chunk_index * 0.05, 3.5)
		density = minf(0.7 + _chunk_index * 0.02, 1.6)
	var res := LevelGen.castle_chunk(rng, _next_chunk_x, _next_h, pal, pool, density, difficulty, kind)
	var c: Chunk = res.chunk
	terrain_layer.add_child(c)
	chunks.append(c)
	for s in res.spawns:
		spawn_enemy(s.kind, s.pos)
	for p in res.pickups:
		spawn_pickup("coin", p.pos, 2, true)
		coins_total += 1
	if kind == "boss":
		var bx := _next_chunk_x + 420.0
		spawn_enemy(level.boss, Vector2(bx, c.ground_at(bx) - 30.0))
		fx.popup(Vector2(bx, 150), "!", Color("ff4040"))
	if endless and _chunk_index > 0 and _chunk_index % 8 == 0:
		var bx := _next_chunk_x + 400.0
		spawn_enemy("golden_knight" if _chunk_index % 16 == 8 else "warlord", Vector2(bx, c.ground_at(bx) - 30.0))
	if endless and _chunk_index > 0 and _chunk_index % 5 == 0 and not res.surfaces.is_empty():
		var sp: Vector2 = res.surfaces[rng.randi() % res.surfaces.size()]
		spawn_pickup("chest", sp + Vector2(0, -10))
	if kind == "end":
		chest = spawn_pickup("chest", res.chest)
		chest.locked = boss_alive
		end_x = _next_chunk_x + LevelGen.CHUNK_W
	_next_h = res.end_h
	_next_chunk_x += LevelGen.CHUNK_W
	_chunk_index += 1


func _update_castle() -> void:
	if player.dead:
		return
	distance = maxi(distance, int(player.global_position.x / 16.0))
	if endless:
		var right := view_rect().end.x
		while _next_chunk_x < right + 900.0:
			_add_castle_chunk("normal")
		var cutoff := view_rect().position.x - 900.0
		for c in chunks.duplicate():
			if c.x1 < cutoff:
				chunks.erase(c)
				c.queue_free()
		for n in enemies_layer.get_children() + pickups_layer.get_children():
			if n.global_position.x < cutoff:
				n.queue_free()


# ======================================================================== dungeon

func _build_dungeon() -> void:
	kill_y = 460.0
	camera.limit_top = 0
	camera.limit_bottom = int(LevelGen.ROOM_H)
	_add_door(0.0, true)
	var n: int = 2 if endless else level.rooms
	for i in n:
		_add_room()
	player.position = Vector2(80, LevelGen.FLOOR_Y - 20)
	_set_room_camera(0)


func _add_room() -> void:
	var i := rooms.size()
	var x0 := i * LevelGen.ROOM_W
	if endless:
		difficulty = minf(1.0 + i * 0.12, 4.0)
	var res := LevelGen.dungeon_room(rng, x0, pal, level.pool, difficulty)
	var c: Chunk = res.chunk
	terrain_layer.add_child(c)
	chunks.append(c)
	for k in res.keys:
		spawn_pickup("key", k, 1, true)
		keys_total += 1
	for p in res.pickups:
		for j in p.n:
			spawn_pickup("coin", p.pos + Vector2(j * 16.0, 0), 2, true)
			coins_total += 1
	var boss := ""
	var last: bool = not endless and i == level.rooms - 1
	if last:
		boss = level.boss
	elif endless and (i + 1) % 5 == 0:
		boss = "golden_knight" if (i + 1) % 10 == 5 else "warlord"
	var waves: int = level.waves + (1 if boss != "" else 0)
	if endless:
		waves = 2 + i / 4
	rooms.append({
		"x0": x0, "res": res, "state": "waiting", "wave": 0, "waves": waves,
		"alive": [], "boss": boss, "door": _add_door(x0 + LevelGen.ROOM_W, true),
	})


func _add_door(x: float, closed: bool) -> Dictionary:
	var rect := Rect2(x - 18, LevelGen.CEIL_Y + 40, 36, LevelGen.FLOOR_Y - LevelGen.CEIL_Y - 40)
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.get_center()
	body.add_child(cs)
	var door := {"rect": rect, "body": body, "x": x, "open": false}
	body.draw.connect(func():
		if not door.open:
			body.draw_rect(rect, pal.door)
			body.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), pal.stone_light)
			for k in int(rect.size.y / 12.0):
				body.draw_rect(Rect2(rect.position.x + 4, rect.position.y + 8 + k * 12.0, rect.size.x - 8, 2), Color(0, 0, 0, 0.3))
			body.draw_circle(rect.get_center(), 4.0, pal.stone_light))
	terrain_layer.add_child(body)
	doors.append(door)
	if not closed:
		_set_door(door, true)
	return door


func _set_door(door: Dictionary, open: bool) -> void:
	door.open = open
	door.body.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	if open:
		doors.erase(door)
	elif not doors.has(door):
		doors.append(door)
	door.body.queue_redraw()


func _set_room_camera(i: int) -> void:
	camera.limit_left = int(rooms[i].x0)
	camera.limit_right = int(rooms[i].x0 + LevelGen.ROOM_W)


func _update_dungeon(_delta: float) -> void:
	if player.dead or room_i >= rooms.size():
		return
	var room: Dictionary = rooms[room_i]
	var px := player.global_position.x
	match room.state:
		"waiting":
			if px > room.x0 + 50.0 and time > 1.2:
				room.state = "fighting"
				_set_room_camera(room_i)
				if room_i > 0:
					_set_door(rooms[room_i - 1].door, false)
				for t in room.res.traps:
					spawn_enemy("arrow_trap", t)
				_spawn_wave(room)
		"fighting":
			room.alive = room.alive.filter(func(e): return is_instance_valid(e) and not e.dead)
			if room.alive.is_empty():
				room.wave += 1
				if room.wave < room.waves:
					_spawn_wave(room)
				else:
					_room_cleared(room)
		"cleared":
			if px > room.x0 + LevelGen.ROOM_W + 20.0 and room_i + 1 < rooms.size():
				room_i += 1


func _spawn_wave(room: Dictionary) -> void:
	var res: Dictionary = room.res
	var is_boss_wave: bool = room.boss != "" and room.wave == room.waves - 1
	var count: int = 2 + int(difficulty * 1.2) + room.wave
	if is_boss_wave:
		count = 2
		var bp: Vector2 = Vector2(room.x0 + LevelGen.ROOM_W * 0.6, LevelGen.FLOOR_Y - 30.0)
		_portal_spawn(room.boss, bp)
		fx.big_popup(Vector2(room.x0 + LevelGen.ROOM_W / 2.0, 120), "BOSS!", Color("ff5050"), 20.0)
	var pool: Array = level.pool.filter(func(k): return k != "arrow_trap")
	for k in count:
		var kind := LevelGen.pick_kind(rng, pool)
		var pos: Vector2
		if EnemyDB.get_def(kind).get("flying", false) or res.points.is_empty():
			pos = res.air[rng.randi() % res.air.size()]
		else:
			pos = res.points[rng.randi() % res.points.size()]
		_portal_spawn(kind, pos + Vector2(rng.randf_range(-12, 12), 0))
	if room.wave > 0 and not is_boss_wave:
		fx.big_popup(Vector2(room.x0 + LevelGen.ROOM_W / 2.0, 120), "WAVE %d" % (room.wave + 1), Color.WHITE, 16.0)


func _portal_spawn(kind: String, pos: Vector2) -> void:
	fx.ring(pos, 16.0, Color("c060ff"))
	fx.smoke(pos, 3, 5.0)
	spawn_enemy(kind, pos)


func _room_cleared(room: Dictionary) -> void:
	room.state = "cleared"
	rooms_cleared += 1
	Sfx.play("door")
	var last: bool = not endless and room_i == rooms.size() - 1
	if last:
		_win_dungeon()
		return
	_set_door(room.door, true)
	camera.limit_right = int(room.x0 + LevelGen.ROOM_W * 2.0)
	fx.big_popup(Vector2(room.x0 + LevelGen.ROOM_W / 2.0, 110), "ROOM CLEAR!", Color("7ae8ff"), 18.0)
	if endless and room_i + 2 >= rooms.size():
		_add_room()


func _win_dungeon() -> void:
	target_time_scale = 0.35
	fx.big_popup(player.global_position + Vector2(0, -40), "DUNGEON CLEAR!", Color("ffe070"), 22.0)
	await _vacuum_pickups()
	finish(true)


# ======================================================================== end of run

func finish(won: bool) -> void:
	if finished:
		return
	finished = true
	target_time_scale = 1.0
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	var result := {
		"track": track, "level": level_n, "endless": endless, "won": won, "level_name": level.name,
		"coins": coins, "keys": keys, "kills": kills, "enemies_total": enemies_total,
		"coins_collected": coins_collected, "coins_total": coins_total, "hearts_lost": hearts_lost,
		"max_combo": max_combo, "time": time, "distance": distance, "rooms": rooms_cleared,
		"keys_total": keys_total, "par_time": level.get("par_time", 0.0), "combo_target": level.get("combo_target", 0),
	}
	var star_coins := _won_coins_collected if _won_coins_collected >= 0 else coins_collected
	var star_keys := _won_keys if _won_keys >= 0 else keys
	if track == "castle":
		var treasure := float(star_coins) / maxf(1.0, coins_total)
		var kill_pct := float(kills) / maxf(1.0, enemies_total)
		var hearts_pct := float(Dragon.MAX_HEARTS - mini(hearts_lost, Dragon.MAX_HEARTS)) / Dragon.MAX_HEARTS
		result.stars = [won and treasure >= 0.9, won and hearts_lost == 0, won and kills >= enemies_total]
		result.star_labels = ["Treasure %d%%" % int(treasure * 100.0), "Hearts %d%%" % int(hearts_pct * 100.0), "Kills %d%%" % int(kill_pct * 100.0)]
	else:
		result.stars = [won and star_keys >= keys_total, won and max_combo >= int(level.combo_target), won and time <= float(level.par_time)]
		result.star_labels = ["Keys %d/%d" % [mini(star_keys, keys_total), keys_total], "Combo x%d / x%d" % [max_combo, level.combo_target], "Time %s / %s" % [_fmt_time(time), _fmt_time(level.par_time)]]
	if endless:
		Game.stat_add("endless_runs")
	result.summary = Game.submit_result(result)
	Events.level_finished.emit(result)
	Sfx.play("win" if won else "die")
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().paused = true
	var rs = load("res://ui/results_screen.gd").new()
	hud.add_child(rs)
	rs.setup(result)


static func _fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
