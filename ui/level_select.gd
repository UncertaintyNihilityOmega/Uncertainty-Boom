extends Control
## Level map: Castles / Dungeons tabs, a horizontally scrolling zig-zag track of 20 levels + Endless.

const TRACK_RECT := Rect2(0, 68, 640, 222)
const INFO_RECT := Rect2(8, 296, 624, 58)
const ENDLESS := 20

var _track := "castle"
var _selected := 0
var _view: TrackView
var _tab_castle: Button
var _tab_dungeon: Button
var _play: Button
var _t := 0.0


## Scrolling track. Node index 0..19 are levels, 20 is the Endless node.
class TrackView extends Control:
	signal node_clicked(index: int)

	const SPACING := 108.0
	const LEFT := 66.0

	var track := "castle"
	var selected := 0
	var scroll := 0.0
	var target_scroll := 0.0
	var hover := -1
	var _t := 0.0
	var _pressed := false
	var _dragging := false
	var _press_x := 0.0
	var _press_scroll := 0.0

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_exited.connect(func() -> void: hover = -1)

	func content_width() -> float:
		return LEFT + 20.0 * SPACING + 26.0 + 92.0

	func max_scroll() -> float:
		return maxf(0.0, content_width() - size.x)

	func node_content_x(i: int) -> float:
		return LEFT + i * SPACING + (26.0 if i == 20 else 0.0)

	func node_x(i: int) -> float:
		return node_content_x(i) - scroll

	func node_top(i: int) -> float:
		if i == 20:
			return 96.0
		return 66.0 if i % 2 == 0 else 120.0

	func focus_on(i: int, instant := false) -> void:
		target_scroll = clampf(node_content_x(i) - size.x * 0.5, 0.0, max_scroll())
		if instant:
			scroll = target_scroll

	func scroll_by(amount: float) -> void:
		target_scroll = clampf(target_scroll + amount, 0.0, max_scroll())

	func hit_test(p: Vector2) -> int:
		for i in 21:
			var half := 62.0 if i == 20 else 46.0
			var top := node_top(i)
			if Rect2(node_x(i) - half, top - 62.0, half * 2.0, 122.0).has_point(p):
				return i
		return -1

	func _process(delta: float) -> void:
		_t += delta
		scroll = lerpf(scroll, target_scroll, 1.0 - exp(-12.0 * delta))
		if absf(scroll - target_scroll) < 0.2:
			scroll = target_scroll
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
					scroll_by(-100.0)
				MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
					scroll_by(100.0)
				MOUSE_BUTTON_LEFT:
					if mb.pressed:
						_pressed = true
						_dragging = false
						_press_x = mb.position.x
						_press_scroll = target_scroll
					else:
						if _pressed and not _dragging:
							var i := hit_test(mb.position)
							if i >= 0:
								node_clicked.emit(i)
						_pressed = false
						_dragging = false
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if _pressed and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
				var dx := mm.position.x - _press_x
				if absf(dx) > 5.0:
					_dragging = true
				if _dragging:
					target_scroll = clampf(_press_scroll - dx, 0.0, max_scroll())
					scroll = target_scroll
			else:
				var h := hit_test(mm.position)
				if h != hover:
					hover = h
					if h >= 0:
						Sfx.play("ui_hover")

	# ------------------------------------------------------------ drawing

	func _draw() -> void:
		if track == "castle":
			_draw_castle_bg()
		else:
			_draw_dungeon_bg()
		# Dotted path between level nodes.
		for i in 20:
			var a := Vector2(node_x(i), node_top(i) + 20.0)
			var b := Vector2(node_x(i + 1), node_top(i + 1) + 20.0)
			if b.x < -10.0 or a.x > size.x + 10.0:
				continue
			for k in 7:
				var p := a.lerp(b, (k + 0.5) / 7.0)
				draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 2.0, 2.0), Color(1, 1, 1, 0.22))
		for i in 21:
			var x := node_x(i)
			if x < -80.0 or x > size.x + 80.0:
				continue
			_draw_node(i, x)
		_draw_scrollbar()
		if track == "dungeon" and not Game.is_level_unlocked("dungeon", 1):
			UIKit.draw_panel(self, Rect2(size.x * 0.5 - 150.0, size.y * 0.5 - 34.0, 300.0, 68.0), Color(0.02, 0.05, 0.12, 0.92), Color("5a7a9a"), 10, 2)
			UIKit.draw_padlock(self, Vector2(size.x * 0.5 - 118.0, size.y * 0.5), 26.0)
			UIKit.draw_text(self, "Clear Castle 3 to unlock", Vector2(size.x * 0.5 + 14.0, size.y * 0.5 - 9.0), 16, Color.WHITE, 1)

	func _draw_scrollbar() -> void:
		var ms := max_scroll()
		if ms <= 0.0:
			return
		var track_w := size.x - 40.0
		var thumb := maxf(30.0, track_w * size.x / content_width())
		var tx := 20.0 + (track_w - thumb) * (scroll / ms)
		draw_rect(Rect2(20, size.y - 6.0, track_w, 3.0), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(tx, size.y - 6.0, thumb, 3.0), Color(1, 1, 1, 0.5))

	func _draw_castle_bg() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0a3a58"))
		for i in 34:
			var sx := fposmod(UIKit._rand(i, 5.0) * 900.0 - scroll * 0.3, 900.0) - 130.0
			var sy := 8.0 + UIKit._rand(i, 6.0) * 110.0
			if sx > 0.0 and sx < size.x:
				var tw := 0.5 + 0.5 * sin(_t * 1.5 + i)
				draw_colored_polygon(PackedVector2Array([Vector2(sx, sy - 2), Vector2(sx + 2, sy), Vector2(sx, sy + 2), Vector2(sx - 2, sy)]), Color(0.3, 0.85, 1.0, 0.25 + 0.4 * tw))
		draw_colored_polygon(UIKit.hill_polygon(size.x, 150.0, size.y, 16.0, 0.012, scroll * 0.012 * 0.5), Color("0a4a6a"))
		draw_colored_polygon(UIKit.hill_polygon(size.x, 176.0, size.y, 12.0, 0.014, scroll * 0.014 * 0.8), Color("0c6a78"))
		draw_colored_polygon(UIKit.hill_polygon(size.x, 198.0, size.y, 8.0, 0.02, scroll * 0.02), UIKit.GRASS)
		for k in 30:
			var gx := fposmod(k * 74.0 - scroll, 2220.0) - 40.0
			if gx > 0.0 and gx < size.x:
				for j in 3:
					var bx := gx + j * 9.0
					draw_colored_polygon(PackedVector2Array([Vector2(bx, 212), Vector2(bx + 3, 204), Vector2(bx + 6, 212)]), UIKit.TEAL)

	func _draw_dungeon_bg() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UIKit.DUNGEON_BG)
		var off := fposmod(scroll * 0.6, 28.0)
		for gx in range(-1, 26):
			for gy in range(0, 9):
				var c := Vector2(gx * 28.0 - off + (14.0 if gy % 2 == 1 else 0.0), gy * 26.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(7, 0), c + Vector2(0, 6), c + Vector2(-7, 0)]), Color("12184a"))
		for px in [0.0, size.x - 18.0]:
			draw_rect(Rect2(px, 0, 18, size.y), Color("0c3a6a"))
			draw_rect(Rect2(px + (12.0 if px == 0.0 else 0.0), 0, 6, size.y), Color("1a6aa8"))
		draw_rect(Rect2(0, size.y - 34.0, size.x, 34.0), Color(0.1, 0.8, 0.9, 0.28))
		for k in 14:
			var wx := fposmod(k * 61.0 - scroll * 0.9 + sin(_t + k) * 4.0, 860.0) - 40.0
			if wx > 0.0 and wx < size.x:
				draw_line(Vector2(wx, size.y - 24.0 + (k % 3) * 7.0), Vector2(wx + 14.0, size.y - 24.0 + (k % 3) * 7.0), Color(0.6, 1, 1, 0.35), 1.0)

	func _best_line(x: float, y: float, text: String) -> void:
		var w := UIKit.text_width(text, 11) + 13.0
		var left := x - w * 0.5
		UIKit.draw_crown(self, Vector2(left + 5.0, y + 7.0), 10.0)
		UIKit.draw_text(self, text, Vector2(left + 13.0, y), 11, Color.WHITE, 0, 1)

	func _draw_node(i: int, x: float) -> void:
		var top := node_top(i)
		if i == 20:
			_draw_endless(x, top)
			return
		var n := i + 1
		var unlocked := Game.is_level_unlocked(track, n)
		var rec := Game.level_record(track, n)
		var done: bool = rec.done
		var dim := 0.0 if unlocked else 0.6
		var is_sel := selected == i
		if track == "castle":
			var hill := UIKit.GRASS.lerp(Color("0b2a3a"), dim)
			var dome := _dome(x, top, 46.0)
			draw_colored_polygon(dome, hill)
			if hover == i and unlocked:
				draw_colored_polygon(dome, Color(1, 1, 1, 0.12))
			if is_sel:
				draw_polyline(dome, Color.WHITE, 2.0)
			UIKit.draw_castle(self, Vector2(x, top + 3.0), 40.0, 32.0, UIKit.STONE, dim, unlocked)
			if done:
				UIKit.draw_flames(self, Vector2(x - 12.0, top - 28.0), 12.0, 14.0, _t + i)
				UIKit.draw_flames(self, Vector2(x + 12.0, top - 28.0), 12.0, 14.0, _t + i * 0.7)
				UIKit.draw_smoke(self, Vector2(x, top - 38.0), _t + i)
			if rec.best_gold > 0:
				_best_line(x, top - 60.0, UIKit.fmt_int(int(rec.best_gold)))
		else:
			var pool_c := Vector2(x, top + 22.0)
			var pool := _ellipse(pool_c, 44.0, 22.0)
			draw_colored_polygon(_ellipse(pool_c + Vector2(0, 3), 45.0, 22.0), Color("0a5a78").lerp(Color("0b1630"), dim))
			draw_colored_polygon(pool, UIKit.WATER.lerp(Color("0b1630"), dim))
			if hover == i and unlocked:
				draw_colored_polygon(pool, Color(1, 1, 1, 0.14))
			if is_sel:
				draw_polyline(pool, Color.WHITE, 2.0)
			if done:
				draw_arc(Vector2(x, top - 12.0), 21.0 + sin(_t * 3.0 + i) * 1.5, 0, TAU, 24, Color(1.0, 0.85, 0.3, 0.55), 2.0)
			UIKit.draw_swords(self, Vector2(x, top - 12.0), 34.0, Color("e8f4ff").lerp(Color("203048"), dim), Color("ffb030").lerp(Color("203048"), dim))
			if float(rec.best_time) > 0.0:
				_best_line(x, top - 60.0, UIKit.fmt_time(float(rec.best_time)))
		if unlocked:
			UIKit.draw_star_pill(self, Vector2(x, top + 13.0), rec.stars)
		else:
			UIKit.draw_padlock(self, Vector2(x, top - 14.0 if track == "castle" else top - 12.0), 18.0)
		UIKit.draw_text(self, str(n), Vector2(x, top + 22.0), 20, Color.WHITE if unlocked else Color("6a8aa8"), 1, 2)

	func _draw_endless(x: float, top: float) -> void:
		var unlocked := Game.is_endless_unlocked(track)
		var dim := 0.0 if unlocked else 0.6
		var is_sel := selected == 20
		var rec := Game.endless_record(track)
		if track == "castle":
			var dome := _dome(x, top, 64.0)
			draw_colored_polygon(dome, UIKit.GRASS.lerp(Color("0b2a3a"), dim))
			if hover == 20 and unlocked:
				draw_colored_polygon(dome, Color(1, 1, 1, 0.12))
			if is_sel:
				draw_polyline(dome, Color.WHITE, 2.0)
			UIKit.draw_castle(self, Vector2(x, top + 3.0), 58.0, 46.0, UIKit.STONE, dim, unlocked)
			if unlocked:
				UIKit.draw_flames(self, Vector2(x - 17.0, top - 42.0), 16.0, 18.0, _t)
				UIKit.draw_flames(self, Vector2(x + 17.0, top - 42.0), 16.0, 18.0, _t + 1.3)
				UIKit.draw_smoke(self, Vector2(x, top - 52.0), _t, 4)
			if unlocked and int(rec.best) > 0:
				_best_line(x, top - 78.0, "%s m" % UIKit.fmt_int(int(rec.best)))
		else:
			var pool_c := Vector2(x, top + 24.0)
			var pool := _ellipse(pool_c, 60.0, 28.0)
			draw_colored_polygon(_ellipse(pool_c + Vector2(0, 3), 61.0, 28.0), Color("0a5a78").lerp(Color("0b1630"), dim))
			draw_colored_polygon(pool, UIKit.WATER.lerp(Color("0b1630"), dim))
			if hover == 20 and unlocked:
				draw_colored_polygon(pool, Color(1, 1, 1, 0.14))
			if is_sel:
				draw_polyline(pool, Color.WHITE, 2.0)
			UIKit.draw_swords(self, Vector2(x, top - 16.0), 46.0, Color("e8f4ff").lerp(Color("203048"), dim), Color("ffb030").lerp(Color("203048"), dim))
			if unlocked and int(rec.best) > 0:
				_best_line(x, top - 78.0, "%s rooms" % UIKit.fmt_int(int(rec.best)))
		if unlocked:
			UIKit.draw_text(self, "ENDLESS", Vector2(x, top + 8.0), 14, Color.WHITE, 1, 2)
			UIKit.draw_infinity(self, Vector2(x, top + 36.0), 32.0, Color.WHITE, 3.0)
		else:
			UIKit.draw_padlock(self, Vector2(x, top - 18.0), 20.0)
			UIKit.draw_text(self, "ENDLESS", Vector2(x, top + 8.0), 14, Color("6a8aa8"), 1, 2)
			UIKit.draw_text(self, "Clear level 5", Vector2(x, top + 30.0), 11, Color("9ab4cc"), 1, 1)

	func _dome(x: float, top: float, half: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 21:
			var a := PI + PI * k / 20.0
			pts.append(Vector2(x + cos(a) * half, top + 26.0 + sin(a) * 26.0))
		pts.append(Vector2(x + half, top + 58.0))
		pts.append(Vector2(x - half, top + 58.0))
		return pts

	func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 28:
			var a := TAU * k / 28.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return pts


func setup(args: Dictionary) -> void:
	size = Vector2(640, 360)
	_track = String(args.get("track", "castle"))
	Events.currency_changed.connect(queue_redraw)

	var back := UIKit.make_button("Back", Vector2(64, 26), UIKit.BLUE, 12, "left")
	UIKit.place(back, 6, 5)
	back.pressed.connect(_back)
	add_child(back)

	var stats := UIKit.StatsBar.new()
	UIKit.place(stats, 78, 3)
	add_child(stats)

	var nest := UIKit.make_button("Nest", Vector2(56, 26), UIKit.TEAL, 11)
	UIKit.place(nest, 578, 5)
	nest.pressed.connect(func() -> void: Events.request_screen.emit("nest", {}))
	add_child(nest)

	_tab_castle = UIKit.make_button("Castles", Vector2(96, 26), UIKit.TEAL, 12)
	UIKit.place(_tab_castle, 8, 39)
	_tab_castle.pressed.connect(_set_track.bind("castle"))
	add_child(_tab_castle)
	_tab_dungeon = UIKit.make_button("Dungeons", Vector2(96, 26), UIKit.TEAL, 12)
	UIKit.place(_tab_dungeon, 108, 39)
	_tab_dungeon.pressed.connect(_set_track.bind("dungeon"))
	add_child(_tab_dungeon)

	var left := UIKit.make_button("", Vector2(30, 26), UIKit.BLUE, 12, "left")
	UIKit.place(left, 570, 39)
	left.pressed.connect(func() -> void: _view.scroll_by(-216.0))
	add_child(left)
	var right := UIKit.make_button("", Vector2(30, 26), UIKit.BLUE, 12, "right")
	UIKit.place(right, 604, 39)
	right.pressed.connect(func() -> void: _view.scroll_by(216.0))
	add_child(right)

	_view = TrackView.new()
	_view.position = TRACK_RECT.position
	_view.size = TRACK_RECT.size
	_view.node_clicked.connect(_on_node_clicked)
	add_child(_view)

	_play = UIKit.make_button("Play", Vector2(118, 42), UIKit.TEAL, 18, "play")
	UIKit.place(_play, INFO_RECT.end.x - 126.0, INFO_RECT.position.y + 8.0)
	_play.pressed.connect(_on_play)
	add_child(_play)

	_set_track(_track, true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _back() -> void:
	Events.request_screen.emit("menu", {})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
	elif event.is_action_pressed("ui_left"):
		_view.scroll_by(-108.0)
	elif event.is_action_pressed("ui_right"):
		_view.scroll_by(108.0)


func _style_tab(b: Button, active: bool) -> void:
	var col := UIKit.TEAL if active else Color("24486a")
	b.add_theme_stylebox_override("normal", UIKit._btn_style(col, false))
	b.add_theme_stylebox_override("hover", UIKit._btn_style(col.lightened(0.18), false))
	b.add_theme_stylebox_override("pressed", UIKit._btn_style(col.darkened(0.12), true))


func _set_track(track: String, first := false) -> void:
	_track = track
	_view.track = track
	_style_tab(_tab_castle, track == "castle")
	_style_tab(_tab_dungeon, track == "dungeon")
	_select(_default_selection(), true)
	if not first:
		_view.focus_on(_selected, true)


func _default_selection() -> int:
	for n in range(1, Game.level_count(_track) + 1):
		if Game.is_level_unlocked(_track, n) and not Game.level_record(_track, n).done:
			return n - 1
	if Game.is_endless_unlocked(_track):
		return ENDLESS
	return 0


func _select(i: int, instant := false) -> void:
	_selected = i
	_view.selected = i
	_view.focus_on(i, instant)
	_play.disabled = not _is_playable(i)
	queue_redraw()


func _is_playable(i: int) -> bool:
	if i == ENDLESS:
		return Game.is_endless_unlocked(_track)
	return Game.is_level_unlocked(_track, i + 1)


func _on_node_clicked(i: int) -> void:
	if not _is_playable(i):
		Sfx.play("error")
	else:
		Sfx.play("ui_click")
	_select(i)


func _on_play() -> void:
	if not _is_playable(_selected):
		return
	if _selected == ENDLESS:
		Game.start_level(_track, 1, true)
	else:
		Game.start_level(_track, _selected + 1)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	UIKit.draw_night_background(self, size, _t, 0, false)
	draw_rect(Rect2(0, 0, 640, 36), Color(0.02, 0.06, 0.14, 0.55))
	draw_rect(Rect2(0, 36, 640, 2), Color("1a4a6a"))
	var cleared := Game.count_cleared(_track)
	var total := Game.level_count(_track)
	UIKit.draw_text(self, "Cleared %d / %d" % [cleared, total], Vector2(226, 45), 12, UIKit.DIM)
	UIKit.draw_star(self, Vector2(350, 52), 6.0)
	UIKit.draw_text(self, "%d / %d" % [Game.count_stars(_track), total * 3], Vector2(360, 45), 12, UIKit.DIM)
	if _track == "dungeon" and not Game.is_level_unlocked("dungeon", 1):
		UIKit.draw_padlock(self, Vector2(214, 52), 12.0)
	_draw_info()


func _draw_info() -> void:
	UIKit.draw_panel(self, INFO_RECT, UIKit.PANEL, Color("3a78a8"), 8, 2)
	var x := INFO_RECT.position.x + 12.0
	var y := INFO_RECT.position.y + 6.0
	if _selected == ENDLESS:
		var endless_name := "Endless Castles" if _track == "castle" else "Endless Dungeon"
		UIKit.draw_text(self, endless_name, Vector2(x, y), 14, Color.WHITE)
		if not Game.is_endless_unlocked(_track):
			UIKit.draw_padlock(self, Vector2(x + 7.0, y + 28.0), 12.0)
			UIKit.draw_text(self, "Clear level 5 to unlock", Vector2(x + 18.0, y + 22.0), 11, Color("ffa0a0"))
			return
		var rec := Game.endless_record(_track)
		var unit := " m" if _track == "castle" else " rooms"
		UIKit.draw_crown(self, Vector2(x + 6.0, y + 29.0), 11.0)
		UIKit.draw_text(self, "Best: %s%s" % [UIKit.fmt_int(int(rec.best)), unit], Vector2(x + 18.0, y + 22.0), 12, Color.WHITE)
		var blurb := "Random castles, forever. Fly as far as you can." if _track == "castle" else "Random rooms, forever. Clear as many as you can."
		UIKit.draw_wrapped(self, blurb, Vector2(250, y + 4.0), 240.0, 11, UIKit.DIM, 3)
		return
	var n := _selected + 1
	var info := LevelDB.get_level(_track, n)
	var title := "%d. %s" % [n, info.name]
	UIKit.draw_text_fit(self, title, Vector2(x, y), 14, 215.0, Color.WHITE)
	if String(info.boss) != "":
		UIKit.draw_text(self, "BOSS LEVEL", Vector2(x, y + 36.0), 10, Color("ff8a60"))
	if not Game.is_level_unlocked(_track, n):
		UIKit.draw_padlock(self, Vector2(x + 7.0, y + 28.0 - 1.0), 12.0)
		var need := "Clear level %d first" % (n - 1) if (n > 1 or _track == "castle") else "Clear Castle 3 first"
		UIKit.draw_text(self, need, Vector2(x + 18.0, y + 22.0), 11, Color("ffa0a0"))
		return
	var rec := Game.level_record(_track, n)
	var best_text := "Best: -"
	if _track == "castle":
		if int(rec.best_gold) > 0:
			best_text = "Best: %s gold" % UIKit.fmt_int(int(rec.best_gold))
	elif float(rec.best_time) > 0.0:
		best_text = "Best: %s" % UIKit.fmt_time(float(rec.best_time))
	UIKit.draw_crown(self, Vector2(x + 6.0, y + 29.0), 11.0)
	UIKit.draw_text(self, best_text, Vector2(x + 18.0, y + 22.0), 12, Color.WHITE)
	var goals: Array[String] = []
	if _track == "castle":
		goals = ["Treasure: 90% of the coins", "No hearts lost", "Defeat every enemy"]
	else:
		var par := float(info.par_time)
		goals = ["Collect every key", "Reach a x%d combo" % int(info.combo_target), "Finish within %d:%02d" % [int(par) / 60, int(par) % 60]]
	for k in 3:
		var gy := y + 1.0 + k * 14.0
		UIKit.draw_star(self, Vector2(262, gy + 7.0), 5.0, bool(rec.stars[k]))
		UIKit.draw_text(self, goals[k], Vector2(272, gy), 11, Color.WHITE if bool(rec.stars[k]) else UIKit.DIM)
