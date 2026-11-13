extends Control
## HUD de jogo: vitalidade, munição, abates e dicas de controle.
##
## O HUD começa escondido (a cinemática de abertura chama play_intro()) e entra
## em cena com os painéis animados, na ordem em que o jogador precisa deles.

const UIKit = preload("res://ui/ui_kit.gd")

@onready var _health_panel: PanelContainer = $HealthPanel
@onready var _health_bar: ProgressBar = $HealthPanel/Margin/Box/HealthBar
@onready var _health_value: Label = $HealthPanel/Margin/Box/HealthValue
@onready var _health_kicker: Label = $HealthPanel/Margin/Box/HealthKicker
@onready var _kills_panel: PanelContainer = $KillsPanel
@onready var _enemies_label: Label = $KillsPanel/Margin/Box/EnemiesLabel
@onready var _kills_kicker: Label = $KillsPanel/Margin/Box/KillsKicker
@onready var _ammo_panel: PanelContainer = $AmmoPanel
@onready var _bullets_label: Label = $AmmoPanel/Margin/Box/BulletsLabel
@onready var _weapon_name: Label = $AmmoPanel/Margin/Box/WeaponName
@onready var _hint: Label = $Hint
@onready var _controls: PanelContainer = $ControlsBar
@onready var _crosshair: Control = $Crosshair

var _weapons_manager: Node = null
var _intro_played: bool = false
var _low_health: bool = false
var _pulse_tween: Tween = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style()
	_bind_player()

	Global.bullets_changed.connect(_on_bullets_changed)
	Global.player_health_changed.connect(_on_player_health_changed)
	Global.enemy_count_changed.connect(_on_enemy_count_changed)
	Global.player_dead.connect(_on_player_dead)

	_on_enemy_count_changed(0)
	_update_health(100.0, 100.0)

	# Se a abertura for pulada, o HUD entra sozinho.
	_auto_reveal()


func _style() -> void:
	UIKit.apply_font(_health_kicker, 14, UIKit.ACCENT)
	UIKit.apply_font(_health_value, 16, UIKit.TEXT)
	UIKit.apply_font(_kills_kicker, 12, UIKit.MUTED)
	UIKit.apply_font(_enemies_label, 38, UIKit.TEXT)
	UIKit.apply_font(_weapon_name, 14, UIKit.MUTED)
	UIKit.apply_font(_bullets_label, 34, UIKit.TEXT)
	UIKit.apply_font(_hint, 16, UIKit.MUTED)
	_enemies_label.text = "00"
	_bullets_label.text = "-- / --"
	_hint.modulate.a = 0.0
	_crosshair.modulate.a = 0.0

	for chip in $ControlsBar/Margin/Row.get_children():
		if chip is Label:
			UIKit.apply_font(chip, 13, UIKit.MUTED)

	for panel in [_health_panel, _kills_panel, _ammo_panel, _controls]:
		panel.add_theme_stylebox_override("panel", _panel_style(panel == _health_panel))
		panel.modulate.a = 0.0

	var fill := _health_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		fill = fill.duplicate()
		_health_bar.add_theme_stylebox_override("fill", fill)


func _panel_style(accent: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.043, 0.058, 0.078, 0.86)
	style.set_corner_radius_all(6)
	style.border_width_left = 3 if accent else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = UIKit.ACCENT if accent else Color(1, 1, 1, 0.1)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 14
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


func _bind_player() -> void:
	var player := Global.player
	if not is_instance_valid(player):
		return
	_weapons_manager = player.get_node_or_null("WeaponsManager")
	_refresh_ammo()


func _auto_reveal() -> void:
	await get_tree().create_timer(0.6).timeout
	if _intro_played or Global.cinematic_mode:
		return
	visible = true
	play_intro()


## Chamado pela cinemática quando o jogador termina de levantar.
func play_intro() -> void:
	if _intro_played:
		visible = true
		return
	_intro_played = true
	visible = true
	modulate.a = 1.0
	_bind_player()

	await get_tree().process_frame
	for panel in [_health_panel, _kills_panel, _ammo_panel, _controls]:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.94, 0.94)

	_reveal(_health_panel, 0.05)
	_reveal(_kills_panel, 0.16)
	_reveal(_ammo_panel, 0.28)
	_reveal(_controls, 0.44)
	_fade(_crosshair, 0.3, 0.5)
	_fade(_hint, 1.0, 0.8)

	_hint.text = "MISSÃO: LIMPAR O SETOR"
	_hint.modulate.a = 1.0
	var hint_tw := create_tween()
	hint_tw.tween_property(_hint, "modulate:a", 0.0, 1.0).set_delay(6.0)

	var controls_tw := create_tween()
	controls_tw.tween_property(_controls, "modulate:a", 0.0, 1.0).set_delay(14.0)


func _reveal(panel: Control, delay: float) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.35).set_delay(delay)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.45).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _fade(node: CanvasItem, target: float, delay: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", target, 0.4).set_delay(delay)


# ------------------------------------------------------------------- updates

func _on_bullets_changed() -> void:
	_refresh_ammo()


func _refresh_ammo() -> void:
	if _weapons_manager == null and is_instance_valid(Global.player):
		_weapons_manager = Global.player.get_node_or_null("WeaponsManager")
	if _weapons_manager == null or _weapons_manager.current_weapon == null:
		_bullets_label.text = "-- / --"
		return

	var weapon = _weapons_manager.current_weapon
	_weapon_name.text = String(weapon.name).to_upper()
	var mag: int = int(_weapons_manager.get_current_mag())
	var ammo: int = int(_weapons_manager.get_current_ammo())

	var melee: bool = bool(weapon.get("is_melee_weapon"))
	if melee or mag < 0:
		_bullets_label.text = "∞"
	elif ammo == -1:
		_bullets_label.text = ("%d / ∞" % mag) if weapon.reload_required else "∞"
	elif weapon.reload_required:
		_bullets_label.text = "%d / %d" % [mag, ammo]
	else:
		_bullets_label.text = str(ammo)


func _on_enemy_count_changed(count: int) -> void:
	_enemies_label.text = "%02d" % count
	var tw := create_tween()
	_enemies_label.modulate = UIKit.ACCENT
	tw.tween_property(_enemies_label, "modulate", UIKit.TEXT, 0.45)


func _on_player_health_changed(_health_change: float, current_health: float, max_health: float, _is_enemy_damage: bool) -> void:
	_update_health(current_health, max_health)


func _update_health(current_health: float, max_health: float) -> void:
	_health_bar.max_value = maxf(max_health, 1.0)
	_health_bar.value = current_health
	_health_value.text = "%d / %d" % [int(round(current_health)), int(round(max_health))]

	var ratio := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	var fill := _health_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		var color := UIKit.ACCENT.lerp(UIKit.DANGER, clampf((0.55 - ratio) / 0.55, 0.0, 1.0))
		(fill as StyleBoxFlat).bg_color = color

	if ratio <= 0.3 and not _low_health:
		_low_health = true
		_start_low_health_pulse()
	elif ratio > 0.3 and _low_health:
		_low_health = false
		if _pulse_tween != null and _pulse_tween.is_valid():
			_pulse_tween.kill()
		_health_panel.modulate.a = 1.0


func _start_low_health_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_health_panel, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_health_panel, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


func _on_player_dead() -> void:
	_hint.text = "VOCÊ CAIU  —  ESC PARA REINICIAR"
	_hint.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_hint, "modulate:a", 0.65, 1.0).set_trans(Tween.TRANS_SINE)
