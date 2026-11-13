class_name ControlsPanel
extends Control
## Janela modal com a lista de controlos.

signal closed


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
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	v.add_child(UIKit.label("CONTROLOS", 44, UIKit.ACCENT))
	var rows: Array = [
		["Mover", "Joystick esquerdo" if Global.is_mobile else "W A S D"],
		["Olhar", "Arrastar à direita" if Global.is_mobile else "Rato"],
		["Disparar / Mirar", "Botões à direita" if Global.is_mobile else "Botão esq. / dir."],
		["Correr / Saltar", "Anel do joystick / botão" if Global.is_mobile else "Shift / Espaço"],
		["Recarregar / Trocar arma", "Botões" if Global.is_mobile else "R / Roda do rato"],
		["Entrar / sair do carro", "Botão USAR" if Global.is_mobile else "F"],
		["Mudar de vista (a pé e no carro)", "Botão da câmara" if Global.is_mobile else "V"],
		["Carro: travão de mão", "Botão TRAVÃO" if Global.is_mobile else "Espaço"],
		["Pausa", "Botão II" if Global.is_mobile else "Esc / P"],
	]
	for r in rows:
		var h := HBoxContainer.new()
		var a := UIKit.label(r[0], 24, UIKit.DIM)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(UIKit.label(r[1], 24, UIKit.TEXT))
		v.add_child(h)
	var back := UIKit.button("FECHAR", "PrimaryButton")
	back.pressed.connect(close)
	v.add_child(back)


func open() -> void:
	visible = true
	for c in find_children("*", "Button", true, false):
		(c as Button).grab_focus()
		break


func close() -> void:
	visible = false
	closed.emit()
