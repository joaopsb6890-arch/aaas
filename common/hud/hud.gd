extends Control
## HUD: vida, munição, arma atual, inimigos mortos e ecrã de fim de jogo.
## O layout é calculado em código (centrado/ancorado) para funcionar em
## qualquer proporção de ecrã e respeitar o "notch" dos telemóveis.

@onready var enemies_label: Label = $EnemiesLabel
@onready var bullets_label: Label = $BulletsLabel
@onready var health_bar: ProgressBar = $HealthBar

var weapons_manager = null

var health_label: Label
var weapon_label: Label
var game_over_root: Control
var game_over_hint: Label
var _is_dead: bool = false
var _hit_flash: ColorRect
var _hit_tween: Tween


func _ready() -> void:
	Global.bullets_changed.connect(_on_bullets_changed)
	Global.player_health_changed.connect(_on_player_health_changed)
	Global.enemy_count_changed.connect(_on_enemy_count_changed)
	Global.player_dead.connect(_on_player_dead)
	get_viewport().size_changed.connect(_layout)

	# Get weapons manager from player
	if Global.player:
		weapons_manager = Global.player.get_node_or_null("WeaponsManager")

	_build_extra_nodes()
	_layout()

	# Initial display updates
	_on_bullets_changed()
	_on_enemy_count_changed(Global.enemies_killed)
	if Global.player:
		update_health_bar(Global.player.current_health, Global.player.MAX_HEALTH)


func _build_extra_nodes() -> void:
	health_label = Label.new()
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 22)
	health_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	health_label.add_theme_constant_override("outline_size", 5)
	health_bar.add_child(health_label)
	health_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	health_bar.show_percentage = false

	weapon_label = Label.new()
	weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.add_theme_font_size_override("font_size", 26)
	weapon_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	weapon_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	weapon_label.add_theme_constant_override("outline_size", 6)
	add_child(weapon_label)

	for l in [bullets_label, enemies_label]:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 8)

	# flash vermelho ao levar dano (sem texturas, barato)
	_hit_flash = ColorRect.new()
	_hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_flash.color = Color(0.9, 0.1, 0.1, 0.0)
	add_child(_hit_flash)
	_hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)

	# fim de jogo
	game_over_root = Control.new()
	game_over_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_root.visible = false
	add_child(game_over_root)
	game_over_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_root.add_child(dim)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "FIM DE JOGO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	game_over_root.add_child(title)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.offset_bottom = -60
	game_over_hint = Label.new()
	game_over_hint.text = "Toca no ecrã para recomeçar" if Global.is_mobile else "Prime R ou clica para recomeçar"
	game_over_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_hint.add_theme_font_size_override("font_size", 36)
	game_over_root.add_child(game_over_hint)
	game_over_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_hint.offset_top = 80


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	var inset := Global.get_safe_insets()
	var m := 36.0

	# Vida (topo-esquerda)
	health_bar.custom_minimum_size = Vector2(380, 34)
	health_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	health_bar.position = Vector2(inset.x + m, inset.y + m)
	health_bar.size = Vector2(380, 34)

	# Inimigos mortos (topo-direita)
	enemies_label.add_theme_font_size_override("font_size", 30)
	enemies_label.custom_minimum_size = Vector2(300, 0)
	enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemies_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	enemies_label.size = Vector2(300, 40)
	enemies_label.position = Vector2(s.x - inset.z - m - 300.0, inset.y + m - 4.0)

	# Munição + nome da arma (centro-baixo, livre dos botões táteis)
	bullets_label.add_theme_font_size_override("font_size", 44)
	bullets_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bullets_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bullets_label.size = Vector2(360, 56)
	bullets_label.position = Vector2((s.x - 360.0) * 0.5, s.y - inset.w - 80.0)
	weapon_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	weapon_label.size = Vector2(360, 34)
	weapon_label.position = Vector2((s.x - 360.0) * 0.5, s.y - inset.w - 112.0)


func _process(_delta: float) -> void:
	var on_foot := not Global.in_vehicle
	bullets_label.visible = on_foot
	if weapon_label:
		weapon_label.visible = on_foot


func _on_bullets_changed() -> void:
	if not weapons_manager or not weapons_manager.current_weapon:
		bullets_label.text = "-- / --"
		return

	var w = weapons_manager.current_weapon
	weapon_label.text = _pretty_name(w.name)

	var current_mag = weapons_manager.get_current_mag()
	var current_ammo = weapons_manager.get_current_ammo()

	if w.is_melee_weapon:
		bullets_label.text = "∞"
	elif current_ammo == -1:
		bullets_label.text = str(current_mag, " / ∞") if w.reload_required else "∞"
	else:
		bullets_label.text = str(current_mag, " / ", current_ammo) if w.reload_required else str(current_ammo)


func _pretty_name(raw: String) -> String:
	# "AssualtBurstRifle" -> "ASSUALT BURST RIFLE"
	var out := ""
	for i in raw.length():
		var c := raw[i]
		if i > 0 and c == c.to_upper() and c != c.to_lower():
			out += " "
		out += c
	return out.to_upper()


func _on_enemy_count_changed(count: int) -> void:
	enemies_label.text = str("ABATES: ", count)


func _on_player_health_changed(health_change: float, current_health: float, max_health: float, _is_enemy_damage: bool) -> void:
	update_health_bar(current_health, max_health)
	if health_change < 0.0 and _hit_flash:
		if _hit_tween:
			_hit_tween.kill()
		_hit_flash.color.a = 0.25
		_hit_tween = create_tween()
		_hit_tween.tween_property(_hit_flash, "color:a", 0.0, 0.35)


func update_health_bar(current_health, max_health) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	if health_label:
		health_label.text = str(int(ceil(current_health)))


func _on_player_dead() -> void:
	_is_dead = true
