extends CharacterBody3D


@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 6.0
var speed: float = 0.0
const GRAVITY: float = -20

@export var sensitivity:float = 0.01
var inertia_air:float = 7.5
var inertia_ground: float = 10.0

#BOB
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

var is_aiming: bool = false
var aim_assist: Node = null

# Salto: "buffer" (lembra o toque durante uns instantes) e "coyote time"
# (deixa saltar logo depois de sair de uma borda). Resolve saltos que
# "não saem" quando o toque é curto ou o FPS é baixo.
const JUMP_BUFFER_TIME: float = 0.15
const COYOTE_TIME: float = 0.12
var jump_buffer: float = 0.0
var coyote_timer: float = 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_holder: Node3D = $CameraPivot/CameraHolder
@onready var camera: Camera3D = %MainCamera
@onready var audio_manager: Node3D = $AudioManager
@onready var weapons_manager: Node3D = $WeaponsManager

@export var weapon:Node3D
var views: Node = null
var walk_anim:float = 0.0
var sprint_anim:float = 0.0



# Animation blend speeds
const ANIM_BLEND_SPEED: float = 20.0

# Audio tracking
var was_on_floor: bool = false
var footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL_WALK: float = 0.5
const FOOTSTEP_INTERVAL_SPRINT: float = 0.3

const MAX_HEALTH:float = 100.0
var current_health:float = 100.0
var is_alive: bool = true
const HIT_STAGGER: float = 40.0



func _ready() -> void:
	Global.player = self
	# anti-bloqueio: sobe pequenos degraus e desliza em vez de prender nas arestas
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = false
	floor_constant_speed = true
	safe_margin = 0.02
	wall_min_slide_angle = deg_to_rad(5.0)
	views = preload("res://common/camera/player_views.gd").new()
	views.name = "Views"
	add_child(views)
	Global.aim_mode_changed.connect(_on_aim_mode_changed)
	Global.look_input.connect(_on_look_input)
	Global.player_dead.connect(_on_player_dead)
	if Global.is_mobile:
		aim_assist = preload("res://common/mobile/aim_assist.gd").new()
		aim_assist.player = self
		add_child(aim_assist)
		# braços/armas renderizam a resolução menor: poupa bastante GPU
		var sub_vp := get_node_or_null("WeaponSubViewport/SubViewport") as SubViewport
		if sub_vp:
			sub_vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			sub_vp.scaling_3d_scale = Global.MOBILE_WEAPON_RENDER_SCALE
			sub_vp.msaa_3d = Viewport.MSAA_DISABLED


func _on_player_dead() -> void:
	is_alive = false
	jump_buffer = 0.0
	if is_aiming:
		Global.aim_mode_changed.emit(false)


func _input(event: InputEvent) -> void:
	# Guarda o pedido de salto no momento exato do toque/tecla
	if event.is_action_pressed("jump") and not Global.in_vehicle:
		jump_buffer = JUMP_BUFFER_TIME


func _on_look_input(delta: Vector2) -> void:
	if Global.in_vehicle or not is_alive:
		return
	if aim_assist:
		aim_assist.notify_look(delta)
		delta *= aim_assist.look_multiplier
	camera_pivot.rotate_y(-delta.x)
	camera_holder.rotate_x(-delta.y)
	camera_holder.rotation.x = clamp(camera_holder.rotation.x, deg_to_rad(-60), deg_to_rad(60))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * sensitivity * GameSettings.look_sens)
		camera_holder.rotate_x(-event.relative.y * sensitivity * GameSettings.look_sens)
		camera_holder.rotation.x = clamp(camera_holder.rotation.x, deg_to_rad(-60),deg_to_rad(60))




func _physics_process(delta: float) -> void:
	# Add the gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Detect landing from air
	if is_on_floor() and not was_on_floor:
		# Player just landed
		if audio_manager:
			audio_manager.play_footstep(true)  # Play jump/land sound
	
	# Update floor state tracker
	was_on_floor = is_on_floor()

	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER_TIME

	# Coyote time + jump buffer
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer = maxf(jump_buffer - delta, 0.0)
	
	# Handle jump
	if is_alive and jump_buffer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer = 0.0
		coyote_timer = 0.0

	# Handle sprint
	if Input.is_action_pressed("sprint"):
		handle_sprint()

	else:
		handle_walk()

	var input_dir := Input.get_vector("left", "right", "forward", "backward") if is_alive else Vector2.ZERO
	# analógico: não normalizar, para o joystick controlar a velocidade
	var direction := (camera_pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).limit_length(1.0)
	
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * inertia_ground)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * inertia_ground)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * inertia_air)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * inertia_air)

	# head bob
	t_bob += velocity.length() * float(is_on_floor()) * delta
	camera_holder.transform.origin = _headbob(t_bob) if views.is_first_person() else Vector3.ZERO
	
	# Handle footstep sounds
	_handle_footsteps(delta)
	
	# Emit velocity for crosshair
	Global.player_velocity_changed.emit(velocity)

	move_and_slide()


func _handle_footsteps(delta: float) -> void:
	# Only play footsteps when on ground and moving
	if is_on_floor() and velocity.length() > 0.1:
		footstep_timer -= delta
		
		if footstep_timer <= 0.0:
			# Determine interval based on sprint/walk
			var interval = FOOTSTEP_INTERVAL_SPRINT if Input.is_action_pressed("sprint") else FOOTSTEP_INTERVAL_WALK
			footstep_timer = interval
			
			# Play footstep (not a jump landing)
			if audio_manager:
				audio_manager.play_footstep(false)
	else:
		# Reset timer when not moving
		footstep_timer = 0.0






func handle_walk() -> void:
	speed = walk_speed
	Global.player_sprinting_changed.emit(false)

func handle_sprint() -> void:
	# Prohibit sprinting when in aim mode
	if is_aiming:
		handle_walk()
		return
	
	speed = sprint_speed
	Global.player_sprinting_changed.emit(true)

func _on_aim_mode_changed(aim_mode: bool) -> void:
	is_aiming = aim_mode
	# If we were sprinting and now aiming, revert to walk speed
	if aim_mode and Input.is_action_pressed("sprint"):
		handle_walk()



func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin (time * BOB_FREQ) * BOB_AMP
	pos.x = cos (time * BOB_FREQ/2) * BOB_AMP
	return pos




func get_damage(damage:float,direction:Vector3, is_enemy_damage:bool = false) -> void:
	current_health -= damage
	if not is_alive:
		return
	if current_health <= 0.0:
		current_health = 0.0
		is_alive = false
		Global.player_dead.emit()
	else:
		velocity +=  direction * HIT_STAGGER
	Global.player_health_changed.emit(-damage,current_health,MAX_HEALTH, is_enemy_damage)
