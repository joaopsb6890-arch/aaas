extends Node
## GTA-style camera switcher for the player on foot.
##
## Autoload: keeps working with the stock player scene because it only reads the
## existing CameraPivot / CameraHolder / %MainCamera transforms and drives its own
## collision-aware Camera3D. Press V to cycle through 4 views.

const ViewToast := preload("res://common/camera/view_toast.gd")
const PlayerBody := preload("res://common/player/player_body.gd")

const VIEWS := [
	{"title": "1ª PESSOA", "dist": 0.0, "height": 0.0, "side": 0.0, "fov": 75.0, "smooth": 0.0},
	{"title": "3ª PESSOA - PERTO", "dist": 2.6, "height": 0.15, "side": 0.5, "fov": 70.0, "smooth": 14.0},
	{"title": "3ª PESSOA - MEDIA", "dist": 4.0, "height": 0.4, "side": 0.4, "fov": 68.0, "smooth": 10.0},
	{"title": "3ª PESSOA - LONGE", "dist": 5.6, "height": 0.75, "side": 0.0, "fov": 66.0, "smooth": 8.0},
]

const CAMERA_COLLISION_MASK := 1
const COLLISION_PADDING := 0.28
const CAMERA_CULL_MASK := 1048573

var _player: Node3D
var _player_camera: Camera3D
var _pivot: Node3D
var _holder: Node3D
var _camera: Camera3D
var _body: Node3D
var _toast: CanvasLayer

var _view: int = 0
var _cam_position: Vector3
var _cam_ready: bool = false


func _input(event: InputEvent) -> void:
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

	if Global.in_vehicle:
		# O veículo controla a própria câmera e a visibilidade do player.
		if _view != 0:
			_view = 0
			_cam_ready = false
		if _camera != null and _camera.current:
			_camera.current = false
		return

	_apply_view(delta)


func _resolve() -> bool:
	if is_instance_valid(_player):
		if is_instance_valid(_player_camera) and is_instance_valid(_camera):
			return true
		# Jogador válido, mas as câmeras foram recriadas (troca de cena, etc.).
		_player_camera = _find_player_camera()
		if _player_camera == null:
			return false
		_pivot = _player.get_node_or_null("CameraPivot") as Node3D
		if _pivot == null:
			_pivot = _player
		_holder = _player_camera.get_parent() as Node3D
		_ensure_camera()
		return is_instance_valid(_camera)

	# Referências antigas (jogador removido / cena trocada):
	# importate limpar antes de qualquer checagem de tipo.
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
	_camera.fov = float(VIEWS[1]["fov"])
	_camera.near = 0.05
	parent.add_child(_camera)
	_cam_ready = false


func _apply_view(delta: float) -> void:
	var view: Dictionary = VIEWS[_view]

	if _view == 0:
		if _camera != null and _camera.current:
			_camera.current = false
		if not _player_camera.current:
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
		pitch = clampf(_holder.rotation.x, deg_to_rad(-70.0), deg_to_rad(55.0))
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var origin: Vector3 = pivot.global_position
	var desired: Vector3 = origin + basis * Vector3(float(view["side"]), float(view["height"]), float(view["dist"]))
	desired = _resolve_collision(origin, desired)

	var smooth: float = float(view["smooth"])
	if not _cam_ready:
		_cam_position = desired
		_cam_ready = true
	elif smooth > 0.0:
		_cam_position = _cam_position.lerp(desired, 1.0 - exp(-smooth * delta))
	else:
		_cam_position = desired

	_camera.global_transform = Transform3D(basis, _cam_position)
	_camera.fov = lerpf(_camera.fov, float(view["fov"]), 1.0 - exp(-7.0 * delta))
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
	return from + direction * maxf(distance, 0.35)


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
		_body.visible = not first_person


func _ensure_body() -> void:
	if is_instance_valid(_body):
		return
	if not is_instance_valid(_player) or not is_instance_valid(_pivot):
		return
	_body = PlayerBody.new()
	_body.name = "PlayerBody"
	_pivot.add_child(_body)
	_body.setup(_pivot, _player)


func _show_toast() -> void:
	if _toast == null:
		return
	_toast.toast("CÂMERA  %s  (%d/%d)" % [String(VIEWS[_view]["title"]), _view + 1, VIEWS.size()])
