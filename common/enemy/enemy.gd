extends CharacterBody3D

@export_group("node connections")
@export var character_root: Node3D
@export var collision_shape: CollisionShape3D
@export var animation_tree: AnimationTree
@export var damage_body:PhysicalBoneSimulator3D

@export_group("settings")
@export var move_speed: float = 1.0
@export var rotate_speed: float = 2.0
@export var max_health: float = 100.0
var current_health: float = 100.0
@export var show_health_bar:bool = true
@export var can_open_doors: bool = false

@export_group("attack")
@export var attack_damage: float = 10.0
@export var attack_range: float = 2.0
@export var vision_range: float = 10.0
@export var chase_time: float = 5.0
var is_chasing:bool = false

@export_group("senses")
## Campo de visão total (graus). Fora dele só ouvem/sentem de perto.
@export var vision_angle_deg: float = 150.0
## Distância a que "sentem" o jogador mesmo sem o ver.
@export var awareness_radius: float = 4.0
@export var hearing_scale: float = 1.0
@export var wander_radius: float = 12.0
@export var runner_chance: float = 0.18

@export_group("sfx")
@export var spawn_sfx:AudioStreamPlayer3D
@export var idle_sfx:AudioStreamPlayer3D
@export var alert_sfx:AudioStreamPlayer3D
@export var hit_sfx:AudioStreamPlayer3D
@export var attack_sfx:AudioStreamPlayer3D
@export var death_sfx:AudioStreamPlayer3D

@export_group("vfx")
@export var spawn_vfx:Node3D
@export var attack_vfx:Node3D
@export var hit_vfx:Node3D
@export var death_vfx:Node3D





enum AI { IDLE, WANDER, ALERT, CHASE, SEARCH, ATTACK }

var state_machine:AnimationNodeStateMachinePlayback
var current_state
var previous_state

const GRAVITY = -20.0
var is_alive: bool = true
var player = null

var ai: int = AI.IDLE
var _home: Vector3
var _last_known: Vector3
var _wander_target: Vector3
var _think_t: float = 0.0
var _timer: float = 0.0          # temporário do estado atual
var _lost_t: float = 0.0
var _repath_t: float = 0.0
var _speed_mult: float = 1.0
var _is_runner: bool = false
var _stagger: float = 0.0
var _safe_vel: Vector3 = Vector3.ZERO
var _stuck_t: float = 0.0
var _check_pos: Vector3
var _check_t: float = 0.0
var _side_t: float = 0.0
var _side_dir: float = 1.0
var _cascaded: bool = false
var _sees: bool = false

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var debug_label: Label3D = $DebugLabel
@onready var chase_timer: Timer = $ChaseTimer
@onready var health_bar: MeshInstance3D = $HealthBar



func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	health_bar.visible = show_health_bar
	if health_bar.get_surface_override_material_count() > 0:
		health_bar.set_surface_override_material(0, health_bar.get_active_material(0).duplicate())
	update_health_bar()
	if can_open_doors:
		add_to_group("door_access")
	debug_label.visible = Global.debug_mode
	state_machine = animation_tree.get("parameters/playback")
	var bone_array: Array = damage_body.get_children()
	for col_bone in bone_array:
		col_bone.update_damage.connect(get_damage)
		col_bone.collision_layer = 2
		col_bone.collision_mask = 2
	# variação individual: velocidade e "corredores"
	_speed_mult = randf_range(0.85, 1.3)
	_is_runner = randf() < runner_chance
	if _is_runner:
		_speed_mult *= 1.6
	_home = global_position
	_think_t = randf() * 0.2
	_timer = randf_range(1.0, 4.0)
	_check_pos = global_position
	# evitar que se amontoem
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.5
	nav_agent.max_speed = maxf(move_speed * 2.5, 6.0)
	nav_agent.path_desired_distance = 0.7
	nav_agent.target_desired_distance = 1.0
	nav_agent.velocity_computed.connect(func(v: Vector3): _safe_vel = v)
	Global.noise_made.connect(_on_noise)
	play_sfx(spawn_sfx)
	play_vfx(spawn_vfx)


# ---------------------------------------------------------------- PERCEÇÃO

func _target_radius() -> float:
	return 1.8 if Global.in_vehicle else 0.0


func _can_see(pp: Vector3, dist: float) -> bool:
	if dist > vision_range:
		return false
	if dist < 1.5:
		return true
	var to := pp - global_position
	to.y = 0.0
	var fwd := -character_root.global_transform.basis.z
	fwd.y = 0.0
	if dist > awareness_radius and rad_to_deg(fwd.angle_to(to)) > vision_angle_deg * 0.5:
		return false
	var excl: Array[RID] = [get_rid()]
	if player is CollisionObject3D:
		excl.append(player.get_rid())
	if Global.vehicle is CollisionObject3D:
		excl.append(Global.vehicle.get_rid())
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5, pp + Vector3.UP * 1.0, 1, excl)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _on_noise(pos: Vector3, radius: float) -> void:
	if not is_alive or ai == AI.ATTACK or ai == AI.CHASE:
		return
	if global_position.distance_to(pos) <= radius * hearing_scale:
		_notice(pos, true)


func _notice(pos: Vector3, cascade: bool) -> void:
	_last_known = pos
	if ai != AI.ALERT:
		ai = AI.ALERT
		_timer = randf_range(0.35, 0.9)
		play_sfx(alert_sfx)
	if cascade and not _cascaded:
		_cascaded = true
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and e.is_alive and e.global_position.distance_to(global_position) < 12.0:
				e._notice(pos, false)


# ---------------------------------------------------------------- DECISÃO

func _think(dt: float, pp: Vector3, dist: float) -> void:
	_sees = _can_see(pp, dist)
	if _sees:
		_last_known = pp
		_lost_t = 0.0
		if ai in [AI.IDLE, AI.WANDER, AI.SEARCH]:
			_notice(pp, true)
	elif ai in [AI.CHASE, AI.ATTACK]:
		_lost_t += dt
		if _lost_t > chase_time * 0.4:
			ai = AI.SEARCH
			_timer = 3.0
	# ataque com histerese
	var reach := attack_range + _target_radius()
	if ai == AI.ATTACK:
		if dist > reach * 1.35:
			ai = AI.CHASE
	elif ai == AI.CHASE and dist < reach:
		ai = AI.ATTACK
	match ai:
		AI.ALERT:
			_timer -= dt
			if _timer <= 0.0:
				ai = AI.CHASE if _sees else AI.SEARCH
				_timer = 3.0
		AI.SEARCH:
			if global_position.distance_to(_last_known) < 1.5:
				_timer -= dt
				if _timer <= 0.0:
					ai = AI.WANDER
					_pick_wander()
		AI.IDLE:
			_timer -= dt
			if _timer <= 0.0:
				ai = AI.WANDER
				_pick_wander()
		AI.WANDER:
			if global_position.distance_to(_wander_target) < 1.5:
				ai = AI.IDLE
				_timer = randf_range(2.0, 5.0)


func _pick_wander() -> void:
	var a := randf() * TAU
	_wander_target = _home + Vector3(cos(a), 0.0, sin(a)) * randf_range(3.0, wander_radius)
	_repath_t = 0.0


# ---------------------------------------------------------------- LOOP

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if player == null or not is_instance_valid(player):
		player = Global.player
	if not is_alive:
		return
	if player == null or not player.is_alive:
		velocity = Vector3(0.0, velocity.y, 0.0)
		_set_anim("idle")
		move_and_slide()
		return
	var pp: Vector3 = player.global_position
	var dist := global_position.distance_to(pp) - _target_radius()
	_stagger = maxf(_stagger - delta, 0.0)
	# decisões menos frequentes quando está longe (poupa CPU)
	_think_t -= delta
	if _think_t <= 0.0:
		var dt := 0.1 if dist < 20.0 else (0.25 if dist < 45.0 else 0.5)
		_think_t = dt
		_think(dt, pp, dist)
	# animação conforme o estado
	var want := "idle"
	match ai:
		AI.ATTACK: want = "attack"
		AI.WANDER, AI.CHASE, AI.SEARCH: want = "move"
	_set_anim(want)
	if state_machine == null:
		move_and_slide()
		return
	match state_machine.get_current_node():
		"walk":
			var target := _last_known
			var spd := move_speed * _speed_mult
			match ai:
				AI.WANDER:
					target = _wander_target
					spd *= 0.4
				AI.SEARCH:
					spd *= 0.75
				AI.CHASE:
					target = pp
			_move_to(target, spd, delta)
		"attack":
			velocity = Vector3(0.0, velocity.y, 0.0)
			_face(pp, delta, 8.0)
		_:
			velocity = Vector3(0.0, velocity.y, 0.0)
			if ai == AI.ALERT:
				_face(_last_known, delta, 8.0)
	move_and_slide()
	debug_label.text = AI.keys()[ai]


func _move_to(target: Vector3, spd: float, delta: float) -> void:
	_repath_t -= delta
	if _repath_t <= 0.0:
		_repath_t = 0.25
		nav_agent.set_target_position(target)
	var next := nav_agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		dir = target - global_position
		dir.y = 0.0
	dir = dir.normalized()
	# desvio lateral quando fica preso
	_side_t = maxf(_side_t - delta, 0.0)
	if _side_t > 0.0:
		dir = dir.rotated(Vector3.UP, _side_dir * 1.0).normalized()
	var factor := 0.25 if _stagger > 0.0 else 1.0
	var desired := dir * spd * factor
	var vy := velocity.y
	nav_agent.velocity = desired
	var v := _safe_vel if _safe_vel.length() > 0.01 else desired
	velocity = Vector3(v.x, vy, v.z)
	_face(global_position + dir, delta, 6.0)
	# deteção de bloqueio
	_check_t += delta
	if _check_t >= 0.6:
		var moved := global_position.distance_to(_check_pos)
		_check_pos = global_position
		_check_t = 0.0
		if moved < spd * 0.6 * 0.25:
			_stuck_t += 0.6
			if _stuck_t >= 1.2:
				_stuck_t = 0.0
				_side_t = 0.8
				_side_dir = 1.0 if randf() < 0.5 else -1.0
				_repath_t = 0.0
		else:
			_stuck_t = 0.0


func _face(target: Vector3, delta: float, rate: float) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	character_root.rotation.y = lerp_angle(character_root.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * delta))


func _set_anim(new_state: String) -> void:
	current_state = new_state
	if current_state != previous_state:
		_change_state(current_state)
		previous_state = current_state

func _change_state(new_state: String) -> void:
	# Reset all conditions
	animation_tree.set("parameters/conditions/idle", false)
	animation_tree.set("parameters/conditions/move", false)
	animation_tree.set("parameters/conditions/attack", false)
	animation_tree.set("parameters/conditions/dead", false)
	
	# Set the new state condition and update debug label
	match new_state:
		"idle":
			animation_tree.set("parameters/conditions/idle", true)
			play_sfx(idle_sfx)
			debug_label.text = "IDLE"
		"move":
			animation_tree.set("parameters/conditions/move", true)
			play_sfx(alert_sfx)
			debug_label.text = "MOVE"
		"attack":
			play_sfx(attack_sfx)
			play_vfx(attack_vfx)
			animation_tree.set("parameters/conditions/attack", true)
			debug_label.text = "ATTACK"
		"dead":
			animation_tree.set("parameters/conditions/dead", true)
			debug_label.text = "DEAD"

func _deal_damage():
	if player == null or not is_alive:
		return
	if global_position.distance_to(player.global_position) < attack_range + _target_radius() + 0.4:
		var direction = global_position.direction_to(player.global_position)
		# dentro do carro leva muito menos dano
		player.get_damage(attack_damage * (0.35 if Global.in_vehicle else 1.0), direction, true)


func get_damage(damage:float,_direction:Vector3) -> void:
	# Inimigo morto não leva dano (os ossos continuavam a ser atingidos
	# e contavam várias mortes)
	if not is_alive:
		return
	current_health -= damage
	_stagger = 0.3
	if ai in [AI.IDLE, AI.WANDER, AI.SEARCH] and Global.player:
		_notice(Global.player.global_position, true)
	update_health_bar()
	play_sfx(hit_sfx)
	play_vfx(hit_vfx)
	
	if current_health <= 0:
		is_alive = false
		die()


func update_health_bar() -> void:
	var health_mat := health_bar.get_active_material(0)
	health_mat.uv1_offset.x = -((current_health/ max_health) - 1 ) / 2

func die():
	Global.enemy_killed.emit()
	
	play_vfx(death_vfx)
	play_sfx(death_sfx)
	
	character_root.visible = false
	collision_shape.set_deferred("disabled", true)
	for bone in damage_body.get_children():
		if bone is CollisionObject3D:
			bone.set_deferred("collision_layer", 0)
			bone.set_deferred("collision_mask", 0)
	health_bar.visible = false
	debug_label.visible = false
	
	await get_tree().create_timer(5.0).timeout
	queue_free()

func play_sfx(sfx:AudioStreamPlayer3D):
	if sfx:
		sfx.play()

func play_vfx(vfx:Node3D):
	if vfx:
		if vfx.is_class("GPUParticles3D"):
			vfx.restart()
		elif vfx.has_method("activate"):
			vfx.activate()
