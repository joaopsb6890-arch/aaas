extends Node

var debug_mode: bool = false
var player: CharacterBody3D
var enemies_killed: int = 0
var in_vehicle: bool = false
## Veículo que o jogador está a conduzir (null a pé).
var vehicle: Node = null
## true enquanto a cena de jogo está ativa (false nos menus).
var game_active: bool = false
## true quando um menu (pausa, fim de jogo...) está a capturar o input.
var menu_open: bool = false
## Estatísticas da partida atual.
var play_time: float = 0.0
var distance_driven: float = 0.0

## Põe a true para testar os controlos táteis no PC.
const FORCE_MOBILE: bool = false
var is_mobile: bool = false

# ---- Otimização mobile (ajusta à vontade) ----
## Resolução 3D relativa ao ecrã (a interface continua nítida). 0.6 = rápido, 1.0 = nativo.
const MOBILE_RENDER_SCALE: float = 0.75
## Resolução 3D das armas/braços (SubViewport).
const MOBILE_WEAPON_RENDER_SCALE: float = 0.7
const MOBILE_MAX_FPS: int = 60
const MOBILE_SHADOW_DISTANCE: float = 50.0
## Número máximo de buracos de bala na cena.
const MAX_DECALS_MOBILE: int = 24
const MAX_DECALS_DESKTOP: int = 80

## Auxílio de mira: 0 = desligado, 1 = forte (também ajustável no menu de opções).
var aim_assist_strength: float = 0.6
## true quando o auxílio tem um inimigo na mira (a mira fica vermelha).
var aim_on_target: bool = false

var _decals: Array[Node] = []

@warning_ignore("unused_signal")
signal enemy_killed

@warning_ignore("unused_signal")
signal enemy_count_changed(count: int)

@warning_ignore("unused_signal")
signal aim_mode_changed

@warning_ignore("unused_signal")
signal active_camera_fov_changed

@warning_ignore("unused_signal")
signal fire_input

@warning_ignore("unused_signal")
signal reload_input

@warning_ignore("unused_signal")
signal weapon_switch_next

@warning_ignore("unused_signal")
signal weapon_switch_prev

@warning_ignore("unused_signal")
signal bullets_changed

@warning_ignore("unused_signal")
signal camera_shake

@warning_ignore("unused_signal")
signal player_velocity_changed

@warning_ignore("unused_signal")
signal player_health_changed(health_change: float, current_health: float, max_health: float, is_enemy_damage: bool)

@warning_ignore("unused_signal")
signal player_dead

@warning_ignore("unused_signal")
signal player_sprinting_changed

@warning_ignore("unused_signal")
signal activate_pressed

## Ruído no mundo (tiros, explosões, motor): os inimigos ouvem-no.
@warning_ignore("unused_signal")
signal noise_made(position: Vector3, radius: float)

## Tecla V / botão de câmara: muda a vista (a pé ou no carro).
@warning_ignore("unused_signal")
signal camera_view_pressed

@warning_ignore("unused_signal")
signal camera_view_changed(context: String, index: int, view_name: String)

@warning_ignore("unused_signal")
signal vehicle_entered(vehicle: Node)

@warning_ignore("unused_signal")
signal vehicle_exited

## Pede para abrir o menu de pausa (botão tátil, perda de foco...).
@warning_ignore("unused_signal")
signal pause_requested

## Rotação de câmara em radianos (x = yaw, y = pitch). Usado pelo toque.
@warning_ignore("unused_signal")
signal look_input(delta: Vector2)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile = FORCE_MOBILE \
		or OS.has_feature("android") \
		or OS.has_feature("ios") \
		or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())
	enemy_killed.connect(_on_enemy_killed)
	if is_mobile:
		_setup_mobile_input()
		Engine.max_fps = MOBILE_MAX_FPS
		# nos menus os toques têm de virar cliques de rato
		Input.emulate_mouse_from_touch = true


func _process(delta: float) -> void:
	if game_active and not menu_open and not get_tree().paused:
		play_time += delta


func _on_enemy_killed() -> void:
	enemies_killed += 1
	enemy_count_changed.emit(enemies_killed)


# ---------------------------------------------------------------- MOBILE

## Remove os botões do rato das ações: assim nenhum toque/arrasto pode
## disparar a arma, mirar ou trocar de arma por emulação de rato.
func _setup_mobile_input() -> void:
	for action in ["fire", "aim_mode", "weapon_change_prev", "weapon_change_next"]:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventMouseButton:
				InputMap.action_erase_event(action, ev)


## Margens seguras (notch/cantos arredondados) em coordenadas do viewport.
## x = esquerda, y = topo, z = direita, w = baixo.
func get_safe_insets() -> Vector4:
	if not is_mobile:
		return Vector4.ZERO
	var win := Vector2(get_window().size)
	if win.x <= 0.0 or win.y <= 0.0:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var screen := Vector2(DisplayServer.screen_get_size())
	if safe.size.x <= 0 or screen.x <= 0.0:
		return Vector4.ZERO
	var k := get_viewport().get_visible_rect().size / win
	var left := maxf(float(safe.position.x), 0.0) * k.x
	var top := maxf(float(safe.position.y), 0.0) * k.y
	var right := maxf(screen.x - float(safe.position.x + safe.size.x), 0.0) * k.x
	var bottom := maxf(screen.y - float(safe.position.y + safe.size.y), 0.0) * k.y
	return Vector4(left, top, right, bottom)


# ---------------------------------------------------------------- DECALS

## Regista um buraco de bala e apaga os mais antigos acima do limite.
func register_decal(decal: Node) -> void:
	_decals.append(decal)
	var limit := MAX_DECALS_MOBILE if is_mobile else MAX_DECALS_DESKTOP
	while _decals.size() > limit:
		var old: Node = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	decal.tree_exited.connect(func(): _decals.erase(decal))


# ---------------------------------------------------------------- FLUXO DE JOGO

## Chamado pela cena de jogo quando começa.
func enter_game() -> void:
	game_active = true
	menu_open = false
	in_vehicle = false
	vehicle = null
	aim_on_target = false
	get_tree().paused = false
	_apply_cursor_mode()


## Menus (pausa, fim de jogo) ligam/desligam o modo "interface".
func set_menu_open(open: bool) -> void:
	menu_open = open
	if open:
		for action in InputMap.get_actions():
			if Input.is_action_pressed(action):
				Input.action_release(action)
	_apply_cursor_mode()


func _apply_cursor_mode() -> void:
	var ui_mode := menu_open or not game_active
	if is_mobile:
		# toques viram cliques de rato só quando há interface
		Input.emulate_mouse_from_touch = ui_mode
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if ui_mode else Input.MOUSE_MODE_CAPTURED)


func _reset_run() -> void:
	enemies_killed = 0
	in_vehicle = false
	vehicle = null
	aim_on_target = false
	play_time = 0.0
	distance_driven = 0.0
	_decals.clear()
	Bullets.reset()
	for action in InputMap.get_actions():
		Input.action_release(action)


func restart_game() -> void:
	_reset_run()
	get_tree().paused = false
	menu_open = false
	game_active = true
	_apply_cursor_mode()
	get_tree().reload_current_scene()


func go_to_main_menu() -> void:
	_reset_run()
	get_tree().paused = false
	menu_open = false
	game_active = false
	_apply_cursor_mode()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
