extends CanvasLayer
## Transient bottom-center label used to confirm camera changes.

const FONT_PATH := "res://resources/fonts/ShareTech-Regular.ttf"
const HOLD_TIME := 1.2
const FADE_TIME := 0.35

var _label: Label
var _tween: Tween


func _ready() -> void:
	layer = 25
	_label = Label.new()
	_label.text = ""
	_label.modulate.a = 0.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = -320.0
	_label.offset_right = 320.0
	_label.offset_top = -132.0
	_label.offset_bottom = -92.0

	var font := load(FONT_PATH)
	if font is Font:
		_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color("e9eef5"))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 8)
	add_child(_label)


func toast(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	_label.modulate.a = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(_label, "modulate:a", 0.0, FADE_TIME)
