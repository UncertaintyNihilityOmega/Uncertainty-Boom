class_name AttackIcon
extends Control
## Draws the projectile pattern of an attack style (fan, ring, rain, wave, orbit, chain...).
## Shots travel left to right from the dragon at the left edge, like the Hangar reference.

var attack: Dictionary = {}
## Darken the shot colours (used on the bright yellow "equipped" tile).
var darken := false

const DARK := Color(0.02, 0.05, 0.12, 0.7)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(40, 28)


func set_attack(id: String) -> void:
	attack = AttackDB.get_attack(id)
	queue_redraw()


func set_darken(value: bool) -> void:
	darken = value
	queue_redraw()


func _col() -> Color:
	var c: Color = attack.color
	return c.darkened(0.35) if darken else c


func _draw() -> void:
	if attack.is_empty():
		return
	var s := minf(size.x, size.y) / 34.0
	draw_set_transform(size * 0.5, 0.0, Vector2(s, s))
	var pattern: String = attack.pattern
	var col := _col()
	var origin := Vector2(-15, 0)
	match pattern:
		"ring":
			_pattern_ring(col)
		"back":
			_pattern_back(col)
		"wall":
			_pattern_wall(col)
		"spiral":
			_pattern_spiral(col)
		"twin_wave":
			_pattern_twin_wave(col, origin)
		"rain":
			_pattern_rain(col)
		"orbit":
			_pattern_orbit(col)
		"mine":
			_pattern_mine(col)
		"chain":
			_pattern_chain(col, origin)
		_:
			_pattern_forward(col, origin)
	_draw_effect_badge()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- shot pieces

func _radius() -> float:
	return clampf(float(attack.size) * 0.4 + 1.2, 1.6, 5.0)


## A projectile head at p travelling along `angle`.
func _head(p: Vector2, angle: float, col: Color, r := -1.0) -> void:
	if r < 0.0:
		r = _radius()
	var dir := Vector2.from_angle(angle)
	match String(attack.shape):
		"comet":
			draw_colored_polygon(PackedVector2Array([p - dir * r * 3.2, p + dir.orthogonal() * r * 0.9, p - dir.orthogonal() * r * 0.9]), Color(col.r, col.g, col.b, 0.55))
			draw_circle(p, r + 1.0, DARK)
			draw_circle(p, r, col)
			draw_circle(p, r * 0.45, Color(1, 1, 0.85))
		"bolt":
			var a := p - dir * r * 2.6
			draw_line(a, p, DARK, r * 1.2 + 2.0)
			draw_line(a, p, col, r * 1.2)
			draw_circle(p, r * 0.8, Color(1, 1, 1, 0.9))
		"bomb":
			draw_circle(p, r + 1.2, DARK)
			draw_circle(p, r + 0.2, Color("3a3040"))
			draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.45, col)
			draw_circle(p - dir.orthogonal() * (r + 0.5), 1.0, Color("ffe060"))
		"star":
			draw_colored_polygon(UIKit.star_points(p, r + 2.4), DARK)
			draw_colored_polygon(UIKit.star_points(p, r + 1.6), col)
		"ring":
			draw_arc(p, r + 1.0, 0, TAU, 12, DARK, 3.4)
			draw_arc(p, r + 1.0, 0, TAU, 12, col, 1.8)
		_:
			draw_circle(p, r + 1.0, DARK)
			draw_circle(p, r, col)
			draw_circle(p + Vector2(-r * 0.25, -r * 0.25), r * 0.4, col.lightened(0.5))


func _trail(a: Vector2, b: Vector2, col: Color, width := 1.6) -> void:
	draw_line(a, b, Color(0, 0, 0, 0.35), width + 1.6)
	draw_line(a, b, Color(col.r, col.g, col.b, 0.75), width)


func _path(points: PackedVector2Array, col: Color) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, Color(0, 0, 0, 0.35), 3.2)
	draw_polyline(points, Color(col.r, col.g, col.b, 0.75), 1.6)


func _explode_ring(p: Vector2, col: Color) -> void:
	var ex := float(attack.explode)
	if ex <= 0.0:
		return
	var rr := 3.5 + ex / 7.0
	draw_arc(p, rr, 0, TAU, 14, DARK, 3.0)
	draw_arc(p, rr, 0, TAU, 14, Color(1, 0.85, 0.3) if not darken else Color(0.8, 0.3, 0.0), 1.4)


func _split_fork(p: Vector2, col: Color) -> void:
	if int(attack.split) <= 0:
		return
	for a in [-0.7, 0.0, 0.7]:
		var q := p + Vector2.from_angle(a) * 7.0
		_trail(p, q, col, 1.2)
		draw_circle(q, 1.4, col)


func _enemy_ring(p: Vector2) -> void:
	draw_arc(p, 3.2, 0, TAU, 10, Color(1, 1, 1, 0.55), 1.0)


# ---------------------------------------------------------------- patterns

func _pattern_forward(col: Color, origin: Vector2) -> void:
	_dragon_marker(origin)
	var count := int(attack.count)
	var burst := int(attack.burst)
	var gravity := float(attack.gravity)
	var wave := float(attack.wave)
	var homing := float(attack.homing)
	var bounce := int(attack.bounce)
	var spread := minf(float(attack.spread), 90.0)
	if bool(attack.boomerang):
		var pts := PackedVector2Array()
		for i in 25:
			var a := float(i) / 24.0 * TAU
			pts.append(Vector2(-1 + cos(a) * 14.0, sin(a) * 8.0))
		_path(pts, col)
		_head(Vector2(13, 0), PI * 0.5, col)
		return
	if gravity > 0.0:
		var arcs := clampi(maxi(count, burst), 1, 3)
		for k in arcs:
			var h := 10.0 + (k - (arcs - 1) * 0.5) * 7.0
			var drop := 14.0 + (k - (arcs - 1) * 0.5) * 8.0
			var pts := PackedVector2Array()
			for i in 15:
				var t := float(i) / 14.0
				pts.append(Vector2(origin.x + 30.0 * t, origin.y - 4.0 - 4.0 * h * t * (1.0 - t) * 1.0 + drop * t))
			_path(pts, col)
			var tail := pts[pts.size() - 1]
			_head(tail, 1.0, col)
			if k == arcs - 1 or arcs == 1:
				_explode_ring(tail, col)
				_split_fork(tail, col)
		return
	if wave > 0.0:
		var pts := PackedVector2Array()
		for i in 21:
			var x := origin.x + 29.0 * float(i) / 20.0
			pts.append(Vector2(x, sin(float(i) * 0.65) * 5.5))
		_path(pts, col)
		_head(pts[pts.size() - 1], 0.0, col)
		return
	if bounce > 0:
		var pts := PackedVector2Array()
		for i in 25:
			var x := origin.x + 30.0 * float(i) / 24.0
			pts.append(Vector2(x, 11.0 - absf(sin(float(i) * 0.4)) * 20.0))
		_path(pts, col)
		_head(pts[pts.size() - 1], 0.5, col)
		return
	if homing > 0.0:
		var curves := clampi(count, 1, 3)
		for k in curves:
			var ctrl := Vector2(-2, -16 + k * 14)
			var tgt := Vector2(14, -8 + k * 8)
			var pts := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				pts.append(origin.lerp(ctrl, t).lerp(ctrl.lerp(tgt, t), t))
			_path(pts, col)
			_head(pts[pts.size() - 2], 0.3, col, _radius() * 0.8 if curves > 1 else _radius())
			draw_arc(tgt + Vector2(3, 0), 2.4, 0, TAU, 8, Color(1, 1, 1, 0.5), 1.0)
		if float(attack.explode) > 0.0:
			_explode_ring(Vector2(14, 0), col)
		return
	# Straight fan (or single / burst line).
	var n := clampi(count, 1, 7)
	var length := 28.0
	for i in n:
		var a := 0.0
		if n > 1:
			a = deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, float(i) / (n - 1)))
		var dir := Vector2.from_angle(a)
		var tip := origin + dir * length
		if float(attack.jitter) > 0.0 and n > 1:
			tip += dir.orthogonal() * (-1.5 + float(i % 3) * 1.5)
		_trail(origin + dir * 4.0, tip, col)
		if burst > 1:
			for b in burst:
				_head(origin + dir * (length - b * 9.0), a, col, _radius() * 0.85)
		else:
			_head(tip, a, col, _radius() * (0.8 if n > 3 else 1.0))
		if int(attack.pierce) > 0 and n == 1:
			_enemy_ring(origin + dir * 14.0)
			_enemy_ring(origin + dir * 24.0)
		if i == n - 1 or n == 1:
			_explode_ring(tip, col)
			_split_fork(tip, col)
	if float(attack.accel) > 0.0:
		for k in 3:
			_trail(origin + Vector2(2, -3 + k * 3), origin + Vector2(10 + k * 2, -3 + k * 3), Color("ffd040"), 1.0)


func _dragon_marker(p: Vector2) -> void:
	draw_circle(p, 2.6, Color(1, 1, 1, 0.9))
	draw_circle(p + Vector2(1.4, -1.0), 1.0, Color(0.1, 0.1, 0.2))


func _pattern_ring(col: Color) -> void:
	var n := clampi(int(attack.count), 6, 16)
	for i in n:
		var a := TAU * i / n
		var d := Vector2.from_angle(a)
		_trail(d * 8.0, d * 13.0, col, 1.2)
		_head(d * 14.0, a, col, _radius() * 0.8)
	_dragon_marker(Vector2.ZERO)
	if float(attack.explode) > 0.0:
		draw_arc(Vector2.ZERO, 17.0, 0, TAU, 20, Color(1, 0.8, 0.3, 0.5), 1.0)


func _pattern_back(col: Color) -> void:
	var n := clampi(int(attack.count), 1, 4)
	var spread := minf(float(attack.spread), 70.0)
	for side in [1.0, -1.0]:
		for i in n:
			var a := 0.0
			if n > 1:
				a = deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, float(i) / (n - 1)))
			var dir := Vector2.from_angle(a) * Vector2(side, 1.0)
			_trail(dir * 4.0, dir * 14.0, col)
			_head(dir * 15.0, dir.angle(), col, _radius() * 0.85)
	_dragon_marker(Vector2.ZERO)


func _pattern_wall(col: Color) -> void:
	var n := clampi(int(attack.count), 2, 7)
	_dragon_marker(Vector2(-15, 0))
	for i in n:
		var y := (i - (n - 1) * 0.5) * (26.0 / maxf(1.0, n - 1.0) if n > 1 else 0.0)
		_trail(Vector2(-4, y), Vector2(10, y), col)
		_head(Vector2(11, y), 0.0, col, _radius() * 0.85)


func _pattern_spiral(col: Color) -> void:
	var arms := clampi(int(attack.count), 1, 4)
	_dragon_marker(Vector2(-15, 0))
	for k in arms:
		var pts := PackedVector2Array()
		for i in 22:
			var t := float(i) / 21.0
			var a := t * TAU * 1.4 + k * TAU / arms
			pts.append(Vector2(-6 + t * 20.0, sin(a) * (2.0 + t * 9.0)))
		_path(pts, col)
		_head(pts[pts.size() - 1], 0.0, col, _radius() * 0.8)


func _pattern_twin_wave(col: Color, origin: Vector2) -> void:
	_dragon_marker(origin)
	for k in 2:
		var pts := PackedVector2Array()
		for i in 21:
			var x := origin.x + 29.0 * float(i) / 20.0
			pts.append(Vector2(x, sin(float(i) * 0.65 + k * PI) * 6.0))
		_path(pts, col)
		_head(pts[pts.size() - 1], 0.0, col, _radius() * 0.9)


func _pattern_rain(col: Color) -> void:
	var n := clampi(int(attack.count), 3, 7)
	draw_line(Vector2(-17, 13), Vector2(17, 13), Color(1, 1, 1, 0.35), 1.0)
	for i in n:
		var x := -12.0 + 24.0 * float(i) / (n - 1)
		var y := 4.0 + float(i % 2) * 3.0
		_trail(Vector2(x - 9.0, y - 18.0), Vector2(x, y), col)
		_head(Vector2(x, y), 1.1, col, _radius() * 0.85)
		if float(attack.explode) > 0.0 and i % 2 == 0:
			draw_arc(Vector2(x, 12.0), 3.0, PI, TAU, 8, Color(1, 0.8, 0.3, 0.8), 1.2)


func _pattern_orbit(col: Color) -> void:
	var n := clampi(int(attack.count), 3, 6)
	draw_arc(Vector2.ZERO, 12.0, 0, TAU, 24, Color(col.r, col.g, col.b, 0.35), 1.0)
	for i in n:
		var a := TAU * i / n - 0.5
		_head(Vector2.from_angle(a) * 12.0, a + PI * 0.5, col, _radius() * 0.9)
	_dragon_marker(Vector2.ZERO)


func _pattern_mine(col: Color) -> void:
	draw_line(Vector2(-17, 9), Vector2(17, 9), Color(1, 1, 1, 0.3), 1.0)
	for i in 3:
		var p := Vector2(-10.0 + i * 10.0, 5.0)
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0)
			draw_line(p + d * 3.5, p + d * 5.5, DARK, 2.0)
		draw_circle(p, 3.6, Color("2a2a34"))
		draw_circle(p, 1.8, col if i != 1 else Color(1, 0.3, 0.2))
	draw_arc(Vector2(10, 5), 8.0, 0, TAU, 14, Color(1, 0.8, 0.3, 0.6), 1.0)
	_dragon_marker(Vector2(-15, -7))


func _pattern_chain(col: Color, origin: Vector2) -> void:
	var n := clampi(int(attack.count), 3, 6)
	var pts := PackedVector2Array([origin])
	for i in n:
		var x := -9.0 + 24.0 * float(i) / maxf(1.0, n - 1.0)
		pts.append(Vector2(x, -9.0 if i % 2 == 0 else 9.0))
	draw_polyline(pts, Color(0, 0, 0, 0.45), 3.4)
	draw_polyline(pts, col.lightened(0.3) if not darken else col, 1.6)
	for i in range(1, pts.size()):
		draw_circle(pts[i], 2.4, DARK)
		draw_circle(pts[i], 1.6, Color(1, 1, 1, 0.95) if not darken else Color(0.2, 0.2, 0.3))
	_dragon_marker(origin)


func _draw_effect_badge() -> void:
	var effect := String(attack.effect)
	if effect == "":
		return
	var p := Vector2(13, 12)
	match effect:
		"freeze":
			for k in 3:
				var d := Vector2.from_angle(k * PI / 3.0) * 4.0
				draw_line(p - d, p + d, Color("a0f0ff") if not darken else Color("2080a0"), 1.4)
		"burn":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 3), p + Vector2(0, -5), p + Vector2(3, 3)]), Color("ff4020"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-1.5, 3), p + Vector2(0, -1), p + Vector2(1.5, 3)]), Color("ffd040"))
		"shock":
			draw_polyline(PackedVector2Array([p + Vector2(1, -5), p + Vector2(-2, 0), p + Vector2(2, 0), p + Vector2(-1, 5)]), Color("ffe840") if not darken else Color("a08000"), 1.6)
		"poison":
			draw_circle(p, 2.6, Color("60e040") if not darken else Color("308020"))
			draw_circle(p + Vector2(3, -3), 1.4, Color("60e040") if not darken else Color("308020"))
