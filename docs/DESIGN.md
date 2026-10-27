# Uncertainty Boom — Design & Code Contracts

Godot **4.6.1**, GDScript, renderer `gl_compatibility`. Pixel look: game renders at
**640x360** (stretch mode `viewport`, nearest filtering) and is scaled up to the window.
All art is drawn in code with simple vector shapes (`_draw()`), so there are no image assets.
All audio is synthesized at runtime (`autoload/sfx.gd`).

## Game summary
A small, rebellious dragon raids castles and dungeons.
- **Castle track:** 20 side-scrolling levels plus **Endless Castles** (random chunks forever).
  Goal: reach the treasure chest at the end. Stars: Treasure ≥ 90% coins, no hearts lost, all enemies killed.
- **Dungeon track:** 20 levels made of closed rooms plus **Endless Dungeon** (random rooms forever).
  Clear every wave in a room, the door opens, then move on. Timer runs. Keys drop.
  Stars: all keys collected, max combo ≥ target, time ≤ par.
- **Progression:** gold collected → *lifetime gold* → **dragon level** (+4% damage per level).
  Gold is also the wallet: **attack styles (60) are bought with gold** (need a dragon level too).
  **Keys** (from dungeons & treasure chests) buy **dragon skins (6, cosmetic)**.
- **Slow-mo meter:** slow-mo drains it, kills/hits refill it, and it regenerates slowly.

## Controls
See the table in README.md. Movement is dash-and-fall: W/S combined with A/D dash in that
direction (W alone on the ground jumps, S on the ground slides, S alone in the air smash-dives),
Shift dashes toward the cursor, dashes are unlimited and can cancel each other. E toggles
slow motion, right mouse holds slow motion while aiming a slingshot dash, R auto-attacks.
Keyboard-only mode makes Shift dash in the WASD direction.

## Folder layout
```
autoload/events.gd           Events  (signal bus)
autoload/game.gd             Game    (save, currencies, unlocks, stats, achievements, settings, input map)
autoload/sfx.gd              Sfx     (procedural sfx + music)
data/attack_db.gd            AttackDB       60 attack styles
data/dragon_db.gd            DragonDB       6 skins
data/level_db.gd             LevelDB        40 level param sets
data/enemy_db.gd             EnemyDB        22 enemy defs
data/achievement_db.gd       AchievementDB  60 achievements
game/player/dragon.gd        Dragon     the player
game/player/dragon_art.gd    DragonArt  static drawing of a dragon skin
game/player/projectile.gd    PlayerShot
game/player/rain_cloud.gd    RainCloud  storm cloud for "rain" attacks
game/enemies/enemy.gd        Enemy      all 22 behaviours + art
game/enemies/enemy_shot.gd   EnemyShot  arrows, bombs, bolts, orbs…
game/level/world.gd          World      runs a level
game/level/level_gen.gd      LevelGen   terrain + placement
game/level/chunk.gd          Chunk      terrain slice (collision + drawing)
game/level/background.gd     parallax backdrop
game/level/pickup.gd         Pickup     coins/keys/hearts/chest
game/level/fx.gd             Fx         particles/popups/shake
game/level/hud.gd            HUD
ui/main.gd                   screen router (scenes/main.tscn)
ui/ui_kit.gd                 shared styles/widgets
ui/*.gd                      menus / overlays (the Nest is ui/nest.gd)
```

## Physics layers (bit values)
world=1, player=2, enemies=4, player_shots=8, enemy_shots=16, pickups=32.
Enemies: `collision_layer = 4`, `collision_mask = 1 | 4` (ghosts: 0). Dragon: `layer 2`, `mask 1`.
Projectiles do **manual** hit detection (no Area2D) using distance checks and
`PhysicsDirectSpaceState2D` queries against the world.

## Scale & palette
- Dragon is ~16 px long. Small enemies ~10–14 px tall, bosses 28–40 px.
- Gravity 900 px/s². Screen 640x360. Castle levels ~3000–8000 px long, 540 px tall.
- Palette: navy sky `#0d2a44`, moon `#e0f08a`, grass `#00a07a`, stone `#14b4f0`,
  enemy accent orange `#ff8a20`, enemy skin `#ffd0a0`, steel `#c8d0e0`, black smoke.
- Enemies read as "medieval troops": orange helmets/plumes, small shields, cone hats for mages.

## Contract: World (game/level/world.gd) — what enemies may call
Enemies hold `var world` **untyped** (duck typing) and use only:
- `world.player` → Dragon node (or null). Use `world.player.global_position`, `.velocity`,
  `.dead` (bool), `.hurt(amount: int, from: Vector2)`, `.apply_slow(seconds: float)`,
  `.is_invulnerable() -> bool`, `.HURT_RADIUS` (float, ~6).
- `world.fx` → Fx node: `explosion(pos, radius := 16.0, color := Color(1,0.5,0.1))`,
  `sparks(pos, color, count := 6, speed := 120.0)`, `smoke(pos, count := 3, size := 6.0)`,
  `popup(pos, text: String, color := Color.WHITE)`, `shake(strength: float)`,
  `ring(pos, radius: float, color: Color)`, `line(a, b, color, width := 2.0, life := 0.15)`,
  `debris(pos, color, count := 6)`.
- `world.shots_layer` → Node2D to add `EnemyShot` nodes into.
- `world.enemies_layer` → Node2D to add spawned minions into (use `world.spawn_enemy(kind, pos)`).
- `world.spawn_enemy(kind: String, pos: Vector2) -> Node` (for slimes splitting, warlord summons).
- `world.on_enemy_hit(enemy, was_airborne: bool)` — call on every damaging hit (combo).
- `world.on_enemy_died(enemy)` — call exactly once when hp hits 0 (drops, stats, combo).
- `world.difficulty` → float ≥ 1.0. Scale fire rates / projectile speed / hp with it gently.
- `world.is_active_pos(pos: Vector2) -> bool` — true when pos is near the camera view.
  Enemies must **not attack** while this is false (avoid off-screen snipes).
- `world.is_solid(pos: Vector2) -> bool` — terrain point test (ledge detection, shot impact).
- `world.ground_y(x: float, from_y: float) -> float` — y of first solid surface below.

## Contract: Enemy (game/enemies/enemy.gd, `class_name Enemy extends CharacterBody2D`)
- Created by World: `var e := Enemy.new(); e.setup(kind, world); e.position = p; enemies_layer.add_child(e)`.
- Fields: `kind: String`, `def: Dictionary` (from EnemyDB), `hp: float`, `max_hp: float`,
  `dead: bool`, `world` (untyped).
- `func take_hit(dmg: float, knock: Vector2, effect := "", source := "shot") -> void`
  - `source` is `"shot" | "dash" | "slam" | "explosion" | "chain"`.
  - `effect`: `"burn"` (DOT), `"freeze"` (slow 50% 2 s, tint blue), `"shock"` (stun 0.6 s), `"poison"` (DOT, green).
  - knockback launches enemies into the air (juggling!). Bosses/stationary resist knock.
  - Must call `world.on_enemy_hit(self, is_airborne())` then on death
    `world.on_enemy_died(self)` and `queue_free()` (after spawning death FX).
- `func is_airborne() -> bool`, `func get_radius() -> float` (rough body radius for hit tests).
- Adds itself to group `"enemies"` (bosses also `"bosses"`).
- Draws itself in `_draw()` (pixel-ish vector shapes, ~10–14 px; flashes white when hit, HP bar for bosses).
- Melee damage: touching the dragon calls `world.player.hurt(1, global_position)`.

## Contract: EnemyDB (data/enemy_db.gd)
`EnemyDB.ALL[kind] = {name, hp, gold, flying: bool, stationary: bool, boss: bool, desc}` plus whatever the enemy agent needs.
**The 22 kinds** (fixed — LevelDB uses these ids):
`squire, knight, archer, crossbow, bomber, spearman, mage, cleric, balloon, rocketeer,
ballista, cannon, catapult, berserker, ice_mage, bat, slime, skeleton, arrow_trap, ghost,
golden_knight (mini-boss), warlord (boss)`.

## Contract: Player shots → enemies
`PlayerShot` finds enemies by distance (`enemy.get_radius()`) from group `"enemies"`,
and calls `take_hit`. It destroys enemy shots in group `"enemy_shots"` that it touches
(EnemyShot must implement `destroy()`), except shots with `meta "indestructible"`.

## Contract: UI screens
Router `ui/main.gd` creates screens by name: `menu, levels, nest, settings, achievements, world`.
Each screen script: `extends Control`, implements `func setup(args: Dictionary) -> void`,
fills the 640x360 viewport. Navigation only via `Events.request_screen.emit(name, args)`.
- `levels` args: `{"track": "castle"|"dungeon"}` (optional).
- Start a level: `Game.start_level(track, n, endless := false)`.
Overlays the World instantiates (on its HUD CanvasLayer, `process_mode = ALWAYS`):
- `ui/pause_menu.gd` — `setup({})`; signals `resume_pressed`, `restart_pressed`, `quit_pressed`.
- `ui/results_screen.gd` — `setup(result)`; buttons navigate by themselves
  (next → `Game.start_level(track, n+1)`, retry → same level, map → `levels`).
- `ui/toast.gd` — CanvasLayer added by main.gd; listens to `Events.achievement_unlocked`.

### Result dictionary (World → results screen)
```
{track, level, endless, won: bool, level_name,
 coins, keys, kills, enemies_total, coins_collected, coins_total, hearts_lost, max_combo,
 time: float, distance: int (endless castle, metres), rooms: int (dungeon rooms cleared),
 keys_total, par_time, combo_target,
 stars: [bool, bool, bool], star_labels: [String, String, String],
 summary: {new_stars, new_best, level_before, level_after}}
```

## Stats (for achievements; `Game.get_stat(name)`)
Counters: `kills, kills_<kind>, airborne_kills, bosses_killed, dashes, dash_kills, slam_kills,
slowmo_seconds, deaths, hits_taken, flawless_levels, gold_spent, keys_earned, chests_opened,
shots_fired, shots_destroyed, levels_played, coins_collected, max_combo, burn_kills,
freeze_kills, shock_kills, poison_kills, endless_runs`.
Computed: `castle_cleared, dungeon_cleared, castle_stars, dungeon_stars, total_stars,
attacks_owned, dragons_owned, dragon_level, gold_earned, endless_castle_best (m),
endless_dungeon_best (rooms), achievements`.
