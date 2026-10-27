extends Control
## End-of-run overlay: stars, coins, stats, level-up banner and Next / Retry / Map buttons.

const PANEL := Rect2(60, 76, 520, 148)

var _r: Dictionary = {}
var _t := 0.0
var _opened_ms := 0
var _coins_shown := 0
var _last_tick := 0.0
var _stars_seen := 0
var _next_ok := false


func setup(result: Dictionary) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_r = result
	_opened_ms = Time.get_ticks_msec()

	var track: String = String(_r.get("track", "castle"))
	var level: int = int(_r.get("level", 1))
	var endless: bool = bool(_r.get("endless", false))
	var won: bool = bool(_r.get("won", false))
	_next_ok = won and not endless and level < Game.level_count(track) and Game.is_level_unlocked(track, level + 1)

	var stats := UIKit.StatsBar.new()
	UIKit.place(stats, 71, 230)
	add_child(stats)

	var widths := [120.0, 120.0] if not _next_ok else [120.0, 120.0, 150.0]
	var total := 14.0 * (widths.size() - 1)
	for w in widths:
		total += float(w)
	var x := (640.0 - total) * 0.5

	var map_btn := UIKit.make_button("Level map", Vector2(120, 36), UIKit.BLUE, 13)
	UIKit.place(map_btn, x, 304)
	map_btn.pressed.connect(_go_map)
	add_child(map_btn)
	x += 134.0

	var retry := UIKit.make_button("Retry", Vector2(120, 36), UIKit.BLUE if _next_ok else UIKit.TEAL, 13)
	UIKit.place(retry, x, 304)
	retry.pressed.connect(_go_retry)
	add_child(retry)
	x += 134.0

	if _next_ok:
		var next := UIKit.make_button("Next", Vector2(150, 36), UIKit.TEAL, 15, "play")
		UIKit.place(next, x, 304)
		next.pressed.connect(_go_next)
		add_child(next)


func _go_map() -> void:
	Events.request_screen.emit("levels", {"track": String(_r.get("track", "castle"))})


func _go_retry() -> void:
	Game.start_level(String(_r.get("track", "castle")), int(_r.get("level", 1)), bool(_r.get("endless", false)))


func _go_next() -> void:
	Game.start_level(String(_r.get("track", "castle")), int(_r.get("level", 1)) + 1)


func _input(event: InputEvent) -> void:
	if Time.get_ticks_msec() - _opened_ms < 600:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			if _next_ok:
				_go_next()
			else:
				_go_retry()
		elif k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_go_map()


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.05)
	var coins := int(_r.get("coins", 0))
	var target := int(lerpf(0.0, float(coins), clampf((_t - 0.5) / 1.1, 0.0, 1.0)))
	if target != _coins_shown:
		_coins_shown = target
		if _t - _last_tick > 0.08:
			_last_tick = _t
			Sfx.play("coin", 0.12, -6.0)
	var stars: Array = _r.get("stars", [false, false, false])
	var seen := 0
	for i in 3:
		if _t > 0.3 + 0.35 * i:
			seen = i + 1
	if seen > _stars_seen:
		for i in range(_stars_seen, seen):
			if bool(stars[i]):
				Sfx.play("coin", 0.05)
		_stars_seen = seen
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw_lava() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a0408"))
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	draw_circle(Vector2(320, 380), 260.0, Color(1.0, 0.35, 0.05, 0.10 + 0.05 * pulse))
	draw_circle(Vector2(320, 380), 170.0, Color(1.0, 0.5, 0.1, 0.12 + 0.05 * pulse))
	var back := PackedVector2Array([Vector2(0, 300), Vector2(70, 252), Vector2(130, 290), Vector2(210, 232), Vector2(290, 285), Vector2(380, 240), Vector2(470, 290), Vector2(550, 246), Vector2(640, 285), Vector2(640, 360), Vector2(0, 360)])
	draw_colored_polygon(back, Color("4a1408"))
	var mid := PackedVector2Array([Vector2(0, 332), Vector2(90, 282), Vector2(170, 322), Vector2(260, 268), Vector2(350, 326), Vector2(450, 276), Vector2(540, 322), Vector2(640, 292), Vector2(640, 360), Vector2(0, 360)])
	draw_colored_polygon(mid, Color("b8300c"))
	var front := PackedVector2Array([Vector2(0, 350), Vector2(110, 312), Vector2(200, 346), Vector2(310, 302), Vector2(420, 346), Vector2(520, 310), Vector2(640, 342), Vector2(640, 360), Vector2(0, 360)])
	draw_colored_polygon(front, Color("ff7a18"))
	draw_polyline(front.slice(0, front.size() - 2), Color("ffd040"), 2.0)
	for i in 28:
		var ex := UIKit._rand(i, 1.0) * 640.0 + sin(_t + i) * 6.0
		var ey := fposmod(360.0 - _t * (18.0 + UIKit._rand(i, 2.0) * 34.0) - UIKit._rand(i, 3.0) * 400.0, 380.0)
		var a := clampf(ey / 200.0, 0.0, 1.0)
		draw_rect(Rect2(floorf(ex), floorf(ey), 2, 2), Color(1.0, 0.7 + 0.3 * UIKit._rand(i, 4.0), 0.2, a))


func _stat_row(y: float, label: String, value: String, icon := "") -> void:
	var x := 332.0
	if icon == "gold":
		UIKit.draw_coin(self, Vector2(x + 6.0, y + 8.0), 6.0)
	elif icon == "keys":
		UIKit.draw_key(self, Vector2(x + 7.0, y + 8.0), 16.0)
	UIKit.draw_text(self, label, Vector2(x + 20.0, y + 2.0), 12, UIKit.DIM)
	UIKit.draw_text_fit(self, value, Vector2(PANEL.end.x - 14.0, y), 14, 120.0, Color.WHITE, 2)


func _draw() -> void:
	_draw_lava()
	var won: bool = bool(_r.get("won", false))
	var endless: bool = bool(_r.get("endless", false))
	var track: String = String(_r.get("track", "castle"))
	var summary: Dictionary = _r.get("summary", {})
	var title := "LEVEL CLEAR!"
	var title_col := UIKit.GOLD
	if endless:
		title = "RUN OVER"
		title_col = UIKit.ORANGE
	elif not won:
		title = "DEFEATED"
		title_col = Color("ff5a4a")
	UIKit.draw_text(self, title, Vector2(320, 6), 30, title_col, 1, 4)
	UIKit.draw_text_fit(self, String(_r.get("level_name", "")), Vector2(320, 49), 14, 400.0, Color.WHITE, 1, 2)
	if bool(summary.get("new_best", false)):
		var pulse := 1.0 + 0.08 * sin(_t * 8.0)
		UIKit.draw_crown(self, Vector2(534, 30), 16.0 * pulse)
		UIKit.draw_text(self, "NEW BEST!", Vector2(630, 21), 14, UIKit.GOLD, 2, 2)

	UIKit.draw_panel(self, PANEL, Color(0.04, 0.03, 0.06, 0.82), Color("8a3a18"), 10, 2)
	if endless:
		_draw_endless_left(track)
	else:
		_draw_star_rows()
	_stat_row(PANEL.position.y + 10.0, "Coins", UIKit.fmt_int(_coins_shown), "gold")
	_stat_row(PANEL.position.y + 36.0, "Keys", UIKit.fmt_int(int(_r.get("keys", 0))), "keys")
	_stat_row(PANEL.position.y + 62.0, "Time", UIKit.fmt_time(float(_r.get("time", 0.0))))
	_stat_row(PANEL.position.y + 88.0, "Max combo", "x%d" % int(_r.get("max_combo", 0)))
	var total := int(_r.get("enemies_total", 0))
	var kills := int(_r.get("kills", 0))
	_stat_row(PANEL.position.y + 114.0, "Kills", ("%d / %d" % [kills, total]) if total > 0 else str(kills))
	draw_line(Vector2(320, PANEL.position.y + 12.0), Vector2(320, PANEL.end.y - 12.0), Color(1, 1, 1, 0.12), 1.0)

	if int(summary.get("level_after", 0)) > int(summary.get("level_before", 0)):
		var pulse2 := 0.5 + 0.5 * sin(_t * 6.0)
		var r := Rect2(150, 266, 340, 26)
		UIKit.draw_panel(self, r, Color(0.35, 0.22, 0.02, 0.9), UIKit.GOLD.lerp(Color.WHITE, pulse2 * 0.5), 8, 2)
		UIKit.draw_text(self, "LEVEL UP!  Dragon Lv %d -> %d" % [int(summary.level_before), int(summary.level_after)], Vector2(320, 271), 14, Color("fff0a0"), 1, 1)


func _draw_star_rows() -> void:
	var stars: Array = _r.get("stars", [false, false, false])
	var labels: Array = _r.get("star_labels", ["", "", ""])
	for i in 3:
		var y := PANEL.position.y + 12.0 + i * 44.0
		var shown := _stars_seen > i
		var earned := bool(stars[i]) if i < stars.size() else false
		var pop := clampf((_t - (0.3 + 0.35 * i)) / 0.25, 0.0, 1.0)
		var scale_f := 1.0 + (1.0 - pop) * 0.8 if pop < 1.0 else 1.0
		var c := Vector2(PANEL.position.x + 30.0, y + 18.0)
		UIKit.draw_panel(self, Rect2(PANEL.position.x + 10.0, y, 296.0, 36.0), Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 8, 0)
		UIKit.draw_star(self, c, 12.0 * scale_f if (shown and earned) else 12.0, shown and earned)
		var text := String(labels[i]) if i < labels.size() else ""
		UIKit.draw_text_fit(self, text, Vector2(PANEL.position.x + 52.0, y + 10.0), 13, 240.0, Color.WHITE if earned else UIKit.DIM)


func _draw_endless_left(track: String) -> void:
	var is_castle := track == "castle"
	var value := int(_r.get("distance", 0)) if is_castle else int(_r.get("rooms", 0))
	var unit := "m" if is_castle else (" rooms" if value != 1 else " room")
	var cx := PANEL.position.x + 130.0
	UIKit.draw_text(self, "Distance" if is_castle else "Rooms cleared", Vector2(cx, PANEL.position.y + 18.0), 13, UIKit.DIM, 1)
	UIKit.draw_text_fit(self, "%s%s" % [UIKit.fmt_int(value), unit if is_castle else ""], Vector2(cx, PANEL.position.y + 40.0), 34, 230.0, Color.WHITE, 1, 3)
	var best := int(Game.endless_record(track).best)
	var line := "Best: %s%s" % [UIKit.fmt_int(best), " m" if is_castle else " rooms"]
	var w := UIKit.text_width(line, 13) + 18.0
	UIKit.draw_crown(self, Vector2(cx - w * 0.5 + 6.0, PANEL.position.y + 100.0), 12.0)
	UIKit.draw_text(self, line, Vector2(cx - w * 0.5 + 18.0, PANEL.position.y + 92.0), 13, UIKit.GOLD)
