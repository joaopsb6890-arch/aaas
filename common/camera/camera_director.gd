extends Node
## Câmeras do jogador a pé, com a tecla V.
##
## 4 vistas: 1ª pessoa, 3ª perto, 3ª média e 3ª longe. A câmera de perseguição
## tem ombro, colisão com o cenário, suavização, FOV dinâmico (corrida/mira) e
## tremor em dano. O corpo visível é criado e animado por PlayerBody.

const ViewToast := preload("res://common/camera/view_toast.gd")
const PlayerBody := preload("res://common/player/player_body.gd")

const VIEWS := [
	{"title": "1ª PESSOA", "dist": 0.0, "height": 0.0, "side": 0.0, "fov": 76.0, "smooth": 0.0, "first_person": true},
	{"title": "3ª PESSOA", "dist": 2.75, "height": 0.14, "side": 0.52, "fov": 70.0, "smooth": 17.0, "first_person": false},
	{"title": "3ª PESSOA - MÉDIA", "dist": 4.2, "height": 0.38, "side": 0.42, "fov": 68.0, "smooth": 12.0, "first_person": false},
	{"title": "3ª PESSOA - LONGE", "dist": 6.0, "height": 0.7, "side": 0.0, "fov": 66.0, "smooth": 9.0, "first_person": false},
]

const DEFAULT_VIEW: int = 1
const CAMERA_COLLISION_MASK := 1
const COLLISION_PADDING := 0.3
const CAMERA_CULL_MASK := 1048573

var _player: Node3D
var _player_camera: Camera3D
var _pivot: Node3D
var _holder: Node3D
var _camera: Camera3D
var _body: Node3D
var _toast: CanvasLayer

var _view: int = DEFAULT_VIEW
var _cam_position: Vector3
var _cam_ready: bool = false
var _shake: float = 0.0


func _input(event: InputEvent) -> void:
	if Global.cinematic_mode:
		return
	if not event.is_action_pressed("camera_view"):
		return
	if Global.in_vehicle:
		return
	if not _resolve():
		return
	_view = (_view + 1) % VIEWS.size()
	_cam_ready = false
	_show_toast()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _resolve():
		return

	if Global.cinematic_mode:
		if _camera != null and _camera.current:
			_camera.current = false
		_cam_ready = false
		return

	if Global.in_vehicle:
		# O veículo controla a própria câmera e a visibilidade do player.
		if _camera != null and _camera.current:
			_camera.current = false
		_cam_ready = false
		return

	_apply_view(delta)


## Usado no fim da cinemática para a câmera entrar em cena já enquadrada.
func refresh() -> void:
	_cam_ready = false
	if is_instance_valid(_camera):
		_camera.current = false


func _resolve() -> bool:
	if is_instance_valid(_player):
		if is_instance_valid(_player_camera) and is_instance_valid(_camera):
			return true
		_player_camera = _find_player_camera()
		if _player_camera == null:
			return false
		_pivot = _player.get_node_or_null("CameraPivot") as Node3D
		if _pivot == null:
			_pivot = _player
		_holder = _player_camera.get_parent() as Node3D
		_ensure_camera()
		return is_instance_valid(_camera)

	# Referências antigas (jogador removido / cena trocada).
	_player = null
	_player_camera = null
	_pivot = null
	_holder = null
	_camera = null
	_body = null
	_cam_ready = false

	var candidate: Node = Global.player
	if is_instance_valid(candidate) and candidate is Node3D:
		_player = candidate as Node3D
	else:
		var grouped: Node = get_tree().get_first_node_in_group("player")
		if is_instance_valid(grouped) and grouped is Node3D:
			_player = grouped as Node3D

	if _player == null or not _player.is_inside_tree():
		_player = null
		return false

	_player_camera = _find_player_camera()
	if _player_camera == null:
		return false
	_pivot = _player.get_node_or_null("CameraPivot") as Node3D
	if _pivot == null:
		_pivot = _player
	_holder = _player_camera.get_parent() as Node3D
	_ensure_camera()
	if _toast == null:
		_toast = ViewToast.new()
		add_child(_toast)
	return is_instance_valid(_camera)


func _find_player_camera() -> Camera3D:
	if not is_instance_valid(_player):
		return null
	var unique := _player.get_node_or_null("%MainCamera")
	if unique is Camera3D:
		return unique as Camera3D
	return _find_camera_recursive(_player)


func _find_camera_recursive(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child as Camera3D
		var found := _find_camera_recursive(child)
		if found != null:
			return found
	return null


func _ensure_camera() -> void:
	if is_instance_valid(_camera):
		return
	if not is_instance_valid(_player):
		return
	var parent := _player.get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	_camera = Camera3D.new()
	_camera.name = "ThirdPersonCamera"
	_camera.cull_mask = CAMERA_CULL_MASK
	_camera.fov = float(VIEWS[DEFAULT_VIEW]["fov"])
	_camera.near = 0.06
	_camera.far = 900.0
	parent.add_child(_camera)
	_cam_ready = false


func _apply_view(delta: float) -> void:
	var view: Dictionary = VIEWS[_view]

	if bool(view["first_person"]):
		if _camera != null and _camera.current:
			_camera.current = false
		if _player_camera != null and not _player_camera.current:
			_player_camera.make_current()
		_set_view_visuals(true)
		return

	_set_view_visuals(false)

	var pivot: Node3D = _pivot if is_instance_valid(_pivot) else _player
	if not is_instance_valid(pivot):
		return

	var yaw: float = pivot.global_rotation.y
	var pitch: float = 0.0
	if is_instance_valid(_holder):
		pitch = clampf(_holder.rotation.x, deg_to_rad(-68.0), deg_to_rad(52.0))

	var aiming := float(_player.get("aim_amount")) if _has_prop("aim_amount") else 0.0
	var sprinting := float(_player.get("sprint_amount")) if _has_prop("sprint_amount") else 0.0
	var land_dip := float(_player.get("land_dip")) if _has_prop("land_dip") else 0.0

	var side: float = float(view["side"])
	var distance: float = float(view["dist"])
	if aiming > 0.01:
		side = lerpf(side, 0.3, aiming)
		distance = lerpf(distance, maxf(distance - 0.7, 1.6), aiming)

	var basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var origin: Vector3 = pivot.global_position
	var desired: Vector3 = origin + basis * Vector3(side, float(view["height"]), distance)
	desired.y -= land_dip * 0.12
	desired = _resolve_collision(origin, desired)
	# Nunca deixa a câmera afundar no chão.
	desired.y = maxf(desired.y, _player.global_position.y + 0.35)

	var smooth: float = float(view["smooth"])
	if not _cam_ready:
		_cam_position = desired
		_cam_ready = true
	else:
		_cam_position = _cam_position.lerp(desired, 1.0 - exp(-smooth * delta))

	# Um leve olhar para baixo deixa o personagem mais centralizado no quadro.
	var look_basis := Basis.from_euler(Vector3(pitch + 0.045, yaw, 0.0))
	if _shake > 0.001:
		var tilt := Basis.from_euler(Vector3(
			randf_range(-_shake, _shake),
			randf_range(-_shake, _shake),
			randf_range(-_shake, _shake) * 0.5
		))
		look_basis = look_basis * tilt
		_shake = maxf(_shake - delta * 0.9, 0.0)

	_camera.global_transform = Transform3D(look_basis, _cam_position)

	var target_fov: float = float(view["fov"])
	target_fov += 6.0 * sprinting
	target_fov -= 16.0 * aiming
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-8.0 * delta))
	if not _camera.current:
		_camera.make_current()


func _resolve_collision(from: Vector3, to: Vector3) -> Vector3:
	if not is_instance_valid(_player):
		return to
	var world := _player.get_world_3d()
	if world == null:
		return to
	var state := world.direct_space_state
	if state == null:
		return to
	var exclude: Array[RID] = []
	if _player is CollisionObject3D:
		exclude.append((_player as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, CAMERA_COLLISION_MASK, exclude)
	query.collide_with_areas = false
	var hit := state.intersect_ray(query)
	if hit.is_empty():
		return to
	var direction := (to - from).normalized()
	var distance := from.distance_to(hit["position"]) - COLLISION_PADDING
	return from + direction * maxf(distance, 0.4)


## Primeira pessoa: armas na tela e corpo escondido.
## Terceira pessoa: corpo visível e armas da tela escondidas.
func _set_view_visuals(first_person: bool) -> void:
	if not is_instance_valid(_player):
		return
	_player.visible = true
	var arms_viewport := _player.get_node_or_null("WeaponSubViewport")
	if arms_viewport is CanvasItem:
		(arms_viewport as CanvasItem).visible = first_person
	_ensure_body()
	if is_instance_valid(_body):
		_body.visible = not first_person and not Global.in_vehicle


func _ensure_body() -> void:
	if is_instance_valid(_body):
		return
	if not is_instance_valid(_player) or not is_instance_valid(_pivot):
		return
	_body = PlayerBody.new()
	_body.name = "PlayerBody"
	_pivot.add_child(_body)
	_body.setup(_pivot, _player)


func _has_prop(property: StringName) -> bool:
	return _player.get(property) != null


func _show_toast() -> void:
	if _toast == null:
		return
	_toast.toast("CÂMERA  %s  (%d/%d)" % [String(VIEWS[_view]["title"]), _view + 1, VIEWS.size()])


func _ready() -> void:
	if Global.has_signal("camera_shake"):
		Global.camera_shake.connect(_on_camera_shake)


func _on_camera_shake() -> void:
	_shake = 0.03
