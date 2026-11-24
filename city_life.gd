extends Node3D
## Adds safe perimeter walls and a small living plaza around the imported city.
const NPC_SCENE: PackedScene = preload("res://mixamo_player/assets/YBot.scn")
const NPC_SCRIPT: Script = preload("res://city_npc.gd")

@export var wall_height: float = 5.0
@export var add_market: bool = true
@export var add_fountain: bool = true
@export var add_walking_people: bool = true

func _ready() -> void:
	call_deferred("_build_city_life")

func _build_city_life() -> void:
	var city := get_parent().get_node_or_null("City")
	if city == null:
		return
	var bounds := _get_world_bounds(city)
	if bounds.size.x < 10.0 or bounds.size.z < 10.0:
		return
	_add_perimeter(bounds)
	var ground_y := bounds.position.y + 0.12
	var plaza := Vector3(bounds.position.x + bounds.size.x * 0.68, ground_y, bounds.position.z + bounds.size.z * 0.55)
	if add_market:
		_add_market(bounds, ground_y)
	if add_fountain:
		_add_fountain(plaza)
	if add_walking_people:
		_add_people(bounds, ground_y)

func _get_world_bounds(root: Node) -> AABB:
	var result := AABB()
	var found := false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var local_box := mesh_node.get_aabb()
		for corner_index in 8:
			var point := mesh_node.global_transform * local_box.get_endpoint(corner_index)
			if not found:
				result = AABB(point, Vector3.ZERO)
				found = true
			else:
				result = result.expand(point)
	return result

func _add_perimeter(bounds: AABB) -> void:
	var margin := 2.0
	var center_y := bounds.position.y + wall_height * 0.5
	var x := bounds.position.x + bounds.size.x * 0.5
	var z := bounds.position.z + bounds.size.z * 0.5
	_add_wall(Vector3(x, center_y, bounds.position.z - margin), Vector3(bounds.size.x + margin * 2.0, wall_height, 1.4))
	_add_wall(Vector3(x, center_y, bounds.position.z + bounds.size.z + margin), Vector3(bounds.size.x + margin * 2.0, wall_height, 1.4))
	_add_wall(Vector3(bounds.position.x - margin, center_y, z), Vector3(1.4, wall_height, bounds.size.z))
	_add_wall(Vector3(bounds.position.x + bounds.size.x + margin, center_y, z), Vector3(1.4, wall_height, bounds.size.z))

func _add_wall(at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "CityBoundary"
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.31, 0.34, 0.36)
	material.roughness = 0.95
	visual.material_override = material
	body.add_child(visual)
	add_child(body)

func _add_market(bounds: AABB, ground_y: float) -> void:
	var start := Vector3(bounds.position.x + bounds.size.x * 0.16, ground_y, bounds.position.z + bounds.size.z * 0.20)
	var spacing := maxf(5.0, minf(bounds.size.x, bounds.size.z) * 0.07)
	for index in 3:
		_add_stall(start + Vector3(spacing * index, 0, 0))
	for index in 3:
		_add_stall(start + Vector3(spacing * index, 0, spacing * 1.25))

func _add_stall(at: Vector3) -> void:
	var stall := Node3D.new()
	stall.name = "MarketStall"
	stall.position = at
	add_child(stall)
	_add_box(stall, Vector3(0, 0.65, 0), Vector3(3.0, 1.3, 1.8), Color(0.48, 0.27, 0.13))
	_add_box(stall, Vector3(0, 1.65, 0), Vector3(3.4, 0.22, 2.2), Color(0.72, 0.24, 0.16))
	_add_box(stall, Vector3(-1.38, 1.25, 0), Vector3(0.14, 2.5, 0.14), Color(0.25, 0.19, 0.14))
	_add_box(stall, Vector3(1.38, 1.25, 0), Vector3(0.14, 2.5, 0.14), Color(0.25, 0.19, 0.14))
	_add_box(stall, Vector3(0, 1.95, 0), Vector3(0.14, 0.14, 2.0), Color(0.25, 0.19, 0.14))

func _add_fountain(at: Vector3) -> void:
	var fountain := Node3D.new()
	fountain.name = "AnimatedFountain"
	fountain.position = at
	add_child(fountain)
	_add_cylinder(fountain, Vector3(0, 0.18, 0), 2.4, 0.36, Color(0.55, 0.59, 0.62))
	_add_cylinder(fountain, Vector3(0, 0.48, 0), 1.85, 0.22, Color(0.68, 0.72, 0.75))
	_add_cylinder(fountain, Vector3(0, 0.95, 0), 0.32, 0.85, Color(0.48, 0.53, 0.57))
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.08, 0.58, 0.82, 0.82)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.metallic = 0.25
	water.roughness = 0.12
	_add_cylinder(fountain, Vector3(0, 0.40, 0), 1.62, 0.08, water.albedo_color)
	var spray := CPUParticles3D.new()
	spray.name = "WaterSpray"
	spray.amount = 90
	spray.lifetime = 1.35
	spray.emitting = true
	spray.explosiveness = 0.0
	spray.direction = Vector3(0, 1, 0)
	spray.spread = 12.0
	spray.initial_velocity_min = 2.5
	spray.initial_velocity_max = 4.2
	spray.gravity = Vector3(0, -9.8, 0)
	spray.scale_amount_min = 0.035
	spray.scale_amount_max = 0.075
	spray.position.y = 0.9
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.045
	particle_mesh.height = 0.09
	spray.mesh = particle_mesh
	var particle_material := StandardMaterial3D.new()
	particle_material.albedo_color = Color(0.35, 0.82, 1.0)
	particle_material.emission_enabled = true
	particle_material.emission = Color(0.08, 0.35, 0.65)
	spray.material_override = particle_material
	fountain.add_child(spray)

func _add_cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> void:
	var item := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	item.mesh = mesh
	item.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.3
	item.material_override = material
	parent.add_child(item)

func _add_box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	item.mesh = mesh
	item.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	item.material_override = material
	parent.add_child(item)

func _add_people(bounds: AABB, ground_y: float) -> void:
	var start := Vector3(bounds.position.x + bounds.size.x * 0.18, ground_y, bounds.position.z + bounds.size.z * 0.24)
	var step := maxf(4.0, minf(bounds.size.x, bounds.size.z) * 0.055)
	for index in 3:
		var npc := Node3D.new()
		npc.name = "CityWalker_%d" % index
		npc.set_script(NPC_SCRIPT)
		npc.position = start + Vector3(step * index, 0, step * 2.7)
		npc.route = [
			npc.position,
			npc.position + Vector3(step * 1.3, 0, 0),
			npc.position + Vector3(step * 1.3, 0, step * 0.65),
			npc.position + Vector3(0, 0, step * 0.65)
		]
		var model := NPC_SCENE.instantiate()
		model.name = "AnimatedPerson"
		npc.add_child(model)
		add_child(npc)
