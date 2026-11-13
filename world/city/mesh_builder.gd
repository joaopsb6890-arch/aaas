class_name MeshBuilder
extends RefCounted
## Constrói malhas simples (caixas, telhados, cones) com cor por vértice, numa só superfície.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
## Transformação aplicada a tudo o que for acrescentado a seguir.
var xf: Transform3D = Transform3D.IDENTITY


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var n := (xf.basis * (b - a).cross(d - a)).normalized()
	var base := verts.size()
	for p in [a, b, c, d]:
		verts.append(xf * p)
		norms.append(n)
		cols.append(col)
	idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (xf.basis * (b - a).cross(c - a)).normalized()
	var base := verts.size()
	for p in [a, b, c]:
		verts.append(xf * p)
		norms.append(n)
		cols.append(col)
	idx.append_array([base, base + 2, base + 1])


## Caixa centrada em "pos" (sem a face de baixo se bottom=false).
func add_box(pos: Vector3, size: Vector3, col: Color, bottom: bool = false) -> void:
	var h := size * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3: return pos + Vector3(x * h.x, y * h.y, z * h.z)
	_quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), col)      # +Z
	_quad(p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1), col)  # -Z
	_quad(p.call(1, -1, 1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), col)      # +X
	_quad(p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), col)  # -X
	_quad(p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(-1, 1, -1), col)      # topo
	if bottom:
		_quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), col)


## Telhado de duas águas: cumeeira ao longo de Z. "pos" = centro da base.
func add_gable(pos: Vector3, w: float, d: float, h: float, col: Color, col2: Color) -> void:
	var l := Vector3(-w * 0.5, 0, -d * 0.5)
	var r := Vector3(w * 0.5, 0, -d * 0.5)
	var lf := Vector3(-w * 0.5, 0, d * 0.5)
	var rf := Vector3(w * 0.5, 0, d * 0.5)
	var t0 := Vector3(0, h, -d * 0.5)
	var t1 := Vector3(0, h, d * 0.5)
	_quad(pos + lf, pos + t1, pos + t0, pos + l, col)           # água esquerda
	_quad(pos + r, pos + t0, pos + t1, pos + rf, col)           # água direita
	_tri(pos + lf, pos + rf, pos + t1, col2)                    # empena da frente
	_tri(pos + r, pos + l, pos + t0, col2)                      # empena de trás


## Telhado de quatro águas (pirâmide truncada).
func add_hip(pos: Vector3, w: float, d: float, h: float, col: Color) -> void:
	var rl := maxf(d - w, 0.0) * 0.5
	var a := Vector3(-w * 0.5, 0, -d * 0.5)
	var b := Vector3(w * 0.5, 0, -d * 0.5)
	var c := Vector3(w * 0.5, 0, d * 0.5)
	var e := Vector3(-w * 0.5, 0, d * 0.5)
	var t0 := Vector3(0, h, -rl)
	var t1 := Vector3(0, h, rl)
	_quad(pos + e, pos + t1, pos + t0, pos + a, col)
	_quad(pos + b, pos + t0, pos + t1, pos + c, col)
	_tri(pos + e, pos + c, pos + t1, col.darkened(0.12))
	_tri(pos + b, pos + a, pos + t0, col.darkened(0.12))


## Cone/pirâmide de N lados (copas das árvores).
func add_cone(pos: Vector3, radius: float, h: float, sides: int, col: Color) -> void:
	var top := pos + Vector3(0, h, 0)
	for i in sides:
		var a0 := TAU * float(i) / sides
		var a1 := TAU * float(i + 1) / sides
		var p0 := pos + Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var p1 := pos + Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		_tri(p1, p0, top, col)


## Cilindro com tampa (postes, fontes, depósitos).
func add_cylinder(pos: Vector3, radius: float, h: float, sides: int, col: Color) -> void:
	for i in sides:
		var a0 := TAU * float(i) / sides
		var a1 := TAU * float(i + 1) / sides
		var b0 := pos + Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var b1 := pos + Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		var t0 := b0 + Vector3(0, h, 0)
		var t1 := b1 + Vector3(0, h, 0)
		_quad(b1, b0, t0, t1, col)
		_tri(pos + Vector3(0, h, 0), t1, t0, col.lightened(0.1))


## Copia outro builder para este, com uma transformação.
func append(o: MeshBuilder, t: Transform3D) -> void:
	var base := verts.size()
	for i in o.verts.size():
		verts.append(t * o.verts[i])
		norms.append((t.basis * o.norms[i]).normalized())
		cols.append(o.cols[i])
	for k in o.idx:
		idx.append(base + k)


func is_empty() -> bool:
	return verts.is_empty()


func build(mat: Material) -> ArrayMesh:
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	return m


## Acrescenta uma segunda superfície (ex.: janelas) a uma malha existente.
func add_to(mesh: ArrayMesh, mat: Material) -> void:
	if verts.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
