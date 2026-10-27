class_name Enemy
extends CharacterBody2D
## One script, 22 behaviours (see EnemyDB for the kinds). Created by World:
##   var e := Enemy.new(); e.setup(kind, world); e.position = p; enemies_layer.add_child(e)
## `world` is untyped on purpose (duck typing, see docs/DESIGN.md).
## Art is drawn in _draw() in "unit space": feet at y = +6, forward = +x, then
## scaled/flipped by `facing`. Colours go through _k() for hit flash / status tints.

const GRAVITY := 900.0
const MAX_FALL := 650.0
const HIT_FLASH := 0.08

const NAVY := Color("101830")
const ORANGE := Color("ff8a20")
const SKIN := Color("ffd0a0")
const STEEL := Color("c8d0e0")
const DARK_STEEL := Color("7a86a0")
const GOLD := Color("f0c020")
const RED := Color("d83030")
const WOOD := Color("8a5a30")
const PURPLE := Color("8a50d0")
const BONE := Color("e8e4d0")

# ---- contract fields
var kind := ""
var def: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var dead := false
var world  # untyped (duck typing)

# ---- extras the World may read
var killed_by := ""    ## effect that finished the enemy: "burn" | "freeze" | "shock" | "poison" | ""
var last_source := ""  ## source of the last hit ("shot", "dash", ...)
var small := false     ## small slime

# ---- state
var mode := ""         ## AI mode (== kind, except a popped balloon rider becomes "bomber")
var facing := 1
var age := 0.0
var flash := 0.0
var launched := false
var launch_age := 0.0
var fly := false
var hw := 4.0
var hh := 6.0
var radius := 8.0
var sc := 1.0
var is_boss := false
var phase := 0.0

var cd := 1.0
var state := "idle"
var st := 0.0
var wind_len := 0.5
var aim := Vector2.RIGHT   ## aim vector (a velocity for lobbed shots)
var aim_end := Vector2.ZERO
var act := false
var act_t := 0.0
var have_p := false
var ppos := Vector2.ZERO
var pvel := Vector2.ZERO
var pdx := 0.0
var pdy := 0.0
var pdist := 999.0

var hit_stun := 0.0
var touch_cd := 0.0
var shield_flash := 0.0
var burn_t := 0.0
var poison_t := 0.0
var freeze_t := 0.0
var shock_t := 0.0
var dot_acc := 0.0
var dot_tick := 0.4
var fx_t := 0.0
var slow_mul := 1.0

var turn_t := 0.0
var has_item := true
var reload_t := 0.0
var tp_cd := 1.0
var tp_alpha := 1.0
var pulse_t := 0.0
var scan_t := 0.0
var need_heal := false
var volley_left := 0
var volley_t := 0.0
var burst_left := 0
var burst_t := 0.0
var last_atk := ""
var rage := false
var stun_len := 1.4
var charge_dir := 1
var ghost_a := 1.0
var pile := false
var bones_t := 0.0
var revived := false
var squash := 0.0
var recoil := 0.0
var balloon_alive := true
var balloon_t := 0.0
var wall_found := false
var wave2_t := 0.0
var trail_t := 0.0

var _shape: CollisionShape2D


# ================================================================ setup

func setup(kind_: String, world_) -> void:
	kind = kind_
	world = world_
	def = EnemyDB.get_def(kind)
	mode = kind
	is_boss = def.boss
	fly = def.flying
	hw = def.w
	hh = def.h
	radius = def.r
	sc = def.get("scale", 1.0)
	var diff := _difficulty()
	max_hp = float(def.hp) * (1.0 + (diff - 1.0) * 0.35)
	hp = max_hp
	collision_layer = 4
	# Ghosts drift through everything; everyone else bumps into terrain and each other.
	collision_mask = 0 if kind == "ghost" else 1 | 4
	add_to_group("enemies")
	if is_boss:
		add_to_group("bosses")
	_build_shape()
	facing = 1 if randf() < 0.5 else -1
	cd = randf_range(0.5, 1.5)
	phase = randf() * TAU
	if kind == "ghost":
		ghost_a = 0.0
	if kind == "balloon":
		has_item = true
	if kind == "arrow_trap":
		facing = 0


func _build_shape() -> void:
	_shape = CollisionShape2D.new()
	if hh >= hw and not def.stationary and kind != "bat":
		var cap := CapsuleShape2D.new()
		cap.radius = hw
		cap.height = hh * 2.0
		_shape.shape = cap
	else:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(hw * 2.0, hh * 2.0)
		_shape.shape = rect
	add_child(_shape)


func _ready() -> void:
	floor_snap_length = 4.0
	floor_max_angle = deg_to_rad(50.0)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING if fly else CharacterBody2D.MOTION_MODE_GROUNDED
	if kind == "arrow_trap":
		_find_wall()
	elif not fly and world != null:
		# Spawned slightly inside the floor? Lift out of it.
		var tries := 0
		while tries < 12 and world.is_solid(global_position + Vector2(0.0, hh - 2.0)):
			global_position.y -= 3.0
			tries += 1


func _difficulty() -> float:
	if world == null:
		return 1.0
	var d = world.get("difficulty")
	if d == null:
		return 1.0
	return maxf(1.0, float(d))


## Fire-rate multiplier: >1 means slower cooldowns on easy levels, <1 faster later.
func _rate_mul() -> float:
	return 1.0 / (1.0 + (_difficulty() - 1.0) * 0.35)


func _spd_mul() -> float:
	return 1.0 + (_difficulty() - 1.0) * 0.12


func _find_wall() -> void:
	var left := 999.0
	var right := 999.0
	for d in range(3, 42, 2):
		if left > 900.0 and world.is_solid(global_position + Vector2(-d, 0.0)):
			left = d
		if right > 900.0 and world.is_solid(global_position + Vector2(d, 0.0)):
			right = d
	if left > 900.0 and right > 900.0:
		facing = 0
	else:
		wall_found = true
		facing = 1 if left < right else -1


func make_small() -> void:
	## Turns a freshly spawned slime into a small one.
	small = true
	sc = 0.5
	hw = 3.0
	hh = 2.5
	radius = 5.0
	max_hp = maxf(1.0, round(max_hp * 0.34))
	hp = max_hp
	def["gold"] = 1
	if _shape != null and _shape.shape is RectangleShape2D:
		(_shape.shape as RectangleShape2D).size = Vector2(hw * 2.0, hh * 2.0)


# ================================================================ public API

func is_airborne() -> bool:
	if def.stationary or pile:
		return false
	return fly or launched or not is_on_floor()


func get_radius() -> float:
	if pile:
		return 5.0
	if mode == "balloon":
		return 12.0
	return radius


func heal(amount: float) -> void:
	if dead or pile:
		return
	hp = minf(max_hp, hp + amount)
	_sparks(global_position, Color("80ff90"), 4, 50.0)
	_popup(global_position + Vector2(0.0, -12.0), "+", Color("80ff90"))


func take_hit(dmg: float, knock := Vector2.ZERO, effect := "", source := "shot") -> void:
	if dead:
		return
	last_source = source
	if kind == "ghost" and ghost_a < 0.4:
		return
	if _blocked(knock, source):
		shield_flash = 0.15
		Sfx.play("block")
		_sparks(global_position + Vector2(facing * (hw + 2.0) * sc, -2.0), Color("ffe8a0"), 5, 90.0)
		return
	var was_air := is_airborne()
	if pile:
		flash = HIT_FLASH
		if source == "explosion" or source == "slam" or effect == "burn":
			if world != null:
				world.on_enemy_hit(self, false)
			_die("burn" if effect == "burn" else "")
		else:
			Sfx.play("block")
			_sparks(global_position, BONE, 3, 60.0)
		return
	hp -= dmg
	flash = HIT_FLASH
	Sfx.play("hit", 0.1)
	_apply_effect(effect)
	_apply_knock(knock, source)
	if not is_boss:
		hit_stun = 0.2
	if state == "wind":
		state = "idle"
		cd = maxf(cd, 0.6)
	if mode == "balloon" and balloon_alive:
		_pop_balloon()
	if world != null:
		world.on_enemy_hit(self, was_air)
	if hp <= 0.0:
		_on_zero(effect, source)


func _apply_effect(effect: String) -> void:
	match effect:
		"burn":
			burn_t = 3.0
		"poison":
			poison_t = 4.0
		"freeze":
			if kind != "ice_mage":
				freeze_t = 2.0
		"shock":
			shock_t = 0.25 if is_boss else 0.6
			_sparks(global_position, Color("fff060"), 4, 80.0)
	if effect != "":
		killed_by = effect


func _apply_knock(knock: Vector2, _source: String) -> void:
	if def.stationary:
		return
	var kb: float = def.get("kb", 1.0)
	if is_boss:
		velocity.x += knock.x * kb
		return
	if fly:
		velocity = (velocity + knock * 0.9 * kb).limit_length(320.0)
		return
	var k := knock * kb
	launched = true
	launch_age = 0.0
	state = "idle"
	velocity.x = clampf(k.x, -300.0, 300.0)
	if k.y > 60.0:
		velocity.y = minf(k.y, 500.0)  # spiked downwards
	else:
		velocity.y = maxf(minf(k.y, 0.0) - (150.0 + knock.length() * 0.4) * maxf(kb, 0.4), -430.0)


func _blocked(knock: Vector2, source: String) -> bool:
	if kind != "knight" and kind != "golden_knight":
		return false
	if not _shield_up():
		return false
	if source != "shot" and source != "chain":
		return false
	if knock.length_squared() > 4.0:
		if knock.y > absf(knock.x):
			return false  # dropping in from above
		return knock.x * facing < 0.0
	return (ppos.x - global_position.x) * facing > 0.0


func _shield_up() -> bool:
	if kind == "knight":
		return state != "stunned" and hit_stun <= 0.0
	return state != "stunned" and state != "recover"


func _on_zero(effect: String, source: String) -> void:
	if kind == "skeleton" and not revived and not pile and effect != "burn" and source != "explosion" and source != "slam":
		_collapse()
		return
	_die(effect)


func _collapse() -> void:
	pile = true
	revived = true
	bones_t = 2.0
	launched = false
	velocity = Vector2.ZERO
	burn_t = 0.0
	poison_t = 0.0
	state = "idle"
	_debris(global_position, BONE, 6)
	Sfx.play("enemy_die", 0.1, -6.0)


func _die(effect := "") -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	if effect != "":
		killed_by = effect
	elif killed_by == "":
		if burn_t > 0.0:
			killed_by = "burn"
		elif poison_t > 0.0:
			killed_by = "poison"
	var pos := global_position
	var col := _theme_color()
	Sfx.play("enemy_die")
	if is_boss:
		for i in 6:
			var off := Vector2(randf_range(-hw, hw), randf_range(-hh, hh)) * sc * 0.8
			_boom(pos + off, randf_range(14.0, 26.0))
		_debris(pos, col, 14)
		_smoke(pos, 6, 10.0)
		_shake(10.0)
	else:
		_boom(pos, 12.0 + radius * 0.4)
		_debris(pos, col, 6)
		_smoke(pos, 3, 6.0)
	if kind == "slime" and not small and world != null:
		for i in 2:
			var m = world.spawn_enemy("slime", pos + Vector2((i * 2 - 1) * 4.0, -2.0))
			if m != null:
				m.make_small()
				m.set_meta("spawned", true)
				m.launched = true
				m.velocity = Vector2((i * 2 - 1) * 90.0, -200.0)
	if world != null:
		world.on_enemy_died(self)
	queue_free()


func _theme_color() -> Color:
	match kind:
		"slime": return Color("40c060")
		"ghost": return Color("e0f0ff")
		"skeleton": return BONE
		"mage", "cleric": return PURPLE
		"ice_mage": return Color("60b0ff")
		"golden_knight": return GOLD
		"bat": return Color("503070")
	return ORANGE


# ================================================================ update loop

func _physics_process(delta: float) -> void:
	if dead or world == null:
		return
	age += delta
	flash = maxf(0.0, flash - delta)
	hit_stun = maxf(0.0, hit_stun - delta)
	touch_cd = maxf(0.0, touch_cd - delta)
	shield_flash = maxf(0.0, shield_flash - delta)
	pulse_t = maxf(0.0, pulse_t - delta)
	recoil = maxf(0.0, recoil - delta * 20.0)
	squash = move_toward(squash, 0.0, delta * 4.0)
	_update_status(delta)
	if dead:
		return
	slow_mul = 0.5 if freeze_t > 0.0 else 1.0
	var dt := delta * slow_mul
	_sense(dt)
	if global_position.y > 3000.0:
		_die()
		return

	if kind == "arrow_trap":
		if shock_t <= 0.0 and hit_stun <= 0.0:
			_think(dt)
		queue_redraw()
		return
	if pile:
		bones_t -= delta
		if bones_t <= 0.0:
			_reassemble()
		queue_redraw()
		return

	var stunned := shock_t > 0.0 or (hit_stun > 0.0 and not is_boss)
	if launched:
		launch_age += delta
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		velocity.x = move_toward(velocity.x, 0.0, 50.0 * delta)
	elif stunned:
		if fly:
			velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-4.0 * delta))
		else:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	else:
		_think(dt)
	if not fly and not launched:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	var was_air := not is_on_floor()
	move_and_slide()
	if not fly and was_air and is_on_floor() and not launched:
		squash = 0.5  # landing squish
	if launched and launch_age > 0.08 and is_on_floor():
		launched = false
		hit_stun = maxf(hit_stun, 0.15)
		_smoke(global_position + Vector2(0.0, hh), 1, 3.0)
	_contact_damage()
	queue_redraw()


func _sense(dt: float) -> void:
	var p = _player()
	have_p = p != null
	if have_p:
		ppos = p.global_position
		pvel = p.velocity
	else:
		ppos = global_position + Vector2(facing * 300.0, 0.0)
		pvel = Vector2.ZERO
	pdx = ppos.x - global_position.x
	pdy = ppos.y - global_position.y
	pdist = ppos.distance_to(global_position)
	act = have_p and world.is_active_pos(global_position)
	act_t = act_t + dt if act else 0.0


func _player():
	if world == null:
		return null
	var p = world.get("player")
	if p == null or not is_instance_valid(p):
		return null
	if p.dead:
		return null
	return p


func _update_status(delta: float) -> void:
	var dps := 0.0
	var dot_kind := ""
	if burn_t > 0.0:
		burn_t -= delta
		dps += 1.5
		dot_kind = "burn"
	if poison_t > 0.0:
		poison_t -= delta
		dps += 1.0
		if dot_kind == "":
			dot_kind = "poison"
	if freeze_t > 0.0:
		freeze_t -= delta
	if shock_t > 0.0:
		shock_t -= delta
	fx_t -= delta
	if fx_t <= 0.0:
		fx_t = 0.18
		if burn_t > 0.0:
			_sparks(global_position + Vector2(0.0, -hh * 0.5), Color("ff7020"), 1, 40.0)
			_smoke(global_position + Vector2(0.0, -hh), 1, 3.0)
		if poison_t > 0.0:
			_sparks(global_position + Vector2(randf_range(-hw, hw), -hh * 0.5), Color("70ff50"), 1, 25.0)
		if shock_t > 0.0:
			_sparks(global_position, Color("fff060"), 2, 70.0)
	if dps <= 0.0 or pile:
		return
	if is_boss:
		dps *= 0.4
	dot_acc += dps * delta
	dot_tick -= delta
	if dot_tick <= 0.0:
		dot_tick = 0.4
		hp -= dot_acc
		dot_acc = 0.0
		flash = 0.05
		if hp <= 0.0:
			_on_zero(dot_kind, "dot")


func _reassemble() -> void:
	pile = false
	hp = maxf(1.0, ceilf(max_hp * 0.5))
	state = "idle"
	hit_stun = 0.3
	_sparks(global_position, BONE, 6, 80.0)
	Sfx.play("flap", 0.1)


func _contact_damage() -> void:
	if def.stationary or touch_cd > 0.0 or not act or not have_p or pile:
		return
	if launched or hit_stun > 0.0 or shock_t > 0.0:
		return
	if kind == "ghost" and ghost_a < 0.4:
		return
	var p = _player()
	if p == null or p.is_invulnerable():
		return
	var hr: float = p.HURT_RADIUS
	if p.global_position.distance_to(global_position) < radius * 0.75 + hr:
		touch_cd = 1.0
		p.hurt(1, global_position)


# ================================================================ helpers

func _fx():
	if world == null:
		return null
	return world.get("fx")


func _boom(pos: Vector2, r: float, col := Color(1.0, 0.5, 0.1)) -> void:
	var fx = _fx()
	if fx != null:
		fx.explosion(pos, r, col)


func _sparks(pos: Vector2, col: Color, n := 6, spd := 120.0) -> void:
	var fx = _fx()
	if fx != null:
		fx.sparks(pos, col, n, spd)


func _smoke(pos: Vector2, n := 3, size := 6.0) -> void:
	var fx = _fx()
	if fx != null:
		fx.smoke(pos, n, size)


func _popup(pos: Vector2, text: String, col := Color.WHITE) -> void:
	var fx = _fx()
	if fx != null:
		fx.popup(pos, text, col)


func _shake(s: float) -> void:
	var fx = _fx()
	if fx != null:
		fx.shake(s)


func _ring(pos: Vector2, r: float, col: Color) -> void:
	var fx = _fx()
	if fx != null:
		fx.ring(pos, r, col)


func _debris(pos: Vector2, col: Color, n := 6) -> void:
	var fx = _fx()
	if fx != null:
		fx.debris(pos, col, n)


func _shot(skind: String, pos: Vector2, v: Vector2, opts := {}) -> void:
	var layer = world.get("shots_layer")
	if layer == null:
		return
	var s := EnemyShot.new()
	s.setup(skind, world, v, opts)
	layer.add_child(s)
	s.global_position = pos


func _face_to(dx: float) -> void:
	if absf(dx) > 3.0:
		facing = 1 if dx > 0.0 else -1


func _fdir() -> int:
	return facing if facing != 0 else 1


## Attack timer: returns true on the frame a telegraph finishes (fire now).
func _cycle(dt: float, ready: bool, wind: float, cooldown: float) -> bool:
	if state == "wind":
		st += dt
		if st >= wind_len:
			state = "idle"
			st = 0.0
			cd = cooldown * _rate_mul()
			return act
		return false
	cd -= dt
	if ready and act and act_t > 0.6 and cd <= 0.0:
		state = "wind"
		st = 0.0
		wind_len = wind
	return false


func _wind_frac() -> float:
	if state != "wind" or wind_len <= 0.0:
		return 0.0
	return clampf(st / wind_len, 0.0, 1.0)


func _ground_ahead(dir: int) -> bool:
	var gp := global_position
	var x := dir * (hw + 3.0)
	for dy in [hh + 3.0, hh + 9.0, hh + 15.0]:
		if world.is_solid(gp + Vector2(x, dy)):
			return true
	return false


## Walk in `dir` (-1/+1). Returns false (and stops) at walls and ledges.
func _walk(dir: int, speed: float) -> bool:
	if is_on_floor():
		var wall := is_on_wall() and get_wall_normal().x * dir < 0.0
		if wall or not _ground_ahead(dir):
			velocity.x = 0.0
			return false
	velocity.x = dir * speed * slow_mul
	return true


func _patrol(speed: float) -> void:
	if not _walk(facing, speed):
		facing = -facing


func _keep_distance(near: float, far: float, spd: float) -> void:
	var d := absf(pdx)
	if d < near:
		_walk(-1 if pdx > 0.0 else 1, spd)
	elif d > far:
		_walk(1 if pdx > 0.0 else -1, spd)
	else:
		velocity.x = 0.0


func _fly_to(desired: Vector2, rate := 4.0) -> void:
	velocity = velocity.lerp(desired * slow_mul, 1.0 - exp(-rate * get_physics_process_delta_time()))


func _steer(target: Vector2, max_speed: float, rate := 3.0) -> void:
	_fly_to(((target - global_position) * 2.0).limit_length(max_speed), rate)


## Launch velocity to land on `to`. high = lofted arc. Falls back to 45 degrees if out of range.
func _ballistic(from: Vector2, to: Vector2, speed: float, g: float, high := false) -> Vector2:
	var d := to - from
	var x := absf(d.x)
	var dirx := 1.0 if d.x >= 0.0 else -1.0
	if x < 2.0:
		return Vector2(0.0, -speed)
	var y := -d.y
	var s2 := speed * speed
	var disc := s2 * s2 - g * (g * x * x + 2.0 * y * s2)
	var ang := deg_to_rad(45.0)
	if disc >= 0.0:
		var root := sqrt(disc)
		ang = atan((s2 + (root if high else -root)) / (g * x))
	return Vector2(cos(ang) * dirx, -sin(ang)) * speed


## Ballistic aim at the dragon with target leading.
func _aim_ballistic(from: Vector2, speed: float, g: float, high := false, lead := 0.8) -> Vector2:
	var target := ppos
	var v := _ballistic(from, target, speed, g, high)
	var pv := pvel.limit_length(300.0)
	for i in 2:
		var tf := absf(target.x - from.x) / maxf(absf(v.x), 30.0)
		target = ppos + pv * tf * lead
		v = _ballistic(from, target, speed, g, high)
	return v.rotated(randf_range(-0.04, 0.04))


func _muzzle(ox: float, oy: float) -> Vector2:
	return global_position + Vector2(_fdir() * ox, oy)


func _ray_end(from: Vector2, dir: Vector2, length: float) -> Vector2:
	var d := 6.0
	while d < length:
		var pt := from + dir * d
		if world.is_solid(pt):
			return pt
		d += 6.0
	return from + dir * length


func _count_summoned() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy:
			var en: Enemy = node
			if en.has_meta("summoned") and not en.dead:
				n += 1
	return n


# ================================================================ AI dispatch

func _think(dt: float) -> void:
	if not act:
		if state == "wind":
			state = "idle"
		if fly:
			_fly_to(Vector2(0.0, sin(age * 2.0 + phase) * 10.0), 3.0)
		elif kind != "arrow_trap":
			velocity.x = 0.0
		return
	match mode:
		"squire": _ai_squire(dt, 42.0)
		"skeleton": _ai_squire(dt, 52.0)
		"knight": _ai_knight(dt)
		"archer": _ai_archer(dt)
		"crossbow": _ai_crossbow(dt)
		"bomber": _ai_bomber(dt)
		"spearman": _ai_spearman(dt)
		"mage": _ai_mage(dt)
		"ice_mage": _ai_ice_mage(dt)
		"cleric": _ai_cleric(dt)
		"balloon": _ai_balloon(dt)
		"rocketeer": _ai_rocketeer(dt)
		"ballista": _ai_ballista(dt)
		"cannon": _ai_cannon(dt)
		"catapult": _ai_catapult(dt)
		"berserker": _ai_berserker(dt)
		"bat": _ai_bat(dt)
		"slime": _ai_slime(dt)
		"arrow_trap": _ai_arrow_trap(dt)
		"ghost": _ai_ghost(dt)
		"golden_knight": _ai_golden(dt)
		"warlord": _ai_warlord(dt)


# ---------------------------------------------------------------- melee walkers

func _ai_squire(_dt: float, spd: float) -> void:
	if absf(pdx) < 240.0:
		_face_to(pdx)
		_walk(facing, spd)
	else:
		_patrol(spd * 0.5)


func _ai_knight(dt: float) -> void:
	# Turns slowly, so a dragon that flies over his head gets a free shot at his back.
	turn_t -= dt
	var want := 1 if pdx > 0.0 else -1
	if want != facing and turn_t <= 0.0 and absf(pdx) > 6.0:
		facing = want
		turn_t = 0.9
	if absf(pdx) < 240.0:
		_walk(facing, 30.0)
	else:
		_patrol(18.0)


# ---------------------------------------------------------------- ranged units

func _ai_archer(dt: float) -> void:
	_face_to(pdx)
	if state == "wind":
		velocity.x = 0.0
		aim = _aim_ballistic(_muzzle(5.0, -3.0), 330.0 * _spd_mul(), 360.0)
	else:
		_keep_distance(100.0, 250.0, 38.0)
	if _cycle(dt, pdist < 300.0, 0.45, 2.3):
		Sfx.play("arrow")
		_shot("arrow", _muzzle(5.0, -3.0), aim, {"g": 360.0})


func _ai_crossbow(dt: float) -> void:
	_face_to(pdx)
	if state == "wind":
		velocity.x = 0.0
		aim = (ppos + pvel.limit_length(250.0) * 0.12 - _muzzle(6.0, -3.0)).normalized() * 390.0 * _spd_mul()
	else:
		_keep_distance(110.0, 250.0, 34.0)
	if reload_t > 0.0:
		reload_t -= dt
	if _cycle(dt, pdist < 300.0 and reload_t <= 0.0, 0.55, 2.8):
		Sfx.play("arrow")
		_shot("bolt", _muzzle(7.0, -3.0), aim)
		reload_t = 0.6
		recoil = 2.0


func _ai_bomber(dt: float) -> void:
	_face_to(pdx)
	if not has_item:
		reload_t -= dt
		if reload_t <= 0.0:
			has_item = true
	if state == "wind":
		velocity.x = 0.0
		aim = _aim_ballistic(_muzzle(0.0, -16.0), 240.0 * _spd_mul(), 620.0, false, 0.5)
	else:
		_keep_distance(80.0, 150.0, 30.0)
	if _cycle(dt, pdist < 230.0 and has_item, 0.55, 3.0):
		Sfx.play("bomb")
		_shot("bomb", _muzzle(0.0, -16.0), aim)
		has_item = false
		reload_t = 1.4


func _ai_spearman(dt: float) -> void:
	_face_to(pdx)
	if not has_item:
		reload_t -= dt
		if reload_t <= 0.0:
			has_item = true
	if state == "wind":
		velocity.x = 0.0
		aim = _aim_ballistic(_muzzle(4.0, -6.0), 340.0 * _spd_mul(), 240.0)
	else:
		_keep_distance(70.0, 150.0, 36.0)
	if _cycle(dt, pdist < 220.0 and has_item, 0.4, 2.5):
		Sfx.play("arrow")
		_shot("spear", _muzzle(4.0, -6.0), aim)
		has_item = false
		reload_t = 1.2


func _ai_mage(dt: float) -> void:
	_face_to(pdx)
	tp_cd -= dt
	if state == "tp_out":
		st += dt
		velocity.x = 0.0
		tp_alpha = clampf(1.0 - st / 0.22, 0.0, 1.0)
		if st >= 0.22:
			_teleport()
			state = "tp_in"
			st = 0.0
		return
	if state == "tp_in":
		st += dt
		tp_alpha = clampf(st / 0.22, 0.0, 1.0)
		if st >= 0.22:
			state = "idle"
			st = 0.0
			tp_alpha = 1.0
		return
	if state == "wind":
		velocity.x = 0.0
	else:
		_keep_distance(100.0, 220.0, 24.0)
		if pdist < 55.0 and tp_cd <= 0.0:
			state = "tp_out"
			st = 0.0
			tp_cd = 2.5
			return
	if _cycle(dt, pdist < 300.0, 0.55, 3.4):
		Sfx.play("magic")
		var dir := (ppos - _muzzle(5.0, -10.0)).normalized()
		_shot("orb", _muzzle(5.0, -10.0), dir * 85.0 * _spd_mul())
		state = "tp_out"
		st = 0.0
		tp_cd = 2.5


func _teleport() -> void:
	var old := global_position
	for i in 10:
		var nx := old.x + randf_range(-110.0, 110.0)
		if absf(nx - old.x) < 40.0:
			continue
		var gy: float = world.ground_y(nx, old.y - 40.0)
		if absf(gy - (old.y + hh)) > 70.0:
			continue
		var np := Vector2(nx, gy - hh - 1.0)
		if world.is_solid(np) or world.is_solid(np + Vector2(0.0, -hh)):
			continue
		_sparks(old, PURPLE, 8, 90.0)
		global_position = np
		_sparks(np, PURPLE, 8, 90.0)
		return


func _ai_ice_mage(dt: float) -> void:
	_face_to(pdx)
	if state == "wind":
		velocity.x = 0.0
	else:
		_keep_distance(110.0, 230.0, 24.0)
	if _cycle(dt, pdist < 300.0, 0.65, 3.8):
		Sfx.play("ice")
		var base := (ppos - _muzzle(5.0, -9.0)).angle()
		for i in 3:
			var a := base + deg_to_rad((i - 1) * 17.0)
			_shot("shard", _muzzle(5.0, -9.0), Vector2.from_angle(a) * 165.0 * _spd_mul())


func _ai_cleric(dt: float) -> void:
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = 0.3
		need_heal = _hurt_allies(95.0, false) > 0
	if state == "wind":
		velocity.x = 0.0
	elif pdist < 120.0:
		_face_to(pdx)
		_walk(-1 if pdx > 0.0 else 1, 40.0)
	else:
		_patrol(14.0)
	if _cycle(dt, need_heal, 0.6, 3.2):
		_hurt_allies(95.0, true)
		pulse_t = 0.6
		_ring(global_position, 40.0, Color("80ff90"))
		Sfx.play("magic", 0.05, -4.0)


## Counts (or heals) hurt allies within `r`.
func _hurt_allies(r: float, do_heal: bool) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Enemy):
			continue
		var en: Enemy = node
		if en.dead or en.pile or en.hp >= en.max_hp:
			continue
		if en.global_position.distance_to(global_position) > r:
			continue
		n += 1
		if do_heal:
			en.heal(1.0 if en.is_boss else 2.0)
	return n


# ---------------------------------------------------------------- flyers

func _ai_balloon(dt: float) -> void:
	_face_to(pdx)
	var target := Vector2(ppos.x + sin(age * 0.7 + phase) * 70.0, ppos.y - 85.0 + sin(age * 1.3) * 8.0)
	_steer(target, 42.0)
	var over := absf(pdx) < 28.0 and pdy > 20.0 and pdy < 190.0
	if _cycle(dt, over, 0.35, 2.4):
		Sfx.play("bomb")
		_shot("bomb", global_position + Vector2(0.0, 8.0), Vector2(velocity.x * 0.5, 20.0))


func _pop_balloon() -> void:
	balloon_alive = false
	mode = "bomber"
	fly = false
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	balloon_t = 1.0
	has_item = true
	state = "idle"
	cd = 1.5
	velocity.y = -30.0
	_ring(global_position + Vector2(0.0, -19.0), 14.0, Color("ffc070"))
	_smoke(global_position + Vector2(0.0, -19.0), 2, 5.0)
	_popup(global_position + Vector2(0.0, -26.0), "POP!", Color("ffd060"))
	Sfx.play("explode_small", 0.1, -6.0)


func _ai_rocketeer(dt: float) -> void:
	trail_t -= dt
	if trail_t <= 0.0:
		trail_t = 0.08
		_smoke(global_position + Vector2(-facing * 5.0, 6.0), 1, 3.0)
	if state == "ram":
		st += dt
		velocity = aim * 215.0 * slow_mul
		if st > 0.7 or is_on_wall() or is_on_ceiling() or is_on_floor():
			state = "recover"
			st = 0.0
		return
	if state == "recover":
		st += dt
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-5.0 * dt))
		if st > 0.5:
			state = "idle"
		return
	_face_to(pdx)
	if state == "wind":
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * dt))
		aim = (ppos - global_position).normalized()
	else:
		var a := age * 0.9 + phase
		_steer(ppos + Vector2(cos(a) * 95.0, -70.0 + sin(a * 1.7) * 18.0), 95.0)
	if _cycle(dt, pdist < 270.0, 0.55, 2.2):
		state = "ram"
		st = 0.0
		aim = (ppos - global_position).normalized()
		Sfx.play("dash", 0.05, -4.0)


func _ai_bat(dt: float) -> void:
	if state == "swoop":
		st += dt
		aim = aim.rotated(sin(st * 8.0) * 0.03)
		velocity = aim * 180.0 * slow_mul
		if st > 0.75 or is_on_wall() or is_on_floor():
			state = "retreat"
			st = 0.0
		facing = 1 if velocity.x >= 0.0 else -1
		return
	if state == "retreat":
		st += dt
		_fly_to(Vector2(-aim.x * 50.0, -85.0), 5.0)
		if st > 0.6:
			state = "idle"
			st = 0.0
		return
	var w := Vector2(cos(age * 2.3 + phase) * 55.0, sin(age * 3.1 + phase * 2.0) * 45.0)
	w.x += signf(pdx) * 15.0
	_fly_to(w, 3.0)
	if absf(velocity.x) > 5.0:
		facing = 1 if velocity.x > 0.0 else -1
	if state == "wind":
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * dt))
		aim = (ppos - global_position).normalized()
	if _cycle(dt, pdist < 230.0, 0.3, 2.2):
		state = "swoop"
		st = 0.0
		aim = (ppos - global_position).normalized()


func _ai_ghost(_dt: float) -> void:
	ghost_a = clampf(0.55 + 0.6 * sin(age * 1.4 + phase), 0.05, 1.0)
	_face_to(pdx)
	var wob := Vector2(0.0, sin(age * 2.5 + phase) * 22.0)
	var spd := 38.0 if ghost_a >= 0.4 else 60.0
	var dir := (ppos - global_position).normalized()
	if pdist < 22.0:
		dir = Vector2.ZERO
	_fly_to(dir * spd + wob, 2.5)


# ---------------------------------------------------------------- stationary weapons

func _ai_ballista(dt: float) -> void:
	velocity.x = 0.0
	_face_to(pdx)
	var m := _muzzle(7.0, -4.0)
	if state == "wind" and st < wind_len - 0.35:
		aim = (ppos - m).normalized()
		aim_end = _ray_end(m, aim, 380.0)
	if _cycle(dt, pdist < 420.0 and pdist > 50.0, 1.3, 3.8):
		Sfx.play("shoot_big")
		_shot("ballista", m + aim * 10.0, aim * 540.0 * _spd_mul())
		recoil = 5.0
		_shake(2.0)


func _ai_cannon(dt: float) -> void:
	velocity.x = 0.0
	_face_to(pdx)
	var m := _muzzle(7.0, -3.0)
	if state == "wind":
		aim = _aim_ballistic(m, 340.0 * _spd_mul(), 320.0)
		trail_t -= dt
		if trail_t <= 0.0:
			trail_t = 0.1
			_sparks(_muzzle(-8.0, -6.0), Color("ffe040"), 2, 40.0)
	if _cycle(dt, pdist < 420.0 and pdist > 60.0, 0.7, 3.6):
		Sfx.play("shoot_big")
		_shot("cannonball", m + aim.normalized() * 8.0, aim, {"g": 320.0})
		_smoke(m + aim.normalized() * 8.0, 3, 5.0)
		recoil = 5.0
		_shake(2.0)


func _ai_catapult(dt: float) -> void:
	velocity.x = 0.0
	_face_to(pdx)
	var m := _muzzle(6.0, -14.0)
	if state == "wind":
		aim = _aim_ballistic(m, 300.0 * _spd_mul(), 520.0, true, 0.6)
	if _cycle(dt, pdist < 450.0 and pdist > 90.0, 1.0, 5.0):
		Sfx.play("shoot_big")
		_shot("boulder", m, aim, {"g": 520.0})
		recoil = 6.0
		_shake(2.5)


func _ai_arrow_trap(dt: float) -> void:
	if facing == 0 and have_p and act:
		facing = 1 if pdx > 0.0 else -1
	if facing == 0:
		return
	if burst_left > 0:
		burst_t -= dt
		if burst_t <= 0.0:
			var oy := (burst_left - 2) * 3.0
			_shot("arrow", global_position + Vector2(facing * 8.0, oy), Vector2(facing * 380.0 * _spd_mul(), 0.0), {"g": 0.0, "life": 3.0})
			Sfx.play("arrow")
			burst_left -= 1
			burst_t = 0.13
		return
	var ready := act and pdx * facing > 0.0 and absf(pdy) < 70.0 and absf(pdx) < 380.0
	if _cycle(dt, ready, 0.5, 2.8):
		burst_left = 3
		burst_t = 0.0


# ---------------------------------------------------------------- berserker, slime

func _ai_berserker(dt: float) -> void:
	match state:
		"charge":
			st += dt
			velocity.x = charge_dir * 205.0 * slow_mul
			trail_t -= dt
			if trail_t <= 0.0:
				trail_t = 0.07
				_smoke(global_position + Vector2(-charge_dir * 4.0, hh), 1, 3.0)
			var wall := is_on_wall() and get_wall_normal().x * charge_dir < 0.0
			if wall and st > 0.1:
				_self_stun(1.4)
			elif st > 1.5 or (is_on_floor() and not _ground_ahead(charge_dir)):
				state = "idle"
				cd = 1.8
			return
		"stunned":
			st += dt
			velocity.x = 0.0
			if st >= stun_len:
				state = "idle"
				cd = 1.2
			return
	_face_to(pdx)
	if state == "wind":
		velocity.x = 0.0
	elif absf(pdx) < 300.0:
		_walk(facing, 32.0)
	else:
		_patrol(18.0)
	var ready := absf(pdx) < 210.0 and absf(pdy) < 90.0
	if _cycle(dt, ready, 0.5, 0.2):
		state = "charge"
		st = 0.0
		charge_dir = facing
		Sfx.play("dash")


func _self_stun(length: float) -> void:
	state = "stunned"
	st = 0.0
	stun_len = length
	velocity.x = -charge_dir * 40.0
	_sparks(global_position + Vector2(charge_dir * (hw + 2.0), 0.0), Color("ffe080"), 8, 120.0)
	_debris(global_position + Vector2(charge_dir * (hw + 2.0), 0.0), Color("8a8a9a"), 4)
	_shake(4.0)
	Sfx.play("slam", 0.1, -4.0)


func _ai_slime(dt: float) -> void:
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * dt)
		if absf(pdx) < 260.0:
			_face_to(pdx)
	var ready := is_on_floor()
	if _cycle(dt, ready, 0.25, 0.9 + randf() * 0.5):
		var vx := facing * (60.0 if absf(pdx) < 260.0 else 25.0) * (1.3 if small else 1.0)
		if is_on_wall() or not _ground_ahead(facing):
			facing = -facing
			vx = -vx
		velocity = Vector2(vx * slow_mul, -(170.0 if small else 200.0))
		squash = -0.5


# ---------------------------------------------------------------- bosses

func _rage_check() -> void:
	if rage or hp >= max_hp * 0.5:
		return
	rage = true
	state = "roar"
	st = 0.0
	_popup(global_position + Vector2(0.0, -float(def.top) - 6.0), "ENRAGED!", Color("ff5030"))
	_shake(6.0)
	_ring(global_position, 40.0, Color("ff5030"))
	Sfx.play("hurt", 0.05)


func _ai_golden(dt: float) -> void:
	_rage_check()
	var spd: float = float(def.speed) * (1.3 if rage else 1.0)
	st += dt
	match state:
		"roar":
			velocity.x = 0.0
			if st >= 0.8:
				state = "idle"
				cd = 0.6
		"charge_wind":
			velocity.x = 0.0
			if st < wind_len - 0.15:
				_face_to(pdx)
			if st >= wind_len:
				state = "charge"
				st = 0.0
				charge_dir = _fdir()
				Sfx.play("dash")
		"charge":
			velocity.x = charge_dir * (275.0 if rage else 235.0) * slow_mul
			trail_t -= dt
			if trail_t <= 0.0:
				trail_t = 0.06
				_smoke(global_position + Vector2(-charge_dir * 8.0, hh), 1, 4.0)
			var wall := is_on_wall() and get_wall_normal().x * charge_dir < 0.0
			if wall and st > 0.1:
				_self_stun(1.5)
			elif st > 1.1 or (is_on_floor() and not _ground_ahead(charge_dir)):
				state = "recover"
				st = 0.0
		"stunned":
			velocity.x = 0.0
			if st >= stun_len:
				state = "idle"
				cd = 0.8
		"jump_wind":
			velocity.x = 0.0
			if st >= wind_len:
				state = "jump"
				st = 0.0
				velocity = Vector2(clampf(pdx * 1.1, -230.0, 230.0), -400.0)
				Sfx.play("jump")
		"jump":
			if is_on_floor() and st > 0.25:
				_shockwaves(210.0 if not rage else 260.0)
				state = "recover"
				st = 0.0
				velocity.x = 0.0
		"recover":
			velocity.x = 0.0
			if st >= (0.9 if not rage else 0.55):
				state = "idle"
				cd = randf_range(0.8, 1.6) * (0.7 if rage else 1.0)
		_:
			_face_to(pdx)
			if absf(pdx) > 40.0:
				_walk(facing, spd)
			else:
				velocity.x = 0.0
			cd -= dt
			if cd <= 0.0 and act_t > 0.8:
				var pick := "charge" if (randf() < 0.5 and absf(pdy) < 110.0) else "jump"
				if pick == last_atk and randf() < 0.7:
					pick = "jump" if pick == "charge" else "charge"
				last_atk = pick
				st = 0.0
				if pick == "charge":
					state = "charge_wind"
					wind_len = 0.55 if not rage else 0.4
				else:
					state = "jump_wind"
					wind_len = 0.45


## Two ground shockwaves, one each way.
func _shockwaves(spd: float) -> void:
	var base := global_position + Vector2(0.0, hh - 2.0)
	for d in [-1, 1]:
		_shot("wave", base + Vector2(d * 12.0, 0.0), Vector2(d * spd, 0.0))
	_boom(base, 18.0, Color(0.9, 0.7, 0.3))
	_debris(base, Color("8a8a9a"), 8)
	_shake(6.0)
	Sfx.play("slam")


func _ai_warlord(dt: float) -> void:
	_rage_check()
	var spd: float = float(def.speed) * (1.5 if rage else 1.0)
	st += dt
	match state:
		"roar":
			velocity.x = 0.0
			if st >= 0.9:
				state = "idle"
				cd = 0.6
		"volley_wind":
			velocity.x = 0.0
			_face_to(pdx)
			if st >= wind_len:
				state = "volley"
				st = 0.0
				volley_left = 12 if rage else 7
				volley_t = 0.0
		"volley":
			velocity.x = 0.0
			volley_t -= dt
			if volley_t <= 0.0 and volley_left > 0:
				var idx := (12 if rage else 7) - volley_left
				var n := 12 if rage else 7
				var m := _muzzle(10.0, -float(hh) * 0.9)
				var tgt := ppos + Vector2((idx - n * 0.5) * 28.0 + randf_range(-10.0, 10.0), 0.0)
				var v := _ballistic(m, tgt, 520.0, 500.0, true)
				_shot("arrow", m, v, {"g": 500.0, "life": 6.0})
				Sfx.play("arrow", 0.15)
				volley_left -= 1
				volley_t = 0.07
			if volley_left <= 0:
				state = "recover"
				st = 0.0
		"slam_wind":
			velocity.x = 0.0
			if st >= wind_len:
				_shockwaves(190.0 if not rage else 240.0)
				wave2_t = 0.35 if rage else 0.0
				state = "recover"
				st = 0.0
		"summon_wind":
			velocity.x = 0.0
			if st >= wind_len:
				_summon()
				state = "recover"
				st = 0.0
		"recover":
			velocity.x = 0.0
			if wave2_t > 0.0:
				wave2_t -= dt
				if wave2_t <= 0.0:
					_shockwaves(300.0)
			if st >= (0.8 if not rage else 0.5):
				state = "idle"
				cd = 1.8 if not rage else 1.1
		_:
			_face_to(pdx)
			if absf(pdx) > 90.0:
				_walk(facing, spd)
			else:
				velocity.x = 0.0
			cd -= dt
			if cd <= 0.0 and act_t > 1.0:
				var opts := ["volley", "slam", "summon"]
				opts.erase(last_atk)
				var pick: String = opts[randi() % opts.size()]
				if pick == "summon" and _count_summoned() >= 4:
					pick = "volley"
				last_atk = pick
				st = 0.0
				wind_len = 0.85 if pick != "slam" else 0.8
				state = pick + "_wind"
				Sfx.play("magic", 0.05, -4.0)


func _summon() -> void:
	var n := 3 if rage else 2
	for i in n:
		var dir := -1 if i % 2 == 0 else 1
		var pos := global_position + Vector2(dir * (30.0 + i * 14.0), hh - 8.0)
		if world.is_solid(pos):
			pos = global_position + Vector2(0.0, hh - 8.0)
		var m = world.spawn_enemy("squire", pos)
		if m != null:
			m.set_meta("summoned", true)
			m.set_meta("spawned", true)
			m.launched = true
			m.velocity = Vector2(dir * 70.0, -170.0)
		_sparks(pos, ORANGE, 6, 80.0)
	_ring(global_position, 36.0, ORANGE)
	Sfx.play("magic")


# ================================================================ drawing

func _k(c: Color) -> Color:
	if flash > 0.0:
		return Color(1.0, 1.0, 1.0, c.a * _alpha())
	var o := c
	if freeze_t > 0.0:
		o = o.lerp(Color(0.55, 0.85, 1.0), 0.55)
	if poison_t > 0.0:
		o = o.lerp(Color(0.45, 1.0, 0.35), 0.35)
	if burn_t > 0.0 and fmod(age, 0.2) < 0.1:
		o = o.lerp(Color(1.0, 0.5, 0.1), 0.35)
	if shock_t > 0.0 and fmod(age, 0.1) < 0.05:
		o = o.lerp(Color(1.0, 1.0, 0.4), 0.5)
	o.a *= _alpha()
	return o


func _alpha() -> float:
	var a := 1.0
	if kind == "ghost":
		a *= ghost_a
	if kind == "mage":
		a *= tp_alpha
	return a


func _rc(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), _k(c))


func _pg(pts: Array, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), _k(c))


func _ci(x: float, y: float, r: float, c: Color) -> void:
	draw_circle(Vector2(x, y), r, _k(c))


func _ln(a: Vector2, b: Vector2, c: Color, w := 1.0) -> void:
	draw_line(a, b, _k(c), w)


func _oy() -> float:
	return 0.0 if kind == "bat" else hh - 6.0 * sc


func _flip() -> void:
	draw_set_transform(Vector2(0.0, _oy()), 0.0, Vector2(_fdir() * sc, sc))


func _noflip() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rotated part pivoting at unit-space (px, py); +x of the part points along `ang` (global).
func _xf_aim(px: float, py: float, ang: float) -> void:
	var f := _fdir()
	draw_set_transform(Vector2(px * f * sc, py * sc + _oy()), ang, Vector2(sc, sc * f))


func _aim_ang() -> float:
	if state == "wind" and aim != Vector2.ZERO:
		return aim.angle()
	return 0.0 if _fdir() >= 0 else PI


func _legs(c: Color) -> float:
	var walking := absf(velocity.x) > 4.0 and is_on_floor()
	var ph := sin(age * 12.0) if walking else 0.0
	_rc(-3.0 + ph * 1.2, 3.0, 2.0, 3.0, c)
	_rc(1.0 - ph * 1.2, 3.0, 2.0, 3.0, c)
	return -absf(ph) * 0.8


func _body(tunic: Color, helm: Color, plume: Color, by: float, trim := ORANGE) -> void:
	_rc(-3.5, -2.0 + by, 7.0, 5.0, tunic)
	_rc(-3.5, 1.5 + by, 7.0, 1.0, trim)
	_rc(-2.5, -8.0 + by, 5.0, 6.0, SKIN)
	_pg([Vector2(-3, -5 + by), Vector2(-3, -7 + by), Vector2(-1.5, -8.5 + by),
		Vector2(1.5, -8.5 + by), Vector2(3, -7 + by), Vector2(3, -5 + by)], helm)
	_rc(-3.0, -5.3 + by, 6.0, 0.8, helm.darkened(0.3))
	_rc(0.5, -4.0 + by, 1.0, 1.0, NAVY)
	if plume.a > 0.0:
		_pg([Vector2(-1, -8.5 + by), Vector2(1, -8.5 + by), Vector2(0.5, -11 + by), Vector2(-2.5, -10 + by)], plume)


func _draw() -> void:
	if dead:
		return
	if pile:
		_flip()
		_d_bones()
		_noflip()
		_overlays()
		return
	_flip()
	match kind:
		"squire": _d_squire()
		"knight", "golden_knight": _d_knight()
		"archer": _d_archer()
		"crossbow": _d_crossbow()
		"bomber": _d_bomber()
		"spearman": _d_spearman()
		"mage", "ice_mage": _d_mage()
		"cleric": _d_cleric()
		"balloon": _d_balloon()
		"rocketeer": _d_rocketeer()
		"ballista": _d_ballista()
		"cannon": _d_cannon()
		"catapult": _d_catapult()
		"berserker": _d_berserker()
		"bat": _d_bat()
		"slime": _d_slime()
		"skeleton": _d_skeleton()
		"arrow_trap": _d_trap()
		"ghost": _d_ghost()
		"warlord": _d_warlord()
	_noflip()
	_overlays()


func _d_squire() -> void:
	var by := _legs(NAVY)
	_body(Color("b4602a"), ORANGE, ORANGE, by)
	var th := 0.0
	if pdist < 36.0:
		th = sin(age * 10.0) * 2.0
	_rc(2.5 + th, -1.5 + by, 3.0, 2.0, SKIN)
	_ln(Vector2(4.0 + th, -1.0 + by), Vector2(11.0 + th, -4.5 + by), STEEL, 1.5)
	_rc(4.0 + th, -2.5 + by, 1.0, 3.0, GOLD)


func _d_knight() -> void:
	var gold := kind == "golden_knight"
	var by := _legs(Color("a07a10") if gold else NAVY)
	var armor := GOLD if gold else STEEL
	_body(armor, GOLD if gold else ORANGE, ORANGE if not gold else Color("d83030"), by, GOLD if gold else DARK_STEEL)
	if gold:
		_pg([Vector2(-3, -8.5 + by), Vector2(0, -12 + by), Vector2(3, -8.5 + by)], Color("fff0a0"))
		_rc(-4.5, -2.0 + by, 1.5, 4.0, Color("fff0a0"))
	var up := _shield_up()
	var lower := 0.0 if up else 3.0
	var sh := Color.WHITE if shield_flash > 0.0 else (GOLD if gold else ORANGE)
	_pg([Vector2(3, -6 + by + lower), Vector2(8.5, -5.5 + by + lower), Vector2(8.5, 1 + by + lower),
		Vector2(6, 5 + by + lower), Vector2(3, 1 + by + lower)], NAVY)
	_pg([Vector2(3.8, -5 + by + lower), Vector2(7.7, -4.7 + by + lower), Vector2(7.7, 0.7 + by + lower),
		Vector2(6, 4 + by + lower), Vector2(3.8, 0.7 + by + lower)], sh)
	_rc(5.5, -4.5 + by + lower, 1.0, 7.0, STEEL if not gold else Color("fff0a0"))
	_rc(3.8, -2.0 + by + lower, 4.0, 1.0, STEEL if not gold else Color("fff0a0"))
	if state == "charge_wind" or state == "jump_wind":
		_ci(0, 0, 9.0, Color(1.0, 0.8, 0.2, 0.25))


func _d_archer() -> void:
	var by := _legs(NAVY)
	_body(Color("3a8a5a"), Color("e07018"), Color(0, 0, 0, 0), by, Color("e07018"))
	var f := _wind_frac()
	_xf_aim(3.0, -2.0 + by, _aim_ang())
	_ln(Vector2(0, -5), Vector2(2, -2.5), WOOD, 1.0)
	_ln(Vector2(2, -2.5), Vector2(2.5, 0), WOOD, 1.0)
	_ln(Vector2(2.5, 0), Vector2(2, 2.5), WOOD, 1.0)
	_ln(Vector2(2, 2.5), Vector2(0, 5), WOOD, 1.0)
	if state == "wind":
		_ln(Vector2(0, -5), Vector2(-4.0 * f, 0), Color("e8f0ff"), 1.0)
		_ln(Vector2(-4.0 * f, 0), Vector2(0, 5), Color("e8f0ff"), 1.0)
		_ln(Vector2(-4.0 * f, 0), Vector2(7, 0), Color("c89850"), 1.0)
		_rc(7, -1, 2, 2, Color("e8f0ff"))
	else:
		_ln(Vector2(0, -5), Vector2(0, 5), Color("e8f0ff"), 1.0)
	_flip()


func _d_crossbow() -> void:
	var by := _legs(NAVY)
	_body(Color("6a4a30"), STEEL, ORANGE, by, STEEL)
	_xf_aim(2.0, -1.5 + by, _aim_ang())
	_rc(-2, -1.5, 9, 3, WOOD)
	_rc(5, -5, 1.5, 10, DARK_STEEL)
	if reload_t <= 0.0:
		_ln(Vector2(3, 0), Vector2(9, 0), STEEL, 1.0)
		_rc(9, -1, 2, 2, Color("e8f0ff"))
	if state == "wind" and _wind_frac() > 0.5:
		draw_line(Vector2(11, 0), Vector2(36, 0), Color(1.0, 0.2, 0.1, 0.6), 1.0)
	_flip()


func _d_bomber() -> void:
	var by := _legs(NAVY)
	_body(Color("5a3a28"), ORANGE, Color(0, 0, 0, 0), by, ORANGE)
	if has_item:
		var sh := 0.0
		var glow := 0.0
		if state == "wind":
			sh = sin(age * 50.0) * 0.8
			glow = 0.5 if fmod(age * 10.0, 1.0) < 0.5 else 0.0
		_rc(-4.5, -4.0 + by, 1.5, 4.0, SKIN)
		_rc(3.0, -4.0 + by, 1.5, 4.0, SKIN)
		_ci(sh, -15.5, 6.0, NAVY)
		_ci(sh, -15.5, 5.0, ORANGE.lightened(glow))
		_ci(sh - 1.5, -17.0, 1.6, Color("ffc070"))
		_rc(sh - 1.0, -23.0, 2.0, 2.5, STEEL)
		_ci(sh, -23.5, 1.4 + glow * 1.5, Color("ffe040"))
	else:
		_rc(2.5, -1.5 + by, 3.0, 2.0, SKIN)


func _d_spearman() -> void:
	var by := _legs(NAVY)
	_body(Color("a03030"), STEEL, ORANGE, by, ORANGE)
	if has_item:
		var f := _wind_frac()
		_xf_aim(1.0, -2.0 + by, lerpf(-0.5, -0.9, f) if _fdir() > 0 else PI + lerpf(0.5, 0.9, f))
		_ln(Vector2(-6, 0), Vector2(12, 0), WOOD, 1.5)
		_pg([Vector2(11, -2), Vector2(16, 0), Vector2(11, 2)], Color("e8f0ff"))
		_flip()
	_rc(2.0, -2.0 + by, 3.0, 2.0, SKIN)


func _d_mage() -> void:
	var ice := kind == "ice_mage"
	var robe := Color("3a78c8") if ice else Color("6a3ca8")
	var hat := Color("e0f0ff") if ice else Color("5a2c98")
	_pg([Vector2(-4, 6), Vector2(-3.5, -1), Vector2(3.5, -1), Vector2(4, 6)], robe)
	_rc(-4, 4.5, 8.0, 1.5, GOLD)
	_rc(-3.5, 1.0, 7.0, 1.0, GOLD)
	_rc(-2.0, -5.0, 4.0, 4.0, SKIN)
	_rc(0.5, -3.5, 1.0, 1.0, NAVY)
	_pg([Vector2(-5, -4.5), Vector2(5, -4.5), Vector2(2.0, -11), Vector2(-0.5, -17), Vector2(-2, -10)], hat)
	_rc(-3.5, -7.0, 7.0, 1.5, ORANGE if not ice else Color("60b0ff"))
	var f := _wind_frac()
	var orb_c := Color("60e0ff") if ice else Color("e090ff")
	_ln(Vector2(6, 5), Vector2(6, -9), WOOD, 1.0)
	_ci(6, -10, 1.8 + f * 2.5, orb_c)
	if f > 0.0:
		_ci(6, -10, 4.0 + f * 4.0, Color(orb_c.r, orb_c.g, orb_c.b, 0.25))


func _d_cleric() -> void:
	_legs(Color("d8cfb0"))
	_pg([Vector2(-4, 6), Vector2(-3.5, -2), Vector2(3.5, -2), Vector2(4, 6)], Color("f0e8d0"))
	_rc(-4, 4.5, 8.0, 1.5, ORANGE)
	_rc(-3.5, 0.5, 7.0, 1.0, ORANGE)
	_rc(-2.5, -8.0, 5.0, 6.0, SKIN)
	_pg([Vector2(-3.5, -4.5), Vector2(-3.5, -7), Vector2(-1.5, -9), Vector2(1.5, -9), Vector2(3.5, -7), Vector2(3.5, -4.5)], Color("f0e8d0"))
	_rc(0.5, -4.0, 1.0, 1.0, NAVY)
	draw_arc(Vector2(0, -11.5), 3.0, 0.0, TAU, 14, _k(GOLD), 1.0)
	_ln(Vector2(6, 5), Vector2(6, -8), WOOD, 1.0)
	_rc(5, -11, 2.0, 5.0, GOLD)
	_rc(4, -10, 4.0, 2.0, GOLD)
	if state == "wind":
		_ci(6, -9, 3.0 + _wind_frac() * 3.0, Color(0.5, 1.0, 0.6, 0.35))


func _d_balloon() -> void:
	var by := _legs(Color("3a2a28")) if not balloon_alive else 0.0
	if balloon_alive:
		_rc(-3.0, 3.0, 2.0, 3.0, NAVY)
		_rc(1.0, 3.0, 2.0, 3.0, NAVY)
	_body(Color("c03828"), ORANGE, Color(0, 0, 0, 0), by)
	if balloon_alive:
		var sway := sin(age * 1.5 + phase) * 1.5
		_ln(Vector2(sway, -10), Vector2(-3, -5), Color("c8c0a0"), 1.0)
		_ln(Vector2(sway, -10), Vector2(3, -5), Color("c8c0a0"), 1.0)
		_ci(sway, -19, 8.5, NAVY)
		_ci(sway, -19, 7.5, ORANGE)
		_pg([Vector2(sway - 2, -26), Vector2(sway + 2, -26), Vector2(sway + 3, -12), Vector2(sway - 3, -12)], ORANGE.lightened(0.25))
		_pg([Vector2(sway - 1.5, -11), Vector2(sway + 1.5, -11), Vector2(sway, -9)], ORANGE.darkened(0.2))
		_ci(sway - 3, -22, 1.8, Color("ffc070"))
		if has_item:
			_ci(-6, 2, 2.5, NAVY)
			_ci(-6, 2, 1.8, ORANGE)
	elif balloon_t > 0.0:
		balloon_t -= get_physics_process_delta_time()
		var t := 1.0 - balloon_t
		_ci(0, -19 - t * 50.0, 8.0 * (1.0 - t * 0.6), Color(ORANGE.r, ORANGE.g, ORANGE.b, balloon_t))
	if not balloon_alive and has_item:
		_ci(0, -15.5, 5.0, NAVY)
		_ci(0, -15.5, 4.0, ORANGE)


func _d_rocketeer() -> void:
	var by := -sin(age * 8.0) * 0.8
	_rc(-3.0, 3.0, 2.0, 3.0, NAVY)
	_rc(1.0, 3.0, 2.0, 3.0, NAVY)
	_body(Color("5a6a8a"), ORANGE, ORANGE, by, STEEL)
	_rc(0.0, -6.0 + by, 3.5, 1.5, GOLD)
	_rc(-7.0, -3.0 + by, 3.0, 7.0, STEEL)
	_rc(-7.0, -4.0 + by, 3.0, 1.0, ORANGE)
	var fl := 3.0 + randf() * 3.0 + (4.0 if state == "ram" or state == "wind" else 0.0)
	_pg([Vector2(-7, 4 + by), Vector2(-4, 4 + by), Vector2(-5.5, 4 + fl + by)], ORANGE)
	_pg([Vector2(-6.2, 4 + by), Vector2(-4.8, 4 + by), Vector2(-5.5, 4 + fl * 0.6 + by)], Color("ffe040"))
	_rc(2.5, -1.5 + by, 3.0, 2.0, SKIN)


func _d_ballista() -> void:
	var rc := recoil
	_ci(-5, 3.5, 2.8, WOOD)
	_ci(5, 3.5, 2.8, WOOD)
	_ci(-5, 3.5, 1.0, NAVY)
	_ci(5, 3.5, 1.0, NAVY)
	_rc(-7, 0, 14.0, 3.0, Color("6a4020"))
	_rc(-1, -2, 2.0, 3.0, DARK_STEEL)
	_xf_aim(0.0, -2.0, _aim_ang())
	_rc(-8.0 - rc, -1.5, 18.0, 3.0, WOOD)
	_pg([Vector2(7 - rc, -1), Vector2(7 - rc, -9), Vector2(9 - rc, -9), Vector2(10 - rc, 0),
		Vector2(9 - rc, 9), Vector2(7 - rc, 9), Vector2(7 - rc, 1)], Color("5a3a20"))
	_ln(Vector2(8 - rc, -9), Vector2(-3 - rc * 0.5, 0), Color("e8f0ff"), 1.0)
	_ln(Vector2(8 - rc, 9), Vector2(-3 - rc * 0.5, 0), Color("e8f0ff"), 1.0)
	_ln(Vector2(-3, 0), Vector2(14, 0), Color("a07040"), 1.5)
	_pg([Vector2(14, -2), Vector2(19, 0), Vector2(14, 2)], Color("e8f0ff"))
	_flip()


func _d_cannon() -> void:
	var rc := recoil
	_rc(-7, 2, 14.0, 3.0, WOOD)
	_ci(-4, 4, 3.0, WOOD)
	_ci(4, 4, 3.0, WOOD)
	_ci(-4, 4, 1.0, NAVY)
	_ci(4, 4, 1.0, NAVY)
	var ang := _aim_ang()
	if state != "wind":
		ang = deg_to_rad(-25.0) if _fdir() > 0 else PI + deg_to_rad(25.0)
	_xf_aim(0.0, 0.0, ang)
	_pg([Vector2(-8 - rc, -3.5), Vector2(8 - rc, -4.5), Vector2(10 - rc, -4.5), Vector2(10 - rc, 4.5),
		Vector2(8 - rc, 4.5), Vector2(-8 - rc, 3.5)], NAVY)
	_rc(-6.0 - rc, -2.5, 14.0, 1.2, DARK_STEEL)
	_rc(6.0 - rc, -4.5, 2.0, 9.0, ORANGE)
	if state == "wind":
		_ci(-8.5, -3.5, 1.5 + sin(age * 40.0) * 0.7, Color("ffe040"))
	_flip()


func _d_catapult() -> void:
	_rc(-12, 2, 24.0, 3.0, WOOD)
	_ci(-9, 4.5, 3.5, WOOD)
	_ci(9, 4.5, 3.5, WOOD)
	_ci(-9, 4.5, 1.2, NAVY)
	_ci(9, 4.5, 1.2, NAVY)
	_pg([Vector2(-8, 2), Vector2(-5, -8), Vector2(-3, -8), Vector2(-3, 2)], Color("6a4020"))
	_pg([Vector2(3, 2), Vector2(3, -8), Vector2(5, -8), Vector2(8, 2)], Color("6a4020"))
	var f := _wind_frac()
	var arm_ang := lerpf(-0.9, 0.7, f) if state == "wind" else -0.9
	var pivot := Vector2(0, -7)
	var tip := pivot + Vector2(cos(arm_ang + PI), sin(arm_ang + PI)) * 14.0
	var bucket := pivot + Vector2(cos(arm_ang - 0.1), sin(arm_ang - 0.1)) * 14.0
	_ln(pivot, bucket, WOOD, 2.0)
	_ln(pivot, tip, WOOD.darkened(0.2), 2.0)
	_ci(pivot.x, pivot.y, 1.6, STEEL)
	_ci(bucket.x, bucket.y - 1.5, 3.0, Color("8a8a9a"))
	_ci(bucket.x - 0.8, bucket.y - 2.3, 1.0, Color("b4b4c4"))


func _d_berserker() -> void:
	var charging := state == "charge"
	var by := _legs(Color("6a2020"))
	var lean := 1.5 if charging else 0.0
	_rc(-3.5 + lean, -2.0 + by, 7.0, 5.0, SKIN.darkened(0.1))
	_rc(-3.5 + lean, 1.5 + by, 7.0, 1.5, Color("6a2020"))
	_rc(-2.5 + lean, -8.0 + by, 5.0, 6.0, SKIN)
	_pg([Vector2(-3 + lean, -5 + by), Vector2(-3 + lean, -7.5 + by), Vector2(3 + lean, -7.5 + by), Vector2(3 + lean, -5 + by)], Color("ff8a20"))
	_pg([Vector2(-3 + lean, -7.5 + by), Vector2(-4 + lean, -11 + by), Vector2(-1 + lean, -8.5 + by)], STEEL)
	_pg([Vector2(3 + lean, -7.5 + by), Vector2(4 + lean, -11 + by), Vector2(1 + lean, -8.5 + by)], STEEL)
	_ln(Vector2(-0.5 + lean, -5.2 + by), Vector2(2.5 + lean, -4.2 + by), NAVY, 1.0)
	_rc(0.8 + lean, -3.8 + by, 1.0, 1.0, RED)
	var raise := -3.0 if state == "wind" else 0.0
	_rc(2.5 + lean, -2.0 + by + raise, 3.0, 2.5, SKIN)
	_ln(Vector2(4 + lean, 1 + by + raise), Vector2(7 + lean, -8 + by + raise), WOOD, 1.5)
	_pg([Vector2(6 + lean, -8 + by + raise), Vector2(10 + lean, -9 + by + raise), Vector2(10 + lean, -3 + by + raise), Vector2(6.5 + lean, -4 + by + raise)], STEEL)
	if state == "wind" or charging:
		_ci(0, 0, 10.0, Color(1.0, 0.15, 0.1, 0.22))


func _d_bat() -> void:
	var flap := sin(age * 20.0)
	var wy := flap * 4.0
	_pg([Vector2(-1, 0), Vector2(-7, -2 - wy), Vector2(-9, 1 - wy * 0.5), Vector2(-4, 2)], Color("3a2058"))
	_pg([Vector2(1, 0), Vector2(7, -2 - wy), Vector2(9, 1 - wy * 0.5), Vector2(4, 2)], Color("3a2058"))
	_ci(0, 0, 3.4, Color("503070"))
	_pg([Vector2(-2.5, -2), Vector2(-2, -5), Vector2(-0.5, -2.5)], Color("503070"))
	_pg([Vector2(2.5, -2), Vector2(2, -5), Vector2(0.5, -2.5)], Color("503070"))
	_rc(0.2, -1.0, 1.2, 1.2, Color("ff4040"))
	_rc(-1.8, -1.0, 1.2, 1.2, Color("ff4040"))


func _d_slime() -> void:
	var sq := squash
	if state == "wind":
		sq = 0.5 * _wind_frac() / 1.0
	var w := 6.0 * (1.0 + sq * 0.35)
	var h := 9.0 * (1.0 - sq * 0.4)
	var pts: Array = [Vector2(-w, 6)]
	for i in range(0, 9):
		var a := PI + PI * float(i) / 8.0
		pts.append(Vector2(cos(a) * w, 6.0 + sin(a) * h))
	pts.append(Vector2(w, 6))
	_pg(pts, Color("40c060"))
	_rc(-w, 5.0, w * 2.0, 1.0, Color("2a8a44"))
	_ci(-w * 0.4, 6.0 - h * 0.7, 1.4, Color("a0f0b0"))
	var ex := 1.5 if facing > 0 else -1.5
	_rc(-2.5 + ex * 0.4, 6.0 - h * 0.5, 2.0, 2.4, Color.WHITE)
	_rc(1.0 + ex * 0.4, 6.0 - h * 0.5, 2.0, 2.4, Color.WHITE)
	_rc(-1.8 + ex * 0.6, 6.0 - h * 0.4, 1.0, 1.4, NAVY)
	_rc(1.5 + ex * 0.6, 6.0 - h * 0.4, 1.0, 1.4, NAVY)


func _d_skeleton() -> void:
	var by := _legs(BONE)
	_rc(-3.0, 3.0, 1.0, 3.0, BONE)
	_rc(-1.5, -2.0 + by, 3.0, 5.0, NAVY)
	for i in 3:
		_rc(-3.0, -2.0 + by + i * 1.7, 6.0, 0.9, BONE)
	_rc(-2.5, -8.0 + by, 5.0, 6.0, BONE)
	_rc(-1.8, -6.0 + by, 1.6, 1.8, NAVY)
	_rc(0.4, -6.0 + by, 1.6, 1.8, NAVY)
	_rc(-1.5, -3.2 + by, 3.0, 1.0, NAVY)
	_rc(2.5, -1.5 + by, 3.0, 1.5, BONE)
	_ln(Vector2(4, -1 + by), Vector2(10.5, -5 + by), Color("a08060"), 1.5)
	_rc(3.5, -2.0 + by, 1.0, 2.0, WOOD)


func _d_bones() -> void:
	var rise := clampf(bones_t / 2.0, 0.0, 1.0)
	_rc(-5.0, 4.0, 10.0, 2.0, BONE)
	_rc(-3.0, 3.0, 6.0, 1.0, BONE)
	_rc(-4.0, 2.5, 1.0, 2.0, BONE.darkened(0.15))
	_rc(2.0, 2.0, 3.0, 1.0, BONE.darkened(0.15))
	_rc(-1.0, 1.5 - (1.0 - rise) * 0.0, 3.0, 2.5, BONE)
	_rc(-0.5, 2.0, 0.8, 0.8, NAVY)
	_rc(1.0, 2.0, 0.8, 0.8, NAVY)
	if bones_t < 0.7:
		_rc(-5.0 + randf() * 10.0, 3.0 - randf() * 3.0, 1.0, 1.0, BONE)


func _d_trap() -> void:
	var f := _fdir()
	_rc(-5.0 * f - (1.0 if f > 0 else 0.0), -2.0, 1.0, 10.0, DARK_STEEL)  # wall bracket
	_rc(-5.0, 1.0, 10.0, 10.0, Color("5a6a8a"))
	_rc(-5.0, 1.0, 10.0, 1.5, Color("8a9ac0"))
	_rc(-5.0, 9.5, 10.0, 1.5, Color("3a4a6a"))
	var glow := _wind_frac()
	for i in 3:
		var sy := 3.0 + i * 2.6
		_rc(1.0, sy, 5.0, 1.4, Color(1.0, 0.2 + 0.0 * glow, 0.1, 1.0) if glow > 0.0 and fmod(age * 12.0, 1.0) < 0.6 else NAVY)
		if burst_left > 0 or glow > 0.0:
			_rc(6.0, sy + 0.2, 2.0, 1.0, STEEL)
	_rc(-1.0, 4.0, 1.0, 6.0, Color("3a4a6a"))


func _d_ghost() -> void:
	var bob := sin(age * 3.0 + phase) * 1.0
	_ci(0, 0, 9.0, Color(0.7, 0.85, 1.0, 0.12))
	var wag := sin(age * 6.0) * 1.0
	_pg([Vector2(-5, 7 + bob), Vector2(-5.5, -2 + bob), Vector2(-3, -7 + bob), Vector2(3, -7 + bob),
		Vector2(5.5, -2 + bob), Vector2(5, 7 + bob), Vector2(3, 5 + bob + wag), Vector2(1, 7 + bob),
		Vector2(-1, 5 + bob - wag), Vector2(-3, 7 + bob)], Color("e0f0ff"))
	_pg([Vector2(4.5, 0 + bob), Vector2(9, 1 + bob - wag), Vector2(4.5, 3 + bob)], Color("e0f0ff"))
	_rc(-3.0, -4.0 + bob, 2.0, 3.0, NAVY)
	_rc(0.5, -4.0 + bob, 2.0, 3.0, NAVY)
	_rc(-1.5, 0.0 + bob, 3.0, 2.0, NAVY)


func _d_warlord() -> void:
	var by := _legs(Color("20263c"))
	var rg := rage
	var cape_w := sin(age * 3.0) * 1.5
	_pg([Vector2(-3, -2 + by), Vector2(-5, 6), Vector2(-9 - cape_w, 6), Vector2(-6, -2 + by)], Color("a02020") if not rg else Color("e03020"))
	_body(Color("2a3050"), Color("3a4060"), Color(0, 0, 0, 0), by, ORANGE)
	_pg([Vector2(-3, -7 + by), Vector2(-5.5, -11 + by), Vector2(-2, -8.5 + by)], STEEL)
	_pg([Vector2(3, -7 + by), Vector2(5.5, -11 + by), Vector2(2, -8.5 + by)], STEEL)
	_rc(-4.5, -3.0 + by, 2.5, 3.0, DARK_STEEL)
	_rc(2.0, -3.0 + by, 2.5, 3.0, DARK_STEEL)
	# Big sword
	var wf := 0.0
	if state == "slam_wind":
		wf = _wind_frac()
	elif state == "volley_wind" or state == "summon_wind":
		wf = 1.0
	var sang := lerpf(-1.1, -2.0, wf)
	if state == "idle" or state == "recover":
		sang = -1.1
	_xf_aim(3.0, -1.0 + by, sang if _fdir() > 0 else PI - sang)
	_rc(0, -0.8, 3.0, 1.6, SKIN)
	_rc(2.5, -2.2, 1.2, 4.4, GOLD)
	_rc(3.7, -1.0, 12.0, 2.0, STEEL)
	_pg([Vector2(15.7, -1.0), Vector2(18.5, 0.0), Vector2(15.7, 1.0)], STEEL)
	_flip()
	if state == "volley_wind" or state == "summon_wind":
		_ci(0, -14, 3.0 + _wind_frac() * 2.0, Color(1.0, 0.7, 0.2, 0.4))
	if rg:
		_ci(0, 0, 11.0, Color(1.0, 0.2, 0.1, 0.12))


func _overlays() -> void:
	var top := float(def.get("top", 10.0))
	# Healing pulse ring
	if pulse_t > 0.0:
		var r := 95.0 * (1.0 - pulse_t / 0.6)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.5, 1.0, 0.6, pulse_t / 0.6), 2.0)
		draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, pulse_t / 0.6 * 0.6), 1.0)
	# Long red aim line for the ballista
	if kind == "ballista" and state == "wind":
		var locked := st >= wind_len - 0.35
		var a := 1.0 if (not locked or fmod(age * 16.0, 1.0) < 0.6) else 0.3
		var o := global_position
		draw_line(_muzzle(7.0, -4.0) - o, aim_end - o, Color(1.0, 0.1, 0.1, 0.35 + 0.5 * a), 2.0 if locked else 1.0)
		draw_circle(aim_end - o, 2.5 if locked else 1.5, Color(1.0, 0.2, 0.1, a))
	# Warning mark while winding up (non-bosses)
	if state == "wind" and not is_boss and kind != "arrow_trap":
		var wy := -top - 4.0
		draw_rect(Rect2(-0.5, wy - 3.0, 1.0, 2.5), Color("ffb020"))
		draw_rect(Rect2(-0.5, wy, 1.0, 1.0), Color("ffb020"))
	# Stun stars
	if state == "stunned":
		for i in 3:
			var a2 := age * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a2) * 6.0, -top + sin(a2) * 2.0), 1.2, Color("ffe040"))
	# Frozen sparkles
	if freeze_t > 0.0:
		draw_rect(Rect2(-hw * sc - 1.0, -hh * sc, 2.0, 1.0), Color(0.9, 1.0, 1.0))
		draw_rect(Rect2(hw * sc - 1.0, hh * sc - 3.0, 1.0, 2.0), Color(0.9, 1.0, 1.0))
	# Shock zigzag
	if shock_t > 0.0:
		var p0 := Vector2(randf_range(-hw, hw), -hh)
		var p1 := p0 + Vector2(randf_range(-3.0, 3.0), 5.0)
		var p2 := p1 + Vector2(randf_range(-3.0, 3.0), 5.0)
		draw_polyline(PackedVector2Array([p0, p1, p2]), Color("fff060"), 1.0)
	# Boss HP bar
	if is_boss:
		var bw := hw * 2.0 * sc * 0.5 + 18.0
		var by2 := -top - 5.0
		draw_rect(Rect2(-bw * 0.5 - 1.0, by2 - 1.0, bw + 2.0, 5.0), NAVY)
		draw_rect(Rect2(-bw * 0.5, by2, bw, 3.0), Color("401018"))
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-bw * 0.5, by2, bw * frac, 3.0), Color("ff5030") if rage else Color("e03030"))
		draw_rect(Rect2(-bw * 0.5, by2, bw * frac, 1.0), Color(1.0, 1.0, 1.0, 0.35))
