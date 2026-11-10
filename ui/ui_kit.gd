extends RefCounted
## Shared look & feel for the menus (fonts, colors, style boxes, hover animation).
## Usage: const UIKit = preload("res://ui/ui_kit.gd")

const FONT_PATH := "res://resources/fonts/ShareTech-Regular.ttf"

const ACCENT := Color("ff9f1c")
const ACCENT_DARK := Color("b96f00")
const TEXT := Color("e9eef5")
const MUTED := Color("93a3b8")
const SURFACE := Color("121a24")
const SURFACE_HOVER := Color("1e2a38")
const PANEL_BG := Color(0.043, 0.059, 0.086, 0.92)
const DANGER := Color("e5484d")


static func load_font() -> Font:
	var res := load(FONT_PATH)
	if res is Font:
		return res
	return ThemeDB.fallback_font


static func apply_font(node: Control, size: int, color: Color, outline: int = 0) -> void:
	var font := load_font()
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	if node is Label:
		node.add_theme_color_override("font_color", color)
	elif node is Button:
		node.add_theme_color_override("font_color", color)
	if outline > 0:
		node.add_theme_constant_override("outline_size", outline)
		node.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))


static func box(bg: Color, border_color: Color = Color.TRANSPARENT, border_left: int = 0, content_margin: float = 18.0, radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = content_margin + float(border_left)
	sb.content_margin_right = content_margin
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	if border_left > 0:
		sb.border_width_left = border_left
		sb.border_color = border_color
	return sb


static func panel(bg: Color = PANEL_BG, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1.0, 1.0, 1.0, 0.08)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 18
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 26.0
	sb.content_margin_bottom = 26.0
	return sb


static func style_button(button: Button, accent: bool = false) -> void:
	var tint := ACCENT if accent else Color("9fb2c8")
	button.add_theme_stylebox_override("normal", box(SURFACE, tint, 3))
	button.add_theme_stylebox_override("hover", box(SURFACE_HOVER, tint, 6))
	button.add_theme_stylebox_override("pressed", box(tint.darkened(0.55), tint, 6))
	button.add_theme_stylebox_override("focus", box(Color(0.0, 0.0, 0.0, 0.0), tint, 6))
	button.add_theme_stylebox_override("disabled", box(Color(0.07, 0.08, 0.1), Color(0.3, 0.3, 0.3), 3))
	apply_font(button, 24, TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.06))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func animate_hover(button: Button, hovered: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var tw := button.create_tween()
	tw.tween_property(button, "scale", Vector2.ONE * (1.03 if hovered else 1.0), 0.14).set_trans(Tween.TRANS_SINE)


static func wire_button(button: Button) -> void:
	button.mouse_entered.connect(func() -> void: animate_hover(button, true))
	button.mouse_exited.connect(func() -> void: animate_hover(button, false))
	button.focus_entered.connect(func() -> void: animate_hover(button, true))
	button.focus_exited.connect(func() -> void: animate_hover(button, false))


## Fade + pop used for the intro choreography.
static func pop(node: Control, delay: float) -> void:
	node.modulate.a = 0.0
	node.scale = Vector2(0.95, 0.95)
	if node.size != Vector2.ZERO:
		node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.5).set_delay(delay)
	tw.tween_property(node, "scale", Vector2.ONE, 0.55).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
