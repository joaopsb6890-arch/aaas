class_name SettingsPanel
extends Control
## Janela modal de opções (usada no menu principal e no menu de pausa).

signal closed

var _content: VBoxContainer
var _panel: PanelContainer


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_panel.add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	margin.add_child(_content)
	_build()


func _build() -> void:
	var title := UIKit.label("OPÇÕES", 44, UIKit.ACCENT)
	_content.add_child(title)
	_slider("Volume geral", 0.0, 1.0, GameSettings.master_volume, func(v): GameSettings.master_volume = v, true)
	_slider("Campo de visão (FOV)", 60.0, 100.0, GameSettings.fov, func(v): GameSettings.fov = v, false)
	_slider("Sensibilidade", 0.4, 2.0, GameSettings.look_sens, func(v): GameSettings.look_sens = v, false, "x")
	if Global.is_mobile:
		_slider("Auxílio de mira", 0.0, 1.0, GameSettings.aim_assist, func(v): GameSettings.aim_assist = v, true)
		_slider("Tamanho dos botões", 0.8, 1.4, GameSettings.ui_scale, func(v): GameSettings.ui_scale = v, true)
		_toggle("Vibração", GameSettings.haptics, func(v): GameSettings.haptics = v)
	# qualidade gráfica
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UIKit.label("Qualidade gráfica", 26)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var grp := ButtonGroup.new()
	for i in 3:
		var b := Button.new()
		b.text = GameSettings.QUALITY_NAMES[i]
		b.toggle_mode = true
		b.button_group = grp
		b.button_pressed = GameSettings.quality == i
		b.custom_minimum_size = Vector2(120, 0)
		var idx := i
		b.pressed.connect(func():
			GameSettings.quality = idx
			GameSettings.apply_all()
			GameSettings.apply_to_scene(get_tree().current_scene))
		row.add_child(b)
	_content.add_child(row)
	_toggle("Mostrar FPS", GameSettings.show_fps, func(v): GameSettings.show_fps = v)
	if not Global.is_mobile and not OS.has_feature("web"):
		_toggle("Ecrã inteiro", GameSettings.fullscreen, func(v): GameSettings.fullscreen = v)
	var back := UIKit.button("FECHAR", "PrimaryButton")
	back.pressed.connect(close)
	_content.add_child(back)


func _slider(text: String, lo: float, hi: float, val: float, setter: Callable, percent: bool, suffix: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := UIKit.label(text, 26)
	l.custom_minimum_size = Vector2(320, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01 if hi <= 2.0 else 1.0
	s.value = val
	s.custom_minimum_size = Vector2(300, 44)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := UIKit.label("", 26, UIKit.CYAN)
	v.custom_minimum_size = Vector2(90, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	var fmt := func(x: float):
		if percent:
			v.text = "%d%%" % int(round((x - lo) / (hi - lo) * 100.0)) if lo != 0.0 else "%d%%" % int(round(x * 100.0))
		elif suffix != "":
			v.text = "%.2f%s" % [x, suffix]
		else:
			v.text = "%d" % int(x)
	fmt.call(val)
	s.value_changed.connect(func(x: float):
		setter.call(x)
		fmt.call(x)
		GameSettings.apply_all())
	_content.add_child(row)


func _toggle(text: String, val: bool, setter: Callable) -> void:
	var row := HBoxContainer.new()
	var l := UIKit.label(text, 26)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = val
	b.custom_minimum_size = Vector2(190, 0)
	b.text = "LIGADO" if val else "DESLIGADO"
	b.toggled.connect(func(on: bool):
		b.text = "LIGADO" if on else "DESLIGADO"
		setter.call(on)
		GameSettings.apply_all())
	row.add_child(b)
	_content.add_child(row)


func open() -> void:
	visible = true
	modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	_panel.pivot_offset = _panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for c in _content.get_children():
		if c is Button:
			c.grab_focus()


func close() -> void:
	if not visible:
		return
	GameSettings.commit()
	visible = false
	closed.emit()
