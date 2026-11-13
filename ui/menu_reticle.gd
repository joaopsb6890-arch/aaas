extends Control
## Mira tática desenhada atrás do menu. Gira devagar e não captura o mouse.

var _angle: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	_angle = fmod(_angle + delta * 0.16, TAU)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.44
	if radius < 20.0:
		return

	var accent := Color(1.0, 0.623, 0.11, 0.10)
	var faint := Color(0.78, 0.86, 0.95, 0.05)
	var strong := Color(1.0, 0.623, 0.11, 0.18)

	draw_arc(center, radius, 0.0, TAU, 128, faint, 1.0, true)
	draw_arc(center, radius * 0.78, 0.0, TAU, 96, faint, 1.0, true)
	draw_arc(center, radius * 0.55, 0.0, TAU, 96, faint, 1.0, true)

	# Arcos que giram.
	draw_arc(center, radius, _angle, _angle + 1.5, 48, accent, 2.0, true)
	draw_arc(center, radius, _angle + PI, _angle + PI + 0.8, 32, accent, 3.0, true)
	draw_arc(center, radius * 0.78, -_angle * 1.6, -_angle * 1.6 + 2.4, 40, strong, 2.0, true)

	# Marcações a cada 15 graus.
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		var inner := radius * (0.9 if i % 6 != 0 else 0.82)
		var outer := radius
		var color := accent if i % 6 == 0 else faint
		draw_line(
			center + Vector2(cos(angle), sin(angle)) * inner,
			center + Vector2(cos(angle), sin(angle)) * outer,
			color,
			2.0 if i % 6 == 0 else 1.0,
			true
		)

	# Cruz central, com um vão no meio.
	var gap := radius * 0.12
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + dir * gap, center + dir * radius * 0.55, faint, 1.0, true)
	draw_circle(center, 3.0, strong)
