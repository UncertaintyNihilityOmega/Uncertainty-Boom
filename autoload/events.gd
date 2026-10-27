extends Node
## Global signal bus. Lifecycle / cross-screen events only.

## Screen routing: "menu", "levels", "nest", "settings", "achievements", "world".
signal request_screen(screen: String, args: Dictionary)

signal enemy_killed(kind: String, pos: Vector2, airborne: bool)
signal combo_changed(combo: int)
signal player_hurt(hearts_left: int)
signal level_finished(result: Dictionary)

signal achievement_unlocked(id: String)
signal currency_changed
signal settings_changed
signal save_reset
