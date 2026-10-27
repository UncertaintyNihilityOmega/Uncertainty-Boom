class_name Fx
extends Node2D
## All transient visual effects of a level, simulated as plain data and drawn
## in a single _draw call. Slows down with Engine.time_scale like everything else.

const MAX_PARTICLES := 1800
const FIRE_COLORS := [Color("ffe070"), Color("ffa030"), Color("ff6020"), Color("e83018")]

enum { CIRCLE, SMOKE, SPARK, TEXT, RING, LINE, DEBRIS, FLASH }

## Each particle: [type, pos, vel, life, max_life, size, color, gravity, extra]
var _parts: Array = []
var trauma := 0.0
var _font: Font


func _ready() -> void:
	z_index = 50
	_font = ThemeDB.fallback_font


func _add(type: int, pos: Vector2, vel: Vector2, life: float, size: float, color: Color, gravity := 0.0, extra = null) -> void:
	if _parts.size() >= MAX_PARTICLES:
		_parts.pop_front()
	_parts.append([type, pos, vel, life, life, size, color, gravity, extra])


func explosion(pos: Vector2, radius := 16.0, color := Color(1, 0.5, 0.1)) -> void:
	var n := clampi(int(radius / 3.0), 4, 22)
	_add(FLASH, pos, Vector2.ZERO, 0.08, radius * 1.1, Color(1, 0.95, 0.7))
	for i in n:
		var a := randf() * TAU
		var d := randf() * radius * 0.6
		var c: Color = FIRE_COLORS[randi() % FIRE_COLORS.size()].lerp(color, 0.35)
		_add(CIRCLE, pos + Vector2.from_angle(a) * d, Vector2.from_angle(a) * randf_range(20, 60) + Vector2(0, -20),
			randf_range(0.25, 0.5), randf_range(radius * 0.25, radius * 0.55), c)
	smoke(pos, maxi(2, n / 3), radius * 0.35)
	sparks(pos, Color("ffe070"), n, radius * 9.0)
	shake(clampf(radius / 12.0, 0.6, 6.0))


func sparks(pos: Vector2, color: Color, count := 6, speed := 120.0) -> void:
	for i in count:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.4, speed)
		_add(SPARK, pos, v, randf_range(0.15, 0.4), 1.0, color, 200.0)


func smoke(pos: Vector2, count := 3, size := 6.0) -> void:
	for i in count:
		_add(SMOKE, pos + Vector2(randf_range(-size, size), randf_range(-size, size)),
			Vector2(randf_range(-10, 10), randf_range(-25, -8)), randf_range(0.7, 1.3), size * randf_range(0.7, 1.3), Color(0.02, 0.02, 0.05))


func popup(pos: Vector2, text: String, color := Color.WHITE) -> void:
	_add(TEXT, pos + Vector2(randf_range(-4, 4), 0), Vector2(0, -40), 0.8, 12.0, color, 0.0, text)


func big_popup(pos: Vector2, text: String, color := Color.WHITE, size := 20.0) -> void:
	_add(TEXT, pos, Vector2(0, -25), 1.0, size, color, 0.0, text)


func ring(pos: Vector2, radius: float, color: Color) -> void:
	_add(RING, pos, Vector2.ZERO, 0.3, radius, color)


func line(a: Vector2, b: Vector2, color: Color, width := 2.0, life := 0.15) -> void:
	_add(LINE, a, Vector2.ZERO, life, width, color, 0.0, b)


func debris(pos: Vector2, color: Color, count := 6) -> void:
	for i in count:
		var v := Vector2(randf_range(-90, 90), randf_range(-220, -80))
		_add(DEBRIS, pos, v, randf_range(0.6, 1.1), randf_range(1.5, 3.0), color, 700.0)


func trail(pos: Vector2, color: Color, size := 2.0) -> void:
	_add(CIRCLE, pos, Vector2(randf_range(-8, 8), randf_range(-8, 8)), 0.25, size, color)


func shake(strength: float) -> void:
	if Game.get_setting("screen_shake"):
		trauma = minf(trauma + strength, 10.0)


func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 18.0)
	var i := _parts.size() - 1
	while i >= 0:
		var p: Array = _parts[i]
		p[3] -= delta
		if p[3] <= 0.0:
			_parts.remove_at(i)
		else:
			p[2].y += p[7] * delta
			if p[0] == SMOKE or p[0] == CIRCLE:
				p[2] *= 0.94
			p[1] += p[2] * delta
		i -= 1
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var t: float = p[3] / p[4]  # 1 → 0
		var pos: Vector2 = p[1]
		var col: Color = p[6]
		match p[0]:
			CIRCLE:
				draw_circle(pos, maxf(0.5, p[5] * (0.4 + 0.6 * t)), col)
			FLASH:
				draw_circle(pos, p[5] * (1.0 - t * 0.3), Color(col, t))
			SMOKE:
				draw_circle(pos, p[5] * (0.3 + 0.7 * t), Color(col, minf(1.0, t * 2.0)))
			SPARK:
				var tail: Vector2 = p[2] * 0.03
				draw_line(pos - tail, pos, Color(col, t), 1.0)
			TEXT:
				var size := int(p[5])
				var s: String = p[8]
				var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				var a := minf(1.0, t * 3.0)
				draw_string_outline(_font, pos - Vector2(w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.05, 0.05, 0.1, a))
				draw_string(_font, pos - Vector2(w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, a))
			RING:
				draw_arc(pos, p[5] * (1.0 - t * 0.8), 0, TAU, 24, Color(col, t), 2.0)
			LINE:
				draw_line(pos, p[8], Color(col, t), p[5])
			DEBRIS:
				draw_rect(Rect2(pos - Vector2.ONE * p[5] / 2, Vector2.ONE * p[5]), col)
