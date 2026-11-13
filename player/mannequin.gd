class_name Mannequin
extends Node3D
## Boneco procedural (sem assets): corpo do jogador em 3ª pessoa e condutor do carro.

var seated := false
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var head: Node3D
var aim_pivot: Node3D
var flash: MeshInstance3D
var guns: Dictionary = {}
var _phase := 0.0
var _speed := 0.0
var _recoil := 0.0
var _flash_t := 0.0
var _combat := 0.0
var _player: CharacterBody3D


func _ready() -> void:
	_build()
	if not seated:
		Global.camera_shake.connect(_on_fire)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build() -> void:
	var skin := _mat(Color(0.85, 0.68, 0.55))
	var shirt := _mat(Color(0.2, 0.25, 0.19))
	var vest := _mat(Color(0.1, 0.12, 0.11))
	var pants := _mat(Color(0.15, 0.17, 0.22))
	var dark := _mat(Color(0.06, 0.06, 0.07))
	var accent := _mat(Color(1.0, 0.48, 0.18))
	_box(self, Vector3(0.4, 0.2, 0.24), Vector3(0, 0.95, 0), pants)
	_box(self, Vector3(0.44, 0.56, 0.26), Vector3(0, 1.22, 0), shirt)
	_box(self, Vector3(0.47, 0.4, 0.29), Vector3(0, 1.27, 0), vest)
	_box(self, Vector3(0.3, 0.05, 0.3), Vector3(0, 1.05, 0), accent)
	for sx in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.11 * sx, 0.92, 0)
		add_child(leg)
		_box(leg, Vector3(0.17, 0.82, 0.2), Vector3(0, -0.41, 0), pants)
		_box(leg, Vector3(0.18, 0.12, 0.3), Vector3(0, -0.86, -0.05), dark)
		legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(0.29 * sx, 1.43, 0)
		add_child(arm)
		_box(arm, Vector3(0.1, 0.5, 0.1), Vector3(0, -0.25, 0), shirt)
		_box(arm, Vector3(0.09, 0.1, 0.09), Vector3(0, -0.55, 0), skin)
		arms.append(arm)
	head = Node3D.new()
	head.position = Vector3(0, 1.57, 0)
	add_child(head)
	var sph := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.115
	sm.height = 0.23
	sph.mesh = sm
	sph.material_override = skin
	sph.position = Vector3(0, 0.12, 0)
	head.add_child(sph)
	_box(head, Vector3(0.27, 0.1, 0.27), Vector3(0, 0.22, 0), dark)
	_box(head, Vector3(0.17, 0.04, 0.05), Vector3(0, 0.13, -0.12), dark)
	# armas
	aim_pivot = Node3D.new()
	aim_pivot.position = Vector3(0, 1.38, 0)
	add_child(aim_pivot)
	var rifle := Node3D.new()
	_box(rifle, Vector3(0.06, 0.12, 0.62), Vector3(0.14, 0, -0.38), dark)
	_box(rifle, Vector3(0.04, 0.04, 0.3), Vector3(0.14, 0.02, -0.82), dark)
	var pistol := Node3D.new()
	_box(pistol, Vector3(0.05, 0.12, 0.24), Vector3(0.14, 0, -0.3), dark)
	var knife := Node3D.new()
	_box(knife, Vector3(0.025, 0.05, 0.28), Vector3(0.14, 0, -0.38), _mat(Color(0.75, 0.78, 0.82)))
	guns = {"rifle": rifle, "pistol": pistol, "knife": knife}
	for g in guns.values():
		aim_pivot.add_child(g)
		g.visible = false
	var fm := SphereMesh.new()
	fm.radius = 0.09
	fm.height = 0.18
	flash = MeshInstance3D.new()
	flash.mesh = fm
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.8, 0.3)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.7, 0.2)
	flash_mat.emission_energy_multiplier = 4.0
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = flash_mat
	flash.position = Vector3(0.14, 0.02, -1.0)
	flash.visible = false
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_pivot.add_child(flash)
	if seated:
		aim_pivot.visible = false
		for i in 2:
			legs[i].rotation.x = deg_to_rad(80.0)
			arms[i].rotation.x = deg_to_rad(62.0)


func bind_player(p: CharacterBody3D) -> void:
	_player = p


func _on_fire() -> void:
	if not visible:
		return
	_recoil = 1.0
	_flash_t = 0.045
	_combat = 2.5


func _current_gun() -> String:
	if _player == null:
		return "rifle"
	var wm: Node = _player.get_node_or_null("WeaponsManager")
	if wm and wm.current_weapon:
		var n := String(wm.current_weapon.name)
		if n == "Knife":
			return "knife"
		if n == "Pistol":
			return "pistol"
	return "rifle"


func _process(delta: float) -> void:
	if seated or _player == null or not visible:
		return
	var vel := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	_speed = lerpf(_speed, vel.length(), 1.0 - exp(-12.0 * delta))
	var grounded := _player.is_on_floor()
	_combat = maxf(_combat - delta, 0.0)
	var aiming: bool = _player.is_aiming or _combat > 0.0
	# orientação: a olhar para a câmara ao mirar/disparar, senão para onde anda
	var cam_yaw: float = _player.camera_pivot.rotation.y
	var want := rotation.y
	if aiming:
		want = cam_yaw
	elif vel.length() > 0.4:
		want = atan2(-vel.x, -vel.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-12.0 * delta))
	# pernas
	_phase += _speed * delta * 2.6
	var amp := clampf(_speed / 6.0, 0.0, 1.0) * 0.85
	if not grounded:
		legs[0].rotation.x = 0.5
		legs[1].rotation.x = -0.4
	else:
		legs[0].rotation.x = sin(_phase) * amp
		legs[1].rotation.x = -sin(_phase) * amp
	# arma
	for k in guns:
		guns[k].visible = (k == _current_gun())
	var pitch: float = _player.camera_holder.rotation.x
	var carry := pitch if aiming else deg_to_rad(-38.0)
	_recoil = maxf(_recoil - delta * 9.0, 0.0)
	carry += _recoil * 0.07
	aim_pivot.rotation.x = lerpf(aim_pivot.rotation.x, carry, 1.0 - exp(-14.0 * delta))
	for a in arms:
		a.rotation.x = deg_to_rad(90.0) + aim_pivot.rotation.x
	head.rotation.x = clampf(pitch * 0.7, -0.6, 0.6)
	_flash_t = maxf(_flash_t - delta, 0.0)
	flash.visible = _flash_t > 0.0 and _current_gun() != "knife"
	# inclinação ao correr
	rotation.x = 0.0
	position.y = absf(sin(_phase)) * 0.03 * amp
