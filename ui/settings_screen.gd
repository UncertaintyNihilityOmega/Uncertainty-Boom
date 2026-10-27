extends Control
## Settings: volume, display, gameplay options, controls reference and save deletion.

const LEFT_PANEL := Rect2(8, 42, 304, 310)
const RIGHT_PANEL := Rect2(322, 42, 310, 310)
const SLIDERS := [["master", "Master"], ["music", "Music"], ["sfx", "Sound FX"]]
const CONTROLS := [
	["A / D", "Run and steer"],
	["W (+A/D)", "Jump / dash up or diagonally"],
	["S (+A/D)", "Slide; in air: dash down or slam"],
	["Left mouse", "Fire toward cursor (hold = auto-fire)"],
	["Right mouse", "Hold: slow-mo + aim, release: dash"],
	["Shift", "Dash toward cursor (no limit)"],
	["E / R", "Toggle slow-mo / auto-attack nearest"],
	["Esc / P", "Pause"],
]

var _t := 0.0
var _sliders := {}
var _toggles := {}
var _dialog: Control
var _message_time := 0.0


## Emitted when the overlay version (opened from the pause menu) closes.
signal closed

var _overlay := false


## args.overlay = true: opened on top of the pause menu; Back closes it.
func setup(args: Dictionary) -> void:
	size = Vector2(640, 360)
	_overlay = args.get("overlay", false)
	if _overlay:
		process_mode = Node.PROCESS_MODE_ALWAYS
		mouse_filter = Control.MOUSE_FILTER_STOP

	var back := UIKit.make_button("Back", Vector2(64, 26), UIKit.BLUE, 12, "left")
	UIKit.place(back, 6, 5)
	back.pressed.connect(_back)
	add_child(back)

	for i in SLIDERS.size():
		var key: String = SLIDERS[i][0]
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01
		s.value = float(Game.get_setting(key))
		UIKit.style_slider(s)
		UIKit.place(s, 92, 73 + i * 26, 160, 16)
		s.value_changed.connect(func(v: float) -> void:
			Game.set_setting(key, v)
			queue_redraw())
		s.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("ui_click"))
		add_child(s)
		_sliders[key] = s

	_add_toggle("muted", Vector2(246, 175))
	_add_toggle("fullscreen", Vector2(246, 201))
	_add_toggle("screen_shake", Vector2(246, 227))
	_add_toggle("keyboard_mode", Vector2(566, 66))
	_add_toggle("creative", Vector2(566, 132))

	var del := UIKit.make_button("Delete save", Vector2(150, 28), UIKit.RED, 12)
	UIKit.place(del, 85, 312)
	del.pressed.connect(func() -> void: _dialog.visible = true)
	# Deleting the save in the middle of a level is not offered.
	del.disabled = _overlay
	add_child(del)

	_build_dialog()
	Events.save_reset.connect(_sync_from_settings)


func _add_toggle(key: String, pos: Vector2) -> void:
	var t := UIKit.make_toggle(bool(Game.get_setting(key)))
	UIKit.place(t, pos.x, pos.y)
	t.toggled.connect(func(v: bool) -> void: Game.set_setting(key, v))
	add_child(t)
	_toggles[key] = t


func _sync_from_settings() -> void:
	for key in _toggles.keys():
		var t: Button = _toggles[key]
		t.set_pressed_no_signal(bool(Game.get_setting(key)))
		t.text = "ON" if t.button_pressed else "OFF"
	for key in _sliders.keys():
		(_sliders[key] as HSlider).set_value_no_signal(float(Game.get_setting(key)))
	queue_redraw()


func _build_dialog() -> void:
	_dialog = Control.new()
	_dialog.size = Vector2(640, 360)
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.visible = false
	_dialog.draw.connect(func() -> void:
		_dialog.draw_rect(Rect2(0, 0, 640, 360), Color(0.01, 0.03, 0.08, 0.78))
		var r := Rect2(150, 110, 340, 140)
		UIKit.draw_panel(_dialog, r, UIKit.PANEL, Color("e04848"), 10, 2)
		UIKit.draw_text(_dialog, "Delete all progress?", Vector2(320, 124), 18, Color.WHITE, 1)
		UIKit.draw_text(_dialog, "This cannot be undone.", Vector2(320, 152), 12, Color("ffb0b0"), 1))
	add_child(_dialog)
	var cancel := UIKit.make_button("Cancel", Vector2(120, 30), UIKit.BLUE, 12)
	UIKit.place(cancel, 180, 198)
	cancel.pressed.connect(func() -> void: _dialog.visible = false)
	_dialog.add_child(cancel)
	var confirm := UIKit.make_button("Delete", Vector2(120, 30), UIKit.RED, 12)
	UIKit.place(confirm, 340, 198)
	confirm.pressed.connect(func() -> void:
		Game.reset_save()
		_dialog.visible = false
		_message_time = 3.0)
	_dialog.add_child(confirm)


func _process(delta: float) -> void:
	_t += delta
	_message_time = maxf(0.0, _message_time - delta)
	queue_redraw()


func _back() -> void:
	if _overlay:
		closed.emit()
		queue_free()
	else:
		Events.request_screen.emit("menu", {})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _dialog.visible:
			_dialog.visible = false
		else:
			_back()


func _draw() -> void:
	UIKit.draw_night_background(self, size, _t, 0, false)
	draw_rect(Rect2(0, 0, 640, 36), Color(0.02, 0.06, 0.14, 0.55))
	draw_rect(Rect2(0, 36, 640, 2), Color("1a4a6a"))
	UIKit.draw_text(self, "SETTINGS", Vector2(320, 7), 20, Color.WHITE, 1, 2)
	UIKit.draw_panel(self, LEFT_PANEL, UIKit.PANEL, Color("3a78a8"), 8, 2)
	UIKit.draw_panel(self, RIGHT_PANEL, UIKit.PANEL, Color("3a78a8"), 8, 2)

	# Left: audio and display.
	UIKit.draw_text(self, "AUDIO", Vector2(20, 51), 12, UIKit.TEAL)
	for i in SLIDERS.size():
		var key: String = SLIDERS[i][0]
		UIKit.draw_text(self, String(SLIDERS[i][1]), Vector2(20, 71 + i * 26), 12, Color.WHITE)
		UIKit.draw_text(self, "%d%%" % int(round(float(Game.get_setting(key)) * 100.0)), Vector2(300, 71 + i * 26), 12, UIKit.DIM, 2)
	UIKit.draw_text(self, "DISPLAY", Vector2(20, 152), 12, UIKit.TEAL)
	UIKit.draw_text(self, "Mute all", Vector2(20, 177), 12, Color.WHITE)
	UIKit.draw_text(self, "Fullscreen", Vector2(20, 203), 12, Color.WHITE)
	UIKit.draw_text(self, "Screen shake", Vector2(20, 229), 12, Color.WHITE)
	UIKit.draw_text(self, "DATA", Vector2(20, 266), 12, UIKit.TEAL)
	UIKit.draw_wrapped(self, "Removes all progress, gold, keys and unlocks.", Vector2(20, 284), 280.0, 10, UIKit.DIM, 2)
	if _message_time > 0.0:
		UIKit.draw_text(self, "Save deleted.", Vector2(160, 342), 11, Color("ffb0b0"), 1)

	# Right: gameplay options and controls.
	var x := RIGHT_PANEL.position.x + 12.0
	UIKit.draw_text(self, "GAMEPLAY", Vector2(x, 51), 12, UIKit.TEAL)
	UIKit.draw_text(self, "Keyboard-only mode", Vector2(x, 69), 12, Color.WHITE)
	UIKit.draw_wrapped(self, "Play without a mouse: Shift dashes in your WASD direction, R aims at the nearest enemy.", Vector2(x, 90), 286.0, 10, UIKit.DIM, 3)
	UIKit.draw_text(self, "Creative mode", Vector2(x, 135), 12, Color.WHITE)
	UIKit.draw_wrapped(self, "Infinite gold & keys, all levels unlocked. For testing.", Vector2(x, 156), 286.0, 10, UIKit.DIM, 2)
	UIKit.draw_text(self, "CONTROLS", Vector2(x, 186), 12, UIKit.TEAL)
	for i in CONTROLS.size():
		var y := 206.0 + i * 17.0
		UIKit.draw_text(self, String(CONTROLS[i][0]), Vector2(x, y), 11, UIKit.GOLD)
		UIKit.draw_text_fit(self, String(CONTROLS[i][1]), Vector2(x + 76.0, y), 11, 208.0, Color("d8e8f8"))
