extends CanvasLayer
## Global pause menu (autoload). Press ESC in game to open it.

const UIKit = preload("res://ui/ui_kit.gd")

const MAIN_MENU_SCENE := "res://ui/main_menu.tscn"

@onready var _root: Control = $Root
@onready var _panel: PanelContainer = $Root/Center/Panel
@onready var _kicker: Label = $Root/Center/Panel/Margin/Box/Kicker
@onready var _title: Label = $Root/Center/Panel/Margin/Box/Title
@onready var _rule: ColorRect = $Root/Center/Panel/Margin/Box/Rule
@onready var _resume: Button = $Root/Center/Panel/Margin/Box/Resume
@onready var _restart: Button = $Root/Center/Panel/Margin/Box/Restart
@onready var _menu_button: Button = $Root/Center/Panel/Margin/Box/MenuButton
@onready var _quit: Button = $Root/Center/Panel/Margin/Box/Quit
@onready var _hint: Label = $Root/Center/Panel/Margin/Box/Hint

var _open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_style_ui()
	_resume.pressed.connect(close)
	_restart.pressed.connect(_on_restart_pressed)
	_menu_button.pressed.connect(_on_main_menu_pressed)
	_quit.pressed.connect(_on_quit_pressed)


func _input(event: InputEvent) -> void:
	if Global.cinematic_mode:
		return
	if not event.is_action_pressed("exit"):
		return
	if _is_main_menu():
		return
	if _open:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	if _open or _is_main_menu():
		return
	_open = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_root.visible = true
	_animate_open()
	_resume.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.12)
	await tw.finished
	# A cena pode ter sido trocada durante o fade.
	if not is_instance_valid(_root):
		return
	if not _open:
		_root.visible = false
		_root.modulate.a = 1.0


func _style_ui() -> void:
	UIKit.apply_font(_kicker, 15, UIKit.ACCENT)
	UIKit.apply_font(_title, 64, UIKit.TEXT)
	UIKit.apply_font(_hint, 14, UIKit.MUTED)
	_rule.color = UIKit.ACCENT

	UIKit.style_button(_resume, true)
	UIKit.style_button(_restart, false)
	UIKit.style_button(_menu_button, false)
	UIKit.style_button(_quit, false)

	for button in [_resume, _restart, _menu_button, _quit]:
		UIKit.wire_button(button)

	_panel.add_theme_stylebox_override("panel", UIKit.panel())


func _animate_open() -> void:
	_root.modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.96, 0.96)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.16)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _is_main_menu() -> bool:
	var scene := get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return false
	# O carregamento também não deve abrir o menu de pausa.
	return scene.scene_file_path in [MAIN_MENU_SCENE, "res://ui/loader.tscn"]


func _on_restart_pressed() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_open = false
	_root.visible = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	_open = false
	_root.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
