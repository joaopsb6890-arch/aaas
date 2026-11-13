extends Node
## Definições persistentes (volume, FOV, sensibilidade, qualidade gráfica...).
## Autoload "GameSettings". Os menus mexem nas variáveis e chamam commit().

signal changed

const PATH := "user://settings.cfg"
const QUALITY_NAMES: Array[String] = ["BAIXA", "MÉDIA", "ALTA"]
## Escala de resolução 3D no telemóvel por nível de qualidade.
const MOBILE_SCALE: Array[float] = [0.6, 0.75, 1.0]

var master_volume: float = 0.8
var fov: float = 75.0
var look_sens: float = 1.0
var aim_assist: float = 0.6
var ui_scale: float = 1.0
var haptics: bool = true
var quality: int = 1
var show_fps: bool = false
var fullscreen: bool = false

var _fps_layer: CanvasLayer
var _fps_label: Label
var _fps_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	quality = 1 if Global.is_mobile else 2
	aim_assist = Global.aim_assist_strength
	_load()
	_build_fps_overlay()
	apply_all()


func commit() -> void:
	_save()
	apply_all()
	changed.emit()


func apply_all() -> void:
	Global.aim_assist_strength = aim_assist
	_apply_audio()
	_apply_window()
	apply_graphics()
	if _fps_layer:
		_fps_layer.visible = show_fps


func _apply_audio() -> void:
	var v := clampf(master_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(0, v <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))


func _apply_window() -> void:
	if Global.is_mobile or OS.has_feature("web"):
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


## Definições ao nível da janela (resolução 3D, anti-serrilhado).
func apply_graphics() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	vp.use_debanding = false
	if Global.is_mobile:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = MOBILE_SCALE[clampi(quality, 0, 2)]
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(quality, 0, 2)]


## Luzes e ambiente de uma cena (chamar no _ready da cena de jogo / menu).
func apply_to_scene(scene: Node) -> void:
	if scene == null:
		return
	for n in scene.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		if env:
			env.glow_enabled = (not Global.is_mobile) and quality >= 2
			env.adjustment_enabled = false
	for n in scene.find_children("*", "DirectionalLight3D", true, false):
		var l := n as DirectionalLight3D
		if quality <= 0 and Global.is_mobile:
			l.shadow_enabled = false
			continue
		l.shadow_enabled = true
		if Global.is_mobile:
			l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			l.directional_shadow_max_distance = 50.0 if quality <= 1 else 80.0
		else:
			l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			l.directional_shadow_max_distance = [60.0, 100.0, 160.0][clampi(quality, 0, 2)]
	# luzes omni com sombra são muito caras (sobretudo no telemóvel)
	for n in scene.find_children("*", "OmniLight3D", true, false):
		(n as OmniLight3D).shadow_enabled = (not Global.is_mobile) and quality >= 2


# ---------------------------------------------------------------- DISCO

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	fov = clampf(float(cfg.get_value("game", "fov", fov)), 60.0, 100.0)
	look_sens = clampf(float(cfg.get_value("game", "sens", look_sens)), 0.4, 2.0)
	aim_assist = clampf(float(cfg.get_value("game", "assist", aim_assist)), 0.0, 1.0)
	ui_scale = clampf(float(cfg.get_value("game", "ui_scale", ui_scale)), 0.8, 1.4)
	haptics = bool(cfg.get_value("game", "haptics", haptics))
	quality = clampi(int(cfg.get_value("video", "quality", quality)), 0, 2)
	show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("game", "fov", fov)
	cfg.set_value("game", "sens", look_sens)
	cfg.set_value("game", "assist", aim_assist)
	cfg.set_value("game", "ui_scale", ui_scale)
	cfg.set_value("game", "haptics", haptics)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)


# ---------------------------------------------------------------- FPS

func _build_fps_overlay() -> void:
	_fps_layer = CanvasLayer.new()
	_fps_layer.layer = 128
	add_child(_fps_layer)
	_fps_label = Label.new()
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_font_size_override("font_size", 20)
	_fps_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_fps_label.add_theme_constant_override("outline_size", 5)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_layer.add_child(_fps_label)
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -220.0
	_fps_label.offset_right = -24.0
	_fps_label.offset_top = 84.0
	_fps_layer.visible = show_fps


func _process(delta: float) -> void:
	if not show_fps:
		return
	_fps_t -= delta
	if _fps_t <= 0.0:
		_fps_t = 0.25
		_fps_label.text = "%d FPS" % int(Engine.get_frames_per_second())
