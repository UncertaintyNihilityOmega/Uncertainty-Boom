extends Control
## Nest: pick, buy and equip attack styles (gold) and dragon skins (keys).

const GRID_RECT := Rect2(6, 42, 402, 310)
const ATTACK_PANEL := Rect2(412, 42, 222, 172)
const DRAGON_PANEL := Rect2(412, 220, 222, 132)
const COLUMNS := 8
const TILE := 44

var _t := 0.0
var _scroll: ScrollContainer
var _tiles := {}
var _selected := ""
var _dragon_index := 0
var _icon: AttackIcon
var _attack_btn: Button
var _dragon_btn: Button


## One attack tile in the grid.
class Tile extends Control:
	signal picked(id: String)

	var id := ""
	var state := "owned"
	var selected := false
	var hover := false
	var icon: AttackIcon

	func _init(attack_id: String) -> void:
		id = attack_id
		custom_minimum_size = Vector2(44, 44)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		icon = AttackIcon.new()
		icon.position = Vector2(3, 2)
		icon.size = Vector2(38, 27)
		add_child(icon)
		icon.set_attack(attack_id)
		mouse_entered.connect(func() -> void:
			hover = true
			Sfx.play("ui_hover")
			queue_redraw())
		mouse_exited.connect(func() -> void:
			hover = false
			queue_redraw())

	func set_state(new_state: String, is_selected: bool) -> void:
		state = new_state
		selected = is_selected
		icon.set_darken(state == "equipped")
		icon.modulate = Color(1, 1, 1, 0.3) if state == "locked" else (Color(1, 1, 1, 0.6) if state == "expensive" else Color.WHITE)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(id)
			accept_event()

	func _draw() -> void:
		var bg := Color("5a7a20")
		var border := Color("2c3c10")
		match state:
			"equipped":
				bg = Color("ffe020")
				border = Color("ff9a00")
			"buyable":
				bg = Color("1a6aa8")
				border = Color("0a3a68")
			"expensive":
				bg = Color("2a3a50")
				border = Color("18243a")
			"locked":
				bg = Color("141c2a")
				border = Color("0c121c")
		if selected:
			border = Color.WHITE
		UIKit.draw_panel(self, Rect2(Vector2.ZERO, size), bg, border, 6, 2)
		if hover:
			UIKit.draw_panel(self, Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.14), Color(0, 0, 0, 0), 6, 0)
		var price := int(AttackDB.get_attack(id).price)
		match state:
			"equipped":
				UIKit.draw_glyph(self, "check", Vector2(22, 36), 4.0, Color("5a3000"))
			"owned":
				UIKit.draw_glyph(self, "check", Vector2(22, 36), 4.0, Color("c8f070"))
			"buyable":
				UIKit.draw_text(self, UIKit.fmt_int(price), Vector2(22, 30), 10, Color.WHITE, 1)
			"expensive":
				UIKit.draw_text(self, UIKit.fmt_int(price), Vector2(22, 30), 10, Color("ff9090"), 1)
			"locked":
				UIKit.draw_text(self, "Lv %d" % int(AttackDB.get_attack(id).level), Vector2(22, 30), 10, Color("8aa0b8"), 1)


func setup(_args: Dictionary) -> void:
	size = Vector2(640, 360)
	_selected = Game.equipped_attack()
	_dragon_index = _dragon_ids().find(Game.equipped_dragon())
	if _dragon_index < 0:
		_dragon_index = 0

	var back := UIKit.make_button("Back", Vector2(64, 26), UIKit.BLUE, 12, "left")
	UIKit.place(back, 6, 5)
	back.pressed.connect(_back)
	add_child(back)

	var stats := UIKit.StatsBar.new()
	UIKit.place(stats, 78, 3)
	add_child(stats)

	var play := UIKit.make_button("Play", Vector2(68, 26), UIKit.TEAL, 12, "play")
	UIKit.place(play, 566, 5)
	play.pressed.connect(func() -> void: Events.request_screen.emit("levels", {}))
	add_child(play)

	_scroll = ScrollContainer.new()
	_scroll.position = GRID_RECT.position + Vector2(2, 2)
	_scroll.size = GRID_RECT.size - Vector2(4, 4)
	UIKit.style_scroll(_scroll)
	add_child(_scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	_scroll.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	margin.add_child(grid)
	for id in AttackDB.all_ids():
		var tile := Tile.new(id)
		tile.picked.connect(_on_tile_picked)
		grid.add_child(tile)
		_tiles[id] = tile

	_icon = AttackIcon.new()
	_icon.position = ATTACK_PANEL.position + Vector2(8, 8)
	_icon.size = Vector2(54, 38)
	add_child(_icon)

	_attack_btn = UIKit.make_button("", Vector2(206, 26), UIKit.TEAL, 12)
	UIKit.place(_attack_btn, ATTACK_PANEL.position.x + 8, ATTACK_PANEL.position.y + 142)
	_attack_btn.pressed.connect(_on_attack_action)
	add_child(_attack_btn)

	var prev := UIKit.make_button("", Vector2(28, 34), UIKit.TEAL, 12, "left")
	UIKit.place(prev, DRAGON_PANEL.position.x + 8, DRAGON_PANEL.position.y + 36)
	prev.pressed.connect(_cycle_dragon.bind(-1))
	add_child(prev)
	var next := UIKit.make_button("", Vector2(28, 34), UIKit.TEAL, 12, "right")
	UIKit.place(next, DRAGON_PANEL.end.x - 36, DRAGON_PANEL.position.y + 36)
	next.pressed.connect(_cycle_dragon.bind(1))
	add_child(next)

	_dragon_btn = UIKit.make_button("", Vector2(150, 24), UIKit.TEAL, 12)
	UIKit.place(_dragon_btn, DRAGON_PANEL.position.x + 36, DRAGON_PANEL.position.y + 104)
	_dragon_btn.pressed.connect(_on_dragon_action)
	add_child(_dragon_btn)

	Events.currency_changed.connect(_refresh)
	_refresh()
	_scroll_to_selected.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _back() -> void:
	Events.request_screen.emit("menu", {})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _scroll_to_selected() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var idx := AttackDB.all_ids().find(_selected)
	_scroll.scroll_vertical = maxi(0, (idx / COLUMNS) * (TILE + 4) - 90)


# ---------------------------------------------------------------- state

func _dragon_ids() -> Array:
	var ids := []
	for d in DragonDB.LIST:
		ids.append(d.id)
	return ids


func _state_of(id: String) -> String:
	if Game.equipped_attack() == id:
		return "equipped"
	if Game.owns_attack(id):
		return "owned"
	if Game.attack_locked_by_level(id):
		return "locked"
	if Game.can_afford(int(AttackDB.get_attack(id).price)):
		return "buyable"
	return "expensive"


func _refresh() -> void:
	for id in _tiles.keys():
		(_tiles[id] as Tile).set_state(_state_of(id), id == _selected)
	_icon.set_attack(_selected)
	var st := _state_of(_selected)
	var price := int(AttackDB.get_attack(_selected).price)
	match st:
		"equipped":
			_attack_btn.text = "Equipped"
			_attack_btn.disabled = true
		"owned":
			_attack_btn.text = "Equip"
			_attack_btn.disabled = false
		"locked":
			_attack_btn.text = "Needs dragon Lv %d" % int(AttackDB.get_attack(_selected).level)
			_attack_btn.disabled = true
		"buyable":
			_attack_btn.text = "Buy (free)" if Game.is_creative() else "Buy for %s gold" % UIKit.fmt_int(price)
			_attack_btn.disabled = false
		_:
			_attack_btn.text = "Not enough gold"
			_attack_btn.disabled = true
	var did: String = _dragon_ids()[_dragon_index]
	var dprice := int(DragonDB.get_dragon(did).price)
	if Game.equipped_dragon() == did:
		_dragon_btn.text = "Equipped"
		_dragon_btn.disabled = true
	elif Game.owns_dragon(did):
		_dragon_btn.text = "Equip"
		_dragon_btn.disabled = false
	elif Game.can_afford_keys(dprice):
		_dragon_btn.text = "Buy (free)" if Game.is_creative() else "Buy for %d keys" % dprice
		_dragon_btn.disabled = false
	else:
		_dragon_btn.text = "Not enough keys"
		_dragon_btn.disabled = true
	queue_redraw()


func _on_tile_picked(id: String) -> void:
	Sfx.play("ui_click")
	_selected = id
	_refresh()


func _on_attack_action() -> void:
	if Game.owns_attack(_selected):
		Game.equip_attack(_selected)
	else:
		Game.buy_attack(_selected)
	_refresh()


func _cycle_dragon(dir: int) -> void:
	var n := DragonDB.LIST.size()
	_dragon_index = (_dragon_index + dir + n) % n
	_refresh()


func _on_dragon_action() -> void:
	var did: String = _dragon_ids()[_dragon_index]
	if Game.owns_dragon(did):
		Game.equip_dragon(did)
	else:
		Game.buy_dragon(did)
	_refresh()


# ---------------------------------------------------------------- drawing

func _traits(a: Dictionary) -> String:
	var out: Array[String] = []
	var pierce := int(a.pierce)
	if pierce >= 50:
		out.append("Pierces all")
	elif pierce > 0:
		out.append("Pierces %d" % pierce)
	if bool(a.phase):
		out.append("Passes walls")
	if float(a.homing) > 0.0:
		out.append("Homing")
	if float(a.explode) > 0.0:
		out.append("Explosive")
	if int(a.split) > 0:
		out.append("Splits in %d" % int(a.split))
	if int(a.bounce) > 0:
		out.append("Bounces %d" % int(a.bounce))
	if bool(a.boomerang):
		out.append("Returns")
	if float(a.gravity) > 0.0:
		out.append("Arcing")
	if float(a.wave) > 0.0:
		out.append("Wavy")
	if int(a.burst) > 1:
		out.append("%d-shot burst" % int(a.burst))
	match String(a.pattern):
		"ring": out.append("Ring")
		"back": out.append("Fires both ways")
		"wall": out.append("Wall of fire")
		"spiral": out.append("Spiral")
		"twin_wave": out.append("Twin waves")
		"rain": out.append("Falls from above")
		"orbit": out.append("Orbits you")
		"mine": out.append("Drops mines")
		"chain": out.append("Chain lightning")
	match String(a.effect):
		"burn": out.append("Burns")
		"freeze": out.append("Freezes")
		"shock": out.append("Shocks")
		"poison": out.append("Poisons")
	if out.is_empty():
		return "Plain and reliable"
	return ", ".join(out)


func _draw() -> void:
	UIKit.draw_night_background(self, size, _t, 0, false)
	draw_rect(Rect2(0, 0, 640, 36), Color(0.02, 0.06, 0.14, 0.55))
	draw_rect(Rect2(0, 36, 640, 2), Color("1a4a6a"))
	UIKit.draw_panel(self, GRID_RECT, Color(0.03, 0.08, 0.16, 0.85), Color("26506e"), 8, 2)
	_draw_attack_panel()
	_draw_dragon_panel()


func _draw_attack_panel() -> void:
	var r := ATTACK_PANEL
	UIKit.draw_panel(self, r, UIKit.PANEL, Color("3a78a8"), 8, 2)
	UIKit.draw_panel(self, Rect2(r.position + Vector2(6, 6), Vector2(58, 42)), Color(0.02, 0.06, 0.14, 0.8), Color("26506e"), 6, 1)
	var a := AttackDB.get_attack(_selected)
	var x := r.position.x + 72.0
	UIKit.draw_text_fit(self, String(a.name), Vector2(x, r.position.y + 7.0), 14, r.size.x - 80.0, Color.WHITE)
	var st := _state_of(_selected)
	var sy := r.position.y + 28.0
	match st:
		"equipped":
			UIKit.draw_text(self, "Equipped", Vector2(x, sy), 11, UIKit.GOLD)
		"owned":
			UIKit.draw_text(self, "Owned", Vector2(x, sy), 11, UIKit.TEAL)
		"locked":
			UIKit.draw_text(self, "Needs dragon Lv %d" % int(a.level), Vector2(x, sy), 11, Color("ff9090"))
		_:
			UIKit.draw_coin(self, Vector2(x + 5.0, sy + 7.0), 5.0)
			var cost := "free" if Game.is_creative() else UIKit.fmt_int(int(a.price))
			UIKit.draw_text(self, cost, Vector2(x + 14.0, sy), 11, Color.WHITE if st == "buyable" else Color("ff9090"))
	if st != "owned" and st != "equipped":
		UIKit.draw_text(self, "Lv %d" % int(a.level), Vector2(r.end.x - 10.0, sy), 11, Color("8aa0b8"), 2)
	UIKit.draw_wrapped(self, String(a.desc), r.position + Vector2(10, 54), r.size.x - 20.0, 11, Color("d8e8f8"), 2)
	var shots := int(a.count) * int(a.burst)
	var dmg := "%.1f" % float(a.dmg)
	if shots > 1:
		dmg += " x%d" % shots
	var sy2 := r.position.y + 84.0
	UIKit.draw_text(self, "Damage", Vector2(r.position.x + 10.0, sy2), 10, UIKit.DIM)
	UIKit.draw_text(self, dmg, Vector2(r.position.x + 56.0, sy2), 11, Color.WHITE)
	UIKit.draw_text(self, "Rate", Vector2(r.position.x + 118.0, sy2), 10, UIKit.DIM)
	UIKit.draw_text(self, "%.1f/s" % (1.0 / maxf(0.01, float(a.cd))), Vector2(r.position.x + 148.0, sy2), 11, Color.WHITE)
	UIKit.draw_wrapped(self, _traits(a), r.position + Vector2(10, 101), r.size.x - 20.0, 10, Color("9af0d8"), 3)


func _draw_dragon_panel() -> void:
	var r := DRAGON_PANEL
	UIKit.draw_panel(self, r, UIKit.PANEL, Color("3a78a8"), 8, 2)
	var did: String = _dragon_ids()[_dragon_index]
	var d := DragonDB.get_dragon(did)
	var cx := r.position.x + r.size.x * 0.5
	UIKit.draw_text(self, String(d.name), Vector2(cx, r.position.y + 6.0), 14, Color.WHITE, 1)
	var owned := Game.owns_dragon(did)
	var tint := Color.WHITE if owned else Color(0.55, 0.6, 0.75)
	DragonArt.draw(self, Vector2(cx, r.position.y + 58.0 + sin(_t * 2.0) * 2.0), did, 1, _t, 2.6, "fly", 0.0, tint)
	var sy := r.position.y + 84.0
	if owned:
		UIKit.draw_text(self, "Equipped" if Game.equipped_dragon() == did else "Owned", Vector2(cx, sy), 11, UIKit.GOLD if Game.equipped_dragon() == did else UIKit.TEAL, 1)
	else:
		var price := int(d.price)
		var label := "free" if Game.is_creative() else str(price)
		var w := UIKit.text_width(label, 11) + 18.0
		UIKit.draw_key(self, Vector2(cx - w * 0.5 + 6.0, sy + 7.0), 13.0)
		UIKit.draw_text(self, label, Vector2(cx - w * 0.5 + 16.0, sy), 11, Color.WHITE if Game.can_afford_keys(price) else Color("ff9090"))
