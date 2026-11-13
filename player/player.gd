extends CharacterBody3D
## Movimento do jogador: andar, correr, agachar, pular e aterrissar.
##
## Mantém a API do template (Global.player, get_damage, câmera em CameraPivot /
## CameraHolder / %MainCamera e WeaponsManager) e adiciona aceleração,
## desaceleração, coyote time, buffer de pulo, agachamento com checagem de teto
## e um impulso de aterrissagem usado pela câmera e pela animação do corpo.

signal landed(impact: float)

@export_group("Movement")
@export var walk_speed: float = 5.4
@export var sprint_speed: float = 9.2
@export var crouch_speed: float = 2.6
@export var jump_velocity: float = 6.2
@export var gravity: float = -21.0
@export var ground_acceleration: float = 58.0
@export var ground_friction: float = 46.0
@export var air_acceleration: float = 17.0
@export var air_friction: float = 3.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.14

@export_group("Camera")
@export var sensitivity: float = 0.0022
@export var pitch_min: float = -85.0
@export var pitch_max: float = 82.0
@export var standing_eye_height: float = 1.7
@export var crouch_eye_height: float = 1.12

@export_group("Bob")
@export var bob_freq: float = 2.2
@export var bob_amp: float = 0.055

var speed: float = 0.0
var is_aiming: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false
var crouch_amount: float = 0.0
var sprint_amount: float = 0.0
var aim_amount: float = 0.0
var land_dip: float = 0.0
var t_bob: float = 0.0

const MAX_HEALTH: float = 100.0
const HIT_STAGGER: float = 26.0
var current_health: float = 100.0
var is_alive: bool = true

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_holder: Node3D = $CameraPivot/CameraHolder
@onready var camera: Camera3D = %MainCamera
@onready var audio_manager: Node3D = $AudioManager
@onready var weapons_manager: Node3D = $WeaponsManager
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _was_on_floor: bool = true
var _was_sprinting: bool = false
var _footstep_left: float = 0.0
var _height_stand: float = 1.85
var _pivot_stand: Vector3


func _ready() -> void:
	Global.player = self
	Global.aim_mode_changed.connect(_on_aim_mode_changed)
	if collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate()
	_height_stand = collision_shape.shape.height if collision_shape.shape is CapsuleShape3D else 1.85
	_pivot_stand = camera_pivot.position
	current_health = MAX_HEALTH


func _unhandled_input(event: InputEvent) -> void:
	if Global.cinematic_mode or not is_alive:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * sensitivity)
		camera_holder.rotate_x(-event.relative.y * sensitivity)
		camera_holder.rotation.x = clampf(
			camera_holder.rotation.x,
			deg_to_rad(pitch_min),
			deg_to_rad(pitch_max)
		)


func _physics_process(delta: float) -> void:
	if not is_alive:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	var jump_pressed := Input.is_action_just_pressed("jump")

	# Agachar / levantar.
	var wants_crouch := Input.is_action_pressed("crouch")
	if wants_crouch and not is_crouching:
		_set_crouched(true)
	elif not wants_crouch and is_crouching and _has_headroom():
		_set_crouched(false)

	crouch_amount = move_toward(crouch_amount, 1.0 if is_crouching else 0.0, delta * 7.0)
	camera_pivot.position.y = lerpf(_pivot_stand.y, crouch_eye_height, crouch_amount)

	# Gravidade + coyote time + buffer de pulo.
	if not is_on_floor():
		velocity.y += gravity * delta
		_coyote_left = maxf(_coyote_left - delta, 0.0)
	else:
		_coyote_left = coyote_time

	_jump_buffer_left = jump_buffer_time if jump_pressed else maxf(_jump_buffer_left - delta, 0.0)

	if Global.cinematic_mode:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)
		sprint_amount = 0.0
		aim_amount = 0.0
		_set_sprinting(false)
	elif _jump_buffer_left > 0.0 and _coyote_left > 0.0 and not is_crouching:
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		_play_jump_sound()

	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	if Global.cinematic_mode:
		input_dir = Vector2.ZERO
	var direction := (camera_pivot.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	direction.y = 0.0
	if direction.length() > 1.0:
		direction = direction.normalized()

	var wants_sprint := Input.is_action_pressed("sprint") and input_dir.y < -0.1
	_set_sprinting(
		is_alive
		and not Global.cinematic_mode
		and wants_sprint
		and not is_aiming
		and not is_crouching
		and is_on_floor()
	)
	sprint_amount = move_toward(sprint_amount, 1.0 if is_sprinting else 0.0, delta * 5.0)
	aim_amount = move_toward(aim_amount, 1.0 if is_aiming else 0.0, delta * 8.0)

	if is_crouching:
		speed = crouch_speed
	elif is_aiming:
		speed = walk_speed * 0.55
	elif is_sprinting:
		speed = sprint_speed
	else:
		speed = walk_speed

	var target := direction * speed
	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var decel := ground_friction if is_on_floor() else air_friction
	if direction.length() > 0.05:
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)

	# Aterrissagem: alimenta o mergulho da câmera e a animação de impacto.
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var impact := clampf(absf(velocity.y) / 18.0, 0.0, 1.0)
		if impact > 0.12:
			land_dip = impact
			landed.emit(impact)
			_play_jump_sound()
	_was_on_floor = on_floor
	land_dip = maxf(land_dip - delta * 3.2, 0.0)

	# Head bob (a câmera de 3ª pessoa não usa o holder, então não conflita).
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	t_bob += planar_speed * float(on_floor) * delta
	var bob_target := Vector3.ZERO
	if on_floor and planar_speed > 0.5:
		var bob_scale := 1.0 if is_sprinting else 0.8
		bob_target.y = sin(t_bob * bob_freq) * bob_amp * bob_scale
		bob_target.x = cos(t_bob * bob_freq * 0.5) * bob_amp * 0.7 * bob_scale
	camera_holder.position = camera_holder.position.lerp(bob_target, delta * 12.0)

	_handle_footsteps(delta, planar_speed, on_floor)

	Global.player_velocity_changed.emit(velocity)
	move_and_slide()


func _handle_footsteps(delta: float, planar_speed: float, on_floor: bool) -> void:
	if not on_floor or planar_speed < 0.6 or Global.cinematic_mode:
		return
	_footstep_left -= delta
	if _footstep_left > 0.0:
		return
	_footstep_left = (0.32 if is_sprinting else 0.46) * clampf(walk_speed / maxf(planar_speed, 0.1), 0.65, 1.15)
	if audio_manager and audio_manager.has_method("play_footstep"):
		audio_manager.play_footstep(false)


func _play_jump_sound() -> void:
	if audio_manager and audio_manager.has_method("play_footstep"):
		audio_manager.play_footstep(true)


func _set_sprinting(value: bool) -> void:
	if is_sprinting == value:
		return
	is_sprinting = value
	if _was_sprinting != value:
		_was_sprinting = value
		Global.player_sprinting_changed.emit(value)


func _set_crouched(value: bool) -> void:
	is_crouching = value
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		var target_height := 1.2 if value else _height_stand
		create_tween().tween_property(capsule, "height", target_height, 0.16)
		create_tween().tween_property(collision_shape, "position:y", target_height * 0.5, 0.16)


func _has_headroom() -> bool:
	# Se agachar não é possível, o jogador continua agachado (teto baixo).
	return not test_move(
		global_transform,
		Vector3(0.0, _height_stand - 1.2, 0.0)
	)


func _on_aim_mode_changed(aim_mode: bool) -> void:
	is_aiming = aim_mode
	if aim_mode:
		_set_sprinting(false)


func get_damage(damage: float, direction: Vector3, is_enemy_damage: bool = false) -> void:
	if not is_alive:
		return
	current_health = maxf(current_health - damage, 0.0)
	Global.player_health_changed.emit(-damage, current_health, MAX_HEALTH, is_enemy_damage)
	Global.camera_shake.emit()
	if current_health <= 0.0:
		is_alive = false
		Global.player_dead.emit()
		return
	velocity += direction * HIT_STAGGER
