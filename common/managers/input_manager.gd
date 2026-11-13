extends Node

var aim_mode:bool = false
var mouse_mode_captured:bool = true

func _ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	#AIM_MODE
	if event.is_action_pressed("aim_mode"):
		aim_mode = true
		Global.aim_mode_changed.emit(aim_mode)
	elif event.is_action_released("aim_mode"):
		aim_mode = false
		Global.aim_mode_changed.emit(aim_mode)


func _process(_delta: float) -> void:
	if Global.menu_open or not Global.game_active:
		return
	if not Global.in_vehicle:
		#FIRING
		if Input.is_action_just_pressed("fire"):
			Global.fire_input.emit()

		#RELOAD
		if Input.is_action_just_pressed("reload"):
			Global.reload_input.emit()

		#WEAPON SWITCHING
		if Input.is_action_just_pressed("weapon_change_next"):
			Global.weapon_switch_next.emit()

		if Input.is_action_just_pressed("weapon_change_prev"):
			Global.weapon_switch_prev.emit()

	#ACTIVATE
	if Input.is_action_just_pressed("activate"):
		Global.activate_pressed.emit()

	#CAMERA VIEW (V)
	if Input.is_action_just_pressed("camera_view") and Global.game_active and not Global.menu_open:
		Global.camera_view_pressed.emit()

	#PAUSE
	if Input.is_action_just_pressed("pause") and Global.game_active and not Global.menu_open:
		Global.pause_requested.emit()
