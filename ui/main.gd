extends Node
## Screen router. Swaps the active screen when Events.request_screen fires.
##
## Debug command-line options (after `--`):
##   --screen=nest              open a screen directly
##   --level=castle:3           start a level directly (castle|dungeon, n | endless)
##   --screenshot=C:/x.png      save a screenshot after --frames=N frames, then quit
##   --frames=60                frame count for --screenshot (default 45)
##   --shotscale=2              upscale the screenshot (nearest neighbour)
##   --creative                 force creative mode for this session
##   --save=NAME                use user://save_NAME.dat instead of the real save
##   --autoplay                 a simple bot dashes rightwards and auto-attacks
##   --attack=meteor            equip an attack style (test saves only)
##   --pause / --pause=settings open the pause menu (and its settings) after 1 s

const SCREENS := {
	"menu": "res://ui/main_menu.gd",
	"levels": "res://ui/level_select.gd",
	"nest": "res://ui/nest.gd",
	"settings": "res://ui/settings_screen.gd",
	"achievements": "res://ui/achievements_screen.gd",
	"world": "res://game/level/world.gd",
}

var current: Node
var _shot_path := ""
var _shot_frames := 45
var _shot_scale := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.request_screen.connect(_on_request_screen)
	if ResourceLoader.exists("res://ui/toast.gd"):
		add_child(load("res://ui/toast.gd").new())
	var start := "menu"
	var start_args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		var key := parts[0]
		var value := parts[1] if parts.size() > 1 else ""
		match key:
			"screen":
				start = value
			"level":
				var lv := value.split(":")
				start = "world"
				start_args = {"track": lv[0], "level": 1 if lv[1] == "endless" else int(lv[1]), "endless": lv[1] == "endless"}
				Game.current = start_args.duplicate()
			"screenshot":
				_shot_path = value
			"frames":
				_shot_frames = int(value)
			"shotscale":
				_shot_scale = maxi(1, int(value))
			"creative":
				Game.data.settings.creative = true
			"save":
				Game.use_save_file("user://save_%s.dat" % value)
			"autoplay":
				Game.set_meta("autoplay", true)
			"pause":
				Game.set_meta("debug_pause", value)
			"attack":
				if not Game.owns_attack(value):
					Game.data.owned_attacks.append(value)
				Game.data.equipped_attack = value
	_on_request_screen.call_deferred(start, start_args)


func _process(_delta: float) -> void:
	if _shot_path == "":
		return
	_shot_frames -= 1
	if _shot_frames <= 0:
		var img := get_viewport().get_texture().get_image()
		if _shot_scale > 1:
			img.resize(img.get_width() * _shot_scale, img.get_height() * _shot_scale, Image.INTERPOLATE_NEAREST)
		img.save_png(_shot_path)
		get_tree().quit()


func _on_request_screen(screen: String, args: Dictionary) -> void:
	if not SCREENS.has(screen):
		push_error("Unknown screen: " + screen)
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if is_instance_valid(current):
		current.queue_free()
	current = load(SCREENS[screen]).new()
	# The router itself always runs (debug screenshots), but screens must pause.
	current.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(current)
	move_child(current, 0)
	current.setup(args)
	if screen != "world":
		Sfx.play_music("menu")
