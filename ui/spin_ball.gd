extends Control
## Bola de carregamento: globo de arame girando, anel de progresso e órbita.
## Desenhada por código, então não depende de textura nem de cena 3D.

var _angle: float = 0.0
var _progress: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190, 190)
	queue_redraw()


func _process(delta: float) -> void:
	_angle = fmod(_angle + delta * (1.05 + _progress * 1.5), TAU)
	queue_redraw()


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.34
	if radius <= 2.0:
		return

	var accent := Color(1.0, 0.623, 0.11, 1.0)

	# Halo suave.
	for i in range(7):
		draw_circle(center, radius * (1.0 + 0.05 * float(i)), Color(1.0, 0.62, 0.11, 0.014))

	# Núcleo escuro para as linhas não sumirem no fundo.
	draw_circle(center, radius * 0.985, Color(0.032, 0.044, 0.058, 0.92))

	# Meridianos: círculos máximos girados no eixo Y.
	for i in range(10):
		var meridian := PI * float(i) / 10.0 + _angle
		var width := absf(cos(meridian))
		var alpha := 0.04 + 0.26 * width
		var points := PackedVector2Array()
		for j in range(49):
			var theta := TAU * float(j) / 48.0
			points.append(center + Vector2(
				sin(theta) * cos(meridian) * radius,
				cos(theta) * radius
			))
		draw_polyline(points, Color(0.72, 0.83, 0.95, alpha), 1.0, true)

	# Paralelos.
	for i in range(1, 7):
		var phi := -PI * 0.5 + PI * float(i) / 7.0
		var y := sin(phi) * radius
		var half := cos(phi) * radius
		draw_line(
			center + Vector2(-half, y),
			center + Vector2(half, y),
			Color(0.72, 0.83, 0.95, 0.07 + 0.12 * cos(phi)),
			1.0,
			true
		)

	# Contorno e brilho superior.
	draw_arc(center, radius, 0.0, TAU, 96, Color(1.0, 0.68, 0.28, 0.55), 1.5, true)
	draw_circle(center + Vector2(-radius * 0.34, -radius * 0.38), radius * 0.16, Color(1.0, 1.0, 1.0, 0.06))

	# Anel de progresso.
	draw_arc(center, radius * 1.2, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, 0.07), 2.0, true)
	if _progress > 0.001:
		draw_arc(
			center,
			radius * 1.2,
			-PI * 0.5,
			-PI * 0.5 + TAU * _progress,
			96,
			accent,
			2.5,
			true
		)

	# Órbita inclinada com um ponto girando.
	var orbit := PackedVector2Array()
	for j in range(65):
		var a := TAU * float(j) / 64.0
		orbit.append(center + Vector2(cos(a) * radius * 1.34, sin(a) * radius * 0.42).rotated(-0.32))
	draw_polyline(orbit, Color(1.0, 0.623, 0.11, 0.22), 1.0, true)
	var dot_angle := _angle * 0.7
	var dot := Vector2(cos(dot_angle) * radius * 1.34, sin(dot_angle) * radius * 0.42).rotated(-0.32)
	draw_circle(center + dot, 3.2, Color(1.0, 0.78, 0.4, 0.95))
