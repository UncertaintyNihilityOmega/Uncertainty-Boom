class_name RainCloud
extends Node2D
## Storm cloud that gathers above the dragon and rains a "rain" pattern
## attack onto a target point. Works anywhere, including low dungeon ceilings.

const SPAWN_TIME := 0.45
const LINGER := 0.5

var world
var attack: Dictionary
var target := Vector2.ZERO
var _left := 0
var _gap := 0.05
var _t := 0.0
var _age := 0.0


func setup(world_, a: Dictionary, target_: Vector2, count: int) -> void:
	world = world_
	attack = a
	target = target_
	_left = count
	_gap = SPAWN_TIME / maxf(1.0, count)
	z_index = 15


func _physics_process(delta: float) -> void:
	_age += delta
	_t += delta
	if world.player and not world.player.dead:
		global_position = global_position.lerp(_anchor(world.player.global_position), 0.35)
	while _left > 0 and _t >= _gap:
		_t -= _gap
		_left -= 1
		_drop()
	if _left == 0 and _age > SPAWN_TIME + LINGER:
		queue_free()
	queue_redraw()


## Above the dragon, but never inside a ceiling or above the visible screen.
func _anchor(p: Vector2) -> Vector2:
	var pos := p + Vector2(0, -44)
	pos.y = maxf(pos.y, world.view_rect().position.y + 22.0)
	for i in 6:
		if not world.is_solid(pos):
			break
		pos.y += 8.0
	return pos


func _drop() -> void:
	var start := global_position + Vector2(randf_range(-18.0, 18.0), 5.0)
	var aim := target + Vector2(randf_range(-26.0, 26.0), randf_range(-6.0, 6.0))
	var s := PlayerShot.new()
	s.setup(attack, world, start, (aim - start).normalized())
	world.shots_layer.add_child(s)


func _draw() -> void:
	var fade := clampf(minf(_age * 6.0, (SPAWN_TIME + LINGER - _age) * 4.0 + 0.2), 0.0, 1.0)
	var dark := Color(0.16, 0.18, 0.28, 0.9 * fade)
	var light := Color(0.42, 0.46, 0.6, 0.9 * fade)
	for p in [Vector2(-14, 0), Vector2(-5, -5), Vector2(6, -4), Vector2(14, 1), Vector2(0, 2)]:
		draw_circle(p, 8.0, dark)
	for p in [Vector2(-9, -3), Vector2(3, -7), Vector2(11, -2)]:
		draw_circle(p, 4.5, light)
	if fmod(_age * 7.0, 1.0) < 0.15 and _left > 0:
		draw_line(Vector2(-3, 6), Vector2(1, 11), Color(attack.color, fade), 1.0)
		draw_line(Vector2(1, 11), Vector2(-2, 16), Color(attack.color, fade), 1.0)
