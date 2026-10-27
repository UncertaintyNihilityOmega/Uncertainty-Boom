class_name DragonDB
## The 6 cosmetic dragons. Bought with keys.

const LIST := [
	{"id": "ember", "name": "Ember", "price": 0, "body": "e8402a", "belly": "ffc24a", "wing": "a8202a", "horn": "f4e4c0", "eye": "fff27a", "trail": "ff8a20"},
	{"id": "sapphire", "name": "Sapphire", "price": 20, "body": "2a70e8", "belly": "8ee0ff", "wing": "1a3a9a", "horn": "e0f0ff", "eye": "ffffff", "trail": "60c0ff"},
	{"id": "jade", "name": "Jade", "price": 40, "body": "2aa860", "belly": "c8f080", "wing": "16704a", "horn": "f0e0a0", "eye": "ffe040", "trail": "80ff80"},
	{"id": "shadow", "name": "Shadow", "price": 70, "body": "3a3450", "belly": "8a7aa8", "wing": "1c1828", "horn": "d080ff", "eye": "ff5a9a", "trail": "a060ff"},
	{"id": "frost", "name": "Frost", "price": 100, "body": "d8f0ff", "belly": "ffffff", "wing": "80b8e0", "horn": "60a0d0", "eye": "2a60c0", "trail": "c0f0ff"},
	{"id": "aurum", "name": "Aurum", "price": 150, "body": "f0b820", "belly": "fff0a0", "wing": "b07810", "horn": "fffbe0", "eye": "ff3020", "trail": "ffe060"},
]


static func get_dragon(id: String) -> Dictionary:
	for d in LIST:
		if d.id == id:
			return d
	return LIST[0]


static func colors(id: String) -> Dictionary:
	var d := get_dragon(id)
	var out := {}
	for k in ["body", "belly", "wing", "horn", "eye", "trail"]:
		out[k] = Color(d[k])
	return out
