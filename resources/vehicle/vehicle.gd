extends VehicleBody3D
## Jipe: condução arcade melhorada + 4 vistas de câmara estilo GTA (tecla V).

## A frente do modelo do jipe (eixo local para onde o motor empurra).
const FWD := Vector3(0, 0, 1)

const VIEWS: Array[Dictionary] = [
	{"name": "TERCEIRA PESSOA · LONGE", "mode": "chase", "dist": 7.6, "elev": 15.0, "focus": 1.5, "fov": 68.0, "rate": 3.2},
	{"name": "TERCEIRA PESSOA · PERTO", "mode": "chase", "dist": 4.9, "elev": 13.0, "focus": 1.35, "fov": 72.0, "rate": 4.5},
	{"name": "CAPÔ", "mode": "mount", "pos": Vector3(0.0, 1.45, 1.1), "fov": 78.0},
	{"name": "PRIMEIRA PESSOA", "mode": "mount", "pos": Vector3(0.3, 1.67, 0.22), "fov": 82.0},
]

var player_in_range: bool = false
var is_driving: bool = false
var view_index: int = 0
var speed_kmh: float = 0.0
var gear: int = 1

@export_group("Visuals")
@export var door_mesh: Node3D
@export var door_outline_mesh: Node3D
@export var vehicle_outline_mesh: Node3D
@export var animation_player: AnimationPlayer
@export var get_in_animation: StringName = &"get_in"

@export_group("Engine")
@export var engine_power: float = 1500.0
@export var top_speed: float = 38.0
@export var reverse_top_speed: float = 11.0
@export var brake_power: float = 38.0
@export var handbrake_power: float = 24.0
@export var engine_brake: float = 2.5
@export var drag: float = 0.30
@export var downforce: float = 3.0

@export_group("Handling")
@export var steer_max: float = 0.52
@export var steer_min: float = 0.10
@export var steer_response: float = 5.5
@export var steer_return: float = 9.0
@export var grip_front: float = 6.0
@export var grip_rear: float = 5.5
@export var drift_grip: float = 1.6

@export_group("Camera")
@export var camera_sensitivity: float = 0.003

@export_group("Audio")
@export var engine_audio: AudioStreamPlayer3D
@export var engine_min_pitch: float = 0.7
@export var engine_max_pitch: float = 2.0

@export var damage: float = 50.0

@onready var camera: Camera3D = $Camera3D
@onready var player_exit: Marker3D = $PlayerExit

var _wheels: Array[VehicleWheel3D] = []
var _steer: float = 0.0
var _fwd_speed: float = 0.0
var _rear_grip: float = 5.5
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _look_idle: float = 0.0
var _cam_yaw: float = 0.0
var _cam_focus: Vector3 = Vector3.ZERO
var _cam_dist: float = 7.0
var _cam_fov: float = 70.0
var _flip_t: float = 0.0
var _noise_t: float = 0.0
var _hit_times: Dictionary = {}
var _driver: Mannequin
var _smoke: Array[CPUParticles3D] = []
var _saved_layer: int = 1
var _saved_mask: int = 1
var _last_pos: Vector3


func fwd_dir() -> Vector3:
	return global_transform.basis * FWD


func _ready() -> void:
	camera.current = false
	camera.top_level = false
	Global.activate_pressed.connect(_on_activate_pressed)
	Global.look_input.connect(_on_look_input)
	Global.camera_view_pressed.connect(_on_view_pressed)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.35, 0)
	linear_damp = 0.05
	angular_damp = 0.8
	for c in get_children():
		if c is VehicleWheel3D:
			var w := c as VehicleWheel3D
			_wheels.append(w)
			w.suspension_stiffness = 48.0
			w.suspension_travel = 0.25
			w.damping_compression = 0.9
			w.damping_relaxation = 1.1
			w.wheel_roll_influence = 0.06
			w.suspension_max_force = 9000.0
			w.wheel_friction_slip = grip_front if w.use_as_steering else grip_rear
	_rear_grip = grip_rear
	_make_driver()
	_make_smoke()
	_last_pos = global_position
	_park()


func _make_driver() -> void:
	_driver = Mannequin.new()
	_driver.seated = true
	_driver.rotation.y = PI
	_driver.position = Vector3(0.3, 0.52, -0.05)
	_driver.visible = false
	add_child(_driver)


func _make_smoke() -> void:
	for w in _wheels:
		if w.use_as_steering:
			continue
		var p := CPUParticles3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.8, 0.8, 0.8, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material = m
		p.mesh = q
		p.amount = 14
		p.lifetime = 0.9
		p.emitting = false
		p.direction = Vector3.UP
		p.spread = 30.0
		p.initial_velocity_min = 0.5
		p.initial_velocity_max = 1.5
		p.gravity = Vector3(0, 0.6, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.6
		p.local_coords = false
		w.add_child(p)
		p.position = Vector3(0, -0.2, 0)
		_smoke.append(p)


func _park() -> void:
	engine_force = 0.0
	steering = 0.0
	for w in _wheels:
		w.brake = 12.0


# ---------------------------------------------------------------- CÂMARA

func _on_look_input(delta: Vector2) -> void:
	if not is_driving:
		return
	_look_yaw -= delta.x
	_look_pitch -= delta.y
	_look_idle = 0.0
	_clamp_look()


func _unhandled_input(event: InputEvent) -> void:
	if is_driving and event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_look_yaw -= event.relative.x * camera_sensitivity * GameSettings.look_sens
		_look_pitch -= event.relative.y * camera_sensitivity * GameSettings.look_sens
		_look_idle = 0.0
		_clamp_look()


func _clamp_look() -> void:
	var mount: bool = VIEWS[view_index]["mode"] == "mount"
	_look_pitch = clampf(_look_pitch, deg_to_rad(-30.0), deg_to_rad(40.0 if not mount else 30.0))
	if mount:
		_look_yaw = clampf(_look_yaw, deg_to_rad(-110.0), deg_to_rad(110.0))


func _on_view_pressed() -> void:
	if not is_driving:
		return
	view_index = (view_index + 1) % VIEWS.size()
	_apply_view(false)
	Global.camera_view_changed.emit("vehicle", view_index, VIEWS[view_index]["name"])


func _apply_view(snap: bool) -> void:
	var v: Dictionary = VIEWS[view_index]
	var mount: bool = v["mode"] == "mount"
	camera.top_level = not mount
	if _driver:
		_driver.visible = view_index != 3
	_look_yaw = 0.0
	_look_pitch = 0.0
	if mount and snap:
		_cam_fov = v["fov"]


func _process(delta: float) -> void:
	if not is_driving:
		return
	_update_camera(delta)
	_update_engine_audio()
	_update_effects()


func _update_camera(delta: float) -> void:
	var v: Dictionary = VIEWS[view_index]
	_look_idle += delta
	if _look_idle > 1.2:
		_look_yaw = lerpf(_look_yaw, 0.0, 1.0 - exp(-2.5 * delta))
		_look_pitch = lerpf(_look_pitch, 0.0, 1.0 - exp(-2.5 * delta))
	var spd_k := clampf(linear_velocity.length() / top_speed, 0.0, 1.0)
	_cam_fov = lerpf(_cam_fov, float(v["fov"]) + 14.0 * pow(spd_k, 1.5), 1.0 - exp(-4.0 * delta))
	camera.fov = _cam_fov
	if v["mode"] == "mount":
		var pos: Vector3 = v["pos"]
		camera.transform = Transform3D(Basis(Vector3.UP, PI + _look_yaw) * Basis(Vector3.RIGHT, _look_pitch), pos)
		return
	# --- chase ---
	var f := fwd_dir()
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var yaw_f := atan2(-f.x, -f.z)
	var want := yaw_f
	var vel := linear_velocity
	vel.y = 0.0
	if vel.length() > 3.0 and _fwd_speed > 0.0:
		want = lerp_angle(yaw_f, atan2(-vel.x, -vel.z), clampf((vel.length() - 3.0) / 10.0, 0.0, 1.0) * 0.65)
	_cam_yaw = lerp_angle(_cam_yaw, want, 1.0 - exp(-float(v["rate"]) * delta))
	var focus_target := global_position + Vector3.UP * float(v["focus"])
	_cam_focus = _cam_focus.lerp(focus_target, 1.0 - exp(-18.0 * delta))
	var yaw := _cam_yaw + _look_yaw
	var elev := deg_to_rad(float(v["elev"])) + _look_pitch
	var dist: float = v["dist"]
	var dir_h := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var offs := -dir_h * cos(elev) + Vector3.UP * sin(elev)
	# colisão da câmara
	var q := PhysicsRayQueryParameters3D.create(_cam_focus, _cam_focus + offs * dist, 1, [get_rid(), Global.player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var want_d := dist
	if not hit.is_empty():
		want_d = clampf(_cam_focus.distance_to(hit["position"]) - 0.35, 1.2, dist)
	_cam_dist = want_d if want_d < _cam_dist else lerpf(_cam_dist, want_d, 1.0 - exp(-3.0 * delta))
	var cam_pos := _cam_focus + offs * _cam_dist
	camera.global_transform = Transform3D(Basis.IDENTITY, cam_pos).looking_at(_cam_focus + f * 2.0 * spd_k, Vector3.UP)


# ---------------------------------------------------------------- FÍSICA

func _physics_process(delta: float) -> void:
	var vel := linear_velocity
	_fwd_speed = vel.dot(fwd_dir().normalized())
	speed_kmh = vel.length() * 3.6
	if not is_driving:
		return
	var throttle := Input.get_action_strength("forward")
	var reverse := Input.get_action_strength("backward")
	var handbrake := Input.is_action_pressed("brake")
	var steer_in := Input.get_axis("right", "left")
	var spd := vel.length()
	# --- motor / travões ---
	var eng := 0.0
	var brk := 0.0
	if throttle > 0.05 and throttle >= reverse:
		if _fwd_speed < -1.5:
			brk = brake_power * throttle
		else:
			eng = throttle * (1.0 - smoothstep(top_speed * 0.55, top_speed, maxf(_fwd_speed, 0.0)))
	elif reverse > 0.05:
		if _fwd_speed > 1.5:
			brk = brake_power * reverse
		else:
			eng = -reverse * (1.0 - smoothstep(reverse_top_speed * 0.5, reverse_top_speed, maxf(-_fwd_speed, 0.0)))
	else:
		brk = engine_brake
	engine_force = eng * engine_power
	for w in _wheels:
		var b := brk
		if handbrake and not w.use_as_steering:
			b += handbrake_power
		elif handbrake:
			b += handbrake_power * 0.25
		w.brake = b
	# --- direção dependente da velocidade ---
	var sf := clampf(absf(_fwd_speed) / (top_speed * 0.8), 0.0, 1.0)
	var limit := lerpf(steer_max, steer_min, pow(sf, 0.7))
	var target := steer_in * limit
	var rate := steer_response if absf(target) > absf(_steer) else steer_return
	_steer = move_toward(_steer, target, rate * limit * delta * 2.0)
	steering = _steer
	# --- aderência / drift com travão de mão ---
	var want_grip := drift_grip if (handbrake and spd > 6.0) else grip_rear
	_rear_grip = lerpf(_rear_grip, want_grip, 1.0 - exp(-10.0 * delta))
	for w in _wheels:
		if not w.use_as_steering:
			w.wheel_friction_slip = _rear_grip
	if handbrake and spd > 8.0:
		apply_torque(Vector3.UP * steer_in * mass * 1.4 * clampf(spd / 20.0, 0.0, 1.0))
	# --- resistência do ar e aderência ao chão ---
	apply_central_force(-vel * spd * drag)
	apply_central_force(-global_transform.basis.y * spd * spd * downforce)
	# --- virar o carro se capotar ---
	if global_transform.basis.y.dot(Vector3.UP) < 0.35 and spd < 4.0:
		_flip_t += delta
		if _flip_t > 2.0:
			_right_vehicle()
	else:
		_flip_t = 0.0
	# --- jogador acompanha o carro (inimigos perseguem o carro) ---
	var p := Global.player
	if p:
		p.global_position = global_position + Vector3.UP * 0.5
		p.velocity = Vector3.ZERO
	Global.distance_driven += global_position.distance_to(_last_pos)
	_last_pos = global_position
	# --- ruído do motor atrai zombies ---
	_noise_t -= delta
	if _noise_t <= 0.0 and spd > 6.0:
		_noise_t = 0.6
		Global.noise_made.emit(global_position, 12.0 + spd * 0.9)
	_update_gear()


func _update_gear() -> void:
	var s := absf(_fwd_speed)
	if _fwd_speed < -0.5:
		gear = -1
	else:
		gear = clampi(1 + int(s / (top_speed / 5.0)), 1, 5)


func _right_vehicle() -> void:
	_flip_t = 0.0
	var f := fwd_dir()
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	# Basis.looking_at aponta -Z para a direção; o jipe tem a frente em +Z
	var basis := Basis.looking_at(-f, Vector3.UP)
	global_transform = Transform3D(basis, global_position + Vector3.UP * 1.2)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _update_effects() -> void:
	var slip := absf(linear_velocity.dot(global_transform.basis.x)) > 4.0 and linear_velocity.length() > 6.0
	var hb := Input.is_action_pressed("brake") and linear_velocity.length() > 6.0
	for s in _smoke:
		s.emitting = slip or hb


# ---------------------------------------------------------------- ENTRAR / SAIR

func _on_activate_pressed() -> void:
	if Global.menu_open:
		return
	if is_driving:
		_exit_vehicle()
	elif player_in_range and not Global.in_vehicle:
		_enter_vehicle()


func _enter_vehicle() -> void:
	var player := Global.player
	if not player:
		return
	is_driving = true
	Global.in_vehicle = true
	Global.vehicle = self
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.visible = false
	_saved_layer = player.collision_layer
	_saved_mask = player.collision_mask
	player.collision_layer = 0
	player.collision_mask = 0
	# a câmara começa no olhar do jogador e voa para trás do carro
	view_index = 0
	var pcam: Camera3D = player.camera
	_cam_yaw = player.camera_pivot.global_rotation.y
	_cam_focus = pcam.global_position
	_cam_dist = 3.0
	_cam_fov = pcam.fov
	camera.top_level = true
	camera.make_current()
	camera.global_transform = pcam.global_transform
	_apply_view(true)
	engine_force = 0.0
	for w in _wheels:
		w.brake = 0.0
	_steer = 0.0
	steering = 0.0
	_last_pos = global_position
	if engine_audio:
		engine_audio.pitch_scale = engine_min_pitch
		engine_audio.play()
	if door_mesh:
		door_mesh.visible = true
	if animation_player and get_in_animation:
		animation_player.play(get_in_animation)
	_update_outline()
	Global.vehicle_entered.emit(self)
	Global.camera_view_changed.emit("vehicle", 0, VIEWS[0]["name"])


func _find_exit() -> Vector3:
	var space := get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.7
	var local_candidates: Array[Vector3] = [
		player_exit.position, Vector3(-player_exit.position.x, player_exit.position.y, player_exit.position.z),
		Vector3(0, 0.3, -3.4), Vector3(0, 0.3, 3.6), Vector3(0, 3.0, 0)]
	for lc in local_candidates:
		var pos := global_transform * lc
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * 0.9)
		params.collision_mask = 1
		params.exclude = [get_rid()]
		if space.intersect_shape(params, 1).is_empty():
			return pos
	return player_exit.global_position


func _exit_vehicle() -> void:
	var player := Global.player
	if not player:
		return
	is_driving = false
	Global.in_vehicle = false
	Global.vehicle = null
	player.global_position = _find_exit()
	player.collision_layer = _saved_layer
	player.collision_mask = _saved_mask
	player.camera_pivot.global_rotation.y = _cam_yaw
	player.visible = true
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	camera.top_level = false
	player.camera.make_current()
	_park()
	_driver.visible = false
	for s in _smoke:
		s.emitting = false
	if engine_audio:
		engine_audio.stop()
	_update_outline()
	Global.vehicle_exited.emit()


func _update_engine_audio() -> void:
	if not engine_audio:
		return
	var s := absf(_fwd_speed)
	var band := top_speed / 5.0
	var in_gear := fmod(s, band) / band
	var rpm := clampf(0.25 + in_gear * 0.75 if s > 1.0 else 0.2 + Input.get_action_strength("forward") * 0.4, 0.0, 1.0)
	engine_audio.pitch_scale = lerpf(engine_min_pitch, engine_max_pitch, rpm)


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
	if not is_driving or body == null or body.is_in_group("player") or not body.has_method("get_damage"):
		return
	var rel := linear_velocity
	if "velocity" in body:
		rel -= body.velocity
	var spd := rel.length()
	if spd < 4.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var id := body.get_instance_id()
	if _hit_times.has(id) and now - float(_hit_times[id]) < 0.5:
		return
	_hit_times[id] = now
	body.get_damage(damage + spd * 6.0, rel.normalized())
	apply_central_impulse(-linear_velocity * mass * 0.03)
	Global.camera_shake.emit()
