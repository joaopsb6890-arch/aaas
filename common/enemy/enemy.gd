extends CharacterBody3D
## IA do inimigo (patrulha / perseguição / ataque).
##
## Mantém a mesma API e os mesmos nós do template (enemy_base.tscn / undead.tscn),
## e adiciona: campo de visão, linha de visão real, audição de tiros, memória do
## último ponto conhecido, busca, flanqueamento, separação entre inimigos,
## tempo de ataque (windup) e detecção de ficar travado.

@export_group("node connections")
@export var character_root: Node3D
@export var collision_shape: CollisionShape3D
@export var animation_tree: AnimationTree
@export var damage_body: PhysicalBoneSimulator3D

@export_group("settings")
@export var move_speed: float = 1.0
@export var rotate_speed: float = 2.0
@export var max_health: float = 100.0
var current_health: float = 100.0
@export var show_health_bar: bool = true
@export var can_open_doors: bool = false

@export_group("attack")
@export var attack_damage: float = 10.0
@export var attack_range: float = 2.0
@export var vision_range: float = 10.0
@export var chase_time: float = 5.0
var is_chasing: bool = false

@export_group("ai")
## Abertura total do cone de visão, em graus.
@export var field_of_view: float = 120.0
@export var use_line_of_sight: bool = true
## Distância em que o inimigo escuta tiros do jogador.
@export var hearing_range: float = 20.0
## Tempo que ele continua perseguindo depois de perder o jogador de vista.
@export var memory_time: float = 4.0
## Tempo procurando no último ponto conhecido antes de voltar a patrulhar.
@export var search_time: float = 7.0
@export var patrol_radius: float = 6.0
@export var patrol_wait: float = 2.0
## O quanto ele tenta se aproximar pelas laterais em vez de vir reto.
@export var flank_distance: float = 2.5
## Distância mínima entre inimigos para não se empilharem.
@export var separation_radius: float = 1.7
## Tempo entre o início do ataque e o dano (dá chance de esquivar).
@export var attack_windup: float = 0.35
@export var attack_cooldown: float = 1.6
## Antecipação do movimento do jogador para onde ele corre.
@export var player_prediction: float = 0.25
@export var acceleration: float = 9.0
@export var repath_interval: float = 0.2
## Tempo parado antes de considerar que ficou preso.
@export var stuck_time: float = 1.5

@export_group("sfx")
@export var spawn_sfx: AudioStreamPlayer3D
@export var idle_sfx: AudioStreamPlayer3D
@export var alert_sfx: AudioStreamPlayer3D
@export var hit_sfx: AudioStreamPlayer3D
@export var attack_sfx: AudioStreamPlayer3D
@export var death_sfx: AudioStreamPlayer3D

@export_group("vfx")
@export var spawn_vfx: Node3D
@export var attack_vfx: Node3D
@export var hit_vfx: Node3D
@export var death_vfx: Node3D

enum State { IDLE, PATROL, CHASE, SEARCH, ATTACK, DEAD }

const GRAVITY := -20.0
const LOS_MASK := 3
const ARRIVE_DISTANCE := 0.9
const ATTACK_HEIGHT_LIMIT := 1.6

var state: State = State.PATROL
var is_alive: bool = true
var player = null
var state_machine: AnimationNodeStateMachinePlayback

var nav_agent: NavigationAgent3D
var debug_label: Label3D
var chase_timer: Timer
var health_bar: MeshInstance3D

var _spawn_position: Vector3
var _last_known_position: Vector3
var _has_last_known: bool = false
var _memory_left: float = 0.0
var _search_left: float = 0.0
var _attack_cooldown_left: float = 0.0
var _windup_left: float = 0.0
var _repath_left: float = 0.0
var _patrol_wait_left: float = 0.0
var _stuck_left: float = 0.0
var _stuck_anchor: Vector3
var _flank_offset: Vector3 = Vector3.ZERO
var _flank_left: float = 0.0
var _move_target: Vector3
var _has_move_target: bool = false


func _ready() -> void:
	nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	debug_label = get_node_or_null("DebugLabel") as Label3D
	chase_timer = get_node_or_null("ChaseTimer") as Timer
	health_bar = get_node_or_null("HealthBar") as MeshInstance3D

	if chase_timer:
		chase_timer.timeout.connect(_on_chase_timer_timeout)

	current_health = max_health
	_spawn_position = global_position
	_stuck_anchor = global_position

	if health_bar:
		health_bar.visible = show_health_bar
		if health_bar.get_surface_override_material_count() > 0:
			var material := health_bar.get_active_material(0)
			if material:
				health_bar.set_surface_override_material(0, material.duplicate())
		update_health_bar()

	if can_open_doors:
		add_to_group("door_access")

	if debug_label:
		debug_label.visible = Global.debug_mode

	if animation_tree:
		state_machine = animation_tree.get("parameters/playback")

	if damage_body:
		for bone in damage_body.get_children():
			if bone.has_signal("update_damage"):
				bone.update_damage.connect(get_damage)
			if bone is CollisionObject3D:
				bone.collision_layer = 2
				bone.collision_mask = 2

	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.7

	if Global.has_signal("fire_input"):
		Global.fire_input.connect(_on_global_noise)

	_pick_patrol_point()
	_apply_conditions()

	play_sfx(spawn_sfx)
	play_vfx(spawn_vfx)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	_tick_timers(delta)

	if not is_alive:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		move_and_slide()
		return

	if not is_instance_valid(player):
		player = Global.player

	if player == null or not _player_is_alive():
		_decide_passive(delta)
		_apply_movement(delta)
		move_and_slide()
		return

	_perceive(delta)
	_decide(delta)
	_apply_movement(delta)
	move_and_slide()


# ------------------------------------------------------------- percepção ------

func _perceive(delta: float) -> void:
	_memory_left = maxf(_memory_left - delta, 0.0)

	if _can_see_player():
		_last_known_position = player.global_position
		_has_last_known = true
		_memory_left = memory_time
		_search_left = search_time
		is_chasing = true
		if chase_timer:
			chase_timer.start(chase_time)
	elif is_chasing and _memory_left <= 0.0 and (chase_timer == null or chase_timer.is_stopped()):
		is_chasing = false


func _can_see_player() -> bool:
	if not is_instance_valid(player):
		return false

	var eye := global_position + Vector3.UP * 1.4
	var target: Vector3 = player.global_position + Vector3.UP * 1.2
	var distance := eye.distance_to(target)
	if distance > vision_range:
		return false

	# Cone de visão (ignorado bem de perto, para não "perder" quem está colado).
	if distance > attack_range:
		var forward := _forward()
		var flat := Vector3(target.x - eye.x, 0.0, target.z - eye.z)
		if flat.length() > 0.01:
			if rad_to_deg(forward.angle_to(flat.normalized())) > field_of_view * 0.5:
				return false

	if not use_line_of_sight:
		return true

	var world := get_world_3d()
	if world == null:
		return true
	var exclude: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(eye, target, LOS_MASK, exclude)
	query.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		# Sem nada no caminho: assume visão livre (camadas diferentes de colisão).
		return true
	return hit.get("collider") == player


func _player_is_alive() -> bool:
	return is_instance_valid(player) and player.get("is_alive") != false


func _forward() -> Vector3:
	var root: Node3D = character_root if character_root else self
	var forward := -root.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD


# -------------------------------------------------------------- decisão -------

func _decide(delta: float) -> void:
	if _player_in_attack_range():
		_set_state(State.ATTACK)
		_face(player.global_position + Vector3.UP * 1.2, delta)
		return

	if is_chasing or _memory_left > 0.0:
		_set_state(State.CHASE)
		_move_target = _chase_point()
		_has_move_target = true
		return

	if _has_last_known and _search_left > 0.0:
		_set_state(State.SEARCH)
		_move_target = _last_known_position
		_has_move_target = true
		return

	_has_last_known = false
	_set_state(State.PATROL)
	if _has_move_target and global_position.distance_to(_move_target) > ARRIVE_DISTANCE:
		return
	if _patrol_wait_left > 0.0:
		return
	_pick_patrol_point()
	_patrol_wait_left = patrol_wait


func _decide_passive(delta: float) -> void:
	_set_state(State.PATROL)
	if _has_move_target and global_position.distance_to(_move_target) > ARRIVE_DISTANCE:
		return
	if _patrol_wait_left > 0.0:
		return
	_pick_patrol_point()
	_patrol_wait_left = patrol_wait


func _chase_point() -> Vector3:
	var target: Vector3 = player.global_position
	var player_velocity = player.get("velocity")
	if player_velocity is Vector3:
		target += (player_velocity as Vector3) * player_prediction

	_flank_left -= get_physics_process_delta_time()
	if _flank_left <= 0.0:
		_flank_left = randf_range(1.8, 3.6)
		var side := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		if side.length() > 0.01:
			side = side.normalized()
		_flank_offset = side * flank_distance
	return _project_to_navigation(target + _flank_offset)


func _pick_patrol_point() -> void:
	var angle := randf() * TAU
	var radius := randf_range(patrol_radius * 0.35, maxf(patrol_radius, 0.5))
	var point := _spawn_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
	_move_target = _project_to_navigation(point)
	_has_move_target = true


func _project_to_navigation(point: Vector3) -> Vector3:
	if nav_agent == null:
		return point
	var map := nav_agent.get_navigation_map()
	if map.is_valid():
		return NavigationServer3D.map_get_closest_point(map, point)
	return point


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	var previous := state
	state = new_state
	_apply_conditions()

	match new_state:
		State.ATTACK:
			_windup_left = attack_windup
			play_sfx(attack_sfx)
			play_vfx(attack_vfx)
		State.CHASE:
			if previous != State.SEARCH:
				play_sfx(alert_sfx)
		State.SEARCH:
			play_sfx(alert_sfx)
		State.PATROL:
			play_sfx(idle_sfx)

	if debug_label and Global.debug_mode:
		debug_label.text = String(State.keys()[new_state])


func _apply_conditions() -> void:
	if animation_tree == null:
		return
	animation_tree.set("parameters/conditions/idle", state == State.IDLE or state == State.PATROL)
	animation_tree.set("parameters/conditions/move", state == State.CHASE or state == State.SEARCH)
	animation_tree.set("parameters/conditions/attack", state == State.ATTACK)
	animation_tree.set("parameters/conditions/dead", state == State.DEAD)


# -------------------------------------------------------------- movimento -----

func _apply_movement(delta: float) -> void:
	var desired := Vector3.ZERO

	match state:
		State.CHASE, State.SEARCH, State.PATROL:
			if _has_move_target:
				desired = _navigation_direction() * move_speed
		_:
			desired = Vector3.ZERO

	desired += _separation()

	if desired.length() > 0.05:
		_face(global_position + desired, delta)

	_stuck_check(delta, desired.length() > 0.05)
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)


func _navigation_direction() -> Vector3:
	if nav_agent:
		if _repath_left <= 0.0:
			nav_agent.target_position = _move_target
			_repath_left = repath_interval
		var next := nav_agent.get_next_path_position()
		var to_next := next - global_position
		to_next.y = 0.0
		if to_next.length() > 0.05:
			return to_next.normalized()

	var to_target := _move_target - global_position
	to_target.y = 0.0
	if to_target.length() > 0.05:
		return to_target.normalized()
	return Vector3.ZERO


func _separation() -> Vector3:
	if separation_radius <= 0.0:
		return Vector3.ZERO
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("character"):
		if other == self or not is_instance_valid(other):
			continue
		var other_node := other as Node3D
		if other_node == null:
			continue
		var offset := global_position - other_node.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.01 and distance < separation_radius:
			push += offset.normalized() * ((separation_radius - distance) / separation_radius) * move_speed
	return push.limit_length(move_speed)


func _stuck_check(delta: float, moving: bool) -> void:
	if not moving:
		_stuck_anchor = global_position
		_stuck_left = 0.0
		return

	_stuck_left = maxf(_stuck_left - delta, 0.0)
	if _stuck_left > 0.0:
		return

	if global_position.distance_to(_stuck_anchor) < 0.2:
		var angle := randf() * TAU
		var detour := _spawn_position
		if state == State.CHASE and is_instance_valid(player):
			detour = player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * flank_distance * 3.0
		_move_target = _project_to_navigation(detour)
		_has_move_target = true
		if nav_agent:
			nav_agent.target_position = _move_target
		if debug_label and Global.debug_mode:
			debug_label.text = "DETOUR"

	_stuck_anchor = global_position
	_stuck_left = stuck_time


func _face(target: Vector3, delta: float) -> void:
	var root: Node3D = character_root if character_root else self
	var direction := target - global_position
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	direction = direction.normalized()
	var target_yaw := atan2(-direction.x, -direction.z)
	root.rotation.y = lerp_angle(root.rotation.y, target_yaw, clampf(rotate_speed * delta, 0.0, 1.0))


# ----------------------------------------------------------------- timers -----

func _tick_timers(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_repath_left = maxf(_repath_left - delta, 0.0)
	_search_left = maxf(_search_left - delta, 0.0)
	_patrol_wait_left = maxf(_patrol_wait_left - delta, 0.0)

	if _windup_left > 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_deal_damage()


# ------------------------------------------------------------------ dano ------

func _on_global_noise() -> void:
	if not is_alive:
		return
	if not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > hearing_range:
		return
	# Escutou um tiro: investiga o local.
	_last_known_position = player.global_position
	_has_last_known = true
	_search_left = search_time
	if not is_chasing:
		_move_target = _project_to_navigation(_last_known_position)
		_has_move_target = true


func _player_in_attack_range() -> bool:
	if not is_instance_valid(player):
		return false
	var offset: Vector3 = player.global_position - global_position
	if absf(offset.y) > ATTACK_HEIGHT_LIMIT:
		return false
	offset.y = 0.0
	return offset.length() <= attack_range


func _player_in_vision_range() -> bool:
	if not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) < vision_range


func _on_chase_timer_timeout() -> void:
	is_chasing = false


func _deal_damage() -> void:
	if not is_alive or not _player_is_alive():
		return
	if _attack_cooldown_left > 0.0:
		return
	if not _player_in_attack_range():
		return
	_attack_cooldown_left = attack_cooldown
	var direction = global_position.direction_to(player.global_position)
	player.get_damage(attack_damage, direction, true)


func get_damage(damage: float, _direction: Vector3) -> void:
	if not is_alive:
		return

	current_health -= damage
	update_health_bar()
	play_sfx(hit_sfx)
	play_vfx(hit_vfx)

	# Levar tiro alerta o inimigo, mesmo sem ele ter visto o jogador.
	if is_instance_valid(player):
		_last_known_position = player.global_position
		_has_last_known = true
		_search_left = search_time
		_memory_left = memory_time
		is_chasing = true
		if chase_timer:
			chase_timer.start(chase_time)

	if current_health <= 0:
		is_alive = false
		die()


func update_health_bar() -> void:
	if health_bar == null:
		return
	var health_material := health_bar.get_active_material(0)
	if health_material == null:
		return
	var ratio := 0.0
	if max_health > 0.0:
		ratio = clampf(current_health / max_health, 0.0, 1.0)
	health_material.uv1_offset.x = -((ratio) - 1.0) / 2.0


func die() -> void:
	state = State.DEAD
	_apply_conditions()
	Global.enemy_killed.emit()

	play_vfx(death_vfx)
	play_sfx(death_sfx)

	if character_root:
		character_root.visible = false
	if collision_shape:
		collision_shape.disabled = true
	if health_bar:
		health_bar.visible = false
	if debug_label:
		debug_label.visible = false

	velocity = Vector3.ZERO
	set_physics_process(false)

	await get_tree().create_timer(5.0).timeout
	queue_free()


func play_sfx(sfx: AudioStreamPlayer3D) -> void:
	if sfx:
		sfx.play()


func play_vfx(vfx: Node3D) -> void:
	if vfx == null:
		return
	if vfx is GPUParticles3D:
		(vfx as GPUParticles3D).restart()
	elif vfx.has_method("activate"):
		vfx.activate()
