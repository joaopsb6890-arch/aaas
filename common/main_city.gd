extends "res://common/main.gd"
## Mapa da cidade grande: constrói as ruas/casas, posiciona tudo e prepara a navegação.

const NAV_PATH := "res://world/city/city_nav.res"

var city: CityMap


func _ready() -> void:
	var region := $NavigationRegion as NavigationRegion3D
	city = CityMap.new()
	city.name = "City"
	region.add_child(city)
	city.build()
	_setup_navigation(region)
	_place_things()
	super._ready()
	_style_environment()


func _setup_navigation(region: NavigationRegion3D) -> void:
	if ResourceLoader.exists(NAV_PATH):
		region.navigation_mesh = load(NAV_PATH)
		return
	# sem malha pré-calculada: gera em segundo plano (os zombies só andam quando ficar pronta)
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.cell_size = 0.3
	nm.filter_baking_aabb = AABB(Vector3(-262, -2, -262), Vector3(524, 12, 524))
	nm.cell_height = 0.25
	nm.agent_radius = 0.6
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.4
	region.navigation_mesh = nm
	region.bake_navigation_mesh(true)


func _place_things() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# jogador e jipe no cruzamento central
	var start := Vector3(0, 0.3, 14)
	$Player.global_position = start
	$Jeep.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-9, 0.7, 6))
	# pontos de rua longe do início para zombies e barris
	var pts: Array[Vector3] = []
	for p in city.street_points:
		if p.distance_to(start) > 70.0:
			pts.append(p)
	for i in range(pts.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := pts[i]
		pts[i] = pts[j]
		pts[j] = tmp
	var enemies := $Enemies as Node3D
	var template := enemies.get_node("Spawner") as Node3D
	var spawners: Array[Node] = []
	for c in enemies.get_children():
		spawners.append(c)
	var wanted := 12
	while spawners.size() < wanted:
		var d := template.duplicate()
		enemies.add_child(d)
		spawners.append(d)
	for i in spawners.size():
		var sp := spawners[i] as Node3D
		sp.global_position = pts[i % pts.size()]
		sp.spawn_range = 6.0
		sp.max_items = 2
	var k := spawners.size()
	for b in $explosive_items.get_children():
		(b as Node3D).global_position = pts[k % pts.size()] + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
		k += 1
	# caixas de munição espalhadas
	var ammo := load("res://common/utils/ammo_refil.tscn") as PackedScene
	for n in 10:
		var a := ammo.instantiate() as Node3D
		add_child(a)
		a.global_position = pts[(k + n * 3) % pts.size()] + Vector3(4, 0, 4)


## Ambiente mais bonito: neblina de distância (esconde o corte de objetos), cor e contraste.
func _style_environment() -> void:
	for n in find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.85
		env.ambient_light_energy = 0.6
		env.fog_enabled = true
		env.fog_light_color = Color(0.72, 0.8, 0.9)
		env.fog_density = 0.0016
		env.fog_sky_affect = 0.4
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.12
		env.adjustment_contrast = 1.05
	for l in find_children("*", "DirectionalLight3D", true, false):
		var d := l as DirectionalLight3D
		d.light_energy = minf(d.light_energy, 0.9)
		d.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
