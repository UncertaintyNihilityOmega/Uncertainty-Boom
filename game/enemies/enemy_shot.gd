class_name EnemyShot
extends Node2D
## Everything enemies throw or shoot: arrows, bolts, spears, bombs, cannonballs,
## boulders, magic orbs, ice shards, ballista bolts and ground shockwaves.
## Movement and hit detection are manual (no physics bodies).
##   var s := EnemyShot.new(); s.setup("arrow", world, vel, {"g": 300.0}); layer.add_child(s)
## Option keys (all optional, defaults per kind in DEFS):
##   r radius, g gravity, life seconds, boom explosion radius, fuse seconds,
##   homing turn rate (rad/s), dmg hearts, slow seconds (applied to the dragon)

const GRACE := 0.05  # ignore terrain right after spawning (muzzle may touch a wall)
const DEFS := {
	"arrow": {"r": 2.0, "g": 360.0, "life": 4.5},
	"bolt": {"r": 2.0, "g": 0.0, "life": 3.0},
	"spear": {"r": 3.0, "g": 240.0, "life": 4.0},
	"bomb": {"r": 5.0, "g": 620.0, "life": 4.0, "boom": 28.0, "fuse": 2.4},
	"cannonball": {"r": 4.0, "g": 320.0, "life": 5.0, "boom": 18.0},
	"boulder": {"r": 7.0, "g": 520.0, "life": 6.0, "boom": 32.0},
	"orb": {"r": 4.0, "g": 0.0, "life": 5.0, "homing": 1.6},
	"shard": {"r": 3.0, "g": 0.0, "life": 3.0, "slow": 2.2},
	"ballista": {"r": 4.0, "g": 0.0, "life": 2.5},
	"wave": {"r": 7.0, "g": 0.0, "life": 2.4},
}

var kind := "arrow"
var vel := Vector2.ZERO
var grav := 0.0
var radius := 2.0
var life := 4.0
var boom := 0.0
var fuse := 0.0
var homing := 0.0
var damage := 1
var slow := 0.0
var world  # untyped on purpose (duck typing)
var age := 0.0
var dead := false

var _trail := 0.0
var _spin := 0.0
var _wave_h := 16.0


func setup(kind_: String, world_, vel_: Vector2, opts := {}) -> void:
	kind = kind_
	world = world_
	vel = vel_
	var d: Dictionary = DEFS.get(kind, DEFS["arrow"])
	radius = opts.get("r", d.get("r", 2.0))
	grav = opts.get("g", d.get("g", 0.0))
	life = opts.get("life", d.get("life", 4.0))
	boom = opts.get("boom", d.get("boom", 0.0))
	fuse = opts.get("fuse", d.get("fuse", 0.0))
	homing = opts.get("homing", d.get("homing", 0.0))
	damage = int(opts.get("dmg", 1))
	slow = opts.get("slow", d.get("slow", 0.0))
	if kind == "ballista" or kind == "wave":
		set_meta("indestructible", true)
	if kind == "boulder":
		_spin = signf(vel.x if vel.x != 0.0 else 1.0) * 5.0
	add_to_group("enemy_shots")
	z_index = 5
	if kind != "bomb" and kind != "boulder" and kind != "cannonball" and kind != "wave":
		rotation = vel.angle()


# ---------------------------------------------------------------- update

func _physics_process(delta: float) -> void:
	if dead or world == null:
		return
	age += delta
	life -= delta
	if life <= 0.0:
		_expire()
		return
	if kind == "wave":
		_step_wave(delta)
		queue_redraw()
		return
	if fuse > 0.0:
		fuse -= delta
		if fuse <= 0.0:
			_explode(true)
			return
	var p = _player()
	if homing > 0.0 and p != null and age < 4.0:
		var want: float = (p.global_position - global_position).angle()
		var diff := wrapf(want - vel.angle(), -PI, PI)
		var turn := clampf(diff, -homing * delta, homing * delta)
		vel = vel.rotated(turn)
	vel.y += grav * delta
	var from := global_position
	var to := from + vel * delta
	# Terrain
	if age > GRACE:
		var hit := _first_solid(from, to)
		if hit != Vector2.INF:
			global_position = hit
			_impact(null)
			return
	# Player
	if p != null:
		var hr: float = p.HURT_RADIUS
		if _seg_dist(from, to, p.global_position) < hr + radius and not p.is_invulnerable():
			global_position = to
			_impact(p)
			return
	global_position = to
	if kind == "boulder" or kind == "bomb":
		rotation += _spin * delta
	elif kind != "cannonball":
		rotation = vel.angle()
	_trail -= delta
	if _trail <= 0.0:
		_trail = 0.06
		if kind == "cannonball" or kind == "boulder":
			_smoke(global_position, 1, 3.0)
	queue_redraw()


## Ground shockwave: hugs the terrain, hurts a dragon that is low to the ground.
func _step_wave(delta: float) -> void:
	var nx := global_position.x + vel.x * delta
	var gy: float = world.ground_y(nx, global_position.y - 12.0)
	if absf(gy - global_position.y) > 28.0:
		_expire()
		return
	var dirx := signf(vel.x)
	if world.is_solid(Vector2(nx + dirx * 6.0, gy - 5.0)):
		_expire()
		return
	global_position = Vector2(nx, gy - 1.0)
	_trail -= delta
	if _trail <= 0.0:
		_trail = 0.07
		_smoke(global_position, 1, 3.0)
	var p = _player()
	if p != null and not p.is_invulnerable():
		var pp: Vector2 = p.global_position
		var hr: float = p.HURT_RADIUS
		if absf(pp.x - global_position.x) < radius + hr * 0.6 and pp.y > global_position.y - _wave_h - hr and pp.y < global_position.y + 6.0:
			_impact(p)


func _first_solid(from: Vector2, to: Vector2) -> Vector2:
	var seg := to - from
	var n := maxi(1, int(ceilf(seg.length() / 3.0)))
	var prev := from
	for i in range(1, n + 1):
		var pt := from + seg * (float(i) / float(n))
		if world.is_solid(pt):
			return prev
		prev = pt
	return Vector2.INF


func _seg_dist(a: Vector2, b: Vector2, pt: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return a.distance_to(pt)
	var t := clampf((pt - a).dot(ab) / l2, 0.0, 1.0)
	return (a + ab * t).distance_to(pt)


func _player():
	if world == null:
		return null
	var p = world.get("player")
	if p == null or not is_instance_valid(p):
		return null
	if p.dead:
		return null
	return p


# ---------------------------------------------------------------- impact

## p is the dragon if it was hit, or null if we struck terrain.
func _impact(p) -> void:
	if dead:
		return
	if boom > 0.0:
		_explode(true)
		return
	dead = true
	if p != null:
		p.hurt(damage, global_position)
		if slow > 0.0:
			p.apply_slow(slow)
	if kind == "wave":
		pass
	elif p != null:
		_sparks(global_position, _color(), 5, 100.0)
	else:
		_sparks(global_position, _color(), 3, 70.0)
		if kind == "shard":
			Sfx.play("ice", 0.1, -8.0)
	queue_free()


func _expire() -> void:
	if dead:
		return
	if boom > 0.0:
		_explode(true)
		return
	dead = true
	queue_free()


func _explode(harm: bool) -> void:
	if dead:
		return
	dead = true
	var fx = world.get("fx")
	if fx != null:
		fx.explosion(global_position, boom, Color(1.0, 0.5, 0.1))
		fx.smoke(global_position, 2 if boom < 25.0 else 4, 5.0)
		if kind == "boulder":
			fx.debris(global_position, Color("8a8a9a"), 8)
		if boom >= 25.0:
			fx.shake(3.0 if kind == "bomb" else 5.0)
	Sfx.play("explode_small" if boom < 25.0 else "explode")
	if harm:
		var p = _player()
		if p != null and not p.is_invulnerable():
			var hr: float = p.HURT_RADIUS
			if p.global_position.distance_to(global_position) < boom + hr:
				p.hurt(damage, global_position)
	queue_free()


## Called by player shots / dash that hit this projectile.
func destroy() -> void:
	if dead:
		return
	if boom > 0.0:
		# Shot down in mid-air: detonates harmlessly.
		_explode(false)
		return
	dead = true
	_sparks(global_position, _color(), 4, 80.0)
	queue_free()


# ---------------------------------------------------------------- fx helpers

func _sparks(pos: Vector2, col: Color, n: int, spd: float) -> void:
	var fx = world.get("fx") if world != null else null
	if fx != null:
		fx.sparks(pos, col, n, spd)


func _smoke(pos: Vector2, n: int, size: float) -> void:
	var fx = world.get("fx") if world != null else null
	if fx != null:
		fx.smoke(pos, n, size)


func _color() -> Color:
	match kind:
		"orb": return Color("c070ff")
		"shard": return Color("80e0ff")
		"bomb", "cannonball", "boulder": return Color("ff8a20")
		"wave": return Color("d0b890")
	return Color("ffd060")


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	match kind:
		"arrow":
			draw_line(Vector2(-9, 0), Vector2(0, 0), Color("c89850"), 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -1.8), Vector2(3.5, 0), Vector2(0, 1.8)]), Color("e8f0ff"))
			draw_line(Vector2(-9, 0), Vector2(-11, -1.5), Color("ff8a20"), 1.0)
			draw_line(Vector2(-9, 0), Vector2(-11, 1.5), Color("ff8a20"), 1.0)
			# Long yellow streak like the reference volleys.
			draw_line(Vector2(-9, 0), Vector2(-20, 0), Color(1.0, 0.8, 0.2, 0.35), 1.0)
		"bolt":
			draw_line(Vector2(-6, 0), Vector2(1, 0), Color("a07040"), 1.5)
			draw_colored_polygon(PackedVector2Array([Vector2(1, -2), Vector2(5, 0), Vector2(1, 2)]), Color("e8f0ff"))
			draw_line(Vector2(-6, 0), Vector2(-16, 0), Color(1.0, 0.9, 0.4, 0.4), 1.0)
		"spear":
			draw_line(Vector2(-11, 0), Vector2(4, 0), Color("a07040"), 1.5)
			draw_colored_polygon(PackedVector2Array([Vector2(3, -2.5), Vector2(9, 0), Vector2(3, 2.5)]), Color("e8f0ff"))
			draw_rect(Rect2(2, -1, 1.5, 2), Color("ff8a20"))
		"bomb":
			var blink := 1.0 if fmod(age * (4.0 + maxf(0.0, 2.4 - fuse) * 4.0), 1.0) < 0.5 else 0.0
			draw_circle(Vector2.ZERO, 5.5, Color("101830"))
			draw_circle(Vector2.ZERO, 4.5, Color("ff8a20").lightened(blink * 0.35))
			draw_circle(Vector2(-1.5, -1.5), 1.5, Color("ffc070"))
			draw_rect(Rect2(-1, -7.5, 2, 3), Color("c8d0e0"))
			draw_circle(Vector2(0, -8), 1.4 + blink * 0.8, Color("ffe040"))
		"cannonball":
			draw_circle(Vector2.ZERO, 4.5, Color("101830"))
			draw_circle(Vector2.ZERO, 3.5, Color("4a5470"))
			draw_circle(Vector2(-1, -1), 1.2, Color("9aa4c0"))
		"boulder":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-7, -2), Vector2(-4, -6), Vector2(2, -7), Vector2(7, -3),
				Vector2(6, 3), Vector2(1, 7), Vector2(-5, 5)]), Color("101830"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5.5, -1.5), Vector2(-3, -5), Vector2(2, -5.5), Vector2(5.5, -2.5),
				Vector2(4.5, 2.5), Vector2(1, 5.5), Vector2(-4, 4)]), Color("8a8a9a"))
			draw_circle(Vector2(-1, -2), 1.8, Color("b4b4c4"))
		"orb":
			var pulse := 1.0 + sin(age * 14.0) * 0.25
			draw_circle(Vector2.ZERO, 6.0 * pulse, Color(0.75, 0.4, 1.0, 0.25))
			draw_circle(Vector2.ZERO, 4.0, Color("8a50d0"))
			draw_circle(Vector2.ZERO, 2.5, Color("e0a0ff"))
			draw_circle(Vector2(-0.5, -0.5), 1.0, Color.WHITE)
		"shard":
			draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(-1, -2.5), Vector2(6, 0), Vector2(-1, 2.5)]), Color("80e0ff"))
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(0, -1.2), Vector2(4, 0), Vector2(0, 1.2)]), Color("e0ffff"))
		"ballista":
			draw_line(Vector2(-16, 0), Vector2(6, 0), Color("6a4020"), 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -4), Vector2(13, 0), Vector2(5, 4)]), Color("e8f0ff"))
			draw_line(Vector2(-16, 0), Vector2(-20, -3), Color("d83030"), 1.5)
			draw_line(Vector2(-16, 0), Vector2(-20, 3), Color("d83030"), 1.5)
			draw_line(Vector2(-16, 0), Vector2(-34, 0), Color(1.0, 0.5, 0.2, 0.45), 2.0)
		"wave":
			# Jagged dust crest travelling along the floor.
			var d := signf(vel.x)
			var h := _wave_h * (0.75 + 0.25 * sin(age * 30.0))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-7 * d, 1), Vector2(-4 * d, -h * 0.4), Vector2(-1 * d, -h * 0.2),
				Vector2(3 * d, -h), Vector2(7 * d, 1)]), Color("d0b890"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4 * d, 1), Vector2(0, -h * 0.55), Vector2(4 * d, 1)]), Color("fff0c0"))
			draw_line(Vector2(-10 * d, 0), Vector2(10 * d, 0), Color("ff8a20"), 2.0)
