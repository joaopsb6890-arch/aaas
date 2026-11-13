extends CanvasLayer
## Controlos táteis feitos 100% por script (sem cenas).
## - Joystick analógico dinâmico (esquerda). Empurra até ao anel exterior para CORRER.
## - Olhar por arrasto (direita) com suavização e aceleração.
## - Botões: fogo (direita e esquerda), mirar, saltar, recarregar, usar, trocar arma, travão.
## - Toca no nome da arma (em baixo ao centro) para trocar de arma.
## - Engrenagem (topo): menu com sensibilidade, auxílio de mira e tamanho dos botões.

@export var base_look_sensitivity: float = 0.0036   ## radianos por pixel (viewport virtual 1080p)
@export var look_accel: float = 0.7                 ## 0 = linear; mais = flicks rápidos giram mais
@export var look_smoothing_rate: float = 45.0       ## maior = menos suavização (mais direto)
@export var vertical_factor: float = 0.85           ## sensibilidade vertical relativa
@export var aim_sensitivity_multiplier: float = 0.6
@export var joystick_radius: float = 130.0
@export var joystick_deadzone: float = 0.12
@export var control_opacity: float = 0.6
@export var haptics: bool = true

const FOOT := 1
const VEHICLE := 2
const BOTH := 3

const COL_FIRE := Color(1.0, 0.36, 0.30)
const COL_WHITE := Color(1, 1, 1)
const COL_ACTIVE := Color(0.45, 0.85, 1.0)
const SETTINGS_PATH := "user://mobile_settings.cfg"

# Definições (editáveis no menu e guardadas em disco)
var sens_mult: float = 1.0
var ui_scale: float = 1.0

var _buttons: Array[Dictionary] = []
var _canvas: Control
var _hold_counts: Dictionary = {}

# Joystick
var _stick_touch: int = -1
var _stick_origin: Vector2
var _stick_pos: Vector2
var _stick_vec: Vector2 = Vector2.ZERO
var _sprint_auto: bool = false
var _sprint_sent: bool = false

# Olhar
var _look_touch: int = -1
var _look_raw: Vector2 = Vector2.ZERO
var _look_pending: Vector2 = Vector2.ZERO

var _last_context: int = FOOT
var _aiming: bool = false
var _dead: bool = false
var _dirty: bool = true
var _insets: Vector4 = Vector4.ZERO
var _font: Font

# Menu de opções
var _settings_open: bool = false
var _slider_touch: int = -1
var _slider_idx: int = -1
const SLIDERS := [
	{"label": "Sensibilidade", "min": 0.4, "max": 2.0},
	{"label": "Auxílio de mira", "min": 0.0, "max": 1.0},
	{"label": "Tamanho dos botões", "min": 0.8, "max": 1.4},
]


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Global.is_mobile:
		visible = false
		set_process(false)
		set_process_input(false)
		return

	_font = ThemeDB.fallback_font
	_load_settings()
	GameSettings.changed.connect(_load_settings)
	_build_buttons()
	Global.player_dead.connect(_on_player_dead)
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_canvas_draw)
	add_child(_canvas)


func _on_resized() -> void:
	_insets = Global.get_safe_insets()
	_dirty = true


func _on_player_dead() -> void:
	_dead = true
	_release_all()
	_dirty = true


# ---------------------------------------------------------------- DEFINIÇÕES

func _load_settings() -> void:
	sens_mult = GameSettings.look_sens
	ui_scale = GameSettings.ui_scale
	haptics = GameSettings.haptics
	_dirty = true


func _save_settings() -> void:
	pass


func _slider_get(i: int) -> float:
	match i:
		0: return sens_mult
		1: return Global.aim_assist_strength
		_: return ui_scale


func _slider_set(i: int, v: float) -> void:
	match i:
		0: sens_mult = v
		1: Global.aim_assist_strength = v
		_: ui_scale = v
	_dirty = true


func _panel_rect() -> Rect2:
	var s := get_viewport().get_visible_rect().size
	return Rect2(s * 0.5 - Vector2(450, 290), Vector2(900, 580))


func _slider_track(i: int) -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + 60.0, p.position.y + 170.0 + i * 130.0, p.size.x - 120.0, 14.0)


func _close_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + p.size.x * 0.5 - 130.0, p.end.y - 90.0, 260.0, 64.0)


func _open_settings() -> void:
	_release_all()
	_settings_open = true
	get_tree().paused = true
	_dirty = true


func _close_settings() -> void:
	_settings_open = false
	_slider_touch = -1
	_slider_idx = -1
	get_tree().paused = false
	_save_settings()
	_dirty = true


# ---------------------------------------------------------------- BOTÕES

func _build_buttons() -> void:
	# anchor: "br" canto inf. direito, "bl" inf. esquerdo, "tc" topo centro, "bc" inf. centro
	_buttons = [
		{"id": "fire",     "action": "fire",               "label": "",       "mode": "hold", "ctx": FOOT,    "r": 95.0, "anchor": "br", "off": Vector2(-185, -215)},
		{"id": "brake",    "action": "brake",              "label": "TRAVÃO", "mode": "hold", "ctx": VEHICLE, "r": 95.0, "anchor": "br", "off": Vector2(-185, -215)},
		{"id": "aim",      "action": "aim_mode",           "label": "",       "mode": "toggle", "ctx": FOOT,  "r": 64.0, "anchor": "br", "off": Vector2(-355, -250)},
		{"id": "jump",     "action": "jump",               "label": "",       "mode": "hold", "ctx": FOOT,    "r": 64.0, "anchor": "br", "off": Vector2(-110, -405)},
		{"id": "reload",   "action": "reload",             "label": "",       "mode": "tap",  "ctx": FOOT,    "r": 52.0, "anchor": "br", "off": Vector2(-300, -420)},
		{"id": "use",      "action": "activate",           "label": "USAR",   "mode": "tap",  "ctx": BOTH,    "r": 52.0, "anchor": "br", "off": Vector2(-205, -545)},
		{"id": "fire2",    "action": "fire",               "label": "",       "mode": "hold", "ctx": FOOT,    "r": 62.0, "anchor": "bl", "off": Vector2(150, -520)},
		{"id": "prev",     "action": "weapon_change_prev", "label": "",       "mode": "tap",  "ctx": FOOT,    "r": 44.0, "anchor": "tc", "off": Vector2(-125, 80)},
		{"id": "next",     "action": "weapon_change_next", "label": "",       "mode": "tap",  "ctx": FOOT,    "r": 44.0, "anchor": "tc", "off": Vector2(125, 80)},
		{"id": "view",     "action": "camera_view",        "label": "",       "mode": "tap",  "ctx": BOTH,    "r": 44.0, "anchor": "tc", "off": Vector2(250, 80)},
		{"id": "settings", "action": "",                   "label": "",       "mode": "tap",  "ctx": BOTH,    "r": 36.0, "anchor": "tc", "off": Vector2(0, 80)},
		# zona invisível: tocar no nome da arma troca para a seguinte
		{"id": "swap",     "action": "weapon_change_next", "label": "",       "mode": "tap",  "ctx": FOOT,    "r": 70.0, "anchor": "bc", "off": Vector2(0, -85), "hidden": true},
	]
	for b in _buttons:
		b["touch"] = -1
		b["down"] = false
		b["hidden"] = b.get("hidden", false)


func _button_center(b: Dictionary) -> Vector2:
	var s := get_viewport().get_visible_rect().size
	var o: Vector2 = b["off"] * ui_scale
	if b["anchor"] == "tc" or b["anchor"] == "bc":
		o = b["off"]  # centro: não escala o afastamento lateral/vertical
	match b["anchor"]:
		"br": return Vector2(s.x - _insets.z, s.y - _insets.w) + o
		"bl": return Vector2(_insets.x, s.y - _insets.w) + o
		"tc": return Vector2(s.x * 0.5, _insets.y) + o
		"bc": return Vector2(s.x * 0.5, s.y - _insets.w) + o
	return o


func _button_radius(b: Dictionary) -> float:
	if b["anchor"] == "tc":
		return float(b["r"])
	return float(b["r"]) * ui_scale


func _button_active(b: Dictionary) -> bool:
	return (int(b["ctx"]) & _context()) != 0


func _context() -> int:
	return VEHICLE if Global.in_vehicle else FOOT


func _stick_r() -> float:
	return joystick_radius * ui_scale


# ---------------------------------------------------------------- INPUT

func _input(event: InputEvent) -> void:
	if Global.menu_open or not Global.game_active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position, event.relative)


func _touch_down(index: int, pos: Vector2) -> void:
	if _dead:
		return

	if _settings_open:
		_settings_touch_down(index, pos)
		return

	# 1) botões têm prioridade
	for b in _buttons:
		if not _button_active(b) or b["touch"] != -1:
			continue
		if pos.distance_to(_button_center(b)) <= _button_radius(b):
			b["touch"] = index
			_press_button(b)
			# arrastar o dedo no botão de fogo da direita também move a câmara
			if b["id"] == "fire" and _look_touch == -1:
				_look_touch = index
			_dirty = true
			return

	var size := get_viewport().get_visible_rect().size
	# 2) zona esquerda = joystick dinâmico
	if pos.x < size.x * 0.4 and _stick_touch == -1:
		var r := _stick_r()
		_stick_touch = index
		_stick_origin = Vector2(
			clampf(pos.x, r + 20.0, size.x * 0.4),
			clampf(pos.y, size.y * 0.35, size.y - r - 20.0))
		_stick_pos = pos
		_update_stick()
		_dirty = true
		return

	# 3) resto = olhar
	if pos.x >= size.x * 0.4 and _look_touch == -1:
		_look_touch = index


func _touch_up(index: int) -> void:
	if _settings_open:
		if index == _slider_touch:
			_slider_touch = -1
			_slider_idx = -1
			_save_settings()
		return
	for b in _buttons:
		if b["touch"] == index:
			b["touch"] = -1
			_release_button(b)
	if index == _stick_touch:
		_stick_touch = -1
		_stick_vec = Vector2.ZERO
		_sprint_auto = false
		_apply_move()
		_update_sprint()
	if index == _look_touch:
		_look_touch = -1
	_dirty = true


func _touch_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if _settings_open:
		if index == _slider_touch and _slider_idx >= 0:
			_slider_from_x(_slider_idx, pos.x)
		return
	if index == _stick_touch:
		_stick_pos = pos
		_update_stick()
		_dirty = true
	elif index == _look_touch:
		_look_raw += relative   # processado em _process (suavização + aceleração)


func _settings_touch_down(index: int, pos: Vector2) -> void:
	if _close_rect().has_point(pos) or not _panel_rect().has_point(pos):
		_close_settings()
		return
	for i in SLIDERS.size():
		var tr := _slider_track(i).grow(34.0)
		if tr.has_point(pos):
			_slider_touch = index
			_slider_idx = i
			_slider_from_x(i, pos.x)
			return


func _slider_from_x(i: int, x: float) -> void:
	var tr := _slider_track(i)
	var t := clampf((x - tr.position.x) / tr.size.x, 0.0, 1.0)
	var v := lerpf(float(SLIDERS[i]["min"]), float(SLIDERS[i]["max"]), t)
	if i == 1 and v < 0.04:
		v = 0.0
	_slider_set(i, v)


# ---------------------------------------------------------------- OLHAR

func _process_look(delta: float) -> void:
	if _look_raw != Vector2.ZERO:
		var raw := _look_raw.limit_length(260.0)   # evita saltos com picos de lag
		_look_raw = Vector2.ZERO
		var speed := raw.length() / maxf(delta, 0.0001)            # px/s virtuais
		var gain := 1.0 + look_accel * clampf(speed / 1600.0, 0.0, 1.0)
		var sens := base_look_sensitivity * sens_mult * gain
		if _aiming:
			sens *= aim_sensitivity_multiplier
		_look_pending += Vector2(raw.x * sens, raw.y * sens * vertical_factor)
	if _look_pending == Vector2.ZERO:
		return
	# Liberta o movimento ao longo de alguns frames: câmara fluida e sem tremer
	var k := 1.0 - exp(-look_smoothing_rate * delta)
	var step := _look_pending * k
	if step.length() < 0.00005:
		step = _look_pending
	_look_pending -= step
	Global.look_input.emit(step.limit_length(0.4))


# ---------------------------------------------------------------- JOYSTICK + CORRER

func _update_stick() -> void:
	var r := _stick_r()
	var offset := _stick_pos - _stick_origin
	var dist := offset.length()
	# o centro só segue o dedo bem para lá do anel (permite empurrar até ao anel p/ correr)
	if dist > r * 1.5:
		_stick_origin = _stick_pos - offset.normalized() * r * 1.5
		offset = _stick_pos - _stick_origin
		dist = offset.length()

	# Movimento: velocidade máxima aos 80 % do anel
	var v := (offset / (r * 0.8)).limit_length(1.0)
	var mag := v.length()
	if mag < joystick_deadzone:
		v = Vector2.ZERO
	else:
		v = v.normalized() * ((mag - joystick_deadzone) / (1.0 - joystick_deadzone))
	_stick_vec = v

	# Correr: empurrar até ao anel exterior, para a frente. Histerese evita tremer.
	var raw := offset / r
	if not _sprint_auto:
		if dist >= r * 0.98 and raw.y < -0.3:
			_sprint_auto = true
	else:
		if dist < r * 0.85 or raw.y > -0.15:
			_sprint_auto = false
	_apply_move()
	_update_sprint()


func _update_sprint() -> void:
	var want := _sprint_auto and _context() == FOOT and not _dead
	if want != _sprint_sent:
		_sprint_sent = want
		_send_action("sprint", want)
		_dirty = true


func _apply_move() -> void:
	_set_axis("forward", maxf(-_stick_vec.y, 0.0))
	_set_axis("backward", maxf(_stick_vec.y, 0.0))
	_set_axis("left", maxf(-_stick_vec.x, 0.0))
	_set_axis("right", maxf(_stick_vec.x, 0.0))


func _set_axis(action: StringName, strength: float) -> void:
	if strength > 0.001:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


# ---------------------------------------------------------------- AÇÕES

func _press_button(b: Dictionary) -> void:
	b["down"] = true
	if haptics:
		Input.vibrate_handheld(15)
	if b["id"] == "settings":
		b["down"] = false
		b["touch"] = -1
		Global.pause_requested.emit()
		return
	match b["mode"]:
		"hold":
			_hold(b["action"], true)
		"tap":
			_send_action(b["action"], true)
			# solta pouco depois para gerar press+release limpos
			get_tree().create_timer(0.06).timeout.connect(func():
				_send_action(b["action"], false)
				b["down"] = false
				_dirty = true)
		"toggle":
			if b["id"] == "aim":
				_set_aim(not _aiming)


func _release_button(b: Dictionary) -> void:
	if b["mode"] == "hold" and b["down"]:
		b["down"] = false
		_hold(b["action"], false)
	elif b["mode"] == "toggle":
		b["down"] = false


## Ações mantidas por mais de um botão (fogo esq./dir.): só solta quando todos largam.
func _hold(action: StringName, down: bool) -> void:
	var n: int = _hold_counts.get(action, 0)
	if down:
		if n == 0:
			_send_action(action, true)
		_hold_counts[action] = n + 1
	else:
		if n <= 0:
			return
		n -= 1
		_hold_counts[action] = n
		if n == 0:
			_send_action(action, false)


func _set_aim(on: bool) -> void:
	if on == _aiming:
		return
	_aiming = on
	_send_action("aim_mode", on)
	_dirty = true


func _send_action(action: StringName, pressed: bool) -> void:
	if action == &"":
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _release_all() -> void:
	for action in _hold_counts.keys():
		if _hold_counts[action] > 0:
			_send_action(action, false)
	_hold_counts.clear()
	for b in _buttons:
		b["down"] = false
		b["touch"] = -1
	_set_aim(false)
	_sprint_auto = false
	_update_sprint()
	_stick_touch = -1
	_stick_vec = Vector2.ZERO
	_look_touch = -1
	_look_raw = Vector2.ZERO
	_look_pending = Vector2.ZERO
	_apply_move()
	_dirty = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		if Global.is_mobile and _buttons.size() > 0:
			_release_all()


# ---------------------------------------------------------------- LOOP / DESENHO

func _process(delta: float) -> void:
	var show_ui := Global.game_active and not Global.menu_open
	if _canvas and _canvas.visible != show_ui:
		_canvas.visible = show_ui
		if not show_ui:
			_release_all()
	if not show_ui:
		return
	var ctx := _context()
	if ctx != _last_context:
		_last_context = ctx
		# ao mudar de a pé <-> veículo, larga tudo o que deixou de existir
		for b in _buttons:
			if not _button_active(b) and (b["down"] or b["touch"] != -1):
				if b["mode"] == "hold" and b["down"]:
					_hold(b["action"], false)
				b["down"] = false
				b["touch"] = -1
		if ctx == VEHICLE:
			_set_aim(false)
		_update_sprint()
		_dirty = true
	if not _settings_open and not _dead:
		_process_look(delta)
	# só redesenha quando algo mudou (poupa CPU/bateria)
	if _dirty and _canvas:
		_dirty = false
		_canvas.queue_redraw()


func _on_canvas_draw() -> void:
	if _dead:
		return
	var a := control_opacity
	var r := _stick_r()

	# joystick
	var base_pos := _stick_origin if _stick_touch != -1 else _default_stick_pos()
	var ring_col := COL_ACTIVE if _sprint_sent else COL_WHITE
	_canvas.draw_circle(base_pos, r, Color(1, 1, 1, a * 0.12))
	_canvas.draw_arc(base_pos, r * 0.8, 0.0, TAU, 48, Color(1, 1, 1, a * 0.25), 2.0, true)   # alcance de andar
	_canvas.draw_arc(base_pos, r, 0.0, TAU, 56, Color(ring_col.r, ring_col.g, ring_col.b, a * 0.95),
		5.0 if _sprint_sent else 3.0, true)                                                  # anel de correr
	_draw_chevrons(base_pos + Vector2(0, -r * 1.0), r * 0.16, Color(ring_col.r, ring_col.g, ring_col.b, a))
	var knob_pos := base_pos
	if _stick_touch != -1:
		knob_pos = base_pos + (_stick_pos - _stick_origin).limit_length(r)
	_canvas.draw_circle(knob_pos, r * 0.36, Color(ring_col.r, ring_col.g, ring_col.b, a * (0.75 if _stick_touch != -1 else 0.45)))
	_canvas.draw_arc(knob_pos, r * 0.36, 0.0, TAU, 32, Color(1, 1, 1, a), 2.0, true)

	# botões
	for b in _buttons:
		if b["hidden"] or not _button_active(b):
			continue
		var c := _button_center(b)
		var br := _button_radius(b)
		var on: bool = b["down"]
		var tint := COL_FIRE if (b["id"] == "fire" or b["id"] == "fire2" or b["id"] == "brake") else COL_WHITE
		if b["id"] == "aim":
			on = _aiming
		if on:
			br *= 0.94
			if b["mode"] == "toggle":
				tint = COL_ACTIVE
		_canvas.draw_circle(c, br, Color(tint.r, tint.g, tint.b, a * (0.5 if on else 0.16)))
		_canvas.draw_arc(c, br, 0.0, TAU, 44, Color(tint.r, tint.g, tint.b, a + 0.25), 3.5 if on else 3.0, true)
		_draw_icon(String(b["id"]), c, br, Color(1, 1, 1, minf(a + 0.35, 1.0)), String(b["label"]))

	if _settings_open:
		_draw_settings()


func _draw_chevrons(c: Vector2, s: float, col: Color) -> void:
	# duas setas ">" viradas para cima, no topo do anel: "empurra até aqui para correr"
	for k in [0.0, 1.0]:
		var y: float = -s * float(k) * 1.1
		_canvas.draw_polyline(PackedVector2Array([
			c + Vector2(-s, y + s * 0.5), c + Vector2(0, y - s * 0.5), c + Vector2(s, y + s * 0.5)]), col, 3.0, true)


func _draw_icon(id: String, c: Vector2, r: float, col: Color, label: String) -> void:
	var w := maxf(r * 0.07, 3.0)
	match id:
		"fire", "fire2":  # mira
			_canvas.draw_arc(c, r * 0.36, 0.0, TAU, 28, col, w, true)
			_canvas.draw_circle(c, r * 0.08, col)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				_canvas.draw_line(c + d * r * 0.5, c + d * r * 0.72, col, w, true)
		"aim":  # luneta
			_canvas.draw_arc(c, r * 0.5, 0.0, TAU, 28, col, w, true)
			_canvas.draw_line(c + Vector2(-r * 0.5, 0), c + Vector2(r * 0.5, 0), col, w * 0.6, true)
			_canvas.draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.5), col, w * 0.6, true)
		"jump":  # seta dupla para cima
			for k in [-0.12, 0.28]:
				_canvas.draw_polyline(PackedVector2Array([
					c + Vector2(-r * 0.42, r * (k + 0.2)), c + Vector2(0, r * (k - 0.2)),
					c + Vector2(r * 0.42, r * (k + 0.2))]), col, w, true)
		"reload":  # seta circular
			_canvas.draw_arc(c, r * 0.42, deg_to_rad(-60), deg_to_rad(230), 24, col, w, true)
			var tip := c + Vector2.from_angle(deg_to_rad(-60)) * r * 0.42
			_canvas.draw_polyline(PackedVector2Array([
				tip + Vector2(-r * 0.2, -r * 0.02), tip, tip + Vector2(-r * 0.02, r * 0.22)]), col, w, true)
		"prev":
			_canvas.draw_polyline(PackedVector2Array([
				c + Vector2(r * 0.18, -r * 0.4), c + Vector2(-r * 0.2, 0), c + Vector2(r * 0.18, r * 0.4)]), col, w, true)
		"next":
			_canvas.draw_polyline(PackedVector2Array([
				c + Vector2(-r * 0.18, -r * 0.4), c + Vector2(r * 0.2, 0), c + Vector2(-r * 0.18, r * 0.4)]), col, w, true)
		"settings":  # pausa
			_canvas.draw_line(c + Vector2(-r * 0.2, -r * 0.35), c + Vector2(-r * 0.2, r * 0.35), col, w * 1.6, true)
			_canvas.draw_line(c + Vector2(r * 0.2, -r * 0.35), c + Vector2(r * 0.2, r * 0.35), col, w * 1.6, true)
		"view":  # câmara
			_canvas.draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.28), Vector2(r * 0.9, r * 0.56)), col, false, w)
			_canvas.draw_arc(c, r * 0.17, 0.0, TAU, 16, col, w, true)
		_:
			if label != "":
				var fs := int(r * 0.34)
				var ts := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
				_canvas.draw_string(_font, c + Vector2(-ts.x * 0.5, ts.y * 0.3), label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_settings() -> void:
	var s := get_viewport().get_visible_rect().size
	_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55))
	var p := _panel_rect()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.draw(_canvas.get_canvas_item(), p)
	_draw_text("OPÇÕES", Vector2(p.position.x + p.size.x * 0.5, p.position.y + 70.0), 44, Color.WHITE, true)

	for i in SLIDERS.size():
		var tr := _slider_track(i)
		var v := _slider_get(i)
		var t := inverse_lerp(float(SLIDERS[i]["min"]), float(SLIDERS[i]["max"]), v)
		_draw_text(String(SLIDERS[i]["label"]), Vector2(tr.position.x, tr.position.y - 34.0), 30, Color(1, 1, 1, 0.9), false)
		var val_txt := "%.2fx" % v
		if i == 1:
			val_txt = "Desligado" if v < 0.04 else "%d%%" % int(round(v * 100.0))
		elif i == 2:
			val_txt = "%d%%" % int(round(v * 100.0))
		_draw_text(val_txt, Vector2(tr.end.x, tr.position.y - 34.0), 30, COL_ACTIVE, false, true)
		_canvas.draw_rect(tr, Color(1, 1, 1, 0.22))
		_canvas.draw_rect(Rect2(tr.position, Vector2(tr.size.x * t, tr.size.y)), COL_ACTIVE)
		_canvas.draw_circle(tr.position + Vector2(tr.size.x * t, tr.size.y * 0.5), 26.0, Color.WHITE)

	var cr := _close_rect()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(1, 1, 1, 0.16)
	bsb.set_corner_radius_all(32)
	bsb.set_border_width_all(2)
	bsb.border_color = Color(1, 1, 1, 0.6)
	bsb.draw(_canvas.get_canvas_item(), cr)
	_draw_text("FECHAR", cr.get_center() + Vector2(0, 2), 32, Color.WHITE, true)


func _draw_text(txt: String, pos: Vector2, fs: int, col: Color, center: bool, right: bool = false) -> void:
	var ts := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var x := pos.x
	if center:
		x -= ts.x * 0.5
	elif right:
		x -= ts.x
	_canvas.draw_string(_font, Vector2(x, pos.y + (ts.y * 0.3 if center else 0.0)), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _default_stick_pos() -> Vector2:
	var s := get_viewport().get_visible_rect().size
	var r := _stick_r()
	return Vector2(r + 110.0 + _insets.x, s.y - r - 90.0 - _insets.w)
