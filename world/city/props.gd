class_name CityProps
extends RefCounted
## Pequenos objetos urbanos (carros, semáforos, bancos...) como malhas de cor por vértice.

static func car() -> MeshBuilder:
	var b := MeshBuilder.new()
	var body := Color(1, 1, 1)             # tingido por instância
	var dark := Color(0.06, 0.06, 0.07)
	b.add_box(Vector3(0, 0.62, 0), Vector3(1.9, 0.7, 4.4), body)
	b.add_box(Vector3(0, 1.22, -0.2), Vector3(1.75, 0.55, 2.3), Color(0.12, 0.17, 0.24))
	b.add_box(Vector3(0, 1.52, -0.2), Vector3(1.7, 0.1, 2.2), body)
	b.add_box(Vector3(0, 0.92, 1.4), Vector3(1.88, 0.08, 1.4), body)
	for sx in [-0.95, 0.95]:
		for sz in [-1.4, 1.4]:
			b.add_box(Vector3(sx, 0.36, sz), Vector3(0.28, 0.72, 0.72), dark)
	b.add_box(Vector3(-0.6, 0.7, 2.21), Vector3(0.45, 0.2, 0.05), Color(1.0, 0.95, 0.75))
	b.add_box(Vector3(0.6, 0.7, 2.21), Vector3(0.45, 0.2, 0.05), Color(1.0, 0.95, 0.75))
	b.add_box(Vector3(-0.6, 0.7, -2.21), Vector3(0.45, 0.2, 0.05), Color(0.8, 0.1, 0.1))
	b.add_box(Vector3(0.6, 0.7, -2.21), Vector3(0.45, 0.2, 0.05), Color(0.8, 0.1, 0.1))
	return b


static func traffic_light() -> MeshBuilder:
	var b := MeshBuilder.new()
	var metal := Color(0.18, 0.2, 0.22)
	b.add_cylinder(Vector3.ZERO, 0.1, 5.2, 6, metal)
	b.add_box(Vector3(-1.2, 5.0, 0), Vector3(2.5, 0.12, 0.12), metal)
	b.add_box(Vector3(-2.2, 4.55, 0), Vector3(0.38, 1.0, 0.32), Color(0.08, 0.08, 0.09))
	b.add_box(Vector3(-2.2, 4.9, 0.17), Vector3(0.22, 0.22, 0.04), Color(0.9, 0.15, 0.1))
	b.add_box(Vector3(-2.2, 4.55, 0.17), Vector3(0.22, 0.22, 0.04), Color(0.9, 0.7, 0.1))
	b.add_box(Vector3(-2.2, 4.2, 0.17), Vector3(0.22, 0.22, 0.04), Color(0.15, 0.8, 0.3))
	return b


static func bench() -> MeshBuilder:
	var b := MeshBuilder.new()
	var wood := Color(0.5, 0.34, 0.2)
	var metal := Color(0.2, 0.2, 0.22)
	b.add_box(Vector3(0, 0.5, 0), Vector3(1.8, 0.08, 0.5), wood)
	b.add_box(Vector3(0, 0.85, -0.22), Vector3(1.8, 0.4, 0.07), wood)
	b.add_box(Vector3(-0.8, 0.25, 0), Vector3(0.08, 0.5, 0.45), metal)
	b.add_box(Vector3(0.8, 0.25, 0), Vector3(0.08, 0.5, 0.45), metal)
	return b


static func hydrant() -> MeshBuilder:
	var b := MeshBuilder.new()
	b.add_cylinder(Vector3.ZERO, 0.17, 0.7, 7, Color(0.8, 0.12, 0.1))
	b.add_cylinder(Vector3(0, 0.7, 0), 0.2, 0.12, 7, Color(0.7, 0.1, 0.08))
	b.add_box(Vector3(0, 0.45, 0), Vector3(0.5, 0.12, 0.12), Color(0.75, 0.1, 0.08))
	return b


static func bin() -> MeshBuilder:
	var b := MeshBuilder.new()
	b.add_cylinder(Vector3.ZERO, 0.35, 0.95, 8, Color(0.22, 0.38, 0.3))
	b.add_cylinder(Vector3(0, 0.95, 0), 0.38, 0.08, 8, Color(0.15, 0.25, 0.2))
	return b


static func barrier() -> MeshBuilder:
	var b := MeshBuilder.new()
	var c := Color(0.62, 0.62, 0.6)
	b.add_box(Vector3(0, 0.2, 0), Vector3(0.7, 0.4, 2.4), c)
	b.add_box(Vector3(0, 0.6, 0), Vector3(0.4, 0.8, 2.4), c)
	b.add_box(Vector3(0, 0.95, 0), Vector3(0.42, 0.12, 2.42), Color(0.85, 0.4, 0.1))
	return b


static func fountain() -> MeshBuilder:
	var b := MeshBuilder.new()
	b.add_cylinder(Vector3.ZERO, 4.2, 0.6, 14, Color(0.7, 0.7, 0.68))
	b.add_cylinder(Vector3(0, 0.5, 0), 3.7, 0.12, 14, Color(0.25, 0.55, 0.75))
	b.add_cylinder(Vector3(0, 0.5, 0), 0.5, 1.8, 8, Color(0.7, 0.7, 0.68))
	b.add_cylinder(Vector3(0, 2.2, 0), 1.3, 0.25, 10, Color(0.7, 0.7, 0.68))
	b.add_cylinder(Vector3(0, 2.45, 0), 1.1, 0.1, 10, Color(0.3, 0.6, 0.8))
	return b


static func kiosk(col: Color) -> MeshBuilder:
	var b := MeshBuilder.new()
	b.add_box(Vector3(0, 1.3, 0), Vector3(3.2, 2.6, 2.6), Color(0.9, 0.88, 0.82))
	b.add_box(Vector3(0, 2.75, 0), Vector3(3.6, 0.3, 3.0), col)
	b.add_box(Vector3(0, 1.6, 1.32), Vector3(2.2, 1.0, 0.06), Color(0.16, 0.24, 0.34))
	b.add_box(Vector3(0, 0.95, 1.7), Vector3(2.4, 0.1, 0.8), Color(0.5, 0.35, 0.22))
	return b
