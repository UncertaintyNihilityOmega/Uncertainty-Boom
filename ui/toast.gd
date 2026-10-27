extends CanvasLayer
## Slide-in banner "Achievement unlocked!" at the top centre. Several unlocks are queued.

const SHOW_TIME := 2.5
const BANNER := Vector2(292, 36)
const HIDDEN_Y := -42.0

var _queue: Array[String] = []
var _busy := false
var _banner: Control
var _ach_name := ""


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_banner = Control.new()
	_banner.size = BANNER
	_banner.position = Vector2((640.0 - BANNER.x) * 0.5, HIDDEN_Y)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	_banner.draw.connect(_draw_banner)
	add_child(_banner)
	Events.achievement_unlocked.connect(_on_unlocked)


func _on_unlocked(id: String) -> void:
	_queue.append(id)
	if not _busy:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		_banner.visible = false
		return
	_busy = true
	var id: String = _queue.pop_front()
	var entry := AchievementDB.find(id)
	_ach_name = String(entry.get("name", id))
	_banner.position.y = HIDDEN_Y
	_banner.visible = true
	_banner.queue_redraw()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.tween_property(_banner, "position:y", 8.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SHOW_TIME)
	tw.tween_property(_banner, "position:y", HIDDEN_Y, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.finished.connect(_show_next)


func _draw_banner() -> void:
	var r := Rect2(Vector2.ZERO, BANNER)
	UIKit.draw_panel(_banner, r, Color("1a2a44"), UIKit.GOLD, 8, 2)
	UIKit.draw_trophy(_banner, Vector2(22, 19), 24.0)
	UIKit.draw_text(_banner, "Achievement unlocked!", Vector2(42, 4), 10, UIKit.GOLD)
	UIKit.draw_text_fit(_banner, _ach_name, Vector2(42, 17), 13, BANNER.x - 50.0, Color.WHITE)
