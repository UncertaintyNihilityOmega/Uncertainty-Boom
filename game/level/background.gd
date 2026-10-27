extends Node2D
## Parallax backdrop drawn in screen space: sky, moon, far hills, castle
## silhouettes (castles) or a patterned wall (dungeons).

var pal: Dictionary
var dungeon := false
var cam_pos := Vector2.ZERO
const W := 640.0
const H := 360.0


func setup(palette: Dictionary, is_dungeon: bool) -> void:
	pal = palette
	dungeon = is_dungeon
	z_index = -100


func follow(camera_center: Vector2) -> void:
	cam_pos = camera_center
	global_position = camera_center - Vector2(W, H) / 2.0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-20, -20, W + 40, H + 40), pal.sky)
	if dungeon:
		_draw_dungeon()
		return
	# Gradient band near the horizon
	draw_rect(Rect2(-20, H * 0.45, W + 40, H), pal.sky2)
	draw_circle(Vector2(W * 0.62, 95), 34.0, pal.moon)
	# Stars
	for i in 40:
		var sx := fposmod(float(i * 97) - cam_pos.x * 0.03, W)
		var sy := float((i * 53) % 150) + 5.0
		draw_rect(Rect2(sx, sy, 1, 1), Color(1, 1, 1, 0.5 + 0.5 * float(i % 3) / 2.0))
	# Far hills
	var far := PackedVector2Array()
	var off := cam_pos.x * 0.15
	for i in 34:
		var x := i * 20.0 - 20.0
		var wx := x + off
		far.append(Vector2(x, 170.0 + sin(wx * 0.006) * 40.0 + sin(wx * 0.017) * 14.0 - (cam_pos.y - 140.0) * 0.08))
	far.append(Vector2(W + 40, H + 20))
	far.append(Vector2(-20, H + 20))
	draw_colored_polygon(far, pal.far)
	# Castle silhouettes
	_draw_silhouettes(0.35, 225.0, pal.mid)


func _draw_silhouettes(factor: float, base: float, col: Color) -> void:
	var off := cam_pos.x * factor
	var y0 := base - (cam_pos.y - 140.0) * factor * 0.5
	draw_rect(Rect2(-20, y0 + 30, W + 40, H), col)
	var seg := 90.0
	var first := int(floor(off / seg)) - 1
	for i in range(first, first + int(W / seg) + 3):
		var x := i * seg - off
		var hsh := absi(hash(i * 7919))
		var kind := hsh % 5
		match kind:
			0, 1:  # keep with towers
				var w := 40.0 + float(hsh % 30)
				var h := 30.0 + float(hsh % 40)
				draw_rect(Rect2(x, y0 + 30 - h, w, h), col)
				for k in int(w / 8.0):
					if k % 2 == 0:
						draw_rect(Rect2(x + k * 8.0, y0 + 26 - h, 5, 4), col)
				draw_rect(Rect2(x - 6, y0 + 30 - h - 18, 12, h + 18), col)
				draw_rect(Rect2(x + w - 6, y0 + 30 - h - 12, 12, h + 12), col)
				draw_line(Vector2(x, y0 + 12 - h - 18), Vector2(x, y0 + 30 - h - 32), col, 1.0)
			2:  # aqueduct arches
				for k in 3:
					draw_rect(Rect2(x + k * 28.0, y0 + 2, 28, 6), col)
					draw_rect(Rect2(x + k * 28.0, y0 + 2, 5, 30), col)
			3:  # hill with trees
				draw_circle(Vector2(x + 40, y0 + 40), 34.0, col)
				for k in 3:
					var tx := x + 20 + k * 16.0
					draw_colored_polygon(PackedVector2Array([Vector2(tx - 4, y0 + 10), Vector2(tx, y0 - 4), Vector2(tx + 4, y0 + 10)]), col)
			_:
				pass


func _draw_dungeon() -> void:
	var off := cam_pos.x * 0.5
	var size := 24.0
	var cols := int(W / size) + 3
	var first := int(floor(off / size))
	for gy in int(H / size) + 2:
		for i in cols:
			var gx := first + i
			var x := gx * size - off
			var y := gy * size
			var c := Vector2(x + size / 2, y + size / 2)
			var col: Color = pal.sky2 if (gx + gy) % 2 == 0 else pal.far
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0)]), col)
	# Horizontal stone bands
	draw_rect(Rect2(-20, 150, W + 40, 6), pal.mid)
	draw_rect(Rect2(-20, 158, W + 40, 2), pal.far)
