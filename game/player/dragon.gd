class_name Dragon
extends CharacterBody2D
## The player. Runs, jumps, chains unlimited dashes (slingshot), dives into ground slams,
## breathes fire with the equipped attack style and controls slow motion.

const HURT_RADIUS := 6.0
const MAX_HEARTS := 5
const GRAVITY := 900.0
const MAX_FALL := 520.0
const RUN_SPEED := 175.0
const AIR_ACCEL := 1100.0
const GROUND_ACCEL := 1400.0
const JUMP_VEL := -300.0
const MAX_FLAPS := 1
const DASH_SPEED := 560.0
const DASH_TIME := 0.17
const DASH_COOLDOWN := 0.07     # minimum gap between dashes; a dash can cancel a dash
const DASH_CARRY := 0.6         # share of dash speed kept after the dash ends
const DIVE_SPEED := 640.0
const SLIDE_SPEED := 430.0
const SLIDE_TIME := 0.38
const WATER_LIFT := 1500.0      # buoyancy (beats gravity) while submerged
const WATER_MAX_RISE := 150.0
const SLOWMO_SCALE := 0.25
const METER_MAX := 100.0
const METER_DRAIN := 5.4        # per real second (a full meter lasts ~18 s)
const METER_REGEN := 7.0        # per real second, after a pause
const METER_MIN_START := 10.0

var world
var hearts := MAX_HEARTS
var dead := false
var facing := 1
var attack: Dictionary
var skin := "ember"

var flaps := MAX_FLAPS
var meter := METER_MAX
var slowmo := false

var _invuln := 0.0
var _dash_t := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_hits := {}
var _diving := false
var _cooldown := 0.0
var _burst_left := 0
var _burst_t := 0.0
var _burst_dir := Vector2.RIGHT
var _spiral_angle := 0.0
var _slow_t := 0.0
var _regen_wait := 0.0
var _anim := 0.0
var _aiming_dash := false
var _hurt_flash := 0.0
var _last_safe := Vector2.ZERO
var _coyote := 0.0
var _dash_cd := 0.0
var _slide_t := 0.0
var _slide_dir := 1.0
var _slam_grace := 0.0
var _slowmo_toggled := false


func setup(world_) -> void:
	world = world_
	attack = AttackDB.get_attack(Game.equipped_attack())
	skin = Game.equipped_dragon()
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 10)
	shape.shape = rect
	shape.position = Vector2(0, 0)
	add_child(shape)
	z_index = 20
	_last_safe = position


func is_invulnerable() -> bool:
	# Dashing, sliding and smashing down through enemies never hurts the dragon.
	return _invuln > 0.0 or _dash_t > 0.0 or _slide_t > 0.0 or _diving or _slam_grace > 0.0 or dead


func apply_slow(seconds: float) -> void:
	_slow_t = maxf(_slow_t, seconds)


func hurt(amount: int, from: Vector2) -> void:
	if is_invulnerable() or world.finished:
		return
	hearts = maxi(0, hearts - amount)
	world.hearts_lost += amount
	_invuln = 1.2
	_hurt_flash = 0.3
	var away := (global_position - from).normalized()
	velocity = Vector2(away.x * 220.0, -200.0)
	world.fx.shake(5.0)
	world.fx.sparks(global_position, Color("ff4050"), 10, 140.0)
	Sfx.play("hurt")
	Game.stat_add("hits_taken")
	Events.player_hurt.emit(hearts)
	if hearts <= 0:
		_die()


func heal(amount: int) -> void:
	hearts = mini(MAX_HEARTS, hearts + amount)


func refill_meter(amount: float) -> void:
	meter = minf(METER_MAX, meter + amount)


func on_kill(_source: String) -> void:
	refill_meter(6.0)


func _die() -> void:
	dead = true
	_set_slowmo(false)
	world.fx.explosion(global_position, 26.0)
	world.fx.debris(global_position, DragonDB.colors(skin).body, 10)
	Sfx.play("die")
	Game.stat_add("deaths")
	world.on_player_died()
	visible = false


# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if dead or world.finished:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_anim += delta
	_invuln = maxf(0.0, _invuln - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - real_delta)
	_slow_t = maxf(0.0, _slow_t - delta)
	_slam_grace = maxf(0.0, _slam_grace - delta)
	_cooldown -= delta
	_dash_cd -= delta

	var kb_mode: bool = Game.get_setting("keyboard_mode") or Game.has_meta("autoplay")
	_update_slowmo(real_delta)
	_handle_move_input(kb_mode)
	if _dash_t > 0.0:
		_update_dash(delta)
	elif _slide_t > 0.0:
		_update_slide(delta)
	else:
		_update_movement(delta)
	_update_fire(delta, kb_mode)

	if position.y > world.kill_y:
		_fell_out()
	elif position.y < world.ceiling_y:
		position.y = world.ceiling_y
		velocity.y = maxf(velocity.y, 0.0)
	queue_redraw()


## E toggles slow motion on/off; holding right mouse also slows time while aiming.
func _update_slowmo(real_delta: float) -> void:
	if Input.is_action_just_pressed(&"slowmo_key"):
		_slowmo_toggled = not _slowmo_toggled and meter >= METER_MIN_START
		if not _slowmo_toggled and slowmo:
			_set_slowmo(false)
	var want := Input.is_action_pressed(&"aim_dash") or _slowmo_toggled
	_aiming_dash = Input.is_action_pressed(&"aim_dash")
	if Input.is_action_just_released(&"aim_dash"):
		_try_dash(_mouse_dir())
	if want and (slowmo or meter >= METER_MIN_START) and meter > 0.0:
		if not slowmo:
			_set_slowmo(true)
		meter -= METER_DRAIN * real_delta
		Game.data.stats["slowmo_seconds_f"] = float(Game.data.stats.get("slowmo_seconds_f", 0.0)) + real_delta
		if int(Game.data.stats.slowmo_seconds_f) > Game.get_stat("slowmo_seconds"):
			Game.stat_add("slowmo_seconds")
		_regen_wait = 1.0
		if meter <= 0.0:
			meter = 0.0
			_slowmo_toggled = false
			_set_slowmo(false)
	else:
		if slowmo:
			_set_slowmo(false)
		_regen_wait -= real_delta
		if _regen_wait <= 0.0:
			meter = minf(METER_MAX, meter + METER_REGEN * real_delta)


func _set_slowmo(on: bool) -> void:
	slowmo = on
	Sfx.play("slowmo_in" if on else "slowmo_out", 0.0, -4.0)
	world.target_time_scale = SLOWMO_SCALE if on else 1.0


## W / S combined with A / D always means "dash that way":
##   ground: W = jump, W+A/D = diagonal dash up, S (+A/D) = slide
##   air:    W (+A/D) = dash up / diagonal up, S+A/D = diagonal dash down, S = smash dive
## Shift dashes toward the cursor (or the WASD direction in keyboard-only mode).
## Every dash can be cancelled into a new dash at any moment (no dash limit).
func _handle_move_input(kb_mode: bool) -> void:
	var dir := Input.get_axis(&"move_left", &"move_right")
	var grounded := is_on_floor() or _coyote > 0.0
	if Input.is_action_just_pressed(&"dash"):
		var d: Vector2
		if kb_mode:
			d = Vector2(dir, Input.get_axis(&"jump", &"dive"))
			if d == Vector2.ZERO:
				d = Vector2(facing, 0)
		else:
			d = _mouse_dir()
		_try_dash(d)
	if Input.is_action_just_pressed(&"jump"):
		if grounded and dir == 0.0 and _dash_t <= 0.0:
			velocity.y = JUMP_VEL * (0.6 if _slow_t > 0.0 else 1.0)
			_coyote = 0.0
			_slide_t = 0.0
			Sfx.play("jump", 0.1, -6.0)
		else:
			_try_dash(Vector2(dir, -1.0))
	if Input.is_action_just_pressed(&"dive"):
		if grounded and _dash_t <= 0.0:
			_start_slide(dir if dir != 0.0 else float(facing))
		elif dir != 0.0:
			_try_dash(Vector2(dir, 1.0))
		elif not grounded:
			_dash_t = 0.0
			_diving = true
			velocity = Vector2(velocity.x * 0.4, DIVE_SPEED)
			Sfx.play("dash", 0.1, -8.0)


func _update_movement(delta: float) -> void:
	var dir := Input.get_axis(&"move_left", &"move_right")
	var speed_mult := 0.6 if _slow_t > 0.0 else 1.0
	var on_floor := is_on_floor()
	var in_water: bool = world.water_at(global_position)
	if on_floor:
		_coyote = 0.1
		if _diving:
			_slam()
		if world.is_solid(global_position + Vector2(0, 12)):
			_last_safe = global_position
	else:
		_coyote -= delta

	var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
	if in_water:
		accel *= 0.22  # slippery
	velocity.x = move_toward(velocity.x, dir * RUN_SPEED * speed_mult, accel * delta)
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1

	if in_water:
		# Buoyancy pushes the dragon back up to the surface.
		_diving = false
		velocity.y = maxf(velocity.y - WATER_LIFT * delta, -WATER_MAX_RISE)
		velocity *= 0.99
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, DIVE_SPEED if _diving else MAX_FALL)
	if _diving:
		_smash_check()
	move_and_slide()


## Diving onto an enemy smashes it right away instead of hurting the dragon.
func _smash_check() -> void:
	for e in world.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.y > -4.0 and to.length() < 10.0 + e.get_radius():
			_slam()
			return


func _start_slide(d: float) -> void:
	_slide_t = SLIDE_TIME
	_slide_dir = signf(d)
	facing = int(_slide_dir)
	_dash_hits.clear()
	velocity = Vector2(_slide_dir * SLIDE_SPEED, 0.0)
	Sfx.play("dash", 0.1, -6.0)
	world.fx.smoke(global_position + Vector2(-_slide_dir * 6.0, 6.0), 3, 3.0)


func _update_slide(delta: float) -> void:
	_slide_t -= delta
	var t := _slide_t / SLIDE_TIME
	velocity.x = _slide_dir * SLIDE_SPEED * (0.45 + 0.55 * t)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	if is_on_wall():
		_slide_t = 0.0
	if randf() < 0.5:
		world.fx.smoke(global_position + Vector2(-_slide_dir * 6.0, 6.0), 1, 2.0)
	_ram_enemies(Vector2(_slide_dir * 180.0, -300.0))


func _update_dash(delta: float) -> void:
	_dash_t -= delta
	velocity = _dash_dir * DASH_SPEED
	move_and_slide()
	world.fx.trail(global_position - _dash_dir * 6.0, DragonDB.colors(skin).trail, 3.0)
	_ram_enemies(Vector2(_dash_dir.x * 220.0, -260.0))
	if _dash_t <= 0.0:
		velocity = _dash_dir * DASH_SPEED * DASH_CARRY


func _ram_enemies(knock: Vector2) -> void:
	for e in world.enemies:
		if not is_instance_valid(e) or e.dead or _dash_hits.has(e.get_instance_id()):
			continue
		if e.global_position.distance_to(global_position) < 10.0 + e.get_radius():
			_dash_hits[e.get_instance_id()] = true
			world.damage_enemy(e, 3.0 * Game.power_mult(), knock, "", "dash")
			world.fx.explosion(e.global_position, 10.0)
			Sfx.play("hit")


func _try_dash(d: Vector2) -> void:
	if _dash_cd > 0.0 or d == Vector2.ZERO:
		return
	_dash_cd = DASH_COOLDOWN
	_dash_t = DASH_TIME
	_slide_t = 0.0
	_dash_dir = d.normalized()
	_dash_hits.clear()
	_diving = false
	facing = 1 if _dash_dir.x >= 0.0 else -1
	Sfx.play("dash")
	Game.stat_add("dashes")
	world.fx.ring(global_position, 14.0, DragonDB.colors(skin).trail)


func _slam() -> void:
	_diving = false
	_slam_grace = 0.4
	velocity.y = -120.0
	world.explode_at(global_position + Vector2(0, 4), 40.0, 3.0 * Game.power_mult(), "", Color("ffa030"), "slam")
	world.fx.shake(6.0)
	Sfx.play("slam")


func _fell_out() -> void:
	hurt(1, global_position + Vector2(0, 50))
	if dead:
		return
	global_position = _last_safe + Vector2(0, -30)
	velocity = Vector2.ZERO
	_invuln = 1.5


# ------------------------------------------------------------------ attacking

func _mouse_dir() -> Vector2:
	var d := get_global_mouse_position() - global_position
	return d.normalized() if d.length() > 1.0 else Vector2(facing, 0)


func _update_fire(delta: float, kb_mode: bool) -> void:
	if _burst_left > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst_left -= 1
			_burst_t = attack.burst_gap
			_fire_volley(_burst_dir)
	var dir := Vector2.ZERO
	if Input.is_action_pressed(&"fire"):
		dir = _mouse_dir()
	elif Input.is_action_pressed(&"auto_attack"):
		var target = world.nearest_enemy(global_position, 420.0)
		dir = (target.global_position - global_position).normalized() if target else Vector2(facing, 0)
	if dir == Vector2.ZERO or _cooldown > 0.0 or _burst_left > 0:
		return
	_cooldown = attack.cd
	facing = 1 if dir.x >= 0.0 else -1
	Game.stat_add("shots_fired")
	Sfx.play(attack.sound, 0.1, -4.0)
	if attack.pattern == "chain":
		world.chain_lightning(global_position, dir, attack)
		return
	_burst_dir = dir
	_burst_left = attack.burst - 1
	_burst_t = attack.burst_gap
	_fire_volley(dir)


func _fire_volley(dir: Vector2) -> void:
	var a := attack
	var origin := global_position + Vector2(facing * 10.0, -5.0)
	var n: int = a.count
	match a.pattern:
		"ring":
			for i in n:
				_spawn(a, origin, Vector2.from_angle(TAU * i / n + dir.angle()))
		"back":
			for d in [dir, -dir]:
				for i in n / 2:
					_spawn(a, origin, d.rotated(_fan_angle(i, n / 2, a.spread)))
		"wall":
			var side := dir.orthogonal()
			for i in n:
				_spawn(a, origin + side * (i - (n - 1) / 2.0) * 7.0, dir)
		"spiral":
			_spiral_angle += 0.55
			for i in n:
				_spawn(a, origin, Vector2.from_angle(_spiral_angle + TAU * i / n))
		"twin_wave":
			_spawn(a, origin, dir, {"phase": 0.0})
			_spawn(a, origin, dir, {"phase": PI})
		"rain":
			# A storm cloud gathers above the dragon and rains on the target.
			var target := global_position + dir * 160.0
			if Input.is_action_pressed(&"fire") and not Game.get_setting("keyboard_mode"):
				target = get_global_mouse_position()
			else:
				var e = world.nearest_enemy(global_position, 420.0)
				if e:
					target = e.global_position
			var cloud := RainCloud.new()
			cloud.setup(world, a, target, n)
			cloud.global_position = global_position + Vector2(0, -40)
			world.shots_layer.add_child(cloud)
		"orbit":
			for i in n:
				_spawn(a, global_position, dir, {"orbit_index": i, "orbit_total": n})
		_:
			for i in n:
				var d := dir.rotated(_fan_angle(i, n, a.spread))
				if a.jitter > 0.0:
					d = d.rotated(randf_range(-a.jitter, a.jitter))
				_spawn(a, origin, d)
	world.fx.sparks(origin, a.color, 3, 60.0)


func _fan_angle(i: int, n: int, spread: float) -> float:
	if n <= 1:
		return 0.0
	return deg_to_rad(-spread / 2.0 + spread * i / (n - 1))


func _spawn(a: Dictionary, pos: Vector2, dir: Vector2, opts := {}) -> void:
	var s := PlayerShot.new()
	s.setup(a, world, pos, dir, opts)
	world.shots_layer.add_child(s)


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if dead:
		return
	if _invuln > 0.0 and fmod(_invuln * 12.0, 1.0) < 0.4:
		return
	var pose := "fly"
	var rot := 0.0
	if _dash_t > 0.0:
		pose = "dash"
		rot = _dash_dir.angle() + (PI if facing < 0 else 0.0)
	elif _slide_t > 0.0:
		pose = "dash"
		rot = 0.15 * facing
	elif is_on_floor() and absf(velocity.x) < 10.0:
		pose = "idle"
	else:
		rot = clampf(velocity.y * 0.0012, -0.45, 0.45) * facing
	var tint := Color(0.7, 0.85, 1.4) if _slow_t > 0.0 else Color.WHITE
	if _hurt_flash > 0.0:
		tint = Color(2, 0.6, 0.6)
	DragonArt.draw(self, Vector2.ZERO, skin, facing, _anim, 1.0, pose, rot, tint)
	# Aim indicators while in slow motion
	if slowmo or _aiming_dash:
		var md := _mouse_dir()
		if _aiming_dash:
			_draw_aim(md, Color("40e0ff"), 46.0)
		if Input.is_action_pressed(&"fire"):
			_draw_aim(md, Color("ff6080"), 30.0)


func _draw_aim(d: Vector2, col: Color, length: float) -> void:
	var steps := int(length / 6.0)
	for i in range(1, steps):
		draw_circle(d * i * 6.0, 1.0, col)
	var tip := d * length
	draw_colored_polygon(PackedVector2Array([tip + d * 5.0, tip + d.orthogonal() * 3.0, tip - d.orthogonal() * 3.0]), col)
