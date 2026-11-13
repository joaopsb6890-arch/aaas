extends Node
## Vistas de câmara a pé (tecla V): 1ª pessoa + 3 vistas de 3ª pessoa, como no GTA.

const VIEWS: Array[Dictionary] = [
	{"name": "PRIMEIRA PESSOA", "offset": Vector3(0, 0, 0), "aim": Vector3(0, 0, 0)},
	{"name": "TERCEIRA PESSOA · PERTO", "offset": Vector3(0.55, 0.2, 2.0), "aim": Vector3(0.5, 0.12, 1.1)},
	{"name": "TERCEIRA PESSOA · MÉDIA", "offset": Vector3(0.7, 0.45, 3.4), "aim": Vector3(0.55, 0.25, 1.6)},
	{"name": "TERCEIRA PESSOA · LONGE", "offset": Vector3(0.0, 0.85, 5.6), "aim": Vector3(0.45, 0.35, 2.2)},
]

var player: CharacterBody3D
var index := 0
var body: Mannequin
var _offset := Vector3.ZERO
var _viewmodel: Control
var _vm_viewport: SubViewport


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	body = Mannequin.new()
	body.name = "Body"
	body.bind_player(player)
	player.add_child(body)
	body.visible = false
	_viewmodel = player.get_node_or_null("WeaponSubViewport") as Control
	_vm_viewport = player.get_node_or_null("WeaponSubViewport/SubViewport") as SubViewport
	Global.camera_view_pressed.connect(_on_view_pressed)
	Global.vehicle_exited.connect(_apply)


func is_first_person() -> bool:
	return index == 0


func _on_view_pressed() -> void:
	if Global.in_vehicle or not player.is_alive:
		return
	index = (index + 1) % VIEWS.size()
	_apply()
	Global.camera_view_changed.emit("foot", index, VIEWS[index]["name"])


func _apply() -> void:
	var fp := index == 0
	body.visible = not fp
	if _viewmodel:
		_viewmodel.visible = fp
	if _vm_viewport:
		_vm_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if fp else SubViewport.UPDATE_DISABLED


func _physics_process(delta: float) -> void:
	if Global.in_vehicle or player == null:
		return
	var cam: Camera3D = player.camera
	var v: Dictionary = VIEWS[index]
	var want: Vector3 = v["aim"] if player.is_aiming else v["offset"]
	_offset = _offset.lerp(want, 1.0 - exp(-10.0 * delta))
	if index == 0:
		cam.position = Vector3.ZERO
		return
	var holder: Node3D = player.camera_holder
	var head := holder.global_position
	var desired := holder.global_transform * _offset
	var dist := head.distance_to(desired)
	var q := PhysicsRayQueryParameters3D.create(head, desired, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var local := _offset
	if not hit.is_empty() and dist > 0.01:
		var d := clampf(head.distance_to(hit["position"]) - 0.3, 0.25, dist)
		local = holder.to_local(head + (desired - head).normalized() * d)
	cam.position = local
