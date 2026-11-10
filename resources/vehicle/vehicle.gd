extends VehicleBody3D
## Veículo dirigível: física/condução reforçadas e 4 câmeras estilo GTA (tecla V).
##
## Câmeras: 0 = 3ª pessoa longe | 1 = 3ª pessoa perto | 2 = capô | 3 = 1ª pessoa.
## As câmeras de perseguição usam suavização e colisão para não atravessar paredes.

var player_in_range: bool = false
var is_driving: bool = false

@export_group("Visuals")
@export var door_mesh: Node3D
@export var door_outline_mesh: Node3D
@export var vehicle_outline_mesh: Node3D
@export var animation_player: AnimationPlayer
@export var get_in_animation: StringName = &"get_in"

@export_group("Engine")
@export var engine_force_value: float = 500.0
@export var max_rpm: float = 1000.0
@export var brake_strength: float = 100.0
## Velocidade máxima aproximada em m/s (o motor perde força perto dela).
@export var max_forward_speed: float = 32.0
@export var max_reverse_speed: float = 9.0
@export var reverse_force_ratio: float = 0.55
## Resistência aplicada como freio leve quando soltamos o acelerador.
@export var rolling_resistance: float = 4.0
## Força aerodinâmica que empurra o carro para o chão em alta velocidade.
@export var downforce: float = 3000.0
## Corrige a inclinação lateral (roll) nas curvas.
@export var anti_roll_force: float = 9000.0
## Reduz o deslizamento lateral, deixando o carro mais "plantado".
@export var lateral_grip: float = 1.6

@export_group("Steering")
@export var steering_limit: float = 0.36
@export var steering_speed: float = 3.6
## Fração do curso de direção disponível na velocidade máxima.
@export var high_speed_steering: float = 0.28
@export var steering_return_speed: float = 4.0

@export_group("Camera")
## Mesma sensibilidade da câmera a pé (player.gd usa 0.01).
@export var camera_sensitivity: float = 0.01
@export var camera_pitch_min: float = -40.0
@export var camera_pitch_max: float = 60.0
## Tempo sem mexer no mouse até a câmera voltar sozinha para trás do carro.
@export var camera_recenter_delay: float = 1.4
@export var camera_recenter_speed: float = 1.1
@export var camera_auto_fov: bool = true
@export var camera_fov_boost: float = 9.0

@export_group("Audio")
@export var engine_audio: AudioStreamPlayer3D
@export var engine_min_pitch: float = 0.6
@export var engine_max_pitch: float = 2.2
## Velocidade em m/s na qual o pitch do motor chega ao máximo.
@export var engine_max_speed: float = 28.0
@export var engine_volume_db_min: float = -6.0
@export var engine_volume_db_max: float = 0.0

@export var damage: float = 50.0

const ViewToast := preload("res://common/camera/view_toast.gd")

const CAMERA_VIEWS := [
	{
		"title": "3ª PESSOA - LONGE",
		"offset": Vector3(0.0, 2.6, 7.2),
		"pitch_factor": 0.55,
		"fov": 68.0,
		"smooth": 10.0,
		"fixed": false,
	},
	{
		"title": "3ª PESSOA - PERTO",
		"offset": Vector3(0.9, 2.0, 4.2),
		"pitch_factor": 0.7,
		"fov": 72.0,
		"smooth": 14.0,
		"fixed": false,
	},
	{
		"title": "CAPÔ",
		"offset": Vector3(0.0, 1.5, -0.85),
		"pitch_factor": 1.0,
		"fov": 78.0,
		"smooth": 0.0,
		"fixed": true,
	},
	{
		"title": "1ª PESSOA",
		"offset": Vector3(0.0, 1.62, 0.15),
		"pitch_factor": 1.0,
		"fov": 80.0,
		"smooth": 0.0,
		"fixed": true,
	},
]

## Tempo (ms) que uma entrada de "look_input" continua sendo considerada ativa.
const LOOK_SIGNAL_MEMORY_MS := 800
const SEAT_OFFSET := Vector3(0.0, 1.0, 0.35)

@onready var camera: Camera3D = $Camera3D
@onready var player_exit: Marker3D = $PlayerExit

var _steering_input: float = 0.0
var _cam_yaw_offset: float = 0.0
var _cam_pitch_offset: float = 0.0
var _look_idle: float = 0.0
var _last_look_signal_msec: int = -1000000
var _view_yaw: float = 0.0
var _view_pitch: float = 0.0
var _camera_view: int = 0
var _toast: CanvasLayer = null
var _exit_cooldown: float = 0.0
var _uses_look_signal: bool = false
var _forward_speed: float = 0.0
var _player_ref: Node3D = null
var _saved_layer: int = 1
var _saved_mask: int = 1


func _ready() -> void:
	# Centro de massa baixo: o carro inclina menos e não capota em curva.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.3, 0.0)
	if camera != null:
		camera.current = false
	_uses_look_signal = Global.has_signal("look_input")
	if _uses_look_signal:
		Global.look_input.connect(_on_look_input)
	Global.activate_pressed.connect(_on_activate_pressed)
	brake = brake_strength


func _physics_process(delta: float) -> void:
	_exit_cooldown = maxf(_exit_cooldown - delta, 0.0)
	_forward_speed = linear_velocity.dot(-global_transform.basis.z)

	if not is_driving:
		# Freio de estacionamento: o carro não sai rolando sozinho.
		engine_force = 0.0
		brake = brake_strength * 0.6
		steering = move_toward(steering, 0.0, delta * 2.0)
		return

	_apply_driving(delta)
	_follow_seat()


func _process(delta: float) -> void:
	if not is_driving:
		return
	_update_camera(delta)
	_update_engine_audio()


func _input(event: InputEvent) -> void:
	if not is_driving:
		return
	if event.is_action_pressed("camera_view"):
		_cycle_camera()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------- olhar livre ---

func _on_look_input(delta: Vector2) -> void:
	if not is_driving:
		return
	_last_look_signal_msec = Time.get_ticks_msec()
	# Aceita tanto deltas já em radianos quanto deltas em pixels.
	var dx := delta.x
	var dy := delta.y
	if absf(dx) > 1.0:
		dx *= camera_sensitivity
	if absf(dy) > 1.0:
		dy *= camera_sensitivity
	_apply_look(-dx, -dy)


func _unhandled_input(event: InputEvent) -> void:
	if not is_driving:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Se o projeto já envia olhar por Global.look_input, não aplica duas vezes.
		if _look_signal_active():
			return
		_apply_look(
			-event.relative.x * camera_sensitivity,
			-event.relative.y * camera_sensitivity
		)


func _look_signal_active() -> bool:
	return Time.get_ticks_msec() - _last_look_signal_msec < LOOK_SIGNAL_MEMORY_MS


func _apply_look(yaw_delta: float, pitch_delta: float) -> void:
	_cam_yaw_offset = wrapf(_cam_yaw_offset + yaw_delta, -PI, PI)
	_cam_pitch_offset = clampf(
		_cam_pitch_offset + pitch_delta,
		deg_to_rad(camera_pitch_min),
		deg_to_rad(camera_pitch_max)
	)
	_look_idle = 0.0


# ---------------------------------------------------------------- condução ----

func _apply_driving(delta: float) -> void:
	var throttle := Input.get_action_strength("forward") - Input.get_action_strength("backward")
	var braking := Input.is_action_pressed("brake")
	var speed_ratio := clampf(absf(_forward_speed) / maxf(max_forward_speed, 0.01), 0.0, 1.0)

	# --- Motor: curva de potência, limite de velocidade e ré ---
	var force := 0.0
	if throttle > 0.01 and _forward_speed < max_forward_speed:
		var power := clampf(1.0 - speed_ratio * 0.7, 0.25, 1.0)
		force = engine_force_value * throttle * power
	elif throttle < -0.01:
		if _forward_speed > 1.0:
			# Apertar "ré" andando para frente funciona como freio motor.
			braking = true
		else:
			var reverse_power := clampf(1.0 - absf(_forward_speed) / maxf(max_reverse_speed, 0.01), 0.15, 1.0)
			force = engine_force_value * throttle * reverse_force_ratio * reverse_power

	if braking:
		brake = brake_strength
	elif absf(throttle) < 0.05 and absf(_forward_speed) > 0.4:
		brake = rolling_resistance
	else:
		brake = 0.0
	engine_force = lerpf(engine_force, force, clampf(delta * 9.0, 0.0, 1.0))

	# --- Direção: mais fechada em baixa, mais estável em alta ---
	var steer_input := Input.get_axis("right", "left")
	var limit := lerpf(steering_limit, steering_limit * high_speed_steering, speed_ratio)
	var target_steer := limit * steer_input
	if absf(steer_input) < 0.02:
		_steering_input = lerpf(_steering_input, 0.0, clampf(steering_return_speed * delta, 0.0, 1.0))
	else:
		_steering_input = lerpf(_steering_input, target_steer, clampf(steering_speed * delta * 2.0, 0.0, 1.0))
	steering = _steering_input

	# --- Estabilidade: downforce, anti-roll e aderência lateral ---
	if downforce > 0.0:
		apply_central_force(-global_transform.basis.y * downforce * speed_ratio * speed_ratio)
	if anti_roll_force > 0.0:
		var roll := asin(clampf(global_transform.basis.x.dot(Vector3.UP), -1.0, 1.0))
		# O torque precisa se OPOR à inclinação. Com o sinal positivo ele somava
		# com o roll e virava o carro de ponta-cabeça nas curvas fortes.
		apply_torque(global_transform.basis.z * -roll * anti_roll_force)
	if lateral_grip > 0.0:
		var lateral_speed := global_transform.basis.x.dot(linear_velocity)
		apply_central_force(-global_transform.basis.x * lateral_speed * lateral_grip * mass * 0.05)


## Mantém o corpo do jogador junto ao carro enquanto dirige.
## Isso evita que o inimigo persiga/cause dano na posição antiga (fora do carro)
## e que o personagem invisível fique como obstáculo no mundo.
func _follow_seat() -> void:
	if not is_instance_valid(_player_ref):
		return
	_player_ref.global_position = global_transform * SEAT_OFFSET


# ------------------------------------------------------------------ câmera ----

func _cycle_camera() -> void:
	_camera_view = (_camera_view + 1) % CAMERA_VIEWS.size()
	_look_idle = camera_recenter_delay
	if _toast == null:
		_toast = ViewToast.new()
		add_child(_toast)
	_toast.toast("CÂMERA  %s  (%d/%d)" % [
		String(CAMERA_VIEWS[_camera_view]["title"]),
		_camera_view + 1,
		CAMERA_VIEWS.size(),
	])


func _update_camera(delta: float) -> void:
	if camera == null:
		return

	_look_idle += delta
	var view: Dictionary = CAMERA_VIEWS[_camera_view]
	var offset: Vector3 = view["offset"]

	if bool(view["fixed"]):
		# Presa ao carro (capô / primeira pessoa).
		_view_yaw = global_rotation.y + _cam_yaw_offset
		_view_pitch = _cam_pitch_offset
		var local_rotation := Basis.from_euler(Vector3(_view_pitch, _cam_yaw_offset, 0.0))
		camera.global_transform = Transform3D(global_transform.basis * local_rotation, global_transform * offset)
	else:
		# Perseguição: uma única fonte de verdade (yaw/pitch suavizados) para
		# rotação e posição, sem "nadar" enquanto o carro anda.
		var smooth: float = view["smooth"]
		var blend := 1.0 - exp(-smooth * delta)
		_view_yaw = lerp_angle(_view_yaw, global_rotation.y + _cam_yaw_offset, blend)
		_view_pitch = lerpf(_view_pitch, _cam_pitch_offset * float(view["pitch_factor"]), blend)

		var basis := Basis.from_euler(Vector3(_view_pitch * 0.55, _view_yaw, 0.0))
		var anchor := global_transform * Vector3(0.0, 1.15, 0.0)
		var desired := anchor + basis * Vector3(offset.x, offset.y * 0.3, offset.z)
		desired = _resolve_camera_collision(anchor, desired)
		camera.global_transform = Transform3D(basis, desired)

		# Olhar livre volta para trás do carro só depois de um tempo parado.
		if _look_idle > camera_recenter_delay:
			_cam_yaw_offset = lerp_angle(
				_cam_yaw_offset,
				0.0,
				1.0 - exp(-camera_recenter_speed * delta)
			)

	var target_fov: float = view["fov"]
	if camera_auto_fov:
		var speed_ratio := clampf(absf(_forward_speed) / maxf(max_forward_speed, 1.0), 0.0, 1.0)
		target_fov += camera_fov_boost * speed_ratio
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-6.0 * delta))

	if not camera.current:
		camera.make_current()


func _resolve_camera_collision(from: Vector3, to: Vector3) -> Vector3:
	var world := get_world_3d()
	if world == null:
		return to
	var state := world.direct_space_state
	if state == null:
		return to
	var exclude: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	query.collide_with_areas = false
	var hit := state.intersect_ray(query)
	if hit.is_empty():
		return to
	var direction := (to - from).normalized()
	var distance := from.distance_to(hit["position"]) - 0.3
	return from + direction * maxf(distance, 0.5)


# --------------------------------------------------------------- entrar/sair ---

func _get_player() -> CharacterBody3D:
	var candidate: Node = Global.player
	if is_instance_valid(candidate) and candidate is CharacterBody3D:
		return candidate as CharacterBody3D
	return null


func _on_activate_pressed() -> void:
	if is_driving:
		if _exit_cooldown <= 0.0:
			_exit_vehicle()
	elif player_in_range:
		_enter_vehicle()


func _enter_vehicle() -> void:
	var player := _get_player()
	if player == null:
		return

	is_driving = true
	Global.in_vehicle = true
	_player_ref = player

	# Entra já em 3ª pessoa, alinhado com o carro.
	_camera_view = 0
	_cam_yaw_offset = 0.0
	_cam_pitch_offset = 0.0
	_look_idle = camera_recenter_delay
	_view_yaw = global_rotation.y
	_view_pitch = 0.0
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# O jogador vira o "assento": sem colisão (não empurra o carro) e invisível.
	_saved_layer = player.collision_layer
	_saved_mask = player.collision_mask
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.visible = false
	player.global_position = global_transform * SEAT_OFFSET

	camera.make_current()

	engine_force = 0.0
	brake = 0.0
	_steering_input = 0.0
	steering = 0.0

	if engine_audio:
		engine_audio.pitch_scale = engine_min_pitch
		engine_audio.play()

	if door_mesh:
		door_mesh.visible = true

	_play_get_in_animation()

	_update_outline()


func _exit_vehicle() -> void:
	var player := _get_player()
	if player == null:
		is_driving = false
		Global.in_vehicle = false
		_player_ref = null
		return

	is_driving = false
	Global.in_vehicle = false
	_exit_cooldown = 0.45

	player.global_position = player_exit.global_position
	player.velocity = Vector3.ZERO
	player.collision_layer = _saved_layer
	player.collision_mask = _saved_mask
	player.visible = true
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	_player_ref = null

	if player.camera:
		player.camera.make_current()

	engine_force = 0.0
	brake = brake_strength
	_steering_input = 0.0
	steering = 0.0
	_camera_view = 0

	if engine_audio:
		engine_audio.stop()

	_update_outline()


# ------------------------------------------------------------------ extras ----

func _play_get_in_animation() -> void:
	if animation_player == null or get_in_animation == &"":
		return
	if animation_player.has_animation(get_in_animation):
		animation_player.play(get_in_animation)
		return
	# Algumas cenas salvam a animação sem o nome do library, então procuramos
	# pelo sufixo antes de desistir.
	for anim in animation_player.get_animation_list():
		if String(anim).ends_with(String(get_in_animation)):
			animation_player.play(anim)
			return


func _update_engine_audio() -> void:
	if not engine_audio:
		return
	var speed := absf(_forward_speed)
	var t := clampf(speed / maxf(engine_max_speed, 0.01), 0.0, 1.0)
	engine_audio.pitch_scale = lerpf(engine_audio.pitch_scale, lerpf(engine_min_pitch, engine_max_pitch, t), 0.15)
	engine_audio.volume_db = lerpf(engine_volume_db_min, engine_volume_db_max, t)


func _update_outline() -> void:
	var show := player_in_range and not is_driving
	if vehicle_outline_mesh:
		vehicle_outline_mesh.visible = show
	if door_outline_mesh:
		door_outline_mesh.visible = show


func _on_door_area_3d_body_entered(body: Node3D) -> void:
	if body and body.is_in_group("player"):
		player_in_range = true
		_update_outline()


func _on_door_area_3d_body_exited(body: Node3D) -> void:
	if body and body.is_in_group("player"):
		player_in_range = false
		_update_outline()


func _on_bumper_body_entered(body: Node3D) -> void:
	if not Global.in_vehicle:
		return
	if body == null or not is_instance_valid(body):
		return
	# O próprio motorista e qualquer parte do jogador não levam dano do carro.
	if body == _player_ref or body.is_in_group("player"):
		return
	# Só machuca em batidas de verdade (evita dano parado/encostando).
	if linear_velocity.length() < 3.0:
		return
	if body.has_method("get_damage"):
		var direction = global_position.direction_to(body.global_position)
		body.get_damage(damage, direction)
