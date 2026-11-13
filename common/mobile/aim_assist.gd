extends Node
## Auxílio de mira para toque (só mobile). Três camadas:
##  1) Fricção: a câmara fica mais "pesada" quando a mira passa por cima de um inimigo.
##  2) Magnetismo: puxa suavemente a mira para o peito do inimigo mais próximo do centro
##     (mais forte ao disparar/mirar; quase nulo se estiveres a arrastar rápido).
##  3) Feedback: a mira fica vermelha quando há um alvo (Global.aim_on_target).
## A força vem de Global.aim_assist_strength (0 = desligado, 1 = forte).

const SCAN_INTERVAL: float = 0.08
const MAX_RANGE: float = 50.0
const CHEST_HEIGHT: float = 1.35

var player: CharacterBody3D
## Multiplicador aplicado ao movimento de câmara do jogador (fricção).
var look_multiplier: float = 1.0

var _wm: Node
var _target: Node3D = null
var _scan_t: float = 0.0
var _look_accum: float = 0.0
var _look_speed: float = 0.0   # rad/s do dedo do jogador


func _ready() -> void:
	if player:
		_wm = player.get_node_or_null("WeaponsManager")


func notify_look(d: Vector2) -> void:
	_look_accum += d.length()


func _strength() -> float:
	return Global.aim_assist_strength


func _is_active() -> bool:
	return _strength() > 0.01 \
		and is_instance_valid(player) \
		and player.is_alive \
		and not Global.in_vehicle \
		and not get_tree().paused


func _physics_process(delta: float) -> void:
	var speed := _look_accum / maxf(delta, 0.0001)
	_look_accum = 0.0
	_look_speed = lerpf(_look_speed, speed, 0.25)

	if not _is_active():
		_set_target(null)
		look_multiplier = 1.0
		return

	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_INTERVAL
		_set_target(_find_target())

	# Fricção (desaparece se o jogador faz um "flick" rápido)
	var want := 1.0
	if _target:
		var flick := clampf((_look_speed - 2.0) / 3.0, 0.0, 1.0)
		want = lerpf(lerpf(1.0, 0.5, _strength()), 1.0, flick)
	look_multiplier = lerpf(look_multiplier, want, minf(delta * 12.0, 1.0))


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or not _is_active():
		return
	if "is_alive" in _target and not _target.is_alive:
		_set_target(null)
		return

	var cam: Camera3D = player.camera
	var pt := _target.global_position + Vector3.UP * CHEST_HEIGHT
	var dir := (pt - cam.global_position).normalized()
	var desired_yaw := atan2(-dir.x, -dir.z)
	var desired_pitch := asin(clampf(dir.y, -1.0, 1.0))
	var yaw_err := wrapf(desired_yaw - player.camera_pivot.rotation.y, -PI, PI)
	var pitch_err: float = desired_pitch - player.camera_holder.rotation.x

	var active: bool = Input.is_action_pressed("fire") or player.is_aiming
	var s := _strength()
	var override := clampf(_look_speed / 1.5, 0.0, 1.0)   # dedo rápido = tu mandas
	var rate := 8.0 * s * (1.0 if active else 0.3) * (1.0 - 0.85 * override)
	var k := minf(rate * delta, 1.0)
	var max_step := deg_to_rad(150.0) * delta

	player.camera_pivot.rotate_y(clampf(yaw_err * k, -max_step, max_step))
	player.camera_holder.rotate_x(clampf(pitch_err * k, -max_step, max_step))
	player.camera_holder.rotation.x = clampf(player.camera_holder.rotation.x, deg_to_rad(-60), deg_to_rad(60))


func _set_target(t: Node3D) -> void:
	_target = t
	Global.aim_on_target = t != null


func _find_target() -> Node3D:
	var cam: Camera3D = player.camera
	var origin := cam.global_position
	var fwd := -cam.global_basis.z

	var weapon = _wm.current_weapon if _wm else null
	var rng := MAX_RANGE
	if weapon:
		rng = (weapon.firing_distance + 1.5) if weapon.is_melee_weapon else clampf(weapon.firing_distance, 6.0, MAX_RANGE)

	var cone := deg_to_rad(lerpf(4.0, 9.0, _strength()))
	if Input.is_action_pressed("fire") or player.is_aiming:
		cone *= 1.5

	var cands: Array[Dictionary] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.is_alive:
			continue
		var pt: Vector3 = e.global_position + Vector3.UP * CHEST_HEIGHT
		var to := pt - origin
		var dist := to.length()
		if dist < 0.8 or dist > rng:
			continue
		var ang := fwd.angle_to(to)
		if ang > cone:
			continue
		cands.append({"e": e, "pt": pt, "score": ang + dist * 0.002})
	if cands.is_empty():
		return null
	cands.sort_custom(func(a, b): return a["score"] < b["score"])

	var space := player.get_world_3d().direct_space_state
	for i in mini(cands.size(), 3):
		var c: Dictionary = cands[i]
		var q := PhysicsRayQueryParameters3D.create(origin, c["pt"], 1, [player.get_rid(), c["e"].get_rid()])
		if space.intersect_ray(q).is_empty():
			return c["e"]
	return null
