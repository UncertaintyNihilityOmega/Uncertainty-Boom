class_name PlayerShot
extends Node2D
## One projectile fired by the dragon. Behaviour comes entirely from the
## attack dictionary (see AttackDB). Hit detection is manual: distance to
## enemies, point tests against the terrain.

var a: Dictionary           # attack definition
var world
var vel := Vector2.ZERO
var dmg := 1.0
var life := 1.0
var pierce_left := 0
var bounces_left := 0
var is_fragment := false
var wave_phase := 0.0
var orbit_index := 0
var orbit_total := 1
var _base_dir := Vector2.RIGHT
var _age := 0.0
var _hit_ids := {}           # instance_id -> time of last hit (orbit re-hits)
var _trail: Array[Vector2] = []
var _wave_offset := Vector2.ZERO
var _returning := false
var _armed := false


func setup(attack: Dictionary, world_, pos: Vector2, dir: Vector2, opts := {}) -> void:
	a = attack
	world = world_
	position = pos
	_base_dir = dir.normalized()
	vel = _base_dir * a.speed
	life = a.life
	dmg = a.dmg * Game.power_mult()
	pierce_left = a.pierce
	bounces_left = a.bounce
	wave_phase = opts.get("phase", 0.0)
	orbit_index = opts.get("orbit_index", 0)
	orbit_total = opts.get("orbit_total", 1)
	is_fragment = opts.get("fragment", false)
	if is_fragment:
		dmg *= 0.5
		life = 0.35
	z_index = 10


func _physics_process(delta: float) -> void:
	_age += delta
	life -= delta
	if life <= 0.0:
		if a.explode > 0.0 and a.pattern == "mine":
			_explode()
		_die(false)
		return
	_trail.push_front(position)
	if _trail.size() > 5:
		_trail.pop_back()

	match a.pattern:
		"orbit":
			_move_orbit(delta)
		"mine":
			_move_mine(delta)
		_:
			_move_free(delta)

	if _check_enemies():
		return
	_check_enemy_shots()
	if a.pattern != "orbit" and not a.phase and world.is_solid(position):
		_hit_terrain()
	elif position.y > world.kill_y:
		queue_free()
	queue_redraw()


func _move_free(delta: float) -> void:
	if a.accel > 0.0:
		vel += vel.normalized() * a.accel * delta
	if a.gravity > 0.0:
		vel.y += a.gravity * delta
	if a.homing > 0.0 and _age > 0.08:
		var target = _nearest_enemy(260.0)
		if target:
			var want: Vector2 = (target.global_position - global_position).normalized()
			var angle := vel.angle()
			var diff := wrapf(want.angle() - angle, -PI, PI)
			angle += clampf(diff, -a.homing * delta, a.homing * delta)
			vel = Vector2.from_angle(angle) * vel.length()
	if a.boomerang:
		if not _returning and _age > a.life * 0.45:
			_returning = true
		if _returning and world.player:
			var back: Vector2 = (world.player.global_position - global_position)
			vel = vel.lerp(back.normalized() * a.speed * 1.2, 6.0 * delta)
			if back.length() < 10.0:
				queue_free()
				return
	position += vel * delta
	if a.wave > 0.0:
		var side := vel.normalized().orthogonal()
		var new_off: Vector2 = side * sin(_age * 14.0 + wave_phase) * a.wave
		position += new_off - _wave_offset
		_wave_offset = new_off


func _move_orbit(delta: float) -> void:
	if world.player == null:
		queue_free()
		return
	var ang := _age * 5.0 + TAU * orbit_index / float(orbit_total)
	position = world.player.global_position + Vector2.from_angle(ang) * (22.0 + sin(_age * 3.0) * 3.0)


func _move_mine(delta: float) -> void:
	if not _armed:
		vel = vel.move_toward(Vector2.ZERO, 900.0 * delta)
		vel.y += 300.0 * delta
		position += vel * delta
		if vel.length() < 20.0 or _age > 0.35:
			_armed = true
	else:
		for e in world.enemies:
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) < 22.0 + e.get_radius():
				_explode()
				queue_free()
				return


func _check_enemies() -> bool:
	if a.pattern == "mine":
		return false
	var r: float = a.size
	for e in world.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if e.global_position.distance_to(global_position) > r + e.get_radius():
			continue
		var id: int = e.get_instance_id()
		if _hit_ids.has(id):
			if a.pattern != "orbit" or _age - float(_hit_ids[id]) < 0.35:
				continue
		_hit_ids[id] = _age
		var knock_dir: Vector2 = vel.normalized() if vel.length() > 1.0 else (e.global_position - global_position).normalized()
		var knock := Vector2(knock_dir.x * a.knock * 0.6, -a.knock)
		# Piercing shots go straight through shields too.
		world.damage_enemy(e, dmg, knock, a.effect, "pierce" if a.pierce > 0 else "shot")
		Sfx.play("hit", 0.15, -6.0)
		world.fx.sparks(global_position, a.color, 4, 90.0)
		if a.pattern == "orbit" or a.boomerang:
			continue
		if a.explode > 0.0:
			_explode()
		if a.split > 0 and not is_fragment:
			_split()
		if pierce_left > 0:
			pierce_left -= 1
			continue
		_die(true)
		return true
	return false


func _check_enemy_shots() -> void:
	if a.size < 2.0:
		return
	for s in get_tree().get_nodes_in_group("enemy_shots"):
		if s.has_meta("indestructible"):
			continue
		if s.global_position.distance_to(global_position) < a.size + 4.0:
			s.destroy()
			Game.stat_add("shots_destroyed")


func _hit_terrain() -> void:
	if bounces_left > 0:
		bounces_left -= 1
		position -= vel.normalized() * 3.0
		var nx: bool = world.is_solid(position + Vector2(signf(vel.x) * 4.0, 0))
		var ny: bool = world.is_solid(position + Vector2(0, signf(vel.y) * 4.0))
		if nx:
			vel.x = -vel.x * 0.9
		if ny or not nx:
			vel.y = -vel.y * 0.8
		Sfx.play("block", 0.2, -10.0)
		return
	if a.pattern == "mine":
		vel = Vector2.ZERO
		_armed = true
		position -= Vector2(0, 2)
		return
	if a.explode > 0.0:
		_explode()
	if a.split > 0 and not is_fragment:
		_split()
	_die(true)


func _explode() -> void:
	var radius: float = a.explode * (0.6 if is_fragment else 1.0)
	world.explode_at(global_position, radius, dmg, a.effect, a.color)


func _split() -> void:
	for i in a.split:
		var dir := Vector2.from_angle(TAU * i / float(a.split) + randf() * 0.3)
		var frag := PlayerShot.new()
		var fa: Dictionary = a.duplicate()
		fa.split = 0
		fa.gravity = 300.0
		fa.homing = 0.0
		fa.size = 2.0
		fa.explode = a.explode * 0.5
		fa.speed = 240.0
		fa.pattern = ""
		frag.setup(fa, world, global_position, dir, {"fragment": true})
		world.shots_layer.add_child.call_deferred(frag)


func _die(impact: bool) -> void:
	if impact:
		world.fx.sparks(global_position, a.color, 3, 60.0)
		world.fx.smoke(global_position, 1, a.size)
	queue_free()


func _nearest_enemy(max_dist: float):
	var best = null
	var best_d := max_dist
	for e in world.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _draw() -> void:
	var col: Color = a.color
	var r: float = a.size
	# Trail (in local space)
	for i in _trail.size():
		var p: Vector2 = _trail[i] - position
		var t := 1.0 - float(i) / _trail.size()
		draw_circle(p, maxf(0.5, r * 0.8 * t), Color(col, 0.5 * t))
	match a.shape:
		"bolt":
			var d := vel.normalized() * maxf(6.0, r * 4.0)
			draw_line(-d, Vector2.ZERO, col, maxf(1.0, r))
			draw_line(-d * 0.5, Vector2.ZERO, Color.WHITE, maxf(1.0, r * 0.5))
		"comet":
			var d := -vel.normalized() * r * 3.0
			draw_colored_polygon(PackedVector2Array([d, vel.normalized().orthogonal() * r, -vel.normalized().orthogonal() * r]), Color(col, 0.7))
			draw_circle(Vector2.ZERO, r, col)
			draw_circle(Vector2(-r * 0.2, -r * 0.2), r * 0.5, col.lightened(0.6))
		"bomb":
			draw_circle(Vector2.ZERO, r + 1.0, Color(col, 0.4))
			draw_circle(Vector2.ZERO, r, col.darkened(0.3))
			draw_circle(Vector2(-1, -1), r * 0.5, col.lightened(0.4))
		"ring":
			draw_arc(Vector2.ZERO, r + 1.0, 0, TAU, 12, col, 2.0)
			draw_arc(Vector2.ZERO, r - 1.0, _age * 20.0, _age * 20.0 + PI, 8, Color.WHITE, 1.0)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var rr := r + 1.5 if i % 2 == 0 else r * 0.5
				pts.append(Vector2.from_angle(_age * 8.0 + i * TAU / 10.0) * rr)
			draw_colored_polygon(pts, col)
		_:
			draw_circle(Vector2.ZERO, r, col)
			draw_circle(Vector2.ZERO, r * 0.55, col.lightened(0.6))
	if a.pattern == "mine" and _armed:
		var blink := 1.0 if fmod(_age * 4.0, 1.0) < 0.5 else 0.3
		draw_circle(Vector2(0, -r - 1), 1.0, Color(1, 0.2, 0.1, blink))
