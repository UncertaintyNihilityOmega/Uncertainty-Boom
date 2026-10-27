class_name UIKit
extends RefCounted
## Shared colours, widgets and vector icon helpers for every menu screen.
## Everything is drawn in code; there are no image assets.

const SKY := Color("0d2a44")
const SKY_LOW := Color("14486a")
const MOON := Color("e0f08a")
const GRASS := Color("00a07a")
const GRASS_DARK := Color("007a5e")
const STONE := Color("14b4f0")
const STONE_LIGHT := Color("80ecff")
const STONE_DARK := Color("0a78b8")
const TEAL := Color("00d0a0")
const BLUE := Color("14a0e0")
const RED := Color("e04848")
const GOLD := Color("ffc820")
const ORANGE := Color("ff8a20")
const NAVY := Color("0a1830")
const PANEL := Color("12304f")
const PANEL_LIGHT := Color("1c4468")
const WHITE := Color("ffffff")
const DIM := Color("9ab4cc")
const DUNGEON_BG := Color("0a0e2e")
const WATER := Color("20d8e8")

static var _sb_cache := {}
static var _tex_cache := {}


# ---------------------------------------------------------------- text & formatting

static func font() -> Font:
	return ThemeDB.fallback_font


static func text_width(text: String, size: int) -> float:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func text_height(size: int) -> float:
	return font().get_height(size)


## anchor: 0 = pos.x is the left edge, 1 = centre, 2 = right edge. pos.y is the top of the line.
static func draw_text(ci: CanvasItem, text: String, pos: Vector2, size: int, color := Color.WHITE, anchor := 0, outline := 0, outline_color := Color(0.02, 0.05, 0.12, 0.95)) -> void:
	var f := font()
	var x := pos.x
	if anchor != 0:
		var w := text_width(text, size)
		x -= w * 0.5 if anchor == 1 else w
	var p := Vector2(roundf(x), roundf(pos.y + f.get_ascent(size)))
	if outline > 0:
		f.draw_string_outline(ci.get_canvas_item(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
	f.draw_string(ci.get_canvas_item(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Like draw_text but shrinks the font (down to 8) until the text fits in max_w.
static func draw_text_fit(ci: CanvasItem, text: String, pos: Vector2, size: int, max_w: float, color := Color.WHITE, anchor := 0, outline := 0) -> void:
	var s := size
	while s > 8 and text_width(text, s) > max_w:
		s -= 1
	draw_text(ci, text, pos, s, color, anchor, outline)


## Wrapped text; pos.y is the top of the first line.
static func draw_wrapped(ci: CanvasItem, text: String, pos: Vector2, width: float, size: int, color := Color.WHITE, max_lines := -1) -> void:
	var f := font()
	f.draw_multiline_string(ci.get_canvas_item(), Vector2(roundf(pos.x), roundf(pos.y + f.get_ascent(size))), text, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, color)


## 12345 -> "12,345"
static func fmt_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


## 83.4 -> "01:23.400"
static func fmt_time(seconds: float) -> String:
	var ms := int(round(seconds * 1000.0))
	return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]


# ---------------------------------------------------------------- panels & widgets

static func draw_panel(ci: CanvasItem, rect: Rect2, bg: Color, border := Color(0, 0, 0, 0), radius := 6, border_w := 2) -> void:
	var key := "%s|%s|%d|%d" % [bg.to_html(true), border.to_html(true), radius, border_w]
	var sb: StyleBoxFlat = _sb_cache.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = false
		if border.a > 0.0:
			sb.border_color = border
			sb.set_border_width_all(border_w)
		_sb_cache[key] = sb
	ci.draw_style_box(sb, rect)


static func panel_style(bg: Color, border := Color(0, 0, 0, 0), radius := 6, border_w := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = false
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb


static func _btn_style(col: Color, pressed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.anti_aliasing = false
	sb.border_color = col.darkened(0.4)
	sb.border_width_bottom = 1 if pressed else 3
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4 if pressed else 2
	sb.content_margin_bottom = 2 if pressed else 2
	return sb


## Rounded teal button with a darker bottom edge. icon: "", "left", "right", "play", "close".
static func make_button(text: String, min_size := Vector2(100, 28), color := TEAL, font_size := 12, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	b.add_theme_stylebox_override("normal", _btn_style(color, false))
	b.add_theme_stylebox_override("hover", _btn_style(color.lightened(0.18), false))
	b.add_theme_stylebox_override("pressed", _btn_style(color.darkened(0.12), true))
	b.add_theme_stylebox_override("hover_pressed", _btn_style(color.darkened(0.05), true))
	b.add_theme_stylebox_override("disabled", _btn_style(Color("2c3e52"), false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: Sfx.play("ui_click"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Sfx.play("ui_hover"))
	if icon != "":
		b.draw.connect(func() -> void:
			var cx := b.size.y * 0.5 + 4.0 if text != "" else b.size.x * 0.5
			var c := Color(1, 1, 1, 0.45) if b.disabled else Color.WHITE
			draw_glyph(b, icon, Vector2(cx, b.size.y * 0.5 - 1.0), minf(b.size.y * 0.24, 8.0), c))
		if text != "":
			b.add_theme_constant_override("h_separation", 0)
			for key in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				var st: StyleBoxFlat = b.get_theme_stylebox(key)
				st.content_margin_left = 22
	return b


## Toggle button that shows ON / OFF.
static func make_toggle(on: bool, min_size := Vector2(54, 22)) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = min_size
	b.size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	var off := Color("3a4c62")
	b.add_theme_stylebox_override("normal", _btn_style(off, false))
	b.add_theme_stylebox_override("hover", _btn_style(off.lightened(0.15), false))
	b.add_theme_stylebox_override("pressed", _btn_style(TEAL, false))
	b.add_theme_stylebox_override("hover_pressed", _btn_style(TEAL.lightened(0.15), false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.button_pressed = on
	b.text = "ON" if on else "OFF"
	b.toggled.connect(func(v: bool) -> void:
		b.text = "ON" if v else "OFF"
		Sfx.play("ui_click"))
	return b


static func make_label(text: String, size := 12, color := Color.WHITE, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.12, 0.95))
	return l


## Sets position and size of a Control (this project does not use anchors/containers on screens).
static func place(c: Control, x: float, y: float, w := -1.0, h := -1.0) -> Control:
	c.position = Vector2(x, y)
	if w >= 0.0:
		c.size = Vector2(w, h if h >= 0.0 else c.size.y)
	return c


static func circle_texture(radius: int, color: Color) -> ImageTexture:
	var key := "%d|%s" % [radius, color.to_html(true)]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var d := radius * 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			if dist <= radius:
				img.set_pixel(x, y, color if dist <= radius - 1.5 else color.darkened(0.4))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


static func style_slider(s: HSlider) -> void:
	var track := panel_style(Color("0a1c30"), Color("26506e"), 3, 1)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := panel_style(TEAL, Color(0, 0, 0, 0), 3, 0)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", circle_texture(7, Color.WHITE))
	s.add_theme_icon_override("grabber_highlight", circle_texture(7, Color("b0fff0")))
	s.add_theme_icon_override("grabber_disabled", circle_texture(7, Color("808890")))
	s.focus_mode = Control.FOCUS_NONE


static func style_scroll(sc: ScrollContainer) -> void:
	var bar := sc.get_v_scroll_bar()
	bar.custom_minimum_size.x = 10
	bar.add_theme_stylebox_override("scroll", panel_style(Color("0a1c30"), Color(0, 0, 0, 0), 4, 0))
	bar.add_theme_stylebox_override("grabber", panel_style(Color("2aa0c8"), Color(0, 0, 0, 0), 4, 0))
	bar.add_theme_stylebox_override("grabber_highlight", panel_style(Color("60d0f0"), Color(0, 0, 0, 0), 4, 0))
	bar.add_theme_stylebox_override("grabber_pressed", panel_style(Color("90e8ff"), Color(0, 0, 0, 0), 4, 0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


# ---------------------------------------------------------------- vector icons

static func star_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


static func draw_star(ci: CanvasItem, c: Vector2, r: float, filled := true) -> void:
	if filled:
		ci.draw_colored_polygon(star_points(c + Vector2(0, 0.6), r + 0.6), Color("b86a00"))
		ci.draw_colored_polygon(star_points(c, r), GOLD)
	else:
		ci.draw_colored_polygon(star_points(c, r), Color("34485e"))


## Dark pill holding three stars.
static func draw_star_pill(ci: CanvasItem, c: Vector2, stars: Array, w := 46.0, h := 13.0) -> void:
	draw_panel(ci, Rect2(c - Vector2(w * 0.5, h * 0.5), Vector2(w, h)), Color(0.02, 0.1, 0.16, 0.85), Color(0, 0, 0, 0), int(h * 0.5))
	var step := w / 3.4
	for i in 3:
		draw_star(ci, c + Vector2((i - 1) * step, 0), h * 0.38, bool(stars[i]) if i < stars.size() else false)


static func draw_coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color("c07a00"))
	ci.draw_circle(c, r - 1.0, GOLD)
	ci.draw_circle(c + Vector2(0.5, 0.5), r * 0.55, Color("f0a000"))
	ci.draw_rect(Rect2(c.x - 1.0, c.y - r * 0.4, 2.0, r * 0.8), Color("ffe880"))


## c is the centre; s is the total length.
static func draw_key(ci: CanvasItem, c: Vector2, s: float, color := Color("ffd23c")) -> void:
	var ring_r := s * 0.24
	var rc := c + Vector2(-s * 0.26, 0)
	ci.draw_arc(rc, ring_r, 0, TAU, 14, color, maxf(2.0, s * 0.14))
	ci.draw_line(rc + Vector2(ring_r, 0), c + Vector2(s * 0.5, 0), color, maxf(2.0, s * 0.14))
	ci.draw_line(c + Vector2(s * 0.34, 0), c + Vector2(s * 0.34, s * 0.2), color, maxf(1.5, s * 0.12))
	ci.draw_line(c + Vector2(s * 0.5, 0), c + Vector2(s * 0.5, s * 0.16), color, maxf(1.5, s * 0.12))


static func draw_padlock(ci: CanvasItem, c: Vector2, s: float, color := Color("c8d4e0")) -> void:
	var bw := s * 0.8
	var bh := s * 0.55
	ci.draw_arc(c + Vector2(0, -s * 0.05), bw * 0.3, PI, TAU, 10, color.darkened(0.2), maxf(2.0, s * 0.16))
	ci.draw_rect(Rect2(c.x - bw * 0.5, c.y - s * 0.05, bw, bh), color)
	ci.draw_rect(Rect2(c.x - bw * 0.5, c.y - s * 0.05 + bh - 2.0, bw, 2.0), color.darkened(0.3))
	ci.draw_circle(c + Vector2(0, s * 0.18), s * 0.09, Color("30384a"))
	ci.draw_rect(Rect2(c.x - 0.7, c.y + s * 0.18, 1.4, s * 0.16), Color("30384a"))


static func draw_crown(ci: CanvasItem, c: Vector2, w: float, color := GOLD) -> void:
	var h := w * 0.7
	var l := c.x - w * 0.5
	var b := c.y + h * 0.5
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(l, b), Vector2(l, b - h * 0.75), Vector2(l + w * 0.25, b - h * 0.4), Vector2(c.x, b - h),
		Vector2(l + w * 0.75, b - h * 0.4), Vector2(l + w, b - h * 0.75), Vector2(l + w, b)]), color)
	ci.draw_rect(Rect2(l, b - h * 0.2, w, h * 0.2), color.darkened(0.25))


static func draw_trophy(ci: CanvasItem, c: Vector2, s: float, color := GOLD) -> void:
	var dark := color.darkened(0.35)
	var cw := s * 0.56
	var top := c.y - s * 0.46
	ci.draw_arc(c + Vector2(-cw * 0.5, -s * 0.2), s * 0.17, PI * 0.5, PI * 1.5, 8, dark, maxf(1.5, s * 0.08))
	ci.draw_arc(c + Vector2(cw * 0.5, -s * 0.2), s * 0.17, -PI * 0.5, PI * 0.5, 8, dark, maxf(1.5, s * 0.08))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - cw * 0.5, top), Vector2(c.x + cw * 0.5, top), Vector2(c.x + cw * 0.38, top + s * 0.4),
		Vector2(c.x + cw * 0.1, top + s * 0.55), Vector2(c.x - cw * 0.1, top + s * 0.55), Vector2(c.x - cw * 0.38, top + s * 0.4)]), color)
	ci.draw_rect(Rect2(c.x - cw * 0.5, top, cw * 0.2, s * 0.38), color.lightened(0.35))
	ci.draw_rect(Rect2(c.x - s * 0.06, top + s * 0.55, s * 0.12, s * 0.16), dark)
	ci.draw_rect(Rect2(c.x - s * 0.22, top + s * 0.7, s * 0.44, s * 0.14), color)
	ci.draw_rect(Rect2(c.x - s * 0.22, top + s * 0.78, s * 0.44, s * 0.06), dark)


## Two crossed swords centred on c; s is the full blade span.
static func draw_swords(ci: CanvasItem, c: Vector2, s: float, blade := Color("e8f4ff"), hilt := Color("ffb030")) -> void:
	var h := s * 0.5
	for dir in [-1.0, 1.0]:
		var a := c + Vector2(-h * dir, h)
		var b := c + Vector2(h * dir, -h)
		ci.draw_line(a, b, Color("0a1830"), maxf(3.5, s * 0.16))
		ci.draw_line(a, b, blade, maxf(2.0, s * 0.09))
		var guard_c := c + Vector2(-h * dir, h) * 0.5
		var perp := Vector2(dir, 1.0).normalized()
		ci.draw_line(guard_c - perp * s * 0.16, guard_c + perp * s * 0.16, hilt, maxf(2.0, s * 0.09))
		ci.draw_line(guard_c, c + Vector2(-h * dir, h) * 0.95, hilt.darkened(0.3), maxf(2.0, s * 0.09))


static func draw_infinity(ci: CanvasItem, c: Vector2, w: float, color := Color.WHITE, width := 2.0) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := float(i) / 32.0 * TAU
		var d := 1.0 + sin(a) * sin(a)
		pts.append(c + Vector2(cos(a) / d, sin(a) * cos(a) / d) * w * 0.5)
	ci.draw_polyline(pts, color, width)


static func draw_glyph(ci: CanvasItem, kind: String, c: Vector2, r: float, color := Color.WHITE) -> void:
	match kind:
		"left":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.6, -r), c + Vector2(r * 0.6, r), c + Vector2(-r * 0.8, 0)]), color)
		"right", "play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(-r * 0.6, r), c + Vector2(r * 0.8, 0)]), color)
		"close":
			ci.draw_line(c + Vector2(-r, -r), c + Vector2(r, r), color, 2.0)
			ci.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), color, 2.0)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(-r * 0.3, r * 0.7), c + Vector2(r, -r * 0.7)]), color, 2.0)


## Value with a coin or key icon; shows the infinity sign in creative mode. Returns the width used.
static func draw_currency(ci: CanvasItem, kind: String, pos: Vector2, amount: int, size := 14, color := Color.WHITE) -> float:
	var center := pos + Vector2(size * 0.55, size * 0.62)
	if kind == "gold":
		draw_coin(ci, center, size * 0.5)
	else:
		draw_key(ci, center, size * 1.15)
	var x := pos.x + size * 1.3
	if Game.is_creative():
		draw_infinity(ci, Vector2(x + size * 0.6, center.y), size * 1.2, color, 2.0)
		return x - pos.x + size * 1.2
	draw_text(ci, fmt_int(amount), Vector2(x, pos.y), size, color, 0, 1)
	return x - pos.x + text_width(fmt_int(amount), size)


## Little stone castle; pos is the bottom centre. dim 0..1 fades it into the background.
static func draw_castle(ci: CanvasItem, pos: Vector2, w: float, h: float, stone := STONE, dim := 0.0, flag := true) -> void:
	var fade := Color("0b2236")
	var body := stone.lerp(fade, dim)
	var light := stone.lightened(0.4).lerp(fade, dim)
	var dark := stone.darkened(0.35).lerp(fade, dim)
	var tw := w * 0.28
	var left := pos.x - w * 0.5
	var wall_h := h * 0.6
	ci.draw_rect(Rect2(left + tw * 0.5, pos.y - wall_h, w - tw, wall_h), body)
	ci.draw_rect(Rect2(left + tw * 0.5, pos.y - wall_h, w - tw, 2.0), light)
	for tx in [left, pos.x + w * 0.5 - tw]:
		ci.draw_rect(Rect2(tx, pos.y - h, tw, h), body)
		ci.draw_rect(Rect2(tx + tw * 0.65, pos.y - h, tw * 0.35, h), dark)
		ci.draw_rect(Rect2(tx - 1.0, pos.y - h, tw + 2.0, 3.0), light)
		for k in 3:
			ci.draw_rect(Rect2(tx - 1.0 + k * (tw / 2.0), pos.y - h - 3.0, 2.0, 3.0), light)
		ci.draw_rect(Rect2(tx + tw * 0.3, pos.y - h * 0.62, 2.0, 4.0), dark)
	ci.draw_rect(Rect2(pos.x - 3.0, pos.y - 7.0, 6.0, 7.0), dark.darkened(0.4))
	ci.draw_circle(Vector2(pos.x, pos.y - 7.0), 3.0, dark.darkened(0.4))
	if flag:
		var fx := left + tw * 0.5
		ci.draw_line(Vector2(fx, pos.y - h - 3.0), Vector2(fx, pos.y - h - 11.0), light, 1.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(fx, pos.y - h - 11.0), Vector2(fx + 6.0, pos.y - h - 9.0), Vector2(fx, pos.y - h - 7.0)]), Color("ff8aa0").lerp(fade, dim))


static func draw_flames(ci: CanvasItem, pos: Vector2, w: float, h: float, t: float) -> void:
	var n := 4
	for i in n:
		var fx := pos.x - w * 0.5 + (i + 0.5) * w / n
		var fh := h * (0.65 + 0.35 * sin(t * 9.0 + i * 1.7))
		var bw := w / n * 0.62
		ci.draw_colored_polygon(PackedVector2Array([Vector2(fx - bw, pos.y), Vector2(fx + sin(t * 7.0 + i) * 1.5, pos.y - fh), Vector2(fx + bw, pos.y)]), Color("ff4a20"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(fx - bw * 0.5, pos.y), Vector2(fx, pos.y - fh * 0.6), Vector2(fx + bw * 0.5, pos.y)]), Color("ffc040"))


static func draw_smoke(ci: CanvasItem, pos: Vector2, t: float, count := 3) -> void:
	for i in count:
		var ph := fposmod(t * 0.45 + float(i) / count, 1.0)
		ci.draw_circle(pos + Vector2(sin(ph * 6.0 + i) * 3.0, -ph * 26.0), 1.5 + ph * 3.0, Color(0, 0, 0, (1.0 - ph) * 0.8))


# ---------------------------------------------------------------- backgrounds

static func _rand(i: int, salt := 0.0) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


static func hill_polygon(width: float, base_y: float, bottom_y: float, amp: float, freq: float, phase: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= width + 8.0:
		pts.append(Vector2(x, base_y + sin(x * freq + phase) * amp))
		x += 8.0
	pts.append(Vector2(width + 8.0, bottom_y))
	pts.append(Vector2(0, bottom_y))
	return pts


static func draw_silhouette_castle(ci: CanvasItem, pos: Vector2, w: float, h: float, color: Color) -> void:
	var tw := w * 0.16
	ci.draw_rect(Rect2(pos.x - w * 0.5, pos.y - h * 0.62, w, h * 0.62), color)
	for k in int(w / 6.0):
		if k % 2 == 0:
			ci.draw_rect(Rect2(pos.x - w * 0.5 + k * 6.0, pos.y - h * 0.62 - 3.0, 4.0, 3.0), color)
	for tx in [pos.x - w * 0.5, pos.x + w * 0.5 - tw]:
		ci.draw_rect(Rect2(tx, pos.y - h, tw, h), color)
		ci.draw_rect(Rect2(tx - 1.0, pos.y - h - 3.0, tw + 2.0, 3.0), color)
	for k in 3:
		ci.draw_circle(Vector2(pos.x - w * 0.18 + k * w * 0.18, pos.y - h * 0.2), w * 0.06, color.lightened(0.06))


## detail 0: sky, stars, moon.  1: + far hills and silhouette castles.  2: + grass hills.
static func draw_night_background(ci: CanvasItem, size: Vector2, t: float, detail := 2, moon_on := true) -> void:
	var bands := 8
	for i in bands:
		ci.draw_rect(Rect2(0, size.y * i / bands, size.x, size.y / bands + 1.0), SKY.lerp(SKY_LOW, float(i) / (bands - 1)))
	for i in 46:
		var sx := _rand(i, 1.0) * size.x
		var sy := _rand(i, 2.0) * size.y * 0.62
		var tw := 0.55 + 0.45 * sin(t * (1.0 + _rand(i, 3.0) * 2.0) + i)
		if i % 4 == 0:
			var d := 2.0
			ci.draw_colored_polygon(PackedVector2Array([Vector2(sx, sy - d), Vector2(sx + d, sy), Vector2(sx, sy + d), Vector2(sx - d, sy)]), Color(0.2, 0.75, 0.9, 0.35 + 0.4 * tw))
		else:
			ci.draw_rect(Rect2(floorf(sx), floorf(sy), 1.0 + float(i % 3 == 0), 1.0 + float(i % 3 == 0)), Color(0.85, 0.95, 1.0, 0.25 + 0.6 * tw))
	var moon := Vector2(size.x * 0.84, size.y * 0.17)
	if moon_on:
		ci.draw_circle(moon, 27.0, Color(MOON.r, MOON.g, MOON.b, 0.08))
		ci.draw_circle(moon, 22.0, MOON)
		ci.draw_circle(moon + Vector2(-6, -4), 4.0, Color("c8dc70"))
		ci.draw_circle(moon + Vector2(7, 5), 5.0, Color("c8dc70"))
		ci.draw_circle(moon + Vector2(2, -10), 2.5, Color("c8dc70"))
	if detail < 1:
		return
	ci.draw_colored_polygon(hill_polygon(size.x, size.y * 0.58, size.y, 14.0, 0.011, 1.0), Color("0b3a58"))
	var sil := Color("071a2e")
	draw_silhouette_castle(ci, Vector2(size.x * 0.10, size.y * 0.66), 80.0, 62.0, sil)
	draw_silhouette_castle(ci, Vector2(size.x * 0.52, size.y * 0.6), 60.0, 34.0, sil)
	draw_silhouette_castle(ci, Vector2(size.x * 0.93, size.y * 0.64), 56.0, 44.0, sil)
	ci.draw_colored_polygon(hill_polygon(size.x, size.y * 0.7, size.y, 10.0, 0.016, 3.0), Color("06223a"))
	if detail < 2:
		return
	ci.draw_colored_polygon(hill_polygon(size.x, size.y * 0.8, size.y, 12.0, 0.01, 0.0), GRASS_DARK)
	ci.draw_colored_polygon(hill_polygon(size.x, size.y * 0.88, size.y, 8.0, 0.017, 2.0), GRASS)


## Dragon level badge, XP bar, gold and keys in one strip (498 x 30). Redraws on currency changes.
class StatsBar extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(498, 30)
		size = custom_minimum_size

	func _ready() -> void:
		Events.currency_changed.connect(queue_redraw)
		Events.save_reset.connect(queue_redraw)

	func _draw() -> void:
		var lvl := Game.dragon_level()
		var prog := Game.level_progress()
		UIKit.draw_panel(self, Rect2(0, 3, 56, 24), Color("1e5aa0"), Color("6ab4f0"), 6, 2)
		UIKit.draw_text(self, "Lv %d" % lvl, Vector2(28, 7), 14, Color.WHITE, 1)
		var bar := Rect2(64, 8, 172, 15)
		UIKit.draw_panel(self, bar, Color("0a1c30"), Color("26506e"), 4, 1)
		var ratio := clampf(float(prog.x) / maxf(1.0, float(prog.y)), 0.0, 1.0)
		if ratio > 0.0:
			UIKit.draw_panel(self, Rect2(bar.position + Vector2(1, 1), Vector2(maxf(6.0, (bar.size.x - 2.0) * ratio), bar.size.y - 2.0)), Color("ff5a3c"), Color(0, 0, 0, 0), 3)
		UIKit.draw_text(self, "%s / %s" % [UIKit.fmt_int(prog.x), UIKit.fmt_int(prog.y)], bar.position + Vector2(bar.size.x * 0.5, 1), 11, Color.WHITE, 1, 2)
		UIKit.draw_currency(self, "gold", Vector2(256, 6), Game.get_gold(), 14)
		UIKit.draw_currency(self, "keys", Vector2(380, 6), Game.get_keys(), 14)
