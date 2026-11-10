extends Node3D

@onready var mesh: MeshInstance3D = $MuzzleFlashFPS
@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var smoke: GPUParticles3D = $Smoke
@onready var sparks: GPUParticles3D = $Sparks


@export var flash_duration = 0.05


func _ready():
	if Global.is_mobile:
		# luz por tiro é cara no telemóvel
		omni_light.queue_free()
		omni_light = null
	activate()


func activate():
	show_effects()
	
	var muzzle_timer = get_tree().create_timer(flash_duration)
	muzzle_timer.timeout.connect(hide_effects)

func show_effects():
	mesh.visible = true
	if omni_light:
		omni_light.visible = true
	smoke.restart()
	sparks.restart()

func hide_effects():
	mesh.visible = false
	if omni_light:
		omni_light.visible = false
	
	await get_tree().create_timer(2.0).timeout
	queue_free()
