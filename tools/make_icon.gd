extends SceneTree
## Renders the game icon (dragon + fireball on a night badge) to res://assets/icon/ (icon.png + icon.ico).
## Run: Godot --path . --script res://tools/make_icon.gd

const SIZE := 64


func _initialize() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var art := Node2D.new()
	art.draw.connect(func(): _paint(art))
	vp.add_child(art)
	for i in 6:
		await process_frame
	var base := vp.get_texture().get_image()
	var big := base.duplicate()
	big.resize(256, 256, Image.INTERPOLATE_NEAREST)
	big.save_png("res://assets/icon/icon.png")
	_save_ico(base, [16, 32, 48, 64, 256], "res://assets/icon/icon.ico")
	quit()


## Writes a Windows .ico whose entries are embedded PNGs.
func _save_ico(base: Image, sizes: Array, path: String) -> void:
	var pngs := []
	for s in sizes:
		var img := base.duplicate()
		img.resize(s, s, Image.INTERPOLATE_NEAREST if s >= 64 else Image.INTERPOLATE_BILINEAR)
		pngs.append(img.save_png_to_buffer())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_16(0)
	f.store_16(1)
	f.store_16(sizes.size())
	var offset := 6 + 16 * sizes.size()
	for i in sizes.size():
		var s: int = sizes[i]
		f.store_8(0 if s >= 256 else s)
		f.store_8(0 if s >= 256 else s)
		f.store_8(0)
		f.store_8(0)
		f.store_16(1)
		f.store_16(32)
		f.store_32(pngs[i].size())
		f.store_32(offset)
		offset += pngs[i].size()
	for p in pngs:
		f.store_buffer(p)
	f.close()


func _paint(ci: Node2D) -> void:
	var c := Vector2(SIZE, SIZE) / 2.0
	ci.draw_circle(c, 31.0, Color("0a1a32"))
	ci.draw_circle(c, 29.0, Color("0d2a44"))
	ci.draw_circle(Vector2(17, 17), 7.0, Color("e0f08a"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(6, 50), Vector2(20, 42), Vector2(36, 47), Vector2(58, 40), Vector2(60, 52), Vector2(32, 62), Vector2(10, 56)]), Color("00a07a"))
	# Fireball
	ci.draw_colored_polygon(PackedVector2Array([Vector2(53, 20), Vector2(45, 24), Vector2(53, 28)]), Color("ff8a20"))
	ci.draw_circle(Vector2(56, 24), 5.0, Color("ff6020"))
	ci.draw_circle(Vector2(56, 24), 2.5, Color("ffe070"))
	DragonArt.draw(ci, Vector2(26, 38), "ember", 1, 0.0, 1.8, "fly")
