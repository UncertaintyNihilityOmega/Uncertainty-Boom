class_name HUD
extends CanvasLayer
## In-level heads-up display: hearts, coins, combo, slow-mo meter, dash pips,
## level progress / timer / keys, off-screen enemy arrows and the hurt flash.

var world
var _canvas: Control
var _font: Font
var _hurt := 0.0
var _combo_pop := 0.0
var _shown_coins := 0.0


func setup(world_) -> void:
	world = world_
	layer = 10
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	var pause := Button.new()
	pause.text = "II"
	pause.focus_mode = Control.FOCUS_NONE
	pause.position = Vector2(306, 4)
	pause.size = Vector2(28, 20)
	pause.add_theme_font_size_override("font_size", 12)
	pause.pressed.connect(func(): world.open_pause())
	add_child(pause)
	Events.player_hurt.connect(func(_h): _hurt = 0.35)
	Events.combo_changed.connect(func(c): if c > 0: _combo_pop = 0.15)


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	_hurt = maxf(0.0, _hurt - real)
	_combo_pop = maxf(0.0, _combo_pop - real)
	_shown_coins = move_toward(_shown_coins, world.coins, maxf(1.0, absf(world.coins - _shown_coins)) * real * 8.0)
	_canvas.queue_redraw()


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_canvas.draw_string_outline(_font, pos, s, align, width, size, 4, Color(0.03, 0.04, 0.1))
	_canvas.draw_string(_font, pos, s, align, width, size, col)


func _draw_heart(p: Vector2, full: bool) -> void:
	var col := Color("ff3040") if full else Color("3a2030")
	_canvas.draw_circle(p + Vector2(-3, 0), 3.5, col)
	_canvas.draw_circle(p + Vector2(3, 0), 3.5, col)
	_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-6.4, 1), p + Vector2(6.4, 1), p + Vector2(0, 8)]), col)
	if full:
		_canvas.draw_rect(Rect2(p + Vector2(-4, -2), Vector2(2, 2)), Color(1, 0.7, 0.75))


func _draw_hud() -> void:
	var p = world.player
	if p == null:
		return
	# Hurt flash: red border + tint
	if _hurt > 0.0:
		var a := _hurt / 0.35
		_canvas.draw_rect(Rect2(0, 0, 640, 360), Color(1, 0, 0, 0.18 * a))
		_canvas.draw_rect(Rect2(0, 0, 640, 360), Color(1, 0.1, 0.1, 0.9 * a), false, 6.0)
	# Slow-mo vignette
	if Engine.time_scale < 0.9:
		var a2 := (1.0 - Engine.time_scale) * 0.35
		_canvas.draw_rect(Rect2(0, 0, 640, 360), Color(0.2, 0.5, 1.0, a2 * 0.25))
		_canvas.draw_rect(Rect2(0, 0, 640, 360), Color(0.5, 0.9, 1.0, a2), false, 4.0)

	# Hearts
	for i in Dragon.MAX_HEARTS:
		_draw_heart(Vector2(14 + i * 16, 12), i < p.hearts)

	# Slow-mo meter
	var mx := 8.0
	var my := 24.0
	_canvas.draw_rect(Rect2(mx, my, 76, 7), Color(0.03, 0.04, 0.1))
	var frac: float = p.meter / p.METER_MAX
	var mcol := Color("40e0ff") if frac >= p.METER_MIN_START / p.METER_MAX else Color("406080")
	_canvas.draw_rect(Rect2(mx + 1, my + 1, 74 * frac, 5), mcol)
	_text(Vector2(mx + 80, my + 7), "SLOW", 8, Color("a0e8ff"))

	# Coins + combo (top right)
	var coin_s := str(int(_shown_coins))
	_text(Vector2(0, 17), coin_s, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 620)
	_canvas.draw_circle(Vector2(629, 12), 5.0, Color("f0a010"))
	_canvas.draw_circle(Vector2(629, 12), 3.5, Color("ffd84a"))
	if world.combo >= 2:
		var size := 18 + int(_combo_pop * 40.0)
		_text(Vector2(0, 40), "x%d" % world.combo, size, Color("ffe070") if world.combo >= 10 else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 632)
		_canvas.draw_rect(Rect2(592, 45, 40 * clampf(world.combo_timer / 2.5, 0, 1), 2), Color("ffe070"))

	# Track-specific info (top left, under the pips)
	if world.track == "dungeon":
		_text(Vector2(8, 58), _fmt(world.time), 10, Color.WHITE)
		_text(Vector2(56, 58), "Keys %d/%d" % [world.keys, world.keys_total], 10, Color("ffc830"))
		var room_label := "Room %d" % (world.room_i + 1) if world.endless else "Room %d/%d" % [world.room_i + 1, world.rooms.size()]
		_text(Vector2(8, 72), room_label, 10, Color("a0e8ff"))
	elif world.endless:
		_text(Vector2(8, 58), "%d m" % world.distance, 10, Color.WHITE)
	else:
		# Progress bar toward the treasure
		var prog := clampf(p.global_position.x / maxf(1.0, world.end_x - 300.0), 0.0, 1.0)
		_canvas.draw_rect(Rect2(220, 30, 200, 3), Color(0.03, 0.04, 0.1, 0.7))
		_canvas.draw_rect(Rect2(220, 30, 200 * prog, 3), Color("30d0a0"))
		_canvas.draw_rect(Rect2(218 + 200 * prog, 27, 4, 9), Color("ffe070"))
		_canvas.draw_rect(Rect2(420, 26, 8, 8), Color("a85a20"))
	if world.keys > 0 and world.track == "castle":
		_text(Vector2(8, 72 if world.endless else 58), "Keys %d" % world.keys, 10, Color("ffc830"))

	# Attack style name (bottom left)
	_text(Vector2(8, 352), p.attack.name, 10, Color(1, 1, 1, 0.75))
	if Game.get_setting("keyboard_mode"):
		_text(Vector2(0, 352), "E slow-mo   R attack   Shift dash", 8, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, 632)

	_draw_offscreen_arrows()


func _draw_offscreen_arrows() -> void:
	var view: Rect2 = world.view_rect()
	var center := view.get_center()
	var inner := Rect2(Vector2(8, 8), Vector2(624, 344))
	var drawn := 0
	for e in world.enemies:
		if not is_instance_valid(e) or e.dead or view.has_point(e.global_position):
			continue
		var to: Vector2 = e.global_position - center
		if to.length() > 520.0 or drawn > 12:
			continue
		drawn += 1
		var dir := to.normalized()
		var t := minf(absf(312.0 / maxf(absf(dir.x), 0.001)), absf(172.0 / maxf(absf(dir.y), 0.001)))
		var sp := Vector2(320, 180) + dir * t
		sp = sp.clamp(inner.position, inner.end)
		var col := Color("ff8a20") if not EnemyDB.get_def(e.kind).get("boss", false) else Color("ff3030")
		_canvas.draw_colored_polygon(PackedVector2Array([sp + dir * 6.0, sp + dir.orthogonal() * 4.0, sp - dir.orthogonal() * 4.0]), col)


static func _fmt(t: float) -> String:
	return "%02d:%02d.%d" % [int(t) / 60, int(t) % 60, int(fmod(t, 1.0) * 10.0)]
