class_name AchievementDB
## 60 achievements. Each one unlocks when Game.get_stat(stat) >= goal.

const ALL := [
	# ---- Kills
	{"id": "first_blood", "name": "First Blood", "desc": "Defeat your first enemy.", "stat": "kills", "goal": 1},
	{"id": "pest_control", "name": "Pest Control", "desc": "Defeat 100 enemies.", "stat": "kills", "goal": 100},
	{"id": "dragon_menace", "name": "Dragon Menace", "desc": "Defeat 1,000 enemies.", "stat": "kills", "goal": 1000},
	{"id": "extinction_event", "name": "Extinction Event", "desc": "Defeat 10,000 enemies.", "stat": "kills", "goal": 10000},
	{"id": "squire_squasher", "name": "Squire Squasher", "desc": "Defeat 50 Squires.", "stat": "kills_squire", "goal": 50},
	{"id": "bomb_disposal", "name": "Bomb Disposal", "desc": "Defeat 30 Bombers.", "stat": "kills_bomber", "goal": 30},
	{"id": "ghostbuster", "name": "Ghostbuster", "desc": "Defeat 25 Ghosts.", "stat": "kills_ghost", "goal": 25},
	# ---- Combos and tricks
	{"id": "warming_up", "name": "Warming Up", "desc": "Reach a x5 combo.", "stat": "max_combo", "goal": 5},
	{"id": "combo_artist", "name": "Combo Artist", "desc": "Reach a x10 combo.", "stat": "max_combo", "goal": 10},
	{"id": "combo_master", "name": "Combo Master", "desc": "Reach a x20 combo.", "stat": "max_combo", "goal": 20},
	{"id": "combo_legend", "name": "Combo Legend", "desc": "Reach a x40 combo.", "stat": "max_combo", "goal": 40},
	{"id": "juggler", "name": "Juggler", "desc": "Defeat 100 enemies in mid-air.", "stat": "airborne_kills", "goal": 100},
	{"id": "shoulder_charge", "name": "Shoulder Charge", "desc": "Defeat 25 enemies with a dash.", "stat": "dash_kills", "goal": 25},
	{"id": "ground_pounder", "name": "Ground Pounder", "desc": "Defeat 25 enemies with a slam.", "stat": "slam_kills", "goal": 25},
	{"id": "bullet_time", "name": "Bullet Time", "desc": "Spend 120 seconds in slow motion.", "stat": "slowmo_seconds", "goal": 120},
	# ---- Castles and dungeons
	{"id": "castle_crasher", "name": "Castle Crasher", "desc": "Clear 1 castle.", "stat": "castle_cleared", "goal": 1},
	{"id": "siege_master", "name": "Siege Master", "desc": "Clear 5 castles.", "stat": "castle_cleared", "goal": 5},
	{"id": "royal_wrecker", "name": "Royal Wrecker", "desc": "Clear 10 castles.", "stat": "castle_cleared", "goal": 10},
	{"id": "kingdom_come", "name": "Kingdom Come", "desc": "Clear all 20 castles.", "stat": "castle_cleared", "goal": 20},
	{"id": "delver", "name": "Delver", "desc": "Clear 1 dungeon.", "stat": "dungeon_cleared", "goal": 1},
	{"id": "dungeon_crawler", "name": "Dungeon Crawler", "desc": "Clear 5 dungeons.", "stat": "dungeon_cleared", "goal": 5},
	{"id": "deep_diver", "name": "Deep Diver", "desc": "Clear 10 dungeons.", "stat": "dungeon_cleared", "goal": 10},
	{"id": "dungeon_overlord", "name": "Dungeon Overlord", "desc": "Clear all 20 dungeons.", "stat": "dungeon_cleared", "goal": 20},
	# ---- Stars
	{"id": "castle_stargazer", "name": "Castle Stargazer", "desc": "Earn 30 stars in castles.", "stat": "castle_stars", "goal": 30},
	{"id": "starlit_cellars", "name": "Starlit Cellars", "desc": "Earn 30 stars in dungeons.", "stat": "dungeon_stars", "goal": 30},
	{"id": "rising_star", "name": "Rising Star", "desc": "Earn 50 stars in total.", "stat": "total_stars", "goal": 50},
	{"id": "constellation", "name": "Constellation", "desc": "Earn all 120 stars.", "stat": "total_stars", "goal": 120},
	{"id": "untouchable", "name": "Untouchable", "desc": "Earn 3 stars without losing a heart.", "stat": "flawless_levels", "goal": 1},
	# ---- Gold
	{"id": "pocket_change", "name": "Pocket Change", "desc": "Earn 1,000 gold in total.", "stat": "gold_earned", "goal": 1000},
	{"id": "dragons_hoard", "name": "Dragon's Hoard", "desc": "Earn 10,000 gold in total.", "stat": "gold_earned", "goal": 10000},
	{"id": "filthy_rich", "name": "Filthy Rich", "desc": "Earn 100,000 gold in total.", "stat": "gold_earned", "goal": 100000},
	{"id": "big_spender", "name": "Big Spender", "desc": "Spend 10,000 gold.", "stat": "gold_spent", "goal": 10000},
	# ---- Collection
	{"id": "fire_starter", "name": "Fire Starter", "desc": "Own 5 attack styles.", "stat": "attacks_owned", "goal": 5},
	{"id": "pyromaniac", "name": "Pyromaniac", "desc": "Own 15 attack styles.", "stat": "attacks_owned", "goal": 15},
	{"id": "walking_arsenal", "name": "Walking Arsenal", "desc": "Own 30 attack styles.", "stat": "attacks_owned", "goal": 30},
	{"id": "burn_them_all", "name": "Burn Them All", "desc": "Own all 60 attack styles.", "stat": "attacks_owned", "goal": 60},
	{"id": "fresh_scales", "name": "Fresh Scales", "desc": "Own 2 dragons.", "stat": "dragons_owned", "goal": 2},
	{"id": "dragon_collector", "name": "Dragon Collector", "desc": "Own all 6 dragons.", "stat": "dragons_owned", "goal": 6},
	# ---- Dragon level
	{"id": "hatchling_no_more", "name": "Hatchling No More", "desc": "Reach dragon level 5.", "stat": "dragon_level", "goal": 5},
	{"id": "wyrm_in_training", "name": "Wyrm in Training", "desc": "Reach dragon level 10.", "stat": "dragon_level", "goal": 10},
	{"id": "elder_wyrm", "name": "Elder Wyrm", "desc": "Reach dragon level 20.", "stat": "dragon_level", "goal": 20},
	{"id": "ancient_one", "name": "Ancient One", "desc": "Reach dragon level 30.", "stat": "dragon_level", "goal": 30},
	# ---- Endless
	{"id": "marathon_flyer", "name": "Marathon Flyer", "desc": "Fly 500 m in Endless Castles.", "stat": "endless_castle_best", "goal": 500},
	{"id": "endless_wanderer", "name": "Endless Wanderer", "desc": "Fly 2,000 m in Endless Castles.", "stat": "endless_castle_best", "goal": 2000},
	{"id": "horizon_chaser", "name": "Horizon Chaser", "desc": "Fly 5,000 m in Endless Castles.", "stat": "endless_castle_best", "goal": 5000},
	{"id": "room_runner", "name": "Room Runner", "desc": "Clear 5 rooms in Endless Dungeon.", "stat": "endless_dungeon_best", "goal": 5},
	{"id": "maze_master", "name": "Maze Master", "desc": "Clear 15 rooms in Endless Dungeon.", "stat": "endless_dungeon_best", "goal": 15},
	{"id": "bottomless_pit", "name": "Bottomless Pit", "desc": "Clear 30 rooms in Endless Dungeon.", "stat": "endless_dungeon_best", "goal": 30},
	# ---- Misc feats
	{"id": "giant_slayer", "name": "Giant Slayer", "desc": "Defeat 1 boss.", "stat": "bosses_killed", "goal": 1},
	{"id": "royal_pain", "name": "Royal Pain", "desc": "Defeat 10 bosses.", "stat": "bosses_killed", "goal": 10},
	{"id": "treasure_hunter", "name": "Treasure Hunter", "desc": "Open 10 treasure chests.", "stat": "chests_opened", "goal": 10},
	{"id": "arrow_swatter", "name": "Arrow Swatter", "desc": "Destroy 50 enemy projectiles.", "stat": "shots_destroyed", "goal": 50},
	{"id": "flame_grilled", "name": "Flame Grilled", "desc": "Defeat 25 burning enemies.", "stat": "burn_kills", "goal": 25},
	{"id": "cold_shoulder", "name": "Cold Shoulder", "desc": "Defeat 25 frozen enemies.", "stat": "freeze_kills", "goal": 25},
	{"id": "shock_therapy", "name": "Shock Therapy", "desc": "Defeat 25 shocked enemies.", "stat": "shock_kills", "goal": 25},
	{"id": "slow_poison", "name": "Slow Poison", "desc": "Defeat 25 poisoned enemies.", "stat": "poison_kills", "goal": 25},
	{"id": "phoenix_wannabe", "name": "Phoenix Wannabe", "desc": "Get defeated 10 times.", "stat": "deaths", "goal": 10},
	{"id": "frequent_flyer", "name": "Frequent Flyer", "desc": "Start 50 levels.", "stat": "levels_played", "goal": 50},
	{"id": "trophy_hunter", "name": "Trophy Hunter", "desc": "Unlock 30 achievements.", "stat": "achievements", "goal": 30},
	{"id": "completionist", "name": "Completionist", "desc": "Unlock all 59 other achievements.", "stat": "achievements", "goal": 59},
]


static func find(id: String) -> Dictionary:
	for a in ALL:
		if a.id == id:
			return a
	return {}
