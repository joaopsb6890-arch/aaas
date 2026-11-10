extends Node3D
## Corpo visível do jogador nas câmeras de 3ª pessoa.
##
## O template original só tem as armas em primeira pessoa, então em 3ª pessoa
## o personagem era invisível. Este nó monta um boneco simples (só meshes, sem
## colisão) preso ao CameraPivot: ele gira junto com o olhar, mas não acompanha
## a inclinação vertical da câmera (pitch).

const SKIN := Color(0.79, 0.63, 0.5)
const JACKET := Color(0.17, 0.24, 0.22)
const PANTS := Color(0.12, 0.14, 0.17)
const BOOTS := Color(0.08, 0.09, 0.1)
const ACCENT := Color(1.0, 0.62, 0.18)

var _materials: Dictionary = {}


## Monta o corpo alinhado ao chão, independente da altura do pivô da câmera.
func setup(pivot: Node3D, player: Node3D) -> void:
	var feet_y := -1.7
	if is_instance_valid(pivot) and is_instance_valid(player):
		feet_y = player.global_position.y - pivot.global_position.y
	var rig := Node3D.new()
	rig.name = "Rig"
	rig.position.y = feet_y
	add_child(rig)
	_build(rig)


func _build(rig: Node3D) -> void:
	_add_capsule(rig, 0.19, 0.62, JACKET, Vector3(0.0, 1.1, 0.0))
	_add_sphere(rig, 0.115, SKIN, Vector3(0.0, 1.63, 0.0))
	_add_box(rig, Vector3(0.2, 0.09, 0.22), ACCENT, Vector3(0.0, 1.7, 0.0))
	_add_box(rig, Vector3(0.3, 0.34, 0.16), PANTS, Vector3(0.0, 1.12, 0.16))
	_add_box(rig, Vector3(0.44, 0.08, 0.24), ACCENT, Vector3(0.0, 0.86, 0.0))
	for side in [-1.0, 1.0]:
		_add_box(rig, Vector3(0.12, 0.5, 0.13), JACKET, Vector3(0.255 * side, 1.1, 0.0))
		_add_sphere(rig, 0.065, SKIN, Vector3(0.255 * side, 0.82, 0.0))
		_add_box(rig, Vector3(0.16, 0.78, 0.18), PANTS, Vector3(0.095 * side, 0.44, 0.0))
		_add_box(rig, Vector3(0.17, 0.12, 0.27), BOOTS, Vector3(0.095 * side, 0.06, -0.04))


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	_materials[key] = material
	return material


func _add_box(parent: Node3D, size: Vector3, color: Color, position: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add_instance(parent, mesh, color, position)


func _add_sphere(parent: Node3D, radius: float, color: Color, position: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	_add_instance(parent, mesh, color, position)


func _add_capsule(parent: Node3D, radius: float, height: float, color: Color, position: Vector3) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	_add_instance(parent, mesh, color, position)


func _add_instance(parent: Node3D, mesh: Mesh, color: Color, position: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = position
	parent.add_child(instance)
