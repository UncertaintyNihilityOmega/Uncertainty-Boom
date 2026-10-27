extends Control
## Title screen: chunky block-letter logo over a night castle, with a meteor and a small dragon.

const GLYPHS := {
	"U": ["X...X", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
	"N": ["X...X", "XX..X", "XX..X", "X.X.X", "X..XX", "X..XX", "X...X"],
	"C": [".XXX.", "X...X", "X....", "X....", "X....", "X...X", ".XXX."],
	"E": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"],
	"R": ["XXXX.", "X...X", "X...X", "XXXX.", "X.X..", "X..X.", "X...X"],
	"T": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
	"A": [".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
	"I": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "XXXXX"],
	"Y": ["X...X", "X...X", ".X.X.", "..X..", "..X..", "..X..", "..X.."],
	"B": ["XXXX.", "X...X", "X...X", "XXXX.", "X...X", "X...X", "XXXX."],
	"O": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
	"M": ["X...X", "XX.XX", "X.X.X", "X.X.X", "X...X", "X...X", "X...X"],
}
const ROW_COLORS := [Color("ffe070"), Color("ffb040"), Color("ff8a30"), Color("f06030"), Color("e04028"), Color("c82828"), Color("a81c30")]
const OUTLINE := Color("2a0a1e")

var _t := 0.0


func setup(_args: Dictionary) -> void:
	size = Vector2(640, 360)

	var play := UIKit.make_button("PLAY", Vector2(150, 44), UIKit.TEAL, 22, "play")
	UIKit.place(play, 245, 270)
	play.pressed.connect(func() -> void: Events.request_screen.emit("levels", {}))
	add_child(play)

	var specs := [
		["Nest", 100, "nest"], ["Achievements", 130, "achievements"],
		["Settings", 100, "settings"], ["Quit", 80, ""],
	]
	var total := 30.0
	for s in specs:
		total += float(s[1])
	var x := (640.0 - total) * 0.5
	for s in specs:
		var b := UIKit.make_button(String(s[0]), Vector2(float(s[1]), 28), UIKit.TEAL if s[2] != "" else UIKit.RED, 12)
		UIKit.place(b, x, 326)
		x += float(s[1]) + 10.0
		var target: String = s[2]
		b.pressed.connect(func() -> void:
			if target == "":
				get_tree().quit()
			else:
				Events.request_screen.emit(target, {}))
		add_child(b)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	UIKit.draw_night_background(self, size, _t, 1)
	_draw_meteor()
	_draw_big_castle()
	_draw_hill()
	_draw_title()
	var dx := 320.0 + sin(_t * 0.5) * 230.0
	var dy := 196.0 + sin(_t * 0.9) * 26.0
	var facing := 1 if cos(_t * 0.5) >= 0.0 else -1
	DragonArt.draw(self, Vector2(dx, dy), Game.equipped_dragon(), facing, _t, 2.4, "fly", sin(_t * 0.9) * 0.1 * facing)


func _draw_meteor() -> void:
	var p := fposmod(_t / 9.0, 1.0)
	if p > 0.45:
		return
	var q := p / 0.45
	var head := Vector2(lerpf(-30.0, 670.0, q), lerpf(8.0, 200.0, q * q * 0.4 + q * 0.6))
	var dir := Vector2(700.0, 192.0).normalized()
	for i in 16:
		var k := float(i) / 16.0
		var pos := head - dir * (i * 7.0)
		draw_circle(pos, 6.0 * (1.0 - k) + 1.0, Color(1.0, 0.45 + 0.4 * (1.0 - k), 0.1, 0.7 * (1.0 - k)))
	for i in 5:
		draw_circle(head - dir * (60.0 + i * 16.0) + Vector2(0, sin(_t * 3.0 + i) * 3.0), 4.0 - i * 0.5, Color(0, 0, 0, 0.7))
	draw_circle(head, 8.0, Color("ff7a10"))
	draw_circle(head, 5.5, Color("ffd040"))
	draw_circle(head, 2.5, Color("fff6c0"))


func _draw_big_castle() -> void:
	var stone := UIKit.STONE
	var base := 222.0
	var wall := Rect2(196, 142, 248, base - 142.0)
	draw_rect(wall, stone)
	draw_rect(Rect2(wall.position.x, wall.position.y, wall.size.x, 4), UIKit.STONE_LIGHT)
	for i in 31:
		draw_rect(Rect2(wall.position.x + i * 8.0 + 2.0, wall.position.y - 4.0, 4.0, 4.0), UIKit.STONE_LIGHT)
	for row in 7:
		var y := wall.position.y + 12.0 + row * 11.0
		draw_line(Vector2(wall.position.x, y), Vector2(wall.end.x, y), UIKit.STONE_DARK, 1.0)
		for k in 12:
			var bx := wall.position.x + (k * 22.0 + (11.0 if row % 2 == 0 else 0.0))
			if bx < wall.end.x:
				draw_line(Vector2(bx, y), Vector2(bx, y + 11.0), UIKit.STONE_DARK, 1.0)
	for tx in [172.0, 424.0]:
		draw_rect(Rect2(tx, 84, 44, base - 84.0), stone)
		draw_rect(Rect2(tx + 28.0, 84, 16, base - 84.0), UIKit.STONE_DARK)
		draw_rect(Rect2(tx - 4.0, 84, 52, 8), UIKit.STONE_LIGHT)
		for k in 4:
			draw_rect(Rect2(tx - 4.0 + k * 14.0, 74, 10, 10), UIKit.STONE_LIGHT)
		draw_rect(Rect2(tx + 18.0, 112, 5, 12), Color("0a2a48"))
		draw_rect(Rect2(tx + 18.0, 156, 5, 12), Color("0a2a48"))
		var fx: float = tx + 22.0
		draw_line(Vector2(fx, 74), Vector2(fx, 50), Color("c8e8ff"), 1.0)
		var wave := sin(_t * 4.0 + tx) * 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(fx, 50), Vector2(fx + 16, 54 + wave), Vector2(fx + 8, 56), Vector2(fx + 16, 60 - wave), Vector2(fx, 58)]), Color("ff8aa0"))
	# Gate and smoke from behind the title.
	draw_rect(Rect2(308, 176, 24, 46), Color("0a2a48"))
	draw_circle(Vector2(320, 176), 12.0, Color("0a2a48"))
	for i in 5:
		var ph := fposmod(_t * 0.35 + i * 0.2, 1.0)
		draw_circle(Vector2(300.0 + i * 10.0 + sin(ph * 5.0) * 4.0, 150.0 - ph * 40.0), 3.0 + ph * 5.0, Color(0, 0, 0, 0.75 * (1.0 - ph)))


func _draw_hill() -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := PI + PI * i / 40.0
		pts.append(Vector2(320.0 + cos(a) * 400.0, 330.0 + sin(a) * 118.0))
	pts.append(Vector2(720, 370))
	pts.append(Vector2(-80, 370))
	draw_colored_polygon(pts, UIKit.GRASS)
	draw_colored_polygon(UIKit.hill_polygon(size.x, 318.0, 362.0, 6.0, 0.02, 1.0), UIKit.GRASS_DARK)
	for tx in [60.0, 96.0, 560.0, 596.0]:
		var ty := 286.0 if tx < 300.0 else 288.0
		draw_colored_polygon(PackedVector2Array([Vector2(tx, ty - 28), Vector2(tx - 9, ty), Vector2(tx + 9, ty)]), Color("007a5e"))
		draw_rect(Rect2(tx - 1, ty, 2, 6), Color("064a3a"))


func _draw_text_blocks(text: String, top_left: Vector2, px: float) -> void:
	var o := maxf(1.0, floorf(px * 0.3))
	var x := top_left.x
	var cells: Array[Rect2] = []
	var rows: Array[int] = []
	for ch in text:
		var g: Array = GLYPHS[ch]
		for r in 7:
			var line: String = g[r]
			for c in 5:
				if line[c] == "X":
					cells.append(Rect2(x + c * px, top_left.y + r * px, px, px))
					rows.append(r)
		x += 6.0 * px
	for rc in cells:
		draw_rect(Rect2(rc.position + Vector2(-o, 0), rc.size + Vector2(o * 2.0, o * 2.0)), OUTLINE)
	for i in cells.size():
		var rc := cells[i]
		draw_rect(rc, ROW_COLORS[rows[i]])
		draw_rect(Rect2(rc.position, Vector2(rc.size.x, maxf(1.0, px * 0.18))), Color(1, 1, 1, 0.28))
		draw_rect(Rect2(rc.position.x, rc.position.y, maxf(1.0, px * 0.18), rc.size.y), Color(1, 1, 1, 0.14))


func _draw_title() -> void:
	var px1 := 5.0
	var w1 := (11.0 * 6.0 - 1.0) * px1
	_draw_text_blocks("UNCERTAINTY", Vector2((640.0 - w1) * 0.5, 22), px1)
	var px2 := 9.0
	var w2 := (4.0 * 6.0 - 1.0) * px2
	_draw_text_blocks("BOOM", Vector2((640.0 - w2) * 0.5, 66), px2)
