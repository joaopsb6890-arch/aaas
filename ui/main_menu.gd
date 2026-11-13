extends Control
## Menu principal: visual tático, entrada em cascata e transição para o
## carregamento do mundo (ui/loader.tscn).

const UIKit = preload("res://ui/ui_kit.gd")

const LOADER_SCENE := "res://ui/loader.tscn"

@onready var _brand: Label = %BrandName
@onready var _brand_sub: Label = %BrandSub
@onready var _status: Label = %StatusLabel
@onready var _dot: ColorRect = %Dot
@onready var _kicker: Label = %Kicker
@onready var _title: Label = %Title
@onready var _title_tag: Label = %TitleTag
@onready var _divider: ColorRect = %Divider
@onready var _subtitle: Label = %Subtitle
@onready var _description: Label = %Description
@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _version: Label = %Version
@onready var _footer_note: Label = %FooterNote
@onready var _mission_card: PanelContainer = %MissionCard
@onready var _mission_kicker: Label = %MissionKicker
@onready var _mission_title: Label = %MissionTitle
@onready var _controls_card: PanelContainer = %ControlsCard
@onready var _controls_kicker: Label = %ControlsKicker
@onready var _hint: Label = %Hint
@onready var _reticle: Control = $Reticle

var _starting: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	Global.player = null
	Global.in_vehicle = false
	Global.cinematic_mode = false
	modulate.a = 1.0

	_style_ui()
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_play_button.grab_focus()
	_animate_intro()
	_pulse_status()


func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if get_viewport().gui_get_focus_owner() == null:
			_play_button.grab_focus()


func _style_ui() -> void:
	UIKit.apply_font(_brand, 15, UIKit.TEXT)
	UIKit.apply_font(_brand_sub, 12, UIKit.MUTED)
	UIKit.apply_font(_status, 13, UIKit.MUTED)
	UIKit.apply_font(_kicker, 17, UIKit.ACCENT)
	UIKit.apply_font(_title, 104, UIKit.TEXT)
	UIKit.apply_font(_title_tag, 22, UIKit.ACCENT)
	UIKit.apply_font(_subtitle, 17, UIKit.MUTED)
	UIKit.apply_font(_description, 16, UIKit.MUTED)
	_description.custom_minimum_size.x = 520.0
	UIKit.apply_font(_version, 13, UIKit.MUTED)
	UIKit.apply_font(_footer_note, 12, Color(0.55, 0.61, 0.68, 0.9))
	UIKit.apply_font(_mission_kicker, 14, UIKit.ACCENT)
	UIKit.apply_font(_mission_title, 30, UIKit.TEXT)
	UIKit.apply_font(_controls_kicker, 14, UIKit.ACCENT)
	UIKit.apply_font(_hint, 12, UIKit.MUTED)

	for label in _mission_card.find_children("*", "Label", true, false):
		if label.name.begins_with("Key"):
			UIKit.apply_font(label, 13, UIKit.MUTED)
		elif label.name.begins_with("Value"):
			UIKit.apply_font(label, 13, UIKit.TEXT)
	for label in _controls_card.find_children("*", "Label", true, false):
		if not label.name.begins_with("ControlsKicker"):
			UIKit.apply_font(label, 13, UIKit.TEXT)

	_divider.color = UIKit.ACCENT
	_mission_card.add_theme_stylebox_override("panel", _card_style())
	_controls_card.add_theme_stylebox_override("panel", _card_style(Color(1, 1, 1, 0.07)))

	UIKit.style_button(_play_button, true)
	UIKit.style_button(_quit_button, false)
	UIKit.wire_button(_play_button)
	UIKit.wire_button(_quit_button)
	_play_button.add_theme_font_size_override("font_size", 27)
	_quit_button.add_theme_font_size_override("font_size", 22)


func _card_style(border: Color = Color(1, 0.623, 0.11, 0.45)) -> StyleBoxFlat:
	var style := UIKit.panel(Color(0.043, 0.058, 0.078, 0.78), 6)
	style.border_width_left = 3
	style.border_color = border
	style.shadow_size = 22
	return style


func _animate_intro() -> void:
	_reticle.modulate.a = 0.0
	var reticle_tw := create_tween()
	reticle_tw.tween_property(_reticle, "modulate:a", 1.0, 1.6).set_delay(0.15)

	for node in [_brand, _brand_sub, _status, _dot]:
		UIKit.pop(node, 0.0)

	UIKit.pop(_kicker, 0.08)
	UIKit.pop(_title, 0.16)
	UIKit.pop(_title_tag, 0.24)
	UIKit.pop(_divider, 0.3)
	UIKit.pop(_subtitle, 0.35)
	UIKit.pop(_description, 0.42)
	UIKit.pop(_play_button, 0.52)
	UIKit.pop(_quit_button, 0.6)
	UIKit.pop(_mission_card, 0.5)
	UIKit.pop(_controls_card, 0.62)
	UIKit.pop(_hint, 0.74)
	UIKit.pop(_version, 0.7)
	UIKit.pop(_footer_note, 0.76)

	var tw := create_tween().set_loops()
	tw.tween_property(_divider, "modulate", Color(1, 1, 1, 0.75), 2.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_divider, "modulate", Color(1, 1, 1, 1.0), 2.6).set_trans(Tween.TRANS_SINE)


func _pulse_status() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(_dot, "modulate:a", 0.25, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_dot, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)


func _on_play_pressed() -> void:
	if _starting:
		return
	_starting = true
	_play_button.disabled = true
	_quit_button.disabled = true
	UIKit.animate_hover(_play_button, false)
	_hint.text = "CARREGANDO O SETOR..."

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished

	var err := get_tree().change_scene_to_file(LOADER_SCENE)
	if err != OK:
		push_error("Não foi possível abrir %s (erro %d)" % [LOADER_SCENE, err])
		_starting = false
		_play_button.disabled = false
		_quit_button.disabled = false
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func _on_quit_pressed() -> void:
	await get_tree().create_timer(0.05).timeout
	get_tree().quit()
