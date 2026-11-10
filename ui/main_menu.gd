extends Control
## Main menu with animated background, staggered intro and hover feedback.

const UIKit = preload("res://ui/ui_kit.gd")

const GAME_SCENE := "res://main.tscn"

@onready var _kicker: Label = $Content/Row/Left/Kicker
@onready var _title: Label = $Content/Row/Left/Title
@onready var _divider: ColorRect = $Content/Row/Left/Divider
@onready var _subtitle: Label = $Content/Row/Left/Subtitle
@onready var _play_button: Button = $Content/Row/Left/Buttons/PlayButton
@onready var _quit_button: Button = $Content/Row/Left/Buttons/QuitButton
@onready var _version: Label = $Content/Row/Left/Version
@onready var _right: VBoxContainer = $Content/Row/Right
@onready var _controls_title: Label = $Content/Row/Right/ControlsTitle
@onready var _controls_panel: PanelContainer = $Content/Row/Right/ControlsPanel
@onready var _controls_list: VBoxContainer = $Content/Row/Right/ControlsPanel/ControlsMargin/ControlsList
@onready var _hint: Label = $Content/Row/Right/Hint

var _starting: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	# Limpa o estado do jogo anterior (o nó do jogador já foi liberado junto
	# com a fase; manter a referência antiga gera erros de instância liberada).
	Global.player = null
	Global.in_vehicle = false
	modulate.a = 1.0
	_style_ui()
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_play_button.grab_focus()
	_animate_intro()


func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Any key press gives the menu focus back after an alt-tab.
		if get_viewport().gui_get_focus_owner() == null:
			_play_button.grab_focus()


func _style_ui() -> void:
	UIKit.apply_font(_kicker, 18, UIKit.ACCENT)
	UIKit.apply_font(_title, 92, UIKit.TEXT)
	UIKit.apply_font(_subtitle, 19, UIKit.MUTED)
	UIKit.apply_font(_version, 15, UIKit.MUTED)
	UIKit.apply_font(_hint, 14, UIKit.MUTED)
	UIKit.apply_font(_controls_title, 16, UIKit.ACCENT)

	_divider.color = UIKit.ACCENT

	for item in _controls_list.get_children():
		if item is Label:
			UIKit.apply_font(item, 15, UIKit.TEXT)

	UIKit.style_button(_play_button, true)
	UIKit.style_button(_quit_button, false)
	UIKit.wire_button(_play_button)
	UIKit.wire_button(_quit_button)

	_controls_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.047, 0.063, 0.09, 0.72), Color(1, 1, 1, 0.08), 0, 20.0, 6))


func _animate_intro() -> void:
	UIKit.pop(_kicker, 0.05)
	UIKit.pop(_title, 0.11)
	UIKit.pop(_divider, 0.18)
	UIKit.pop(_subtitle, 0.24)
	UIKit.pop(_play_button, 0.34)
	UIKit.pop(_quit_button, 0.42)
	UIKit.pop(_right, 0.32)
	UIKit.pop(_version, 0.55)
	_pulse_title()


func _pulse_title() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(_title, "modulate", Color(1, 1, 1, 0.84), 2.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_title, "modulate", Color(1, 1, 1, 1.0), 2.4).set_trans(Tween.TRANS_SINE)


func _on_play_pressed() -> void:
	if _starting:
		return
	_starting = true
	_play_button.disabled = true
	_quit_button.disabled = true
	UIKit.animate_hover(_play_button, false)

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	await tw.finished

	var err := get_tree().change_scene_to_file(GAME_SCENE)
	if err != OK:
		push_error("Nao foi possivel carregar %s (erro %d)" % [GAME_SCENE, err])
		_starting = false
		_play_button.disabled = false
		_quit_button.disabled = false
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _on_quit_pressed() -> void:
	await get_tree().create_timer(0.05).timeout
	get_tree().quit()
