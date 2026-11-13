extends Control
## Tela de carregamento.
##
## Carrega main.tscn em uma thread (ResourceLoader.load_threaded_request), então
## a UI continua animando enquanto o mundo é montado. Isso evita o travamento
## de trocar de cena direto do menu.

const UIKit = preload("res://ui/ui_kit.gd")
const GAME_SCENE := "res://main.tscn"
const MENU_SCENE := "res://ui/main_menu.tscn"
const MIN_LOAD_TIME := 1.35

@onready var _ball: Control = %Ball
@onready var _bar: ProgressBar = %Progress
@onready var _percent: Label = %Percent
@onready var _status: Label = %Status
@onready var _title: Label = %Title
@onready var _divider: ColorRect = %Divider
@onready var _brand: Label = %Brand
@onready var _footer: Label = %Footer
@onready var _fade: ColorRect = %Fade

var _progress: float = 0.0
var _target: float = 0.0
var _elapsed: float = 0.0
var _stage: String = ""
var _requested: bool = false
var _finished: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Global.player = null
	Global.in_vehicle = false
	Global.cinematic_mode = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color.a = 0.0
	_style()

	_bar.value = 0.0
	_percent.text = "0%"
	await get_tree().process_frame
	# Cenas com AnimationTree (inimigos) não montam no carregador em thread;
	# deixá-las prontas em cache antes evita que o carregamento falhe no meio.
	ResourceLoader.load("res://enemies/undead.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	ResourceLoader.load("res://player/player.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REUSE)

	# Sub-threads desligados: com vários arquivos de cena encadeados o
	# carregador em sub-thread falha ao montar os recursos.
	_requested = ResourceLoader.load_threaded_request(GAME_SCENE, "PackedScene", false) == OK
	if not _requested:
		_fail("NÃO FOI POSSÍVEL ABRIR O SETOR")


func _style() -> void:
	UIKit.apply_font(_brand, 13, UIKit.MUTED)
	UIKit.apply_font(_title, 46, UIKit.TEXT)
	UIKit.apply_font(_status, 15, UIKit.MUTED)
	UIKit.apply_font(_percent, 13, UIKit.ACCENT)
	UIKit.apply_font(_footer, 12, Color(0.55, 0.61, 0.68, 0.9))
	_divider.color = UIKit.ACCENT

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.07, 0.086, 0.105, 0.9)
	background.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIKit.ACCENT
	fill.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("background", background)
	_bar.add_theme_stylebox_override("fill", fill)


func _process(delta: float) -> void:
	if _finished or not _requested:
		return

	_elapsed += delta
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_target = 1.0
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():
				_target = clampf(float(progress[0]), 0.0, 1.0)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail("FALHA AO CARREGAR O SETOR")
			return

	_progress = lerpf(_progress, _target, 1.0 - exp(-5.0 * delta))
	_bar.value = _progress * 100.0
	_percent.text = "%d%%" % int(round(_progress * 100.0))
	if _ball.has_method("set_progress"):
		_ball.set_progress(_progress)

	var stage := _stage_text(_target)
	if stage != _stage:
		_stage = stage
		_status.text = stage

	if _target >= 0.999 and _elapsed >= MIN_LOAD_TIME:
		_finish()


func _stage_text(value: float) -> String:
	if value < 0.2:
		return "LENDO O SETOR"
	if value < 0.5:
		return "CARREGANDO GEOMETRIA"
	if value < 0.78:
		return "IMPORTANDO TEXTURAS"
	if value < 0.99:
		return "POSICIONANDO INIMIGOS"
	return "AJUSTANDO A CÂMERA"


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_status.text = "SETOR PRONTO"
	_percent.text = "100%"
	_bar.value = 100.0
	if _ball.has_method("set_progress"):
		_ball.set_progress(1.0)

	var packed := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	if packed == null:
		_fail("RECURSO INVÁLIDO")
		return

	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	await tw.finished
	get_tree().change_scene_to_packed(packed)


func _fail(message: String) -> void:
	_finished = true
	_status.text = message
	_status.add_theme_color_override("font_color", Color("e5484d"))
	_percent.text = "0%"
	if _ball.has_method("set_progress"):
		_ball.set_progress(0.0)

	await get_tree().create_timer(2.2).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file(MENU_SCENE)

