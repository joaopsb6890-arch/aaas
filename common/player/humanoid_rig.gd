class_name HumanoidRig
extends Node3D
## Boneco articulado feito só com primitivas (nenhum asset importado).
##
## É usado pelo corpo em 3ª pessoa e pela cinemática de abertura. A hierarquia
## de juntas permite animar quadril, coluna, braços e pernas por código, então
## andar, correr, pular, agachar, ser arrastado e levantar do chão são poses
## interpoladas — nada de malha estática.

const SKIN := Color("b9895f")
const CLOTH := Color("2c3532")
const CLOTH_DARK := Color("1b2220")
const ARMOR := Color("39423f")
const ARMOR_DARK := Color("212827")
const STRAP := Color("4a3a28")
const BOOT := Color("13181a")
const GLOVE := Color("1a1f21")
const ACCENT := Color("ff9f1c")
const METAL := Color("767f84")

## Junta -> Node3D.
var joints: Dictionary = {}
var weapon: Node3D = null

var _rest_rot: Dictionary = {}
var _rest_pos: Dictionary = {}
var _target_rot: Dictionary = {}
var _target_pos: Dictionary = {}
var _materials: Dictionary = {}
var _built: bool = false


func _ready() -> void:
	build()


func _process(delta: float) -> void:
	var blend := 1.0 - exp(-16.0 * delta)
	for key in joints:
		var joint: Node3D = joints[key]
		if not is_instance_valid(joint):
			continue
		var target_rot: Vector3 = _target_rot[key]
		var target_pos: Vector3 = _target_pos[key]
		joint.rotation = Vector3(
			lerp_angle(joint.rotation.x, target_rot.x, blend),
			lerp_angle(joint.rotation.y, target_rot.y, blend),
			lerp_angle(joint.rotation.z, target_rot.z, blend)
		)
		joint.position = joint.position.lerp(target_pos, blend)


# ------------------------------------------------------------------ construção

func build() -> void:
	if _built:
		return
	_built = true

	var hips := _joint("hips", self, Vector3(0.0, 0.98, 0.0))
	_box(hips, Vector3(0.33, 0.22, 0.24), ARMOR_DARK, Vector3(0.0, -0.03, 0.0))
	_box(hips, Vector3(0.36, 0.07, 0.27), STRAP, Vector3(0.0, 0.06, 0.0))
	_box(hips, Vector3(0.08, 0.06, 0.02), ACCENT, Vector3(0.0, 0.06, -0.145))
	for side in [-1.0, 1.0]:
		_box(hips, Vector3(0.09, 0.11, 0.06), ARMOR, Vector3(0.17 * side, -0.02, 0.02))

	var spine := _joint("spine", hips, Vector3(0.0, 0.12, 0.0))
	_box(spine, Vector3(0.31, 0.16, 0.22), CLOTH, Vector3(0.0, 0.06, 0.0))

	var chest := _joint("chest", spine, Vector3(0.0, 0.2, 0.0))
	_capsule(chest, 0.18, 0.5, CLOTH, Vector3(0.0, 0.15, 0.0))
	_box(chest, Vector3(0.38, 0.34, 0.27), ARMOR, Vector3(0.0, 0.17, 0.0))
	_box(chest, Vector3(0.22, 0.2, 0.05), ARMOR_DARK, Vector3(0.0, 0.2, -0.145))
	_box(chest, Vector3(0.18, 0.035, 0.02), ACCENT, Vector3(0.0, 0.3, -0.15))
	_box(chest, Vector3(0.05, 0.31, 0.02), STRAP, Vector3(-0.12, 0.15, -0.14))
	_box(chest, Vector3(0.29, 0.33, 0.15), CLOTH_DARK, Vector3(0.0, 0.15, 0.19))
	_box(chest, Vector3(0.2, 0.08, 0.06), STRAP, Vector3(0.0, 0.28, 0.19))
	_box(chest, Vector3(0.06, 0.06, 0.06), ACCENT, Vector3(0.1, 0.03, -0.15))

	var neck := _joint("neck", chest, Vector3(0.0, 0.33, 0.0))
	_capsule(neck, 0.06, 0.12, SKIN, Vector3(0.0, 0.02, 0.0))

	var head := _joint("head", neck, Vector3(0.0, 0.09, 0.0))
	_sphere(head, 0.105, SKIN, Vector3(0.0, 0.09, 0.0), Vector3(1.0, 1.12, 1.02))
	_hemisphere(head, 0.125, ARMOR, Vector3(0.0, 0.11, 0.0))
	_box(head, Vector3(0.09, 0.025, 0.13), ARMOR_DARK, Vector3(0.0, 0.19, -0.01))
	_box(head, Vector3(0.15, 0.04, 0.03), ACCENT, Vector3(0.0, 0.1, -0.105))
	_box(head, Vector3(0.04, 0.05, 0.05), ARMOR_DARK, Vector3(0.11, 0.08, 0.0))
	_box(head, Vector3(0.04, 0.05, 0.05), ARMOR_DARK, Vector3(-0.11, 0.08, 0.0))

	for side in [-1.0, 1.0]:
		_build_arm(chest, side)
		_build_leg(hips, side)

	weapon = _build_weapon(joints["hand_r"])


func _build_arm(chest: Node3D, side: float) -> void:
	var suffix := "l" if side < 0.0 else "r"
	var shoulder := _joint("upperarm_" + suffix, chest, Vector3(0.235 * side, 0.27, 0.0))
	_box(shoulder, Vector3(0.16, 0.1, 0.19), ARMOR, Vector3(0.02 * side, 0.02, 0.0))
	_capsule(shoulder, 0.055, 0.3, CLOTH, Vector3(0.0, -0.15, 0.0))
	_box(shoulder, Vector3(0.115, 0.03, 0.115), STRAP, Vector3(0.0, -0.09, 0.0))

	var elbow := _joint("elbow_" + suffix, shoulder, Vector3(0.0, -0.29, 0.0))
	_sphere(elbow, 0.055, ARMOR_DARK, Vector3.ZERO)
	_capsule(elbow, 0.048, 0.28, CLOTH, Vector3(0.0, -0.14, 0.0))

	var hand := _joint("hand_" + suffix, elbow, Vector3(0.0, -0.27, 0.0))
	_box(hand, Vector3(0.085, 0.11, 0.075), GLOVE, Vector3(0.0, -0.05, 0.0))
	_box(hand, Vector3(0.09, 0.02, 0.08), ACCENT, Vector3(0.0, -0.005, 0.0))


func _build_leg(hips: Node3D, side: float) -> void:
	var suffix := "l" if side < 0.0 else "r"
	var thigh := _joint("thigh_" + suffix, hips, Vector3(0.105 * side, -0.06, 0.0))
	_capsule(thigh, 0.078, 0.46, CLOTH, Vector3(0.0, -0.23, 0.0))
	_box(thigh, Vector3(0.14, 0.09, 0.14), ARMOR, Vector3(0.0, -0.04, 0.0))

	var knee := _joint("knee_" + suffix, thigh, Vector3(0.0, -0.46, 0.0))
	_sphere(knee, 0.07, ARMOR_DARK, Vector3(0.0, 0.0, -0.02))
	_capsule(knee, 0.062, 0.37, CLOTH_DARK, Vector3(0.0, -0.185, 0.0))

	# O tornozelo fica na altura do peito do pé; a sola do coturno toca y = 0.
	var ankle := _joint("ankle_" + suffix, knee, Vector3(0.0, -0.37, 0.0))
	_box(ankle, Vector3(0.15, 0.12, 0.28), BOOT, Vector3(0.0, -0.03, -0.06))
	_box(ankle, Vector3(0.15, 0.03, 0.1), ACCENT, Vector3(0.0, 0.0, -0.17))


func _build_weapon(hand: Node3D) -> Node3D:
	var rifle := Node3D.new()
	rifle.name = "Rifle"
	rifle.position = Vector3(0.0, -0.07, -0.02)
	rifle.rotation = Vector3(deg_to_rad(4.0), 0.0, 0.0)
	hand.add_child(rifle)
	_box(rifle, Vector3(0.07, 0.09, 0.4), METAL, Vector3(0.0, 0.0, -0.12))
	_box(rifle, Vector3(0.05, 0.04, 0.16), ARMOR_DARK, Vector3(0.0, 0.06, -0.03))
	_box(rifle, Vector3(0.06, 0.014, 0.24), ACCENT, Vector3(0.0, 0.047, -0.14))
	_box(rifle, Vector3(0.055, 0.14, 0.075), ARMOR_DARK, Vector3(0.0, -0.11, -0.02))
	_box(rifle, Vector3(0.05, 0.1, 0.16), ARMOR, Vector3(0.0, -0.01, 0.15))
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.018
	barrel.bottom_radius = 0.018
	barrel.height = 0.3
	var barrel_instance := MeshInstance3D.new()
	barrel_instance.mesh = barrel
	barrel_instance.material_override = _material(METAL, 0.55, 0.45)
	barrel_instance.position = Vector3(0.0, 0.0, -0.44)
	barrel_instance.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	rifle.add_child(barrel_instance)
	return rifle


# ---------------------------------------------------------------------- util

func _joint(name: String, parent: Node3D, position: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = name
	node.position = position
	parent.add_child(node)
	joints[name] = node
	_rest_rot[name] = Vector3.ZERO
	_rest_pos[name] = position
	_target_rot[name] = Vector3.ZERO
	_target_pos[name] = position
	return node


func _material(color: Color, metallic: float = 0.0, roughness: float = 0.82) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), metallic, roughness]
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	_materials[key] = material
	return material


func _instance(parent: Node3D, mesh: Mesh, color: Color, position: Vector3, rotation: Vector3 = Vector3.ZERO, metallic: float = 0.0, roughness: float = 0.82) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, metallic, roughness)
	instance.position = position
	instance.rotation = rotation
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, size: Vector3, color: Color, position: Vector3, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(parent, mesh, color, position, rotation)


func _sphere(parent: Node3D, radius: float, color: Color, position: Vector3, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var instance := _instance(parent, mesh, color, position)
	instance.scale = scale
	return instance


func _hemisphere(parent: Node3D, radius: float, color: Color, position: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius
	mesh.is_hemisphere = true
	return _instance(parent, mesh, color, position)


func _capsule(parent: Node3D, radius: float, height: float, color: Color, position: Vector3) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _instance(parent, mesh, color, position)


# --------------------------------------------------------------------- poses

func snap() -> void:
	for key in joints:
		var joint: Node3D = joints[key]
		joint.rotation = _target_rot[key]
		joint.position = _target_pos[key]


func _reset_targets() -> void:
	for key in joints:
		_target_rot[key] = _rest_rot[key]
		_target_pos[key] = _rest_pos[key]


func _rot(joint: String, x: float, y: float = 0.0, z: float = 0.0) -> void:
	_target_rot[joint] = Vector3(x, y, z)


func _pos(joint: String, position: Vector3) -> void:
	_target_pos[joint] = position


func set_weapon_visible(value: bool) -> void:
	if weapon != null:
		weapon.visible = value


## Pose neutra com respiração e pequenos ajustes de equilíbrio.
func pose_idle(time: float) -> void:
	_reset_targets()
	var breath := sin(time * 1.5)
	_rot("hips", 0.0, 0.0, sin(time * 0.7) * 0.015)
	_rot("chest", -0.03 + breath * 0.018, 0.0, 0.0)
	_rot("neck", 0.02 - breath * 0.01, sin(time * 0.45) * 0.05, 0.0)
	_rot("head", -0.02, sin(time * 0.3) * 0.08, 0.0)
	for side in ["l", "r"]:
		var sign_side := -1.0 if side == "l" else 1.0
		_rot("upperarm_" + side, 0.02 + breath * 0.015, 0.0, 0.09 * sign_side)
		_rot("elbow_" + side, 0.18 + breath * 0.02, 0.0, 0.0)
		_rot("thigh_" + side, 0.01, 0.0, 0.02 * sign_side)
		_rot("knee_" + side, 0.04, 0.0, 0.0)
		_rot("ankle_" + side, -0.02, 0.0, 0.0)
	_pos("hips", Vector3(0.0, 0.98 + breath * 0.006, 0.0))


## Ciclo de caminhada/corrida com peso, agachamento, ar e aterrissagem.
func pose_locomotion(phase: float, speed_ratio: float, crouch: float, sprint: float, grounded: bool, vertical: float, aim: float, land: float, time: float) -> void:
	_reset_targets()
	var walk := clampf(speed_ratio, 0.0, 1.0)
	var run := clampf(sprint, 0.0, 1.0)
	var swing := sin(phase)
	var swing2 := sin(phase * 2.0)
	var amplitude := (0.18 + 0.5 * walk) * (1.0 - crouch * 0.35) + run * 0.22

	# Quadril desce no agachamento e sobe/desce no passo.
	var hip_height := 0.98 - crouch * 0.34 - land * 0.12 + absf(swing) * 0.018 * walk
	_pos("hips", Vector3(sin(phase) * 0.018 * walk, hip_height, 0.0))
	_rot("hips", 0.02 * run, swing * 0.1 * walk, sin(phase) * 0.03 * walk)

	# Coluna: inclina para frente ao correr, recua ao agachar.
	_rot("spine", -0.05 * walk - 0.12 * run + crouch * 0.22, -swing * 0.06 * walk, 0.0)
	_rot("chest", -0.03 - 0.1 * run + crouch * 0.16 + sin(time * 1.4) * 0.012, -swing * 0.08 * walk, 0.0)
	_rot("neck", 0.04 + 0.1 * run - crouch * 0.2, swing * 0.03 * walk, 0.0)
	_rot("head", -0.02 - 0.06 * run + crouch * 0.12, -swing * 0.04 * walk, 0.0)

	# Pernas.
	for side in ["l", "r"]:
		var dir := 1.0 if side == "l" else -1.0
		var side_swing := swing * dir
		var thigh_x := -side_swing * amplitude - crouch * 0.9
		var knee_x := maxf(0.0, side_swing) * (0.5 + 0.7 * walk) + crouch * 1.35 + land * 0.55 + maxf(0.0, -vertical) * 0.05
		var ankle_x := -thigh_x * 0.35 - knee_x * 0.3 + 0.06
		if not grounded:
			thigh_x = -0.55 - vertical * 0.03
			knee_x = 1.0 + maxf(0.0, -vertical) * 0.06
			ankle_x = 0.2
		_rot("thigh_" + side, thigh_x, 0.0, 0.02 * (-1.0 if side == "l" else 1.0))
		_rot("knee_" + side, knee_x, 0.0, 0.0)
		_rot("ankle_" + side, ankle_x, 0.0, 0.0)

	# Braços: balanço oposto ao das pernas; sobem ao mirar.
	for side in ["l", "r"]:
		var dir := 1.0 if side == "l" else -1.0
		var sign_side := -1.0 if side == "l" else 1.0
		var arm_swing := -swing * dir * (0.28 + 0.45 * walk)
		var arm_x := arm_swing + 0.02 - crouch * 0.15
		var elbow_x := 0.22 + 0.25 * walk + crouch * 0.2
		var arm_z := 0.09 * sign_side
		if not grounded:
			arm_x = -0.6 - clampf(vertical, -4.0, 4.0) * 0.08
			elbow_x = 0.75
			arm_z = 0.45 * sign_side
		if aim > 0.01:
			# Mira: braço direito à frente, esquerdo apoiando o guarda-mato.
			var aim_arm_x := -1.32 if side == "r" else -1.15
			var aim_elbow := 1.15 if side == "r" else 1.35
			var aim_arm_y := -0.12 if side == "r" else 0.22
			arm_x = lerpf(arm_x, aim_arm_x, aim)
			elbow_x = lerpf(elbow_x, aim_elbow, aim)
			arm_z = lerpf(arm_z, 0.05 * sign_side, aim)
			_rot("upperarm_" + side, arm_x, lerpf(0.0, aim_arm_y, aim), arm_z)
		else:
			_rot("upperarm_" + side, arm_x, 0.0, arm_z)
		_rot("elbow_" + side, elbow_x, 0.0, 0.0)
		_rot("hand_" + side, 0.1, 0.0, 0.0)


## Corpo arrastado pelo chão: braços para trás (acima da cabeça), pernas moles.
func pose_dragged(phase: float, jolt: float) -> void:
	_reset_targets()
	var drag := sin(phase)
	_rot("hips", 0.0, drag * 0.05, 0.0)
	_rot("spine", 0.06, 0.0, drag * 0.04)
	_rot("chest", 0.0, 0.0, drag * 0.03)
	_rot("neck", 0.16 + jolt * 0.25, 0.0, drag * 0.12)
	_rot("head", 0.18 + jolt * 0.3, drag * 0.08, drag * 0.18)
	for side in ["l", "r"]:
		var dir := 1.0 if side == "l" else -1.0
		_rot("upperarm_" + side, -2.75 + jolt * 0.15, 0.1 * dir, 0.18 * dir)
		_rot("elbow_" + side, 0.28 + jolt * 0.2, 0.0, 0.0)
		_rot("hand_" + side, 0.3, 0.0, 0.0)
		_rot("thigh_" + side, 0.16 + drag * 0.05 * dir, 0.0, 0.06 * dir)
		_rot("knee_" + side, 0.18 + maxf(0.0, drag * dir) * 0.2, 0.0, 0.0)
		_rot("ankle_" + side, -0.1, 0.0, 0.0)


## Quem arrasta: anda de costas, inclinado, segurando os pulsos do outro.
func pose_rescuer_drag(phase: float, effort: float) -> void:
	_reset_targets()
	var swing := sin(phase)
	_rot("hips", 0.05, -swing * 0.08, 0.0)
	_pos("hips", Vector3(0.0, 0.98 - absf(swing) * 0.02, 0.0))
	_rot("spine", 0.18 + effort * 0.06, swing * 0.05, 0.0)
	_rot("chest", 0.12 + effort * 0.05, swing * 0.04, 0.0)
	_rot("neck", -0.28, 0.0, 0.0)
	_rot("head", -0.2, swing * 0.05, 0.0)
	for side in ["l", "r"]:
		var dir := 1.0 if side == "l" else -1.0
		_rot("upperarm_" + side, -1.32, -0.18 * dir, 0.22 * dir)
		_rot("elbow_" + side, 0.5, 0.0, 0.0)
		_rot("hand_" + side, -0.25, 0.0, 0.0)
		var thigh_x := swing * dir * 0.45
		_rot("thigh_" + side, thigh_x, 0.0, 0.03 * dir)
		_rot("knee_" + side, maxf(0.0, -swing * dir) * 0.7 + 0.15, 0.0, 0.0)
		_rot("ankle_" + side, -thigh_x * 0.3, 0.0, 0.0)


## Levantar do chão: 0 = deitado, 1 = de pé (com um tranco final).
func pose_getup(t: float, time: float) -> void:
	_reset_targets()
	var k := clampf(t, 0.0, 1.0)

	# Fase 1: apoia os braços e ergue o tronco.
	var push := smoothstep(0.0, 0.34, k)
	# Fase 2: joelho no chão, quadril sobe.
	var knee_up := smoothstep(0.24, 0.68, k)
	# Fase 3: sobe e se firma.
	var stand := smoothstep(0.6, 1.0, k)
	var wobble := sin(time * 16.0) * 0.05 * (1.0 - stand) * stand

	_pos("hips", Vector3(0.0, 0.98 - 0.66 * (1.0 - stand) - 0.14 * knee_up + 0.14 * push, 0.0))
	_rot("hips", 0.42 * (1.0 - stand) - 0.12 * knee_up, wobble, 0.0)
	_rot("spine", 0.55 * (1.0 - stand) + 0.2 * (1.0 - push) - 0.08 * stand, wobble * 0.6, 0.0)
	_rot("chest", 0.35 * (1.0 - stand) - 0.05 * stand, 0.0, wobble * 0.5)
	_rot("neck", -0.3 * (1.0 - stand) - 0.05, 0.0, 0.0)
	_rot("head", -0.25 * (1.0 - stand), 0.0, -wobble)

	for side in ["l", "r"]:
		var dir := 1.0 if side == "l" else -1.0
		var arm_x := lerpf(lerpf(-1.5, -0.35, knee_up), 0.05, stand)
		var elbow_x := lerpf(lerpf(1.4, 0.9, knee_up), 0.2, stand)
		_rot("upperarm_" + side, arm_x, 0.0, lerpf(0.35, 0.1, stand) * dir)
		_rot("elbow_" + side, elbow_x, 0.0, 0.0)
		_rot("hand_" + side, 0.25 * (1.0 - stand), 0.0, 0.0)

		# A perna esquerda apoia primeiro no chão, a direita acompanha.
		var lead := 1.0 if side == "r" else 0.75
		var thigh_x := lerpf(-1.45 * lead, 0.02, stand)
		var knee_x := lerpf(1.9 * lead, 0.05, stand)
		if side == "l":
			thigh_x = lerpf(-0.2, 0.02, stand)
			knee_x = lerpf(0.5, 0.05, stand)
		_rot("thigh_" + side, thigh_x, 0.0, 0.05 * dir)
		_rot("knee_" + side, knee_x, 0.0, 0.0)
		_rot("ankle_" + side, -thigh_x * 0.25 - knee_x * 0.2, 0.0, 0.0)
