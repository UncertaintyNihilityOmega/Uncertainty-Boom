class_name Pickup
extends Node2D
## Coins, keys, hearts and the treasure chest.
## Placed pickups float in place until the dragon comes close; coins dropped by
## enemies pop out and then fly to the dragon on their own. Once a pickup starts
## homing it never gives up, however fast the dragon moves.

const CHEST_SCALE := 2.0

var kind := "coin"          # coin | key | heart | chest
var value := 1
var placed := false         # placed by the level (counts toward Treasure / Keys stars)
var locked := false         # chest stays locked while a boss lives
var homing := false
var world
var vel := Vector2.ZERO
var physics := false
var _t := 0.0
var _age := 0.0
var _home_speed := 0.0


func setup(kind_: String, world_, value_ := 1, placed_ := false) -> void:
	kind = kind_
	world = world_
	value = value_
	placed = placed_
	_t = randf() * TAU
	z_index = 5


func pop(velocity: Vector2) -> void:
	physics = true
	vel = velocity
	# Enemy drops come to the dragon by themselves.
	if kind == "coin":
		homing = true


func _physics_process(delta: float) -> void:
	_t += delta
	_age += delta
	var player = world.player
	if physics and (not homing or _age < 0.3):
		vel.y += 700.0 * delta
		var next := position + vel * delta
		if world.is_solid(next + Vector2(0, 3)):
			vel.y *= -0.35
			vel.x *= 0.7
			if absf(vel.y) < 30.0:
				vel = Vector2.ZERO
				physics = false
		else:
			position = next
		if position.y > world.kill_y and not homing:
			queue_free()
		queue_redraw()
		return
	if player == null or player.dead or locked:
		queue_redraw()
		return
	var to: Vector2 = player.global_position - global_position
	var dist := to.length()
	if kind == "chest":
		if dist < 12.0 * CHEST_SCALE + 6.0:
			world.collect_pickup(self)
			queue_free()
		queue_redraw()
		return
	if not homing and dist < (34.0 if placed else 70.0):
		homing = true
	if homing:
		physics = false
		_home_speed = maxf(_home_speed + 1400.0 * delta, 260.0)
		var chase: float = maxf(_home_speed, player.velocity.length() + 120.0)
		position += to.normalized() * minf(dist, chase * delta)
	if dist < 10.0:
		world.collect_pickup(self)
		queue_free()
	queue_redraw()


func _draw() -> void:
	var bob := 0.0 if physics else sin(_t * 3.0) * 1.5
	match kind:
		"coin":
			var w := absf(cos(_t * 4.0)) * 3.0 + 1.0
			draw_rect(Rect2(-w, -4 + bob, w * 2, 8), Color("f0a010"))
			draw_rect(Rect2(-w + 1, -3 + bob, maxf(w * 2 - 2, 1), 6), Color("ffd84a"))
		"key":
			draw_circle(Vector2(-3, bob), 3.0, Color("ffc830"))
			draw_circle(Vector2(-3, bob), 1.2, Color("2a1a08"))
			draw_rect(Rect2(-1, -1 + bob, 8, 2), Color("ffc830"))
			draw_rect(Rect2(4, bob, 2, 3), Color("ffc830"))
			draw_rect(Rect2(6, bob, 1, 2), Color("ffc830"))
		"heart":
			draw_circle(Vector2(-2, -1 + bob), 2.5, Color("ff3040"))
			draw_circle(Vector2(2, -1 + bob), 2.5, Color("ff3040"))
			draw_colored_polygon(PackedVector2Array([Vector2(-4.5, 0 + bob), Vector2(4.5, 0 + bob), Vector2(0, 5 + bob)]), Color("ff3040"))
		"chest":
			draw_set_transform(Vector2(0, 4), 0.0, Vector2.ONE * CHEST_SCALE)
			draw_rect(Rect2(-12, -10, 24, 14), Color("8a4a18"))
			draw_rect(Rect2(-12, -14, 24, 6), Color("a85a20"))
			draw_rect(Rect2(-12, -10, 24, 2), Color("f0c020"))
			draw_rect(Rect2(-2, -12, 4, 6), Color("f0c020") if not locked else Color("808890"))
			for i in 4:
				var sx := -10.0 + i * 6.5 + sin(_t * 2.0 + i) * 1.0
				draw_rect(Rect2(sx, -17 + sin(_t * 3.0 + i) * 1.5, 3, 3), Color("ffd84a"))
			if locked:
				draw_rect(Rect2(-4, -24, 8, 7), Color("808890"))
				draw_arc(Vector2(0, -24), 3.0, PI, TAU, 8, Color("808890"), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
