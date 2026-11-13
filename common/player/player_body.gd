extends Node3D
## Corpo visível do jogador nas câmeras de 3ª pessoa.
##
## Usa o HumanoidRig (boneco articulado) e lê o estado real do jogador para
## animar: parado, andando, correndo, agachado, no ar, aterrissando e mirando.
## O nó é preso ao CameraPivot, então o corpo gira junto com o olhar, mas fica
## no chão — não acompanha a inclinação vertical da câmera.

const HumanoidRig := preload("res://common/player/humanoid_rig.gd")

var _player: CharacterBody3D
var _pivot: Node3D
var _rig: Node3D

var _phase: float = 0.0
var _time: float = 0.0
var _land: float = 0.0


func _ready() -> void:
	set_process(false)


## Chamado pela CameraDirector quando o corpo é criado.
func setup(pivot: Node3D, player: CharacterBody3D) -> void:
	_pivot = pivot
	_player = player
	add_child(HumanoidRig.new())
	_rig = get_child(0)
	_update_feet()
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_pivot) or _rig == null:
		return

	_time += delta
	_update_feet()

	if Global.in_vehicle:
		visible = false
		return

	var velocity := _player.velocity
	var planar := Vector2(velocity.x, velocity.z).length()
	var crouch := clampf(_num("crouch_amount", 0.0), 0.0, 1.0)
	var sprint := clampf(_num("sprint_amount", 0.0), 0.0, 1.0)
	var aim := clampf(_num("aim_amount", 0.0), 0.0, 1.0)
	var land_dip := clampf(_num("land_dip", 0.0), 0.0, 1.0)
	var grounded := _player.is_on_floor()

	_land = maxf(_land - delta * 4.0, land_dip)
	if land_dip > _land:
		_land = land_dip

	# Cadência do passo proporcional à velocidade real.
	_phase += planar * delta * 2.35
	if planar < 0.15:
		_phase = lerp_angle(_phase, 0.0, delta * 4.0)

	var speed_ratio := clampf(planar / maxf(1.0, float(_player.get("walk_speed"))), 0.0, 1.8)

	if _rig.has_method("pose_locomotion"):
		_rig.pose_locomotion(
			_phase,
			speed_ratio,
			crouch,
			sprint,
			grounded,
			velocity.y,
			aim,
			_land,
			_time
		)

	# Inclinação do corpo inteiro: leve ao correr, mais forte ao agachar/aterrissar.
	var target_pitch := -0.06 * sprint + 0.04 * crouch
	_rig.rotation.x = lerpf(_rig.rotation.x, target_pitch, 1.0 - exp(-8.0 * delta))
	var squash := _land * 0.06
	_rig.scale = _rig.scale.lerp(
		Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5),
		1.0 - exp(-18.0 * delta)
	)


func _update_feet() -> void:
	if not is_instance_valid(_pivot) or not is_instance_valid(_player):
		return
	position.y = _player.global_position.y - _pivot.global_position.y
	position.x = 0.0
	position.z = 0.0


func _num(property: StringName, fallback: float) -> float:
	var value: Variant = _player.get(property)
	if value is float or value is int:
		return float(value)
	return fallback
