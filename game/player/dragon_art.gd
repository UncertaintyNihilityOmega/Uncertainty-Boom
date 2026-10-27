class_name DragonArt
## Draws a dragon skin with simple vector shapes onto any CanvasItem.
## Facing right at scale 1 the dragon is about 22 x 16 px, centered on `pos`.
##   DragonArt.draw(self, Vector2.ZERO, "ember", 1, time, 1.0)
## pose: "fly" (wings flap with t), "dash" (wings swept back), "idle" (wings folded)


static func draw(ci: CanvasItem, pos: Vector2, skin_id: String, facing := 1, t := 0.0, scale := 1.0, pose := "fly", rot := 0.0, tint := Color.WHITE) -> void:
	var c := DragonDB.colors(skin_id)
	for k in c.keys():
		c[k] = c[k] * tint
	ci.draw_set_transform(pos, rot, Vector2(scale * facing, scale))
	var flap := sin(t * 14.0)
	if pose == "idle":
		flap = 0.6 + sin(t * 3.0) * 0.1
	elif pose == "dash":
		flap = -1.0

	# Tail
	var tail_y := sin(t * 6.0) * 1.5
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-4, 0), Vector2(-11, -2 + tail_y), Vector2(-13, -4 + tail_y), Vector2(-10, 1 + tail_y), Vector2(-4, 4)]), c.body)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -4 + tail_y), Vector2(-15, -6 + tail_y), Vector2(-12, -2 + tail_y)]), c.horn)

	# Back wing (darker, behind body). Tip stays above the shoulder so the
	# polygon never folds over itself.
	var wy := -9.0 - flap * 4.0
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-1, -2), Vector2(-7, wy - 1), Vector2(-2, wy + 1), Vector2(3, -2)]), c.wing.darkened(0.3))

	# Body
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -1), Vector2(-3, -4), Vector2(3, -4), Vector2(6, -2), Vector2(6, 3), Vector2(2, 5), Vector2(-4, 5), Vector2(-7, 2)]), c.body)
	# Belly
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-4, 2), Vector2(4, 1), Vector2(5, 3), Vector2(2, 5), Vector2(-3, 5)]), c.belly)
	# Back spikes
	for i in 3:
		var sx := -3.0 + i * 3.0
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(sx, -4), Vector2(sx + 1, -6), Vector2(sx + 2, -4)]), c.horn)
	# Legs
	ci.draw_rect(Rect2(-3, 4, 2, 3), c.body.darkened(0.2))
	ci.draw_rect(Rect2(2, 4, 2, 3), c.body.darkened(0.2))

	# Neck + head
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(3, -3), Vector2(6, -7), Vector2(9, -6), Vector2(7, 0)]), c.body)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(5, -10), Vector2(10, -10), Vector2(13, -7), Vector2(13, -4), Vector2(7, -3), Vector2(5, -6)]), c.body)
	# Jaw / snout highlight
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(8, -5), Vector2(13, -5), Vector2(13, -4), Vector2(8, -3)]), c.belly)
	# Horns
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(5, -10), Vector2(3, -14), Vector2(7, -10)]), c.horn)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(7, -10), Vector2(6, -13), Vector2(9, -10)]), c.horn)
	# Eye
	ci.draw_rect(Rect2(9, -9, 2, 2), c.eye)
	ci.draw_rect(Rect2(10, -9, 1, 1), Color(0.05, 0.05, 0.1))
	# Nostril
	ci.draw_rect(Rect2(12, -7, 1, 1), c.wing.darkened(0.4))

	# Front wing
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -2), Vector2(-5, wy), Vector2(1, wy + 1), Vector2(4, -3)]), c.wing)
	ci.draw_line(Vector2(-2, -2), Vector2(-5, wy), c.wing.lightened(0.3), 1.0)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
