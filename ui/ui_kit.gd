class_name UIKit
extends RefCounted
## Estilo visual partilhado por todos os menus (tema, botões, sons).

const FONT_PATH := "res://resources/fonts/ShareTech-Regular.ttf"
const ACCENT := Color("ff7a2f")
const ACCENT_HI := Color("ffa062")
const CYAN := Color("52d0ff")
const TEXT := Color("eef2f9")
const DIM := Color("8c98ad")
const DANGER := Color("ff4d5a")
const PANEL := Color(0.067, 0.082, 0.118, 0.95)

static var _theme: Theme
static var _font: Font
static var _snd: Dictionary = {}


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font
	return _font


static func box(bg: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	return s


static func _btn(bg: Color, border: Color, bar: bool) -> StyleBoxFlat:
	var s := box(bg, 12, border, 1)
	if bar:
		s.border_width_left = 6
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 15
	s.content_margin_bottom = 15
	return s


static func circle_tex(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(c - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 26
	t.set_color("font_color", "Label", TEXT)
	# Botões
	for type_name in ["Button", "PrimaryButton", "DangerButton"]:
		if type_name != "Button":
			t.set_type_variation(type_name, "Button")
		var base := Color(1, 1, 1, 0.06)
		var line := Color(1, 1, 1, 0.14)
		var hov := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.20)
		var pre := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.40)
		var txt := TEXT
		var edge := ACCENT
		if type_name == "PrimaryButton":
			base = ACCENT
			line = ACCENT_HI
			hov = ACCENT_HI
			pre = Color("d9611b")
			txt = Color("1a0e06")
			edge = Color.WHITE
		elif type_name == "DangerButton":
			edge = DANGER
			hov = Color(DANGER.r, DANGER.g, DANGER.b, 0.22)
			pre = Color(DANGER.r, DANGER.g, DANGER.b, 0.45)
		t.set_stylebox("normal", type_name, _btn(base, line, true))
		t.set_stylebox("hover", type_name, _btn(hov, edge, true))
		t.set_stylebox("pressed", type_name, _btn(pre, edge, true))
		t.set_stylebox("focus", type_name, _btn(hov, edge, true))
		t.set_stylebox("disabled", type_name, _btn(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06), true))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(c, type_name, txt)
		t.set_color("font_disabled_color", type_name, DIM)
		t.set_font_size("font_size", type_name, 28)
	# Slider
	var track := box(Color(1, 1, 1, 0.16), 5)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := box(ACCENT, 5)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", circle_tex(40, Color.WHITE))
	t.set_icon("grabber_highlight", "HSlider", circle_tex(40, ACCENT_HI))
	t.set_icon("grabber_disabled", "HSlider", circle_tex(40, DIM))
	# Painéis
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 22, Color(1, 1, 1, 0.12), 2))
	_theme = t
	return t


static func label(text: String, size: int = 26, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, kind: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	if kind != "":
		b.theme_type_variation = kind
	b.resized.connect(func(): b.pivot_offset = Vector2(0.0, b.size.y * 0.5))
	b.mouse_entered.connect(func(): _scale(b, 1.035))
	b.mouse_exited.connect(func(): _scale(b, 1.0))
	b.focus_entered.connect(func(): _scale(b, 1.035))
	b.focus_exited.connect(func(): _scale(b, 1.0))
	b.button_down.connect(func(): _scale(b, 0.97))
	b.button_up.connect(func(): _scale(b, 1.035 if b.is_hovered() else 1.0))
	b.pressed.connect(func(): play(b, "click"))
	b.mouse_entered.connect(func(): play(b, "hover"))
	return b


static func _scale(b: Control, s: float) -> void:
	if not b.is_inside_tree():
		return
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(s, s), 0.10).set_trans(Tween.TRANS_SINE)


static func _tone(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var k := float(i) / float(n)
		ph += TAU * lerpf(f0, f1, k) / rate
		var v := int(clampf(sin(ph) * (1.0 - k) * (1.0 - k) * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


static func play(owner: Node, kind: String) -> void:
	if not owner.is_inside_tree():
		return
	if not _snd.has(kind):
		_snd[kind] = _tone(660.0, 900.0, 0.08, 0.35) if kind == "click" else _tone(1300.0, 1300.0, 0.025, 0.10)
	var p := owner.get_node_or_null("UISfx") as AudioStreamPlayer
	if p == null:
		p = AudioStreamPlayer.new()
		p.name = "UISfx"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		owner.add_child(p)
	p.stream = _snd[kind]
	p.play()
