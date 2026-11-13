extends Node
## Cinemática de abertura.
##
## 1) Um soldado arrasta o jogador pelo chão (bonecos animados + câmera baixa).
## 2) Corte para preto.
## 3) O jogador levanta do chão em 3ª pessoa e a câmera sobe até o enquadramento
##    de jogo.
## 4) O HUD entra em cena e o controle é liberado.
##
## Tudo é construído por código: nenhuma cena extra precisa ser mantida.

const HumanoidRig := preload("res://common/player/humanoid_rig.gd")
const FOOTSTEP := preload("res://player/sfx/footstep_ground.ogg")
const FONT_PATH := "res://resources/fonts/ShareTech-Regular.ttf"

const DRAG_DURATION := 6.4
const GETUP_DURATION := 3.6

var _player: CharacterBody3D
var _hud: Control
var _scene_root: Node

var _overlay: CanvasLayer
var _black: ColorRect
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _subtitle: Label
var _skip_hint: Label

var _camera: Camera3D
var _camera_ready: bool = false
var _spawn: Vector3 = Vector3.ZERO

var _dragged_root: Node3D
var _dragged_rig: Node3D
var _rescuer_root: Node3D
var _rescuer_rig: Node3D
var _getup_root: Node3D
var _getup_rig: Node3D

var _drag_active: bool = false
var _drag_time: float = 0.0
var _step_left: float = 0.0
var _skip: bool = false
var _sfx: AudioStreamPlayer3D


func _ready() -> void:
	_scene_root = get_tree().current_scene
	if _scene_root == null:
		_scene_root = get_parent()

	var candidate: Node = Global.player
	if is_instance_valid(candidate) and candidate is CharacterBody3D:
		_player = candidate as CharacterBody3D
	else:
		var grouped := get_tree().get_first_node_in_group("player")
		if grouped is CharacterBody3D:
			_player = grouped as CharacterBody3D
	if _player == null:
		queue_free()
		return

	_hud = get_tree().get_first_node_in_group("hud") as Control
	_spawn = _player.global_position
	Global.cinematic_mode = true
	Global.enemies_killed = 0
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	_player.velocity = Vector3.ZERO
	var arms := _player.get_node_or_null("WeaponSubViewport")
	if arms is CanvasItem:
		(arms as CanvasItem).visible = false
	if _hud != null:
		_hud.visible = false

	# A cena ainda está instanciando os filhos durante o _ready; só dá para
	# adicionar os nós da cinemática depois deste frame.
	await get_tree().process_frame
	_pause_spawners()
	_build_ui()
	_build_bodies()
	_build_camera()
	await _run()


func _run() -> void:
	# Alguns frames em preto também dão tempo ao renderizador para compilar os
	# materiais da fase antes da primeira imagem da cinemática.
	for i in 5:
		await get_tree().process_frame

	await _fade_black(1.0, 0.0, 1.0)
	_show_letterbox(true)
	_drag_active = true
	_show_subtitle("— Aguenta firme. A gente chega na base.", 0.35)
	await _wait(4.6)
	_show_subtitle("— Levanta. Levanta agora!", 0.0)
	await _wait(1.6)
	_drag_active = false
	_skip_hint.visible = false
	_hide_subtitle()
	await _fade_black(0.0, 1.0, 0.5)
	await _wait(0.35)
	_clear_drag()
	await _play_getup()
	_finish()


func _process(delta: float) -> void:
	if not _drag_active or _dragged_root == null or _rescuer_root == null:
		return

	_drag_time = minf(_drag_time + delta, DRAG_DURATION)
	var t := _drag_time / DRAG_DURATION
	var eased := smoothstep(0.0, 1.0, t)
	var base_z := lerpf(_spawn.z - 3.6, _spawn.z - 0.5, eased)

	_dragged_root.position = Vector3(_spawn.x, _spawn.y + 0.16, base_z)
	_dragged_root.rotation = Vector3(deg_to_rad(88.0), 0.0, sin(_drag_time * 1.15) * 0.03)
	_rescuer_root.position = Vector3(_spawn.x, _spawn.y, base_z + 3.45)

	if _dragged_rig != null:
		_dragged_rig.pose_dragged(_drag_time * 5.2 + 1.1, 0.35 + sin(_drag_time * 3.1) * 0.25)
	if _rescuer_rig != null:
		_rescuer_rig.pose_rescuer_drag(_drag_time * 5.2, 0.6)

	# Câmera baixa, quase no chão, acompanhando o arrasto.
	var target_pos := Vector3(_spawn.x + 4.15, _spawn.y + 0.86, base_z + 1.45)
	if not _camera_ready:
		_camera.global_position = target_pos
		_camera_ready = true
	else:
		_camera.global_position = _camera.global_position.lerp(target_pos, 1.0 - exp(-3.5 * delta))
	var look_target := Vector3(_spawn.x, _spawn.y + 0.48, base_z + 1.7)
	_camera.look_at(look_target, Vector3.UP)
	_camera.fov = lerpf(_camera.fov, 54.0, 1.0 - exp(-3.0 * delta))

	# Passos de quem arrasta.
	_step_left -= delta
	if _step_left <= 0.0:
		_step_left = 0.56
		if _sfx != null and not _sfx.playing:
			_sfx.play()


func _play_getup() -> void:
	_getup_root = Node3D.new()
	_getup_root.name = "IntroGetUp"
	_scene_root.add_child(_getup_root)
	_getup_root.position = _spawn + Vector3(0.0, 0.16, -0.9)
	_getup_root.rotation = Vector3(deg_to_rad(88.0), 0.0, 0.0)

	_getup_rig = HumanoidRig.new()
	_getup_root.add_child(_getup_rig)
	_getup_rig.set_weapon_visible(false)
	_getup_rig.pose_getup(0.0, 0.0)
	_getup_rig.snap()

	_camera.global_position = _spawn + Vector3(2.55, 0.52, 2.2)
	_camera.look_at(_spawn + Vector3(0.0, 0.3, 0.55), Vector3.UP)
	_camera.fov = 52.0
	_camera_ready = true

	await _fade_black(1.0, 0.0, 0.85)

	var t := 0.0
	var time := 0.0
	while t < 1.0:
		var delta := get_process_delta_time()
		time += delta
		t = minf(t + delta / GETUP_DURATION, 1.0)
		_apply_getup(t, time)
		await get_tree().process_frame
	_apply_getup(1.0, time)


func _apply_getup(t: float, time: float) -> void:
	if _getup_root == null or _getup_rig == null:
		return

	var stand := smoothstep(0.08, 0.9, t)
	_getup_root.rotation = Vector3(lerpf(deg_to_rad(88.0), 0.0, stand), 0.0, 0.0)
	_getup_root.position = _spawn + Vector3(0.0, lerpf(0.16, 0.0, stand), lerpf(-0.9, 0.0, smoothstep(0.0, 0.95, t)))
	_getup_rig.pose_getup(t, time)

	# A câmera começa baixa e perto do chão e termina exatamente no
	# enquadramento usado pela CameraDirector (3ª pessoa perto).
	var pos := _spawn + Vector3(2.55, 0.52, 2.2).lerp(Vector3(0.52, 1.84, 2.75), smoothstep(0.02, 0.94, t))
	var look := _spawn + Vector3(0.0, 0.3, 0.55).lerp(Vector3(0.52, 1.48, -5.25), smoothstep(0.12, 0.96, t))
	_camera.global_position = pos
	_camera.look_at(look, Vector3.UP)
	_camera.fov = lerpf(52.0, 70.0, smoothstep(0.0, 1.0, t))


func _finish() -> void:
	Global.cinematic_mode = false

	if _getup_root != null:
		_getup_root.queue_free()
		_getup_root = null
	if _camera != null:
		_camera.queue_free()
		_camera = null
	if _sfx != null:
		_sfx.queue_free()
		_sfx = null

	_player.global_position = _spawn
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(true)
	_player.set_process_unhandled_input(true)
	_player.rotation = Vector3.ZERO
	var pivot := _player.get_node_or_null("CameraPivot") as Node3D
	if pivot != null:
		pivot.rotation = Vector3.ZERO
	var holder := _player.get_node_or_null("CameraPivot/CameraHolder") as Node3D
	if holder != null:
		holder.rotation = Vector3.ZERO

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	CameraDirector.refresh()

	if _hud == null:
		_hud = get_tree().get_first_node_in_group("hud") as Control
	if _hud != null:
		_hud.visible = true
		if _hud.has_method("play_intro"):
			_hud.play_intro()

	_resume_spawners()
	_show_letterbox(false)
	_skip_hint.visible = false

	var tw := create_tween()
	tw.tween_interval(0.55)
	await tw.finished
	if _overlay != null:
		_overlay.visible = false
	queue_free()


# ------------------------------------------------------------------------ UI

func _build_ui() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "IntroOverlay"
	_overlay.layer = 80
	add_child(_overlay)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(root)

	_black = ColorRect.new()
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_black)

	_bar_top = _make_bar(root, true)
	_bar_bottom = _make_bar(root, false)
	_bar_top.modulate.a = 0.0
	_bar_bottom.modulate.a = 0.0

	_subtitle = Label.new()
	_subtitle.anchor_left = 0.5
	_subtitle.anchor_right = 0.5
	_subtitle.anchor_top = 1.0
	_subtitle.anchor_bottom = 1.0
	_subtitle.offset_left = -430.0
	_subtitle.offset_right = 430.0
	_subtitle.offset_top = -178.0
	_subtitle.offset_bottom = -110.0
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.modulate.a = 0.0
	_subtitle.visible_ratio = 0.0
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(_subtitle, 27, Color("f2f5f8"), 10)
	root.add_child(_subtitle)

	_skip_hint = Label.new()
	_skip_hint.anchor_left = 1.0
	_skip_hint.anchor_right = 1.0
	_skip_hint.anchor_top = 0.0
	_skip_hint.anchor_bottom = 0.0
	_skip_hint.offset_left = -310.0
	_skip_hint.offset_right = -46.0
	_skip_hint.offset_top = 116.0
	_skip_hint.offset_bottom = 146.0
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.text = "ESPAÇO  ›  PULAR CENA"
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(_skip_hint, 15, Color(0.72, 0.78, 0.85, 0.9), 6)
	root.add_child(_skip_hint)


func _make_bar(root: Control, top: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	if top:
		bar.anchor_top = 0.0
		bar.anchor_bottom = 0.0
		bar.offset_bottom = 92.0
	else:
		bar.anchor_top = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_top = -92.0
	bar.color = Color(0.0, 0.0, 0.0, 0.88)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	return bar


func _apply_font(label: Label, size: int, color: Color, outline: int = 0) -> void:
	var font := load(FONT_PATH)
	if font is Font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_constant_override("outline_size", outline)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))


func _show_letterbox(show_bars: bool) -> void:
	var target := 1.0 if show_bars else 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_bar_top, "modulate:a", target, 0.6)
	tw.tween_property(_bar_bottom, "modulate:a", target, 0.6)


func _show_subtitle(text: String, delay: float) -> void:
	_subtitle.text = text
	_subtitle.modulate.a = 0.0
	_subtitle.visible_ratio = 0.0
	var tw := _subtitle.create_tween()
	tw.tween_property(_subtitle, "modulate:a", 1.0, 0.25).set_delay(delay)
	tw.parallel().tween_property(_subtitle, "visible_ratio", 1.0, 1.0).set_delay(delay)


func _hide_subtitle() -> void:
	var tw := _subtitle.create_tween()
	tw.tween_property(_subtitle, "modulate:a", 0.0, 0.35)


func _fade_black(from: float, to: float, duration: float) -> void:
	_black.color.a = from
	var tw := create_tween()
	tw.tween_property(_black, "color:a", to, duration).set_trans(Tween.TRANS_SINE)
	await tw.finished


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		if _skip:
			_skip = false
			return
		elapsed += get_process_delta_time()


# ------------------------------------------------------------------- cenário

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "IntroCamera"
	_camera.fov = 54.0
	_camera.near = 0.05
	_camera.far = 900.0
	_scene_root.add_child(_camera)
	_camera.make_current()


func _build_bodies() -> void:
	_dragged_root = Node3D.new()
	_dragged_root.name = "IntroDraggedBody"
	_scene_root.add_child(_dragged_root)
	_dragged_rig = HumanoidRig.new()
	_dragged_root.add_child(_dragged_rig)
	_dragged_rig.set_weapon_visible(false)

	_rescuer_root = Node3D.new()
	_rescuer_root.name = "IntroRescuer"
	_scene_root.add_child(_rescuer_root)
	_rescuer_rig = HumanoidRig.new()
	_rescuer_root.add_child(_rescuer_rig)
	_rescuer_rig.set_weapon_visible(false)

	_sfx = AudioStreamPlayer3D.new()
	_sfx.stream = FOOTSTEP
	_sfx.volume_db = -18.0
	_sfx.pitch_scale = 0.78
	_sfx.unit_size = 6.0
	_sfx.max_distance = 24.0
	_sfx.position = Vector3(0.0, 0.1, 0.0)
	_rescuer_root.add_child(_sfx)


func _clear_drag() -> void:
	if _dragged_root != null:
		_dragged_root.queue_free()
		_dragged_root = null
	if _rescuer_root != null:
		_rescuer_root.queue_free()
		_rescuer_root = null
	_dragged_rig = null
	_rescuer_rig = null
	_sfx = null


func _pause_spawners() -> void:
	for spawner in _spawners():
		spawner.set_process(false)
		var timer := spawner.get_node_or_null("SpawnTimer") as Timer
		if timer != null:
			timer.paused = true


func _resume_spawners() -> void:
	for spawner in _spawners():
		spawner.set_process(true)
		var timer := spawner.get_node_or_null("SpawnTimer") as Timer
		if timer != null:
			timer.paused = false
			timer.start(5.0)


func _spawners() -> Array:
	var result: Array = []
	var enemies := _scene_root.get_node_or_null("Enemies")
	if enemies == null:
		return result
	for child in enemies.get_children():
		if child.get_node_or_null("SpawnTimer") != null:
			result.append(child)
	return result


func _unhandled_input(event: InputEvent) -> void:
	if not _drag_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_skip = true
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_skip = true
		get_viewport().set_input_as_handled()
