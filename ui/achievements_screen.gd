extends Control
## Scrollable list of all achievements with progress bars.

var _t := 0.0


## One achievement card.
class Card extends Control:
	var entry: Dictionary = {}
	var unlocked := false
	var value := 0

	func _init(e: Dictionary) -> void:
		entry = e
		custom_minimum_size = Vector2(304, 50)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		unlocked = Game.is_achievement_unlocked(String(e.id))
		value = Game.get_stat(String(e.stat))

	func _draw() -> void:
		var goal := int(entry.goal)
		var shown := goal if unlocked else mini(value, goal)
		if unlocked:
			UIKit.draw_panel(self, Rect2(Vector2.ZERO, size), Color("3c3210"), UIKit.GOLD, 8, 2)
		else:
			UIKit.draw_panel(self, Rect2(Vector2.ZERO, size), UIKit.PANEL, Color("26506e"), 8, 2)
		UIKit.draw_trophy(self, Vector2(24, 25), 30.0, UIKit.GOLD if unlocked else Color("4a5c76"))
		UIKit.draw_text_fit(self, String(entry.name), Vector2(46, 5), 12, 250.0, Color("fff0b0") if unlocked else Color.WHITE)
		UIKit.draw_text_fit(self, String(entry.desc), Vector2(46, 20), 10, 250.0, Color("e8d8a0") if unlocked else UIKit.DIM)
		var bar := Rect2(46, 35, 150, 9)
		UIKit.draw_panel(self, bar, Color("0a1c30"), Color("26506e"), 4, 1)
		var ratio := clampf(float(shown) / maxf(1.0, float(goal)), 0.0, 1.0)
		if ratio > 0.0:
			UIKit.draw_panel(self, Rect2(bar.position + Vector2(1, 1), Vector2(maxf(4.0, (bar.size.x - 2.0) * ratio), bar.size.y - 2.0)), UIKit.GOLD if unlocked else UIKit.TEAL, Color(0, 0, 0, 0), 3)
		if unlocked:
			UIKit.draw_text(self, "Unlocked", Vector2(204, 33), 10, UIKit.GOLD)
		else:
			UIKit.draw_text_fit(self, "%s / %s" % [UIKit.fmt_int(shown), UIKit.fmt_int(goal)], Vector2(204, 33), 10, 94.0, UIKit.DIM)


func setup(_args: Dictionary) -> void:
	size = Vector2(640, 360)

	var back := UIKit.make_button("Back", Vector2(64, 26), UIKit.BLUE, 12, "left")
	UIKit.place(back, 6, 5)
	back.pressed.connect(_back)
	add_child(back)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 42)
	scroll.size = Vector2(624, 310)
	UIKit.style_scroll(scroll)
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for a in AchievementDB.ALL:
		grid.add_child(Card.new(a))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _back() -> void:
	Events.request_screen.emit("menu", {})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _draw() -> void:
	UIKit.draw_night_background(self, size, _t, 0, false)
	draw_rect(Rect2(0, 0, 640, 36), Color(0.02, 0.06, 0.14, 0.55))
	draw_rect(Rect2(0, 36, 640, 2), Color("1a4a6a"))
	UIKit.draw_text(self, "ACHIEVEMENTS", Vector2(320, 7), 20, Color.WHITE, 1, 2)
	var total := AchievementDB.ALL.size()
	var label := "%d / %d unlocked" % [Game.get_stat("achievements"), total]
	UIKit.draw_trophy(self, Vector2(626.0 - UIKit.text_width(label, 14) - 14.0, 19), 22.0)
	UIKit.draw_text(self, label, Vector2(630, 10), 14, UIKit.GOLD, 2)
