class_name Chunk
extends StaticBody2D
## A slice of level terrain: a ground heightmap (with pits) plus solid
## rectangles (towers, walls, bridges, platforms) and decorations.
## Builds its own collision and draws itself in flat vector style.

const COL := 16.0
const BOTTOM := 900.0
const PIT := 99999.0

var x0 := 0.0
var x1 := 640.0
var heights := PackedFloat32Array()   # ground y per COL column (+1 for the right edge), PIT = no ground
var rects: Array[Rect2] = []          # solid blocks
var styles: Array[String] = []        # per rect: tower | wall | bridge | pillar | hang | platform | stone
var deco: Array[Dictionary] = []      # {type, pos, ...}: arches, flag, tree, chain, banner, torch
var hazards: Array[Rect2] = []        # spikes: hurt the dragon
var water: Array[Rect2] = []          # slows the dragon
var pal: Dictionary


func setup(from_x: float, to_x: float, palette: Dictionary) -> void:
	x0 = from_x
	x1 = to_x
	pal = palette
	collision_layer = 1
	collision_mask = 0
	var cols := int(ceil((x1 - x0) / COL)) + 1
	heights.resize(cols)
	heights.fill(PIT)


func add_rect(r: Rect2, style := "stone") -> void:
	rects.append(r)
	styles.append(style)


## Builds the physics shapes once all data is filled in.
func build() -> void:
	var run := PackedVector2Array()
	for i in heights.size():
		var h := heights[i]
		if h < PIT:
			run.append(Vector2(x0 + i * COL, h))
		if (h >= PIT or i == heights.size() - 1) and run.size() >= 2:
			_add_ground_poly(run)
			run = PackedVector2Array()
		elif h >= PIT:
			run = PackedVector2Array()
	for r in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		add_child(cs)
	queue_redraw()


func _add_ground_poly(run: PackedVector2Array) -> void:
	var poly := run.duplicate()
	poly.append(Vector2(run[run.size() - 1].x, BOTTOM))
	poly.append(Vector2(run[0].x, BOTTOM))
	var cp := CollisionPolygon2D.new()
	cp.polygon = poly
	add_child(cp)


func ground_at(x: float) -> float:
	var fx := (x - x0) / COL
	var i := int(floor(fx))
	if i < 0 or i >= heights.size():
		return PIT
	var a := heights[i]
	var b := heights[mini(i + 1, heights.size() - 1)]
	if a >= PIT or b >= PIT:
		return PIT
	return lerpf(a, b, fx - i)


func is_solid(p: Vector2) -> bool:
	if p.x < x0 or p.x > x1:
		return false
	if p.y >= ground_at(p.x):
		return true
	for r in rects:
		if r.has_point(p):
			return true
	return false


## y of the first surface at or below from_y (PIT if none).
func surface_below(x: float, from_y: float) -> float:
	var best := ground_at(x)
	if best < from_y:
		best = PIT
	for r in rects:
		if x >= r.position.x and x <= r.end.x and r.position.y >= from_y and r.position.y < best:
			best = r.position.y
	return best


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	for d in deco:
		if d.type == "arches":
			_draw_arches(d)
	for w in water:
		draw_rect(w, Color(pal.water, 0.55))
		draw_rect(Rect2(w.position, Vector2(w.size.x, 2)), Color(pal.water.lightened(0.4), 0.8))
	_draw_ground()
	for i in rects.size():
		_draw_rect_style(rects[i], styles[i])
	for h in hazards:
		var n := int(h.size.x / 6.0)
		for k in n:
			var bx := h.position.x + k * 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(bx, h.end.y), Vector2(bx + 3, h.position.y), Vector2(bx + 6, h.end.y)]), pal.spike)
	for d in deco:
		match d.type:
			"flag": _draw_flag(d.pos)
			"tree": _draw_tree(d.pos, d.get("s", 1.0))
			"chain": _draw_chain(d.pos, d.to)
			"torch": _draw_torch(d.pos)
			"window": draw_rect(Rect2(d.pos, Vector2(3, 6)), pal.stone_dark)


func _draw_ground() -> void:
	var run := PackedVector2Array()
	for i in heights.size():
		var h := heights[i]
		if h < PIT:
			run.append(Vector2(x0 + i * COL, h))
		if (h >= PIT or i == heights.size() - 1) and run.size() >= 2:
			_fill_ground(run)
			run = PackedVector2Array()
		elif h >= PIT:
			run = PackedVector2Array()


func _fill_ground(run: PackedVector2Array) -> void:
	var poly := run.duplicate()
	poly.append(Vector2(run[run.size() - 1].x, BOTTOM))
	poly.append(Vector2(run[0].x, BOTTOM))
	draw_colored_polygon(poly, pal.ground)
	# Darker deep band for depth.
	var band := PackedVector2Array()
	for p in run:
		band.append(p + Vector2(0, 26))
	band.append(Vector2(run[run.size() - 1].x, BOTTOM))
	band.append(Vector2(run[0].x, BOTTOM))
	draw_colored_polygon(band, pal.ground_dark)
	draw_polyline(run, pal.ground_top, 2.0)


func _draw_rect_style(r: Rect2, style: String) -> void:
	match style:
		"platform":
			draw_rect(r, pal.stone)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), pal.stone_light)
			draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), pal.stone_dark)
		"hang":
			draw_rect(r, pal.stone)
			draw_rect(Rect2(r.position.x, r.position.y, 4, r.size.y), pal.stone_light)
			draw_rect(Rect2(r.end.x - 6, r.position.y, 6, r.size.y), pal.stone_dark)
			draw_rect(Rect2(r.position.x - 3, r.end.y - 6, r.size.x + 6, 6), pal.stone_light)
		"door":
			draw_rect(r, pal.door)
			for k in int(r.size.y / 10.0):
				draw_rect(Rect2(r.position.x, r.position.y + k * 10.0, r.size.x, 1), pal.stone_dark)
		_:
			draw_rect(r, pal.stone)
			draw_rect(Rect2(r.position.x, r.position.y, 3, r.size.y), pal.stone_light)
			draw_rect(Rect2(r.end.x - 5, r.position.y, 5, r.size.y), pal.stone_dark)
			if style == "tower" or style == "wall":
				# Crenellations
				var n := int(r.size.x / 8.0)
				for k in n:
					if k % 2 == 0:
						draw_rect(Rect2(r.position.x + k * 8.0, r.position.y - 5, 6, 5), pal.stone_light)
				draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), pal.stone_light)
				# Brick lines
				for k in int(r.size.y / 12.0):
					var y := r.position.y + 8 + k * 12.0
					draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 6, y), Color(pal.stone_dark, 0.35), 1.0)
			elif style == "bridge":
				draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), pal.stone_light)
				var n := int(r.size.x / 6.0)
				for k in n:
					draw_rect(Rect2(r.position.x + k * 6.0, r.position.y - 3, 3, 3), pal.stone_light)


func _draw_arches(d: Dictionary) -> void:
	var y: float = d.y
	var from_x: float = d.x0
	var to_x: float = d.x1
	var span := 48.0
	var x := from_x
	while x < to_x - 4.0:
		var w := minf(span, to_x - x)
		draw_rect(Rect2(x, y, 8, BOTTOM - y), pal.stone_dark)
		draw_rect(Rect2(x, y, w, 14), pal.stone)
		draw_circle(Vector2(x + w / 2.0 + 4.0, y + 22.0), (w - 8.0) / 2.0, pal.sky)
		x += span
	draw_rect(Rect2(to_x - 8, y, 8, BOTTOM - y), pal.stone_dark)


func _draw_flag(p: Vector2) -> void:
	draw_line(p, p + Vector2(0, -18), pal.pole, 1.0)
	var t := Time.get_ticks_msec() / 300.0
	var pts := PackedVector2Array()
	for k in 5:
		pts.append(p + Vector2(k * 3.0, -18 + sin(t + k) * 1.2))
	for k in range(4, -1, -1):
		pts.append(p + Vector2(k * 3.0, -14 + sin(t + k) * 1.2))
	draw_colored_polygon(pts, pal.flag)


func _draw_tree(p: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 0) * s, p + Vector2(0, -16) * s, p + Vector2(5, 0) * s]), pal.tree)
	draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2, 3)), pal.tree.darkened(0.3))


func _draw_chain(a: Vector2, b: Vector2) -> void:
	var n := int(a.distance_to(b) / 5.0)
	for k in n:
		var p := a.lerp(b, float(k) / maxf(n, 1))
		draw_rect(Rect2(p - Vector2(1, 1.5), Vector2(2, 3)), pal.chain if k % 2 == 0 else pal.chain.darkened(0.3))


func _draw_torch(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2, 6)), pal.pole)
	var f := sin(Time.get_ticks_msec() / 80.0) * 1.0
	draw_circle(p + Vector2(0, -2), 3.0 + f * 0.5, Color("ff8a20"))
	draw_circle(p + Vector2(0, -2), 1.5, Color("ffe070"))
