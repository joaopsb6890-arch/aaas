extends Control
## Menu principal animado.

const GAME_SCENE := "res://main_city.tscn"
const TITLE := "FPS DEMO"

var _buttons: Array[Button] = []
var _settings: SettingsPanel
var _controls: ControlsPanel
var _loading := false
var _bar: ProgressBar
var _fade: ColorRect
var _title_letters: Array[Label] = []
var _glow_t := 0.0


func _ready() -> void:
	Global.game_active = false
	Global.menu_open = false
	Global._apply_cursor_mode()
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()
	_settings = SettingsPanel.new()
	add_child(_settings)
	_controls = ControlsPanel.new()
	add_child(_controls)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.7)
	_animate_in()
	GameSettings.apply_graphics()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.material = ShaderMaterial.new()
	(bg.material as ShaderMaterial).shader = load("res://ui/menu_background.gdshader")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# faíscas a subir
	var p := CPUParticles2D.new()
	p.amount = 60
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 10)
	p.position = Vector2(576, 700)
	p.direction = Vector2(0.2, -1)
	p.spread = 20.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 0.55, 0.2, 0.0), Color(1, 0.6, 0.25, 0.9), Color(1, 0.3, 0.1, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	p.color_ramp = grad
	add_child(p)


func _build_menu() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 90.0
	col.offset_right = 560.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var tag := UIKit.label("SOBREVIVE  •  CONDUZ  •  ELIMINA", 20, UIKit.CYAN)
	col.add_child(tag)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	col.add_child(row)
	for ch in TITLE:
		var l := UIKit.label(ch, 84, UIKit.TEXT)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 8)
		row.add_child(l)
		_title_letters.append(l)
	var bar := ColorRect.new()
	bar.color = UIKit.ACCENT
	bar.custom_minimum_size = Vector2(0, 6)
	col.add_child(bar)
	bar.name = "AccentBar"
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	col.add_child(gap)
	var defs: Array = [
		["JOGAR", "PrimaryButton", _on_play],
		["OPÇÕES", "", func(): _settings.open()],
		["CONTROLOS", "", func(): _controls.open()],
	]
	if not OS.has_feature("web"):
		defs.append(["SAIR", "DangerButton", func(): get_tree().quit()])
	for d in defs:
		var b := UIKit.button(d[0], d[1])
		b.custom_minimum_size = Vector2(0, 68)
		b.pressed.connect(d[2])
		col.add_child(b)
		_buttons.append(b)
	var ver := UIKit.label("v1.0  •  Godot 4", 18, UIKit.DIM)
	add_child(ver)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -260.0
	ver.offset_top = -44.0
	ver.offset_right = -24.0
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# barra de carregamento
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.visible = false
	_bar.add_theme_stylebox_override("background", UIKit.box(Color(1, 1, 1, 0.12), 5))
	_bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.ACCENT, 5))
	col.add_child(_bar)
	_buttons[0].call_deferred("grab_focus")


func _animate_in() -> void:
	for i in _title_letters.size():
		var l := _title_letters[i]
		l.modulate.a = 0.0
		l.pivot_offset = Vector2(20, 60)
		l.scale = Vector2(1.0, 0.2)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(l, "modulate:a", 1.0, 0.4).set_delay(0.08 * i + 0.2)
		tw.tween_property(l, "scale", Vector2.ONE, 0.5).set_delay(0.08 * i + 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in _buttons.size():
		var b := _buttons[i]
		b.modulate.a = 0.0
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(b, "modulate:a", 1.0, 0.4).set_delay(0.7 + 0.1 * i)


func _process(delta: float) -> void:
	_glow_t += delta
	for i in _title_letters.size():
		var k := 0.5 + 0.5 * sin(_glow_t * 2.0 - i * 0.5)
		_title_letters[i].add_theme_color_override("font_color", UIKit.TEXT.lerp(UIKit.ACCENT_HI, k * 0.55))
	if _loading:
		var prog: Array = []
		var st := ResourceLoader.load_threaded_get_status(GAME_SCENE, prog)
		if prog.size() > 0:
			_bar.value = lerpf(_bar.value, float(prog[0]) * 100.0, 0.3)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_loading = false
			var ps := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
			var tw := create_tween()
			tw.tween_property(_fade, "color:a", 1.0, 0.35)
			tw.tween_callback(func(): get_tree().change_scene_to_packed(ps))
		elif st == ResourceLoader.THREAD_LOAD_FAILED:
			_loading = false
			get_tree().change_scene_to_file(GAME_SCENE)


func _on_play() -> void:
	if _loading:
		return
	for b in _buttons:
		b.disabled = true
	_bar.visible = true
	_loading = true
	ResourceLoader.load_threaded_request(GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _settings.visible:
			_settings.close()
		elif _controls.visible:
			_controls.close()
