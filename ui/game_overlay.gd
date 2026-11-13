extends CanvasLayer
## Velocímetro do carro + aviso do nome da vista de câmara.

var _gauge: Control
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	layer = 5
	_gauge = Control.new()
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gauge.draw.connect(_draw_gauge)
	_gauge.visible = false
	add_child(_gauge)
	_toast = Label.new()
	_toast.theme = UIKit.theme()
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.add_theme_color_override("font_color", UIKit.TEXT)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -300.0
	_toast.offset_right = 300.0
	_toast.offset_top = 140.0
	Global.camera_view_changed.connect(_on_view_changed)


func _on_view_changed(_ctx: String, _idx: int, view_name: String) -> void:
	_toast.text = "VISTA: " + view_name
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _process(_delta: float) -> void:
	var show_gauge := Global.in_vehicle and Global.vehicle != null
	_gauge.visible = show_gauge
	if show_gauge:
		_gauge.queue_redraw()


func _draw_gauge() -> void:
	var v: Node = Global.vehicle
	if v == null or not is_instance_valid(v):
		return
	var s := _gauge.get_viewport_rect().size
	var c := Vector2(s.x * 0.5, s.y - 110.0)
	var r := 82.0
	var kmh: float = v.speed_kmh
	var k := clampf(kmh / 160.0, 0.0, 1.0)
	var a0 := deg_to_rad(150.0)
	var sweep := deg_to_rad(240.0)
	_gauge.draw_circle(c, r + 12.0, Color(0, 0, 0, 0.45))
	_gauge.draw_arc(c, r, a0, a0 + sweep, 48, Color(1, 1, 1, 0.18), 10.0, true)
	var col := UIKit.CYAN.lerp(UIKit.DANGER, clampf((k - 0.65) / 0.35, 0.0, 1.0))
	if k > 0.01:
		_gauge.draw_arc(c, r, a0, a0 + sweep * k, 48, col, 10.0, true)
	for i in 9:
		var ang := a0 + sweep * float(i) / 8.0
		var d := Vector2.from_angle(ang)
		_gauge.draw_line(c + d * (r - 16.0), c + d * (r - 26.0), Color(1, 1, 1, 0.5), 2.0, true)
	var f := UIKit.font()
	var txt := str(int(kmh))
	var ts := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 52)
	_gauge.draw_string(f, c + Vector2(-ts.x * 0.5, 14.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, UIKit.TEXT)
	var u := f.get_string_size("KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	_gauge.draw_string(f, c + Vector2(-u.x * 0.5, 40.0), "KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.DIM)
	var g := str(v.gear)
	var gs := f.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	_gauge.draw_string(f, c + Vector2(-gs.x * 0.5, -34.0), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIKit.ACCENT)
