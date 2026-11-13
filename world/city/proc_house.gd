class_name ProcHouse
extends RefCounted
## Casas e prédios gerados em código, todos diferentes. A frente fica virada para +Z.
## build() devolve malhas (paredes/telhado e vidros) para serem fundidas por quarteirão.

const WALLS: Array[Color] = [
	Color("e8d9b8"), Color("d9a679"), Color("b8c7d1"), Color("cfd8b2"), Color("e3b8b0"),
	Color("c9c2b6"), Color("9fb4a0"), Color("d8cfa0"), Color("a8a0b8"), Color("e6e1d6"),
	Color("c98f7a"), Color("8fa7bd"), Color("d6c9a5")]
const ROOFS: Array[Color] = [
	Color("8c3b2b"), Color("5a4a42"), Color("3d4a56"), Color("6e5a3c"), Color("7a2f2f"), Color("44484d"), Color("2f5a4a")]
const DOORS: Array[Color] = [
	Color("5a3a22"), Color("2f4f6f"), Color("7a2a2a"), Color("2f5f3a"), Color("e8e4dc")]
const KINDS := ["cottage", "cottage", "modern", "shop", "apartment", "villa", "townhouse"]


static func _windows(g: MeshBuilder, w: float, d: float, floors: int, fh: float, y0: float, rng: RandomNumberGenerator, cols_front: int, shutters: bool) -> void:
	var glass := Color(0.16, 0.24, 0.34)
	var frame := Color(0.93, 0.93, 0.9)
	for f in floors:
		var y := y0 + fh * (f + 0.55)
		for i in cols_front:
			var x := lerpf(-w * 0.5 + 1.6, w * 0.5 - 1.6, (float(i) + 0.5) / cols_front) if cols_front > 1 else 0.0
			if f == 0 and i == cols_front / 2 and cols_front % 2 == 1:
				continue  # espaço da porta
			g.add_box(Vector3(x, y, d * 0.5 + 0.03), Vector3(1.3, 1.5, 0.08), frame)
			g.add_box(Vector3(x, y, d * 0.5 + 0.08), Vector3(1.1, 1.3, 0.06), glass)
			if shutters:
				g.add_box(Vector3(x - 0.85, y, d * 0.5 + 0.06), Vector3(0.4, 1.5, 0.06), Color(0.25, 0.4, 0.3))
				g.add_box(Vector3(x + 0.85, y, d * 0.5 + 0.06), Vector3(0.4, 1.5, 0.06), Color(0.25, 0.4, 0.3))
		var n_side := maxi(int(d / 4.5), 1)
		for i in n_side:
			var z := lerpf(-d * 0.5 + 2.2, d * 0.5 - 2.2, (float(i) + 0.5) / n_side) if n_side > 1 else 0.0
			if rng.randf() < 0.85:
				for s in [-1.0, 1.0]:
					g.add_box(Vector3(s * (w * 0.5 + 0.03), y, z), Vector3(0.08, 1.4, 1.1), glass)


static func _fence(b: MeshBuilder, w: float, z: float, col: Color) -> void:
	var n := int(w / 1.3)
	for i in n + 1:
		var x := lerpf(-w * 0.5, w * 0.5, float(i) / maxf(n, 1))
		b.add_box(Vector3(x, 0.55, z), Vector3(0.1, 1.1, 0.1), col)
	b.add_box(Vector3(0, 0.85, z), Vector3(w, 0.08, 0.06), col)
	b.add_box(Vector3(0, 0.45, z), Vector3(w, 0.08, 0.06), col)


## Devolve {"b": MeshBuilder, "g": MeshBuilder, "w", "d", "h"}
static func build(rng: RandomNumberGenerator, kind: String = "") -> Dictionary:
	if kind == "":
		kind = KINDS[rng.randi() % KINDS.size()]
	var b := MeshBuilder.new()
	var g := MeshBuilder.new()
	var wall: Color = WALLS[rng.randi() % WALLS.size()]
	var roof: Color = ROOFS[rng.randi() % ROOFS.size()]
	var door: Color = DOORS[rng.randi() % DOORS.size()]
	var w := 9.0
	var d := 10.0
	var h := 3.0
	var trim := Color(0.95, 0.95, 0.93)
	var fence_col := Color(0.92, 0.9, 0.84) if rng.randf() < 0.6 else Color(0.45, 0.32, 0.22)
	var with_fence := false
	match kind:
		"cottage":
			w = rng.randf_range(8.0, 11.0)
			d = rng.randf_range(9.0, 12.0)
			var floors := rng.randi_range(1, 2)
			var fh := 3.0
			h = fh * floors
			b.add_box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall)
			b.add_box(Vector3(0, 0.25, 0), Vector3(w + 0.2, 0.5, d + 0.2), trim.darkened(0.25))
			b.add_gable(Vector3(0, h, 0), w + 1.0, d + 1.0, rng.randf_range(2.2, 3.4), roof, wall)
			var dx := rng.randf_range(-1.5, 1.5)
			b.add_box(Vector3(dx, 1.1, d * 0.5 + 0.04), Vector3(1.2, 2.2, 0.1), door)
			# alpendre com degraus
			b.add_box(Vector3(dx, 0.1, d * 0.5 + 0.9), Vector3(2.4, 0.2, 1.8), Color(0.7, 0.7, 0.68))
			if rng.randf() < 0.6:
				b.add_box(Vector3(dx, 2.6, d * 0.5 + 1.0), Vector3(2.8, 0.15, 2.0), roof)
				b.add_box(Vector3(dx - 1.3, 1.3, d * 0.5 + 1.8), Vector3(0.12, 2.6, 0.12), trim)
				b.add_box(Vector3(dx + 1.3, 1.3, d * 0.5 + 1.8), Vector3(0.12, 2.6, 0.12), trim)
			b.add_box(Vector3(w * 0.28, h + 2.0, -d * 0.2), Vector3(0.9, 2.6, 0.9), Color(0.45, 0.3, 0.26))
			_windows(g, w, d, floors, fh, 0.0, rng, 2 if w < 9.5 else 3, rng.randf() < 0.5)
			h += 3.0
			with_fence = true
		"townhouse":
			w = rng.randf_range(7.0, 9.0)
			d = rng.randf_range(10.0, 13.0)
			var fl := rng.randi_range(2, 3)
			h = 3.0 * fl
			b.add_box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall.darkened(0.04))
			b.add_box(Vector3(0, h + 0.2, 0), Vector3(w + 0.4, 0.4, d + 0.4), trim)
			b.add_box(Vector3(0, 1.1, d * 0.5 + 0.04), Vector3(1.2, 2.2, 0.1), door)
			b.add_box(Vector3(0, 0.15, d * 0.5 + 0.8), Vector3(2.0, 0.3, 1.6), Color(0.7, 0.7, 0.68))
			for f in range(1, fl):  # varandas
				b.add_box(Vector3(0, 3.0 * f, d * 0.5 + 0.5), Vector3(w * 0.7, 0.15, 1.0), trim)
				b.add_box(Vector3(0, 3.0 * f + 0.55, d * 0.5 + 0.98), Vector3(w * 0.7, 0.9, 0.06), Color(0.3, 0.32, 0.34))
			_windows(g, w, d, fl, 3.0, 0.0, rng, 2, false)
			h += 0.4
			with_fence = true
		"modern":
			w = rng.randf_range(10.0, 14.0)
			d = rng.randf_range(9.0, 12.0)
			var fh2 := 3.2
			h = fh2 * 2.0
			b.add_box(Vector3(0, fh2 * 0.5, 0), Vector3(w, fh2, d), wall.lightened(0.1))
			b.add_box(Vector3(w * 0.12, fh2 * 1.5, 0), Vector3(w * 0.78, fh2, d), Color(0.82, 0.82, 0.8))
			b.add_box(Vector3(0, h + 0.15, 0), Vector3(w + 1.2, 0.3, d + 1.2), Color(0.2, 0.2, 0.22))
			b.add_box(Vector3(-w * 0.25, 1.2, d * 0.5 + 0.05), Vector3(3.4, 2.4, 0.1), Color(0.55, 0.57, 0.6))
			b.add_box(Vector3(-w * 0.45, fh2 * 1.5, d * 0.5 + 0.9), Vector3(w * 0.3, 0.2, 1.8), Color(0.25, 0.25, 0.27))
			for i in 4:   # painéis solares
				b.add_box(Vector3(-w * 0.3 + i * 1.7, h + 0.55, 0), Vector3(1.5, 0.08, 2.4), Color(0.1, 0.16, 0.3))
			_windows(g, w, d, 2, fh2, 0.0, rng, 3, false)
			h += 0.6
		"shop":
			w = rng.randf_range(10.0, 15.0)
			d = rng.randf_range(9.0, 13.0)
			h = 4.2
			var awn := Color.from_hsv(rng.randf(), 0.65, 0.85)
			b.add_box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall)
			b.add_box(Vector3(0, h + 0.3, 0), Vector3(w + 0.4, 0.6, d + 0.4), wall.darkened(0.25))
			b.add_box(Vector3(0, 3.1, d * 0.5 + 0.9), Vector3(w - 1.0, 0.2, 1.8), awn)
			b.add_box(Vector3(0, 3.8, d * 0.5 + 0.12), Vector3(w * 0.6, 0.8, 0.2), Color.from_hsv(rng.randf(), 0.5, 0.35))
			b.add_box(Vector3(0, 1.1, d * 0.5 + 0.05), Vector3(1.4, 2.2, 0.1), door)
			g.add_box(Vector3(-w * 0.27, 1.5, d * 0.5 + 0.06), Vector3(w * 0.28, 1.8, 0.08), Color(0.2, 0.32, 0.42))
			g.add_box(Vector3(w * 0.27, 1.5, d * 0.5 + 0.06), Vector3(w * 0.28, 1.8, 0.08), Color(0.2, 0.32, 0.42))
			b.add_box(Vector3(w * 0.3, h + 1.0, -d * 0.2), Vector3(2.2, 1.0, 1.6), Color(0.6, 0.6, 0.62))
			h += 1.6
		"apartment":
			w = rng.randf_range(11.0, 15.0)
			d = rng.randf_range(10.0, 14.0)
			var fl3 := rng.randi_range(3, 6)
			var fh3 := 3.1
			h = fh3 * fl3
			b.add_box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall.darkened(0.08))
			b.add_box(Vector3(0, h + 0.3, 0), Vector3(w + 0.5, 0.6, d + 0.5), wall.darkened(0.3))
			b.add_box(Vector3(w * 0.25, h + 1.5, -d * 0.2), Vector3(2.4, 1.8, 2.4), Color(0.5, 0.5, 0.52))
			b.add_cylinder(Vector3(-w * 0.25, h + 0.6, -d * 0.2), 1.0, 1.8, 8, Color(0.55, 0.4, 0.3))
			b.add_box(Vector3(0, 1.2, d * 0.5 + 0.05), Vector3(2.0, 2.4, 0.1), Color(0.25, 0.28, 0.3))
			for f in range(1, fl3):  # varandas
				if rng.randf() < 0.6:
					b.add_box(Vector3(w * 0.28, fh3 * f + 0.05, d * 0.5 + 0.45), Vector3(w * 0.3, 0.14, 0.9), Color(0.75, 0.75, 0.73))
			_windows(g, w, d, fl3, fh3, 0.4, rng, 4, false)
			h += 2.4
		_:  # villa
			w = rng.randf_range(11.0, 14.0)
			d = rng.randf_range(10.0, 13.0)
			h = 3.2
			b.add_box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall)
			b.add_box(Vector3(-w * 0.18, h + 1.6, 0), Vector3(w * 0.55, 3.2, d * 0.8), wall.lightened(0.08))
			b.add_hip(Vector3(0, h, 0), w + 1.0, d + 1.0, 1.6, roof)
			b.add_hip(Vector3(-w * 0.18, h + 3.2, 0), w * 0.55 + 1.0, d * 0.8 + 1.0, 1.8, roof)
			b.add_box(Vector3(w * 0.3, 1.1, d * 0.5 + 0.05), Vector3(1.3, 2.2, 0.1), door)
			b.add_box(Vector3(w * 0.3, 0.1, d * 0.5 + 0.8), Vector3(2.2, 0.2, 1.6), Color(0.7, 0.7, 0.68))
			_windows(g, w, d, 1, 3.2, 0.0, rng, 3, true)
			h += 5.0
			with_fence = true
	# caminho até à rua, cerca e sebes
	b.add_box(Vector3(0, 0.03, d * 0.5 + 2.6), Vector3(1.5, 0.06, 4.4), Color(0.72, 0.7, 0.66))
	if with_fence and rng.randf() < 0.75:
		_fence(b, w + 2.0, d * 0.5 + 4.6, fence_col)
	if rng.randf() < 0.55:
		var hc := Color(0.2, 0.42, 0.22)
		b.add_box(Vector3(-w * 0.5 + 0.8, 0.45, d * 0.5 + 1.2), Vector3(1.6, 0.9, 0.9), hc)
		b.add_box(Vector3(w * 0.5 - 0.8, 0.45, d * 0.5 + 1.2), Vector3(1.6, 0.9, 0.9), hc)
	return {"b": b, "g": g, "w": w, "d": d, "h": h}
