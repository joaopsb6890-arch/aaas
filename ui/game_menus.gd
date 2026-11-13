extends CanvasLayer
## Menu de pausa profissional + ecrã de fim de jogo. Adicionado pela cena de jogo.

var _root: Control
var _blur: ColorRect
var _panel: Control
var _title: Label
var _stats: Label
var _buttons: Array[Button] = []
var _resume: Button
var _confirm: Control
var _confirm_action: Callable
var _settings: SettingsPanel
var _controls: ControlsPanel
var _open := false
var _dead := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UIKit.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	_blur = ColorRect.new()
	_blur.material = ShaderMaterial.new()
	(_blur.material as ShaderMaterial).shader = load("res://ui/blur.gdshader")
	_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_blur)
	_build_panel()
	_build_confirm()
	_settings = SettingsPanel.new()
	_root.add_child(_settings)
	_controls = ControlsPanel.new()
	_root.add_child(_controls)
	Global.pause_requested.connect(_on_pause_requested)
	Global.player_dead.connect(_on_player_dead)


func _build_panel() -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 90.0
	col.offset_right = 520.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_title = UIKit.label("PAUSA", 80, UIKit.TEXT)
	col.add_child(_title)
	var bar := ColorRect.new()
	bar.color = UIKit.ACCENT
	bar.custom_minimum_size = Vector2(120, 6)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(bar)
	_stats = UIKit.label("", 22, UIKit.DIM)
	col.add_child(_stats)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	col.add_child(gap)
	_resume = _add_button(col, "CONTINUAR", "PrimaryButton", close_pause)
	_add_button(col, "OPÇÕES", "", func(): _settings.open())
	_add_button(col, "CONTROLOS", "", func(): _controls.open())
	_add_button(col, "REINICIAR", "", func(): _ask("Reiniciar a partida?", Global.restart_game))
	_add_button(col, "MENU PRINCIPAL", "DangerButton", func(): _ask("Voltar ao menu principal?", Global.go_to_main_menu))


func _add_button(parent: Node, text: String, kind: String, cb: Callable) -> Button:
	var b := UIKit.button(text, kind)
	b.custom_minimum_size = Vector2(0, 62)
	b.pressed.connect(cb)
	parent.add_child(b)
	_buttons.append(b)
	return b


func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	_root.add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	_confirm.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_confirm.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pc := PanelContainer.new()
	center.add_child(pc)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 36)
	pc.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)
	var q := UIKit.label("Tens a certeza?", 34)
	q.name = "Question"
	v.add_child(q)
	v.add_child(UIKit.label("O progresso desta partida perde-se.", 22, UIKit.DIM))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var no := UIKit.button("CANCELAR")
	no.custom_minimum_size = Vector2(200, 60)
	no.pressed.connect(func(): _confirm.visible = false)
	h.add_child(no)
	var yes := UIKit.button("CONFIRMAR", "DangerButton")
	yes.custom_minimum_size = Vector2(200, 60)
	yes.pressed.connect(func():
		_confirm.visible = false
		_confirm_action.call())
	h.add_child(yes)


func _ask(text: String, action: Callable) -> void:
	(_confirm.find_child("Question", true, false) as Label).text = text
	_confirm_action = action
	_confirm.visible = true


func _on_pause_requested() -> void:
	if _dead:
		return
	if _open:
		close_pause()
	else:
		open_pause()


func _unhandled_input(event: InputEvent) -> void:
	if not Global.game_active or not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if _confirm.visible:
		_confirm.visible = false
	elif _settings.visible:
		_settings.close()
	elif _controls.visible:
		_controls.close()
	elif not _dead:
		_on_pause_requested()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and Global.game_active and not _open and not _dead:
		open_pause()


func _refresh_stats() -> void:
	var t := int(Global.play_time)
	_stats.text = "ABATES  %d     TEMPO  %02d:%02d     CONDUZIDO  %.1f km" % [Global.enemies_killed, t / 60, t % 60, Global.distance_driven / 1000.0]


func open_pause() -> void:
	_open = true
	_title.text = "PAUSA"
	_resume.visible = true
	_refresh_stats()
	_show()


func close_pause() -> void:
	_open = false
	_confirm.visible = false
	_root.visible = false
	get_tree().paused = false
	Global.set_menu_open(false)


func _show() -> void:
	get_tree().paused = true
	Global.set_menu_open(true)
	_root.visible = true
	_panel.modulate.a = 0.0
	_panel.position.x = -60.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_blur.material.set_shader_parameter("amount", 0.0)
	tw.tween_property(_blur.material, "shader_parameter/amount", 1.0, 0.3)
	_resume.grab_focus() if _resume.visible else _buttons[3].grab_focus()


func _on_player_dead() -> void:
	_dead = true
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	_title.text = "FIM DE JOGO"
	_title.add_theme_color_override("font_color", UIKit.DANGER)
	_resume.visible = false
	_refresh_stats()
	_open = true
	_show()
