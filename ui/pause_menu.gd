extends Control
## Pause overlay shown by the World. The World reacts to the three signals.

signal resume_pressed
signal restart_pressed
signal quit_pressed

const PANEL := Rect2(200, 62, 240, 236)

## Volumes remembered while a channel is switched off from here.
static var _saved := {}

var _opened_ms := 0
var _settings: Control
var _music_toggle: Button
var _sound_toggle: Button


func setup(_args: Dictionary) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_opened_ms = Time.get_ticks_msec()

	var resume := UIKit.make_button("Resume", Vector2(188, 30), UIKit.TEAL, 14, "play")
	UIKit.place(resume, PANEL.position.x + 26, PANEL.position.y + 48)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	add_child(resume)

	var restart := UIKit.make_button("Restart", Vector2(188, 30), UIKit.BLUE, 14)
	UIKit.place(restart, PANEL.position.x + 26, PANEL.position.y + 84)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	add_child(restart)

	var settings := UIKit.make_button("Settings", Vector2(188, 30), UIKit.BLUE, 14)
	UIKit.place(settings, PANEL.position.x + 26, PANEL.position.y + 120)
	settings.pressed.connect(_open_settings)
	add_child(settings)

	var quit := UIKit.make_button("Level map", Vector2(188, 30), UIKit.BLUE, 14)
	UIKit.place(quit, PANEL.position.x + 26, PANEL.position.y + 156)
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	add_child(quit)

	var muted: bool = Game.get_setting("muted")
	_music_toggle = UIKit.make_toggle(not muted and float(Game.get_setting("music")) > 0.001)
	UIKit.place(_music_toggle, PANEL.position.x + 54, PANEL.position.y + 200)
	_music_toggle.toggled.connect(_set_channel.bind("music"))
	add_child(_music_toggle)

	_sound_toggle = UIKit.make_toggle(not muted and float(Game.get_setting("sfx")) > 0.001)
	UIKit.place(_sound_toggle, PANEL.position.x + 168, PANEL.position.y + 200)
	_sound_toggle.toggled.connect(_set_channel.bind("sfx"))
	add_child(_sound_toggle)
	queue_redraw()


func _set_channel(on: bool, key: String) -> void:
	if on:
		if Game.get_setting("muted"):
			Game.set_setting("muted", false)
		var v := float(_saved.get(key, Game.DEFAULT_SETTINGS[key]))
		Game.set_setting(key, v if v > 0.001 else float(Game.DEFAULT_SETTINGS[key]))
	else:
		var cur := float(Game.get_setting(key))
		if cur > 0.001:
			_saved[key] = cur
		Game.set_setting(key, 0.0)


func _open_settings() -> void:
	_settings = load("res://ui/settings_screen.gd").new()
	add_child(_settings)
	_settings.setup({"overlay": true})
	_settings.closed.connect(func() -> void:
		_settings = null
		_opened_ms = Time.get_ticks_msec()
		_sync_toggles())


## Mirrors volume changes made in the settings overlay onto the quick toggles.
func _sync_toggles() -> void:
	var muted: bool = Game.get_setting("muted")
	_music_toggle.set_pressed_no_signal(not muted and float(Game.get_setting("music")) > 0.001)
	_sound_toggle.set_pressed_no_signal(not muted and float(Game.get_setting("sfx")) > 0.001)
	_music_toggle.text = "ON" if _music_toggle.button_pressed else "OFF"
	_sound_toggle.text = "ON" if _sound_toggle.button_pressed else "OFF"


func _input(event: InputEvent) -> void:
	if not visible or _settings != null or Time.get_ticks_msec() - _opened_ms < 250:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.1, 0.72))
	UIKit.draw_panel(self, PANEL, UIKit.PANEL, Color("3a78a8"), 10, 2)
	UIKit.draw_text(self, "PAUSED", Vector2(PANEL.position.x + PANEL.size.x * 0.5, PANEL.position.y + 12), 26, Color.WHITE, 1, 3)
	UIKit.draw_text(self, "Music", Vector2(PANEL.position.x + 14, PANEL.position.y + 203), 12, UIKit.DIM)
	UIKit.draw_text(self, "Sound", Vector2(PANEL.position.x + 124, PANEL.position.y + 203), 12, UIKit.DIM)
