class_name CityMap
extends Node3D
## Cidade grande e procedural, otimizada.
##  - ruas: peças do source/Raods.fbx (reescaladas em código e fundidas por rua)
##  - casas: source/mx_res_1x2_duplex.fbx + casas/prédios gerados em código
## Toda a geometria é fundida por zona (poucos draw calls) e a colisão é feita só com
## caixas simples (o jogador não prende em arestas de malhas).

const ROADS_SRC := "res://source/Raods.fbx"
const HOUSE_SRC := "res://source/mx_res_1x2_duplex.fbx"

const BLOCKS := 4
const TILE := 29.4
const ROAD_W := 25.6
const BLOCK := TILE * 3.0
const PITCH := BLOCK + ROAD_W
const SIDEWALK := 4.0
const CURB_H := 0.02
const HOUSE_SCALE := 0.012
const SEED := 20260512

const STRAIGHT := {
	"Roads_002": [1.5, -13.23],
	"Roads_001": [1.49, -13.28],
	"Roads_008": [1.19, -15.92],
}
const CAR_COLORS: Array[Color] = [
	Color("c8402f"), Color("2f5fa8"), Color("e8e4dc"), Color("2b2d31"), Color("c9b13a"),
	Color("4a7a52"), Color("8a8f96"), Color("b5622a"), Color("6a3f8a")]

var rng := RandomNumberGenerator.new()
var fbx_count := 0
var street_points: Array[Vector3] = []
var extent: float = 0.0
var plaza_blocks: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2)]
var park_blocks: Array[Vector2i] = [Vector2i(2, 1)]

var _piece_mesh: Dictionary = {}
var _house_mesh: ArrayMesh
var _asphalt := Color(0.06, 0.06, 0.065)
var _concrete := Color(0.62, 0.62, 0.6)
var _curb := Color(0.78, 0.78, 0.76)
var _grass := Color(0.33, 0.47, 0.26)

var _flat: Dictionary = {}            # chunk -> MeshBuilder
var _houses_b: Dictionary = {}        # chunk -> MeshBuilder (paredes/telhados)
var _houses_g: Dictionary = {}        # chunk -> MeshBuilder (vidros)
var _boxes: Dictionary = {}           # chunk -> Array [Transform3D, Vector3]
var _fbx_xf: Dictionary = {}          # chunk -> Array[Transform3D]
var _mm: Dictionary = {}              # tipo -> {chunk -> Array[Transform3D]}
var _mm_col: Dictionary = {}          # tipo -> {chunk -> Array[Color]}
var _mm_mesh: Dictionary = {}


func line_pos(i: int) -> float:
	return (float(i) - BLOCKS * 0.5) * PITCH


func block_center(bx: int, bz: int) -> Vector3:
	return Vector3((line_pos(bx) + line_pos(bx + 1)) * 0.5, 0.0, (line_pos(bz) + line_pos(bz + 1)) * 0.5)


func _chunk(p: Vector3) -> Vector2i:
	var o := BLOCKS * PITCH * 0.5
	return Vector2i(clampi(int(floorf((p.x + o) / PITCH)), 0, BLOCKS), clampi(int(floorf((p.z + o) / PITCH)), 0, BLOCKS))


func _fb(p: Vector3) -> MeshBuilder:
	var k := _chunk(p)
	if not _flat.has(k):
		_flat[k] = MeshBuilder.new()
	return _flat[k]


func build() -> void:
	rng.seed = SEED
	extent = BLOCKS * PITCH * 0.5 + ROAD_W * 0.5
	_load_materials()
	_make_ground()
	for i in BLOCKS + 1:
		for j in BLOCKS:
			_street_segment(true, i, j)
			_street_segment(false, i, j)
	for i in BLOCKS + 1:
		for j in BLOCKS + 1:
			_intersection(i, j)
	for bx in BLOCKS:
		for bz in BLOCKS:
			_block(bx, bz)
	_roadblocks()
	_skyline()
	_flush()


# ---------------------------------------------------------------- PEÇAS DO FBX

func _load_materials() -> void:
	var src := (load(ROADS_SRC) as PackedScene).instantiate()
	var mi := src.get_node("Roads_002") as MeshInstance3D
	var m1 := mi.get_active_material(1) as BaseMaterial3D
	if m1:
		_concrete = m1.albedo_color.lerp(Color(0.62, 0.62, 0.6), 0.5)
	src.free()


## Peça do FBX em metros, com o topo em y=0 e o asfalto a começar em z=0.
func _road_mesh(piece: String, center: bool = false) -> ArrayMesh:
	var key := piece + ("_c" if center else "")
	if _piece_mesh.has(key):
		return _piece_mesh[key]
	var src := (load(ROADS_SRC) as PackedScene).instantiate()
	var mi := src.get_node(piece) as MeshInstance3D
	var rot := Basis(Vector3(0, 0, 1), PI * 0.5)
	var top := 1.5
	var z0 := 0.0
	var cx := 0.0
	var cz := 0.0
	if STRAIGHT.has(piece):
		top = STRAIGHT[piece][0]
		z0 = STRAIGHT[piece][1]
	elif piece == "Roads_000":
		top = 2.18
		cx = 1.05
		cz = -3.8
	var out := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			var v := rot * (vs[i] * 1000.0)
			v.y -= top
			if center:
				v.x += cx
				v.z -= cz
			else:
				v.z -= z0
			vs[i] = v
			if ns.size() > i:
				ns[i] = rot * ns[i]
		arr[Mesh.ARRAY_VERTEX] = vs
		arr[Mesh.ARRAY_NORMAL] = ns
		arr[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(out.get_surface_count() - 1, mi.get_active_material(s))
	src.free()
	_piece_mesh[key] = out
	return out


## Funde várias peças (nome, transformação) numa só malha, agrupadas por material.
func _merge_pieces(list: Array) -> ArrayMesh:
	var sts := {}
	for e in list:
		var mesh := _road_mesh(e[0], e[2] if e.size() > 2 else false)
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			var key: String = m.resource_name if m else "none"
			if not sts.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(m)
				sts[key] = st
			(sts[key] as SurfaceTool).append_from(mesh, s, e[1])
	var out := ArrayMesh.new()
	for k in sts:
		(sts[k] as SurfaceTool).commit(out)
	return out


func _house() -> ArrayMesh:
	if _house_mesh:
		return _house_mesh
	var src := (load(HOUSE_SRC) as PackedScene).instantiate()
	var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	var ab := mi.get_aabb()
	var c := ab.get_center()
	var out := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in vs.size():
			var v := vs[i]
			vs[i] = Vector3((v.x - c.x) * HOUSE_SCALE, (v.y - ab.position.y) * HOUSE_SCALE, (v.z - c.z) * HOUSE_SCALE)
		arr[Mesh.ARRAY_VERTEX] = vs
		arr[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(out.get_surface_count() - 1, mi.get_active_material(s))
	src.free()
	_house_mesh = out
	return out


func house_size() -> Vector3:
	return _house().get_aabb().size


# ---------------------------------------------------------------- AUXILIARES

func _flat_box(center: Vector3, size: Vector3, col: Color) -> void:
	_fb(center).add_box(center, size, col)


func _collide(chunk_pos: Vector3, xf: Transform3D, size: Vector3) -> void:
	var k := _chunk(chunk_pos)
	if not _boxes.has(k):
		_boxes[k] = []
	_boxes[k].append([xf, size])


func _mm_add(kind: String, mesh: Mesh, xf: Transform3D, col: Variant = null) -> void:
	_mm_mesh[kind] = mesh
	var k := _chunk(xf.origin)
	if not _mm.has(kind):
		_mm[kind] = {}
		_mm_col[kind] = {}
	if not _mm[kind].has(k):
		_mm[kind][k] = []
		_mm_col[kind][k] = []
	_mm[kind][k].append(xf)
	if col != null:
		_mm_col[kind][k].append(col)


func _vmat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.92
	return m


var _prop_cache: Dictionary = {}

func _prop(name: String) -> ArrayMesh:
	if _prop_cache.has(name):
		return _prop_cache[name]
	var b: MeshBuilder
	match name:
		"car": b = CityProps.car()
		"light": b = CityProps.traffic_light()
		"bench": b = CityProps.bench()
		"hydrant": b = CityProps.hydrant()
		"bin": b = CityProps.bin()
		"barrier": b = CityProps.barrier()
		"fountain": b = CityProps.fountain()
		"lamp":
			b = MeshBuilder.new()
			b.add_cylinder(Vector3.ZERO, 0.07, 7.0, 6, Color(0.22, 0.24, 0.26))
			b.add_box(Vector3(0.7, 7.0, 0), Vector3(1.5, 0.16, 0.2), Color(0.22, 0.24, 0.26))
			b.add_box(Vector3(1.3, 6.9, 0), Vector3(0.6, 0.14, 0.3), Color(1.0, 0.95, 0.75))
		"tree":
			b = MeshBuilder.new()
			b.add_box(Vector3(0, 1.1, 0), Vector3(0.45, 2.2, 0.45), Color(0.38, 0.26, 0.17))
			b.add_cone(Vector3(0, 1.8, 0), 2.1, 3.4, 7, Color(0.2, 0.42, 0.2))
			b.add_cone(Vector3(0, 3.6, 0), 1.6, 3.0, 7, Color(0.25, 0.5, 0.24))
		"tree2":
			b = MeshBuilder.new()
			b.add_box(Vector3(0, 1.4, 0), Vector3(0.5, 2.8, 0.5), Color(0.42, 0.3, 0.2))
			b.add_box(Vector3(0, 3.7, 0), Vector3(2.8, 2.2, 2.8), Color(0.3, 0.52, 0.22))
			b.add_box(Vector3(0.3, 5.0, 0.2), Vector3(1.9, 1.5, 1.9), Color(0.36, 0.58, 0.26))
		_:
			b = MeshBuilder.new()
	var mesh := b.build(_vmat())
	_prop_cache[name] = mesh
	return mesh


# ---------------------------------------------------------------- CHÃO

func _make_ground() -> void:
	var size := 2600.0
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _grass.darkened(0.12)
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position.y = -0.1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# um único colisor plano: nunca há arestas onde prender
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 2.0, size)
	cs.shape = box
	cs.position = Vector3(0, -1.0, 0)
	body.add_child(cs)
	add_child(body)
	# muros invisíveis no limite
	var lim := extent + 60.0
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var wb := StaticBody3D.new()
		var wcs := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		var along := Vector3(absf(d.z), 0, absf(d.x))
		wbox.size = Vector3(2.0, 40.0, 2.0) + along * (lim * 2.0)
		wcs.shape = wbox
		wb.position = d * lim + Vector3(0, 19.0, 0)
		wb.add_child(wcs)
		add_child(wb)
	# manchas de relva fora da cidade (variação de cor)
	var pb := MeshBuilder.new()
	for i in 220:
		var a := rng.randf() * TAU
		var r := rng.randf_range(extent + 5.0, extent + 420.0)
		var sz := rng.randf_range(25.0, 80.0)
		var c := _grass.lerp(Color(0.5, 0.52, 0.28) if rng.randf() < 0.35 else Color(0.22, 0.4, 0.22), rng.randf_range(0.2, 0.7))
		pb.add_box(Vector3(cos(a) * r, -0.07, sin(a) * r), Vector3(sz, 0.04, sz * rng.randf_range(0.6, 1.4)), c)
	var pmi := MeshInstance3D.new()
	pmi.mesh = pb.build(_vmat())
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pmi)


# ---------------------------------------------------------------- RUAS

func _street_segment(vertical: bool, line: int, seg: int) -> void:
	var fixed := line_pos(line)
	var start := line_pos(seg) + ROAD_W * 0.5
	var yaw := 0.0 if vertical else PI * 0.5
	var names := STRAIGHT.keys()
	var list: Array = []
	var inv_yaw := yaw
	for k in 3:
		var along := start + k * TILE
		var piece: String = names[0]
		var r := rng.randf()
		if r > 0.82:
			piece = names[1]
		elif r > 0.64:
			piece = names[2]
		var pos := Vector3(fixed, 0, along) if vertical else Vector3(along, 0, fixed)
		list.append([piece, Transform3D(Basis(Vector3.UP, yaw), pos)])
		var hole_c := along + 20.0 + 4.7
		var hc := Vector3(fixed, -0.25, hole_c) if vertical else Vector3(hole_c, -0.25, fixed)
		_flat_box(hc, Vector3(20.0, 0.5, 9.4) if vertical else Vector3(9.4, 0.5, 20.0), _asphalt)
		for d in 4:
			var dc := along + 2.5 + d * 7.0
			var lc := Vector3(fixed, 0.02, dc) if vertical else Vector3(dc, 0.02, fixed)
			_flat_box(lc, Vector3(0.22, 0.04, 3.2) if vertical else Vector3(3.2, 0.04, 0.22), Color(0.95, 0.8, 0.15))
		# detalhes por peça
		for s in [-1.0, 1.0]:
			var off: float = s * (ROAD_W * 0.5 + 1.6)
			var lp := Vector3(fixed + off, CURB_H, along + 6.0) if vertical else Vector3(along + 6.0, CURB_H, fixed + off)
			var lbasis := Basis(Vector3.UP, (0.0 if s < 0 else PI) if vertical else (PI * 0.5 if s < 0 else -PI * 0.5))
			_mm_add("lamp", _prop("lamp"), Transform3D(lbasis, lp))
			if rng.randf() < 0.8:
				var tp := Vector3(fixed + off, CURB_H, along + TILE * 0.5 + 8.0) if vertical else Vector3(along + TILE * 0.5 + 8.0, CURB_H, fixed + off)
				_add_tree(tp, rng.randf_range(0.8, 1.15))
			if rng.randf() < 0.25:
				var hp := Vector3(fixed + s * (ROAD_W * 0.5 + 0.9), CURB_H, along + 18.0) if vertical else Vector3(along + 18.0, CURB_H, fixed + s * (ROAD_W * 0.5 + 0.9))
				var pk := "hydrant" if rng.randf() < 0.5 else "bin"
				_mm_add(pk, _prop(pk), Transform3D(Basis.IDENTITY, hp))
			# carros estacionados
			if rng.randf() < 0.32:
				var za := along + rng.randf_range(3.0, 17.0)
				var xo: float = s * 8.0 + rng.randf_range(-0.25, 0.25)
				var cp := Vector3(fixed + xo, 0.0, za) if vertical else Vector3(za, 0.0, fixed + xo)
				var cy := (0.0 if s < 0 else PI) if vertical else (PI * 0.5 if s < 0 else -PI * 0.5)
				cy += rng.randf_range(-0.04, 0.04) + (PI if rng.randf() < 0.3 else 0.0)
				var cxf := Transform3D(Basis(Vector3.UP, cy), cp)
				_mm_add("car", _prop("car"), cxf, CAR_COLORS[rng.randi() % CAR_COLORS.size()])
				_collide(cp, Transform3D(cxf.basis, cp + Vector3(0, 0.75, 0)), Vector3(1.9, 1.5, 4.4))
		street_points.append(Vector3(fixed, 0.5, along + 10.0) if vertical else Vector3(along + 10.0, 0.5, fixed))
	# linhas de berma (brancas) ao longo de todo o segmento
	for s in [-1.0, 1.0]:
		var mid := start + BLOCK * 0.5
		var ec := Vector3(fixed + s * 9.7, 0.02, mid) if vertical else Vector3(mid, 0.02, fixed + s * 9.7)
		_flat_box(ec, Vector3(0.16, 0.04, BLOCK) if vertical else Vector3(BLOCK, 0.04, 0.16), Color(0.9, 0.9, 0.88))
	var mi := MeshInstance3D.new()
	mi.mesh = _merge_pieces(list)
	mi.visibility_range_end = 330.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	inv_yaw = 0.0


func _intersection(i: int, j: int) -> void:
	var c := Vector3(line_pos(i), 0, line_pos(j))
	_flat_box(c + Vector3(0, -0.25, 0), Vector3(ROAD_W, 0.5, ROAD_W), _asphalt)
	for side in 4:
		var dir := Vector3(0, 0, 1).rotated(Vector3.UP, side * PI * 0.5)
		var perp := Vector3(1, 0, 0).rotated(Vector3.UP, side * PI * 0.5)
		for k in 9:
			var p := c + dir * (ROAD_W * 0.5 - 2.6) + perp * (-9.6 + k * 2.4)
			var sz := Vector3(0.8, 0.04, 3.4) if side % 2 == 0 else Vector3(3.4, 0.04, 0.8)
			_flat_box(Vector3(p.x, 0.02, p.z), sz, Color(0.93, 0.93, 0.9))
		# semáforo em cada canto
	for corner in 4:
		var cx := -1.0 if corner % 2 == 0 else 1.0
		var cz := -1.0 if corner < 2 else 1.0
		var pos := c + Vector3(cx * (ROAD_W * 0.5 + 0.8), CURB_H, cz * (ROAD_W * 0.5 + 0.8))
		var face := atan2(-cx, -cz) + PI * 0.5
		_mm_add("light", _prop("light"), Transform3D(Basis(Vector3.UP, face), pos))
	street_points.append(c + Vector3(0, 0.5, 0))


func _roadblocks() -> void:
	# barreiras de betão e carros abandonados espalhados (ambiente pós-apocalíptico)
	var tries := 0
	var placed := 0
	while placed < 16 and tries < 200:
		tries += 1
		var vertical := rng.randf() < 0.5
		var line := rng.randi_range(0, BLOCKS)
		var seg := rng.randi_range(0, BLOCKS - 1)
		var fixed := line_pos(line)
		var along := line_pos(seg) + ROAD_W * 0.5 + rng.randf_range(10.0, BLOCK - 10.0)
		var p := Vector3(fixed, 0, along) if vertical else Vector3(along, 0, fixed)
		if p.length() < 45.0:
			continue
		placed += 1
		var yaw := (PI * 0.5 if vertical else 0.0) + rng.randf_range(-0.25, 0.25)
		for n in 2:
			var off := (n - 0.5) * 2.6
			var bp := p + (Vector3(off, 0, 0) if vertical else Vector3(0, 0, off))
			var xf := Transform3D(Basis(Vector3.UP, yaw), bp)
			_mm_add("barrier", _prop("barrier"), xf)
			_collide(bp, Transform3D(Basis(Vector3.UP, yaw), bp + Vector3(0, 0.55, 0)), Vector3(0.7, 1.1, 2.4))
		if rng.randf() < 0.6:
			var cp := p + (Vector3(7.0, 0, 3.0) if vertical else Vector3(3.0, 0, 7.0))
			var cxf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), cp)
			_mm_add("car", _prop("car"), cxf, Color(0.12, 0.1, 0.09))
			_collide(cp, Transform3D(cxf.basis, cp + Vector3(0, 0.75, 0)), Vector3(1.9, 1.5, 4.4))


# ---------------------------------------------------------------- QUARTEIRÕES

func _block(bx: int, bz: int) -> void:
	var c := block_center(bx, bz)
	var half := BLOCK * 0.5
	var inner := BLOCK - SIDEWALK * 2.0
	var top := CURB_H
	var th := 0.5
	var cy := top - th * 0.5
	var fb := _fb(c)
	# passeios (anel) + lancil mais claro na orla
	fb.add_box(c + Vector3(0, cy, -(half - SIDEWALK * 0.5)), Vector3(BLOCK, th, SIDEWALK), _concrete)
	fb.add_box(c + Vector3(0, cy, half - SIDEWALK * 0.5), Vector3(BLOCK, th, SIDEWALK), _concrete)
	fb.add_box(c + Vector3(-(half - SIDEWALK * 0.5), cy, 0), Vector3(SIDEWALK, th, inner), _concrete)
	fb.add_box(c + Vector3(half - SIDEWALK * 0.5, cy, 0), Vector3(SIDEWALK, th, inner), _concrete)
	for s in [-1.0, 1.0]:
		fb.add_box(c + Vector3(0, top, s * (half - 0.2)), Vector3(BLOCK, 0.02, 0.4), _curb)
		fb.add_box(c + Vector3(s * (half - 0.2), top, 0), Vector3(0.4, 0.02, inner), _curb)
	var is_plaza := plaza_blocks.has(Vector2i(bx, bz))
	var is_park := park_blocks.has(Vector2i(bx, bz))
	# lote: relva em 16 quadrados com tons ligeiramente diferentes
	var tiles := 4
	var ts := inner / tiles
	for ix in tiles:
		for iz in tiles:
			var col := _concrete.darkened(0.1) if is_plaza else _grass.lerp(Color(0.4, 0.5, 0.26), rng.randf_range(0.0, 0.5)).darkened(rng.randf_range(0.0, 0.1))
			fb.add_box(c + Vector3((ix + 0.5 - tiles * 0.5) * ts, cy, (iz + 0.5 - tiles * 0.5) * ts), Vector3(ts, th, ts), col)
	if is_plaza:
		_plaza(c, inner, bx + bz)
		return
	if is_park:
		_park(c, inner)
		return
	_ring_buildings(c, inner)
	# quintais: árvores, arbustos, barracões
	for k in 16:
		_add_tree(c + Vector3(rng.randf_range(-inner * 0.32, inner * 0.32), CURB_H, rng.randf_range(-inner * 0.32, inner * 0.32)), rng.randf_range(0.8, 1.3))
	for k in 3:
		var sp := c + Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))
		var sh := Color.from_hsv(rng.randf(), 0.25, 0.8)
		fb.add_box(sp + Vector3(0, 1.2, 0), Vector3(3.0, 2.4, 2.4), sh)
		fb.add_box(sp + Vector3(0, 2.55, 0), Vector3(3.4, 0.3, 2.8), Color(0.35, 0.3, 0.28))
		_collide(sp, Transform3D(Basis.IDENTITY, sp + Vector3(0, 1.2, 0)), Vector3(3.0, 2.4, 2.4))


func _plaza(c: Vector3, inner: float, seed_i: int) -> void:
	var yaw := 0.0 if seed_i % 2 == 0 else PI * 0.5
	var list: Array = [["Roads_000", Transform3D(Basis(Vector3.UP, yaw), c + Vector3(0, CURB_H, 0)), true]]
	var mi := MeshInstance3D.new()
	mi.mesh = _merge_pieces(list)
	mi.visibility_range_end = 330.0
	add_child(mi)
	# fonte no centro, bancos e quiosques à volta
	_mm_add("fountain", _prop("fountain"), Transform3D(Basis.IDENTITY, c + Vector3(0, CURB_H, 0)))
	_collide(c, Transform3D(Basis.IDENTITY, c + Vector3(0, 1.0, 0)), Vector3(8.4, 2.0, 8.4))
	for k in 6:
		var a := TAU * k / 6.0
		_mm_add("bench", _prop("bench"), Transform3D(Basis(Vector3.UP, -a + PI * 0.5), c + Vector3(cos(a) * 9.5, CURB_H, sin(a) * 9.5)))
	for k in 4:
		var a2 := TAU * (k + 0.5) / 4.0
		var kp := c + Vector3(cos(a2) * 20.0, CURB_H, sin(a2) * 20.0)
		var fb := _fb(c)
		fb.append(CityProps.kiosk(Color.from_hsv(rng.randf(), 0.7, 0.85)), Transform3D(Basis(Vector3.UP, -a2 - PI * 0.5), kp))
		_collide(kp, Transform3D(Basis(Vector3.UP, -a2 - PI * 0.5), kp + Vector3(0, 1.4, 0)), Vector3(3.6, 2.8, 3.0))
	for k in 10:
		_add_tree(c + Vector3(rng.randf_range(-inner * 0.45, inner * 0.45), CURB_H, rng.randf_range(-inner * 0.45, inner * 0.45)), rng.randf_range(1.0, 1.3))
	_ring_buildings(c, inner, true)


func _park(c: Vector3, inner: float) -> void:
	var fb := _fb(c)
	# caminhos em cruz, lagoa e bancos
	fb.add_box(c + Vector3(0, 0.03, 0), Vector3(inner, 0.04, 4.0), Color(0.74, 0.68, 0.55))
	fb.add_box(c + Vector3(0, 0.03, 0), Vector3(4.0, 0.04, inner), Color(0.74, 0.68, 0.55))
	fb.add_box(c + Vector3(-22, 0.04, -22), Vector3(20, 0.04, 14), Color(0.24, 0.5, 0.65))
	for k in 8:
		var bp := c + Vector3(-1, CURB_H, 6.0 + k * 8.0) if k < 4 else c + Vector3(6.0 + (k - 4) * 8.0, CURB_H, -1)
		_mm_add("bench", _prop("bench"), Transform3D(Basis(Vector3.UP, PI * 0.5 if k < 4 else 0.0), bp))
	for k in 70:
		var p := c + Vector3(rng.randf_range(-inner * 0.46, inner * 0.46), CURB_H, rng.randf_range(-inner * 0.46, inner * 0.46))
		if absf(p.x - c.x) < 3.5 or absf(p.z - c.z) < 3.5:
			continue
		_add_tree(p, rng.randf_range(0.9, 1.6))


## Casas à volta do quarteirão, viradas para a rua.
func _ring_buildings(c: Vector3, inner: float, sparse: bool = false) -> void:
	var half := inner * 0.5
	var corner := 21.0
	for side in 4:
		var out_dir := Vector3(0, 0, 1).rotated(Vector3.UP, side * PI * 0.5)
		var tang := Vector3(1, 0, 0).rotated(Vector3.UP, side * PI * 0.5)
		var t := -half + corner
		var end := half - corner
		while t < end - 6.0:
			var use_fbx := rng.randf() < 0.4
			var w: float
			var d: float
			var info: Dictionary = {}
			var h := 8.3
			if use_fbx:
				var sz := house_size()
				w = sz.x
				d = sz.z
				h = sz.y
			else:
				info = ProcHouse.build(rng)
				w = info["w"]
				d = info["d"]
				h = info["h"]
			if t + w > end:
				break
			if sparse and rng.randf() < 0.5:
				t += w + rng.randf_range(6.0, 12.0)
				continue
			var tc := t + w * 0.5
			var depth_pos := half - 3.0 - d * 0.5
			var pos := c + tang * tc + out_dir * depth_pos + Vector3(0, CURB_H, 0)
			var xf := Transform3D(Basis(Vector3.UP, atan2(out_dir.x, out_dir.z)), pos)
			var k := _chunk(pos)
			if use_fbx:
				if not _fbx_xf.has(k):
					_fbx_xf[k] = []
				_fbx_xf[k].append(xf)
				fbx_count += 1
			else:
				if not _houses_b.has(k):
					_houses_b[k] = MeshBuilder.new()
					_houses_g[k] = MeshBuilder.new()
				(_houses_b[k] as MeshBuilder).append(info["b"], xf)
				(_houses_g[k] as MeshBuilder).append(info["g"], xf)
			_collide(pos, Transform3D(xf.basis, pos + Vector3(0, h * 0.5, 0)), Vector3(w, h, d))
			t += w + rng.randf_range(3.0, 7.5)


func _add_tree(pos: Vector3, s: float) -> void:
	var kind := "tree" if rng.randf() < 0.65 else "tree2"
	_mm_add(kind, _prop(kind), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos))


# ---------------------------------------------------------------- HORIZONTE

func _skyline() -> void:
	var b := MeshBuilder.new()
	for i in 90:
		var a := TAU * float(i) / 90.0 + rng.randf_range(-0.03, 0.03)
		var r := rng.randf_range(340.0, 470.0)
		var w := rng.randf_range(14.0, 34.0)
		var h := rng.randf_range(25.0, 130.0)
		var tone := rng.randf_range(0.5, 0.72)
		var col := Color(tone * 0.9, tone, tone * 1.1)
		var pos := Vector3(cos(a) * r, h * 0.5, sin(a) * r)
		b.xf = Transform3D(Basis(Vector3.UP, -a), pos)
		b.add_box(Vector3.ZERO, Vector3(w, h, w * rng.randf_range(0.8, 1.4)), col)
		if rng.randf() < 0.4:
			b.add_box(Vector3(0, h * 0.5 + 4.0, 0), Vector3(w * 0.4, 8.0, w * 0.4), col.darkened(0.15))
	# montanhas distantes
	b.xf = Transform3D.IDENTITY
	for i in 26:
		var a2 := TAU * float(i) / 26.0
		var r2 := rng.randf_range(760.0, 900.0)
		var hh := rng.randf_range(90.0, 220.0)
		b.add_cone(Vector3(cos(a2) * r2, -2.0, sin(a2) * r2), rng.randf_range(160.0, 260.0), hh, 6, Color(0.42, 0.52, 0.6).lerp(Color(0.6, 0.68, 0.76), rng.randf()))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(_vmat())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- CONSTRUÇÃO FINAL

func _flush() -> void:
	var vm := _vmat()
	for k in _flat:
		var mi := MeshInstance3D.new()
		mi.mesh = (_flat[k] as MeshBuilder).build(vm)
		mi.visibility_range_end = 330.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.roughness = 0.15
	glass.metallic = 0.3
	glass.emission_enabled = true
	glass.emission = Color(0.05, 0.08, 0.12)
	for k in _houses_b:
		var mesh := (_houses_b[k] as MeshBuilder).build(vm)
		(_houses_g[k] as MeshBuilder).add_to(mesh, glass)
		var mi2 := MeshInstance3D.new()
		mi2.mesh = mesh
		mi2.visibility_range_end = 300.0
		add_child(mi2)
	var hm := _house()
	for k in _fbx_xf:
		_add_multimesh(hm, _fbx_xf[k], [], 300.0, true)
	for kind in _mm:
		var shadows: bool = kind in ["car", "barrier", "fountain"]
		for k in _mm[kind]:
			_add_multimesh(_mm_mesh[kind], _mm[kind][k], _mm_col[kind][k], 230.0, shadows)
	for k in _boxes:
		var body := StaticBody3D.new()
		for e in _boxes[k]:
			var cs := CollisionShape3D.new()
			var shp := BoxShape3D.new()
			shp.size = e[1]
			cs.shape = shp
			cs.transform = e[0]
			body.add_child(cs)
		add_child(body)


func _add_multimesh(mesh: Mesh, xfs: Array, colors: Array, range_end: float, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() == xfs.size() and colors.size() > 0
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = range_end
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
